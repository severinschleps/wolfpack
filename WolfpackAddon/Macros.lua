local ADDON, ns = ...

------------------------------------------------------------------------------------------
-- Macros: one account-wide library, a General tab and a tab per class, that every character
-- can open and edit. Wolfpack writes them into the game's own macro slots: General into the
-- account-wide ones, your class's tab into this character's. So they are ordinary macros on the
-- bars, with #showtooltip, icons, cooldowns and keys. Written at login and after each change,
-- out of combat only (the game allows nothing else). A macro is known by its name; one deleted
-- or renamed here leaves a note (deleted[tab][name]) so other characters drop it too. Macros
-- made in Blizzard's window are left alone, and on the first visit a tab takes in the ones
-- already there.
------------------------------------------------------------------------------------------
local M = {}
ns.mac = M
M.QUESTION = 134400 -- the question mark: the game shows the spell's icon instead
M.BODY_MAX, M.NAME_MAX = 255, 16

-- WolfpackAddonDB.macros = { tabs = { general = { { name, icon, body } ... }, ROGUE = ... },
-- deleted = { [tab] = { [name] = true } } }
function M.db()
    local store = WolfpackAddonDB
    if type(store) ~= "table" then return end
    store.macros = store.macros or {}
    local d = store.macros
    d.tabs, d.deleted = d.tabs or {}, d.deleted or {}
    return d
end

function M.myClass() return select(2, UnitClass("player")) end
function M.max(tab)
    if tab == "general" then return MAX_ACCOUNT_MACROS or 120 end
    return MAX_CHARACTER_MACROS or 18
end

-- the classes this client has, in the game's order
function M.classes()
    local out = {}
    for _, token in ipairs(CLASS_SORT_ORDER or { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN",
        "MAGE", "WARLOCK", "DRUID" }) do
        local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
        if name or not LOCALIZED_CLASS_NAMES_MALE then
            out[#out + 1] = { token, name or (token:sub(1, 1) .. token:sub(2):lower()) }
        end
    end
    return out
end

-- one part of the game's macros: name -> index. perChar: this character's, else the account's.
function M.section(perChar)
    local out = {}
    local ok, na, nc = pcall(GetNumMacros)
    if not ok then return out end
    local first = perChar and (MAX_ACCOUNT_MACROS or 120) + 1 or 1
    for i = first, first + ((perChar and nc or na) or 0) - 1 do
        local name = GetMacroInfo(i)
        if name and not out[name] then out[name] = i end
    end
    return out
end

-- a tab, taking in the game's macros of its part the first time it is opened here
function M.tab(key)
    local d = M.db()
    if not d.tabs[key] then
        local list = {}
        if key == "general" or key == M.myClass() then
            local ok, na, nc = pcall(GetNumMacros)
            local per = key ~= "general"
            local first = per and (MAX_ACCOUNT_MACROS or 120) + 1 or 1
            for i = first, first + ((ok and (per and nc or na)) or 0) - 1 do
                local name, icon, body = GetMacroInfo(i)
                if name then list[#list + 1] = { name = name, icon = icon or M.QUESTION, body = body or "" } end
            end
        end
        d.tabs[key] = list
    end
    return d.tabs[key]
end

function M.find(list, name)
    for i, m in ipairs(list) do if m.name == name then return i end end
end

-- the library into the game's slots: General, then your class's tab
function M.sync()
    if not M.db() then return end
    if InCombatLockdown() then M.pending = true return end
    M.pending = false
    local d = M.db()
    for _, part in ipairs({ { "general", false }, { M.myClass(), true } }) do
        local key, per = part[1], part[2]
        local list = M.tab(key)
        local have = M.section(per)
        for name in pairs(d.deleted[key] or {}) do
            if have[name] and not M.find(list, name) then pcall(DeleteMacro, have[name]) end
        end
        for _, m in ipairs(list) do
            have = M.section(per) -- the game sorts its macros: indexes move after every change
            local i = have[m.name]
            if i then
                local _, icon, body = GetMacroInfo(i)
                if body ~= m.body or (m.icon ~= M.QUESTION and icon ~= m.icon) then
                    pcall(EditMacro, i, m.name, m.icon, m.body)
                end
            else
                pcall(CreateMacro, m.name, m.icon, m.body, per)
            end
        end
    end
end

-- a name nobody in this tab uses yet
function M.free(list, name, skip)
    local base, n = name, 2
    while true do
        local i = M.find(list, name)
        if not i or i == skip then return name end
        name = (base:sub(1, M.NAME_MAX - 3) .. " " .. n)
        n = n + 1
    end
end

-- edits: each is written into the game's slots straight away (out of combat)
function M.new(key)
    local list = M.tab(key)
    if #list >= M.max(key) then return end
    local m = { name = M.free(list, "New macro"), icon = M.QUESTION, body = "" }
    list[#list + 1] = m
    M.sync()
    return #list
end

function M.save(key, i, name, icon, body)
    local list, d = M.tab(key), M.db()
    local m = list[i]
    if not m then return end
    name = strtrim(name or ""):sub(1, M.NAME_MAX)
    if name == "" then name = m.name end
    name = M.free(list, name, i)
    d.deleted[key] = d.deleted[key] or {}
    if name ~= m.name then d.deleted[key][m.name] = true end -- the old name goes elsewhere too
    d.deleted[key][name] = nil
    m.name, m.icon, m.body = name, icon or m.icon, (body or ""):sub(1, M.BODY_MAX)
    M.sync()
end

function M.delete(key, i)
    local list, d = M.tab(key), M.db()
    local m = table.remove(list, i)
    if not m then return end
    d.deleted[key] = d.deleted[key] or {}
    d.deleted[key][m.name] = true
    M.sync()
end

-- onto the cursor, to drop on a bar: only a macro this character has in its slots
function M.pickup(key, i)
    local m = M.tab(key)[i]
    if not m or InCombatLockdown() or not (key == "general" or key == M.myClass()) then return end
    M.sync()
    local idx = M.section(key ~= "general")[m.name]
    if idx then PickupMacro(idx) end
end

-- the game's macro icons: spells, then items
function M.icons()
    if M.iconList then return M.iconList end
    local out = { M.QUESTION }
    for _, fn in ipairs({ GetMacroIcons, GetMacroItemIcons }) do
        local t = {}
        local ok, r = pcall(fn, t)
        local src = (ok and type(r) == "table" and r) or t
        for _, icon in ipairs(src) do out[#out + 1] = icon end
    end
    if #out > 1 then M.iconList = out end -- kept once the game has handed them over
    return out
end

------------------------------------------------------------------------------------------
-- The Macros page: tabs, the tab's macros as icons, the one picked in an editor, an icon picker.
------------------------------------------------------------------------------------------
local ui = ns.ui
local P = { tab = "general", pick = 1, iconPage = 1 } -- what the page shows
M.P = P
local X, TOP, W = 28, -100, 470
local CELL, PER_ROW = 46, 10

local function text(page, font)
    local f = page:CreateFontString(nil, "OVERLAY")
    f:SetFontObject(font or ui.SMALL)
    f:SetJustifyH("LEFT")
    return f
end

local function build(page)
    local f = { tabs = {}, cells = {}, iconCells = {} }
    M.page, M.f = page, f
    -- tabs: General, then a class each; yours says so
    local tabs = { { "general", "General" } }
    for _, c in ipairs(M.classes()) do tabs[#tabs + 1] = c end
    local perRow, tw = 6, 76
    for i, t in ipairs(tabs) do
        local b = ui.Button(page, t[1] == M.myClass() and (t[2] .. " (you)") or t[2], tw)
        b:SetPoint("TOPLEFT", X + ((i - 1) % perRow) * (tw + 3), TOP - math.floor((i - 1) / perRow) * 27)
        b:SetScript("OnClick", function() P.tab, P.pick, P.picking = t[1], 1, false; M.refresh() end)
        b.key = t[1]
        f.tabs[i] = b
    end
    local y = TOP - math.ceil(#tabs / perRow) * 27 - 12
    -- the tab's macros
    f.gridTop = y
    f.gridTitle = text(page, ui.HEADING)
    f.gridTitle:SetPoint("TOPLEFT", page, "TOPLEFT", X, y - 12)
    f.count = text(page, ui.LABEL)
    f.count:SetPoint("TOPRIGHT", page, "TOPLEFT", X + W, y - 14)
    f.note = text(page, ui.LABEL)
    f.note:SetWidth(W)
    for i = 1, 120 do
        local c = CreateFrame("Button", nil, page)
        c:SetSize(CELL - 6, CELL - 6)
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetAllPoints()
        c.name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        c.name:SetPoint("TOP", c, "BOTTOM", 0, -1)
        c.name:SetWidth(CELL)
        c.name:SetWordWrap(false)
        c.sel = c:CreateTexture(nil, "OVERLAY")
        c.sel:SetAllPoints()
        c.sel:SetColorTexture(1, 0.82, 0, 0.25)
        c:RegisterForDrag("LeftButton")
        c:SetScript("OnClick", function(self)
            if self.add then P.pick = M.new(P.tab) or P.pick else P.pick = self.i or P.pick end
            P.picking = false
            M.refresh()
        end)
        c:SetScript("OnDragStart", function(self) if self.i then M.pickup(P.tab, self.i) end end)
        f.cells[i] = c
    end
    -- the editor
    f.edTitle = text(page, ui.HEADING)
    f.name = ui.Input(page, 160)
    f.name:SetMaxLetters(M.NAME_MAX)
    f.iconBtn = CreateFrame("Button", nil, page)
    f.iconBtn:SetSize(36, 36)
    f.iconBtn.tex = f.iconBtn:CreateTexture(nil, "ARTWORK")
    f.iconBtn.tex:SetAllPoints()
    f.iconBtn:SetScript("OnClick", function() P.picking = not P.picking; M.refresh() end)
    f.body = CreateFrame("EditBox", nil, page)
    f.body:SetMultiLine(true)
    f.body:SetAutoFocus(false)
    f.body:SetMaxLetters(M.BODY_MAX)
    f.body:SetFontObject(ui.TEXT_LEFT)
    f.body:SetTextInsets(8, 8, 6, 6)
    f.body:SetSize(W, 120)
    ui.box(f.body, ui.C.input, ui.C.border, 6)
    f.body:SetScript("OnEscapePressed", f.body.ClearFocus)
    f.chars = text(page, ui.LABEL)
    f.body:SetScript("OnTextChanged", function(self)
        f.chars:SetText(#(self:GetText() or "") .. " / " .. M.BODY_MAX)
    end)
    local function save()
        M.save(P.tab, P.pick, f.name:GetText(), P.icon, f.body:GetText())
        f.name:ClearFocus()
        f.body:ClearFocus()
        M.refresh()
    end
    f.name:SetScript("OnEnterPressed", save)
    f.save = ui.Button(page, "Save", 80)
    f.save:SetScript("OnClick", save)
    f.del = ui.Button(page, "Delete", 80)
    f.del:SetScript("OnClick", function()
        M.delete(P.tab, P.pick)
        P.pick = math.max(1, (P.pick or 1) - 1)
        M.refresh()
    end)
    f.drag = ui.Button(page, "Pick up", 80)
    f.drag:SetScript("OnClick", function() M.pickup(P.tab, P.pick) end)
    f.edNote = text(page, ui.LABEL)
    f.edNote:SetWidth(W)
    -- the icon picker, in the editor's place while open
    f.prev, f.next = ui.Button(page, "<", 30), ui.Button(page, ">", 30)
    f.prev:SetScript("OnClick", function() P.iconPage = math.max(1, P.iconPage - 1); M.refresh() end)
    f.next:SetScript("OnClick", function() P.iconPage = P.iconPage + 1; M.refresh() end)
    f.iconPageText = text(page, ui.LABEL)
    for i = 1, 50 do
        local c = CreateFrame("Button", nil, page)
        c:SetSize(38, 38)
        c.tex = c:CreateTexture(nil, "ARTWORK")
        c.tex:SetAllPoints()
        c:SetScript("OnClick", function(self) P.icon, P.picking = self.icon, false; M.refresh(true) end)
        f.iconCells[i] = c
    end
end

-- keep: the editor's text as typed (only the icon changed)
function M.refresh(keep)
    local f, page = M.f, M.page
    if not f then return end
    local list = M.tab(P.tab)
    for _, b in ipairs(f.tabs) do if b.key == P.tab then b:LockHighlight() else b:UnlockHighlight() end end
    local mine = P.tab == "general" or P.tab == M.myClass()
    f.gridTitle:SetText(P.tab == "general" and "General: every character" or
        ((P.tab == M.myClass() and "Your class" or "Class") .. ": every character of it"))
    f.count:SetText(#list .. " / " .. M.max(P.tab))
    -- the grid, then a + while there is room
    local y = f.gridTop - 36
    local n = #list + (#list < M.max(P.tab) and 1 or 0)
    for i, c in ipairs(f.cells) do
        if i <= n then
            local m = list[i]
            c.i, c.add = m and i or nil, not m
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", page, "TOPLEFT", X + ((i - 1) % PER_ROW) * CELL, y - math.floor((i - 1) / PER_ROW) * (CELL + 12))
            c.icon:SetTexture(m and m.icon or "Interface\\PaperDollInfoFrame\\Character-Plus")
            c.name:SetText(m and m.name or "")
            c.sel:SetShown(m ~= nil and i == P.pick and not P.picking)
            c:Show()
        else
            c:Hide()
        end
    end
    y = y - math.ceil(math.max(n, 1) / PER_ROW) * (CELL + 12)
    f.note:ClearAllPoints()
    f.note:SetPoint("TOPLEFT", page, "TOPLEFT", X, y)
    f.note:SetText(mine and "Click one to edit it; drag one onto a bar (out of combat)."
        or "Every character of this class gets these in its own macro slots. Log in as one to put them on its bars.")
    y = y - 30
    -- the editor
    local m = list[P.pick]
    if m and not keep then P.icon = m.icon end
    local editing = m ~= nil and not P.picking
    for _, w in ipairs({ f.edTitle, f.name, f.iconBtn, f.body, f.chars, f.save, f.del, f.drag, f.edNote }) do
        w:SetShown(editing)
    end
    if editing then
        f.edTitle:ClearAllPoints()
        f.edTitle:SetPoint("TOPLEFT", page, "TOPLEFT", X, y)
        f.edTitle:SetText("Edit")
        f.iconBtn:ClearAllPoints()
        f.iconBtn:SetPoint("TOPLEFT", page, "TOPLEFT", X, y - 22)
        f.iconBtn.tex:SetTexture(P.icon or M.QUESTION)
        f.name:ClearAllPoints()
        f.name:SetPoint("LEFT", f.iconBtn, "RIGHT", 10, 0)
        if not keep then f.name:SetText(m.name); f.body:SetText(m.body) end
        f.body:ClearAllPoints()
        f.body:SetPoint("TOPLEFT", page, "TOPLEFT", X, y - 66)
        f.chars:ClearAllPoints()
        f.chars:SetPoint("TOPRIGHT", f.body, "BOTTOMRIGHT", 0, -4)
        f.chars:SetText(#(f.body:GetText() or "") .. " / " .. M.BODY_MAX)
        f.save:ClearAllPoints()
        f.save:SetPoint("TOPLEFT", f.body, "BOTTOMLEFT", 0, -22)
        f.del:ClearAllPoints()
        f.del:SetPoint("LEFT", f.save, "RIGHT", 6, 0)
        f.drag:ClearAllPoints()
        f.drag:SetPoint("LEFT", f.del, "RIGHT", 6, 0)
        f.drag:SetShown(mine)
        f.edNote:ClearAllPoints()
        f.edNote:SetPoint("TOPLEFT", f.save, "BOTTOMLEFT", 0, -8)
        f.edNote:SetText("Click the icon to pick another; the question mark shows the spell the macro casts. "
            .. "Saved into the game's macro slots straight away, or once combat ends.")
        y = y - 66 - 120 - 22 - 24 - 8 - 30
    end
    -- the icon picker
    local icons = M.icons()
    local pages = math.max(1, math.ceil(#icons / #f.iconCells))
    P.iconPage = math.min(P.iconPage, pages)
    f.prev:SetShown(P.picking)
    f.next:SetShown(P.picking)
    f.iconPageText:SetShown(P.picking)
    for i, c in ipairs(f.iconCells) do
        local icon = icons[(P.iconPage - 1) * #f.iconCells + i]
        c:SetShown(P.picking and icon ~= nil)
        if P.picking and icon then
            c.icon = icon
            c.tex:SetTexture(icon)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", page, "TOPLEFT", X + ((i - 1) % 10) * 42, y - 30 - math.floor((i - 1) / 10) * 42)
        end
    end
    if P.picking then
        f.prev:ClearAllPoints()
        f.prev:SetPoint("TOPLEFT", page, "TOPLEFT", X, y)
        f.next:ClearAllPoints()
        f.next:SetPoint("LEFT", f.prev, "RIGHT", 4, 0)
        f.iconPageText:ClearAllPoints()
        f.iconPageText:SetPoint("LEFT", f.next, "RIGHT", 10, 0)
        f.iconPageText:SetText("Pick an icon, page " .. P.iconPage .. " of " .. pages)
        y = y - 30 - 5 * 42
    end
    page.need = -y + 20
    if ns.content and page:IsShown() then ns.content:SetHeight(math.max(1, page.need - 90 + 16)) end
end

-- the options window's Macros page; built the first time it is opened
function M.ShowConfig(page)
    if not M.db() then return end
    if not M.f then build(page) end
    M.refresh()
end
