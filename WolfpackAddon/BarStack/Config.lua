local _, ns = ...
ns.bs = ns.bs or {}
local BS = ns.bs
local ui = ns.ui

local VIS = { "always", "usable", "aura", "debuff", "missing", "proc" }
local VIS_TEXT = { always = "Always", usable = "Only while usable", aura = "Only while aura is active",
  debuff = "Only while debuff is active",
  missing = "Only while debuff is missing", proc = "Only while proc is active" }
BS.VIS, BS.VIS_TEXT = VIS, VIS_TEXT
local MAX_SPELLS = 8 -- ponytail: no scrolling in the spell list; a bar holds "one or a few" spells

-- Three columns of cards: the group, its bars, the picked bar (and its spells below it).
local W, H = 832, ui.BS_H
local C1, C2, C3 = 0, 242, 484
local W12, W3 = 230, 348
local BOTTOM = -500

local f, selected, dragFrom, group
local listRows, spellRows, pickRows = {}, {}, {}
local groupSliders, barSliders = {}, {}

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
  text(parent, s, x, y)
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
  local d = ui.Window(nil, w, h, title)
  d:SetParent(f)
  d:ClearAllPoints()
  d:SetPoint("TOPLEFT", f:GetParent(), "TOPRIGHT", 12, 0)
  return d
end

------------------------------------------------------------------------
-- Bar list (top = top layer, drag to reorder)
------------------------------------------------------------------------

local function listRow(i)
  if listRows[i] then return listRows[i] end
  local r = ui.Button(f.list, "", 196, true)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
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
-- Spell list + picker
------------------------------------------------------------------------

local function spellRow(i)
  if spellRows[i] then return spellRows[i] end
  local r = CreateFrame("Frame", nil, f.right)
  r:SetSize(W3 - 24, 22)
  r:SetPoint("TOPLEFT", C3 + 12, -324 - (i - 1) * 22)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT")
  r.name = r:CreateFontString(nil, "OVERLAY", ui.TEXT_LEFT)
  r.name:SetPoint("LEFT", 28, 0)
  r.name:SetWidth(240)
  r.remove = ui.Button(r, "Remove", 64, true)
  r.remove:SetPoint("RIGHT")
  r.remove:SetScript("OnClick", function()
    table.remove(selected.spells, i)
    changed()
  end)
  spellRows[i] = r
  return r
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
    table.insert(selected.spells, { baseSpell = self.sp.baseSpell, name = self.sp.name })
    f.picker:Hide()
    changed()
  end)
  pickRows[i] = r
  return r
end

local function showPicker()
  local p = f.picker
  if not p then
    p = dialog(270, 460, "Add spell")
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
  local buffsOnly = selected and BS.AURA_MODES[selected.visibility]
  p.hint:SetText(buffsOnly and "Tracked Buffs only:\nthat is all this bar's Show setting can use."
    or "Lists spells in Blizzard's Cooldown Manager.\nMissing one? Add it there first.")
  local spells = BS.AvailableSpells(buffsOnly)
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
-- Export / import
------------------------------------------------------------------------

local function showText(mode)
  local d = f.textDialog
  if not d then
    d = ui.Window(nil, 440, 280, "Profile string")
    d:SetParent(f)
    d:SetFrameLevel(f:GetFrameLevel() + 50)
    local sf = ui.Scroll(CreateFrame("ScrollFrame", nil, d, "UIPanelScrollFrameTemplate"))
    sf:SetPoint("TOPLEFT", 16, -48)
    sf:SetPoint("BOTTOMRIGHT", -32, 50)
    d.edit = CreateFrame("EditBox", nil, sf)
    d.edit:SetMultiLine(true)
    d.edit:SetFontObject(ui.SMALL)
    d.edit:SetWidth(380)
    d.edit:SetAutoFocus(false)
    d.edit:SetScript("OnEscapePressed", function() d:Hide() end)
    sf:SetScrollChild(d.edit)
    d.status = d:CreateFontString(nil, "OVERLAY", ui.DANGER)
    d.status:SetPoint("BOTTOMLEFT", 16, 20)
    d.ok = button(d, "Import", 100, nil, nil, function()
      if BS.Import(d.edit:GetText()) then
        d:Hide()
        group, selected = nil, nil
        BS.RefreshConfig()
      else
        d.status:SetText("Not a valid Bar Stack string.")
      end
    end)
    d.ok:SetPoint("BOTTOMRIGHT", -16, 14)
    f.textDialog = d
  end
  d.status:SetText("")
  d.ok:SetShown(mode == "import")
  d.edit:SetText(mode == "export" and (BS.Export() or "Export is unavailable on this client.") or "")
  d:Show()
  d.edit:SetFocus()
  d.edit:HighlightText()
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
  f:SetScript("OnHide", function() if BS.preview then preview(false) end end)

  ui.card(f, C1, 0, W12, -BOTTOM)
  ui.card(f, C2, 0, W12, -BOTTOM)
  ui.card(f, C3, 0, W3, 276)
  ui.card(f, C3, -288, W3, -288 - BOTTOM)

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
  slider(groupSliders, f, "Position X", x, -288, 206, -1000, 1000, 1,
    function() return S().x end, function(v) S().x = BS.Clamp(v, -3000, 3000) end)
  slider(groupSliders, f, "Position Y", x, -334, 206, -600, 600, 1,
    function() return S().y end, function(v) S().y = BS.Clamp(v, -3000, 3000) end)
  f.inCombat = checkbox(f, "Show in combat", x, -388, function(on) S().showInCombat = on; changed() end)
  f.outCombat = checkbox(f, "Show out of combat", x, -414, function(on) S().showOutOfCombat = on; changed() end)

  -- column 2: its bars (top = top layer, drag or Move up / down to reorder)
  x = C2 + 12
  text(f, "Bars", x, -12, "GameFontNormal")
  f.list = scroll(f, x, -40, 196, 340)
  button(f, "New", 64, x, -392, function()
    selected = BS.NewBar(G())
    changed()
  end)
  button(f, "Copy", 64, x + 70, -392, function()
    if not selected then return end
    local copy = CopyTable(selected)
    copy.id, copy.name = nil, selected.name .. " copy"
    table.insert(G().bars, tIndexOf(G().bars, selected), BS.NormalizeBar(copy))
    selected = copy
    changed()
  end)
  button(f, "Delete", 66, x + 140, -392, function()
    local i = selected and tIndexOf(G().bars, selected)
    if i then table.remove(G().bars, i); selected = nil; changed() end
  end)
  f.up = button(f, "Move up", 100, x, -422, function()
    if selected and BS.MoveBar(selected, -1) then changed() end
  end)
  f.down = button(f, "Move down", 100, x + 106, -422, function()
    if selected and BS.MoveBar(selected, 1) then changed() end
  end)
  local hint = text(f, "The top bar draws over the others. Drag one to reorder.", x, -458,
    "GameFontDisableSmall")
  hint:SetWidth(206)
  hint:SetJustifyH("LEFT")

  -- column 3: the selected bar, then its spells
  x = C3 + 12
  text(f, "Bar", x, -12, "GameFontNormal")
  f.empty = text(f, "No bars yet. Click New to create one.", x, -40, "GameFontDisableSmall")
  local r = CreateFrame("Frame", nil, f)
  r:SetAllPoints()
  f.right = r

  text(r, "Name", x, -40)
  f.name = input(r, x, -56, W3 - 24, false, function(v) selected.name = v end)
  text(r, "Show", x, -92)
  f.vis = dropdown(r, x, -108, 202, function()
    local out = {}
    for _, v in ipairs(VIS) do
      out[#out + 1] = { VIS_TEXT[v], function() return selected and selected.visibility == v end,
        function() selected.visibility = v; changed() end }
    end
    return out
  end)
  text(r, "Group", x + 210, -92)
  f.barGroup = dropdown(r, x + 210, -108, 114, function()
    return groupItems({ current = function() return selected and BS.GroupOf(selected) end,
      set = function(g) if BS.MoveToGroup(selected, g) then group = g; changed() end end })
  end)
  f.orient = button(r, "", 110, x, -144, function()
    selected.orientation = selected.orientation == "vertical" and "horizontal" or "vertical"
    changed()
  end)
  text(r, "Icons run this way", x + 118, -150, "GameFontDisableSmall")
  local B = function() return selected end
  local half = (W3 - 24 - 12) / 2
  slider(barSliders, r, "Icon width", x, -180, half, 8, 200, 1,
    function() return B() and B().size.w end, function(v) B().size.w = BS.Clamp(v, 1, 2000) end)
  slider(barSliders, r, "Icon height", x + half + 12, -180, half, 8, 200, 1,
    function() return B() and B().size.h end, function(v) B().size.h = BS.Clamp(v, 1, 2000) end)
  slider(barSliders, r, "Offset X", x, -226, half, -400, 400, 1,
    function() return B() and B().offset.x end, function(v) B().offset.x = BS.Clamp(v, -2000, 2000) end)
  slider(barSliders, r, "Offset Y", x + half + 12, -226, half, -400, 400, 1,
    function() return B() and B().offset.y end, function(v) B().offset.y = BS.Clamp(v, -2000, 2000) end)

  text(r, "Spells", x, -300, "GameFontNormal")
  f.add = button(r, "Add spell", 90, C3 + W3 - 102, -296, showPicker)
  -- why a spell on this bar shows nothing, said where you are looking rather than in /bs check
  f.spellNote = text(r, "", x, -328, "GameFontNormalSmall")
  f.spellNote:SetWidth(W3 - 24)
  f.spellNote:SetJustifyH("LEFT")
  BS.cfg = f
  f.groupSliders, f.barSliders = groupSliders, barSliders

  -- footer: what the whole profile shares
  f.preview = checkbox(f, "Show all bars", 2, -516, preview)
  f.combatNote = text(f, "Changes apply after combat.", 150, -516, "GameFontRedSmall")
  button(f, "Icon style", 96, W - 268, -512, BS.ShowIconStyle)
  button(f, "Export", 80, W - 166, -512, function() showText("export") end)
  button(f, "Import", 80, W - 80, -512, function() showText("import") end)
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
    row:SetText(("|cff71717a%d|r   %s"):format(#bars - i + 1, b.name))
    if b == selected then row:LockHighlight() else row:UnlockHighlight() end
    row:Show()
  end
  for i = #bars + 1, #listRows do listRows[i]:Hide() end
  local at = selected and tIndexOf(bars, selected)
  f.up:SetEnabled(at ~= nil and at > 1)
  f.down:SetEnabled(at ~= nil and at < #bars)

  local s = G().stack
  for _, sl in ipairs(groupSliders) do sl.sync() end
  f.inCombat:SetChecked(s.showInCombat)
  f.outCombat:SetChecked(s.showOutOfCombat)
  f.preview:SetChecked(BS.preview == true)
  f.combatNote:SetShown(BS.pending == true)

  f.right:SetShown(selected ~= nil)
  f.empty:SetShown(selected == nil)
  if f.picker and not selected then f.picker:Hide() end
  local b = selected
  if not b then return end
  if not f.name:HasFocus() then f.name:SetText(b.name) end
  f.vis:GenerateMenu()
  f.barGroup:GenerateMenu()
  for _, sl in ipairs(barSliders) do sl.sync() end
  f.orient:SetText(b.orientation == "vertical" and "Vertical" or "Horizontal")
  f.add:SetEnabled(#b.spells < MAX_SPELLS)
  for i, sp in ipairs(b.spells) do
    local row = spellRow(i)
    row.icon:SetTexture((C_Spell and BS.try(C_Spell.GetSpellTexture, sp.baseSpell)) or 134400)
    row.name:SetText(sp.name or ("Spell " .. sp.baseSpell))
    row:Show()
  end
  for i = #b.spells + 1, #spellRows do spellRows[i]:Hide() end
  local notes = {}
  for _, rec in ipairs(BS.placed or {}) do
    if rec.barRef == b and not rec.frame and b.visibility ~= "usable" then
      notes[#notes + 1] = "|cfff87171" .. rec.spell .. (BS.AURA_MODES[b.visibility]
        and ": not in Tracked Buffs. Add it there in the Cooldown Manager.|r"
        or ": not in the Cooldown Manager. Add it there.|r")
    end
  end
  if b.visibility == "usable" then
    notes[#notes + 1] = "|cffa1a1aaShows while " .. (b.spells[1] and b.spells[1].name or "its spell")
      .. " can be pressed: enough rage, a low enough target, or a proc -- as your action bar shows it."
      .. (#b.spells > 1 and " The first spell decides." or "") .. "|r"
  end
  if BS.TARGET_MODES[b.visibility] and not UnitExists("target") then
    notes[#notes + 1] = "|cfffbbf24Shows only while you have a target.|r"
  end
  f.spellNote:ClearAllPoints()
  f.spellNote:SetPoint("TOPLEFT", C3 + 12, -328 - #b.spells * 22)
  f.spellNote:SetText(table.concat(notes, "\n"))
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
