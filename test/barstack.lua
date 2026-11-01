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
GetRealmName = function() return "Realm" end
GetSpecialization = function() return 1 end
InCombatLockdown = function() return false end

local ns = {}
assert(loadfile("WolfpackAddon/BarStack/Core.lua"))("WolfpackAddon", ns)
assert(loadfile("WolfpackAddon/BarStack/Stack.lua"))("WolfpackAddon", ns)
local BS = ns.bs
assert(BS and ns.ToggleConfig == nil, "Bar Stack keeps its names on its own table")
BS.Layout = function() end

-- normalize garbage (e.g. a hostile import string)
local b = BS.NormalizeBar({ name = 5, size = { w = -3, h = 0 / 0 }, visibility = "nope", spells = { { baseSpell = 7384 }, "junk", { baseSpell = "x" } }, style = { texture = "../evil" } })
assert(b.name == "New bar" and b.size.w == 1 and b.size.h == 1)
assert(b.visibility == "always" and b.style.texture == "flat" and b.style.color == "#C79C6E")
assert(#b.spells == 1 and b.spells[1].name == "Overpower" and b.spells[1].display == "icon")

-- storage round trip through the CVar chunks (SavedVariables missing, like on Forever)
BarStackDB = nil
BS.LoadDB(); BS.LoadProfile()
BS.NewBar().name = "Proc"
BS.Save()
assert(cvars.barStackData3 ~= "" and cvars.barStackData40 == "", "payload should span a few chunks")
BarStackDB = nil
BS.LoadDB(); BS.LoadProfile()
assert(BS.cvFound and not BS.svFound)
assert(BS.profile.bars[1].name == "Proc", "profile restored from CVars")

-- newest backend wins
BarStackDB = { updated = 1, profiles = {} }
BS.LoadDB()
assert(BS.db.profiles["Tester-Realm:1"], "CVar copy is newer than the stale SavedVariables")

-- import rejects junk, accepts an export
assert(not BS.Import("garbage"))
local s = BS.Export()
BS.profile.bars = {}
assert(BS.Import(s) and BS.profile.bars[1].name == "Proc")

-- moving a bar up and down the stack, and not past either end
BS.profile.bars = {}
local low = BS.NewBar(); low.name = "Low"
local high = BS.NewBar(); high.name = "High" -- NewBar puts it at the top
assert(BS.profile.bars[1] == high and BS.profile.bars[2] == low)
assert(BS.MoveBar(low, -1) and BS.profile.bars[1] == low, "Move up takes it a layer higher")
assert(not BS.MoveBar(low, -1), "nothing above the top layer")
assert(BS.MoveBar(low, 1) and BS.profile.bars[2] == low, "Move down puts it back")
assert(not BS.MoveBar(low, 1), "nothing below the bottom layer")

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
BuffIconCooldownViewer = nil

assert(select(1, BS.Hex("#FF0000")) == 1 and select(2, BS.Hex("bad")) == 1)
print("barstack ok")
