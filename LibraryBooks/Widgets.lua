local _, ns = ...
local W = {}
ns.W = W

local W8 = "Interface\\Buttons\\WHITE8X8"
-- Small layout helpers (keep call sites short).
local function at(frame, point, x, y) frame:SetPoint(point, x, y) end
local function wash(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a) end
local function hideTip() GameTooltip:Hide() end

local FONT = "Fonts\\ARIALN.TTF" -- ships with every client and covers Latin + Cyrillic
W.W8 = W8

for _, s in ipairs({ 10, 11, 12, 13, 14, 16, 18, 22 }) do
    local f = CreateFont("LibraryBooksFont" .. s)
    f:SetFont(FONT, s, "")
    f:SetTextColor(0.92, 0.92, 0.92)
end
do
    local f = CreateFont("LibraryBooksFontBar")
    f:SetFont(FONT, 11, "OUTLINE"); f:SetTextColor(1, 1, 1)
end
function W.Font(size) return "LibraryBooksFont" .. size end

W.THEMES = {
    Alliance = { accent = { 0.27, 0.55, 0.98 }, gold = { 0.96, 0.80, 0.34 }, bg = { 0.045, 0.06, 0.10, 0.97 },
        panel = { 0.075, 0.095, 0.15, 1 }, crest = "CrestAlliance", book = "BookAlliance",
        heading = { 0.10, 0.26, 0.62 }, tab = { 0.10, 0.21, 0.46 }, tabOn = { 0.20, 0.38, 0.78 } },
    Horde = { accent = { 0.86, 0.22, 0.16 }, gold = { 0.88, 0.68, 0.38 }, bg = { 0.10, 0.045, 0.04, 0.97 },
        panel = { 0.15, 0.075, 0.065, 1 }, crest = "CrestHorde", book = "BookHorde",
        heading = { 0.58, 0.10, 0.08 }, tab = { 0.40, 0.08, 0.07 }, tabOn = { 0.70, 0.16, 0.12 } },
}
function W.Theme() return W.THEMES[ns.faction] or W.THEMES.Alliance end

local TPL = BackdropTemplateMixin and "BackdropTemplate" or nil
function W.Frame(parent, name)
    return CreateFrame("Frame", name, parent, TPL)
end
function W.Skin(f, bg, border)
    f:SetBackdrop({ bgFile = W8, edgeFile = W8, edgeSize = 1 })
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    local b = border or { 1, 1, 1, 0.08 }
    f:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end
function W.Text(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", W.Font(size))
    if r then fs:SetTextColor(r, g, b) end
    fs:SetJustifyH("LEFT")
    return fs
end

function W.Button(parent, label, w, h)
    local t = W.Theme()
    local b = CreateFrame("Button", nil, parent, TPL)
    b:SetSize(w, h)
    W.Skin(b, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.12 })
    b.text = W.Text(b, 12); b.text:SetPoint("CENTER"); b.text:SetJustifyH("CENTER"); b.text:SetText(label or "")
    function b:SetActive(on)
        self.active = on
        if on then
            self:SetBackdropColor(t.accent[1], t.accent[2], t.accent[3], 0.35)
            self:SetBackdropBorderColor(t.accent[1], t.accent[2], t.accent[3], 1)
        else
            self:SetBackdropColor(1, 1, 1, 0.06); self:SetBackdropBorderColor(1, 1, 1, 0.12)
        end
    end
    b:SetScript("OnEnter", function(self)
        if not self.active then self:SetBackdropColor(1, 1, 1, 0.14) end
        if self.tip then GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(self.tip, 1, 1, 1, 1, true); GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function(self) self:SetActive(self.active); GameTooltip:Hide() end)
    return b
end

function W.Check(parent, getter, setter)
    local t = W.Theme()
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(330, 22)
    c.box = W.Frame(c); c.box:SetSize(16, 16); c.box:SetPoint("LEFT")
    W.Skin(c.box, { 0, 0, 0, 0.4 }, { 1, 1, 1, 0.3 })
    c.tick = c.box:CreateTexture(nil, "OVERLAY")
    at(c.tick, "TOPLEFT", 3, -3); at(c.tick, "BOTTOMRIGHT", -3, 3)
    wash(c.tick, t.accent[1], t.accent[2], t.accent[3], 1)
    c.label = W.Text(c, 13); c.label:SetPoint("LEFT", c.box, "RIGHT", 8, 0)
    function c:Refresh() self.tick:SetShown(getter() and true or false) end
    c:SetScript("OnClick", function(self) setter(not getter()); self:Refresh() end)
    c:SetScript("OnEnter", function(self) self.box:SetBackdropBorderColor(t.accent[1], t.accent[2], t.accent[3], 1) end)
    c:SetScript("OnLeave", function(self) self.box:SetBackdropBorderColor(1, 1, 1, 0.3) end)
    c:Refresh()
    return c
end

function W.Slider(parent, min, max, step, getter, setter, fmt)
    local t = W.Theme()
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL"); s:SetSize(220, 16)
    s:SetMinMaxValues(min, max); s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(4); wash(track, 1, 1, 1, 0.15)
    s:SetThumbTexture(W8)
    local th = s:GetThumbTexture(); th:SetSize(10, 16); th:SetVertexColor(t.accent[1], t.accent[2], t.accent[3])
    s.val = W.Text(s, 12); s.val:SetPoint("LEFT", s, "RIGHT", 10, 0)
    s.ready = false
    s:SetScript("OnValueChanged", function(self, v)
        if self.ready then setter(v) end
        self.val:SetText((fmt or "%.0f"):format(v))
    end)
    function s:Refresh() self.ready = false; self:SetValue(getter()); self.ready = true end
    s:Refresh()
    return s
end

function W.Scroll(parent, width, height)
    local t = W.Theme()
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetSize(width, height)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(width, 1)
    sf:SetScrollChild(content)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL"); bar:SetSize(6, height)
    bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, 0)
    bar:SetMinMaxValues(0, 1); bar:SetValue(0)
    local tr = bar:CreateTexture(nil, "BACKGROUND"); tr:SetAllPoints(); wash(tr, 1, 1, 1, 0.07)
    bar:SetThumbTexture(W8)
    local th = bar:GetThumbTexture(); th:SetSize(6, 40); th:SetVertexColor(t.accent[1], t.accent[2], t.accent[3], 0.8)
    sf:SetScript("OnScrollRangeChanged", function(_, _, yr)
        yr = yr or 0
        bar:SetMinMaxValues(0, math.max(yr, 0)); bar:SetShown(yr > 0)
    end)
    sf:SetScript("OnVerticalScroll", function(_, off) bar:SetValue(off) end)
    bar:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d)
        local cur, max = self:GetVerticalScroll(), self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - d * 44)))
    end)
    return sf, content
end

function W.EditBox(parent, w, h, placeholder)
    local e = CreateFrame("EditBox", nil, parent, TPL)
    e:SetSize(w, h); e:SetAutoFocus(false); e:SetFontObject(W.Font(12))
    e:SetTextInsets(8, 8, 0, 0)
    W.Skin(e, { 0, 0, 0, 0.35 }, { 1, 1, 1, 0.12 })
    e.hint = W.Text(e, 12, 0.55, 0.55, 0.55); at(e.hint, "LEFT", 8, 0); e.hint:SetText(placeholder or "")
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:HookScript("OnTextChanged", function(self) self.hint:SetShown(self:GetText() == "") end)
    return e
end
