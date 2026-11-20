local _, ns = ...
local Pins = {}
ns.Pins = Pins

local function hideTip() GameTooltip:Hide() end
local function note(tt, text, r, g, b) tt:AddLine(text, r, g, b, true) end
local MIN_SIZE = 8
-- Visible diameter of the minimap in yards, indexed by zoom level + 1.
local SPAN_OUTDOOR = { 466.67, 400, 333.33, 266.67, 200, 133.33 }
local SPAN_INDOOR = { 300, 240, 180, 120, 80, 50 }

-- Tooltips -----------------------------------------------------------------------
function ns.FillTooltip(tt, book, loc, withHints)
    local level = UnitLevel("player") or 1
    local a = ns.Assess(book, loc)
    tt:AddLine(ns.Title(book), 1, 0.85, 0.35)
    tt:AddDoubleLine(ns.ZoneName(loc.map), ns.S("zoneLevels") .. ": " .. ns.LevelText(a.zone, level), 0.8, 0.8, 0.8, 1, 1, 1)
    if ns.IsCollected(book) then tt:AddLine(ns.S("collected"), 0.35, 0.85, 0.4)
    else tt:AddLine(ns.S("notCollected"), 0.9, 0.9, 0.9) end
    local text = ns.Desc(book, loc)
    if text ~= "" then note(tt, text, 1, 1, 1) end
    if loc.kind and loc.kind ~= "exact" then note(tt, ns.S("kind_" .. loc.kind), 0.7, 0.8, 1) end
    if book.multi then note(tt, ns.S("note_multi"), 0.7, 0.8, 1) end
    tt:AddDoubleLine(ns.S("difficulty"), ns.S("mode_" .. book.mode) .. " · " .. ns.S("tier_" .. a.tier), 0.7, 0.7, 0.7,
        unpack(ns.TierColors[a.tier]))
    if ns.db.warnings then
        for _, line in ipairs(a.lines) do
            if line.kind == "warn" then note(tt, line.text, 1, 0.45, 0.35) end
        end
    end
    if withHints then
        tt:AddLine(" ")
        for _, key in ipairs({ "hint_click", "hint_shift", "hint_right" }) do tt:AddLine(ns.S(key), 0.6, 0.6, 0.6) end
    end
end

function ns.FillTurnInTooltip(tt, spot)
    tt:AddLine(ns.S("turn_title"), 0.4, 0.9, 0.95)
    tt:AddDoubleLine(ns.ZoneName(spot.map), ("%.1f / %.1f"):format(spot.x, spot.y), 0.8, 0.8, 0.8, 1, 1, 1)
    note(tt, ns.S("turn_desc"), 1, 1, 1)
    tt:AddLine(" ")
    tt:AddLine(ns.S("hint_click"), 0.6, 0.6, 0.6)
    tt:AddLine(ns.S("hint_right"), 0.6, 0.6, 0.6)
end

-- Entries to draw: one per visible book spot, plus the faction's turn-in point ---------
local function collect()
    local out = {}
    for _, book in ipairs(ns.books) do
        for _, loc in ipairs(book.locs) do
            if ns.PinVisible(book, loc) then out[#out + 1] = { book = book, loc = loc } end
        end
    end
    local spot = ns.TurnInSpot()
    if spot and ns.db.showTurnIn then out[#out + 1] = { loc = spot, turnin = true } end
    return out
end

-- Markers ----------------------------------------------------------------------------
local function markerEnter(m)
    GameTooltip:SetOwner(m, "ANCHOR_RIGHT")
    if m.isTurnIn then ns.FillTurnInTooltip(GameTooltip, m.loc) else ns.FillTooltip(GameTooltip, m.book, m.loc, true) end
    GameTooltip:Show()
end

local function markerClick(m, button)
    local right = button == "RightButton"
    if m.isTurnIn then
        if right then ns.OpenMap(m.loc.map); ns.Ping({ id = "turnin" }, m.loc) else ns.SetTurnInWaypoint() end
    elseif right then
        ns.OpenMap(m.loc.map); ns.Ping(m.book, m.loc)
    elseif IsShiftKeyDown() then
        if not ns.ToggleManual(m.book) then ns.Print(ns.S("msg_quest")) end
    else
        ns.SetWaypoint(m.book, m.loc)
    end
end

local function newMarker(parent)
    local m = CreateFrame("Button", nil, parent)
    m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    m.art = m:CreateTexture(nil, "ARTWORK"); m.art:SetAllPoints()
    m.halo = m:CreateTexture(nil, "OVERLAY")
    m.halo:SetTexture(ns.TEX .. "Ring"); m.halo:SetPoint("CENTER"); m.halo:Hide()
    local pulse = m.halo:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    if fade.SetFromAlpha then fade:SetFromAlpha(1); fade:SetToAlpha(0.15) else fade:SetChange(-0.85) end
    fade:SetDuration(0.6)
    m.pulse = pulse
    m:SetScript("OnEnter", markerEnter)
    m:SetScript("OnLeave", hideTip)
    m:SetScript("OnClick", markerClick)
    m:Hide()
    return m
end

local function dress(m, entry, base)
    m.book, m.loc, m.isTurnIn = entry.book, entry.loc, entry.turnin
    local variant = ns.db.mapOutline and "" or "Plain"
    local px, alpha = base, ns.db.opacity
    if entry.turnin then
        px = math.floor(base * 1.15 + 0.5)
        m.art:SetTexture(ns.TEX .. "TurnIn" .. variant)
    else
        local loc = entry.loc
        if loc.alt then px = math.max(MIN_SIZE, math.floor(base * 0.8 + 0.5)); alpha = alpha * 0.85 end
        if loc.kind == "unconfirmed" or loc.kind == "disputed" then alpha = alpha * 0.8 end
        local name = ns.IsCollected(entry.book) and "BookPinDone" or ("BookPin" .. variant)
        m.art:SetTexture(ns.TEX .. name)
    end
    m:SetSize(px, px)
    m.halo:SetSize(px * 2, px * 2)
    m:SetAlpha(alpha)
    local ping = ns.ping
    local wanted = entry.turnin and "turnin" or entry.book.id
    if ping and ping.expires > GetTime() and ping.id == wanted and ping.loc == entry.loc then
        m:SetAlpha(1); m.halo:Show()
        if not m.pulse:IsPlaying() then m.pulse:Play() end
    else
        m.pulse:Stop(); m.halo:Hide()
    end
end

-- A pool hands out markers during one redraw and hides the leftovers afterwards.
local function newPool(resolveParent)
    local pool = { items = {}, used = 0 }
    function pool:rewind() self.used = 0 end
    function pool:take()
        self.used = self.used + 1
        local m = self.items[self.used]
        if not m then m = newMarker(resolveParent()); self.items[self.used] = m end
        return m
    end
    function pool:sweep()
        for i = self.used + 1, #self.items do self.items[i]:Hide() end
    end
    return pool
end

-- World map and zone maps --------------------------------------------------------------
local worldPool
local instanceOfMap = {}

local function mapCanvas()
    return WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

local function canvasZoom()
    local sc = WorldMapFrame.ScrollContainer
    return sc.GetCanvasScale and sc:GetCanvasScale() or 1
end

local function instanceOf(mapID)
    local known = instanceOfMap[mapID]
    if known == nil then known = (ns.WorldPos(mapID, 50, 50)) or false; instanceOfMap[mapID] = known end
    return known or nil
end

-- Where a spot appears (0..1) on the map being shown, or nil.
local function locate(loc, mapID)
    if loc.map == mapID then return loc.x / 100, loc.y / 100 end
    local api = C_Map
    if not (api and CreateVector2D) then return end
    if api.GetWorldPosFromMapPos and api.GetMapPosFromWorldPos then
        local ok1, inst, wpos = pcall(api.GetWorldPosFromMapPos, loc.map, CreateVector2D(loc.x / 100, loc.y / 100))
        if ok1 and wpos and inst == instanceOf(mapID) then
            local ok2, _, mpos = pcall(api.GetMapPosFromWorldPos, inst, wpos, mapID)
            if ok2 and mpos then
                local fx, fy = mpos:GetXY()
                if fx and fy then return fx, fy end
            end
        end
    end
    if api.GetMapRectOnMap then
        local ok3, left, right, top, bottom = pcall(api.GetMapRectOnMap, loc.map, mapID)
        if ok3 and left and right and right > left and bottom > top then
            return left + loc.x / 100 * (right - left), top + loc.y / 100 * (bottom - top)
        end
    end
end

-- Level just above everything the map itself put on the canvas.
local function levelAbove(canvas)
    local top = canvas:GetFrameLevel()
    local kids = { canvas:GetChildren() }
    for i = 1, #kids do
        local lv = kids[i]:GetFrameLevel()
        if lv > top and not kids[i].libraryMarker then top = lv end
    end
    return math.min(top + 2, 9990)
end

local function redrawWorld()
    if not worldPool then return end
    worldPool:rewind()
    local canvas = mapCanvas()
    if canvas and ns.db.showWorld and WorldMapFrame:IsShown() then
        local mapID = WorldMapFrame:GetMapID()
        if mapID then
            local w, h, zoom = canvas:GetWidth(), canvas:GetHeight(), canvasZoom()
            local level = levelAbove(canvas)
            local onContinent = ns.continents[mapID]
            for _, entry in ipairs(collect()) do
                if entry.loc.map == mapID or ns.db.showContinent or not onContinent then
                    local fx, fy = locate(entry.loc, mapID)
                    if fx and fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1 then
                        local m = worldPool:take()
                        m.libraryMarker = true
                        dress(m, entry, ns.db.iconSize)
                        m:SetScale(1 / zoom)
                        m:SetFrameLevel(level)
                        m:ClearAllPoints()
                        m:SetPoint("CENTER", canvas, "TOPLEFT", fx * w * zoom, -fy * h * zoom)
                        m:Show()
                    end
                end
            end
        end
    end
    worldPool:sweep()
end

-- Minimap ------------------------------------------------------------------------------
local miniPool, miniTargets = nil, {}

local function rebuildMiniTargets()
    miniTargets = {}
    for _, entry in ipairs(collect()) do
        local inst, n, w = ns.WorldPos(entry.loc.map, entry.loc.x, entry.loc.y)
        if inst then miniTargets[#miniTargets + 1] = { entry = entry, inst = inst, n = n, w = w } end
    end
end

local function turn(x, y, s, c) return x * c - y * s, x * s + y * c end

local function redrawMini()
    if not miniPool then return end
    miniPool:rewind()
    if ns.db.showMini and UnitPosition and Minimap:IsVisible() then
        local pn, pw, _, pinst = UnitPosition("player")
        if pn and pw then
            local spans = (IsIndoors and IsIndoors()) and SPAN_INDOOR or SPAN_OUTDOOR
            local reach = (spans[Minimap:GetZoom() + 1] or spans[1]) / 2
            local halfW, halfH = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
            local heading = GetCVar("rotateMinimap") == "1" and GetPlayerFacing and GetPlayerFacing() or nil
            local s, c = 0, 1
            if heading then s, c = math.sin(heading), math.cos(heading) end
            local boxy = GetMinimapShape and GetMinimapShape() == "SQUARE"
            local px = math.max(MIN_SIZE, ns.db.iconSize * 0.7)
            for _, t in ipairs(miniTargets) do
                if t.inst == pinst then
                    local east, south = pw - t.w, pn - t.n -- yards to the right / downwards on screen
                    if heading then east, south = turn(east, south, s, c) end
                    east, south = east / reach, south / reach
                    local inside = boxy and (math.abs(east) <= 1 and math.abs(south) <= 1) or (not boxy and east * east + south * south <= 1)
                    if inside then
                        local m = miniPool:take()
                        dress(m, t.entry, px)
                        m:ClearAllPoints()
                        m:SetPoint("CENTER", Minimap, "CENTER", east * halfW, -south * halfH)
                        m:Show()
                    end
                end
            end
        end
    end
    miniPool:sweep()
end

function Pins.Refresh()
    if not miniPool then return end
    rebuildMiniTargets()
    redrawMini()
    redrawWorld()
end

function Pins.Init()
    local canvas = mapCanvas()
    if canvas then
        worldPool = newPool(mapCanvas)
        if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", redrawWorld) end
        WorldMapFrame:HookScript("OnShow", redrawWorld)
        local lastSignature
        C_Timer.NewTicker(0.2, function()
            if ns.ping and ns.ping.expires < GetTime() then ns.ping = nil; lastSignature = nil end
            local c = mapCanvas()
            local signature = ("%s|%.4f|%.1f"):format(tostring(WorldMapFrame:GetMapID()), canvasZoom(), c and c:GetWidth() or 0)
            if signature ~= lastSignature then lastSignature = signature; redrawWorld() end
        end)
    end
    local holder = CreateFrame("Frame", nil, Minimap)
    holder:SetAllPoints(Minimap)
    holder:SetFrameLevel(Minimap:GetFrameLevel() + 4)
    miniPool = newPool(function() return holder end)
    C_Timer.NewTicker(0.1, redrawMini)
    Pins.Refresh()
end
