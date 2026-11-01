-- The options look: flat dark panels, 1 px borders, rounded corners, one sans font. Wolfpack's
-- options and Bar Stack both build their widgets here, so the two can never drift apart.
local ADDON, ns = ...
local ui = {}
ns.ui = ui

-- Colors, zinc-dark. Every widget reads these; nothing below hardcodes its own.
local C = {
  bg = { 0.035, 0.035, 0.043, 0.97 },
  card = { 0.063, 0.063, 0.071, 1 },
  border = { 0.153, 0.153, 0.165, 1 },
  input = { 0.035, 0.035, 0.043, 1 },
  secondary = { 0.153, 0.153, 0.165, 1 },
  hover = { 0.247, 0.247, 0.275, 1 },
  accent = { 0.153, 0.153, 0.165, 1 },
  clear = { 0, 0, 0, 0 },
  fg = { 0.98, 0.98, 0.98, 1 },
  muted = { 0.631, 0.631, 0.667, 1 },
  dim = { 0.443, 0.443, 0.478, 1 },
  ring = { 0.443, 0.443, 0.478, 1 },
  danger = { 0.973, 0.443, 0.443, 1 },
}
ui.C = C
ui.BS_H = 596 -- Bar Stack's editor, on its page of the options window

local ROUND = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Round\\r"
local FACE = "Interface\\AddOns\\" .. ADDON .. "\\Fonts\\FiraSans-Medium.ttf"

local function paint(t, c) t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
ui.paint = paint

-- Fonts, by role. Copying a game font first keeps text readable if the file fails to load.
local function font(name, size, c, justify)
  local f = CreateFont(name)
  f:CopyFontObject(GameFontHighlight)
  f:SetFont(FACE, size, "")
  f:SetTextColor(c[1], c[2], c[3])
  if justify then f:SetJustifyH(justify) end
  return name
end
ui.TEXT = font("WolfpackUIText", 12, C.fg)
ui.TEXT_LEFT = font("WolfpackUITextLeft", 12, C.fg, "LEFT")
ui.SMALL = font("WolfpackUISmall", 11, C.fg)
ui.LABEL = font("WolfpackUILabel", 11, C.muted)
ui.MUTED = font("WolfpackUIMuted", 11, C.dim)
ui.DISABLED = font("WolfpackUIDisabled", 12, C.dim)
ui.HEADING = font("WolfpackUIHeading", 13, C.fg)
ui.TITLE = font("WolfpackUITitle", 16, C.fg)
ui.DANGER = font("WolfpackUIDanger", 11, C.danger)

-- The game font names the option code was written with, and what each one now is.
local MAP = {
  GameFontHighlight = ui.TEXT, GameFontHighlightLeft = ui.TEXT_LEFT, GameFontNormal = ui.HEADING,
  GameFontNormalLarge = ui.TITLE, GameFontNormalSmall = ui.LABEL, GameFontHighlightSmall = ui.SMALL,
  GameFontDisable = ui.MUTED, GameFontDisableSmall = ui.MUTED, GameFontRedSmall = ui.DANGER,
}
function ui.font(name) return MAP[name or "GameFontHighlight"] or name end

-- A rounded box on f: the border color as a shape, the fill 1 px inside it, each cut by a mask
-- (WoW has no border-radius). Covers `over` (a region of f), or all of f. Returns fill, border.
function ui.box(f, fill, edge, r, layer, over)
  r = r or 6
  over = over or f
  local function shape(inset, c, sub)
    local t = f:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    t:SetPoint("TOPLEFT", over, "TOPLEFT", inset, -inset)
    t:SetPoint("BOTTOMRIGHT", over, "BOTTOMRIGHT", -inset, inset)
    paint(t, c)
    local rr = math.max(1, r - inset)
    local m = f:CreateMaskTexture()
    m:SetAllPoints(t)
    m:SetTexture(ROUND .. rr .. ".tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetTextureSliceMargins(rr, rr, rr, rr)
    t:AddMaskTexture(m)
    return t
  end
  local border = edge and shape(0, edge, 0)
  return shape(edge and 1 or 0, fill, 1), border
end

-- Card: a raised rounded panel behind a group of settings. Drawn as textures on the page itself,
-- so every widget on the page stays in front of it.
function ui.card(parent, x, y, w, h)
  local area = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
  area:SetPoint("TOPLEFT", x, y)
  area:SetSize(w, h)
  area:SetColorTexture(0, 0, 0, 0)
  ui.box(parent, C.card, C.border, 8, "BACKGROUND", area)
  return area
end

-- Hover / selected / disabled for anything drawn with ui.box. LockHighlight is what the option
-- code already calls to mark the picked entry, so it is taken over to mean "selected".
local function states(b, body, base, on, fs, dimText)
  local function repaint()
    local enabled = b:IsEnabled()
    paint(body, (b.locked and on) or (b.hot and enabled and C.hover) or base)
    body:SetAlpha(enabled and 1 or 0.5)
    if fs and dimText and enabled then
      local c = (b.locked or b.hot) and C.fg or C.muted
      fs:SetTextColor(c[1], c[2], c[3])
    end
  end
  b:HookScript("OnEnter", function() b.hot = true; repaint() end)
  b:HookScript("OnLeave", function() b.hot = false; repaint() end)
  b:HookScript("OnEnable", repaint)
  b:HookScript("OnDisable", repaint)
  function b:LockHighlight() self.locked = true; repaint() end
  function b:UnlockHighlight() self.locked = false; repaint() end
  b.repaint = repaint
  repaint()
end

-- Button. ghost = no fill until hovered or selected, text to the left: the sidebar's look.
function ui.Button(parent, text, w, ghost)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 80, 24)
  local body = ui.box(b, ghost and C.clear or C.secondary, not ghost and C.border or nil, 6)
  local fs = b:CreateFontString(nil, "OVERLAY")
  b:SetFontString(fs)
  b:SetNormalFontObject(ui.TEXT)
  b:SetHighlightFontObject(ui.TEXT)
  b:SetDisabledFontObject(ui.DISABLED)
  if ghost then
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", 10, 0)
    fs:SetJustifyH("LEFT")
  end
  b:SetText(text or "")
  states(b, body, ghost and C.clear or C.secondary, ghost and C.accent or C.hover, fs, ghost)
  return b
end

-- Text field; the border lights up while you type in it.
function ui.Input(parent, w)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(w or 60, 24)
  e:SetAutoFocus(false)
  e:EnableMouse(true)
  e:SetFontObject(ui.TEXT_LEFT)
  e:SetTextInsets(8, 8, 0, 0)
  local _, edge = ui.box(e, C.input, C.border, 6)
  local function focus(on) paint(edge, on and C.ring or C.border) end
  e:HookScript("OnEditFocusGained", function() focus(true) end)
  e:HookScript("OnEditFocusLost", function() focus(false) end)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  focus(false)
  return e
end

-- Checkbox with its label in c.Text; the label is part of the click area.
function ui.Check(parent, text)
  local c = CreateFrame("CheckButton", nil, parent)
  c:SetSize(16, 16)
  ui.box(c, C.input, C.ring, 4)
  local on = ui.box(c, C.fg, nil, 4, "ARTWORK")
  local tick = c:CreateTexture(nil, "OVERLAY")
  tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  tick:SetDesaturated(true)
  tick:SetVertexColor(0.035, 0.035, 0.043)
  tick:SetPoint("CENTER", 0, 0)
  tick:SetSize(20, 20)
  local function sync()
    local checked = c:GetChecked() and true or false
    on:SetShown(checked)
    tick:SetShown(checked)
  end
  local set = c.SetChecked
  function c:SetChecked(v) set(self, v); sync() end
  c:HookScript("PostClick", sync) -- not OnClick: callers set that one, which drops hooks
  c.Text = c:CreateFontString(nil, "OVERLAY", ui.TEXT_LEFT)
  c.Text:SetPoint("LEFT", c, "RIGHT", 8, 0)
  c.Text:SetText(text or "")
  c:SetHitRectInsets(0, -((tonumber(c.Text:GetStringWidth()) or 0) + 8), -4, -4)
  sync()
  return c
end

-- Slider: a thin track, filled up to a round white thumb.
function ui.Slider(parent, w)
  local s = CreateFrame("Slider", nil, parent)
  s:SetSize(w or 120, 16)
  s:SetOrientation("HORIZONTAL")
  s:SetHitRectInsets(0, 0, -4, -4)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  paint(track, C.secondary)
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(14, 14)
  paint(thumb, C.fg)
  local m = s:CreateMaskTexture()
  m:SetAllPoints(thumb)
  m:SetTexture(ROUND .. "7.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetTextureSliceMargins(7, 7, 7, 7)
  thumb:AddMaskTexture(m)
  s:SetThumbTexture(thumb)
  local filled = s:CreateTexture(nil, "ARTWORK")
  filled:SetPoint("LEFT")
  filled:SetPoint("RIGHT", thumb, "CENTER")
  filled:SetHeight(4)
  paint(filled, C.muted)
  return s
end

-- Skins a WowStyle1DropdownTemplate button: its art goes, a flat box and a chevron take over.
function ui.Dropdown(dd)
  for _, r in ipairs({ dd:GetRegions() }) do
    if r:IsObjectType("Texture") then r:SetAlpha(0) end
  end
  local body = ui.box(dd, C.input, C.border, 6)
  local arrow = dd:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
  arrow:SetDesaturated(true)
  arrow:SetVertexColor(C.muted[1], C.muted[2], C.muted[3])
  arrow:SetSize(14, 14)
  arrow:SetPoint("RIGHT", -8, -3)
  if type(dd.Text) == "table" then dd.Text:SetFontObject(ui.TEXT_LEFT) end
  dd:HookScript("OnEnter", function() paint(body, C.accent) end)
  dd:HookScript("OnLeave", function() paint(body, C.input) end)
  return dd
end

-- Scroll frame from UIPanelScrollFrameTemplate: arrows gone, a slim thumb left.
function ui.Scroll(sf)
  pcall(function()
    local bar = sf.ScrollBar
    for _, k in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
      if bar[k] then bar[k]:SetAlpha(0); bar[k]:EnableMouse(false) end
    end
    for _, r in ipairs({ bar:GetRegions() }) do
      if r:IsObjectType("Texture") and r ~= bar:GetThumbTexture() then r:SetAlpha(0) end
    end
    local t = bar:GetThumbTexture()
    paint(t, C.hover)
    t:SetWidth(6)
  end)
  return sf
end

-- Window: flat panel, title at the left of a header strip, a close button, drag to move,
-- Escape closes it (when it has a name).
function ui.Window(name, w, h, title, header)
  header = header or 36
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(w, h)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  ui.box(f, C.bg, C.border, 10)
  local line = f:CreateTexture(nil, "ARTWORK")
  paint(line, C.border)
  line:SetPoint("TOPLEFT", 1, -header)
  line:SetPoint("TOPRIGHT", -1, -header)
  line:SetHeight(1)
  f.TitleText = f:CreateFontString(nil, "OVERLAY", ui.HEADING)
  f.TitleText:SetPoint("LEFT", f, "TOPLEFT", 16, -header / 2)
  f.TitleText:SetText(title or "")
  f.CloseButton = ui.Button(f, "x", 24, true)
  f.CloseButton:GetFontString():ClearAllPoints()
  f.CloseButton:GetFontString():SetPoint("CENTER", 0, 1)
  f.CloseButton:SetPoint("RIGHT", f, "TOPRIGHT", -8, -header / 2)
  f.CloseButton:SetScript("OnClick", function() f:Hide() end)
  if name then tinsert(UISpecialFrames, name) end
  return f
end
