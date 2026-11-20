local _, ns = ...
local uid
local secure = securecallfunction or securecall

-- Run a function from a clean (untainted) call so Blizzard's map code is not blamed for our taint.
local function Clean(fn, ...)
    if secure then return secure(fn, ...) end
    return pcall(fn, ...)
end

function ns.HasTomTom() return TomTom ~= nil and TomTom.AddWaypoint ~= nil end
function ns.HasBlizzPin()
    return C_Map ~= nil and C_Map.SetUserWaypoint ~= nil and UiMapPoint ~= nil and UiMapPoint.CreateFromCoordinates ~= nil
end

function ns.ClearWaypoint()
    if uid and ns.HasTomTom() and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, uid) end
    uid = nil
    if C_Map and C_Map.HasUserWaypoint and C_Map.ClearUserWaypoint then
        Clean(function() if C_Map.HasUserWaypoint() then C_Map.ClearUserWaypoint() end end)
    end
    ns.ping = nil
    ns.Changed()
end

-- Highlight a spot on the world map and minimap (our own "ping").
function ns.Ping(book, loc)
    ns.ping = { id = book.id, loc = loc, expires = GetTime() + 15 }
    ns.Changed()
end

local function UseTomTom() return ns.db.wpMode == "tomtom" and ns.HasTomTom() end

-- Places one waypoint with the chosen system. Returns true when a system was used.
local function Place(title, loc)
    if UseTomTom() then
        if uid and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, uid) end
        local ok, id = pcall(TomTom.AddWaypoint, TomTom, loc.map, loc.x / 100, loc.y / 100, {
            title = title, persistent = false, minimap = true, world = true, crazy = true, from = "Library Books",
        })
        if ok and id then uid = id; return true end
    elseif ns.HasBlizzPin() then
        Clean(function()
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(loc.map, loc.x / 100, loc.y / 100))
            local track = C_SuperTrack
            if track and track.SetSuperTrackedUserWaypoint then track.SetSuperTrackedUserWaypoint(true) end
        end)
        return true
    end
    return false
end

function ns.SetWaypoint(book, loc)
    loc = loc or ns.NearestLoc(book)
    if loc.kind == "unconfirmed" then ns.Print(ns.S("msg_noway")); return false end
    if not ns.MapInfo(loc.map) then ns.Print(ns.S("msg_nomap")); return false end
    local title = ns.Title(book)
    local used = Place(title, loc)
    ns.Ping(book, loc)
    if used then ns.Print(ns.S("msg_way", title, ns.ZoneName(loc.map), loc.x, loc.y)) else ns.Print(ns.S("msg_nosys")) end
    return true
end

-- Waypoint to the book turn-in point of the player's faction.
function ns.SetTurnInWaypoint()
    local spot = ns.TurnInSpot()
    if not spot then return false end
    if not ns.MapInfo(spot.map) then ns.Print(ns.S("msg_nomap")); return false end
    local title = ns.S("turn_title")
    local used = Place(title, spot)
    ns.Ping({ id = "turnin" }, spot)
    if used then ns.Print(ns.S("msg_way", title, ns.ZoneName(spot.map), spot.x, spot.y)) else ns.Print(ns.S("msg_nosys")) end
    return true
end

function ns.OpenMap(map)
    if not WorldMapFrame then return end
    Clean(function()
        if not WorldMapFrame:IsShown() then
            if ToggleWorldMap then ToggleWorldMap() else WorldMapFrame:Show() end
        end
        if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(map) end
    end)
end
