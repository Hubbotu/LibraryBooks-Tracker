local ADDON, ns = ...

local REFRESH_EVENTS = {
    "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_REMOVED",
    "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA",
}

local handlers = {}

function handlers.ADDON_LOADED(_, name)
    if name == ADDON then ns.InitDB() end
end

function handlers.PLAYER_LOGIN(frame)
    local faction = UnitFactionGroup("player")
    ns.faction = (faction == "Horde") and "Horde" or "Alliance"
    ns.UI.Init()
    ns.Pins.Init()
    ns.MinimapButton.Init()
    ns.Settings.RegisterBlizzard()
    for _, name in ipairs(REFRESH_EVENTS) do frame:RegisterEvent(name) end
    ns.QueueRefresh()
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("ADDON_LOADED")
listener:RegisterEvent("PLAYER_LOGIN")
listener:SetScript("OnEvent", function(self, event, ...)
    local handle = handlers[event]
    if handle then handle(self, ...) else ns.QueueRefresh() end
end)

-- Slash commands ------------------------------------------------------------------------
local LANG_ALIASES = { en = "enUS", ru = "ruRU", de = "deDE", enus = "enUS", ruru = "ruRU", dede = "deDE" }

local commands = {}
function commands.settings() ns.UI.ToggleSettings() end
commands.config, commands.options = commands.settings, commands.settings
function commands.lang(arg)
    local code = LANG_ALIASES[arg:lower()]
    if not code then ns.Print(ns.S("msg_help")); return end
    ns.SetLang(code)
    ns.Print(ns.S("msg_lang", ns.langNames[code]))
end
function commands.map()
    local id = ns.CurrentMap()
    local pos
    if id then pos = C_Map.GetPlayerMapPosition(id, "player") end
    if pos then
        local x, y = pos:GetXY()
        ns.Print(ns.S("msg_map", id, x * 100, y * 100))
    end
end
function commands.reset() ns.UI.ResetPosition(); ns.Print(ns.S("msg_reset")) end
function commands.minimap()
    ns.db.minimapButton.hide = not ns.db.minimapButton.hide
    ns.MinimapButton.Update()
end
function commands.clear() ns.ClearWaypoint() end

SLASH_LIBRARYBOOKS1, SLASH_LIBRARYBOOKS2, SLASH_LIBRARYBOOKS3 = "/librarybooks", "/lbooks", "/lb"
SlashCmdList["LIBRARYBOOKS"] = function(msg)
    local word, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    word = word:lower()
    if word == "" then ns.UI.Toggle(); return end
    local run = commands[word]
    if run then run(rest) else ns.Print(ns.S("msg_help")) end
end
