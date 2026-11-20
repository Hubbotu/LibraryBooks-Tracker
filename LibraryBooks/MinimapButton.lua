local _, ns = ...
local Button = {}
ns.MinimapButton = Button
local frame

local function reposition()
    local rad = math.rad(ns.db.minimapButton.angle or 215)
    local dist = Minimap:GetWidth() / 2 + 6
    frame:ClearAllPoints()
    local dx, dy = math.cos(rad) * dist, math.sin(rad) * dist
    frame:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
end

local function followCursor()
    local factor = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local rise, run = cursorY / factor - centerY, cursorX / factor - centerX
    ns.db.minimapButton.angle = math.deg(math.atan2(rise, run))
    reposition()
end

-- Adds the uncollected books of the current location to the tooltip (if enabled).
local function describeHere(tt)
    if not ns.db.showLocalTip then return end
    local here = ns.LocalBooks()
    if #here == 0 then return end
    local map = ns.CurrentMap()
    tt:AddLine(" ")
    tt:AddLine(ns.S("tip_here", #here) .. "  " .. ns.ZoneName(map), 0.96, 0.78, 0.25)
    for i = 1, math.min(#here, 10) do
        local b = here[i]
        local spot = b.locs[1]
        for _, l in ipairs(b.locs) do
            if l.map == map and l.kind ~= "entrance" then spot = l; break end
        end
        local col = ns.RatingColors[ns.Rating(b, spot)]
        tt:AddDoubleLine(ns.Title(b), ns.S("mode_" .. b.mode), col[1], col[2], col[3], 0.7, 0.7, 0.7)
    end
    if #here > 10 then tt:AddLine(ns.S("tip_more", #here - 10), 0.7, 0.7, 0.7) end
end

local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.S("title"), 1, 0.85, 0.35)
    GameTooltip:AddLine(ns.S("btn_tip"), 0.8, 0.8, 0.8)
    GameTooltip:AddLine(ns.S("progress", ns.CountCollected(), #ns.books), 0.4, 0.9, 0.5)
    describeHere(GameTooltip)
    GameTooltip:Show()
end

function Button.Update()
    if frame then frame:SetShown(not ns.db.minimapButton.hide) end
end

function Button.Init()
    if frame then return end
    frame = CreateFrame("Button", "LibraryBooksMinimapButton", Minimap)
    frame:SetSize(31, 31)
    frame:SetFrameStrata("MEDIUM"); frame:SetFrameLevel(8)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:RegisterForDrag("LeftButton")
    local backing = frame:CreateTexture(nil, "BACKGROUND")
    backing:SetSize(22, 22); backing:SetPoint("CENTER"); backing:SetColorTexture(0.05, 0.05, 0.08, 0.9)
    local emblem = frame:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(20, 20); emblem:SetPoint("CENTER"); emblem:SetTexture(ns.TEX .. ns.W.Theme().crest)
    local rim = frame:CreateTexture(nil, "OVERLAY")
    rim:SetSize(54, 54); rim:SetPoint("TOPLEFT"); rim:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    frame:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    frame:SetScript("OnClick", function(_, which)
        if which == "RightButton" then ns.UI.ToggleSettings() else ns.UI.Toggle() end
    end)
    frame:SetScript("OnEnter", showTooltip)
    frame:SetScript("OnLeave", function() if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end end)
    local function drag(self, on) self:SetScript("OnUpdate", on and followCursor or nil) end
    frame:SetScript("OnDragStart", function(self) drag(self, true) end)
    frame:SetScript("OnDragStop", function(self) drag(self, false) end)
    reposition()
    Button.Update()
end
