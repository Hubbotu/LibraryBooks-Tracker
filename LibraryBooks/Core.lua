local ADDON, ns = ...
_G.LibraryBooks = ns

ns.ADDON = ADDON
local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (meta and meta(ADDON, "Version")) or "?"
ns.TEX = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\"
ns.locales = {}
ns.langs = { "enUS", "ruRU", "deDE" }
ns.langLabels = { enUS = "EN", ruRU = "RU", deDE = "DE" }
ns.langNames = { enUS = "English", ruRU = "Русский", deDE = "Deutsch" }
ns.rev = 0
ns.faction = "Alliance"

ns.defaults = {
    lang = "enUS",
    showWorld = true,
    showMini = true,
    showContinent = true,
    showUnconfirmed = false,
    hideCollectedPins = true,
    listHideDone = false,
    iconSize = 22,
    opacity = 1,
    wpMode = "tomtom",
    warnings = true,
    showTurnIn = true,
    mapOutline = true,
    showLocalTip = true,
    uiScale = 1,
    minimapButton = { hide = false, angle = 215 },
}

local function Merge(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then dst[k] = {}; Merge(dst[k], v) else dst[k] = v end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            Merge(dst[k], v)
        end
    end
end

function ns.InitDB()
    LibraryBooksDB = LibraryBooksDB or {}
    LibraryBooksCharDB = LibraryBooksCharDB or {}
    LibraryBooksCharDB.manual = LibraryBooksCharDB.manual or {}
    Merge(LibraryBooksDB, ns.defaults)
    ns.db = LibraryBooksDB
    ns.charDB = LibraryBooksCharDB
end

-- Localisation -------------------------------------------------------------
function ns.RegisterLocale(code, data) ns.locales[code] = data end

function ns.GetLang()
    local l = ns.db and ns.db.lang
    if l and ns.locales[l] then return l end
    return "enUS"
end

function ns.tr(kind, key)
    local loc = ns.locales[ns.GetLang()]
    local v = loc and loc[kind] and loc[kind][key]
    if v == nil and ns.locales.enUS then v = ns.locales.enUS[kind] and ns.locales.enUS[kind][key] end
    return v
end

function ns.S(key, ...)
    local s = ns.tr("S", key) or key
    if select("#", ...) > 0 then return s:format(...) end
    return s
end

function ns.Title(book) return ns.tr("B", book.id) or book.id end
function ns.Desc(book, loc) return ns.tr("D", loc.d or book.id) or "" end

function ns.ZoneName(map)
    local n = ns.tr("Z", map)
    if n then return n end
    local info = ns.MapInfo(map)
    return info and info.name or tostring(map)
end

function ns.FactionName(f) return ns.S("faction_" .. tostring(f)) end

function ns.SetLang(code)
    if not ns.locales[code] then return end
    ns.db.lang = code
    ns.Changed()
    if ns.UI and ns.UI.Relocalize then ns.UI.Relocalize() end
end

-- State --------------------------------------------------------------------
local isDone = IsQuestFlaggedCompleted
do
    local questApi = C_QuestLog
    if questApi and questApi.IsQuestFlaggedCompleted then isDone = questApi.IsQuestFlaggedCompleted end
end

function ns.IsCollected(book)
    if book.q and isDone then
        local ok, res = pcall(isDone, book.q)
        if ok and res then return true, "quest" end
    end
    if ns.charDB and ns.charDB.manual[book.id] then return true, "manual" end
    return false
end

function ns.IsQuestDone(id)
    if not (id and isDone) then return false end
    local ok, res = pcall(isDone, id)
    return ok and res and true or false
end

function ns.CountCollected()
    local n = 0
    for _, b in ipairs(ns.books) do if ns.IsCollected(b) then n = n + 1 end end
    return n
end

function ns.ToggleManual(book)
    local done, how = ns.IsCollected(book)
    if how == "quest" then return false end
    ns.charDB.manual[book.id] = (not done) or nil
    ns.Changed()
    return true
end

function ns.Changed()
    ns.rev = ns.rev + 1
    if ns.Pins and ns.Pins.Refresh then ns.Pins.Refresh() end
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

local queued
function ns.QueueRefresh()
    if queued then return end
    queued = true
    local function fire() queued = false; ns.Changed() end
    C_Timer.After(0.4, fire)
end

function ns.PinVisible(book, loc)
    if loc.kind == "unconfirmed" and not ns.db.showUnconfirmed then return false end
    if ns.IsCollected(book) then return false end -- found books never appear on the maps
    return true
end

-- World coordinates (cached) ---------------------------------------------------
local wcache = {}
function ns.WorldPos(map, x, y)
    local key = map .. ":" .. x .. ":" .. y
    local c = wcache[key]
    if c == nil then
        c = false
        local api = C_Map
        if api and api.GetWorldPosFromMapPos then
            local probe = CreateVector2D(x / 100, y / 100)
            local inst, pos = api.GetWorldPosFromMapPos(map, probe)
            if pos then c = { inst, pos.x, pos.y } end
        end
        wcache[key] = c
    end
    if c then return c[1], c[2], c[3] end
end

function ns.Print(msg) print("|cffe8c14aLibrary Books|r: " .. msg) end

function ns.BookIcon(book)
    local id, icon = book.item, nil
    if id then
        local items = C_Item
        if items and items.GetItemIconByID then icon = items.GetItemIconByID(id) end
        if not icon then
            local instant = GetItemInfoInstant
            if items and items.GetItemInfoInstant then instant = items.GetItemInfoInstant end
            if instant then icon = select(5, instant(id)) end
        end
        if not icon and type(GetItemIcon) == "function" then icon = GetItemIcon(id) end
    end
    return icon or "Interface\\Icons\\INV_Misc_Book_11"
end

-- Current location helpers ---------------------------------------------------------
function ns.CurrentMap()
    local api = C_Map
    if not api or not api.GetBestMapForUnit then return nil end
    return api.GetBestMapForUnit("player")
end

function ns.MapInfo(id)
    local api = C_Map
    if not api or not api.GetMapInfo then return nil end
    return api.GetMapInfo(id)
end

function ns.InZone(book, map)
    for _, loc in ipairs(book.locs) do
        if loc.kind ~= "entrance" and loc.map == map then return true end
    end
    return false
end

function ns.IsLocalBook(book, map)
    map = map or ns.CurrentMap()
    return map ~= nil and not ns.IsCollected(book) and ns.InZone(book, map)
end

function ns.LocalBooks()
    local map, list = ns.CurrentMap(), {}
    if not map then return list end
    for _, b in ipairs(ns.books) do if ns.IsLocalBook(b, map) then list[#list + 1] = b end end
    return list
end

function ns.OrderLocalFirst(list)
    local map, first, rest = ns.CurrentMap(), {}, {}
    for _, b in ipairs(list) do
        if ns.IsLocalBook(b, map) then first[#first + 1] = b else rest[#rest + 1] = b end
    end
    for _, b in ipairs(rest) do first[#first + 1] = b end
    return first
end

function ns.TurnInSpot() return ns.turnIn and ns.turnIn[ns.faction] end
