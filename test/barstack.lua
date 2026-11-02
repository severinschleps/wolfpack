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
local b = BS.NormalizeBar({ name = 5, size = { w = -3, h = 0 / 0 }, style = { texture = "../evil" }, icons = {
  { look = "nope", spell = { baseSpell = 7384 } }, "junk", { look = "aura" },
  { conditions = { { kind = "usable", baseSpell = 100 }, { kind = "target" }, { kind = "sometimes" }, { kind = "active" } } },
} })
assert(b.name == "New bar" and b.size.w == 1 and b.size.h == 1)
assert(b.style == nil and b.visibility == nil, "no bar styling and no Show setting: icons only")
assert(#b.icons == 3 and b.icons[1].look == "custom" and b.icons[1].spell.name == "Overpower", "an unknown look: our own picture")
assert(b.icons[2].look == "custom", "Blizzard's icon needs a spell; without one, our own picture")
local cs = b.icons[3].conditions
assert(#cs == 2 and cs[1].kind == "usable" and cs[1].name == "Charge" and cs[2].kind == "target", "bad conditions dropped")

-- a bar from before icons: each spell becomes an icon that shows the way the bar's Show did
local function migrated(show, extra)
  return BS.NormalizeBar({ visibility = show, spells = { { baseSpell = 100, name = "Charge" } }, conditions = extra }).icons[1]
end
local m = migrated("always")
assert(m.look == "cooldown" and #m.conditions == 0, "always: Blizzard's cooldown icon")
m = migrated("usable")
assert(m.look == "custom" and m.swipe and m.conditions[1].kind == "usable" and m.conditions[1].baseSpell == 100, "usable")
m = migrated("aura")
assert(m.look == "aura" and #m.conditions == 0, "aura: Blizzard's aura icon")
m = migrated("debuff")
assert(m.look == "aura" and m.conditions[1].kind == "target", "debuff: the aura icon, with a target")
m = migrated("missing")
assert(m.look == "custom" and m.conditions[1].kind == "target" and m.conditions[2].kind == "missing"
  and m.conditions[2].name == "Charge", "debuff missing: our own icon, a target and the debuff missing")
m = migrated("auramissing")
assert(#m.conditions == 1 and m.conditions[1].kind == "missing", "aura missing needs no target")
m = migrated("usable", { { kind = "active", baseSpell = 100, name = "Charge" } })
assert(#m.conditions == 2 and m.conditions[2].kind == "active", "the bar's own conditions come along")

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

-- a profile handed back by Wolfpack's profile string: junk refused, a profile taken
assert(not BS.ImportProfile("garbage") and not BS.ImportProfile({}))
local saved = CopyTable(BS.profile)
BS.profile.groups[1].bars = {}
assert(BS.ImportProfile(saved) and BS.profile.groups[1].bars[1].name == "Proc")

-- a version 1 profile (one stack, one list of bars) becomes the first group, nothing lost
local old = BS.NormalizeProfile({ version = 1, stack = { x = 50, y = 60 }, bars = { { name = "Old" } } })
assert(old.version == 2 and #old.groups == 1 and old.stack == nil and old.bars == nil, "migrated to groups")
assert(old.groups[1].stack.x == 50 and old.groups[1].bars[1].name == "Old", "position and bars kept")
-- and an old profile still imports
BS.db.profiles["Tester-Realm:1"] = nil
assert(BS.ImportProfile({ version = 1, bars = { { name = "Imported" } } }), "an old profile imports")
assert(BS.profile.groups[1].bars[1].name == "Imported")

-- groups, bars and icons belong to the Wolfpack profile in use: this character's set moves to
-- the first one picked, another profile starts empty, and switching back brings the set back
ns.profileName = "Warrior"
BS.LoadProfile()
assert(BS.profile.groups[1].bars[1].name == "Imported", "the character's set moved to the profile")
assert(BS.db.profiles["wp:Warrior:1"] and not BS.db.profiles["Tester-Realm:1"], "stored under the profile")
ns.profileName = "Alpha"
BS.LoadProfile()
assert(#BS.profile.groups[1].bars == 0, "another profile has its own, empty set")
ns.profileName = "Warrior"
BS.LoadProfile()
assert(BS.profile.groups[1].bars[1].name == "Imported", "switching back restores the set")
ns.profileName = nil
BS.db.profiles["Tester-Realm:1"] = BS.db.profiles["wp:Warrior:1"]
BS.LoadProfile()

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
for _, mode in ipairs({ "aura" }) do
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
-- the bar's settings live in a flyout, opened by Settings in the Bars column
assert(#BS.cfg.barSliders == 0, "no bar settings until asked for")
BS.cfg.settings._onOnClick()
assert(#BS.cfg.barSliders == 5, "Settings opens them: icon width and height, offsets, gap")
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
local function menuStarting(text)
  for _, fn in ipairs(menus) do
    local r = radios(fn)
    if r[1] and r[1].text == text then return r end
  end
end
assert(not menuStarting("Always"), "no Show setting on a bar any more: each icon has conditions")
local icon = BS.NormalizeIcon

-- a layout pass over two groups: one stack frame each, every icon accounted for
hooksecurefunc = function() end
local cdFrame = mock()
cdFrame.GetSpellID = function() return 100 end
EssentialCooldownViewer = { GetItemFrames = function() return { cdFrame } end }
local gA, gB = BS.profile.groups[1], BS.NewGroup()
gA.bars = {}
BS.NewBar(gA).icons = { icon({ look = "cooldown", spell = { baseSpell = 100, name = "Charge" } }) }
BS.NewBar(gB).icons = { icon({ look = "aura", spell = { baseSpell = 107574, name = "Avatar" } }) }
BS.ready = true
realLayout()
assert(BS.stacks[gA.id] and BS.stacks[gB.id] and BS.stacks[gA.id] ~= BS.stacks[gB.id], "a stack frame per group")
assert(#BS.placed == 2 and BS.placed[1].frame == cdFrame and BS.placed[1].group == "Stack 1", "Charge placed in Stack 1")
assert(BS.placed[2].frame == nil and BS.placed[2].look == "aura", "Avatar has no buff frame, so nothing is borrowed")

-- an aura icon's frame has Blizzard's Show / Hide / SetAlpha counted, for /bs check
hooksecurefunc = function(t, m, fn)
  local orig = t[m]
  t[m] = function(...) local r = orig(...); fn(...); return r end
end
local buffFrame = mock()
buffFrame.GetSpellID = function() return 107574 end
for _, m in ipairs({ "Show", "Hide", "SetShown", "SetAlpha" }) do buffFrame[m] = function() end end
BuffIconCooldownViewer = { GetItemFrames = function() return { buffFrame } end }
realLayout()
assert(BS.placed[2].frame == buffFrame and BS.watch[buffFrame], "a borrowed aura frame is watched")
buffFrame:Hide(); buffFrame:Show(); buffFrame:Hide()
buffFrame:SetAlpha(0.5)
local w = BS.watch[buffFrame]
assert(w.Hide == 2 and w.Show == 1 and w.SetAlpha == 1 and not w.SetAlphaSecret, "every call counted: " .. w.Hide)
assert(BS.watch[cdFrame] == nil, "a cooldown icon is left alone")
local said, keptPrint = {}, print
print = function(t) said[#said + 1] = t end
BS.Check()
print = keptPrint
local probe
for _, t in ipairs(said) do if t:find("Blizzard called Show 1, Hide 2") then probe = t end end
assert(probe, "/bs check reports the calls")

-- conditions: each one is a frame between the bar and the icon, so their opacities multiply.
-- Our own Rend icon, shown while you have a target AND Rend is missing from it
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
local rendSpell = { baseSpell = 772, name = "Rend" }
local rendBar = BS.NewBar(gA)
rendBar.icons = { icon({ look = "custom", spell = rendSpell,
  conditions = { { kind = "target" }, { kind = "missing", baseSpell = 772, name = "Rend" } } }) }
local function recOf(bar)
  for _, r in ipairs(BS.placed) do if r.barRef == bar then return r end end
end
local function gatesOf(rec)
  local out = {}
  for _, q in ipairs(BS.gates) do if q.icon == rec.icon then out[#out + 1] = q end end
  return out
end
S_target = true
realLayout()
local rec = recOf(rendBar)
local qs = gatesOf(rec)
assert(rec.reminder and rec.frame == nil, "our own Rend icon, nothing borrowed")
assert(#qs == 2 and qs[1].cond.kind == "target" and qs[2].frame == rendFrame, "the missing condition watches Rend's frame")
local tG, mG = qs[1].gate, qs[2].gate
assert(rendFrame.parent ~= rec.container, "Blizzard's frame is parked, not in the bar")
assert(tG._alpha == 1 and mG._alpha == 1, "a target, no Rend: shown")
rendFrame:Show()
assert(mG._alpha == 0, "Rend goes up: hidden")
rendFrame:Hide()
assert(mG._alpha == 1, "Rend falls off: back")
rendFrame:SetShown(true)
assert(mG._alpha == 0, "SetShown works the same way")
rendFrame:SetShown(false)
issecretvalue = function(v) return v == "SECRET" end
rendFrame:SetShown("SECRET")
assert(mG._fromBool[1] == "SECRET" and mG._fromBool[2] == 0 and mG._fromBool[3] == 1, "a secret, handed on unread and inverted")
issecretvalue = nil
rendFrame.shown = true
realLayout()
assert(mG._alpha == 0, "laid out with Rend up: hidden from the start")
rendFrame.shown = false
S_target = false
BS.UpdateVisibility() -- what PLAYER_TARGET_CHANGED does
assert(tG._alpha == 0, "no target: hidden")
-- with the page open ("Show all bars" is on), the conditions still follow the game: you test an
-- icon while you build it. Forcing them on hid nothing while Rend was up (seen in game)
BS.preview = true
BS.UpdateVisibility()
assert(tG._alpha == 0, "page open, no target: still hidden")
rendFrame:Show()
assert(mG._alpha == 0, "page open, Rend goes up: the missing icon hides")
rendFrame:Hide()
assert(mG._alpha == 1, "page open, Rend falls off: back")
BS.preview = nil
S_target = true
BS.UpdateVisibility()
-- the chain: bar -> target -> Rend missing -> the icon's pane
local function recordParent(fr) rawset(fr, "SetParent", function(self, p) rawset(self, "parent", p) end) end
for _, fr in ipairs({ tG, mG, rec.container }) do recordParent(fr) end
realLayout()
assert(rawget(rec.container, "parent") == mG and rawget(mG, "parent") == tG and rawget(tG, "parent") == rec.barFrame,
  "each condition hangs from the one before, the icon from the last")
-- the plate behind our own icon lives in the same pane, so the conditions switch it too
assert(BS.borderOf[rec.reminder], "our own icon has its plate")

-- one Rend serves both: an aura icon shows Blizzard's Rend frame, and the missing condition
-- watches that very frame
local debuffBar = BS.NewBar(gA)
debuffBar.icons = { icon({ look = "aura", spell = rendSpell }) }
realLayout()
local activeRec = recOf(debuffBar)
assert(activeRec.frame == rendFrame and rendFrame.parent == activeRec.container, "the aura icon shows Blizzard's Rend")
assert(gatesOf(recOf(rendBar))[2].frame == rendFrame, "the missing condition watches the very same frame")
rendFrame:Show()
assert(mG._alpha == 0 and rendFrame.parent == activeRec.container, "Rend up: our icon hides, Blizzard's stays in its bar")
rendFrame:Hide()
assert(mG._alpha == 1, "Rend off: ours is back")

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
local three = { size = { w = 40, h = 30 }, icons = { 1, 2, 3 } }
assert(select(1, BS.BarSize(three)) == 120 and select(2, BS.BarSize(three)) == 30, "the bar is three icons wide")
three.orientation = "vertical"
assert(select(1, BS.BarSize(three)) == 40 and select(2, BS.BarSize(three)) == 90, "or three tall")
three.gap = 5
assert(select(2, BS.BarSize(three)) == 100, "with a 5 px gap between each two")
three.orientation = nil
assert(select(1, BS.BarSize(three)) == 130, "either way")

-- sent home: Blizzard's own size and scale come back
BuffIconCooldownViewer = { GetItemFrames = function() return {} end }
realLayout()
assert(rendFrame.scale == 1 and rendFrame.w == 36 and rendFrame.h == 36, "returned the way it came")
BuffIconCooldownViewer = nil

-- a frame Blizzard has dropped no longer answers for its spell: when Blizzard moves Rend to a new
-- icon frame, the icons follow it rather than the old frame we once borrowed
local oldIcon = mock()
oldIcon.GetSpellID = function() return 772 end
BuffIconCooldownViewer = { GetItemFrames = function() return { oldIcon } end }
oldIcon.GetParent = function(self) return rawget(self, "parent") or BuffIconCooldownViewer end
oldIcon.SetParent = function(self, p) rawset(self, "parent", p) end
realLayout() -- the aura icon borrows the old icon while it is the only Rend there is
-- Blizzard lists only what is still inside its viewer: the borrowed icon is off its list, and
-- must still be found -- this is what went wrong in game, every frame we had placed went missing
BuffIconCooldownViewer.GetItemFrames = function() return {} end
realLayout()
assert(recOf(debuffBar).frame == oldIcon, "a frame we placed is still ours, though Blizzard no longer lists it")
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
assert(recOf(debuffBar).frame == newIcon, "the aura icon follows Rend to its new frame")
assert(gatesOf(recOf(rendBar))[2].frame == newIcon, "and so does the missing condition")
-- /bs frames lists every frame with each way of asking its spell, and survives what it cannot ask
said = {}
print = function(t) said[#said + 1] = t end
BS.Frames()
print = keptPrint
local listed
for _, t in ipairs(said) do if t:find("GetSpellID 772") and t:find("ours 772") then listed = t end end
assert(listed, "a frame line names what each question answered: " .. table.concat(said, " / "))
BuffIconCooldownViewer, BuffBarCooldownViewer = nil, nil

-- the window says, under the icon list, why an icon shows nothing
realLayout()
BS.RefreshConfig()
local note = BS.cfg.iconNote._text or ""
assert(note:find("Rend: not in Tracked Buffs"), "an untracked aura icon is named: " .. note)

-- "Usable": Execute shows exactly while WoW says it can be pressed -- rage, a target under the
-- threshold, or a Sudden Death proc all go into that one answer
names[163201] = "Execute"
local usableNow = false
C_Spell.IsSpellUsable = function(id) assert(id == 163201); return usableNow end
local exSpell = { baseSpell = 163201, name = "Execute" }
local exBar = BS.NewBar(gA)
exBar.icons = { icon({ look = "custom", spell = exSpell, swipe = true,
  conditions = { { kind = "usable", baseSpell = 163201, name = "Execute" } } }) }
realLayout()
local exRec = recOf(exBar)
local uG = gatesOf(exRec)[1].gate
assert(exRec.reminder and exRec.frame == nil, "our own icon: Blizzard's froze in its unusable look when moved")
assert(uG._alpha == 0, "not usable: hidden")
usableNow = true
BS.UpdateUsable() -- what SPELL_UPDATE_USABLE does
assert(uG._alpha == 1, "usable: shown")
issecretvalue = function(v) return v == "SECRET" end
usableNow = "SECRET"
BS.UpdateUsable()
assert(uG._fromBool and uG._fromBool[1] == "SECRET" and uG._fromBool[2] == 1 and uG._fromBool[3] == 0,
  "a secret answer drives the opacity without being read")
issecretvalue = nil
usableNow = false
BS.preview = true
BS.UpdateUsable()
assert(uG._alpha == 0, "page open: not usable still hides it")
BS.preview = nil
BS.UpdateUsable()
said = {}
print = function(t) said[#said + 1] = t end
BS.Check()
print = keptPrint
local seenIcon, seenCond
for _, t in ipairs(said) do
  if t:find("Execute: own picture") then seenIcon = t end
  if t:find("if usable Execute %-%- asks WoW, now no") then seenCond = t end
end
assert(seenIcon and seenCond, "/bs check names the icon and what its condition answered: " .. table.concat(said, "\n"))
-- a cooldown swipe over the icon, fed WoW's duration object unread; the icon itself stays put
local exSwipe = exRec.swipe
assert(exSwipe, "the icon has a cooldown swipe")
local fedWith
exSwipe.SetCooldownFromDurationObject = function(_, d) fedWith = d end
C_Spell.GetSpellCooldownDuration = function(id) assert(id == 163201); return { "Execute's cooldown" } end
usableNow = true
BS.UpdateUsable() -- what SPELL_UPDATE_COOLDOWN does
assert(fedWith and fedWith[1] == "Execute's cooldown" and BS.swipeSeen[exRec.icon] == "duration object",
  "the swipe plays the duration object")
-- a client without the duration object: start and duration go to the swipe instead
C_Spell.GetSpellCooldownDuration = nil
local fedStart
exSwipe.SetCooldown = function(_, start, dur) fedStart = start .. "/" .. dur end
C_Spell.GetSpellCooldown = function() return { startTime = 100, duration = 6, modRate = 1 } end
BS.UpdateUsable()
assert(fedStart == "100/6" and BS.swipeSeen[exRec.icon] == "start and duration", "the fallback route")
-- neither: each refusal is kept, word for word
C_Spell.GetSpellCooldown = nil
BS.UpdateUsable()
assert(BS.swipeSeen[exRec.icon]:find("^none") and BS.swipeSeen[exRec.icon]:find("duration object: "), "both reasons kept")

-- the picture of our own: a texture typed in wins over the spell's
local texOf = { Rend = 132155 }
C_Spell.GetSpellTexture = function(v) return texOf[v] or 1 end
assert(BS.IconTexture({ spell = exSpell }) == 1, "the spell's picture")
assert(BS.IconTexture({ spell = exSpell, texture = 135358 }) == 135358, "a file ID")
assert(BS.IconTexture({ texture = "Rend" }) == 132155, "a spell's name")
C_Spell.GetSpellTexture = function() return nil end
assert(BS.IconTexture({ texture = "Interface\\Icons\\Foo" }) == "Interface\\Icons\\Foo", "a path")
assert(BS.IconTexture({}) == 134400, "nothing yet: a question mark")
C_Spell.GetSpellTexture = function() return 1 end

-- Icon style: the art zoomed to fill the icon, a border plate behind it, corners rounded alike
local ic = BS.profile.icons
assert(ic.zoom == 8 and ic.border == 2 and ic.radius == 12, "a profile starts with a slight zoom, a 2 px border and small corners")
assert(BS.NormalizeBar({}).gap == 8, "and 8 px between icons")
local own = exRec.reminder
assert(own._coords[1] == 0.08 and own._coords[2] == 0.92, "our own icon is zoomed 8% a side")
local plate = BS.borderOf[own]
assert(plate and rawget(plate, "_shown") ~= false, "a border plate behind it")
ic.zoom, ic.border, ic.radius = 20, 3, 25
realLayout()
assert(own._coords[1] == 0.2, "zoom follows the setting")
assert(rawget(own, "_mask") and rawget(plate, "_mask"), "rounded: icon and border cut by the same shape")
ic.radius = 0
realLayout()
assert(rawget(own, "_mask") == false, "square again: the mask comes off")
ic.border = 0
realLayout()
assert(rawget(plate, "_shown") == false, "no border: no plate")
ic.zoom, ic.border = 8, 1
-- garbage in a saved profile is put right
local fixed = BS.NormalizeProfile({ icons = { zoom = 99, border = -4, radius = 13, color = { 5, "x" } } })
assert(fixed.icons.zoom == 30 and fixed.icons.border == 0 and fixed.icons.radius == 0, "clamped")
-- the window's Icon style dialog edits it
BS.cfg.iconStyle._onOnClick() -- the button at the top right of the Icons box
local corners = menuStarting("Square")
assert(corners and #corners == 4 and corners[4].text == "Round", "corners: square, small, medium, round")
corners[4].set()
assert(ic.radius == 50 and corners[4].isSel(), "picking Round sets it")
ic.radius = 0
C_Spell.IsSpellUsable = nil

-- the flow in the window: Add icon makes one and opens it, the Icon dialog sets its look and
-- adds conditions
BS.RefreshConfig()
local before = {}
for _, bar in ipairs(gA.bars) do before[bar] = #bar.icons end
BS.cfg.add._onOnClick()
local made -- on the bar the window has picked
for _, bar in ipairs(gA.bars) do if #bar.icons > before[bar] then made = bar.icons[#bar.icons] end end
assert(made and made.look == "custom" and #made.conditions == 0, "Add icon: a new icon, shown always")
local looks = menuStarting("My own picture")
assert(looks and #looks == 3 and looks[3].text:find("aura icon"), "three looks")
looks[3].set()
assert(made.look == "aura" and looks[3].isSel(), "picking a look sets the icon")
BS.cfg.editor.adds[4]._onOnClick() -- Target
assert(made.conditions[1] and made.conditions[1].kind == "target", "Target adds a condition")
BS.cfg.editor.adds[1]._onOnClick() -- Usable: picks a spell first
local pickBtn = BS.cfg.picker
assert(pickBtn and pickBtn.onPick, "Usable asks which spell")
pickBtn.onPick({ baseSpell = 163201, name = "Execute" })
assert(made.conditions[2].kind == "usable" and made.conditions[2].name == "Execute", "the picked spell becomes the condition")

-- the icons' order in a bar: up and down, not past either end
local order = { icons = { "a", "b", "c" } }
assert(BS.MoveIcon(order, 2, -1) and order.icons[1] == "b" and order.icons[2] == "a", "up one")
assert(BS.MoveIcon(order, 2, 1) and order.icons[3] == "a", "down one")
assert(not BS.MoveIcon(order, 1, -1) and not BS.MoveIcon(order, 3, 1), "nothing past either end")
-- the window's arrows do it on the picked bar: the icon made above is its last one
local holder
for _, bar in ipairs(gA.bars) do if tContains(bar.icons, made) then holder = bar end end
local at = tIndexOf(holder.icons, made)
assert(at > 1, "the picked bar has an icon above it")
BS.RefreshConfig()
BS.cfg.iconRows[at].up._onOnClick()
assert(holder.icons[at - 1] == made, "the up arrow moves it one place up")
BS.cfg.iconRows[at - 1].down._onOnClick()
assert(holder.icons[at] == made, "and the down arrow back")

-- and the bars' order the same way, from their rows in the Bars list
local topBar, secondBar = gA.bars[1], gA.bars[2]
BS.RefreshConfig()
BS.cfg.listRows[2].up._onOnClick()
assert(gA.bars[1] == secondBar and gA.bars[2] == topBar, "a bar's up arrow takes it a layer higher")
BS.cfg.listRows[1].down._onOnClick()
assert(gA.bars[1] == topBar, "and its down arrow back")
assert(rawget(BS.cfg, "up") == nil and rawget(BS.cfg, "down") == nil, "no Move up / Move down buttons under the list")

-- the picker for an aura offers Tracked Buffs only
EssentialCooldownViewer = { GetItemFrames = function() return { cdFrame } end }
BuffIconCooldownViewer = { GetItemFrames = function() return { rendFrame } end }
local all, buffsOnly = BS.AvailableSpells(), BS.AvailableSpells(true)
assert(#all == 2 and #buffsOnly == 1 and buffsOnly[1].name == "Rend", "only the tracked debuff is offered")
BuffIconCooldownViewer = nil
EssentialCooldownViewer = nil

-- stances, forms and stealth: Bear Form from the stance bar, and not stealthed
names[5487], names[768] = "Bear Form", "Cat Form"
local inForm, stealthed = 0, false
local secretIDs = false
GetNumShapeshiftForms = function() return 2 end
GetShapeshiftFormInfo = function(i)
  local sid = ({ 768, 5487 })[i]
  return 100 + i, inForm == i, true, secretIDs and "SECRET" or sid
end
IsStealthed = function() return stealthed end
local formBar = BS.NewBar(gA)
formBar.icons = { icon({ look = "custom", spell = { baseSpell = 5487, name = "Bear Form" },
  conditions = { { kind = "form", baseSpell = 5487, name = "Bear Form" }, { kind = "nostealth" } } }) }
assert(formBar.icons[1].conditions[2].kind == "nostealth", "stealth needs no spell and is kept")
realLayout()
local fq = gatesOf(recOf(formBar))
local formG, stealthG = fq[1].gate, fq[2].gate
assert(formG._alpha == 0 and stealthG._alpha == 1, "caster form, not stealthed")
inForm = 2
BS.UpdateUsable() -- what UPDATE_SHAPESHIFT_FORM does
assert(formG._alpha == 1, "in Bear Form: yes")
inForm = 1
BS.UpdateUsable()
assert(formG._alpha == 0, "Cat Form is not Bear Form")
stealthed = true
BS.UpdateUsable() -- what UPDATE_STEALTH does
assert(stealthG._alpha == 0, "stealthed: not stealthed says no")
-- in combat the stance bar may name its spells in secrets: the slot learned before still counts
issecretvalue = function(v) return v == "SECRET" end
secretIDs, inForm = true, 2
BS.UpdateUsable()
assert(formG._alpha == 1, "secret spell IDs: Bear Form still found by its slot")
issecretvalue, secretIDs = nil, false
local forms = BS.Forms()
assert(#forms == 2 and forms[2].name == "Bear Form" and forms[2].icon == 102, "the picker lists your forms")
table.remove(gA.bars, tIndexOf(gA.bars, formBar))
realLayout()
GetNumShapeshiftForms, GetShapeshiftFormInfo, IsStealthed = nil, nil, nil
assert(#BS.cfg.editor.adds == 8, "the Icon dialog adds In form, Not in form, Stealthed, Not stealthed too")

-- Blizzard's viewers stay shown but invisible: hidden by their Visibility setting they fill no
-- icons at all, and Bar Stack had nothing to read (seen in game: every frame empty, in combat too)
local viewer = mock()
viewer.SetAlpha = function(self, a) rawset(self, "_alpha", a) end
viewer.GetItemFrames = function() return {} end
EssentialCooldownViewer = viewer
assert(BS.profile.hideBlizzard == true, "on by default")
BS.UpdateVisibility()
assert(viewer._alpha == 0, "invisible, never Hide()")
viewer:SetAlpha(1) -- Blizzard's own Opacity setting
assert(viewer._alpha == 0, "Blizzard's opacity is put back to 0")
BS.SetEditing(true)
assert(viewer._alpha == 1, "Edit Mode: back, to be placed")
BS.SetEditing(false)
assert(viewer._alpha == 0, "and gone again after")
BS.profile.hideBlizzard = false
BS.UpdateVisibility()
assert(viewer._alpha == 1, "switched off: visible again")
viewer:SetAlpha(0.6)
assert(viewer._alpha == 0.6, "and its opacity is Blizzard's own")
assert(BS.NormalizeProfile({}).hideBlizzard == true, "a new profile hides them")
EssentialCooldownViewer = nil

-- a frame whose spell comes back secret in combat keeps the last readable answer
local pooled = { GetSpellID = function() return 772 end }
assert(BS.FrameSpell(pooled) == 772)
pooled.GetSpellID = function() error("secret") end
assert(BS.FrameSpell(pooled) == 772, "the frame is still Rend's, so it stays in the bar")

print("barstack ok")
