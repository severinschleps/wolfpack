-- Bar Stack logic check outside the game: `luajit test/barstack.lua` from the repo root.
-- Stubs only what Core.lua / Stack.lua touch at load time and in the tested functions.

GetBuildInfo = function() return "12.0.0", "1", "", 120000 end
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
SlashCmdList = {}
time = os.time
tIndexOf = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end
tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
CopyTable = function(t)
  local c = {}
  for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end
  return c
end
local names = { [7384] = "Overpower", [7887] = "Overpower", [100] = "Charge" }
C_Spell = { GetSpellName = function(id) return names[id] end, GetSpellTexture = function() return 1 end }
local cvars = {}
C_CVar = {
  RegisterCVar = function(n, d) cvars[n] = cvars[n] or d end,
  SetCVar = function(n, v) cvars[n] = v end,
  GetCVar = function(n) return cvars[n] end,
}
-- fake encoder: keeps tables in a registry, pads the string so it spans several CVar chunks
local reg = {}
C_EncodingUtil = {
  SerializeCBOR = function(t) reg[#reg + 1] = CopyTable(t); return tostring(#reg) end,
  CompressString = function(s) return s end,
  DecompressString = function(s) return s end,
  EncodeBase64 = function(s) return s .. ":" .. ("x"):rep(600) end,
  DecodeBase64 = function(s) return s:match("^(%d+):") end,
  DeserializeCBOR = function(s) return reg[tonumber(s)] end,
}
UnitName = function() return "Tester" end
UnitExists = function(u) return u == "target" and S_target or false end
GetRealmName = function() return "Realm" end
GetSpecialization = function() return 1 end
InCombatLockdown = function() return false end

local ns = {}
assert(loadfile("WolfpackAddon/BarStack/Core.lua"))("WolfpackAddon", ns)
assert(loadfile("WolfpackAddon/BarStack/Stack.lua"))("WolfpackAddon", ns)
local BS = ns.bs
assert(BS and ns.ToggleConfig == nil, "Bar Stack keeps its names on its own table")
local realLayout = BS.Layout
BS.Layout = function() end

-- normalize garbage (e.g. a hostile import string)
local b = BS.NormalizeBar({ name = 5, size = { w = -3, h = 0 / 0 }, visibility = "nope", spells = { { baseSpell = 7384 }, "junk", { baseSpell = "x" } }, style = { texture = "../evil" } })
assert(b.name == "New bar" and b.size.w == 1 and b.size.h == 1)
assert(b.visibility == "always" and b.style == nil, "no bar styling: icons only")
assert(#b.spells == 1 and b.spells[1].name == "Overpower" and b.spells[1].display == nil)

-- size is one icon. A bar saved when size was the whole bar is cut into its spells, once
local old = BS.NormalizeBar({ size = { w = 240, h = 24 }, spells = { { baseSpell = 7384 }, { baseSpell = 100 } } })
assert(old.size.w == 120 and old.size.h == 24, "two spells on a 240 wide bar: 120 per icon")
assert(BS.NormalizeBar(old).size.w == 120, "and only once")
local oldV = BS.NormalizeBar({ size = { w = 30, h = 90 }, orientation = "vertical",
  spells = { { baseSpell = 7384 }, { baseSpell = 100 }, { baseSpell = 7887 } } })
assert(oldV.size.w == 30 and oldV.size.h == 30, "a vertical bar is cut along its height")
assert(BS.NormalizeBar({}).size.w == 36, "a new bar starts at one 36 px icon")

-- storage round trip through the CVar chunks (SavedVariables missing, like on Forever)
BarStackDB = nil
BS.LoadDB(); BS.LoadProfile()
BS.NewBar(BS.profile.groups[1]).name = "Proc"
BS.Save()
assert(cvars.barStackData3 ~= "" and cvars.barStackData40 == "", "payload should span a few chunks")
BarStackDB = nil
BS.LoadDB(); BS.LoadProfile()
assert(BS.cvFound and not BS.svFound)
assert(BS.profile.groups[1].bars[1].name == "Proc", "profile restored from CVars")

-- newest backend wins
BarStackDB = { updated = 1, profiles = {} }
BS.LoadDB()
assert(BS.db.profiles["Tester-Realm:1"], "CVar copy is newer than the stale SavedVariables")

-- import rejects junk, accepts an export
assert(not BS.Import("garbage"))
local s = BS.Export()
BS.profile.groups[1].bars = {}
assert(BS.Import(s) and BS.profile.groups[1].bars[1].name == "Proc")

-- a version 1 profile (one stack, one list of bars) becomes the first group, nothing lost
local old = BS.NormalizeProfile({ version = 1, stack = { x = 50, y = 60 }, bars = { { name = "Old" } } })
assert(old.version == 2 and #old.groups == 1 and old.stack == nil and old.bars == nil, "migrated to groups")
assert(old.groups[1].stack.x == 50 and old.groups[1].bars[1].name == "Old", "position and bars kept")
-- and an old export string still imports
BS.db.profiles["Tester-Realm:1"] = nil
assert(BS.Import(BS.Encode({ version = 1, bars = { { name = "Imported" } } })), "an old string imports")
assert(BS.profile.groups[1].bars[1].name == "Imported")

-- moving a bar up and down the stack, and not past either end
local g1 = BS.profile.groups[1]
g1.bars = {}
local low = BS.NewBar(g1); low.name = "Low"
local high = BS.NewBar(g1); high.name = "High" -- NewBar puts it at the top
assert(g1.bars[1] == high and g1.bars[2] == low)
assert(BS.MoveBar(low, -1) and g1.bars[1] == low, "Move up takes it a layer higher")
assert(not BS.MoveBar(low, -1), "nothing above the top layer")
assert(BS.MoveBar(low, 1) and g1.bars[2] == low, "Move down puts it back")
assert(not BS.MoveBar(low, 1), "nothing below the bottom layer")

-- groups: each is a stack of its own, and only an empty group goes
local g2 = BS.NewGroup()
assert(#BS.profile.groups == 2 and g2.name == "Stack 2" and g2.stack.y == -180, "a new group starts as its own stack")
assert(g2.stack ~= g1.stack, "with settings of its own")
local inG2 = BS.NewBar(g2)
assert(BS.GroupOf(inG2) == g2 and not BS.DeleteGroup(g2), "a group with bars is kept")
table.remove(g2.bars, 1)
assert(BS.DeleteGroup(g2) and #BS.profile.groups == 1, "an empty one goes")
assert(not BS.DeleteGroup(g1), "the last group always stays")

-- ranks: a frame showing rank 2 matches a widget saved with rank 1
local item = { GetSpellID = function() return 7887 end }
assert(BS.Matches(item, { baseSpell = 7384, name = "Overpower" }))
assert(not BS.Matches(item, { baseSpell = 100, name = "Charge" }))

-- picker groups ranks into one entry
EssentialCooldownViewer = { GetItemFrames = function() return { item, { GetSpellID = function() return 7384 end }, { cooldownInfo = { spellID = 100 } } } end }
local list = BS.AvailableSpells()
assert(#list == 2 and list[1].name == "Charge" and list[2].name == "Overpower")

-- a buff put on an "always" bar is still found: every viewer is searched, preferred ones first
local buff = { GetSpellID = function() return 100 end }
EssentialCooldownViewer = { GetItemFrames = function() return {} end }
BuffIconCooldownViewer = { GetItemFrames = function() return { buff } end }
local it, from = BS.Find({ baseSpell = 100, name = "Charge", display = "icon" }, "always", {})
assert(it == buff and from == "BuffIconCooldownViewer", "a buff on an always bar is found")
-- Avatar on an "only while aura is active" bar: its cooldown icon is always up, so it must not
-- be borrowed; only a buff viewer frame shows and hides with the aura
local avatarCD = { GetSpellID = function() return 107574 end }
names[107574] = "Avatar"
EssentialCooldownViewer = { GetItemFrames = function() return { avatarCD } end }
BuffIconCooldownViewer = { GetItemFrames = function() return {} end }
for _, mode in ipairs({ "aura", "debuff", "proc" }) do
  assert(BS.Find({ baseSpell = 107574, name = "Avatar", display = "icon" }, mode, {}) == nil,
    mode .. ": the always-up cooldown icon is not used")
end
local avatarBuff = { GetSpellID = function() return 107574 end }
BuffBarCooldownViewer = { GetItemFrames = function() return { avatarBuff } end }
assert(BS.Find({ baseSpell = 107574, name = "Avatar" }, "aura", {}) == nil, "Tracked Bars is never used: icons only")
BuffIconCooldownViewer = { GetItemFrames = function() return { avatarBuff } end }
assert(BS.Find({ baseSpell = 107574, name = "Avatar" }, "aura", {}) == avatarBuff, "Tracked Buffs is where an aura comes from")
assert(BS.Find({ baseSpell = 107574, name = "Avatar", display = "icon" }, "always", {}) == avatarCD,
  "an always bar still takes the cooldown")
BuffIconCooldownViewer, BuffBarCooldownViewer = nil, nil

-- the window: built against frames that answer anything, with the dropdown menus captured
local menus = {}
local function mock()
  return setmetatable({}, {
    __index = function(t, k)
      if k == "SetupMenu" then return function(self, fn) menus[#menus + 1] = fn end end
      if k == "SetScript" then return function(self, n, fn) rawset(self, "_on" .. n, fn) end end
      if k == "GetFrameLevel" or k == "GetScale" or k == "GetWidth" or k == "GetHeight" then return function() return 1 end end
      if k == "GetCenter" then return function() return 0, 0 end end
      if k == "SetAlpha" then return function(self, a) rawset(self, "_alpha", a) end end
      if k == "SetAlphaFromBoolean" then
        return function(self, v, yes, no) rawset(self, "_fromBool", { v, yes, no }) end
      end
      if k == "SetShown" then return function(self, v) rawset(self, "_shown", v) end end
      if k == "Hide" then return function(self) rawset(self, "_shown", false) end end
      if k == "Show" then return function(self) rawset(self, "_shown", true) end end
      if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
      if k == "SetTexCoord" then return function(self, ...) rawset(self, "_coords", { ... }) end end
      if k == "GetTexCoord" then return function(self) return unpack(rawget(self, "_coords") or { 0, 1, 0, 1 }) end end
      if k == "AddMaskTexture" then return function(self, m) rawset(self, "_mask", m) end end
      if k == "RemoveMaskTexture" then return function(self) rawset(self, "_mask", false) end end
      if k == "SetValue" then return function(self, v) rawset(self, "_value", v) end end
      if k == "GetAlpha" then return function(self) return rawget(self, "_alpha") or 1 end end
      local m = mock()
      rawset(t, k, m)
      return m
    end,
    __call = function() return mock() end,
  })
end
CreateFrame = function() return mock() end
CreateFont = function() return mock() end
UISpecialFrames, tinsert = {}, table.insert
assert(loadfile("WolfpackAddon/UI.lua"))("WolfpackAddon", ns)
assert(loadfile("WolfpackAddon/BarStack/Config.lua"))("WolfpackAddon", ns)
BS.NewBar(BS.profile.groups[1]).name = "Avatar bar"
BS.ShowConfig(mock())
assert(BS.preview == true, "the page opens with every bar shown")
-- the sliders move what they say: the picked bar inside its stack, and the stack on screen
local saves, realSave = 0, BS.Save
BS.Save = function() saves = saves + 1 end
local offX, posY = BS.cfg.barSliders[3], BS.cfg.groupSliders[4]
offX._onOnValueChanged(offX, 37.4)
assert(BS.profile.groups[1].bars[1].offset.x == 37, "Offset X moves the bar, in whole pixels")
posY._onOnValueChanged(posY, -220)
assert(BS.profile.groups[1].stack.y == -220, "Position Y moves the whole stack")
assert(saves == 0, "dragging saves nothing yet")
offX._onOnMouseUp(offX)
assert(saves == 1, "letting go saves")
BS.Save = realSave
BS.preview = nil -- what follows is about play, with the page closed
local function radios(fn)
  local out = {}
  fn(nil, { CreateRadio = function(_, text, isSel, set) out[#out + 1] = { text = text, isSel = isSel, set = set } end })
  return out
end
local vis
for _, fn in ipairs(menus) do
  local r = radios(fn)
  if r[1] and r[1].text == "Always" then vis = r end
end
assert(vis and #vis == 6, "the Show dropdown has six choices")
assert(vis[2].text == "Only while usable" and vis[3].text == "Only while aura is active"
  and vis[4].text == "Only while debuff is active" and vis[5].text == "Only while debuff is missing"
  and vis[6].text == "Only while proc is active", "named as asked")
vis[4].set()
assert(BS.profile.groups[1].bars[1].visibility == "debuff" and vis[4].isSel(), "picking one sets the bar")

-- a layout pass over two groups: one stack frame each, every spell accounted for
hooksecurefunc = function() end
local cdFrame = mock()
cdFrame.GetSpellID = function() return 100 end
EssentialCooldownViewer = { GetItemFrames = function() return { cdFrame } end }
local gA, gB = BS.profile.groups[1], BS.NewGroup()
gA.bars = {}
BS.NewBar(gA).spells = { { baseSpell = 100, name = "Charge", display = "icon" } }
BS.NewBar(gB).spells = { { baseSpell = 107574, name = "Avatar", display = "icon" } }
gB.bars[1].visibility = "aura"
BS.ready = true
realLayout()
assert(BS.stacks[gA.id] and BS.stacks[gB.id] and BS.stacks[gA.id] ~= BS.stacks[gB.id], "a stack frame per group")
assert(#BS.placed == 2 and BS.placed[1].frame == cdFrame and BS.placed[1].group == "Stack 1", "Charge placed in Stack 1")
assert(BS.placed[2].frame == nil and BS.placed[2].visibility == "aura", "Avatar has no buff frame, so nothing is borrowed")

-- the show-while-missing probe: an aura bar's frame has Blizzard's Show / Hide / SetAlpha counted
hooksecurefunc = function(t, m, fn)
  local orig = t[m]
  t[m] = function(...) local r = orig(...); fn(...); return r end
end
local buffFrame = mock()
buffFrame.GetSpellID = function() return 107574 end
for _, m in ipairs({ "Show", "Hide", "SetShown", "SetAlpha" }) do buffFrame[m] = function() end end
BuffIconCooldownViewer = { GetItemFrames = function() return { buffFrame } end }
realLayout()
assert(BS.placed[2].frame == buffFrame and BS.watch[buffFrame], "a borrowed buff frame is watched")
buffFrame:Hide(); buffFrame:Show(); buffFrame:Hide()
buffFrame:SetAlpha(0.5)
local w = BS.watch[buffFrame]
assert(w.Hide == 2 and w.Show == 1 and w.SetAlpha == 1 and not w.SetAlphaSecret, "every call counted: " .. w.Hide)
assert(BS.watch[cdFrame] == nil, "an always bar's cooldown frame is left alone")
local said, keptPrint = {}, print
print = function(t) said[#said + 1] = t end
BS.Check()
print = keptPrint
local probe
for _, t in ipairs(said) do if t:find("Blizzard called Show 1, Hide 2") then probe = t end end
assert(probe, "/bs check reports the calls")

-- "flash at % left": the time left is never read. Blizzard's duration object, caught as it is
-- handed to the icon's Cooldown, is asked through a step curve: 1 under the bar's %, 0 above
Enum = Enum or {}
Enum.LuaCurveType = { Step = 1 }
C_CurveUtil = { CreateCurve = function()
  local pts = {}
  return { SetType = function() end, AddPoint = function(_, x, y) pts[#pts + 1] = { x, y } end,
    at = function(_, x) local y for _, p in ipairs(pts) do if x >= p[1] then y = p[2] end end return y end }
end }
local function aura(left) return { EvaluateRemainingPercent = function(_, c) return c:at(left) end } end
local function flashOf(it) for _, v in ipairs(BS.flashes) do if v.it == it then return v end end end
buffFrame.Cooldown = { SetCooldownFromDurationObject = function() end }
gB.bars[1].flashAt = 20
realLayout()
local fx = flashOf(buffFrame)
assert(fx and fx.pct == 20, "an aura bar set to 20% gets a flash")
BS.UpdateFlashes()
assert(fx.frame._alpha == 0, "no duration yet: no flash")
buffFrame.Cooldown:SetCooldownFromDurationObject(aura(0.5))
BS.UpdateFlashes()
assert(fx.frame._alpha == 0, "half left: quiet")
buffFrame.Cooldown:SetCooldownFromDurationObject(aura(0.1))
BS.UpdateFlashes()
assert(fx.frame._alpha == 1 and BS.flashSeen.result == "working", "10% left: flashing")
BS.preview = true
BS.UpdateFlashes()
assert(fx.frame._alpha == 1, "with Show all bars on too: the options page is where it gets set up")
BS.preview = nil
assert(BS.cdCalls[buffFrame].SetCooldownFromDurationObject == 2, "/bs check can say how Blizzard set the cooldown")
gB.bars[1].flashAt = 0
realLayout()
BS.UpdateFlashes()
assert(not flashOf(buffFrame) and fx.frame._alpha == 0, "0%: off")
assert(BS.NormalizeBar({ flashLow = true }).flashAt == 25, "the old on / off flash becomes 25%")

-- "only while debuff is missing": Blizzard's Rend frame is parked out of sight, and our own Rend
-- icon shows exactly while Blizzard's frame is hidden
names[772] = "Rend"
local rendFrame = mock()
rendFrame.GetSpellID = function() return 772 end
rendFrame.shown = false
rendFrame.IsShown = function(self) return self.shown end
rendFrame.Show = function(self) self.shown = true end
rendFrame.Hide = function(self) self.shown = false end
rendFrame.SetShown = function(self, v) self.shown = v end
rendFrame.SetAlpha = function() end
rendFrame.SetParent = function(self, p) self.parent = p end
rendFrame.GetParent = function(self) return self.parent end
rendFrame.SetSize = function(self, w, h) self.w, self.h = w, h end
-- Blizzard drew it 36 x 36 at scale 1; that is its natural size
rendFrame.GetWidth = function(self) return self.w or 36 end
rendFrame.GetHeight = function(self) return self.h or 36 end
rendFrame.GetScale = function(self) return self.scale or 1 end
rendFrame.SetScale = function(self, v) self.scale = v end
-- a widget: its methods live on the metatable, the way the game hands them out
rendFrame.Cooldown = setmetatable({}, { __index = { SetCooldownFromDurationObject = function() end,
  SetCooldown = function() end, Clear = function() end, SetSwipeColor = function() end } })
BuffIconCooldownViewer = { GetItemFrames = function() return { rendFrame } end }
local rendBar = BS.NewBar(gA)
rendBar.visibility = "missing"
rendBar.spells = { { baseSpell = 772, name = "Rend", display = "icon" } }
realLayout()
local rec
for _, r in ipairs(BS.placed) do if r.spell == "Rend" then rec = r end end
assert(rec and rec.frame == rendFrame and rec.reminder, "Rend is watched and has a reminder icon")
assert(rendFrame.parent ~= rec.reminder and rendFrame.parent == rec.container, "Blizzard's frame is parked, not in the bar")
local rem = rec.reminder
assert(rem._alpha == 1, "no Rend on the target: the reminder shows")
rendFrame:Show()
assert(rem._alpha == 0, "Rend goes up: the reminder hides")
rendFrame:Hide()
assert(rem._alpha == 1, "Rend falls off: the reminder is back")
rendFrame:SetShown(true)
assert(rem._alpha == 0, "SetShown works the same way")
rendFrame:SetShown(false)
-- a frame that already shows Rend when the bar is laid out starts with the reminder hidden
rendFrame.shown = true
realLayout()
assert(rem._alpha == 0, "laid out with Rend up: hidden from the start")
-- a Rend that is not tracked at all still shows the reminder, and check says why
BuffIconCooldownViewer = { GetItemFrames = function() return {} end }
realLayout()
for _, r in ipairs(BS.placed) do if r.spell == "Rend" then rec = r end end
assert(rec.frame == nil and rec.reminder._alpha == 1, "untracked: the reminder stays up")
said = {}
print = function(t) said[#said + 1] = t end
BS.Check()
print = keptPrint
local why
for _, t in ipairs(said) do if t:find("Rend: not in Tracked Buffs") then why = t end end
assert(why, "/bs check says Rend needs tracking")
BuffIconCooldownViewer = { GetItemFrames = function() return { rendFrame } end }
realLayout()
said = {}
print = function(t) said[#said + 1] = t end
BS.Check()
print = keptPrint
for _, t in ipairs(said) do if t:find("Rend: watching") then why = t end end
assert(why:find("reminder icon"), "and reports the reminder once it is watched: " .. why)

-- debuff bars, active or missing, only show with a target; other bars do not care
local debuffBar = BS.NewBar(gA)
debuffBar.visibility = "debuff"
debuffBar.spells = { { baseSpell = 772, name = "Rend", display = "icon" } }
realLayout()
local frameOf = {}
for _, r in ipairs(BS.placed) do frameOf[r.bar] = frameOf[r.bar] or {}; frameOf[r.bar][r.visibility] = r.barFrame end
local missingC, debuffC = frameOf[rendBar.name].missing, frameOf[debuffBar.name].debuff
local alwaysC
for _, r in ipairs(BS.placed) do if r.spell == "Charge" then alwaysC = r.barFrame end end -- an always bar
S_target = false
BS.UpdateVisibility()
assert(missingC._shown == false and debuffC._shown == false, "no target: both debuff bars hide")
assert(alwaysC._shown == true, "an always bar stays")
S_target = true
BS.UpdateVisibility()
assert(missingC._shown == true and debuffC._shown == true, "a target: both are back")
S_target = false
BS.preview = true
BS.UpdateVisibility()
assert(missingC._shown == true and debuffC._shown == true, "Show all bars shows them anyway, to place them")
BS.preview = nil

-- one Rend, in Tracked Buffs, serves both: the "active" bar shows Blizzard's icon, the "missing"
-- bar watches that same frame and flips its own icon
rendFrame.shown = false
BuffIconCooldownViewer = { GetItemFrames = function() return { rendFrame } end }
realLayout()
local activeRec, missingRec
for _, r in ipairs(BS.placed) do
  if r.spell == "Rend" and r.visibility == "debuff" then activeRec = r end
  if r.spell == "Rend" and r.visibility == "missing" then missingRec = r end
end
assert(activeRec.frame == rendFrame and rendFrame.parent == activeRec.barFrame, "the active bar shows Blizzard's Rend icon")
assert(missingRec.frame == rendFrame, "the missing bar watches the very same frame")
assert(missingRec.reminder._alpha == 1, "no Rend: the missing icon shows")
rendFrame:Show()
assert(missingRec.reminder._alpha == 0 and rendFrame.parent == activeRec.barFrame,
  "Rend up: the icon hides, and the frame stays in the active bar")
rendFrame:Hide()
assert(missingRec.reminder._alpha == 1, "Rend off: the icon is back")
-- the plates come and go with their icons: the missing icon's plate is switched with it, and
-- the active icon's plate sits on Blizzard's own frame, so Blizzard hiding it hides the plate
local missingPlate = BS.borderOf[missingRec.reminder]
assert(missingPlate and missingPlate._alpha == 1, "Rend off: the missing icon's plate shows")
rendFrame:Show()
assert(missingPlate._alpha == 0, "Rend up: the missing icon's plate hides with it")
rendFrame:Hide()
-- and it can flash early: its own icon pulses while Rend is still up with under 15% left, so the
-- reapply comes before the gap. Once Rend is gone the plain reminder takes over, without a flash
missingRec.barRef.flashAt = 15
realLayout()
local ef, up = flashOf(rendFrame), BS.mirrorUp[rendFrame] and BS.mirrorUp[rendFrame][1]
assert(ef and ef.pct == 15 and up, "the missing bar has an early flash")
rendFrame:Show()
assert(up._alpha == 1, "Rend up: the early flash may show")
rendFrame.Cooldown:SetCooldownFromDurationObject(aura(0.5))
BS.UpdateFlashes()
assert(ef.frame._alpha == 0, "half left: quiet")
rendFrame.Cooldown:SetCooldownFromDurationObject(aura(0.1))
BS.UpdateFlashes()
assert(ef.frame._alpha == 1, "10% left: the reminder flashes before Rend is gone")
rendFrame:Hide()
assert(up._alpha == 0 and missingRec.reminder._alpha == 1, "Rend gone: the steady reminder, no flash")
missingRec.barRef.flashAt = 0
realLayout()

-- sizes are what the bar says, on screen: frame size times its scale. Size is one icon (36 x 36
-- for a new bar), square, scaled from Blizzard's own size, never stretched
local function shown(f) return f.w * f.scale, f.h * f.scale end
local sw_, sh_ = shown(rendFrame)
assert(rendFrame.w == 36 and rendFrame.h == 36, "the icon keeps its own shape")
assert(math.abs(sw_ - 36) < 0.01 and math.abs(sh_ - 36) < 0.01, "and is 36 x 36 on screen: " .. sw_)
debuffBar.size.w, debuffBar.size.h = 40, 40
realLayout()
sw_, sh_ = shown(rendFrame)
assert(math.abs(sh_ - 40) < 0.01, "a 40 px icon is 40 px on screen: " .. sh_)
debuffBar.size.w, debuffBar.size.h = 36, 36
local three = { size = { w = 40, h = 30 }, spells = { 1, 2, 3 } }
assert(select(1, BS.BarSize(three)) == 120 and select(2, BS.BarSize(three)) == 30, "the bar is three icons wide")
three.orientation = "vertical"
assert(select(1, BS.BarSize(three)) == 40 and select(2, BS.BarSize(three)) == 90, "or three tall")
three.gap = 5
assert(select(2, BS.BarSize(three)) == 100, "with a 5 px gap between each two")
three.orientation = nil
assert(select(1, BS.BarSize(three)) == 130, "either way")
-- and no Icon / Bar choice is left in the window
BS.RefreshConfig()
for _, fn in ipairs(menus) do
  local r = radios(fn)
  assert(not (r[1] and r[1].text == "Icon"), "the Icon / Bar dropdown is gone")
end

-- sent home: Blizzard's own size and scale come back
BuffIconCooldownViewer = { GetItemFrames = function() return {} end }
realLayout()
assert(rendFrame.scale == 1 and rendFrame.w == 36 and rendFrame.h == 36, "returned the way it came")
BuffIconCooldownViewer = nil

-- a frame Blizzard has dropped no longer answers for its spell: when Blizzard moves Rend to a new
-- icon frame, the bars follow it rather than the old frame we once borrowed
local oldIcon = mock()
oldIcon.GetSpellID = function() return 772 end
BuffIconCooldownViewer = { GetItemFrames = function() return { oldIcon } end }
oldIcon.GetParent = function(self) return rawget(self, "parent") or BuffIconCooldownViewer end
oldIcon.SetParent = function(self, p) rawset(self, "parent", p) end
realLayout() -- the missing bar borrows the old icon while it is the only Rend there is
-- Blizzard lists only what is still inside its viewer: the borrowed icon is off its list, and
-- must still be found -- this is what went wrong in game, every frame we had placed went missing
BuffIconCooldownViewer.GetItemFrames = function() return {} end
realLayout()
for _, r in ipairs(BS.placed) do
  if r.spell == "Rend" then assert(r.frame == oldIcon, "a frame we placed is still ours, though Blizzard no longer lists it") end
end
-- in combat its spell comes back secret: the last readable answer stands
issecretvalue = function(v) return v == "SECRET" end
oldIcon.GetSpellID = function() return "SECRET" end
assert(BS.FrameSpell(oldIcon) == 772, "secret: the frame is still Rend's")
-- Blizzard clears the old icon, which then answers nothing
oldIcon.GetSpellID = function() return nil end
assert(BS.FrameSpell(oldIcon) == nil, "cleared: it no longer stands for Rend")
issecretvalue = nil
local newIcon = mock()
newIcon.GetSpellID = function() return 772 end
BuffIconCooldownViewer.GetItemFrames = function() return { newIcon } end
realLayout()
for _, r in ipairs(BS.placed) do
  if r.spell == "Rend" then assert(r.frame == newIcon, r.visibility .. " bar follows Rend to its new frame") end
end
-- /bs frames lists every frame with each way of asking its spell, and survives what it cannot ask
said = {}
print = function(t) said[#said + 1] = t end
BS.Frames()
print = keptPrint
local listed
for _, t in ipairs(said) do if t:find("GetSpellID 772") and t:find("ours 772") then listed = t end end
assert(listed, "a frame line names what each question answered: " .. table.concat(said, " / "))
BuffIconCooldownViewer, BuffBarCooldownViewer = nil, nil

-- the window says, under the spell list, why the selected bar shows nothing
realLayout()
BS.RefreshConfig()
local note = BS.cfg.spellNote._text or ""
assert(note:find("Rend: not in Tracked Buffs"), "an untracked debuff is named: " .. note)
assert(note:find("only while you have a target"), "and so is the target rule: " .. note)

-- "Only while usable": Execute shows exactly while WoW says it can be pressed -- rage, a target
-- under the threshold, or a Sudden Death proc all go into that one answer
names[163201] = "Execute"
local exFrame = mock()
exFrame.GetSpellID = function() return 163201 end
EssentialCooldownViewer = { GetItemFrames = function() return { exFrame } end }
local usableNow = false
C_Spell.IsSpellUsable = function(id) assert(id == 163201); return usableNow end
local exBar = BS.NewBar(gA)
exBar.visibility = "usable"
exBar.spells = { { baseSpell = 163201, name = "Execute" } }
realLayout()
local exC
local exRec
for _, r in ipairs(BS.placed) do if r.spell == "Execute" then exC, exRec = r.barFrame, r end end
-- Blizzard's Execute frame stays with Blizzard: moved out of its viewer it froze in its
-- "not usable" look (seen in game). The bar draws a plain Execute icon of its own instead
assert(exRec.frame == nil and rawget(exFrame, "parent") == nil, "Blizzard's frame is not borrowed")
assert(exRec.reminder and exRec.reminder._alpha == 1, "our own icon, always the usable look")
assert(exC._alpha == 0, "not usable: hidden")
usableNow = true
BS.UpdateUsable() -- what SPELL_UPDATE_USABLE does
assert(exC._alpha == 1, "usable: shown")
-- in combat the answer may come back secret: it is handed on unread
issecretvalue = function(v) return v == "SECRET" end
usableNow = "SECRET"
BS.UpdateUsable()
assert(exC._fromBool and exC._fromBool[1] == "SECRET" and exC._fromBool[2] == 1 and exC._fromBool[3] == 0,
  "a secret answer drives the opacity without being read")
issecretvalue = nil
-- placing it shows it anyway, and a bar switched to another mode is never left invisible
usableNow = false
BS.UpdateUsable()
BS.preview = true
BS.UpdateUsable()
assert(exC._alpha == 1, "Show all bars shows it")
BS.preview = nil
exBar.visibility = "always"
BS.UpdateUsable()
assert(exC._alpha == 1, "back to Always: visible again")
said = {}
exBar.visibility = "usable"
realLayout()
print = function(t) said[#said + 1] = t end
BS.Check()
print = keptPrint
local seenLine
for _, t in ipairs(said) do if t:find("Execute: own icon; usable right now: false") then seenLine = t end end
assert(seenLine, "/bs check says what WoW answered")
-- a cooldown swipe over the icon, fed WoW's duration object unread; the icon itself stays put
local exSwipe = exRec.swipe
assert(exSwipe, "the icon has a cooldown swipe")
local fedWith
exSwipe.SetCooldownFromDurationObject = function(_, d) fedWith = d end
C_Spell.GetSpellCooldownDuration = function(id) assert(id == 163201); return { "Execute's cooldown" } end
usableNow = true
BS.UpdateUsable() -- what SPELL_UPDATE_COOLDOWN does
assert(fedWith and fedWith[1] == "Execute's cooldown" and BS.swipeSeen[exBar.id] == "duration object",
  "the swipe plays the duration object")
assert(exRec.reminder._alpha == 1, "the swipe never hides the icon")
-- a client without the duration object: start and duration go to the swipe instead
C_Spell.GetSpellCooldownDuration = nil
local fedStart
exSwipe.SetCooldown = function(_, start, dur) fedStart = start .. "/" .. dur end
C_Spell.GetSpellCooldown = function() return { startTime = 100, duration = 6, modRate = 1 } end
BS.UpdateUsable()
assert(fedStart == "100/6" and BS.swipeSeen[exBar.id] == "start and duration", "the fallback route")
-- neither: each refusal is kept, word for word
C_Spell.GetSpellCooldown = nil
BS.UpdateUsable()
assert(BS.swipeSeen[exBar.id]:find("^none") and BS.swipeSeen[exBar.id]:find("duration object: "), "both reasons kept")
-- Icon style: the art zoomed to fill the icon, a border plate behind it, corners rounded alike
local ic = BS.profile.icons
assert(ic.zoom == 8 and ic.border == 1 and ic.radius == 0, "a profile starts with a slight zoom and a 1 px border")
local icon = exRec.reminder
assert(icon._coords[1] == 0.08 and icon._coords[2] == 0.92, "our own icon is zoomed 8% a side")
local sty = { border = BS.borderOf[icon] }
assert(sty.border and rawget(sty.border, "_shown") ~= false, "a border plate behind it")
ic.zoom, ic.border, ic.radius = 20, 3, 25
realLayout()
assert(icon._coords[1] == 0.2, "zoom follows the setting")
assert(rawget(icon, "_mask") and rawget(sty.border, "_mask"), "rounded: icon and border cut by the same shape")
ic.radius = 0
realLayout()
assert(rawget(icon, "_mask") == false, "square again: the mask comes off")
ic.border = 0
realLayout()
assert(rawget(sty.border, "_shown") == false, "no border: no plate")
ic.zoom, ic.border = 8, 1
-- garbage in a saved profile is put right
local fixed = BS.NormalizeProfile({ icons = { zoom = 99, border = -4, radius = 13, color = { 5, "x" } } })
assert(fixed.icons.zoom == 30 and fixed.icons.border == 0 and fixed.icons.radius == 0, "clamped")
-- the window's Icon style dialog edits it
BS.ShowIconStyle()
local corners
for _, fn in ipairs(menus) do
  local r = radios(fn)
  if r[1] and r[1].text == "Square" then corners = r end
end
assert(corners and #corners == 4 and corners[4].text == "Round", "corners: square, small, medium, round")
corners[4].set()
assert(ic.radius == 50 and corners[4].isSel(), "picking Round sets it")
ic.radius = 0
C_Spell.IsSpellUsable = nil
EssentialCooldownViewer = nil

-- the picker for an aura or debuff bar offers Tracked Buffs only
EssentialCooldownViewer = { GetItemFrames = function() return { cdFrame } end }
BuffIconCooldownViewer = { GetItemFrames = function() return { rendFrame } end }
local all, buffsOnly = BS.AvailableSpells(), BS.AvailableSpells(true)
assert(#all == 2 and #buffsOnly == 1 and buffsOnly[1].name == "Rend", "only the tracked debuff is offered")
BuffIconCooldownViewer = nil

-- a frame whose spell comes back secret in combat keeps the last readable answer
local pooled = { GetSpellID = function() return 772 end }
assert(BS.FrameSpell(pooled) == 772)
pooled.GetSpellID = function() error("secret") end
assert(BS.FrameSpell(pooled) == 772, "the frame is still Rend's, so it stays in the bar")

print("barstack ok")
