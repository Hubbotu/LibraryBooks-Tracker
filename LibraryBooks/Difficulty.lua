local _, ns = ...

local SEV = { "easy", "fair", "risky", "danger" }
ns.TierColors = {
    easy = { 0.35, 0.85, 0.40 }, fair = { 0.95, 0.85, 0.30 }, risky = { 1.0, 0.60, 0.20 },
    danger = { 0.95, 0.30, 0.30 }, missing = { 0.60, 0.60, 0.60 },
}

local function opposite(f) return f == "Alliance" and "Horde" or "Alliance" end

-- Returns a table: tier, sev, mode, zone, lines = { {kind="warn"|"info", text=} }
function ns.Assess(book, loc)
    local level = UnitLevel("player") or 1
    local zone = ns.zones[loc.map]
    local a = { mode = book.mode, zone = zone, lines = {}, level = level }
    local function add(kind, key, ...) a.lines[#a.lines + 1] = { kind = kind, text = ns.S(key, ...) } end

    if book.mode == "missing" then
        a.tier, a.sev = "missing", 0
        add("warn", "note_missing")
        return a
    end

    local sev = 1
    local group = (book.mode == "group" or book.mode == "pet")
    if zone and not zone.city then
        local shift = book.hard and 3 or 0
        local lo, hi = zone.lo + shift, zone.hi + shift
        local fairMin = lo - (group and 3 or 0)
        if level >= hi then sev = 1
        elseif level >= fairMin then sev = 2
        elseif level >= fairMin - 3 then sev = 3
        else sev = 4 end
        if sev == 3 then add("warn", "warn_risky", zone.lo, zone.hi, level) end
        if sev == 4 then
            if group then add("warn", "warn_grouplow", level, zone.lo, zone.hi)
            else add("warn", "warn_danger", zone.lo, zone.hi, level) end
        elseif sev == 3 and group then
            add("warn", "warn_grouplow", level, zone.lo, zone.hi)
        end
    end

    if book.minLevel and level < book.minLevel then
        sev = 4
        add("warn", "warn_minlevel", book.minLevel)
    end
    if book.fav then
        if book.fav ~= ns.faction then
            sev = math.max(sev, 3)
            add("warn", "warn_hostile", ns.FactionName(book.fav))
        else
            add("info", "note_fav")
        end
    end
    if group then add("info", "note_group") end
    if book.mode == "pet" then add("info", "note_pet") end
    if book.mode == "depends" then add("info", "note_depends") end
    if book.hard then add("info", "note_hard", 3) end
    if book.wait then add("info", "note_wait") end
    if book.long then add("info", "note_long") end

    a.sev, a.tier = sev, SEV[sev]
    return a
end

-- Easiest location of a book (for the list view).
function ns.BestLoc(book)
    local best, bestSev, bestIdx = book.locs[1], 99, 1
    for i, loc in ipairs(book.locs) do
        local s = loc.kind == "entrance" and 99 or ns.Assess(book, loc).sev
        if s < bestSev then best, bestSev, bestIdx = loc, s, i end
    end
    return best, bestIdx
end

-- Nearest location to the player (same continent), else the easiest one.
function ns.NearestLoc(book)
    if #book.locs == 1 or (#book.locs == 2 and book.locs[2].kind == "entrance") then return book.locs[1], 1 end
    local mapID = ns.CurrentMap()
    local pos
    if mapID then pos = C_Map.GetPlayerMapPosition(mapID, "player") end
    if pos then
        local px, py = pos:GetXY()
        local pi, pwx, pwy = ns.WorldPos(mapID, px * 100, py * 100)
        if pi then
            local best, bi, bd
            for i, loc in ipairs(book.locs) do
                local li, lx, ly = ns.WorldPos(loc.map, loc.x, loc.y)
                if li == pi and loc.kind ~= "entrance" then
                    local d = (lx - pwx) ^ 2 + (ly - pwy) ^ 2
                    if not bd or d < bd then best, bi, bd = loc, i, d end
                end
            end
            if best then return best, bi end
        end
    end
    return ns.BestLoc(book)
end

function ns.ZoneColor(zone, level)
    if not zone or zone.city then return 0.7, 0.8, 1.0 end
    if level >= zone.hi then return 0.35, 0.85, 0.40 end
    if level >= zone.lo then return 0.95, 0.85, 0.30 end
    if level >= zone.lo - 3 then return 1.0, 0.60, 0.20 end
    return 0.95, 0.30, 0.30
end

local function hex(r, g, b) return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255) end
ns.Hex = hex

-- Coloured "lo–hi" text for the zone, or the capital label.
function ns.LevelText(zone, level)
    if not zone then return "?" end
    if zone.city then return ns.S("city") end
    return hex(ns.ZoneColor(zone, level)) .. zone.lo .. "–" .. zone.hi .. "|r"
end


ns.RatingColors = {
    green = { 0.20, 0.85, 0.25 }, yellow = { 0.97, 0.82, 0.15 },
    red = { 0.92, 0.22, 0.20 }, gray = { 0.50, 0.50, 0.50 },
}
function ns.Rating(book, loc)
    if ns.IsCollected(book) then return "gray" end
    if book.mode == "missing" or book.mode == "group" or book.mode == "pet" then return "red" end
    local sev = ns.Assess(book, loc).sev
    if sev <= 1 then return "green" end
    if sev <= 3 then return "yellow" end
    return "red"
end
