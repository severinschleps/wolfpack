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
assert(b.visibility == "always" and b.style.texture == "flat" and b.style.color == "#C79C6E")
assert(#b.spells == 1 and b.spells[1].name == "Overpower" and b.spells[1].display == "icon")

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

-- groups: each is a stack of its own; a bar moves between them, and only an empty group goes
local g2 = BS.NewGroup()
assert(#BS.profile.groups == 2 and g2.name == "Stack 2" and g2.stack.y == -180, "a new group starts as its own stack")
assert(g2.stack ~= g1.stack, "with settings of its own")
assert(BS.MoveToGroup(high, g2) and g2.bars[1] == high and BS.GroupOf(high) == g2, "a bar moves to another group")
assert(#g1.bars == 1 and not tContains(g1.bars, high), "and leaves the old one")
assert(not BS.DeleteGroup(g2), "a group with bars is kept")
BS.MoveToGroup(high, g1)
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
assert(BS.Find({ baseSpell = 107574, name = "Avatar", display = "icon" }, "aura", {}) == avatarBuff,
  "tracked as a buff bar, it is found there even for an icon")
assert(BS.Find({ baseSpell = 107574, name = "Avatar", display = "icon" }, "always", {}) == avatarCD,
  "an always bar still takes the cooldown")
BuffIconCooldownViewer, BuffBarCooldownViewer = nil, nil

-- the window: built against frames that answer anything, with the dropdown menus captured
local menus = {}
local function mock()
  return setmetatable({}, {
    __index = function(t, k)
      if k == "SetupMenu" then return function(self, fn) menus[#menus + 1] = fn end end
      if k == "GetFrameLevel" or k == "GetScale" or k == "GetWidth" or k == "GetHeight" then return function() return 1 end end
      if k == "GetCenter" then return function() return 0, 0 end end
      if k == "SetAlpha" then return function(self, a) rawset(self, "_alpha", a) end end
      if k == "SetShown" then return function(self, v) rawset(self, "_shown", v) end end
      if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
      if k == "GetAlpha" then return function(self) return rawget(self, "_alpha") or 1 end end
      local m = mock()
      rawset(t, k, m)
      return m
    end,
    __call = function() return mock() end,
  })
end
CreateFrame = function() return mock() end
UISpecialFrames, tinsert = {}, table.insert
assert(loadfile("WolfpackAddon/BarStack/Config.lua"))("WolfpackAddon", ns)
BS.NewBar(BS.profile.groups[1]).name = "Avatar bar"
BS.ToggleConfig()
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
assert(vis and #vis == 5, "the Show dropdown has five choices")
assert(vis[2].text == "Only while aura is active" and vis[3].text == "Only while debuff is active"
  and vis[4].text == "Only while debuff is missing" and vis[5].text == "Only while proc is active", "named as asked")
vis[3].set()
assert(BS.profile.groups[1].bars[1].visibility == "debuff" and vis[3].isSel(), "picking one sets the bar")

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

-- one Rend, in Tracked Bars only, serves both: the "active" bar shows Blizzard's frame as its bar,
-- the "missing" bar watches that same frame and flips its own icon
rendFrame.shown = false
BuffIconCooldownViewer = nil
BuffBarCooldownViewer = { GetItemFrames = function() return { rendFrame } end }
debuffBar.spells[1].display = "bar"
realLayout()
local activeRec, missingRec
for _, r in ipairs(BS.placed) do
  if r.spell == "Rend" and r.visibility == "debuff" then activeRec = r end
  if r.spell == "Rend" and r.visibility == "missing" then missingRec = r end
end
assert(activeRec.frame == rendFrame and rendFrame.parent == activeRec.barFrame, "the active bar shows Blizzard's Rend bar")
assert(missingRec.frame == rendFrame, "the missing bar watches the very same frame")
assert(missingRec.reminder._alpha == 1, "no Rend: the missing icon shows")
rendFrame:Show()
assert(missingRec.reminder._alpha == 0 and rendFrame.parent == activeRec.barFrame,
  "Rend up: the icon hides, and the frame stays in the active bar")
rendFrame:Hide()
assert(missingRec.reminder._alpha == 1, "Rend off: the icon is back")
assert(rendFrame.w == 240 and rendFrame.h == 24, "from Tracked Bars it is drawn as the bar: " .. rendFrame.w)
-- the same spell set to "Bar" but tracked as a buff icon stays square, and the window says why
BuffBarCooldownViewer = nil
BuffIconCooldownViewer = { GetItemFrames = function() return { rendFrame } end }
realLayout()
assert(rendFrame.w == 24 and rendFrame.h == 24, "an icon frame is never stretched along the bar")
BS.RefreshConfig()
assert((BS.cfg.spellNote._text or ""):find("Move it to Tracked Bars"), "the window says how to get the bar: " .. tostring(BS.cfg.spellNote._text))
BuffIconCooldownViewer = nil

-- the window says, under the spell list, why the selected bar shows nothing
realLayout()
BS.RefreshConfig()
local note = BS.cfg.spellNote._text or ""
assert(note:find("Rend: not in Tracked Buffs or Tracked Bars"), "an untracked debuff is named: " .. note)
assert(note:find("only while you have a target"), "and so is the target rule: " .. note)

-- the picker for an aura or debuff bar offers Tracked Buffs / Bars only
EssentialCooldownViewer = { GetItemFrames = function() return { cdFrame } end }
BuffBarCooldownViewer = { GetItemFrames = function() return { rendFrame } end }
local all, buffsOnly = BS.AvailableSpells(), BS.AvailableSpells(true)
assert(#all == 2 and #buffsOnly == 1 and buffsOnly[1].name == "Rend", "only the tracked debuff is offered")
BuffBarCooldownViewer = nil

-- a frame whose spell comes back secret in combat keeps the last readable answer
local pooled = { GetSpellID = function() return 772 end }
assert(BS.FrameSpell(pooled) == 772)
pooled.GetSpellID = function() error("secret") end
assert(BS.FrameSpell(pooled) == 772, "the frame is still Rend's, so it stays in the bar")

assert(select(1, BS.Hex("#FF0000")) == 1 and select(2, BS.Hex("bad")) == 1)
print("barstack ok")
