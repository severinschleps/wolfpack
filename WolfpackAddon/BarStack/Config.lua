local _, ns = ...
ns.bs = ns.bs or {}
local BS = ns.bs
local ui = ns.ui

local MAX_ICONS = 8 -- ponytail: no scrolling in the icon list; a bar holds "one or a few" icons
local MAX_CONDS = 6

-- Cards: the group and its bars side by side, the picked bar's icons under both (the options
-- window is narrow and scrolls), then the footer.
local W, H = 472, ui.BS_H
local C1, C2, C3 = 0, 242, 0
local W12, W3 = 230, 472
local BOTTOM = -656
local Y3, H3 = BOTTOM - 16, 300 -- the icons card's top and height
local FOOT = Y3 - H3 - 16

local f, selected, dragFrom, group, editing -- editing: the icon open in the Icon dialog
local listRows, iconRows, pickRows, condRows = {}, {}, {}, {}
local groupSliders, barSliders = {}, {}
local dialogs = {} -- every flyout, so leaving the page closes them

-- The group whose bars the window shows; the first one if the old pick is gone.
local function G()
  local groups = BS.profile.groups
  if not tContains(groups, group) then group = groups[1] end
  return group
end

local function changed()
  BS.Changed()
  BS.RefreshConfig()
end

local function text(parent, s, x, y, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", ui.font(font or "GameFontNormalSmall"))
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(s)
  return fs
end

local function button(parent, s, w, x, y, onClick)
  local b = ui.Button(parent, s, w)
  if x then b:SetPoint("TOPLEFT", x, y) end
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function input(parent, x, y, w, numeric, set)
  local e = ui.Input(parent, w)
  e:SetPoint("TOPLEFT", x, y)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  e:SetScript("OnEscapePressed", function(self) BS.RefreshConfig(); self:ClearFocus() end)
  e:HookScript("OnEditFocusLost", function(self)
    local v = self:GetText()
    if numeric then v = tonumber(v) end
    if v and v ~= "" then set(v); changed() else BS.RefreshConfig() end
  end)
  return e
end

local function checkbox(parent, s, x, y, onClick)
  local c = ui.Check(parent, s)
  c:SetPoint("TOPLEFT", x, y)
  c:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
  return c
end

-- items() -> { { text, isSelected(), onSelect() }, ... }, asked afresh each time the menu opens
local function dropdown(parent, x, y, w, items)
  local d = ui.Dropdown(CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate"))
  d:SetPoint("TOPLEFT", x, y)
  d:SetSize(w, 26)
  d:SetupMenu(function(_, root)
    for _, it in ipairs(items()) do root:CreateRadio(it[1], it[2], it[3]) end
  end)
  return d
end

-- Label, track, and the value typed in beside it. Dragging moves things live and saves on release
-- (a save writes every CVar chunk); the wheel and the box save at once. get() nil = nothing to show.
local function slider(list, parent, s, x, y, w, min, max, step, get, set)
  local label = text(parent, s, x, y)
  local sl = ui.Slider(parent, w - 54)
  sl:SetPoint("TOPLEFT", x, y - 20)
  sl:SetMinMaxValues(min, max)
  sl:SetValueStep(step)
  sl:SetObeyStepOnDrag(true)
  sl:EnableMouseWheel(true)
  local box = ui.Input(parent, 44)
  box:SetPoint("LEFT", sl, "RIGHT", 10, 0)
  local syncing
  local function round(v) return math.floor(v / step + 0.5) * step end
  sl:SetScript("OnValueChanged", function(_, v)
    if syncing or get() == nil then return end
    v = round(v)
    if v ~= get() then set(v); BS.Apply(); BS.RefreshConfig() end
  end)
  sl:SetScript("OnMouseUp", function() BS.Save() end)
  sl:SetScript("OnMouseWheel", function(_, d)
    if get() == nil then return end
    set(round(math.max(min, math.min(max, get() + d * step))))
    changed()
  end)
  box:SetScript("OnEnterPressed", box.ClearFocus)
  box:HookScript("OnEditFocusLost", function()
    local v = tonumber(box:GetText())
    if v and get() ~= nil then set(round(v)); changed() else BS.RefreshConfig() end
  end)
  function sl.sync()
    local v = get()
    if v == nil then return end
    syncing = true
    sl:SetValue(math.max(min, math.min(max, v)))
    syncing = false
    if not box:HasFocus() then box:SetText(("%g"):format(v)) end
  end
  function sl.show(on)
    for _, p in ipairs({ label, sl, box }) do p:SetShown(on) end
  end
  list[#list + 1] = sl
  return sl
end

local function groupItems(onSelect)
  local out = {}
  for _, g in ipairs(BS.profile.groups) do
    out[#out + 1] = { g.name, function() return g == onSelect.current() end, function() onSelect.set(g) end }
  end
  return out
end

local function scroll(parent, x, y, w, h)
  local sf = ui.Scroll(CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", x, y)
  sf:SetSize(w, h)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(w, 1)
  sf:SetScrollChild(child)
  return child
end

-- A dialog beside the options window.
local function dialog(w, h, title)
  -- beside the whole window, not the page: the page scrolls, and would cut a dialog off
  local win = ns.cfg or f:GetParent()
  local d = ui.Window(nil, w, h, title)
  d:SetParent(win)
  d:ClearAllPoints()
  d:SetPoint("TOPLEFT", win, "TOPRIGHT", 12, 0)
  dialogs[#dialogs + 1] = d
  return d
end

------------------------------------------------------------------------
-- Bar list (top = top layer, drag to reorder)
------------------------------------------------------------------------

-- An arrow button at the right of a list row, x from its right edge: d = -1 up, 1 down. It draws
-- the dropdowns' own arrow, flipped for up.
local function arrow(row, d, x, onClick)
  local b = ui.Button(row, "", 22, true)
  b:SetPoint("RIGHT", x, 0)
  local t = b:CreateTexture(nil, "OVERLAY")
  t:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
  if d < 0 then t:SetTexCoord(0, 1, 1, 0) end -- flipped: up
  t:SetDesaturated(true)
  t:SetSize(14, 14)
  t:SetPoint("CENTER", 0, d < 0 and 3 or -3)
  b:SetScript("OnClick", onClick)
  return b
end

local function listRow(i)
  if listRows[i] then return listRows[i] end
  local r = ui.Button(f.list, "", 196, true)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
  r:GetFontString():SetPoint("RIGHT", -50, 0)
  r:GetFontString():SetPoint("LEFT", 28, 0)
  -- ticked: this character loads the bar; every bar is in every character's list
  r.load = ui.Check(r)
  r.load:SetPoint("LEFT", 6, 0)
  r.load:SetHitRectInsets(0, 0, -4, -4)
  r.load:SetScript("OnClick", function(self)
    BS.SetLoaded(G().bars[r.index], self:GetChecked())
    changed()
  end)
  -- a layer up or down; the top of the list draws over the rest
  local function move(d)
    return function() if BS.MoveBar(G().bars[i], d) then changed() end end
  end
  r.up, r.down = arrow(r, -1, -24, move(-1)), arrow(r, 1, 0, move(1))
  r:RegisterForDrag("LeftButton")
  r:SetScript("OnClick", function(self)
    selected = G().bars[self.index]
    BS.RefreshConfig()
  end)
  r:SetScript("OnDragStart", function(self) dragFrom = self.index end)
  r:SetScript("OnDragStop", function()
    local bars = G().bars
    for _, o in ipairs(listRows) do
      if dragFrom and o:IsShown() and o:IsMouseOver() and o.index ~= dragFrom then
        table.insert(bars, o.index, table.remove(bars, dragFrom))
        changed()
        break
      end
    end
    dragFrom = nil
  end)
  listRows[i] = r
  return r
end

------------------------------------------------------------------------
-- The bar's icons, the Icon dialog, and the spell picker both use
------------------------------------------------------------------------

local editor, settings -- the Icon and Bar settings flyouts, made the first time they are opened

local function iconRow(i)
  if iconRows[i] then return iconRows[i] end
  local r = ui.Button(f.right, "", W3 - 24, true)
  r:SetPoint("TOPLEFT", C3 + 12, Y3 - 40 - (i - 1) * 26)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT", 4, 0)
  r:GetFontString():ClearAllPoints()
  r:GetFontString():SetPoint("LEFT", 30, 0)
  r:GetFontString():SetPoint("RIGHT", -118, 0)
  r:GetFontString():SetJustifyH("LEFT")
  r:SetScript("OnClick", function() BS.EditIcon(selected.icons[i]) end)
  r.remove = ui.Button(r, "Remove", 64, true)
  r.remove:SetPoint("RIGHT")
  r.remove:SetScript("OnClick", function()
    if editing == selected.icons[i] then editor:Hide() end
    table.remove(selected.icons, i)
    changed()
  end)
  -- the order the icons run in the bar: one arrow each way
  local function move(d)
    return function() if BS.MoveIcon(selected, i, d) then changed() end end
  end
  r.up, r.down = arrow(r, -1, -94, move(-1)), arrow(r, 1, -70, move(1))
  iconRows[i] = r
  return r
end

-- what an icon's row says: its picture's name and when it shows
local function summary(ic)
  local n = #ic.conditions
  return BS.IconName(ic) .. "|cff71717a  --  " .. (n == 0 and "always" or n == 1 and "1 condition"
    or n .. " conditions") .. "|r"
end

local function pickRow(i)
  if pickRows[i] then return pickRows[i] end
  local r = ui.Button(f.picker.list, "", 230, true)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT", 6, 0)
  r:GetFontString():SetPoint("LEFT", 32, 0)
  r:SetScript("OnClick", function(self)
    f.picker:Hide()
    f.picker.onPick({ baseSpell = self.sp.baseSpell, name = self.sp.name })
    changed()
  end)
  pickRows[i] = r
  return r
end

-- Spells from Blizzard's Cooldown Manager; `buffsOnly` lists Tracked Buffs alone, all an aura
-- icon or an aura condition can use. onPick(spell) is told which one.
local function showPicker(buffsOnly, onPick, list, hint)
  local p = f.picker
  if not p then
    p = dialog(270, 460, "Pick a spell")
    p.hint = text(p, "", 16, -48, "GameFontDisableSmall")
    p.hint:SetJustifyH("LEFT")
    button(p, "Open Cooldown Manager", 238, 16, -80, function()
      if not pcall(function() CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown()) end) then
        print("|cffC79C6EBar Stack|r: open it from Options > Gameplay Enhancements > Cooldown Manager.")
      end
    end)
    p.empty = text(p, "No spells found. Is the Cooldown Manager on?", 16, -116, "GameFontDisableSmall")
    p.list = scroll(p, 16, -116, 230, 330)
    f.picker = p
  end
  p.onPick = onPick
  p:ClearAllPoints()
  p:SetPoint("TOPLEFT", editor, "TOPRIGHT", 12, 0) -- beside the icon it is for
  p.hint:SetText(hint or buffsOnly and "Tracked Buffs only: an aura has to be\nthere for Blizzard to say it is up."
    or "Lists spells in Blizzard's Cooldown Manager.\nMissing one? Add it there first.")
  local spells = list or BS.AvailableSpells(buffsOnly)
  p.list:SetHeight(math.max(1, #spells * 26))
  for i, sp in ipairs(spells) do
    local r = pickRow(i)
    r.sp = sp
    r.icon:SetTexture(sp.icon or 134400)
    r:SetText(sp.name)
    r:Show()
  end
  for i = #spells + 1, #pickRows do pickRows[i]:Hide() end
  p.empty:SetShown(#spells == 0)
  p:Show()
end

local LOOK_TEXT = { custom = "My own picture", cooldown = "Blizzard's cooldown icon",
  aura = "Blizzard's aura icon (with timer)" }
local LOOKS = { "custom", "cooldown", "aura" }
local COND_TEXT = { usable = "Usable", active = "Aura up", missing = "Aura missing", target = "Have a target",
  form = "In", noform = "Not in", stealth = "Stealthed", nostealth = "Not stealthed" }
local NO_SPELL_ICON = { target = 132212, stealth = 132320, nostealth = 132320 }

local function condRow(i)
  if condRows[i] then return condRows[i] end
  local r = CreateFrame("Frame", nil, editor)
  r:SetSize(288, 22)
  r:SetPoint("TOPLEFT", 16, -346 - (i - 1) * 24)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT")
  r.name = r:CreateFontString(nil, "OVERLAY", ui.TEXT_LEFT)
  r.name:SetPoint("LEFT", 28, 0)
  r.name:SetWidth(190)
  r.remove = ui.Button(r, "Remove", 64, true)
  r.remove:SetPoint("RIGHT")
  r.remove:SetScript("OnClick", function()
    table.remove(editing.conditions, i)
    changed()
  end)
  condRows[i] = r
  return r
end

-- The Icon dialog: first what the icon looks like, then when it shows.
function BS.EditIcon(ic)
  editing = ic
  if settings then settings:Hide() end -- one flyout at a time, they open in the same place
  if not editor then
    local d = dialog(320, 500, "Icon")
    editor, f.editor = d, d
    text(d, "Looks like", 16, -44, "GameFontNormal")
    d.look = dropdown(d, 16, -66, 288, function()
      local out = {}
      for _, v in ipairs(LOOKS) do
        out[#out + 1] = { LOOK_TEXT[v], function() return editing and editing.look == v end,
          function() editing.look = v; changed() end }
      end
      return out
    end)
    d.spellLabel = text(d, "Spell", 16, -102)
    d.spell = button(d, "", 288, 16, -118, function()
      showPicker(editing.look == "aura", function(sp) editing.spell = sp end)
    end)
    d.texLabel = text(d, "Or a texture: file ID, path or spell name", 16, -154)
    d.tex = ui.Input(d, 288)
    d.tex:SetPoint("TOPLEFT", 16, -170)
    d.tex:SetScript("OnEnterPressed", d.tex.ClearFocus)
    d.tex:SetScript("OnEscapePressed", function(self) BS.RefreshConfig(); self:ClearFocus() end)
    d.tex:HookScript("OnEditFocusLost", function(self)
      local v = strtrim(self:GetText() or "")
      editing.texture = v ~= "" and (tonumber(v) or v) or nil
      changed()
    end)
    d.swipe = checkbox(d, "Cooldown swipe of the spell", 16, -202, function(on) editing.swipe = on; changed() end)
    d.lookNote = text(d, "", 16, -154, "GameFontDisableSmall")
    d.lookNote:SetWidth(288)
    d.lookNote:SetJustifyH("LEFT")

    text(d, "Shows while all of these hold", 16, -240, "GameFontNormal")
    d.adds = {
      button(d, "Usable", 70, 16, -262, function()
        showPicker(false, function(sp) sp.kind = "usable"; table.insert(editing.conditions, sp) end)
      end),
      button(d, "Aura up", 70, 88, -262, function()
        showPicker(true, function(sp) sp.kind = "active"; table.insert(editing.conditions, sp) end)
      end),
      button(d, "Aura missing", 70, 160, -262, function()
        showPicker(true, function(sp) sp.kind = "missing"; table.insert(editing.conditions, sp) end)
      end),
      button(d, "Target", 70, 232, -262, function()
        table.insert(editing.conditions, { kind = "target" })
        changed()
      end),
    }
    -- stances, druid forms, a rogue's stealth: whatever your stance bar holds
    local function pickForm(kind)
      showPicker(false, function(sp) sp.kind = kind; table.insert(editing.conditions, sp) end,
        BS.Forms(), "Your stances and forms, as your\nstance bar holds them.")
    end
    for i, k in ipairs({ { "In form", function() pickForm("form") end },
      { "Not in form", function() pickForm("noform") end },
      { "Stealthed", function() table.insert(editing.conditions, { kind = "stealth" }); changed() end },
      { "Not stealthed", function() table.insert(editing.conditions, { kind = "nostealth" }); changed() end } }) do
      d.adds[#d.adds + 1] = button(d, k[1], 70, 16 + (i - 1) * 72, -290, k[2])
    end
    text(d, "Usable: as your action bar shows it. Aura: from Tracked Buffs.", 16, -320, "GameFontDisableSmall")
    d.empty = text(d, "None: the icon always shows.", 16, -350, "GameFontDisableSmall")
  end
  editor:Show()
  BS.RefreshConfig()
end

-- Bar settings: its name, which way its icons run, their size, its place in the stack.
function BS.ShowBarSettings()
  if not selected then return end
  if not settings then
    local d = dialog(300, 420, "Bar settings")
    settings, f.barSettings = d, d
    local x, w = 16, 268
    text(d, "Name", x, -48)
    d.name = input(d, x, -64, w, false, function(v) selected.name = v end)
    d.orient = button(d, "", 110, x, -100, function()
      selected.orientation = selected.orientation == "vertical" and "horizontal" or "vertical"
      changed()
    end)
    text(d, "Icons run this way", x + 118, -106, "GameFontDisableSmall")
    local B = function() return selected end
    -- the group's icon size until moved here; then the bar's own, till "Use the group's size"
    local function own()
      local b = B()
      if not b.size then local w_, h_ = BS.IconSize(b); b.size = { w = w_, h = h_ } end
      return b.size
    end
    slider(barSliders, d, "Icon width", x, -136, w, 8, 200, 1,
      function() return B() and BS.IconSize(B()) end, function(v) own().w = BS.Clamp(v, 1, 2000) end)
    slider(barSliders, d, "Icon height", x, -182, w, 8, 200, 1,
      function() return B() and select(2, BS.IconSize(B())) end, function(v) own().h = BS.Clamp(v, 1, 2000) end)
    slider(barSliders, d, "Offset X", x, -228, w, -400, 400, 1,
      function() return B() and B().offset.x end, function(v) B().offset.x = BS.Clamp(v, -2000, 2000) end)
    slider(barSliders, d, "Offset Y", x, -274, w, -400, 400, 1,
      function() return B() and B().offset.y end, function(v) B().offset.y = BS.Clamp(v, -2000, 2000) end)
    slider(barSliders, d, "Icon gap", x, -320, w, 0, 40, 1,
      function() return B() and B().gap end, function(v) B().gap = BS.Clamp(v, 0, 200) end)
    d.groupSize = button(d, "Use the group's icon size", 200, x, -372, function() selected.size = nil; changed() end)
  end
  if editor then editor:Hide() end
  if f.picker then f.picker:Hide() end
  settings:Show()
  BS.RefreshConfig()
end

local function refreshSettings(b)
  if not (settings and settings:IsShown()) then return end
  if not settings.name:HasFocus() then settings.name:SetText(b.name) end
  settings.orient:SetText(b.orientation == "vertical" and "Vertical" or "Horizontal")
  settings.groupSize:SetEnabled(b.size ~= nil)
  for _, sl in ipairs(barSliders) do sl.sync() end
end

local function refreshEditor()
  if not (editor and editor:IsShown()) then return end
  if not (selected and tContains(selected.icons, editing)) then return editor:Hide() end
  local d, ic = editor, editing
  d.look:GenerateMenu()
  local own = ic.look == "custom"
  d.spellLabel:SetText(own and "Spell (its picture and cooldown; optional)" or "Spell")
  d.spell:SetText(ic.spell and ic.spell.name or "Pick a spell")
  d.texLabel:SetShown(own)
  d.tex:SetShown(own)
  if not d.tex:HasFocus() then d.tex:SetText(ic.texture and tostring(ic.texture) or "") end
  d.swipe:SetShown(own)
  d.swipe:SetChecked(ic.swipe)
  d.swipe:SetEnabled(ic.spell ~= nil)
  d.lookNote:SetShown(not own)
  d.lookNote:SetText(ic.look == "aura" and "Blizzard shows it only while the aura is up, with its timer."
    .. " Needs the spell in Tracked Buffs." or "Blizzard's icon, with its cooldown and charges.")
  local untracked = {}
  for _, q in ipairs(BS.gates or {}) do
    if q.icon == ic and q.frame == false then untracked[q.cond] = true end
  end
  for i, q in ipairs(ic.conditions) do
    local row = condRow(i)
    row.icon:SetTexture(q.baseSpell and C_Spell and BS.try(C_Spell.GetSpellTexture, q.baseSpell)
      or NO_SPELL_ICON[q.kind] or 134400)
    row.name:SetText(COND_TEXT[q.kind] .. (q.name and ": " .. q.name or "")
      .. (untracked[q] and " |cfff87171(not in Tracked Buffs; Tracked Bars is not read)|r" or ""))
    row:Show()
  end
  for i = #ic.conditions + 1, #condRows do condRows[i]:Hide() end
  for _, add in ipairs(d.adds) do add:SetEnabled(#ic.conditions < MAX_CONDS) end
  d.empty:SetShown(#ic.conditions == 0)
end

------------------------------------------------------------------------
-- Icon style: zoom, border and corners for every icon in the profile
------------------------------------------------------------------------

local RADIUS = { { 0, "Square" }, { 12, "Small" }, { 25, "Medium" }, { 50, "Round" } }
local iconStyle -- the dialog, made the first time it is opened

function BS.ShowIconStyle()
  local d = iconStyle
  if not d then
    d = dialog(250, 290, "Icon style")
    local I = function() return BS.profile.icons end
    text(d, "Zoom (%): trims the art's edges so it fills the icon", 16, -48, "GameFontDisableSmall")
    d.zoom = input(d, 16, -66, 60, true, function(v) I().zoom = BS.Clamp(v, 0, 30) end)
    text(d, "Border (px)", 16, -104)
    d.border = input(d, 16, -122, 60, true, function(v) I().border = BS.Clamp(math.floor(v + 0.5), 0, 8) end)
    text(d, "Border color", 100, -104)
    d.swatch = d:CreateTexture(nil, "ARTWORK")
    d.swatch:SetSize(24, 24)
    d.swatch:SetPoint("TOPLEFT", 100, -122)
    button(d, "Pick", 60, 132, -122, function()
      local c = I().color
      local r0, g0, b0, a0 = c[1], c[2], c[3], c[4]
      local function set(r, g, b, a)
        c[1], c[2], c[3], c[4] = r, g, b, a
        changed()
      end
      ColorPickerFrame:SetupColorPickerAndShow({
        r = r0, g = g0, b = b0, opacity = a0, hasOpacity = true,
        swatchFunc = function()
          local r, g, b = ColorPickerFrame:GetColorRGB()
          set(r, g, b, ColorPickerFrame:GetColorAlpha())
        end,
        opacityFunc = function()
          local r, g, b = ColorPickerFrame:GetColorRGB()
          set(r, g, b, ColorPickerFrame:GetColorAlpha())
        end,
        cancelFunc = function() set(r0, g0, b0, a0) end,
      })
    end)
    text(d, "Corners", 16, -162)
    d.radius = dropdown(d, 16, -180, 160, function()
      local out = {}
      for _, e in ipairs(RADIUS) do
        out[#out + 1] = { e[2], function() return I().radius == e[1] end,
          function() I().radius = e[1]; changed() end }
      end
      return out
    end)
    text(d, "Applies to every icon in this profile.", 16, -224, "GameFontDisableSmall")
    iconStyle = d
  end
  d:Show()
  BS.RefreshConfig()
end

------------------------------------------------------------------------
-- The editor, on Wolfpack's Bar Stack page (its options window has the title and the close button)
------------------------------------------------------------------------

local function preview(on)
  BS.preview = on
  BS.Apply()
end

local function build(parent)
  f = CreateFrame("Frame", nil, parent)
  f:SetSize(W, H)
  f:SetPoint("TOPLEFT", 16, -100)
  -- every bar is on screen while you edit them, so there is something to place
  f:SetScript("OnShow", function() preview(true); BS.RefreshConfig() end)
  f:SetScript("OnHide", function()
    if BS.preview then preview(false) end
    for _, d in ipairs(dialogs) do d:Hide() end
  end)

  ui.card(f, C1, 0, W12, -BOTTOM)
  ui.card(f, C2, 0, W12, -BOTTOM)
  ui.card(f, C3, Y3, W3, H3)

  -- column 1: the group (each one is a stack of its own) and its stack settings
  local x = C1 + 12
  text(f, "Group", x, -12, "GameFontNormal")
  text(f, "Editing", x, -40)
  f.groupDrop = dropdown(f, x, -56, 206, function()
    return groupItems({ current = G, set = function(g) group, selected = g, nil; BS.RefreshConfig() end })
  end)
  text(f, "Name", x, -92)
  f.groupName = input(f, x, -108, 206, false, function(v) G().name = v end)
  button(f, "New group", 100, x, -144, function()
    group, selected = BS.NewGroup(), nil
    changed()
  end)
  f.delGroup = button(f, "Delete", 100, x + 106, -144, function()
    if BS.DeleteGroup(G()) then group, selected = nil, nil; changed() end
  end)
  f.groupNote = text(f, "Empty a group to delete it.", x, -174, "GameFontDisableSmall")
  local S = function() return G().stack end
  slider(groupSliders, f, "Scale", x, -196, 206, 0.3, 3, 0.05,
    function() return S().scale end, function(v) S().scale = BS.Clamp(v, 0.3, 3) end)
  slider(groupSliders, f, "Opacity", x, -242, 206, 0, 1, 0.05,
    function() return S().alpha end, function(v) S().alpha = BS.Clamp(v, 0, 1) end)
  -- on the Combat Display's top or bottom it moves along as that grows; picking one starts at the edge
  text(f, "Anchored to", x, -288)
  f.anchor = dropdown(f, x, -304, 206, function()
    local out = {}
    for _, e in ipairs({ { "The screen", "screen", -180 }, { "Combat Display, top", "top", 4 },
      { "Combat Display, bottom", "bottom", -4 }, { "Combat Display, icon stack 1", "slot1", 0 },
      { "Combat Display, icon stack 2", "slot2", 0 }, { "Combat Display, icon stack 3", "slot3", 0 } }) do
      out[#out + 1] = { e[1], function() return S().anchor == e[2] end, function()
        local s = S()
        if s.anchor ~= e[2] then s.anchor, s.x, s.y = e[2], 0, e[3]; changed() end
      end }
    end
    return out
  end)
  slider(groupSliders, f, "Position X", x, -340, 206, -1000, 1000, 1,
    function() return S().x end, function(v) S().x = BS.Clamp(v, -3000, 3000) end)
  slider(groupSliders, f, "Position Y", x, -386, 206, -600, 600, 1,
    function() return S().y end, function(v) S().y = BS.Clamp(v, -3000, 3000) end)
  f.inCombat = checkbox(f, "Show in combat", x, -440, function(on) S().showInCombat = on; changed() end)
  f.outCombat = checkbox(f, "Show out of combat", x, -466, function(on) S().showOutOfCombat = on; changed() end)
  -- every bar of the group whose size was never set on the bar itself
  slider(groupSliders, f, "Icon width", x, -500, 206, 8, 200, 1,
    function() return S().size.w end, function(v) S().size.w = BS.Clamp(v, 1, 2000) end)
  slider(groupSliders, f, "Icon height", x, -546, 206, 8, 200, 1,
    function() return S().size.h end, function(v) S().size.h = BS.Clamp(v, 1, 2000) end)
  text(f, "Class", x, -592)
  f.class = dropdown(f, x, -608, 206, function()
    local out = { { "Every class", function() return S().class == nil end, function() S().class = nil; changed() end } }
    for _, c in ipairs(CLASS_SORT_ORDER or {}) do
      out[#out + 1] = { LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c] or c,
        function() return S().class == c end, function() S().class = c; changed() end }
    end
    return out
  end)

  -- column 2: its bars (top = top layer, the arrows or a drag reorder them)
  x = C2 + 12
  text(f, "Bars", x, -12, "GameFontNormal")
  f.settings = button(f, "Settings", 90, C2 + W12 - 102, -8, BS.ShowBarSettings)
  f.list = scroll(f, x, -40, 196, 390)
  f.loadNote = text(f, "", x, -440, "GameFontDisableSmall")
  f.loadNote:SetWidth(206)
  f.loadNote:SetJustifyH("LEFT")
  button(f, "New", 64, x, -512, function()
    selected = BS.NewBar(G())
    changed()
  end)
  button(f, "Copy", 64, x + 70, -512, function()
    if not selected then return end
    local copy = CopyTable(selected)
    copy.id, copy.name = nil, selected.name .. " copy"
    table.insert(G().bars, tIndexOf(G().bars, selected), BS.NormalizeBar(copy))
    BS.SetLoaded(copy, true)
    selected = copy
    changed()
  end)
  button(f, "Delete", 66, x + 140, -512, function()
    local i = selected and tIndexOf(G().bars, selected)
    if i then table.remove(G().bars, i); selected = nil; changed() end
  end)
  local hint = text(f, "The top bar draws over the others. Use the arrows or drag one to reorder.", x, -548,
    "GameFontDisableSmall")
  hint:SetWidth(206)
  hint:SetJustifyH("LEFT")

  -- column 3: the selected bar's icons (its settings are a flyout, from the Bars column)
  x = C3 + 12
  f.empty = text(f, "No bars yet. Click New to create one.", x, Y3 - 40, "GameFontDisableSmall")
  local r = CreateFrame("Frame", nil, f)
  r:SetAllPoints()
  f.right = r
  f.iconsTitle = text(r, "Icons", x, Y3 - 12, "GameFontNormal")
  f.iconsTitle:SetWidth(W3 - 222)
  f.iconsTitle:SetJustifyH("LEFT")
  f.iconsTitle:SetWordWrap(false)
  -- the look of every icon in the profile, top right, so it is there with or without a bar picked
  f.iconStyle = button(f, "Icon style", 90, C3 + W3 - 102, Y3 - 8, BS.ShowIconStyle)
  f.add = button(r, "Add icon", 90, C3 + W3 - 198, Y3 - 8, function()
    local ic = BS.NormalizeIcon({})
    table.insert(selected.icons, ic)
    changed()
    BS.EditIcon(ic)
  end)
  -- why an icon on this bar shows nothing, said where you are looking rather than in /bs check
  f.iconNote = text(r, "", x, Y3 - 44, "GameFontNormalSmall")
  f.iconNote:SetWidth(W3 - 24)
  f.iconNote:SetJustifyH("LEFT")
  BS.cfg = f
  f.groupSliders, f.barSliders, f.iconRows, f.listRows = groupSliders, barSliders, iconRows, listRows

  -- footer: what the whole profile shares
  f.preview = checkbox(f, "Show all bars", 2, FOOT, preview)
  f.hideBlizzard = checkbox(f, "Hide Blizzard's Cooldown Manager", 140, FOOT, function(on)
    BS.profile.hideBlizzard = on
    changed()
  end)
  f.combatNote = text(f, "Changes apply after combat.", 2, FOOT - 28, "GameFontRedSmall")
end

function BS.RefreshConfig()
  if not (BS.profile and f and f:IsVisible()) then return end
  local groups, bars = BS.profile.groups, G().bars
  if not tContains(bars, selected) then selected = bars[1] end
  f.groupDrop:GenerateMenu()
  local d, ic = iconStyle, BS.profile.icons
  if d and d:IsShown() then
    if not d.zoom:HasFocus() then d.zoom:SetText(tostring(ic.zoom)) end
    if not d.border:HasFocus() then d.border:SetText(tostring(ic.border)) end
    d.swatch:SetColorTexture(ic.color[1], ic.color[2], ic.color[3], ic.color[4])
    d.radius:GenerateMenu()
  end
  if not f.groupName:HasFocus() then f.groupName:SetText(G().name) end
  local canDelete = #groups > 1 and #bars == 0
  f.delGroup:SetEnabled(canDelete)
  f.groupNote:SetShown(not canDelete and #groups > 1)

  f.list:SetHeight(math.max(1, #bars * 26))
  for i, b in ipairs(bars) do
    local row = listRow(i)
    row.index = i
    local on = BS.Loaded(b)
    row:SetText(("|cff71717a%d|r   %s%s"):format(#bars - i + 1, on and "" or "|cff71717a", b.name))
    row.load:SetChecked(on)
    if b == selected then row:LockHighlight() else row:UnlockHighlight() end
    row.up:SetEnabled(i > 1)
    row.down:SetEnabled(i < #bars)
    row:Show()
  end
  for i = #bars + 1, #listRows do listRows[i]:Hide() end
  local class = G().stack.class
  f.loadNote:SetText(("Ticked bars load on %s. The library is shared by all your characters."):format(
    UnitName("player")) .. (class and ("\n|cfffbbf24Only on %s.|r"):format(
    LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class) or ""))

  local s = G().stack
  for _, sl in ipairs(groupSliders) do sl.sync() end
  f.anchor:GenerateMenu()
  f.class:GenerateMenu()
  f.inCombat:SetChecked(s.showInCombat)
  f.outCombat:SetChecked(s.showOutOfCombat)
  f.preview:SetChecked(BS.preview == true)
  f.hideBlizzard:SetChecked(BS.profile.hideBlizzard)
  f.combatNote:SetShown(BS.pending == true)

  f.right:SetShown(selected ~= nil)
  f.empty:SetShown(selected == nil)
  if f.picker and not selected then f.picker:Hide() end
  if editor and not selected then editor:Hide() end
  if settings and not selected then settings:Hide() end
  f.settings:SetEnabled(selected ~= nil)
  local b = selected
  if not b then return end
  f.iconsTitle:SetText("Icons  |cff71717a" .. b.name .. "|r")
  refreshSettings(b)
  f.add:SetEnabled(#b.icons < MAX_ICONS)
  for i, ic in ipairs(b.icons) do
    local row = iconRow(i)
    row.icon:SetTexture(BS.IconTexture(ic))
    row:SetText(summary(ic))
    row.up:SetEnabled(i > 1)
    row.down:SetEnabled(i < #b.icons)
    if ic == editing and editor and editor:IsShown() then row:LockHighlight() else row:UnlockHighlight() end
    row:Show()
  end
  for i = #b.icons + 1, #iconRows do iconRows[i]:Hide() end
  local notes = {}
  for _, rec in ipairs(BS.placed or {}) do
    if rec.barRef == b and rec.look ~= "custom" and not rec.frame then
      notes[#notes + 1] = "|cfff87171" .. rec.spell .. (rec.look == "aura"
        and ": not in Tracked Buffs. Tracked Bars is not read: move it to Tracked Buffs in the Cooldown Manager.|r"
        or ": not in the Cooldown Manager. Add it there.|r")
    end
  end
  if #b.icons == 0 then notes[#notes + 1] = "|cffa1a1aaAdd an icon, then pick its picture and when it shows.|r" end
  f.iconNote:ClearAllPoints()
  f.iconNote:SetPoint("TOPLEFT", C3 + 12, Y3 - 44 - #b.icons * 26)
  f.iconNote:SetText(table.concat(notes, "\n"))
  refreshEditor()
end

-- Wolfpack's options window calls this whenever its Bar Stack page is on screen
function BS.ShowConfig(parent)
  if not BS.profile then return end
  if not f then
    build(parent)
    preview(true) -- OnShow does this from then on; a new frame is already showing
  end
  BS.RefreshConfig()
end

function BS.ToggleConfig()
  if ns.ShowBarStack then ns.ShowBarStack() end
end
