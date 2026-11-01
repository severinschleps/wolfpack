local _, ns = ...
ns.bs = ns.bs or {}
local BS = ns.bs

local VIS = { "always", "aura", "proc" }
local VIS_TEXT = { always = "Always", aura = "While aura active", proc = "While proc active" }
local MAX_SPELLS = 8 -- ponytail: no scrolling in the spell list; a bar holds "one or a few" spells
local RIGHT = 210

local f, selected, dragFrom
local listRows, spellRows, pickRows = {}, {}, {}

local function changed()
  BS.Changed()
  BS.RefreshConfig()
end

local function text(parent, s, x, y, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(s)
  return fs
end

local function button(parent, s, w, x, y, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(s)
  if x then b:SetPoint("TOPLEFT", x, y) end
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function input(parent, x, y, w, numeric, set)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(w, 20)
  e:SetPoint("TOPLEFT", x + 6, y)
  e:SetAutoFocus(false)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  e:SetScript("OnEscapePressed", function(self) BS.RefreshConfig(); self:ClearFocus() end)
  e:SetScript("OnEditFocusLost", function(self)
    local v = self:GetText()
    if numeric then v = tonumber(v) end
    if v and v ~= "" then set(v); changed() else BS.RefreshConfig() end
  end)
  return e
end

local function checkbox(parent, s, x, y, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c:SetPoint("TOPLEFT", x, y)
  local fs = c.Text or c.text
  if fs then fs:SetText(s) end
  c:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
  return c
end

local function scroll(parent, x, y, w, h)
  local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", x, y)
  sf:SetSize(w, h)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(w, 1)
  sf:SetScrollChild(child)
  return child
end

local function window(name, w, h, title)
  local d = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
  d:SetSize(w, h)
  d:SetFrameStrata("DIALOG")
  d:SetToplevel(true)
  d:EnableMouse(true)
  if d.TitleText then d.TitleText:SetText(title) end
  return d
end

------------------------------------------------------------------------
-- Bar list (top = top layer, drag to reorder)
------------------------------------------------------------------------

local function listRow(i)
  if listRows[i] then return listRows[i] end
  local r = CreateFrame("Button", nil, f.list)
  r:SetSize(166, 20)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
  r.text:SetPoint("LEFT", 4, 0)
  r.text:SetPoint("RIGHT", -4, 0)
  r:RegisterForDrag("LeftButton")
  r:SetScript("OnClick", function(self)
    selected = BS.profile.bars[self.index]
    BS.RefreshConfig()
  end)
  r:SetScript("OnDragStart", function(self) dragFrom = self.index end)
  r:SetScript("OnDragStop", function()
    local bars = BS.profile.bars
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
  r:SetSize(420, 20)
  r:SetPoint("TOPLEFT", RIGHT, -180 - (i - 1) * 22)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT")
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.name:SetPoint("LEFT", 24, 0)
  r.name:SetWidth(220)
  r.name:SetJustifyH("LEFT")
  r.display = button(r, "", 60, nil, nil, function()
    local sp = selected.spells[i]
    sp.display = sp.display == "bar" and "icon" or "bar"
    changed()
  end)
  r.display:SetPoint("LEFT", 250, 0)
  r.remove = button(r, "X", 24, nil, nil, function()
    table.remove(selected.spells, i)
    changed()
  end)
  r.remove:SetPoint("LEFT", 316, 0)
  spellRows[i] = r
  return r
end

local function pickRow(i)
  if pickRows[i] then return pickRows[i] end
  local r = CreateFrame("Button", nil, f.picker.list)
  r:SetSize(210, 20)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT")
  r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
  r.text:SetPoint("LEFT", 24, 0)
  r:SetScript("OnClick", function(self)
    table.insert(selected.spells, { baseSpell = self.sp.baseSpell, name = self.sp.name, display = "icon" })
    f.picker:Hide()
    changed()
  end)
  pickRows[i] = r
  return r
end

local function showPicker()
  local p = f.picker
  if not p then
    p = window(nil, 260, 420, "Add spell")
    p:SetParent(f)
    p:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
    local hint = text(p, "Lists spells in Blizzard's Cooldown Manager.\nMissing one? Add it there first.", 14, -32, "GameFontHighlightSmall")
    hint:SetJustifyH("LEFT")
    button(p, "Open Cooldown Manager", 180, 14, -62, function()
      if not pcall(function() CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown()) end) then
        print("|cffC79C6EBar Stack|r: open it from Options > Gameplay Enhancements > Cooldown Manager.")
      end
    end)
    p.empty = text(p, "No spells found. Is the Cooldown Manager on?", 14, -96, "GameFontDisableSmall")
    p.list = scroll(p, 12, -96, 210, 310)
    f.picker = p
  end
  local spells = BS.AvailableSpells()
  p.list:SetHeight(math.max(1, #spells * 22))
  for i, sp in ipairs(spells) do
    local r = pickRow(i)
    r.sp = sp
    r.icon:SetTexture(sp.icon or 134400)
    r.text:SetText(sp.name)
    r:Show()
  end
  for i = #spells + 1, #pickRows do pickRows[i]:Hide() end
  p.empty:SetShown(#spells == 0)
  p:Show()
end

------------------------------------------------------------------------
-- Export / import
------------------------------------------------------------------------

local function showText(mode)
  local d = f.textDialog
  if not d then
    d = window(nil, 420, 260, "Profile string")
    d:SetParent(f)
    d:SetPoint("CENTER", f)
    d:SetFrameLevel(f:GetFrameLevel() + 50)
    local sf = CreateFrame("ScrollFrame", nil, d, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -30)
    sf:SetPoint("BOTTOMRIGHT", -32, 44)
    d.edit = CreateFrame("EditBox", nil, sf)
    d.edit:SetMultiLine(true)
    d.edit:SetFontObject(ChatFontNormal)
    d.edit:SetWidth(370)
    d.edit:SetAutoFocus(false)
    d.edit:SetScript("OnEscapePressed", function() d:Hide() end)
    sf:SetScrollChild(d.edit)
    d.status = d:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    d.status:SetPoint("BOTTOMLEFT", 14, 16)
    d.ok = button(d, "Import", 100, nil, nil, function()
      if BS.Import(d.edit:GetText()) then
        d:Hide()
        selected = nil
        BS.RefreshConfig()
      else
        d.status:SetText("Not a valid Bar Stack string.")
      end
    end)
    d.ok:SetPoint("BOTTOMRIGHT", -14, 10)
    f.textDialog = d
  end
  d.status:SetText("")
  d.ok:SetShown(mode == "import")
  d.edit:SetText(mode == "export" and (BS.Export() or "Export is unavailable on this client.") or "")
  d:Show()
  d.edit:SetFocus()
  d.edit:HighlightText()
end

local function pickColor()
  local b = selected
  local r0, g0, b0 = BS.Hex(b.style.color)
  local function set(r, g, bl)
    b.style.color = ("#%02X%02X%02X"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(bl * 255 + 0.5))
    changed()
  end
  ColorPickerFrame:SetupColorPickerAndShow({
    r = r0, g = g0, b = b0,
    swatchFunc = function() set(ColorPickerFrame:GetColorRGB()) end,
    cancelFunc = function() set(r0, g0, b0) end,
  })
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------

local function build()
  f = window("BarStackConfig", 660, 500, "Bar Stack")
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetScript("OnHide", function()
    if BS.preview then BS.preview = false; BS.Apply() end
  end)
  tinsert(UISpecialFrames, "BarStackConfig")

  -- left: bar list
  text(f, "Bars (top = top layer, drag to reorder)", 14, -32)
  f.list = scroll(f, 12, -50, 166, 306)
  f.up = button(f, "Move up", 82, 12, -364, function()
    if selected and BS.MoveBar(selected, -1) then changed() end
  end)
  f.down = button(f, "Move down", 82, 96, -364, function()
    if selected and BS.MoveBar(selected, 1) then changed() end
  end)
  button(f, "New", 58, 12, -388, function()
    selected = BS.NewBar()
    changed()
  end)
  button(f, "Copy", 58, 72, -388, function()
    if not selected then return end
    local copy = CopyTable(selected)
    copy.id, copy.name = nil, selected.name .. " copy"
    table.insert(BS.profile.bars, tIndexOf(BS.profile.bars, selected), BS.NormalizeBar(copy))
    selected = copy
    changed()
  end)
  button(f, "Delete", 58, 132, -388, function()
    local i = selected and tIndexOf(BS.profile.bars, selected)
    if i then table.remove(BS.profile.bars, i); selected = nil; changed() end
  end)

  -- right: selected bar
  f.empty = text(f, "No bars yet. Click New to create one.", RIGHT, -60, "GameFontDisable")
  local r = CreateFrame("Frame", nil, f)
  r:SetAllPoints()
  f.right = r

  text(r, "Name", RIGHT, -32)
  f.name = input(r, RIGHT, -46, 200, false, function(v) selected.name = v end)
  text(r, "Visibility", 430, -32)
  f.vis = button(r, "", 170, 430, -46, function()
    selected.visibility = VIS[(tIndexOf(VIS, selected.visibility) or 0) % #VIS + 1]
    changed()
  end)

  local nums = {
    { "Width", function(v) selected.size.w = BS.Clamp(v, 1, 2000) end },
    { "Height", function(v) selected.size.h = BS.Clamp(v, 1, 2000) end },
    { "Offset X", function(v) selected.offset.x = BS.Clamp(v, -2000, 2000) end },
    { "Offset Y", function(v) selected.offset.y = BS.Clamp(v, -2000, 2000) end },
  }
  f.nums = {}
  for i, n in ipairs(nums) do
    local x = RIGHT + (i - 1) * 80
    text(r, n[1], x, -78)
    f.nums[i] = input(r, x, -92, 60, true, n[2])
  end

  f.orient = button(r, "", 110, RIGHT, -124, function()
    selected.orientation = selected.orientation == "vertical" and "horizontal" or "vertical"
    changed()
  end)
  f.tex = button(r, "", 120, RIGHT + 118, -124, function()
    selected.style.texture = selected.style.texture == "flat" and "blizzard" or "flat"
    changed()
  end)
  button(r, "Color", 70, RIGHT + 246, -124, pickColor)
  f.swatch = r:CreateTexture(nil, "ARTWORK")
  f.swatch:SetSize(20, 20)
  f.swatch:SetPoint("TOPLEFT", RIGHT + 322, -125)

  text(r, "Spells", RIGHT, -160)
  f.add = button(r, "Add spell", 100, RIGHT + 236, -154, showPicker)

  -- bottom: stack + tools
  text(f, "Stack", 14, -420)
  text(f, "Scale", 60, -420, "GameFontHighlightSmall")
  f.scale = input(f, 92, -416, 40, true, function(v) BS.profile.stack.scale = BS.Clamp(v, 0.3, 3) end)
  text(f, "Opacity", 150, -420, "GameFontHighlightSmall")
  f.alpha = input(f, 194, -416, 40, true, function(v) BS.profile.stack.alpha = BS.Clamp(v, 0, 1) end)
  f.inCombat = checkbox(f, "Show in combat", 260, -414, function(on) BS.profile.stack.showInCombat = on; changed() end)
  f.outCombat = checkbox(f, "Show out of combat", 400, -414, function(on) BS.profile.stack.showOutOfCombat = on; changed() end)

  f.preview = checkbox(f, "Show all bars", 12, -452, function(on)
    BS.preview = on
    BS.Apply()
  end)
  button(f, "Export", 80, 400, -454, function() showText("export") end)
  button(f, "Import", 80, 486, -454, function() showText("import") end)
  f.combatNote = text(f, "Changes apply after combat.", 140, -458, "GameFontRedSmall")
end

function BS.RefreshConfig()
  if not (f and f:IsShown()) then return end
  local bars = BS.profile.bars
  if not tContains(bars, selected) then selected = bars[1] end

  f.list:SetHeight(math.max(1, #bars * 22))
  for i, b in ipairs(bars) do
    local row = listRow(i)
    row.index = i
    row.text:SetText(("|cff888888%d|r  %s"):format(#bars - i + 1, b.name))
    if b == selected then row:LockHighlight() else row:UnlockHighlight() end
    row:Show()
  end
  for i = #bars + 1, #listRows do listRows[i]:Hide() end
  local at = selected and tIndexOf(bars, selected)
  f.up:SetEnabled(at ~= nil and at > 1)
  f.down:SetEnabled(at ~= nil and at < #bars)

  local s = BS.profile.stack
  f.scale:SetText(tostring(s.scale))
  f.alpha:SetText(tostring(s.alpha))
  f.inCombat:SetChecked(s.showInCombat)
  f.outCombat:SetChecked(s.showOutOfCombat)
  f.preview:SetChecked(BS.preview == true)
  f.combatNote:SetShown(BS.pending == true)

  f.right:SetShown(selected ~= nil)
  f.empty:SetShown(selected == nil)
  if f.picker and not selected then f.picker:Hide() end
  local b = selected
  if not b then return end
  f.name:SetText(b.name)
  f.vis:SetText(VIS_TEXT[b.visibility])
  local vals = { b.size.w, b.size.h, b.offset.x, b.offset.y }
  for i, e in ipairs(f.nums) do e:SetText(tostring(vals[i])) end
  f.orient:SetText(b.orientation == "vertical" and "Vertical" or "Horizontal")
  f.tex:SetText("Texture: " .. b.style.texture)
  f.swatch:SetColorTexture(BS.Hex(b.style.color))
  f.add:SetEnabled(#b.spells < MAX_SPELLS)
  for i, sp in ipairs(b.spells) do
    local row = spellRow(i)
    row.icon:SetTexture((C_Spell and BS.try(C_Spell.GetSpellTexture, sp.baseSpell)) or 134400)
    row.name:SetText(sp.name or ("Spell " .. sp.baseSpell))
    row.display:SetText(sp.display == "bar" and "Bar" or "Icon")
    row.display:SetShown(b.visibility ~= "always")
    row:Show()
  end
  for i = #b.spells + 1, #spellRows do spellRows[i]:Hide() end
end

function BS.ToggleConfig()
  if not BS.profile then return end
  if not f then build() end
  f:SetShown(not f:IsShown())
  BS.RefreshConfig()
end
