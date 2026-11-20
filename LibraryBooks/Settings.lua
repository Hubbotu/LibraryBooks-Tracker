local _, ns = ...
ns.Settings = {}
local function at(frame, point, x, y) frame:SetPoint(point, x, y) end
local function wash(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a) end
local function hideTip() GameTooltip:Hide() end

function ns.Settings.RegisterBlizzard()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    pcall(function()
        local f = CreateFrame("Frame")
        f.name = "Library Books"
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(200, 26); at(btn, "TOPLEFT", 20, -20); btn:SetText("Library Books")
        btn:SetScript("OnClick", function()
            if SettingsPanel and SettingsPanel.Hide then HideUIPanel(SettingsPanel) end
            ns.UI.ToggleSettings()
        end)
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(f, f.name))
    end)
end
