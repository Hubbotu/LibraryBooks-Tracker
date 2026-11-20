local _, ns = ...
local W = ns.W
local UI = {}
ns.UI = UI

local TPL = BackdropTemplateMixin and "BackdropTemplate" or nil
-- Small layout helpers (keep call sites short).
local function at(frame, point, x, y) frame:SetPoint(point, x, y) end
local function wash(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a) end
local function hideTip() GameTooltip:Hide() end

local TABS = { { "ek", "tab_ek" }, { "kal", "tab_kal" }, { "diff", "tab_diff" }, { "quests", "tab_quests" }, { "settings", "tab_settings" } }
local INK, INK2 = { 0.20, 0.13, 0.07 }, { 0.40, 0.29, 0.17 }
local BOOK_W, BOOK_H, TAB_H = 960, 592, 40
local TEX_V = 631 / 1024 -- visible height fraction of the 1024x1024 texture
local PAGE_L, PAGE_R, PAGE_W, PAGE_H, PAGE_TOP = 52, 502, 395, 480, 52

local frame, book, tabBtns, tabs = nil, nil, {}, {}
local current, selectedQuest = "ek", 1
local locFilter = nil -- map ID of the chosen location (nil = all)
local HERE = { 0.96, 0.78, 0.25 } -- highlight of uncollected books in the current location

-- Books of a tab, narrowed by the location filter, uncollected books of the current location first.
local function FilteredBooks(cont)
    local list = {}
    for _, b in ipairs(ns.books) do
        if (not cont or b.cont == cont) and (not locFilter or ns.InZone(b, locFilter))
            and not (ns.db.listHideDone and ns.IsCollected(b)) then list[#list + 1] = b end
    end
    return ns.OrderLocalFirst(list)
end

-- Small helpers ------------------------------------------------------------------
local function Ink(fs, c, a) c = c or INK; fs:SetTextColor(c[1], c[2], c[3], a or 1); return fs end
local function Heading() return W.Theme().heading end
local function Text(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", W.Font(size))
    Ink(fs, color); fs:SetJustifyH(justify or "LEFT")
    return fs
end
local function Line(parent, x, y, w, h, a)
    local t = parent:CreateTexture(nil, "ARTWORK")
    wash(t, INK[1], INK[2], INK[3], a or 0.35)
    t:SetPoint("TOPLEFT", x, -y); t:SetSize(w, h or 1)
    return t
end
local function NewPage(x)
    local p = CreateFrame("Frame", nil, book)
    p:SetPoint("TOPLEFT", book, "TOPLEFT", x, -PAGE_TOP); p:SetSize(PAGE_W, PAGE_H)
    p:Hide()
    return p
end
local function PageHeader(page, onRight)
    local h = {}
    h.crest = page:CreateTexture(nil, "ARTWORK")
    h.crest:SetTexture(ns.TEX .. W.Theme().crest); h.crest:SetSize(30, 30)
    h.title = Text(page, 18, Heading())
    h.line = Line(page, 0, 36, PAGE_W, 2, 0.5)
    h.side = Text(page, 12, INK2, "RIGHT")
    if onRight then
        at(h.crest, "TOPRIGHT", 0, 0); at(h.title, "TOPRIGHT", -38, -5); h.title:SetJustifyH("RIGHT")
        at(h.side, "TOPLEFT", 0, -9)
    else
        at(h.crest, "TOPLEFT", 0, 0); at(h.title, "TOPLEFT", 38, -5)
        at(h.side, "TOPRIGHT", 0, -9)
    end
    if onRight then
        local bar = CreateFrame("StatusBar", nil, page, TPL)
        at(bar, "TOPLEFT", 0, -7); bar:SetSize(PAGE_W - 46, 18)
        bar:SetStatusBarTexture(W.W8)
        bar:SetBackdrop({ bgFile = W.W8, edgeFile = W.W8, edgeSize = 1 })
        bar.text = bar:CreateFontString(nil, "OVERLAY", "LibraryBooksFontBar"); bar.text:SetPoint("CENTER")
        bar:Hide()
        h.bar = bar
    end
    return h
end

-- Progress bar in a right-page header (replaces the repeated tab title).
local function SetHeaderBar(h, n, total, dark)
    local bar = h.bar
    h.title:Hide(); bar:Show()
    local hd = Heading()
    if dark then
        bar:SetBackdropColor(1, 1, 1, 0.08); bar:SetBackdropBorderColor(0.96, 0.80, 0.40, 0.7)
        bar:SetStatusBarColor(0.96, 0.80, 0.40, 0.85)
    else
        bar:SetBackdropColor(INK[1], INK[2], INK[3], 0.18); bar:SetBackdropBorderColor(INK[1], INK[2], INK[3], 0.7)
        bar:SetStatusBarColor(hd[1], hd[2], hd[3], 0.9)
    end
    bar:SetMinMaxValues(0, math.max(total, 1)); bar:SetValue(n)
    bar.text:SetText(ns.S("progress", n, total))
end

local function TabProgress(cont)
    local n, total = 0, 0
    for _, b in ipairs(ns.books) do
        if not cont or b.cont == cont then
            total = total + 1
            if ns.IsCollected(b) then n = n + 1 end
        end
    end
    return n, total
end

local function InkSkin(f, active)
    local h = Heading()
    f:SetBackdrop({ bgFile = W.W8, edgeFile = W.W8, edgeSize = 1 })
    if active then
        f:SetBackdropColor(h[1], h[2], h[3], 0.22); f:SetBackdropBorderColor(h[1], h[2], h[3], 0.95)
    else
        f:SetBackdropColor(INK[1], INK[2], INK[3], 0.07); f:SetBackdropBorderColor(INK[1], INK[2], INK[3], 0.35)
    end
end
local function InkButton(parent, w, h)
    local b = CreateFrame("Button", nil, parent, TPL)
    b:SetSize(w, h); InkSkin(b, false)
    b.text = Text(b, 13); b.text:SetPoint("CENTER"); b.text:SetJustifyH("CENTER")
    function b:SetActive(on) self.active = on; InkSkin(self, on) end
    b:SetScript("OnEnter", function(self) if not self.active then self:SetBackdropColor(INK[1], INK[2], INK[3], 0.16) end end)
    b:SetScript("OnLeave", function(self) self:SetActive(self.active) end)
    return b
end
local function InkCheck(parent, getter, setter)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(PAGE_W, 24)
    c.box = CreateFrame("Frame", nil, c, TPL); c.box:SetSize(16, 16); c.box:SetPoint("LEFT")
    c.box:SetBackdrop({ bgFile = W.W8, edgeFile = W.W8, edgeSize = 1 })
    c.box:SetBackdropColor(1, 1, 1, 0.35); c.box:SetBackdropBorderColor(INK[1], INK[2], INK[3], 0.8)
    c.tick = c.box:CreateTexture(nil, "OVERLAY"); at(c.tick, "TOPLEFT", 3, -3); at(c.tick, "BOTTOMRIGHT", -3, 3)
    local h = Heading(); wash(c.tick, h[1], h[2], h[3], 1)
    c.label = Text(c, 13); c.label:SetPoint("LEFT", c.box, "RIGHT", 8, 0)
    function c:Refresh() self.tick:SetShown(getter() and true or false) end
    c:SetScript("OnClick", function(self) setter(not getter()); self:Refresh() end)
    c:Refresh()
    return c
end
local function InkSlider(parent, min, max, step, getter, setter, fmt)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL"); s:SetSize(260, 16)
    s:SetMinMaxValues(min, max); s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local tr = s:CreateTexture(nil, "BACKGROUND"); tr:SetPoint("LEFT"); tr:SetPoint("RIGHT"); tr:SetHeight(3)
    wash(tr, INK[1], INK[2], INK[3], 0.35)
    s:SetThumbTexture(W.W8)
    local th = s:GetThumbTexture(); th:SetSize(10, 16); local h = Heading(); th:SetVertexColor(h[1], h[2], h[3])
    s.val = Text(s, 12, INK2); s.val:SetPoint("LEFT", s, "RIGHT", 10, 0)
    s.ready = false
    s:SetScript("OnValueChanged", function(self, v)
        if self.ready then setter(v) end
        self.val:SetText((fmt or "%.0f"):format(v))
    end)
    function s:Refresh() self.ready = false; self:SetValue(getter()); self.ready = true end
    s:Refresh()
    return s
end

local function TierTag(book_, loc)
    local a = ns.Assess(book_, loc)
    local c = ns.TierColors[a.tier]
    return a, ns.Hex(c[1], c[2], c[3]) .. ns.S("tier_" .. a.tier) .. "|r"
end

local function BookTooltip(owner, b)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    ns.FillTooltip(GameTooltip, b, (ns.NearestLoc(b)), true)
    GameTooltip:Show()
end

-- Collection pages (Eastern Kingdoms / Kalimdor) ------------------------------------
local CELL_W, ROW_H, COLS = 131, 80, 3

local function MakeCell(parent)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(CELL_W, ROW_H)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.hl = c:CreateTexture(nil, "BACKGROUND"); c.hl:SetAllPoints(); wash(c.hl, INK[1], INK[2], INK[3], 0)
    c.border = c:CreateTexture(nil, "BORDER"); c.border:SetSize(42, 42); at(c.border, "TOP", 0, -2)
    c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetSize(36, 36); c.icon:SetPoint("CENTER", c.border, "CENTER")
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.title = Text(c, 10, INK, "CENTER"); c.title:SetPoint("TOP", c.border, "BOTTOM", 0, -2)
    c.title:SetSize(CELL_W - 8, 24); c.title:SetJustifyV("TOP"); c.title:SetWordWrap(true)
    c.zone = Text(c, 10, INK2, "CENTER"); at(c.zone, "BOTTOM", 0, 2); c.zone:SetWidth(CELL_W - 8); c.zone:SetWordWrap(false)
    function c:Shade(hover)
        if self.here then wash(self.hl, HERE[1], HERE[2], HERE[3], hover and 0.40 or 0.26)
        else wash(self.hl, INK[1], INK[2], INK[3], hover and 0.10 or 0) end
    end
    c:SetScript("OnEnter", function(self) self:Shade(true); BookTooltip(self, self.book) end)
    c:SetScript("OnLeave", function(self) self:Shade(false); GameTooltip:Hide() end)
    c:SetScript("OnClick", function(self, btn)
        local loc = ns.NearestLoc(self.book)
        if btn == "RightButton" then ns.OpenMap(loc.map); ns.Ping(self.book, loc)
        elseif IsShiftKeyDown() then if not ns.ToggleManual(self.book) then ns.Print(ns.S("msg_quest")) end
        else ns.SetWaypoint(self.book, loc) end
    end)
    return c
end

local function UpdateCell(c, b)
    c.book = b
    local loc = ns.BestLoc(b)
    local done = ns.IsCollected(b)
    local col = ns.RatingColors[ns.Rating(b, loc)]
    c.icon:SetTexture(ns.BookIcon(b))
    c.icon:SetDesaturated(done)
    c.icon:SetAlpha(done and 0.75 or 1)
    wash(c.border, col[1], col[2], col[3], 1)
    c.title:SetText(ns.Title(b)); Ink(c.title, done and INK2 or INK)
    c.zone:SetText(ns.ZoneName(loc.map))
    c.here = ns.IsLocalBook(b)
    c:Shade(false)
end

local function BuildCollection(contFilter, titleKey)
    local t = { left = NewPage(PAGE_L), right = NewPage(PAGE_R), cells = {}, lines = {} }
    t.lh = PageHeader(t.left, false); t.rh = PageHeader(t.right, true)
    local function Cell(i, page)
        local c = t.cells[i]
        if not c then c = MakeCell(page); t.cells[i] = c end
        if c:GetParent() ~= page then c:SetParent(page) end
        return c
    end
    t.legend = {}
    for i, key in ipairs({ "green", "yellow", "red", "gray" }) do
        local sw = t.left:CreateTexture(nil, "ARTWORK"); sw:SetSize(10, 10)
        local col = ns.RatingColors[key]; wash(sw, col[1], col[2], col[3], 1)
        local row, colN = math.floor((i - 1) / 2), (i - 1) % 2
        sw:SetPoint("TOPLEFT", t.left, "TOPLEFT", colN * (PAGE_W / 2), -(PAGE_H - 34 + row * 16))
        local fs = Text(t.left, 10, INK2); fs:SetPoint("LEFT", sw, "RIGHT", 5, 0); fs:SetWidth(PAGE_W / 2 - 20); fs:SetWordWrap(false)
        t.legend[i] = { fs = fs, key = "leg_" .. key }
    end
    t.empty = Text(t.left, 13, INK2, "CENTER"); at(t.empty, "TOP", 0, -160); t.empty:SetWidth(PAGE_W)
    -- legend of the map icon for the book turn-in point
    t.tiIcon = t.right:CreateTexture(nil, "ARTWORK"); t.tiIcon:SetSize(18, 18); t.tiIcon:SetTexture(ns.TEX .. "TurnIn")
    t.tiIcon:SetPoint("TOPLEFT", t.right, "TOPLEFT", 0, -(PAGE_H - 36))
    t.tiText = Text(t.right, 10, INK2); t.tiText:SetPoint("TOPLEFT", t.tiIcon, "TOPRIGHT", 6, 1)
    t.tiText:SetWidth(PAGE_W - 26); t.tiText:SetHeight(28); t.tiText:SetJustifyV("TOP"); t.tiText:SetWordWrap(true)
    local nlines = 0
    local function AddLine(page, x, y, w, h)
        nlines = nlines + 1
        local ln = t.lines[nlines]
        if not ln then ln = page:CreateTexture(nil, "ARTWORK"); wash(ln, INK[1], INK[2], INK[3], 0.22); t.lines[nlines] = ln end
        ln:SetParent(page); ln:ClearAllPoints(); ln:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y); ln:SetSize(w, h); ln:Show()
    end
    function t.refresh()
        local list = FilteredBooks(contFilter)
        local half = math.ceil(#list / 2)
        t.empty:SetText(ns.S("empty")); t.empty:SetShown(#list == 0)
        t.tiText:SetText(ns.S("leg_turnin")); t.tiIcon:SetShown(ns.TurnInSpot() ~= nil); t.tiText:SetShown(ns.TurnInSpot() ~= nil)
        t.lh.title:SetText(ns.S(titleKey))
        t.lh.side:SetText(ns.S("progress", ns.CountCollected(), #ns.books)); t.rh.side:SetText("")
        SetHeaderBar(t.rh, TabProgress(contFilter))
        for _, l in ipairs(t.legend) do l.fs:SetText(ns.S(l.key)) end
        nlines = 0
        for _, ln in ipairs(t.lines) do ln:Hide() end
        for i, b in ipairs(list) do
            local page, idx = t.left, i
            if i > half then page, idx = t.right, i - half end
            local c = Cell(i, page)
            local col, row = (idx - 1) % COLS, math.floor((idx - 1) / COLS)
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", page, "TOPLEFT", col * CELL_W, -(44 + row * ROW_H))
            UpdateCell(c, b); c:Show()
        end
        for i = #list + 1, #t.cells do t.cells[i]:Hide() end
        for _, pg in ipairs({ { t.left, half }, { t.right, #list - half } }) do
            local rows = math.ceil(pg[2] / COLS)
            for r = 1, rows - 1 do AddLine(pg[1], 0, 44 + r * ROW_H - 1, PAGE_W, 1) end
            for cc = 1, COLS - 1 do AddLine(pg[1], cc * CELL_W - 1, 48, 1, rows * ROW_H - 8) end
        end
    end
    return t
end

-- Difficulty page ---------------------------------------------------------------
local DROW = 20
local function BuildDifficulty()
    local t = { left = NewPage(PAGE_L), right = NewPage(PAGE_R), rows = {} }
    t.lh = PageHeader(t.left, false); t.rh = PageHeader(t.right, true)
    local CREAM, GOLD, DIM = { 0.94, 0.89, 0.78 }, { 0.96, 0.80, 0.40 }, { 0.72, 0.66, 0.55 }
    for _, pg in ipairs({ t.left, t.right }) do
        pg.bg = pg:CreateTexture(nil, "BACKGROUND"); wash(pg.bg, 0.06, 0.045, 0.035, 0.90)
        at(pg.bg, "TOPLEFT", -10, 6); at(pg.bg, "BOTTOMRIGHT", 10, -6)
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
            local ln = pg:CreateTexture(nil, "BACKGROUND", nil, 1); wash(ln, GOLD[1], GOLD[2], GOLD[3], 0.55)
            ln:SetPoint(e[1], pg.bg, e[1]); ln:SetPoint(e[2], pg.bg, e[2])
            if e[3] then ln:SetHeight(1) else ln:SetWidth(1) end
        end
        pg.c1 = Text(pg, 10, DIM); at(pg.c1, "TOPLEFT", 0, -42); pg.c1:SetText("#")
        pg.c2 = Text(pg, 10, DIM); at(pg.c2, "TOPLEFT", 26, -42)
        pg.c3 = Text(pg, 10, DIM, "CENTER"); at(pg.c3, "TOPLEFT", 218, -42); pg.c3:SetWidth(50)
        pg.c4 = Text(pg, 10, DIM, "RIGHT"); at(pg.c4, "TOPLEFT", 270, -42); pg.c4:SetWidth(125)
        local hl = pg:CreateTexture(nil, "ARTWORK"); wash(hl, GOLD[1], GOLD[2], GOLD[3], 0.5)
        at(hl, "TOPLEFT", 0, -56); hl:SetSize(PAGE_W, 1)
    end
    for _, h in ipairs({ t.lh, t.rh }) do
        Ink(h.title, GOLD); Ink(h.side, CREAM); wash(h.line, GOLD[1], GOLD[2], GOLD[3], 0.6)
    end
    local function Row(i, page)
        local r = t.rows[i]
        if not r then
            r = CreateFrame("Button", nil, page)
            r:SetSize(PAGE_W, DROW)
            r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); wash(r.hl, 1, 1, 1, 0)
            r.num = Text(r, 11, DIM); at(r.num, "LEFT", 0, 0); r.num:SetWidth(24)
            r.title = Text(r, 11, CREAM); at(r.title, "LEFT", 26, 0); r.title:SetWidth(188); r.title:SetWordWrap(false)
            r.lv = Text(r, 11, CREAM, "CENTER"); at(r.lv, "LEFT", 218, 0); r.lv:SetWidth(50)
            r.rate = Text(r, 11, CREAM, "RIGHT"); at(r.rate, "LEFT", 270, 0); r.rate:SetWidth(125); r.rate:SetWordWrap(false)
            function r:Shade(hover)
                if self.here then wash(self.hl, HERE[1], HERE[2], HERE[3], hover and 0.32 or 0.18)
                else wash(self.hl, 1, 1, 1, hover and 0.12 or 0) end
            end
            r.sep = r:CreateTexture(nil, "ARTWORK"); wash(r.sep, 1, 1, 1, 0.10)
            r.sep:SetPoint("BOTTOMLEFT"); r.sep:SetPoint("BOTTOMRIGHT"); r.sep:SetHeight(1)
            r:SetScript("OnEnter", function(self) self:Shade(true); BookTooltip(self, self.book) end)
            r:SetScript("OnLeave", function(self) self:Shade(false); GameTooltip:Hide() end)
            r:RegisterForClicks("LeftButtonUp")
            r:SetScript("OnClick", function(self) ns.SetWaypoint(self.book, ns.NearestLoc(self.book)) end)
            t.rows[i] = r
        end
        if r:GetParent() ~= page then r:SetParent(page) end
        return r
    end
    function t.refresh()
        local level = UnitLevel("player") or 1
        t.lh.title:SetText(ns.S("tab_diff"))
        SetHeaderBar(t.rh, ns.CountCollected(), #ns.books, true)
        t.lh.side:SetText(ns.S("your_level", level)); t.rh.side:SetText("")
        for _, pg in ipairs({ t.left, t.right }) do
            pg.c2:SetText(ns.S("col_book")); pg.c3:SetText(ns.S("col_lv")); pg.c4:SetText(ns.S("col_rating"))
        end
        local list = FilteredBooks(nil)
        local half = math.ceil(#list / 2)
        for i = #list + 1, #t.rows do t.rows[i]:Hide() end
        for i, b in ipairs(list) do
            local page, idx = t.left, i
            if i > half then page, idx = t.right, i - half end
            local r = Row(i, page)
            r.book = b
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(58 + (idx - 1) * DROW))
            local loc = ns.BestLoc(b)
            local a, tag = TierTag(b, loc)
            r.num:SetText(b.order)
            r.here = ns.IsLocalBook(b); r:Shade(false)
            r.title:SetText(ns.Title(b))
            local done = ns.IsCollected(b)
            Ink(r.title, done and { 0.50, 0.85, 0.58 } or CREAM)
            r.lv:SetText(ns.LevelText(a.zone, level))
            r.rate:SetText(ns.S("mode_" .. b.mode) .. (b.hard and " *" or "") .. " · " .. tag)
            r:Show()
        end
    end
    return t
end

-- Quests page -----------------------------------------------------------------------
local function QuestStatus(q)
    local level = UnitLevel("player") or 1
    local n = ns.CountCollected()
    if ns.IsQuestDone(q.id) then return "done", n end
    if level < q.level then return "locked", n end
    if n >= q.need then return "ready", n end
    return "avail", n
end

local function ItemData(id)
    local name, quality, _
    if C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(id) end
    if not name and GetItemInfo then name, _, quality = GetItemInfo(id) end
    if C_Item and C_Item.GetItemQualityByID and not quality then quality = C_Item.GetItemQualityByID(id) end
    local icon
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if instant then icon = select(5, instant(id)) end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name, quality, icon
end

local STATUS_ICON = {
    avail = "Interface\\GossipFrame\\AvailableQuestIcon", ready = "Interface\\GossipFrame\\ActiveQuestIcon",
    locked = "Interface\\GossipFrame\\IncompleteQuestIcon", done = "BookPinDone",
}

local function BuildQuests()
    local t = { left = NewPage(PAGE_L), right = NewPage(PAGE_R), entries = {}, rewards = {} }
    t.lh = PageHeader(t.left, false); t.rh = PageHeader(t.right, true)
    t.total = Text(t.left, 12, INK2); at(t.total, "TOPLEFT", 0, -46)
    for i, q in ipairs(ns.quests) do
        local e = CreateFrame("Button", nil, t.left, TPL)
        e:SetSize(PAGE_W, 72); e:SetPoint("TOPLEFT", 0, -72 - (i - 1) * 80)
        InkSkin(e, false)
        e.icon = e:CreateTexture(nil, "ARTWORK"); e.icon:SetSize(30, 30); at(e.icon, "LEFT", 10, 0)
        e.title = Text(e, 14); at(e.title, "TOPLEFT", 52, -10); e.title:SetWidth(320)
        e.sub = Text(e, 11, INK2); e.sub:SetPoint("TOPLEFT", e.title, "BOTTOMLEFT", 0, -3); e.sub:SetWidth(320)
        e.barBg = e:CreateTexture(nil, "ARTWORK"); wash(e.barBg, INK[1], INK[2], INK[3], 0.18)
        at(e.barBg, "BOTTOMLEFT", 52, 10); e.barBg:SetSize(320, 8)
        e.bar = e:CreateTexture(nil, "OVERLAY"); at(e.bar, "BOTTOMLEFT", 52, 10); e.bar:SetHeight(8)
        e.q = q
        e:SetScript("OnClick", function() selectedQuest = i; UI.Refresh() end)
        t.entries[i] = e
    end
    -- turn-in point of the player's faction
    local box = CreateFrame("Frame", nil, t.left, TPL)
    box:SetSize(PAGE_W, 76); box:SetPoint("TOPLEFT", 0, -(72 + #ns.quests * 80)); InkSkin(box, false)
    box.icon = box:CreateTexture(nil, "ARTWORK"); box.icon:SetSize(38, 38); at(box.icon, "LEFT", 10, 0)
    box.icon:SetTexture(ns.TEX .. "TurnIn")
    box.title = Text(box, 13, Heading()); at(box.title, "TOPLEFT", 58, -8); box.title:SetWidth(220)
    box.where = Text(box, 11, INK2); at(box.where, "TOPLEFT", 58, -25); box.where:SetWidth(220)
    box.desc = Text(box, 10); at(box.desc, "TOPLEFT", 58, -41); box.desc:SetWidth(220); box.desc:SetHeight(30)
    box.desc:SetJustifyV("TOP"); box.desc:SetWordWrap(true)
    box.btnWay = InkButton(box, 96, 26); at(box.btnWay, "TOPRIGHT", -8, -10)
    box.btnMap = InkButton(box, 96, 26); at(box.btnMap, "TOPRIGHT", -8, -40)
    box.btnWay:SetScript("OnClick", function() ns.SetTurnInWaypoint() end)
    box.btnMap:SetScript("OnClick", function()
        local sp = ns.TurnInSpot(); if sp then ns.OpenMap(sp.map); ns.Ping({ id = "turnin" }, sp) end
    end)
    t.turn = box
    -- detail (right page)
    local g = t.right
    t.dTitle = Text(g, 18, Heading()); at(t.dTitle, "TOPLEFT", 0, -50); t.dTitle:SetWidth(PAGE_W)
    t.dStatus = Text(g, 12, INK2); t.dStatus:SetPoint("TOPLEFT", t.dTitle, "BOTTOMLEFT", 0, -4)
    t.hObj = Text(g, 13, Heading()); at(t.hObj, "TOPLEFT", 0, -106)
    Line(g, 0, 124, PAGE_W, 1, 0.3)
    t.dObj = Text(g, 13); at(t.dObj, "TOPLEFT", 8, -132); t.dObj:SetWidth(PAGE_W - 8)
    t.hComp = Text(g, 13, Heading()); at(t.hComp, "TOPLEFT", 0, -166)
    Line(g, 0, 184, PAGE_W, 1, 0.3)
    t.dText = Text(g, 13); at(t.dText, "TOPLEFT", 0, -192); t.dText:SetWidth(PAGE_W)
    t.dText:SetJustifyV("TOP"); t.dText:SetWordWrap(true); t.dText:SetSpacing(2)
    t.hRew = Text(g, 13, Heading()); at(t.hRew, "TOPLEFT", 0, -270)
    Line(g, 0, 288, PAGE_W, 1, 0.3)
    t.dChoose = Text(g, 12, INK2); at(t.dChoose, "TOPLEFT", 0, -296); t.dChoose:SetWidth(PAGE_W)
    t.dChoose:SetWordWrap(true)
    t.qid = Text(g, 10, INK2, "RIGHT"); at(t.qid, "BOTTOMRIGHT", 0, 2)
    for i = 1, 3 do
        local r = CreateFrame("Button", nil, g, TPL)
        r:SetSize(PAGE_W, 44); r:SetPoint("TOPLEFT", 0, -322 - (i - 1) * 50)
        InkSkin(r, false)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(34, 34); at(r.icon, "LEFT", 6, 0)
        r.name = Text(r, 13); r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0); r.name:SetWidth(320)
        r:SetScript("OnEnter", function(self)
            if self.itemID then GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetHyperlink("item:" .. self.itemID); GameTooltip:Show() end
        end)
        r:SetScript("OnLeave", hideTip)
        t.rewards[i] = r
    end
    function t.refresh()
        t.lh.title:SetText(ns.S("q_head")); t.rh.title:SetText(ns.S("q_head"))
        t.lh.side:SetText(ns.S("your_level", UnitLevel("player") or 1)); t.rh.side:SetText("")
        t.total:SetText(ns.S("q_books", ns.CountCollected(), #ns.books))
        do
            local sp = ns.TurnInSpot()
            t.turn:SetShown(sp ~= nil)
            if sp then
                t.turn.title:SetText(ns.S("turn_title"))
                t.turn.where:SetText(ns.S("turn_where", ns.ZoneName(sp.map), sp.x, sp.y))
                t.turn.desc:SetText(ns.S("turn_desc"))
                t.turn.btnWay.text:SetText(ns.S("btnWay")); t.turn.btnMap.text:SetText(ns.S("btnMap"))
            end
        end
        for i, e in ipairs(t.entries) do
            local q = e.q
            local st, n = QuestStatus(q)
            if st == "done" then e.icon:SetTexture(ns.TEX .. "BookPinDone") else e.icon:SetTexture(STATUS_ICON[st]) end
            e.icon:SetDesaturated(st == "locked")
            e.title:SetText("[" .. q.level .. "] " .. ns.S("q_title_" .. q.key))
            Ink(e.title, st == "locked" and INK2 or (st == "done" and { 0.12, 0.38, 0.18 } or INK))
            local label = ns.S("q_" .. (st == "locked" and "locked" or st == "avail" and "avail" or st == "ready" and "ready" or "done"), q.level)
            e.sub:SetText(label .. "  ·  " .. math.min(n, q.need) .. "/" .. q.need)
            e.barBg:SetWidth(320)
            local frac = math.min(1, n / q.need)
            e.bar:SetWidth(math.max(1, 320 * frac))
            local h = Heading(); wash(e.bar, h[1], h[2], h[3], 0.85)
            e.bar:SetShown(frac > 0)
            InkSkin(e, i == selectedQuest)
        end
        local q = ns.quests[selectedQuest]
        local st, n = QuestStatus(q)
        t.dTitle:SetText(ns.S("q_title_" .. q.key))
        t.dStatus:SetText(ns.S("q_level", q.level) .. "  ·  " .. ns.S(st == "locked" and "q_locked" or st == "avail" and "q_avail" or st == "ready" and "q_ready" or "q_done", q.level))
        t.hObj:SetText(ns.S("q_objectives"))
        local oc = n >= q.need and "|cff1f6b2e" or "|cff33210f"
        t.dObj:SetText(oc .. "• " .. ns.S("q_objective", q.need, math.min(n, q.need), q.need) .. "|r")
        t.hComp:SetText(ns.S("q_completion"))
        t.dText:SetText(ns.S("q_text_" .. q.key))
        t.hRew:SetText(ns.S("q_rewards"))
        t.dChoose:SetText(ns.S("q_choose"))
        t.qid:SetText(ns.S("q_id", q.id))
        for i, r in ipairs(t.rewards) do
            local id = q.items[i]
            if id then
                local name, quality, icon = ItemData(id)
                r.itemID = id
                r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                r.name:SetText(name or ("item:" .. id))
                local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                if qc then r.name:SetTextColor(qc.r * 0.75, qc.g * 0.75, qc.b * 0.75) else Ink(r.name) end
                r:Show()
            else r:Hide() end
        end
    end
    return t
end

-- Settings page ---------------------------------------------------------------------
local function BuildSettings()
    local t = { left = NewPage(PAGE_L), right = NewPage(PAGE_R), checks = {}, sliders = {}, langBtns = {}, radios = {} }
    t.lh = PageHeader(t.left, false); t.rh = PageHeader(t.right, true)
    local db = ns.db
    local L, R = t.left, t.right
    t.hLang = Text(L, 13, Heading()); at(t.hLang, "TOPLEFT", 0, -52)
    Line(L, 0, 70, PAGE_W, 1, 0.3)
    for i, code in ipairs(ns.langs) do
        local b = InkButton(L, PAGE_W, 30)
        b:SetPoint("TOPLEFT", 0, -80 - (i - 1) * 36)
        b.text:SetText(ns.langNames[code])
        b:SetScript("OnClick", function() ns.SetLang(code) end)
        t.langBtns[code] = b
    end
    t.hWay = Text(L, 13, Heading()); at(t.hWay, "TOPLEFT", 0, -208)
    Line(L, 0, 226, PAGE_W, 1, 0.3)
    local modes = { { "tomtom", "set_wp_tomtom", ns.HasTomTom }, { "blizz", "set_wp_blizz", ns.HasBlizzPin } }
    for i, m in ipairs(modes) do
        local b = InkButton(L, PAGE_W, 30)
        b:SetPoint("TOPLEFT", 0, -236 - (i - 1) * 36)
        b:SetScript("OnClick", function() db.wpMode = m[1]; UI.Refresh() end)
        b.mode = m
        t.radios[i] = b
    end

    t.ver = Text(L, 11, INK2); at(t.ver, "BOTTOMLEFT", 0, 0)
    t.hPins = Text(R, 13, Heading()); at(t.hPins, "TOPLEFT", 0, -52)
    Line(R, 0, 70, PAGE_W, 1, 0.3)
    local y = 80
    local function Check(key, get, set)
        local c = InkCheck(R, get, set); c:SetPoint("TOPLEFT", 0, -y); y = y + 24
        c.key = key; t.checks[#t.checks + 1] = c
    end
    Check("set_world", function() return db.showWorld end, function(v) db.showWorld = v; ns.Changed() end)
    Check("set_mini", function() return db.showMini end, function(v) db.showMini = v; ns.Changed() end)
    Check("set_cont", function() return db.showContinent end, function(v) db.showContinent = v; ns.Changed() end)
    Check("set_unconf", function() return db.showUnconfirmed end, function(v) db.showUnconfirmed = v; ns.Changed() end)
    Check("set_hidefound", function() return db.listHideDone end, function(v) db.listHideDone = v; ns.Changed() end)
    Check("set_outline", function() return db.mapOutline end, function(v) db.mapOutline = v; ns.Changed() end)
    Check("set_turnin", function() return db.showTurnIn end, function(v) db.showTurnIn = v; ns.Changed() end)
    Check("set_localtip", function() return db.showLocalTip end, function(v) db.showLocalTip = v end)
    Check("set_warn", function() return db.warnings end, function(v) db.warnings = v; ns.Changed() end)
    Check("set_button", function() return not db.minimapButton.hide end, function(v) db.minimapButton.hide = not v; ns.MinimapButton.Update() end)
    y = y + 4
    local function Slider(key, min, max, step, get, set, fmt)
        local fs = Text(R, 12, INK2); fs:SetPoint("TOPLEFT", 0, -y)
        local s = InkSlider(R, min, max, step, get, set, fmt); s:SetPoint("TOPLEFT", 0, -y - 20); y = y + 50
        s.fs, s.key = fs, key; t.sliders[#t.sliders + 1] = s
    end
    Slider("set_size", 12, 40, 1, function() return db.iconSize end, function(v) db.iconSize = v; ns.Changed() end)
    Slider("set_opacity", 0.3, 1, 0.05, function() return db.opacity end, function(v) db.opacity = v; ns.Changed() end, "%.2f")
    Slider("set_scale", 0.8, 1.3, 0.05, function() return db.uiScale end, function(v) db.uiScale = v; UI.ApplyScale() end, "%.2f")

    function t.refresh()
        t.lh.title:SetText(ns.S("tab_settings")); t.rh.title:SetText(ns.S("tab_settings"))
        t.lh.side:SetText(""); t.rh.side:SetText("")
        t.ver:SetText("Library Books  ·  " .. ns.S("version", ns.version))
        t.hLang:SetText(ns.S("set_lang")); t.hWay:SetText(ns.S("set_waypoints")); t.hPins:SetText(ns.S("set_pins"))
        for code, b in pairs(t.langBtns) do b:SetActive(code == ns.GetLang()) end
        for _, b in ipairs(t.radios) do
            local label = ns.S(b.mode[2])
            local ok = b.mode[3]()
            if not ok then label = label .. "  (" .. ns.S("set_missing_short") .. ")" end
            b.text:SetText((db.wpMode == b.mode[1] and "[x]  " or "[  ]  ") .. label)
            b:SetActive(db.wpMode == b.mode[1]); b:SetAlpha(ok and 1 or 0.55)
        end
        for _, c in ipairs(t.checks) do c.label:SetText(ns.S(c.key)); c:Refresh() end
        for _, s in ipairs(t.sliders) do s.fs:SetText(ns.S(s.key)); s:Refresh() end
    end
    return t
end

-- Window ------------------------------------------------------------------------------
local BUILDERS = {
    ek = function() return BuildCollection(1415, "tab_ek") end,
    kal = function() return BuildCollection(1414, "tab_kal") end,
    diff = BuildDifficulty, quests = BuildQuests, settings = BuildSettings,
}

-- Location filter ---------------------------------------------------------------
local menu
local FILTER_TABS = { ek = 1415, kal = 1414, diff = false }

local function ScopeZones(tab)
    local cont = FILTER_TABS[tab]
    local zones = {}
    for _, b in ipairs(ns.books) do
        if not cont or b.cont == cont then
            for _, loc in ipairs(b.locs) do
                if loc.kind ~= "entrance" then
                    local z = zones[loc.map]
                    if not z then z = { map = loc.map, open = 0 }; zones[loc.map] = z end
                    if not ns.IsCollected(b) then z.open = z.open + 1 end
                end
            end
        end
    end
    local list = {}
    for _, z in pairs(zones) do z.name = ns.ZoneName(z.map); list[#list + 1] = z end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list, zones
end

local function FilterLabel()
    if not locFilter then return ns.S("loc_all") end
    return ns.ZoneName(locFilter)
end

function UI.UpdateFilter()
    local fb = frame and frame.filterBtn
    if not fb then return end
    local usable = FILTER_TABS[current] ~= nil
    fb:SetShown(usable)
    fb.text:SetText(ns.S("loc_label") .. ": " .. FilterLabel())
    fb:SetWidth(math.min(300, math.max(190, fb.text:GetStringWidth() + 44)))
end

local function OpenMenu()
    local th = W.Theme()
    if not menu then
        menu = CreateFrame("Frame", nil, frame, TPL)
        menu:SetFrameStrata("DIALOG"); menu:SetClampedToScreen(true)
        menu:SetBackdrop({ bgFile = W.W8, edgeFile = W.W8, edgeSize = 1 })
        menu:SetBackdropColor(0.06, 0.045, 0.035, 0.97); menu:SetBackdropBorderColor(th.gold[1], th.gold[2], th.gold[3], 0.8)
        menu:SetSize(262, 326)
        menu.sf, menu.content = W.Scroll(menu, 240, 314)
        at(menu.sf, "TOPLEFT", 6, -6)
        menu.rows = {}
        menu:SetScript("OnUpdate", function(self)
            if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
                and not self:IsMouseOver() and not frame.filterBtn:IsMouseOver() then self:Hide() end
        end)
    end
    menu:ClearAllPoints(); menu:SetPoint("TOPRIGHT", frame.filterBtn, "BOTTOMRIGHT", 0, -2)
    local zones, byMap = ScopeZones(current)
    local entries = { { label = ns.S("loc_all"), key = nil, all = true } }
    local cur = ns.CurrentMap()
    if cur and byMap[cur] then entries[#entries + 1] = { label = ns.S("loc_here", byMap[cur].name), key = cur, here = true } end
    for _, z in ipairs(zones) do
        entries[#entries + 1] = { label = z.name .. (z.open > 0 and ("  (" .. z.open .. ")") or ""), key = z.map }
    end
    for i, e in ipairs(entries) do
        local r = menu.rows[i]
        if not r then
            r = CreateFrame("Button", nil, menu.content)
            r:SetSize(236, 22)
            r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); wash(r.hl, 1, 1, 1, 0)
            r.text = Text(r, 12, { 0.94, 0.89, 0.78 }); at(r.text, "LEFT", 8, 0); r.text:SetWidth(222); r.text:SetWordWrap(false)
            r:SetScript("OnEnter", function(self) wash(self.hl, 1, 1, 1, 0.12) end)
            r:SetScript("OnLeave", function(self) wash(self.hl, 1, 1, 1, 0) end)
            r:SetScript("OnClick", function(self)
                locFilter = self.key
                menu:Hide(); UI.Refresh()
            end)
            menu.rows[i] = r
        end
        r.key = e.key
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
        r.text:SetText(e.label)
        local sel = (e.key == locFilter) and not (e.here and locFilter == nil)
        if e.here then Ink(r.text, HERE) elseif sel or (e.all and not locFilter) then Ink(r.text, th.gold) else Ink(r.text, { 0.94, 0.89, 0.78 }) end
        r:Show()
    end
    for i = #entries + 1, #menu.rows do menu.rows[i]:Hide() end
    menu.content:SetHeight(#entries * 22)
    menu:Show()
end

local function ShowTab(key)
    current = key
    if menu then menu:Hide() end
    if locFilter and FILTER_TABS[key] ~= nil then
        local _, byMap = ScopeZones(key)
        if not byMap[locFilter] then locFilter = nil end
    end
    for k, tab in pairs(tabs) do
        local on = (k == key)
        tab.left:SetShown(on); tab.right:SetShown(on)
    end
    if not tabs[key] then
        tabs[key] = BUILDERS[key]()
    end
    tabs[key].left:Show(); tabs[key].right:Show()
    UI.StyleTabs()
    tabs[key].refresh()
    UI.UpdateFilter()
end

function UI.StyleTabs()
    local th = W.Theme()
    if frame and frame.filterBtn then
        frame.filterBtn:SetBackdropColor(th.tab[1], th.tab[2], th.tab[3], 1)
        frame.filterBtn:SetBackdropBorderColor(th.gold[1], th.gold[2], th.gold[3], 0.8)
    end
    for key, b in pairs(tabBtns) do
        local on = key == current
        local c = on and th.tabOn or th.tab
        b:SetBackdropColor(c[1], c[2], c[3], 1)
        b:SetBackdropBorderColor(th.gold[1], th.gold[2], th.gold[3], on and 1 or 0.55)
        b.text:SetTextColor(on and 1 or 0.85, on and 0.92 or 0.8, on and 0.6 or 0.7)
        b:SetHeight(on and 36 or 31)
    end
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    if not tabs[current] then ShowTab(current) else tabs[current].refresh() end
    UI.UpdateFilter()
end

function UI.Relocalize()
    if not frame then return end
    for _, tb in ipairs(TABS) do
        local b = tabBtns[tb[1]]
        b.text:SetText(ns.S(tb[2]))
        b:SetWidth(math.max(96, b.text:GetStringWidth() + 28))
    end
    local prev
    for _, tb in ipairs(TABS) do
        local b = tabBtns[tb[1]]
        b:ClearAllPoints()
        if prev then b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 4, 0) else b:SetPoint("BOTTOMLEFT", book, "TOPLEFT", 52, -4) end
        prev = b
    end
    UI.Refresh()
end

local function Build()
    local th = W.Theme()
    local f = CreateFrame("Frame", "LibraryBooksFrame", UIParent)
    frame = f
    f:SetSize(BOOK_W, BOOK_H + TAB_H)
    if ns.db.pos then f:SetPoint(ns.db.pos[1], UIParent, ns.db.pos[2], ns.db.pos[3], ns.db.pos[4]) else f:SetPoint("CENTER") end
    f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.pos = { p, rp, x, y }
    end)
    f:SetScale(ns.db.uiScale or 1)
    tinsert(UISpecialFrames, "LibraryBooksFrame")

    book = CreateFrame("Frame", nil, f)
    book:SetSize(BOOK_W, BOOK_H); book:SetPoint("BOTTOM")
    book.tex = book:CreateTexture(nil, "BACKGROUND"); book.tex:SetAllPoints()
    book.tex:SetTexture(ns.TEX .. "BookParchment")
    book.tex:SetTexCoord(0, 1, 0, TEX_V)
    local spineX = BOOK_W * (669 / 1351)
    local spine = book:CreateTexture(nil, "ARTWORK")
    wash(spine, INK[1], INK[2], INK[3], 0.35)
    spine:SetPoint("TOPLEFT", book, "TOPLEFT", spineX - 1, -34); spine:SetSize(2, BOOK_H - 70)
    for _, px in ipairs({ PAGE_L + PAGE_W / 2, PAGE_R + PAGE_W / 2 }) do
        local wm = book:CreateTexture(nil, "ARTWORK")
        wm:SetTexture(ns.TEX .. th.crest); wm:SetSize(250, 250); wm:SetAlpha(0.10)
        wm:SetPoint("CENTER", book, "TOPLEFT", px, -(PAGE_TOP + PAGE_H / 2))
    end

    local close = CreateFrame("Button", nil, book)
    close:SetSize(22, 22); at(close, "TOPRIGHT", -2, -2)
    local cx = close:CreateFontString(nil, "OVERLAY", W.Font(18)); at(cx, "CENTER", 0, 1); cx:SetText("×")
    cx:SetTextColor(th.gold[1], th.gold[2], th.gold[3])
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() cx:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() cx:SetTextColor(th.gold[1], th.gold[2], th.gold[3]) end)

    for _, tb in ipairs(TABS) do
        local b = CreateFrame("Button", nil, f, TPL)
        b:SetBackdrop({ bgFile = W.W8, edgeFile = W.W8, edgeSize = 1 })
        b.text = Text(b, 13, nil, "CENTER"); at(b.text, "CENTER", 0, 1)
        b:SetScript("OnClick", function() ShowTab(tb[1]) end)
        tabBtns[tb[1]] = b
    end
    local fb = CreateFrame("Button", nil, f, TPL)
    fb:SetBackdrop({ bgFile = W.W8, edgeFile = W.W8, edgeSize = 1 })
    fb:SetSize(240, 30); fb:SetPoint("BOTTOMRIGHT", book, "TOPRIGHT", -24, -2)
    fb.text = Text(fb, 12, { 0.94, 0.89, 0.78 }); at(fb.text, "LEFT", 10, 1); fb.text:SetWidth(200); fb.text:SetWordWrap(false)
    fb.arrow = fb:CreateTexture(nil, "OVERLAY"); fb.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    fb.arrow:SetSize(16, 16); at(fb.arrow, "RIGHT", -6, 0)
    fb:SetScript("OnClick", function() if menu and menu:IsShown() then menu:Hide() else OpenMenu() end end)
    f.filterBtn = fb
    f:SetScript("OnShow", function() UI.Relocalize() end)
    f:Hide()
    UI.StyleTabs()
end

function UI.Init() if not frame then Build() end end

function UI.Open(bookID)
    if not frame then Build() end
    frame:Show()
    local b = bookID and ns.bookByID[bookID]
    if b then ShowTab(b.cont == 1414 and "kal" or "ek") end
end

function UI.Toggle()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function UI.ToggleSettings()
    if not frame then Build() end
    if frame:IsShown() and current == "settings" then frame:Hide(); return end
    frame:Show(); ShowTab("settings")
end

function UI.ResetPosition()
    if not frame then Build() end
    ns.db.pos = nil
    frame:ClearAllPoints(); frame:SetPoint("CENTER")
end

function UI.ApplyScale() if frame then frame:SetScale(ns.db.uiScale or 1) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function()
    if frame and frame:IsShown() and current == "quests" then UI.Refresh() end
end)
