-- Smoke test: runs the addon against a fake WoW API. Run from the repo root: luajit test/smoke.lua
-- SECRET mimics Forever's secret values: any math, comparison or concat on it throws.
local SECRET = setmetatable({}, { __tostring = function() error("tostring on secret") end })
local S = { class = "ROGUE", name = "Tester", ptype = 3, secret = true, max = {}, plate = nil }
local TOKENS = { [0] = "MANA", [1] = "RAGE", [3] = "ENERGY" }

local created, evFrame = {}, nil
local M = {}
local function new(kind) return setmetatable({ _kind = kind, _shown = true, _scripts = {} }, { __index = function(_, k)
    if k:match("^%u") then return M[k] or function() return new() end end -- methods are Capitalized
end }) end
function M:Show() self._shown = true end
function M:Hide() self._shown = false end
function M:SetShown(v) assert(v == nil or type(v) == "boolean", "SetShown got " .. type(v)); self._shown = not not v end
function M:IsShown() return self._shown end
function M:SetScript(k, fn) self._scripts[k] = fn end
M.HookScript = M.SetScript
function M:GetText() return self._text end
function M:SetText(t) self._text = t end
function M:HasFocus() return false end
function M:SetMinMaxValues(a, b) self._min, self._max = a, b end
function M:SetValue(v) self._value = v end
function M:GetValue() return type(self._value) == "number" and self._value or 0 end
function M:SetChecked(v) self._checked = v end
function M:GetChecked() return self._checked end
function M:SetSize(w, h) self._w, self._h = w, h end
function M:SetParent(p) self._parent = p end
function M:GetName() return self._name end
function M:GetCenter() return 100, 100 end
function M:GetTop() return 150 end
function M:GetFrameLevel() return 1 end
function M:GetWidth() return 140 end
function M:GetHeight() return 100 end
function M:SetupMenu(gen) self._gen = gen end
function M:GenerateMenu() -- records the dropdown's radio items
    local root = { items = {} }
    function root:CreateRadio(text, isSel, set) self.items[#self.items + 1] = { text = text, sel = isSel, set = set } end
    self._gen(self, root)
    self._items = root.items
end
function M:GetEffectiveScale() return 1 end
function M:IsForbidden() return false end
function M:RegisterEvent() evFrame = self end
function M:RegisterUnitEvent() evFrame = self end

Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3, ComboPoints = 4, SoulShards = 7, HolyPower = 9,
    Chi = 12, ArcaneCharges = 16, Essence = 19 } }
UIParent, Minimap, GameTooltip, UISpecialFrames, SlashCmdList = new(), new(), new(), {}, {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
issecretvalue = function(v) return rawequal(v, SECRET) end
AbbreviateNumbers = function(v) return tostring(v) end
CreateColor = function(...) return { ... } end
PowerBarColor = { ENERGY = { r = 1, g = 1, b = 0 }, MANA = { r = 0, g = 0, b = 1 }, RAGE = { r = 1, g = 0, b = 0 } }
local realPrint = print
print = function(msg) error("addon reported: " .. tostring(msg), 0) end
GetCursorPosition = function() return 10, 20 end
strtrim = function(str) return (str:gsub("^%s+", ""):gsub("%s+$", "")) end
StaticPopupDialogs = {}
StaticPopup_Show = function(which, _, _, data) StaticPopupDialogs[which].OnAccept(nil, data) end -- clicks Yes
UnitName = function() return S.name end
GetRealmName = function() return "Realm" end
CreateFrame = function(kind, name)
    local f = new(kind)
    f._name = name
    if name then _G[name] = f end
    created[#created + 1] = f
    return f
end
ColorPickerFrame = {
    SetupColorPickerAndShow = function(_, info) info.swatchFunc(); info.cancelFunc() end,
    GetColorRGB = function() return 0.1, 0.2, 0.3 end,
    GetColorAlpha = function() return 0.5 end,
}
C_NamePlate = { GetNamePlateForUnit = function() return S.plate end }
UnitClass = function() return S.class:sub(1, 1) .. S.class:sub(2):lower(), S.class end -- "Rogue", "ROGUE"
UnitPowerType = function() return S.ptype, TOKENS[S.ptype] end
UnitPower = function() return S.secret and SECRET or 3 end
UnitPowerMax = function(_, t) return S.secret and SECRET or (S.max[t] or 100) end
UnitHealth = function() return SECRET end
UnitHealthMax = function() return 1000 end

local ns = {}
assert(loadfile("ComboPointDisplay/ComboPointDisplay.lua"))("ComboPointDisplay", ns)
local function fire(e) evFrame._scripts.OnEvent(evFrame, e) end
-- each class logs in as its own character
local function login(class, ptype) S.class, S.name, S.ptype = class, class .. "Char", ptype; fire("PLAYER_LOGIN") end
local function prof() return ComboPointDisplayDB.profiles[ComboPointDisplayDB.chars[S.name .. " - Realm"]] end
local function byText(text) for _, f in ipairs(created) do if f._text == text then return f end end end
local fr = ns.frames

-- Rogue, secret values: 5 pips, each lit when points >= i; stack = 18 + 2 + 14 + 2 + 12
login("ROGUE", 3)
fire("UNIT_POWER_FREQUENT"); fire("UNIT_HEALTH")
assert(fr.combo:IsShown() and fr.combo.n == 5, "rogue combo pips")
for i = 1, 5 do
    local s = fr.combo.segs[i]
    assert(s._min == i - 1 and s._max == i and s._value == SECRET, "pip " .. i)
end
assert(not fr.druidmana:IsShown(), "rogue has no druid mana")
assert(ComboPointDisplayFrame._h == 48, "stack height " .. tostring(ComboPointDisplayFrame._h))

-- Druid: caster = no combo, no extra mana; cat = both; bear = mana only
login("DRUID", 0)
assert(not fr.combo:IsShown() and not fr.druidmana:IsShown(), "druid caster")
S.ptype = 3; fire("UPDATE_SHAPESHIFT_FORM")
assert(fr.combo:IsShown() and fr.druidmana:IsShown(), "druid cat")
S.ptype = 1; fire("UPDATE_SHAPESHIFT_FORM")
assert(not fr.combo:IsShown() and fr.druidmana:IsShown(), "druid bear")

-- Other classes: resource shows only when its max is readable and > 0
login("PALADIN", 0)
assert(not fr.combo:IsShown(), "secret holy power hidden")
S.secret, S.max[9] = false, 5; fire("UNIT_MAXPOWER")
assert(fr.combo:IsShown() and fr.combo.n == 5, "readable holy power shown")
S.max[9] = 0; fire("UNIT_MAXPOWER")
assert(not fr.combo:IsShown(), "no holy power on this client")
login("WARRIOR", 1)
assert(not fr.combo:IsShown() and fr.power:IsShown(), "warrior")

-- Profiles: one per class, named after it, shared account-wide
local store = ComboPointDisplayDB
assert(store.profiles.Rogue and store.profiles.Druid and store.profiles.Paladin and store.profiles.Warrior, "class profiles")
assert(store.chars["WARRIORChar - Realm"] == "Warrior", "character on its class profile")

-- Nameplate: combo follows the target plate, hides without one
S.secret = true
login("ROGUE", 3)
prof().bars.combo.nameplate = true
fire("PLAYER_TARGET_CHANGED")
assert(not fr.combo:IsShown(), "no plate, no bar")
S.plate = new(); fire("NAME_PLATE_UNIT_ADDED")
assert(fr.combo:IsShown() and fr.combo._parent == S.plate, "on plate")
assert(ComboPointDisplayFrame._h == 34, "combo left the stack")
S.plate = nil; fire("NAME_PLATE_UNIT_REMOVED")
assert(not fr.combo:IsShown() and fr.combo._parent == ComboPointDisplayFrame, "back off the plate")

-- Minimap icon: dragging moves it around the minimap
local mini = ComboPointDisplayMinimapButton
mini._scripts.OnDragStart(mini); mini._scripts.OnUpdate(mini); mini._scripts.OnDragStop(mini)
assert(ComboPointDisplayDB.minimapAngle ~= 220 and not mini._scripts.OnUpdate, "minimap drag")

-- Options window: typed numbers apply on Enter and clamp to the slider range (gap: 0-30)
SlashCmdList.COMBOPOINTDISPLAY("")
local boxes = {} -- profile name, gap, X, Y, width, height
for _, f in ipairs(created) do if f._kind == "EditBox" then boxes[#boxes + 1] = f end end
local nameBox, gapBox, xBox, yBox = boxes[1], boxes[2], boxes[3], boxes[4]
gapBox._text = "7"; gapBox._scripts.OnEnterPressed(gapBox)
assert(prof().gap == 7 and gapBox._text == "7", "typed gap")
gapBox._text = "999"; gapBox._scripts.OnEditFocusLost(gapBox)
assert(prof().gap == 30 and gapBox._text == "30", "clamped gap")
gapBox._text = "3"; gapBox._scripts.OnEscapePressed(gapBox)
assert(gapBox._text == "30", "escape restores")

-- Position: X/Y take negative numbers and clamp to half the screen (mock screen 140 x 100)
xBox._text = "-50"; xBox._scripts.OnEnterPressed(xBox)
yBox._text = "-999"; yBox._scripts.OnEnterPressed(yBox)
assert(prof().x == -50 and prof().y == -50, "typed position")
yBox._text = "abc"; yBox._scripts.OnEnterPressed(yBox)
assert(prof().y == -50 and yBox._text == "-50", "junk input ignored")
local mover -- the unnamed frame with drag + right-click handlers
for _, f in ipairs(created) do if f._scripts.OnMouseUp and f._scripts.OnDragStart and not f._name then mover = f end end
mover._scripts.OnDragStart(mover); mover._scripts.OnUpdate(mover); mover._scripts.OnDragStop(mover)
assert(prof().x == 0 and prof().y == 50 and not mover._scripts.OnUpdate, "drag stores coordinates")

-- Profiles: create copies the current one, dropdown switches, delete falls back to the class profile
nameBox._text = "  PvP "; nameBox._scripts.OnEnterPressed(nameBox)
assert(store.profiles.PvP and store.profiles.PvP.gap == 30 and prof() == store.profiles.PvP, "create copies + switches")
prof().gap = 5
assert(store.profiles.Rogue.gap == 30, "profiles are independent")
local dd
for _, f in ipairs(created) do if f._gen then dd = f end end
dd:GenerateMenu()
local names = {}
for _, it in ipairs(dd._items) do names[#names + 1] = it.text .. (it.sel() and "*" or "") end
assert(table.concat(names, ",") == "Druid,Paladin,PvP*,Rogue,Warrior", table.concat(names, ","))
dd._items[4].set()
assert(prof() == store.profiles.Rogue, "dropdown switches")
dd._items[3].set()
byText("Delete")._scripts.OnClick(byText("Delete"), "LeftButton")
assert(not store.profiles.PvP and prof() == store.profiles.Rogue, "delete falls back to class profile")

-- Poke every control
for _, f in ipairs(created) do
    local sc = f._scripts
    for _, btn in ipairs({ "LeftButton", "RightButton" }) do
        if sc.OnClick then f._checked = btn == "LeftButton"; sc.OnClick(f, btn) end
        if sc.OnMouseUp then sc.OnMouseUp(f, btn) end
    end
    if sc.OnValueChanged then sc.OnValueChanged(f, 42) end
    if sc.OnMouseWheel then sc.OnMouseWheel(f, 1) end
    if sc.OnEnter then sc.OnEnter(f); sc.OnLeave(f) end
    if sc.OnDragStart then
        sc.OnDragStart(f)
        if f._scripts.OnUpdate then f._scripts.OnUpdate(f) end
        sc.OnDragStop(f)
    end
end
local seen = {}
for _, k in ipairs(prof().order) do seen[k] = true end
assert(seen.health and seen.power and seen.combo and seen.druidmana and #prof().order == 4, "order intact")

SlashCmdList.COMBOPOINTDISPLAY("")
realPrint("smoke ok")
