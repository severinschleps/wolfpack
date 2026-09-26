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
function M:GetName() return self._name end
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
function M:SetPoint(...)
    self._point = { ... }
    self._points = self._points or {}
    self._points[#self._points + 1] = { ... }
end
function M:ClearAllPoints() self._points = {} end
function M:SetGradient(orient, c1, c2) self._grad = { orient, c1, c2 } end
function M:SetTexture(t) self._tex = t end
function M:SetScale(v) self._scale = v end
function M:SetTextureSliceMargins(...) self._slice = { ... } end
function M:SetAlpha(v) self._alpha = v end
function M:SetDesaturated(v) self._desat = v end
function M:SetAtlas(a) self._atlas = a end
function M:SetTexCoord(...) self._coords = { ... } end
function M:SetStatusBarColor(...) self._sbc = { ... } end
function M:SetStatusBarTexture(t) self._tex = t end
function M:SetCooldown(start, dur) self._cd = { start, dur } end
function M:SetAttribute(k, v) self._attr = self._attr or {}; self._attr[k] = v end
function M:GetAttribute(k) return (self._attr or {})[k] end
function M:RegisterForClicks(...) self._clicks = { ... } end
function M:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
function M:SetTextColor(...) self._color = { ... } end
function M:GetFont() return self._font and self._font[1] or "Fonts\\FRIZQT__.TTF", 25, "OUTLINE" end
function M:SetSwipeTexture(t) self._swipeTex = t end
function M:SetReverse(v) self._reverse = v end
function M:SetReverseFill(v) self._reverseFill = v end
function M:SetFrameLevel(v) self._level = v end
function M:GetFrameLevel() return self._level or 0 end
function M:SetSwipeColor(...) self._swipe = { ... } end
function M:SetTimerDuration(d, interp, dir) self._timer, self._dir = d, dir end
function M:GetAlpha() return self._alpha or 1 end
function M:SetColorTexture(...) self._color = { ... } end
function M:SetVertexColor(...) self._vertex = { ... } end
function M:IsMouseOver() return S.mouseOver end
function M:GetStatusBarTexture() self._sbt = self._sbt or new(); return self._sbt end
function M:AddMaskTexture(m) self._masks = self._masks or {}; self._masks[m] = true end
function M:RemoveMaskTexture(m) if self._masks then self._masks[m] = nil end end
function M:GetParent() return self._parent end
function M:GetName() return self._name end
function M:GetCenter() return 100, 100 end
function M:GetTop() return 150 end
function M:GetBottom() return 60 end
function M:GetFrameLevel() return self._level or 1 end
function M:SetFrameLevel(v) self._level = v end
function M:GetFrameStrata() return self._strata or "MEDIUM" end
function M:SetFrameStrata(v) self._strata = v end
function M:IsMouseEnabled() return true end
function M:GetWidth() return self._w or 140 end
function M:GetHeight() return self._h or 100 end
function M:SetAttribute(k, v) self._attr = self._attr or {}; self._attr[k] = v end
function M:GetUnboundedStringWidth() return 50 end
function M:GetStringWidth() return 8 end
function M:GetStringHeight() return 10 end
function M:GetNumPoints() return self._point and 1 or 0 end
function M:GetChildren() return unpack(self._children or {}) end
function M:GetRegions() return unpack(self._regions or {}) end
function M:GetText() return self._text end
function M:IsObjectType(t) return self._kind == t end
function M:SetMaskTexture(m) self._mask = m end
function M:GetPoint() return unpack(self._point) end
function M:SetupMenu(gen) self._gen = gen end
function M:GenerateMenu() -- records the dropdown's radio items
    local root = { items = {} }
    function root:CreateRadio(text, isSel, set)
        local it = { text = text, sel = isSel, set = set }
        function it:AddInitializer(fn) self.init = fn end
        self.items[#self.items + 1] = it
        return it
    end
    self._gen(self, root)
    self._items = root.items
end
function M:GetEffectiveScale() return 1 end
function M:IsForbidden() return false end
function M:RegisterEvent() evFrame = self end
function M:RegisterUnitEvent() evFrame = self end

Enum = { TooltipDataLineType = { QuestObjective = 8, QuestTitle = 17, QuestPlayer = 18 }, PowerType = { Mana = 0, Rage = 1, Energy = 3, ComboPoints = 4, SoulShards = 7, HolyPower = 9,
    Chi = 12, ArcaneCharges = 16, Essence = 19 } }
CreateFont = function() return new() end
GameFontHighlight = new()
UIParent, Minimap, GameTooltip, UISpecialFrames, SlashCmdList = new(), new(), new(), {}, {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
issecretvalue = function(v) return rawequal(v, SECRET) end
AbbreviateNumbers = function(v) return tostring(v) end
CreateColor = function(...) return { ... } end
PowerBarColor = { ENERGY = { r = 1, g = 1, b = 0 }, MANA = { r = 0, g = 0, b = 1 }, RAGE = { r = 1, g = 0, b = 0 } }
local realPrint = print
S.printed = {}
print = function(msg) -- addon errors fail the test; ordinary chat output is kept
    msg = tostring(msg)
    if msg:find("error:") then error("addon reported: " .. msg, 0) end
    S.printed[#S.printed + 1] = msg
end
C_Item = { GetItemInfo = function(id)
    local it = (S.items or {})[id]
    if not it then return nil end
    return it.name, nil, nil, it.level
end }
GetCursorPosition = function() return 10, 20 end
strtrim = function(str) return (str:gsub("^%s+", ""):gsub("%s+$", "")) end
StaticPopupDialogs = {}
StaticPopup_Show = function(which, _, _, data) StaticPopupDialogs[which].OnAccept(nil, data) end -- clicks Yes
UnitName = function() return S.name end
InCombatLockdown = function() return S.combat end
-- minimap: two addon buttons sit on it, plus Blizzard's tracking and calendar
Minimap = new()
Minimap._w = 140
local function addonButton(name)
    local b = new("Button")
    b._name, b._parent, b._w = name, Minimap, 24 -- icon-sized, like a real minimap button
    b:SetPoint("CENTER", Minimap, "CENTER", 10, 0)
    return b
end
Minimap._children = { addonButton("SomeAddonIcon"), addonButton("AnotherAddonIcon") }
-- one of them draws its own counter
local iconCount = new("FontString")
iconCount._text = "3"
Minimap._children[1]._regions = { iconCount }
MinimapBackdrop, MinimapCompassTexture = new(), new()
MinimapCluster = new()
MinimapCluster.Tracking, GameTimeFrame = new(), new()
MinimapCluster.ZoneTextButton, TimeManagerClockButton = new(), new()
MinimapCluster.DielFrame = new() -- Forever's day/night dial
MinimapCluster.BorderTop = new() -- the dark strip behind Blizzard's zone text
GetMinimapZoneText = function() return "Ruins of Lordaeron" end
MinimapCluster.Tracking._w, GameTimeFrame._w = 26, 26
-- a counter text left loose on the minimap, like some addon buttons leave behind
local strayCount = new("FontString")
strayCount._text = "3"
Minimap._regions = { strayCount }
GetNetStats = function() return 0, 0, 30, 42 end
date = function() return "12:34" end
C_Map = {
    GetBestMapForUnit = function() return 84 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.253, 0.607 end } end,
    -- a small map tree: the world, one continent, two zones
    GetMapInfo = function(id) return ({ [947] = { name = "Azeroth", mapType = 2 },
        [13] = { name = "Eastern Kingdoms", mapType = 2 },
        [52] = { name = "Westfall", mapType = 3 },
        [84] = { name = "Stormwind City", mapType = 3 } })[id] end,
    GetMapChildrenInfo = function(id)
        if id == 947 then return { { mapID = 13 } } end
        if id == 13 then return { { mapID = 52 }, { mapID = 84 } } end
        return {}
    end,
    SetUserWaypoint = function(point) S.waypoint = point end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { map = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) S.superTrack = on end }
WorldMapFrame = new()
WorldMapFrame.SetMapID = function(self, id) S.mapShown = id end
ToggleWorldMap = function() S.mapOpen = true end
MainActionBar = new()
MainActionBar.EndCaps = { LeftEndCap = { Texture = new() }, RightEndCap = { Texture = new() } }
BagsBar = new()
BagsBar._parent = UIParent
BagsBar:SetPoint("TOPRIGHT", "MicroButtonAndBagsBar", "TOPRIGHT", 0, 0)
ContainerFrameCombinedBags, ContainerFrame1 = new(), new()
ContainerFrameCombinedBags._shown, ContainerFrame1._shown = false, false
S.calls = {}
local function record(name) return function() S.calls[#S.calls + 1] = name end end
AcceptQuest, ConfirmAcceptQuest = record("accept"), record("confirm")
AcknowledgeAutoAcceptQuest, StaticPopup_Hide = record("ack"), record("hidepopup")
IsShiftKeyDown = function() return S.shift end
IsInGroup = function() return S.group end
IsInRaid = function() return S.raid or false end
CanMerchantRepair = function() return S.canRepair end
GetRepairAllCost = function() return S.repairCost or 0, S.canRepair or false end
RepairAllItems = function() S.repaired = (S.repaired or 0) + 1 end
GetMoney = function() return S.money or 0 end
-- this client has no GetCoinTextureString at all, which is what broke the repair message
issecretvalue = function(v) return v == SECRET end
UnitIsUnit = function(a, b) return a == b or (b == "target" and a == S.targetUnit) end
RegisterUnitWatch = function(f) f._watched = true end
GetNumGroupMembers = function() return S.members or 0 end
UnitIsDeadOrGhost = function() return false end
UnitLevel = function() return S.level or 60 end
UnitRace = function() return "Orc", "Orc", S.raceID or 2 end
UnitFactionGroup = function() return S.faction or "Horde" end
IsSpellKnown = function(id) return (S.known or {})[id] == true end
GetMoneyString = function(c) return tostring(math.floor(c / 10000)) .. "g" end
-- the game's macro list: 120 slots, names unique, nothing doing in combat
S.gameMacros = {}
GetMacroIndexByName = function(name)
    for i, m in ipairs(S.gameMacros) do if m.name == name then return i end end
    return 0
end
CreateMacro = function(name, icon, body)
    assert(not S.combat, "the game refuses macros in combat")
    if #S.gameMacros >= (S.macroRoom or 120) then error("out of macro slots") end
    S.gameMacros[#S.gameMacros + 1] = { name = name, icon = icon, body = body }
    return #S.gameMacros
end
EditMacro = function(i, name, icon, body)
    S.gameMacros[i] = { name = name, icon = icon, body = body }
end
PickupMacro = function(i) S.cursor = S.gameMacros[i] end
GameTooltip.SetSpellByID = function(_, id) S.tooltip = id end
GetNumMacroIcons = function() return S.macroIcons and #S.macroIcons or 0 end
GetMacroIconInfo = function(i) return (S.macroIcons or {})[i] end
C_SpellBook = { GetSpellBookItemName = function(i) return (S.book or {})[i] and S.book[i][1] or nil end }
GetInventorySlotInfo = function() return 0 end
GetInventoryItemID = function() return S.ammoID end
GetInventoryItemCount = function() return S.ammoCount or 0 end
GetPetHappiness = function() return S.happiness end
GetItemIcon = function(id) return 1000 + id end
GetWeaponEnchantInfo = function() return S.mainEnchant or false, S.mainMs or 0, 0, 0,
    S.offEnchant or false, S.offMs or 0 end
GetInventoryItemTexture = function(_, slot)
    return (S.weapons or {})[slot] or (slot == 0 and S.ammoIcon) or nil
end
UnitGroupRolesAssigned = function(unit) return (S.units or {})[unit] or "NONE" end
GetTexCoordsForRoleSmallCircle = function() return 0, 0.5, 0, 0.5 end
C_UnitAuras = {
    -- in combat this client throws instead of answering, like the live one does
    GetAuraDataByIndex = function(unit, i, filter)
        assert(not S.combat, "aura data is secret in combat")
        if filter == "HARMFUL" then return (S.debuffs or {})[i] end
        return (S.auras or {})[i]
    end,
    -- the game's own list of what you can take off; its entries may hold secret fields
    GetUnitAuras = function(unit, filter)
        if filter == "HARMFUL|RAID" then return S.curable or {} end
        return S.auras or {}
    end,
    GetAuraDataBySpellName = function(unit, name)
        for _, a in ipairs(S.auras or {}) do
            if a.name == name then return a end
        end
    end,
    GetAuraDuration = function() return { IsZero = function() return false end } end,
}
S.time = 1000
GetTime = function() return S.time end
-- Duration objects stand in for the client's secret-safe ones: everything about them, IsZero
-- included, is secret, so the addon may only pass them on. Reading one here fails the test.
C_PetInfo = { GetPetHappiness = function()
    if S.happyTable then return { happiness = S.happiness } end
    return S.happiness
end }
C_Spell = { GetSpellPowerCost = function(id) return S.costs and S.costs[id] or {} end,
    GetSpellTexture = function(id) -- the game takes a name as readily as an id
        if type(id) == "string" then return (S.spellTextures or {})[id] end
        return id == 139 and 135953 or 100 + id
    end,
    GetSpellInfo = function(id) return { name = (S.spellNames or {})[id] or ("Spell" .. id) } end }
GetTotemDuration = function(slot)
    return setmetatable({ slot = slot }, { __index = function() error("read a secret duration") end })
end
UnitGetTotalAbsorbs = function(unit) return unit == "player" and (S.absorb or 0) or 0 end
-- The heal prediction calculator takes the secret numbers and hands back drawable values
CreateUnitHealPredictionCalculator = function()
    return {
        SetIncomingHealClampMode = function() end,
        SetIncomingHealOverflowPercent = function() end,
        GetMaximumHealth = function() return 1000 end,
        GetIncomingHeals = function() return S.incomingHeal or 0 end,
    }
end
UnitGetDetailedHealPrediction = function() end
UnitCastingInfo = function() if S.cast then return S.cast, "", 136116 end end
UnitChannelInfo = function() if S.channel then return S.channel, "", 136197 end end
UnitCastingDuration = function() return S.cast and "castDuration" end
UnitChannelDuration = function() return S.channel and "channelDuration" end
QuestGetAutoAccept = function() return S.autoQuest end
QuestIsFromAreaTrigger = function() return S.areaTrigger end
CompleteQuest = record("complete")
IsQuestCompletable = function() return S.completable end
GetNumQuestChoices = function() return S.choices or 0 end
GetQuestMoneyToGet = function() return S.cost or 0 end
GetQuestReward = function(c) S.calls[#S.calls + 1] = "reward" .. c end
C_GossipInfo = {
    GetActiveQuests = function() return S.gossip or {} end,
    SelectActiveQuest = function(id) S.calls[#S.calls + 1] = "turnin" .. id end,
    GetAvailableQuests = function() return S.available or {} end,
    SelectAvailableQuest = function(id) S.calls[#S.calls + 1] = "take" .. id end,
}
GetNumActiveQuests = function() return #(S.greeting or {}) end
GetActiveTitle = function(i) return "Quest " .. i, S.greeting[i] end
SelectActiveQuest = function(i) S.calls[#S.calls + 1] = "greetTurnin" .. i end
GetNumAvailableQuests = function() return S.greetNew or 0 end
SelectAvailableQuest = function(i) S.calls[#S.calls + 1] = "greetTake" .. i end
UnitGUID = function() return S.npc end
GossipFrame, QuestFrame = new(), new()
GossipFrame._shown, QuestFrame._shown = false, false
hooksecurefunc = function(t, name, fn)
    if type(t) == "string" then t, name, fn = _G, t, name end -- the global-function form
    local orig = t[name]
    t[name] = function(...) orig(...); fn(...) end
end
-- bags: 0 = backpack (a gray with value, a gray worth nothing, a green), 1 = empty
S.bags = { [0] = {
    { quality = 0, hasNoValue = false }, { quality = 0, hasNoValue = true },
    { quality = 2, hasNoValue = false }, { quality = 0, hasNoValue = false, isLocked = true },
}, [1] = {} }
S.sold = {}
S.money = 100
NUM_BAG_SLOTS = 1
GetMoney = function() return S.money end
GetMoneyString = function(m) return m .. "c" end
MerchantFrame = new()
C_Container = {
    GetContainerNumSlots = function(bag) return #(S.bags[bag] or {}) end,
    GetContainerItemInfo = function(bag, slot) return S.bags[bag] and S.bags[bag][slot] end,
    UseContainerItem = function(bag, slot) S.sold[#S.sold + 1] = bag .. ":" .. slot; S.money = S.money + 5 end,
}
C_Timer = {
    After = function(_, fn) fn() end,
    NewTicker = function(_, fn) local t = { cancelled = false }; function t:Cancel() self.cancelled = true end
        S.ticker = { fn = fn, obj = t }; return t end,
}
PlayerCastingBarFrame = new()
PlayerCastingBarFrame._parent = UIParent
-- Serialization stand-in: deep copies, so nothing is shared between export and import
local blobs = {}
local bakedStub -- stands in for the baked profile string, which the fake codec can't decode
local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = deepcopy(v) end
    return c
end
C_EncodingUtil = {
    SerializeCBOR = function(t) blobs[#blobs + 1] = deepcopy(t); return "blob" .. #blobs end,
    DeserializeCBOR = function(str) local i = tonumber(str:match("^blob(%d+)$")); return deepcopy(blobs[i]) end,
    CompressString = function(str) return "z" .. str end,
    DecompressString = function(str) assert(str:sub(1, 1) == "z", "bad deflate"); return str:sub(2) end,
    EncodeBase64 = function(str) return "B" .. str end,
    DecodeBase64 = function(str) return str:sub(1, 1) == "B" and str:sub(2) or bakedStub end,
}
C_EditMode = { ConvertLayoutInfoToString = function(info) return "EDITMODE:" .. info.layoutName end }
EditModeManagerFrame = { GetActiveLayoutInfo = function() return { layoutName = "MyLayout" } end,
    IsEditModeActive = function() return S.editMode end }
ChatFontNormal = new()
CombatTextFont = new() -- the scrolling combat text's font object
S.cvars = {}
SetCVar = function(k, v) S.cvars[k] = v end
GetCVarBool = function(k) return S.cvars[k] == "1" end
EditModeManagerFrame = EditModeManagerFrame or new()
ShowUIPanel = function(f) S.shownPanel = f end
PlayerFrame = new()
PlayerFrame._parent = UIParent
GetRealmName = function() return "Realm" end
CreateFrame = function(kind, name, parent, template)
    local f = new(kind)
    f._name, f._parent, f._template = name, parent, template
    if name then _G[name] = f end
    created[#created + 1] = f
    return f
end
ColorPickerFrame = {
    SetupColorPickerAndShow = function(_, info) S.picker = info end,
    GetColorRGB = function() return 0.1, 0.2, 0.3 end,
    GetColorAlpha = function() return 0.5 end,
}
S.plates, S.tips, S.related, S.quests = {}, {}, {}, {}
C_NamePlate = { GetNamePlateForUnit = function(unit) return unit == "target" and S.plate or S.plates[unit] end }
C_TooltipInfo = { GetUnit = function(unit) return { lines = S.tips[unit] or {} } end }
C_QuestLog = {
    UnitIsRelatedToActiveQuest = function(unit) return S.related[unit] or false end,
    GetNumQuestLogEntries = function() return #S.quests end,
    GetInfo = function(i) return S.quests[i].info end,
    GetQuestObjectives = function(id) for _, q in ipairs(S.quests) do if q.info.questID == id then return q.objectives end end end,
    IsQuestFlaggedCompleted = function(id) return (S.questDone or {})[id] == true end,
    GetLogIndexForQuestID = function(id) return (S.questLog or {})[id] end,
}
UnitClass = function(unit) -- "Rogue", "ROGUE"
    local token = (S.unitClasses or {})[unit] or (unit == "target" and S.targetClass) or S.class
    return token:sub(1, 1) .. token:sub(2):lower(), token
end
UnitIsPlayer = function(unit) return unit == "player" or (unit == "target" and S.targetIsPlayer) end
local CLASS = { ROGUE = { r = 1, g = 0.96, b = 0.41 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
C_ClassColor = { GetClassColor = function(token) return CLASS[token] end }
UnitPowerType = function() return S.ptype, TOKENS[S.ptype] end
UnitPower = function() return S.secret and SECRET or 3 end
UnitPowerMax = function(_, t) return S.secret and SECRET or (S.max[t] or 100) end
UnitHealth = function(unit)
    if unit == "target" then return S.targetHP elseif unit == "pet" then return S.petHP end
    return SECRET
end
UnitExists = function(unit)
    if unit == "pet" then return S.petHP ~= nil end
    if unit == "player" then return true end
    if (S.units or {})[unit] then return true end
    return unit == "target" and S.targetHP ~= nil
end
UnitHealthMax = function() return 1000 end

DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local ns = {}
assert(loadfile("WolfpackAddon/Data/Training.lua"))("WolfpackAddon", ns) -- loaded first, per the toc
assert(loadfile("WolfpackAddon_Loot/Data.lua"))() -- its own addon; it sets a global
assert(loadfile("WolfpackAddon/WolfpackAddon.lua"))("WolfpackAddon", ns)
for _, c in ipairs({ "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN",
    "WARLOCK", "WARRIOR" }) do
    assert(type(ns.training[c]) == "table", c .. " has a spell list")
end
local function fire(e, ...) evFrame._scripts.OnEvent(evFrame, e, ...) end
-- each class logs in as its own character
local function login(class, ptype) S.class, S.name, S.ptype = class, class .. "Char", ptype; fire("PLAYER_LOGIN") end
local function prof() return WolfpackAddonDB.profiles[WolfpackAddonDB.chars[S.name .. " - Realm"]] end
local function byText(text) for _, f in ipairs(created) do if f._text == text then return f end end end
local fr = ns.frames

-- Rogue, secret values: 5 pips, each lit when points >= i; stack = health 18, power 14, combo 12,
-- cast bar and swing rows only join the stack while they run
-- the panels hear about the world before a profile exists, and must sit that out quietly
for _, evf in ipairs({ ns.mgEv, ns.hnEv, ns.bfEv }) do
    evf._scripts.OnEvent(evf, "PLAYER_ENTERING_WORLD")
end

login("ROGUE", 3)
fire("UNIT_POWER_FREQUENT"); fire("UNIT_HEALTH")
assert(fr.combo:IsShown() and fr.combo.n == 5, "rogue combo pips")
for i = 1, 5 do
    local s = fr.combo.segs[i]
    assert(s._min == i - 1 and s._max == i and s._value == SECRET, "pip " .. i)
end
assert(not fr.druidmana:IsShown(), "rogue has no druid mana")
assert(WolfpackAddonFrame._h == 48, "stack height " .. tostring(WolfpackAddonFrame._h))

-- Extra space above / below a bar pushes the rest of the stack
local hp = prof().regular.bars.health
hp.padBottom = 10
fire("UNIT_MAXPOWER")
assert(fr.power._point[5] == -30 and WolfpackAddonFrame._h == 58, "space below health")
hp.padBottom, prof().regular.bars.power.padTop = 0, 6
fire("UNIT_MAXPOWER")
assert(fr.power._point[5] == -26, "space above power")
prof().regular.bars.power.padTop = 0
fire("UNIT_MAXPOWER")

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
local store = WolfpackAddonDB
assert(store.profiles.Rogue and store.profiles.Druid and store.profiles.Paladin and store.profiles.Warrior, "class profiles")
assert(store.chars["WARRIORChar - Realm"] == "Warrior", "character on its class profile")

-- Per-bar offsets move only that bar; the next bar keeps its slot (18 + 2 = 20, then 20 + 14 + 2 = 36)
S.secret = true
login("ROGUE", 3)
local R = prof().regular.bars
R.power.x, R.power.y = 5, -3
fire("UNIT_MAXPOWER")
local pp, cp = fr.power._point, fr.combo._point
assert(pp[1] == "TOP" and pp[2] == WolfpackAddonFrame and pp[4] == 5 and pp[5] == -23, "power offset")
assert(cp[4] == 0 and cp[5] == -36, "combo keeps its slot")
R.power.x, R.power.y = 0, 0

-- Target health: only with the option on and a target; right of the player's health bar
local tf = ns.targetFrame
fire("PLAYER_TARGET_CHANGED")
assert(not tf:IsShown(), "option off")
prof().regular.bars.health.target = true
fire("PLAYER_TARGET_CHANGED")
assert(not tf:IsShown(), "no target")
S.targetHP = 500
fire("PLAYER_TARGET_CHANGED")
local tp, hp = tf._point, fr.health._point
assert(tf:IsShown() and tp[1] == "LEFT" and tp[2] == fr.health and tp[3] == "RIGHT" and tp[4] == 2, "beside health")
assert(fr.health._w == 109 and tf._w == 109, "220 wide, 2 gap: two halves of 109")
assert(hp[1] == "TOPLEFT" and hp[3] == "TOP" and hp[4] == -110, "player half starts at the bar's left edge")
assert(tf.segs[1]._value == 500 and tf.segs[1]._max == 1000 and tf.text._text == "500", "target values")
prof().regular.bars.health.colorMode = "class"
S.targetClass = "MAGE"; fire("PLAYER_TARGET_CHANGED")
assert(tf.segs[1]._sbc[1] == 0.2 and fr.health.segs[1]._sbc[1] == 1, "NPC target: custom color, you: class")
S.targetIsPlayer = true; fire("PLAYER_TARGET_CHANGED")
assert(tf.segs[1]._sbc[1] == 0.25, "player target: their class color")
S.targetIsPlayer, prof().regular.bars.health.colorMode = nil, "custom"
S.targetHP = 250; fire("UNIT_HEALTH", "target")
assert(tf.segs[1]._value == 250 and fr.health.segs[1]._value == SECRET, "target updates, player keeps its own")
assert(WolfpackAddonFrame._w == 220, "stack width ignores the target bar")
S.targetHP = nil; fire("PLAYER_TARGET_CHANGED")
assert(not tf:IsShown() and fr.health._w == 220 and fr.health._point[1] == "TOP", "target gone: full width again")
prof().regular.bars.health.target = false

-- Background color and gradient points: one slice per pair of points, masked by the bar's fill
local gb = prof().regular.bars.health
gb.bgColor = { 0.1, 0.2, 0.3, 0.6 }
fire("UNIT_MAXPOWER")
local gs = fr.health.segs[1]
assert(gs.bg._color[1] == 0.1 and gs.bg._color[4] == 0.6, "background color per bar")
assert(#gs.slices == 0, "no slices without a gradient")
gb.gradient = true
fire("UNIT_MAXPOWER")
assert(#gs.slices == 1 and gs.slices[1]:IsShown() and gs._sbc[4] == 0, "two points: one slice, fill hidden")
assert(gs.slices[1]._masks[gs.fillMask], "slices show only over the filled part")
tinsert(gb.stops, 2, { pos = 50, color = { 0, 1, 0, 1 } })
fire("UNIT_MAXPOWER")
assert(#gs.slices == 2 and gs.slices[2]:IsShown(), "three points: two slices")
local p1, p2 = gs.slices[1]._points, gs.slices[2]._points
assert(p1[1][4] == 0 and p1[2][4] == 110 and p2[1][4] == 110 and p2[2][4] == 220, "slices span 0-50-100% of 220")
assert(gs.slices[1]._grad[1] == "HORIZONTAL" and gs.slices[1]._grad[3][2] == 1, "green at the middle point")
gb.direction = "left"
fire("UNIT_MAXPOWER")
assert(gs.slices[1]._grad[3][2] == 1 and gs.slices[2]._grad[3][1] == 0.2, "reversed: colors mirror")
gb.direction = "down"
fire("UNIT_MAXPOWER")
assert(gs.slices[1]._grad[1] == "VERTICAL" and gs.slices[1]._points[2][5] == -9, "top to bottom: 50% of 18")
gb.gradient, gb.direction = false, "right"
table.remove(gb.stops, 2)
fire("UNIT_MAXPOWER")
assert(not gs.slices[1]:IsShown() and gs._sbc[1] == 0.2, "gradient off: solid color again")

-- Grow direction: pinning the bottom edge makes the stack grow upwards instead
local R1 = prof().regular
assert(WolfpackAddonFrame._point[1] == "TOP", "grows down by default")
R1.grow = "up"
fire("PLAYER_ENTERING_WORLD")
assert(WolfpackAddonFrame._point[1] == "BOTTOM" and WolfpackAddonFrame._point[4] == R1.x, "pinned by its bottom")
S.plate = new(); prof().nameplate.grow = "up"; fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
assert(ns.plateFrames.combo._parent._point[1] == "BOTTOM", "nameplate stack too")
S.plate = nil; prof().nameplate.grow = "down"; fire("NAME_PLATE_UNIT_REMOVED", "nameplate9")
local mover2
for _, f in ipairs(created) do if f._scripts.OnMouseUp and f._scripts.OnDragStart and not f._name then mover2 = f end end
mover2._scripts.OnDragStart(mover2); mover2._scripts.OnDragStop(mover2)
assert(R1.y == -40, "drag stores the bottom edge (60 - 100)")
R1.grow, R1.x, R1.y = "down", 0, -120
fire("PLAYER_ENTERING_WORLD")

-- Cast bar: out of the stack while idle, joins it while casting; channels drain; icon side
local cb = fr.castbar
assert(not cb:IsShown() and WolfpackAddonFrame._h == 48, "idle: out of the stack")
S.cast = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
local cs = cb.segs[1]
assert(cb:IsShown() and WolfpackAddonFrame._h == 64 and cb._point[5] == -50, "casting: joins the stack")
assert(cs._timer == "castDuration" and cs._dir == 0, "cast fills up")
assert(cb.text._text == "Fireball" and cb.text:IsShown() and cb.icon._tex == 136116 and cb.icon:IsShown(), "name + icon")
assert(cs._w == 204 and cs._point[4] == 16 and cb.icon._point[1] == "LEFT", "icon left: bar starts after 14 + 2")
S.cast = nil; S.channel = "Drain Life"; fire("UNIT_SPELLCAST_CHANNEL_START", "player")
assert(cs._timer == "channelDuration" and cs._dir == 1 and cb.text._text == "Drain Life", "channel drains")
prof().regular.bars.castbar.iconSide = "right"; fire("UNIT_MAXPOWER")
assert(cs._w == 204 and cs._point[4] == 0 and cb.icon._point[1] == "RIGHT", "icon right")
prof().regular.bars.castbar.icon = false; fire("UNIT_MAXPOWER")
assert(cs._w == 220 and not cb.icon:IsShown(), "no icon: full width")
S.channel = nil; fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
assert(not cb:IsShown() and WolfpackAddonFrame._h == 48, "done: out of the stack again")
prof().locked = false; fire("UNIT_MAXPOWER")
assert(cb:IsShown() and cb.text._text == "Cast Bar" and cb.icon._tex == 134400, "unlocked: preview")
prof().locked = true; fire("UNIT_MAXPOWER")
assert(not cb:IsShown(), "locked again: gone")
prof().regular.bars.castbar.icon, prof().regular.bars.castbar.iconSide = true, "left"

-- Swing timer: a row joins the stack only while that weapon swings
local sw, swf = prof().regular.bars.swing, ns.swingFrames.regular
sw.off, sw.ranged = true, true
fire("UNIT_MAXPOWER")
assert(not swf[1]:IsShown() and not swf[3]:IsShown() and WolfpackAddonFrame._h == 48, "idle: no rows")
fire("PLAYER_SWING", 2.6, 0) -- main hand, 2.6 s
assert(swf[1]:IsShown() and WolfpackAddonFrame._h == 60 and swf[1]._point[5] == -50, "main hand joins")
assert(swf[1].segs[1]._max == 2.6 and swf[1].segs[1]._value == 0 and swf[1].text._text == "2.6", "seconds left")
assert(not swf[2]:IsShown(), "off hand still idle")
S.time = 1001; ns.swingTicker._scripts.OnUpdate()
assert(swf[1].segs[1]._value == 1 and swf[1].text._text == "1.6", "counts down")
fire("PLAYER_SWING", 1.8, 2) -- ranged
assert(swf[3]:IsShown() and WolfpackAddonFrame._h == 72 and swf[3]._point[5] == -62, "ranged joins below it")
S.time = 1010; ns.swingTicker._scripts.OnUpdate()
assert(not swf[1]:IsShown() and not swf[3]:IsShown(), "done: rows leave")
assert(WolfpackAddonFrame._h == 48 and not ns.swingTicker._scripts.OnUpdate, "stack closed up, ticker stopped")
prof().locked = false; fire("UNIT_MAXPOWER")
assert(swf[1]:IsShown() and swf[3]:IsShown() and swf[1].text._text == "Main hand", "unlocked: preview rows")
prof().locked = true
sw.off, sw.ranged = false, false
fire("UNIT_MAXPOWER")

-- Pet health: only with a pet; own value; joins the stack (48 + 2 + 10)
local pb = fr.pethealth
assert(not pb:IsShown() and WolfpackAddonFrame._h == 48, "no pet: no bar")
S.petHP = 300; fire("UNIT_PET", "player")
assert(pb:IsShown() and pb.segs[1]._value == 300 and pb.segs[1]._max == 1000 and pb.text._text == "300", "pet bar")
assert(WolfpackAddonFrame._h == 60 and pb._point[5] == -50, "joins the stack")
S.petHP = 120; fire("UNIT_HEALTH", "pet")
assert(pb.segs[1]._value == 120 and fr.health.segs[1]._value == SECRET, "pet updates on its own")
S.petHP = nil; fire("UNIT_PET", "player")
assert(not pb:IsShown() and WolfpackAddonFrame._h == 48, "pet gone")

-- In-combat icon: in combat only (or previewing), centered on the chosen bar's left edge
local ci, icon = prof().regular.combatIcon, ns.combatIcon
fire("UNIT_MAXPOWER")
assert(not icon:IsShown(), "out of combat: hidden")
fire("PLAYER_REGEN_DISABLED")
local ip = icon._point
assert(icon:IsShown() and ip[1] == "CENTER" and ip[2] == fr.health and ip[3] == "LEFT" and ip[4] == -12, "health bar's left edge")
assert(icon.tex._atlas == "UI-HUD-UnitFrame-Player-CombatIcon" and icon._w == 20, "default art and size")
ci.bar, ci.style = "druidmana", "classic"; fire("UNIT_MAXPOWER")
assert(icon._point[2] == WolfpackAddonFrame, "attached bar hidden: falls back to the group")
assert(icon.tex._tex == 130936 and icon.tex._coords[1] == 0.5, "classic swords cropped from the state icon")
ci.show = false; fire("UNIT_MAXPOWER")
assert(not icon:IsShown(), "show off")
ci.show, ci.bar, ci.style = true, "health", "atlas"
fire("PLAYER_REGEN_ENABLED")
assert(not icon:IsShown(), "combat over")
prof().locked = false; fire("UNIT_MAXPOWER")
assert(icon:IsShown(), "unlocked: preview for placing it")
prof().locked = true; fire("UNIT_MAXPOWER")

-- Border and radius: border inside the bar's size, bar inset by it; one mask file per radius,
-- sliced at native size (Media/Round/r<N>.tga)
local hb = prof().regular.bars.health -- 220 x 18
local function maskR(m) return m._tex:match("r(%d+)%.tga$") + 0, m._slice[1] end
hb.borderSize, hb.radius = 2, 8
fire("UNIT_MAXPOWER")
local seg = fr.health.segs[1]
assert(seg._w == 216 and seg._h == 14 and seg._point[4] == 2, "inset by the border")
assert(seg.border:IsShown() and seg.border._point[4] == 2 and seg.border._point[5] == -2, "border around it")
assert(maskR(seg.borderMask) == 8 and select(2, maskR(seg.borderMask)) == 8 and maskR(seg.mask) == 6, "outer 8, inner 8 - 2")
assert(seg.border._masks[seg.borderMask] and seg.bg._masks[seg.mask] and seg:GetStatusBarTexture()._masks[seg.mask], "masked")
hb.radius = 32; fire("UNIT_MAXPOWER")
assert(maskR(seg.borderMask) == 9 and maskR(seg.mask) == 7, "radius capped at half the height")
hb.radius = "pill"; fire("UNIT_MAXPOWER")
assert(maskR(seg.borderMask) == 9 and maskR(seg.mask) == 7, "pill: half of each height")
for r = 1, 50 do assert(io.open("WolfpackAddon/Media/Round/r" .. r .. ".tga"), "mask file r" .. r) end
hb.borderSize, hb.radius = 0, 0; fire("UNIT_MAXPOWER")
assert(not seg.border:IsShown() and seg._w == 220 and not seg.bg._masks[seg.mask], "off: square, no border")
assert(not seg:GetStatusBarTexture()._masks[seg.mask], "fill unmasked")

-- Highlight: overlay on every bar of the group while hovered; no polling unless it's on
local hl, anchorF = prof().regular.highlight, WolfpackAddonFrame
fire("UNIT_MAXPOWER")
assert(not anchorF._scripts.OnUpdate, "no polling by default")
hl.show = true; fire("UNIT_MAXPOWER")
local poll = anchorF._scripts.OnUpdate
S.mouseOver = true; poll(anchorF)
assert(fr.health.segs[1].hl:IsShown() and fr.combo.segs[5].hl:IsShown(), "hovered: highlighted")
assert(fr.health.segs[1].hl._color[4] == 0.25, "default opacity 25%")
fire("UNIT_MAXPOWER")
assert(fr.power.segs[1].hl:IsShown(), "stays lit through a re-layout")
S.mouseOver = false; poll(anchorF)
assert(not fr.health.segs[1].hl:IsShown() and not fr.combo.segs[5].hl:IsShown(), "left: off")
S.mouseOver = true; poll(anchorF)
hl.show = false; fire("UNIT_MAXPOWER")
assert(not anchorF._scripts.OnUpdate and not fr.health.segs[1].hl:IsShown(), "option off clears it")
S.mouseOver = false

-- Color modes: power bar defaults to its power type color; class color for bar and/or border;
-- border can follow the bar's color. Alpha stays from the swatches.
assert(fr.power.segs[1]._sbc[1] == 1 and fr.power.segs[1]._sbc[3] == 0, "power type color (energy)")
local hc = prof().regular.bars.health
local hs = fr.health.segs[1]
hc.colorMode, hc.borderSize, hc.borderMode = "class", 1, "bar"; fire("UNIT_MAXPOWER")
assert(hs._sbc[1] == 1 and hs._sbc[3] == 0.41 and hs.border._color[3] == 0.41, "class bar, border = bar")
hc.colorMode, hc.borderMode = "custom", "class"; fire("UNIT_MAXPOWER")
assert(hs._sbc[1] == 0.2 and hs.border._color[3] == 0.41 and hs.border._color[4] == 1, "custom bar, class border")
hc.borderSize, hc.borderMode = 0, "custom"

-- Player frame: hide by reparenting (out of combat only), restore to the original parent
local R0 = prof().regular
fire("UNIT_MAXPOWER")
assert(PlayerFrame._parent == UIParent, "untouched by default")
S.combat = true
R0.hidePlayerFrame = true; fire("UNIT_MAXPOWER")
assert(PlayerFrame._parent == UIParent, "not in combat")
S.combat = false; fire("PLAYER_REGEN_ENABLED")
local hider = PlayerFrame._parent
assert(hider ~= UIParent and not hider:IsShown(), "hidden after combat")
R0.hidePlayerFrame = false; fire("UNIT_MAXPOWER")
assert(PlayerFrame._parent == UIParent, "restored")

-- Blizzard cast bar: parked under the hidden frame, stays there when Blizzard re-parents it
local pcb = PlayerCastingBarFrame
assert(pcb._parent == UIParent and rawget(pcb, "SetParent") == nil, "untouched and unhooked by default")
R0.hideBlizzCastbar = true; fire("UNIT_MAXPOWER")
assert(pcb._parent == hider, "hidden")
pcb:SetParent(PlayerFrame) -- Blizzard attaching it to the player frame
assert(pcb._parent == hider, "re-parked after Blizzard moved it")
S.combat = true; R0.hideBlizzCastbar = false; fire("UNIT_MAXPOWER")
assert(pcb._parent == hider, "waits for combat to end")
S.combat = false; fire("PLAYER_REGEN_ENABLED")
assert(pcb._parent == PlayerFrame, "restored where Blizzard last wanted it")
pcb:SetParent(UIParent)
assert(pcb._parent == UIParent, "option off: Blizzard moves it freely")

-- Right-click menu: a secure unit button over the bars, synced out of combat, off while unlocked
assert(not WolfpackAddonClicker, "no secure button unless asked")
R0.playerMenu = true; fire("UNIT_MAXPOWER")
local ck = WolfpackAddonClicker
assert(ck._template == "SecureUnitButtonTemplate" and ck._attr.unit == "player" and ck._attr.type2 == "togglemenu", "menu button")
assert(ck._point[1] == "TOP" and ck._point[2] == UIParent and ck._point[4] == R0.x and ck._point[5] == R0.y, "over the bars")
assert(ck._w == 220 and ck._h == 48 and ck:IsShown(), "same size as the bars")
prof().locked = false; fire("UNIT_MAXPOWER")
assert(not ck:IsShown(), "unlocked: drag handle gets the mouse")
assert(ck._attr.type1 == nil, "left click off by default")
prof().locked, R0.playerTarget = true, true; fire("UNIT_MAXPOWER")
assert(ck:IsShown() and ck._attr.type1 == "target" and ck._attr.type2 == "togglemenu", "left targets, right menu")
R0.playerMenu = false; fire("UNIT_MAXPOWER")
assert(ck:IsShown() and ck._attr.type1 == "target" and ck._attr.type2 == nil, "left click alone")
R0.playerTarget = false; fire("UNIT_MAXPOWER")
assert(not ck:IsShown(), "both off")
R0.playerMouseover = true; fire("UNIT_MAXPOWER")
assert(ck:IsShown() and ck._attr.unit == "player" and not ck._attr.type1 and not ck._attr.type2, "mouseover only: no clicks")
R0.playerMouseover = false; fire("UNIT_MAXPOWER")

-- Nameplate layout is separate: own show flags, sizes, gap and group offset
local pf, plateStack = ns.plateFrames, ns.plateFrames.combo._parent
local N = prof().nameplate.bars
N.combo.show = true
fire("PLAYER_TARGET_CHANGED")
assert(fr.combo:IsShown() and not pf.combo:IsShown() and not plateStack:IsShown(), "no plate: regular only")
S.plate = new(); fire("NAME_PLATE_UNIT_ADDED")
assert(fr.combo:IsShown() and pf.combo:IsShown(), "both")
assert(plateStack._parent == S.plate and plateStack:IsShown(), "plate stack on the plate")
local ps = plateStack._point
assert(ps[2] == S.plate and ps[3] == "BOTTOM" and ps[4] == 0 and ps[5] == -2, "plate group offset")
assert(WolfpackAddonFrame._h == 48 and plateStack._h == 6, "stacks sized independently")
R.combo.show = false
N.health.show = true
fire("PLAYER_TARGET_CHANGED")
assert(not fr.combo:IsShown() and pf.combo:IsShown() and pf.health:IsShown(), "nameplate only")
assert(WolfpackAddonFrame._h == 34 and plateStack._h == 15, "plate stack: 8 + 1 + 6")
fire("UNIT_POWER_FREQUENT"); fire("UNIT_HEALTH")
assert(pf.combo.segs[3]._value == SECRET, "plate bars get values")
N.combo.show = false
fire("PLAYER_TARGET_CHANGED")
assert(not fr.combo:IsShown() and not pf.combo:IsShown(), "neither")
S.plate = nil; fire("NAME_PLATE_UNIT_REMOVED")
assert(not plateStack:IsShown() and not pf.health:IsShown() and plateStack._parent == WolfpackAddonFrame, "plate gone")
R.combo.show, N.health.show = true, false

-- Quest mobs: sword for open kill objectives, bag for open item objectives, from the tooltip
local L = Enum.TooltipDataLineType
S.quests = { { info = { questID = 7, isHeader = false }, objectives = {
    { text = "Boar Flank: 2/6", type = "item", numFulfilled = 2, numRequired = 6 },
    { text = "Boar slain: 3/10", type = "monster", numFulfilled = 3, numRequired = 10 } } } }
fire("QUEST_LOG_UPDATE")
local plate = new()
S.plates.nameplate1, S.related.nameplate1 = plate, true
S.tips.nameplate1 = { { type = L.QuestTitle, leftText = "Boars", id = 7 },
    { type = L.QuestObjective, leftText = "3/10 Boar slain", completed = false },
    { type = L.QuestObjective, leftText = "Boar Flank: 2/6", completed = false } }
fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
local h = ns.plateUnits.nameplate1
assert(h and h._parent == plate and h.kill:IsShown() and h.loot:IsShown(), "kill + loot")
assert(not h.kill._desat and not h.loot._desat, "yours: full color")
local bp, kp, lp = h.box._point, h.kill._point, h.loot._point
assert(bp[1] == "TOPRIGHT" and bp[2] == h and bp[3] == "TOPRIGHT" and bp[4] == 0 and bp[5] == 0, "row at the top-right corner")
assert(h.box._w == 42 and h.kill._tex == 131013, "room for both: 20 + 2 + 20")
assert(kp[1] == "TOPLEFT" and kp[2] == h.box and kp[4] == 0 and lp[4] == 22, "sword left, bag right")
-- how many are left, from the tooltip's "3/10" (kill) and "2/6" (item)
local Q = prof().quest
assert(not h.badge.kill.text:IsShown(), "no numbers unless asked")
Q.kill.count, Q.loot.count = true, true
fire("QUEST_LOG_UPDATE")
assert(h.badge.kill.text:IsShown() and h.badge.kill.text._text == 7, "7 kills left")
assert(h.badge.loot.text._text == 4 and h.badge.loot.bg._color[1] == 0, "4 items left, black plate")
assert(h.badge.kill.text._point[1] == "BOTTOM" and h.badge.kill.text._point[2] == h.kill, "centered above the icon")
assert(h.badge.kill.bg._w == 12 and h.badge.kill.bg._h == 12, "plate hugs the number")
Q.kill.count, Q.loot.count = false, false
fire("QUEST_LOG_UPDATE")
assert(not h.badge.kill.text:IsShown(), "off again")
Q.kill.count = true
fire("QUEST_LOG_UPDATE")

S.tips.nameplate1[2].completed = true
fire("QUEST_LOG_UPDATE")
assert(not h.kill:IsShown() and h.loot:IsShown(), "finished kill objective hidden")
assert(h.loot._point[4] == 0 and h.box._w == 42, "lone bag slides to the row's left edge, row keeps its size")
-- Groups: quests you have stay in color even when the tooltip credits a groupmate
S.tips.nameplate1 = { { type = L.QuestTitle, leftText = "Boars", id = 7 },
    { type = L.QuestPlayer, leftText = "Bob" }, { type = L.QuestObjective, leftText = "Boar Flank: 2/6" },
    { type = L.QuestObjective, leftText = "3/10 Boar slain" } }
S.group = true; fire("QUEST_LOG_UPDATE")
assert(h.kill:IsShown() and not h.kill._desat and h.loot:IsShown() and not h.loot._desat, "both are mine: color")
assert(h.badge.kill.text._text == 7 and h.badge.loot.text._text == 4, "counts from my own quest log")
S.related.nameplate1 = false
S.tips.nameplate1 = { { type = L.QuestTitle, leftText = "Wolves", id = 9 }, { type = L.QuestPlayer, leftText = "Bob" },
    { type = L.QuestObjective, leftText = "Wolf Pelt: 1/4", completed = false } }
fire("QUEST_LOG_UPDATE")
-- a quest you don't have at all: gray, and shown as a kill since your log can't say otherwise
assert(h.kill:IsShown() and h.kill._desat and not h.loot:IsShown(), "only Bob needs it: gray")
assert(h.badge.kill.text._text == 3, "count from the tooltip (1/4)")
S.tips.nameplate1 = { { type = L.QuestTitle, leftText = "Boars", id = 7 },
    { type = L.QuestObjective, leftText = "Boar Flank: 2/6", completed = false } }
fire("QUEST_LOG_UPDATE")
assert(h.loot:IsShown() and not h.loot._desat, "can't tell whose: full color")
S.group = false; fire("QUEST_LOG_UPDATE")
assert(not h.loot:IsShown(), "solo: only your quest mobs")
S.related.nameplate1 = true
S.tips.nameplate1 = {}
fire("QUEST_LOG_UPDATE")
assert(h.kill:IsShown() and not h.loot:IsShown(), "related without objective lines: sword")
S.tips.nameplate1 = { { type = L.QuestObjective, leftText = SECRET } }
fire("QUEST_LOG_UPDATE")
assert(h.kill:IsShown(), "secret tooltip keeps the last answer")
S.related.nameplate1 = false
fire("QUEST_LOG_UPDATE")
assert(not h.kill:IsShown() and not h.loot:IsShown(), "not a quest mob")
S.related.nameplate1 = true; S.tips.nameplate1 = {}
fire("QUEST_LOG_UPDATE")
fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(not h.kill:IsShown() and not ns.plateUnits.nameplate1, "removed plate cleared")
fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(ns.plateUnits.nameplate1 == h, "recycled plate reuses its holder")

-- Minimap icon: dragging moves it around the minimap
local mini = WolfpackAddonMinimapButton
mini._scripts.OnDragStart(mini); mini._scripts.OnUpdate(mini); mini._scripts.OnDragStop(mini)
assert(WolfpackAddonDB.minimapAngle ~= 220 and not mini._scripts.OnUpdate, "minimap drag")

-- Options window: typed numbers apply on Enter and clamp to the slider range (gap: 0-30)
SlashCmdList.WOLFPACKADDON("")
assert(ns.cfg:IsShown(), "one click opens it -- the first one built it, which is not a toggle")
SlashCmdList.WOLFPACKADDON("")
assert(not ns.cfg:IsShown(), "and the next click closes it again")
SlashCmdList.WOLFPACKADDON("")
local boxes = {} -- profile name, gap, group X/Y, width, height, extra above/below, offset X/Y, border,
-- text size, quest row X/Y/spacing, kill size, loot size, highlight opacity, icon size/X/Y
for _, f in ipairs(created) do if f._kind == "EditBox" then boxes[#boxes + 1] = f end end
local nameBox, gapBox, xBox, yBox = boxes[1], boxes[2], boxes[3], boxes[4]
gapBox._text = "7"; gapBox._scripts.OnEnterPressed(gapBox)
assert(prof().regular.gap == 7 and gapBox._text == "7", "typed gap")
gapBox._text = "999"; gapBox._scripts.OnEditFocusLost(gapBox)
assert(prof().regular.gap == 30 and gapBox._text == "30", "clamped gap")
gapBox._text = "3"; gapBox._scripts.OnEscapePressed(gapBox)
assert(gapBox._text == "30", "escape restores")

-- Position: X/Y take negative numbers and clamp to half the screen (mock screen 140 x 100)
xBox._text = "-50"; xBox._scripts.OnEnterPressed(xBox)
yBox._text = "-999"; yBox._scripts.OnEnterPressed(yBox)
assert(prof().regular.x == -50 and prof().regular.y == -50, "typed position")
yBox._text = "abc"; yBox._scripts.OnEnterPressed(yBox)
assert(prof().regular.y == -50 and yBox._text == "-50", "junk input ignored")
local mover -- the unnamed frame with drag + right-click handlers
for _, f in ipairs(created) do if f._scripts.OnMouseUp and f._scripts.OnDragStart and not f._name then mover = f end end
mover._scripts.OnDragStart(mover); mover._scripts.OnUpdate(mover); mover._scripts.OnDragStop(mover)
assert(prof().regular.x == 0 and prof().regular.y == 50 and not mover._scripts.OnUpdate, "drag stores coordinates")

-- Sidebar: Nameplates (Bars tab) edits the nameplate layout only; its group range is +-200
byText("Nameplates")._scripts.OnClick(byText("Nameplates"), "LeftButton")
assert(gapBox._text == "1" and xBox._text == "0" and yBox._text == "-2", "tab shows nameplate values")
gapBox._text = "4"; gapBox._scripts.OnEnterPressed(gapBox)
xBox._text = "-150"; xBox._scripts.OnEnterPressed(xBox)
boxes[5]._text = "90"; boxes[5]._scripts.OnEnterPressed(boxes[5])
assert(prof().nameplate.gap == 4 and prof().nameplate.x == -150 and prof().nameplate.bars.health.width == 90, "nameplate edits")
assert(prof().regular.gap == 30 and prof().regular.x == 0 and prof().regular.bars.health.width == 220, "regular untouched")
-- every sidebar entry is really there, opens its page, and that page has settings on it
for _, name in ipairs({ "Combat Display", "Nameplates", "Buffs", "Training", "Dungeons",
    "Other", "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock",
    "Warrior" }) do
    local b = byText(name)
    assert(b, "sidebar entry missing: " .. name)
    b._scripts.OnClick(b, "LeftButton")
end
-- every class has a macro shelf, whether or not the addon does anything else for it
for _, e in ipairs(ns.CLASS_SECTIONS) do
    byText(e[2])._scripts.OnClick(byText(e[2]), "LeftButton")
    byText("Macros")._scripts.OnClick(byText("Macros"), "LeftButton")
    assert(ns.macroPage:IsShown(), e[2] .. " has somewhere to keep macros")
    assert(ns.macroClass == e[3], "and it is that class's shelf: " .. tostring(ns.macroClass))
end
-- a class the addon has settings for keeps them on its own tab
byText("Mage")._scripts.OnClick(byText("Mage"), "LeftButton")
byText("Settings")._scripts.OnClick(byText("Settings"), "LeftButton")
assert(ns.pages.mage:IsShown() and not ns.macroPage:IsShown(), "Mage settings are still there")
-- a class it does not goes straight to the macros, with no empty Settings tab offered
byText("Warrior")._scripts.OnClick(byText("Warrior"), "LeftButton")
assert(ns.macroPage:IsShown(), "a warrior lands on the macro shelf")
assert(not byText("Settings"):IsShown(), "and is not offered an empty settings tab")
-- New macro, edit it, and it is on the shelf
local before = #ns.mc.shelf("WARRIOR")
byText("New macro")._scripts.OnClick(byText("New macro"), "LeftButton")
assert(#ns.mc.shelf("WARRIOR") == before + 1, "a new one is added")
ns.macro.name._text = "Pull"
ns.macro.name._scripts.OnEnterPressed(ns.macro.name)
assert(ns.mc.shelf("WARRIOR")[ns.macro.picked].name == "Pull", "and renaming it sticks")
-- the roster shows macros as icons, the one you are editing ringed
local cell = ns.macro.rows[ns.macro.picked]
assert(cell:IsShown() and cell.sel:IsShown(), "the one being edited is the marked one")
assert(cell.tex._tex, "and every macro on the roster wears an icon")
GameTooltip._text = nil
cell._scripts.OnEnter(cell)
assert(GameTooltip._text == "Pull", "its name is in the tooltip, since the icon cannot say it")
cell._scripts.OnLeave(cell)
-- clicking another one moves the editor to it
local other = ns.macro.rows[1]
other._scripts.OnClick(other)
assert(ns.macro.picked == 1 and ns.macro.rows[1].sel:IsShown(), "clicking an icon picks it")
assert(ns.macro.name._text == ns.mc.shelf("WARRIOR")[1].name, "and the editor follows")
ns.macro.rows[cell == other and 1 or #ns.mc.shelf("WARRIOR")]._scripts.OnClick(
    ns.macro.rows[#ns.mc.shelf("WARRIOR")])
-- an icon can be picked by hand, out of whatever list this build offers
S.macroIcons = { "Interface/Icons/Ability_Warrior_Charge", "Interface/Icons/INV_Sword_04" }
for i = 3, 120 do S.macroIcons[i] = "Interface/Icons/Spell_Fire_" .. i end
ns.mc.iconCache = nil
assert(#ns.mc.icons() == 120, "the game's icon list is read")
assert(ns.mc.iconName("Interface/Icons/INV_Sword_04") == "INV_Sword_04", "icons have names")
assert(#ns.mc.iconsLike("sword") == 1, "and the search box narrows by them")
assert(#ns.mc.iconsLike("") == 120, "an empty box is the whole list")
local mine = ns.mc.shelf("WARRIOR")[ns.macro.picked]
assert(mine.icon == nil, "a new macro has no icon of its own")
ns.macro.iconBtn._scripts.OnClick(ns.macro.iconBtn)
assert(ns.macro.picker:IsShown(), "the picker opens")
assert(ns.macro.picker.buttons[1]:IsShown(), "with icons on it")
assert(ns.macro.picker.buttons[2].icon == "Interface/Icons/INV_Sword_04", "the second one")
ns.macro.picker.buttons[2]._scripts.OnClick(ns.macro.picker.buttons[2])
assert(mine.icon == "Interface/Icons/INV_Sword_04", "clicking one keeps it")
assert(not ns.macro.picker:IsShown(), "and closes the picker")
-- that icon is what the game gets, not the guess
S.gameMacros = {}
ns.mc.toGame(mine)
assert(S.gameMacros[1].icon == "Interface/Icons/INV_Sword_04", "the game is given the chosen one")
-- paging through, and going back to the automatic icon
ns.macro.iconBtn._scripts.OnClick(ns.macro.iconBtn)
byText("More")._scripts.OnClick(byText("More"), "LeftButton")
assert(ns.macro.picker.buttons[1].icon == S.macroIcons[49], "page two starts where page one ended")
byText("Back to the spell's icon")._scripts.OnClick(byText("Back to the spell's icon"), "LeftButton")
assert(mine.icon == nil, "and it can go back to following the spell")
S.macroIcons, ns.mc.iconCache = nil, nil

-- dragging a row hands it to the game and puts it on the cursor
S.gameMacros, S.cursor = {}, nil
local mrow = ns.macro.rows[ns.macro.picked]
mrow._scripts.OnDragStart(mrow)
assert(S.cursor and S.cursor.name == "Pull", "dragging one puts it on the cursor")
byText("Delete this one")._scripts.OnClick(byText("Delete this one"), "LeftButton")
assert(#ns.mc.shelf("WARRIOR") == before, "and deleting takes it off the shelf")
-- the training page fills itself in when it is the one on screen
byText("Training")._scripts.OnClick(byText("Training"), "LeftButton")
assert(ns.trainRows[1] and ns.trainRows[1]:IsShown(), "the trainer list has rows on it")
assert(ns.trainRows[1].name._text:find("Level"), "and it starts with a level heading")
-- hovering a spell asks the game for its tooltip, and adds why it is on the list
local trSpell
for _, r in ipairs(ns.trainRows) do if r:IsShown() and r.spellID then trSpell = r break end end
assert(trSpell, "a spell row is on the page")
assert(trSpell.note and trSpell.note ~= "", "with a line saying where you stand: " .. trSpell.note)
S.tooltip = nil
trSpell._scripts.OnEnter(trSpell)
assert(S.tooltip == trSpell.spellID, "the game is asked for that spell")
trSpell._scripts.OnLeave(trSpell)
local trHeader = ns.trainRows[1]
trHeader._scripts.OnEnter(trHeader) -- a level heading has nothing to show
assert(not ns.errored, "and a heading is simply passed over")
-- and so does the dungeon page: a place is picked for you, its bosses and loot drawn
byText("Dungeons")._scripts.OnClick(byText("Dungeons"), "LeftButton")
assert(#WolfpackAddonLootData > 0, "the dungeon addon is loaded")
assert(prof().dungeons.pick > 0, "one is picked, near your level")
assert(ns.dung.picks[1] and ns.dung.picks[1]:IsShown(), "the dungeon list is drawn")
assert(ns.dung.rows[1] and ns.dung.rows[1]:IsShown(), "and so is that dungeon's loot")
local sawBoss, sawItem = false, false
for _, r in ipairs(ns.dung.rows) do
    if r:IsShown() and r.itemID then sawItem = true elseif r:IsShown() then sawBoss = true end
end
assert(sawBoss and sawItem, "bosses with items under them")
-- every quest says where you stand with it
local dm
for _, d in ipairs(WolfpackAddonLootData) do if d.name == "The Deadmines" then dm = d end end
assert(dm and #dm.quests > 0, "Deadmines has quests")
local qu = dm.quests[1] -- { id, name, level, min, side }
S.level, S.faction, S.questDone, S.questLog = 60, "Alliance", {}, {}
assert(ns.lt.questState(qu) == "open", "level is there and it is your side: pick it up")
S.questDone = { [qu[1]] = true }
assert(ns.lt.questState(qu) == "done", "handed in already")
S.questDone, S.questLog = {}, { [qu[1]] = 3 }
assert(ns.lt.questState(qu) == "log", "it is in your log right now")
S.questLog = {}
S.level = 2
assert(ns.lt.questState(qu) == "low", "too low for it yet")
S.level, S.faction = 60, "Horde"
assert(ns.lt.questState(qu) == "faction", "an Alliance quest is not yours to take")
S.faction = "Alliance"
-- and the page paints that state next to the name
byText("Dungeons")._scripts.OnClick(byText("Dungeons"), "LeftButton")
local sawState = false
for _, r in ipairs(ns.dung.rows) do
    if r:IsShown() and r.quest then
        assert(r.right._text ~= "", "a quest row carries its state: " .. tostring(r.right._text))
        sawState = true
    end
end
assert(sawState, "quests are on the page at all")
-- clicking a quest opens the map where it is handed out and pins the spot
local withGiver
for _, d in ipairs(WolfpackAddonLootData) do
    for _, x in ipairs(d.quests) do if x[6] and (x[8] or 0) > 0 then withGiver = x break end end
    if withGiver then break end
end
assert(withGiver, "at least one quest knows who hands it out")
assert(ns.lt.mapByName("Westfall") == 52, "a zone name finds its map")
assert(ns.lt.mapByName("Nowhere") == nil, "and an unknown one finds nothing")
local here = { 166, "The Defias Brotherhood", 22, 14, 1, "Gryan Stoutmantle", "Westfall", 56.2, 47.6 }
S.waypoint, S.mapShown, S.superTrack = nil, nil, nil
assert(ns.lt.showOnMap(here), "a quest with a spot goes on the map")
assert(S.mapShown == 52, "the map opens on that zone")
assert(S.waypoint and math.abs(S.waypoint.x - 0.562) < 1e-9
    and math.abs(S.waypoint.y - 0.476) < 1e-9, "the pin lands on the spot")
assert(S.superTrack == true, "with the arrow pointing at it")
-- a zone this client does not know, and a quest nobody hands out, are both simply declined
S.waypoint, S.mapShown = nil, nil
assert(not ns.lt.showOnMap({ 1, "?", 1, 1, 3, "Someone", "Elsewhen", 10, 10 }), "no such zone")
assert(not ns.lt.showOnMap({ 1, "?", 1, 1, 3, nil, nil, 0, 0 }), "nobody hands it out")
assert(S.mapShown == nil and S.waypoint == nil, "and nothing was poked either time")
-- clicking the row itself goes through the same door
local row
for _, r in ipairs(ns.dung.rows) do if r:IsShown() and r.quest then row = r break end end
assert(row, "a quest row is on the page")
row._scripts.OnClick(row)
assert(not ns.errored, "clicking one never errors, wherever it points")
-- in a fight nothing is touched
S.combat = true
S.waypoint, S.mapShown = nil, nil
assert(not ns.lt.showOnMap(here), "not mid-fight")
assert(S.mapShown == nil and S.waypoint == nil, "and nothing was poked")
S.combat = false
-- and with that addon switched off the page says so instead of falling over
local keptLoot = WolfpackAddonLootData
WolfpackAddonLootData = nil
byText("Dungeons")._scripts.OnClick(byText("Dungeons"), "LeftButton")
assert(not ns.errored, "no data, no error")
assert(ns.dung.empty:IsShown() and ns.dung.empty._text:find("not loaded"), "it explains itself")
WolfpackAddonLootData = keptLoot
byText("Dungeons")._scripts.OnClick(byText("Dungeons"), "LeftButton")
for section, page in pairs(ns.pages) do
    assert((ns.boxesOn[page] or 0) > 0, "nothing on the " .. section .. " page")
end
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
assert(gapBox._text == "30", "back on Combat Display")

-- Profiles: create copies the current one, dropdown switches, delete falls back to the class profile
nameBox._text = "  PvP "; nameBox._scripts.OnEnterPressed(nameBox)
assert(store.profiles.PvP and store.profiles.PvP.regular.gap == 30 and prof() == store.profiles.PvP, "create copies + switches")
prof().regular.gap = 5
assert(store.profiles.Rogue.regular.gap == 30, "profiles are independent")
-- a name that is taken gets a number instead of switching to the old one
nameBox._text = "PvP"; nameBox._scripts.OnEnterPressed(nameBox)
assert(store.profiles["PvP 2"] and prof() == store.profiles["PvP 2"], "same name again: PvP 2")
store.profiles["PvP 2"], store.chars[S.name .. " - Realm"] = nil, "PvP"
local dds = {} -- profile, texture, bar color, border color, radius, font, kill icon, loot icon, combat icon, attach
for _, f in ipairs(created) do if f._gen then dds[#dds + 1] = f end end
local dd = dds[1]
dd:GenerateMenu()
local names = {}
for _, it in ipairs(dd._items) do names[#names + 1] = it.text .. (it.sel() and "*" or "") end
-- "Alpha" is a ready-made profile: listed before it exists, created when picked
assert(table.concat(names, ",") == "Alpha,Druid,Paladin,PvP*,Rogue,Warrior", table.concat(names, ","))
assert(store.profiles.Alpha == nil, "not created until used")
dd._items[1].set()
assert(store.profiles.Alpha and prof() == store.profiles.Alpha, "picked: made from the preset")
dd._items[5].set()
assert(prof() == store.profiles.Rogue, "dropdown switches")
dd._items[4].set()
byText("Delete")._scripts.OnClick(byText("Delete"), "LeftButton")
assert(not store.profiles.PvP and prof() == store.profiles.Rogue, "delete falls back to class profile")

-- Texture and font dropdowns: pick sets the selected bar (Health), previews render
local texDD, fontDD = dds[2], dds[6]
texDD:GenerateMenu(); fontDD:GenerateMenu()
assert(#texDD._items == 5 and #fontDD._items == 6, "dropdown entries")
-- Menu entries' regions refuse SetFont in the real client (Blizzard_Menu Compositor)
local function menuButton()
    local b = new()
    b.fontString, b.leftTexture1 = new(), new()
    function b:AttachFontString()
        local fs = new()
        function fs:SetFont() error("Use of function 'SetFont' is disallowed") end
        b._attached = fs
        return fs
    end
    function b:AttachTexture() b._attached = new(); return b._attached end
    return b
end
-- previews go in a column after the radio tick; the name starts after that column
local function checkColumn(b, slot)
    local p, n = b._attached._point, b.fontString._point
    assert(p[1] == "LEFT" and p[2] == b.leftTexture1 and p[3] == "RIGHT", "preview right after the tick")
    assert(n[1] == "LEFT" and n[2] == b._attached and n[4] == slot + 10, "name after the preview column")
end
for _, it in ipairs(texDD._items) do
    local b = menuButton()
    assert(type(it.init(b)) == "number", "texture preview")
    checkColumn(b, 90)
end
for _, it in ipairs(fontDD._items) do
    local b = menuButton()
    assert(it.init(b) >= 22 + 44 + 10 + #it.text * 7, "font entry wide enough for preview + name")
    checkColumn(b, 44)
end
texDD._items[2].set(); fontDD._items[6].set()
dds[5]:GenerateMenu()
assert(#dds[5]._items == 7 and dds[5]._items[7].text == "Pill (50% of height)", "radius presets")
dds[5]._items[7].set()
assert(prof().regular.bars.health.radius == "pill", "pill picked")
dds[5]._items[1].set()
assert(prof().regular.bars.health.texture == "Interface\\Buttons\\WHITE8X8", "texture picked")
assert(prof().regular.bars.health.font:match("Anton%-Regular%.ttf$") and fontDD._items[6].sel(), "font picked")

-- Quest page: icon style, size and position per icon
byText("Nameplates")._scripts.OnClick(byText("Nameplates"), "LeftButton")
byText("Quest mobs")._scripts.OnClick(byText("Quest mobs"), "LeftButton")
dds[7]:GenerateMenu(); dds[8]:GenerateMenu()
assert(#dds[7]._items == 4 and #dds[8]._items == 4, "icon choices")
for _, it in ipairs(dds[7]._items) do assert(type(it.init(menuButton())) == "number", "icon preview") end
dds[7]._items[3].set()
boxes[16]._text = "32"; boxes[16]._scripts.OnEnterPressed(boxes[16]) -- kill size
boxes[13]._text = "-5"; boxes[13]._scripts.OnEnterPressed(boxes[13]) -- row X
local Q = prof().quest
assert(Q.kill.icon == 135274 and Q.kill.size == 32 and Q.loot.size == 20 and Q.x == -5, "quest page edits")
assert(h.kill._tex == 135274 and h.kill._w == 32 and h.box._w == 54 and h.box._point[4] == -5, "live plate row restyled")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")

-- The options window sizes itself to its tallest column; 990x740 still fits a 1080p screen
assert(ns.configHeight > 400 and ns.configHeight < 740, "window height " .. ns.configHeight)

-- Other: gryphons hidden via texture alpha only, untouched until the option is used
local caps = MainActionBar.EndCaps
assert(caps.LeftEndCap.Texture._alpha == nil, "gryphons untouched by default")
byText("Other")._scripts.OnClick(byText("Other"), "LeftButton")
prof().other.hideGryphons = true; fire("UNIT_MAXPOWER")
assert(caps.LeftEndCap.Texture._alpha == 0 and caps.RightEndCap.Texture._alpha == 0, "hidden")
prof().other.hideGryphons = false; fire("UNIT_MAXPOWER")
assert(caps.LeftEndCap.Texture._alpha == 1, "shown again")
local opBox = boxes[18] -- highlight opacity (%)
opBox._text = "60"; opBox._scripts.OnEnterPressed(opBox)
assert(math.abs(prof().regular.highlight.color[4] - 0.6) < 1e-9 and opBox._text == "60", "opacity typed")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")

-- Auto-accept: off by default; Shift skips; item/area-trigger quests left to Blizzard
local function calls() local c = table.concat(S.calls, ","); S.calls = {}; return c end
fire("QUEST_DETAIL", 0)
assert(calls() == "", "off by default")
prof().other.autoAccept = true
fire("QUEST_DETAIL", 0); fire("QUEST_DETAIL", nil)
assert(calls() == "accept,accept", "accepts")
S.shift = true; fire("QUEST_DETAIL", 0); fire("QUEST_ACCEPT_CONFIRM"); S.shift = false
assert(calls() == "", "shift skips")
fire("QUEST_DETAIL", 12345)
S.areaTrigger = true; fire("QUEST_DETAIL", 0); S.areaTrigger = false
assert(calls() == "", "item and area trigger quests left alone")
S.autoQuest = true; fire("QUEST_DETAIL", 0); S.autoQuest = false
fire("QUEST_ACCEPT_CONFIRM")
assert(calls() == "ack,confirm,hidepopup", "auto-accept quests acknowledged, escorts confirmed")
prof().other.autoAccept = false

-- Auto-complete: finished quests picked at the NPC, handed in, reward taken unless it needs a choice
S.gossip = { { questID = 11, isComplete = false }, { questID = 12, isComplete = true } }
S.greeting = { false, true }
S.completable = true
fire("GOSSIP_SHOW"); fire("QUEST_PROGRESS"); fire("QUEST_COMPLETE")
assert(calls() == "", "off by default")
prof().other.autoComplete = true
S.npc = "npc-1"
fire("GOSSIP_SHOW"); fire("QUEST_GREETING"); fire("QUEST_PROGRESS"); fire("QUEST_COMPLETE")
assert(calls() == "turnin12,greetTurnin2,complete,reward0", "turns in")
S.choices = 1; fire("QUEST_COMPLETE")
S.choices = 3; fire("QUEST_COMPLETE")
S.choices, S.cost = 0, 500; fire("QUEST_COMPLETE")
S.cost, S.completable = 0, false; fire("QUEST_PROGRESS")
assert(calls() == "reward1", "single reward taken; choice, gold cost and unfinished left alone")
S.shift = true; fire("GOSSIP_SHOW"); fire("QUEST_COMPLETE"); S.shift = false
assert(calls() == "", "shift skips")
-- Several quests at one NPC: turn-ins first, then one new quest per opening, never looping
S.available = { { questID = 21 }, { questID = 22 } }
S.gossip = { { questID = 12, isComplete = true } }
S.greetNew, S.greeting = 1, { false }
S.npc = "npc-2"
prof().other.autoAccept = true
fire("GOSSIP_SHOW"); fire("GOSSIP_SHOW"); fire("GOSSIP_SHOW"); fire("GOSSIP_SHOW")
assert(calls() == "turnin12,take21,take22,greetTake1", "each quest once, no loop")
fire("GOSSIP_SHOW")
assert(calls() == "", "nothing left to pick at this NPC")
S.npc = "npc-3" -- another quest giver: its own list again
fire("GOSSIP_SHOW")
assert(calls() == "turnin12", "new NPC starts over")
prof().other.autoAccept = false
fire("GOSSIP_SHOW"); fire("GOSSIP_SHOW")
assert(calls() == "", "auto-accept off: no quests taken")
S.shift = true; S.npc = "npc-4"; fire("GOSSIP_SHOW"); S.shift = false
assert(calls() == "", "shift skips the whole list")
prof().other.autoComplete = false
S.available, S.greetNew = {}, 0

-- Show on mouseover: alpha fades toward 1 while hovered (0.2 s), 0 otherwise; Edit Mode shows all
local oth = prof().other
assert(not ns.hoverTicker._scripts.OnUpdate, "no polling by default")
oth.hover.bar1 = true; fire("UNIT_MAXPOWER")
local tick = ns.hoverTicker._scripts.OnUpdate
S.mouseOver = false; tick(nil, 1)
assert(MainActionBar._alpha == 0, "hidden")
S.mouseOver = true; tick(nil, 0.1)
assert(MainActionBar._alpha == 0.5, "fading in")
tick(nil, 1)
assert(MainActionBar._alpha == 1, "shown on hover")
S.mouseOver, S.editMode = false, true; tick(nil, 1)
assert(MainActionBar._alpha == 1, "Edit Mode shows everything")
S.editMode = false
oth.hover.bar1 = nil; fire("UNIT_MAXPOWER")
assert(MainActionBar._alpha == 1 and not ns.hoverTicker._scripts.OnUpdate, "off: back to normal, no polling")

-- Bag bar only while bags are open: parked, attached above combined bags / beside the backpack,
-- restored to its Edit Mode spot when turned off; untouched until used
assert(BagsBar._parent == UIParent and not ContainerFrame1._scripts.OnShow, "untouched by default")
oth.bagsOnOpen = true; fire("UNIT_MAXPOWER")
assert(BagsBar._parent == hider, "bags closed: hidden")
ContainerFrameCombinedBags._shown = true; ContainerFrameCombinedBags._scripts.OnShow()
local bb = BagsBar._point
assert(BagsBar._parent == UIParent and bb[1] == "BOTTOMRIGHT" and bb[2] == ContainerFrameCombinedBags and bb[3] == "TOPRIGHT", "above combined bags")
ContainerFrameCombinedBags._shown = false; ContainerFrameCombinedBags._scripts.OnHide()
assert(BagsBar._parent == hider, "closed again")
ContainerFrame1._shown = true; ContainerFrame1._scripts.OnShow()
assert(BagsBar._point[2] == ContainerFrame1 and BagsBar._point[3] == "BOTTOMLEFT", "beside the backpack")
ContainerFrame1._shown = false; ContainerFrame1._scripts.OnHide()
oth.bagsOnOpen = false; fire("UNIT_MAXPOWER")
assert(BagsBar._parent == UIParent and BagsBar._point[2] == "MicroButtonAndBagsBar", "restored")

-- Color pickers start from the color in use: class / same-as-bar borders, class bars; picking
-- a color makes it custom, opacity alone doesn't, cancel restores both
local sw, hcol = ns.swatches, prof().regular.bars.health
hcol.colorMode, hcol.borderMode = "class", "bar"
sw["Custom border color"]._scripts.OnClick()
assert(S.picker.r == 1 and S.picker.b == 0.41, "border picker opens on the (class) bar color")
S.picker.opacityFunc()
assert(hcol.borderMode == "bar" and hcol.borderColor[4] == 0.5, "opacity only: mode kept")
S.picker.swatchFunc()
assert(hcol.borderMode == "custom" and hcol.borderColor[1] == 0.1, "picked: custom")
S.picker.cancelFunc()
assert(hcol.borderMode == "bar" and hcol.borderColor[1] == 0 and hcol.borderColor[4] == 1, "cancel restores")
sw["Custom color"]._scripts.OnClick()
assert(S.picker.r == 1 and S.picker.g == 0.96, "bar picker opens on the class color")
S.picker.swatchFunc()
assert(hcol.colorMode == "custom" and hcol.color[3] == 0.3, "bar picked: custom")
hcol.colorMode, hcol.borderMode, hcol.color = "custom", "custom", { 0.2, 0.8, 0.2, 1 }

-- Auto-sell junk: only gray items that are worth something and unlocked, one per tick
fire("MERCHANT_SHOW")
assert(not S.ticker, "off by default")
prof().other.sellJunk = true
fire("MERCHANT_SHOW")
local tick = S.ticker
tick.fn(tick.obj); tick.fn(tick.obj)
assert(table.concat(S.sold, ",") == "0:1", "only the gray item with a sell price")
assert(tick.obj.cancelled and S.money == 105, "finished")
assert(S.printed[#S.printed]:find("sold junk for 5c"), "reported what it earned")
-- stops when the merchant window closes
S.sold, S.money = {}, 100
S.bags[0] = { { quality = 0, hasNoValue = false }, { quality = 0, hasNoValue = false } }
fire("MERCHANT_SHOW")
tick = S.ticker
tick.fn(tick.obj)
fire("MERCHANT_CLOSED")
assert(#S.sold == 1 and tick.obj.cancelled, "closing stops it")
prof().other.sellJunk = false

-- Auto-repair: only when asked, only when the merchant can, only when you can afford it
S.canRepair, S.repairCost, S.money = true, 500, 1000
fire("MERCHANT_SHOW")
assert(not S.repaired, "off by default")
prof().other.autoRepair = true
fire("MERCHANT_SHOW")
assert(S.repaired == 1, "repaired")
assert(table.concat(S.printed, "|"):find("repaired for"), "and said what it cost, without erroring")
S.money = 100
fire("MERCHANT_SHOW")
assert(S.repaired == 1, "too poor: left alone")
S.money, S.canRepair = 1000, false
fire("MERCHANT_SHOW")
assert(S.repaired == 1, "a merchant who cannot repair is left alone")
prof().other.autoRepair = false

-- Gradient points dialog: add, edit percent, delete
prof().regular.bars.health.gradient = true
byText("Gradient points...")._scripts.OnClick()
local sf = WolfpackAddonStops
local stops = prof().regular.bars.health.stops
assert(sf:IsShown() and sf.rows[1]:IsShown() and not sf.rows[3]:IsShown(), "a row per point")
assert(not sf.rows[1].del:IsShown(), "two points can't be deleted")
sf.add._scripts.OnClick()
assert(#stops == 3 and sf.rows[3]:IsShown() and sf.rows[1].del:IsShown(), "added a point")
sf.rows[3].box._text = "250"; sf.rows[3].box._scripts.OnEnterPressed()
assert(stops[3].pos == 100 and sf.rows[3].box._text == "100", "percent clamped to 0-100")
sf.rows[2].box._text = "40"; sf.rows[2].box._scripts.OnEnterPressed()
assert(stops[2].pos == 40, "typed percent")
sf.rows[3].del._scripts.OnClick()
assert(#stops == 2 and not sf.rows[3]:IsShown(), "deleted")
prof().regular.bars.health.gradient = false

-- Minimap: square mask, 1 px border, the tray collecting icons, and the info bar
local MM = prof().other.minimap
assert(Minimap._mask == nil, "untouched by default")
MM.square = true; fire("UNIT_MAXPOWER")
assert(Minimap._mask == "Interface\\Buttons\\WHITE8X8" and MinimapCompassTexture._alpha == 0, "square: corners shown")
MM.square = false; fire("UNIT_MAXPOWER")
assert(Minimap._mask == "ui-hud-minimap-frame-generic-mask" and MinimapCompassTexture._alpha == 1, "round again")
MM.square, MM.border = true, true
fire("UNIT_MAXPOWER")
local bord
for _, f in ipairs(created) do if f._parent == MinimapCluster and f._kind == "Frame" then bord = bord or f end end
assert(bord and bord:IsShown() and not bord.masked, "square: plain border plate behind the minimap")
MM.radius = 8; fire("UNIT_MAXPOWER")
-- 8 px on a 140 px minimap is a ratio of 0.057: m8 (0.0625) is the closest mask
assert(Minimap._mask:match("MinimapRound\\m8%.tga$") and bord.masked, "rounded corners: closest mask for both")
for _, r in ipairs({ 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64 }) do
    assert(io.open("WolfpackAddon/Media/MinimapRound/m" .. r .. ".tga"), "minimap mask m" .. r)
end
MM.radius = "round"; fire("UNIT_MAXPOWER")
assert(Minimap._mask == "ui-hud-minimap-frame-generic-mask" and not bord:IsShown(), "round again, Blizzard's own art")
MM.radius, MM.square = 0, false
fire("UNIT_MAXPOWER")
local icon1, icon2 = Minimap._children[1], Minimap._children[2]
MM.tray, MM.trayBlizzard = true, false
fire("UNIT_MAXPOWER")
local trayBtn = WolfpackAddonTray
assert(trayBtn and trayBtn:IsShown() and icon1._parent ~= Minimap and icon2._parent ~= Minimap, "addon icons moved into the tray")
assert(MinimapCluster.Tracking._parent == nil, "tracking left alone until asked")
MM.trayBlizzard = true; fire("UNIT_MAXPOWER")
assert(MinimapCluster.Tracking._parent == icon1._parent and GameTimeFrame._parent == icon1._parent, "tracking + calendar too")
local panel = icon1._parent
assert(not panel:IsShown(), "panel closed until the tray is clicked")
trayBtn._scripts.OnClick()
assert(panel:IsShown() and panel._w == 12 + 4 * 28, "click opens it, four across")
assert(not strayCount:IsShown(), "a loose counter on the minimap is hidden while the tray is on")
assert(not iconCount:IsShown(), "a counter drawn on a collected icon goes quiet too")
assert(ns.mini.trayBg:GetFrameStrata() == "BACKGROUND" and icon1._strata == "MEDIUM",
    "backdrop sits behind the icons, not over them")
-- Edit Mode measures the minimap from its children: ours must not count
assert(trayBtn.ignoreInLayout and panel.ignoreInLayout and WolfpackAddonMinimapButton.ignoreInLayout,
    "tray, panel and our icon stay out of the minimap's layout")
assert(icon1._strata == panel:GetFrameStrata() and icon1._level > panel:GetFrameLevel(), "icons above the panel")
trayBtn._scripts.OnDragStart(trayBtn); trayBtn._scripts.OnUpdate(); trayBtn._scripts.OnDragStop(trayBtn)
assert(type(WolfpackAddonDB.trayAngle) == "number" and trayBtn._point[2] == Minimap, "dragged around the minimap")
-- 45 degrees: on the circle it sits at cos/sin, on the square it slides out to the corner
WolfpackAddonDB.trayAngle = 45
MM.square = false; fire("UNIT_MAXPOWER")
local out = 140 / 2 + 6
assert(math.abs(trayBtn._point[4] - math.cos(math.rad(45)) * out) < 0.01, "round: on the circle")
MM.square = true; fire("UNIT_MAXPOWER")
assert(math.abs(trayBtn._point[4] - out) < 0.01 and math.abs(trayBtn._point[5] - out) < 0.01, "square: at the corner")
MM.square = false
MM.tray = false; fire("UNIT_MAXPOWER")
assert(icon1._parent == Minimap and icon1._point[2] == Minimap and MinimapCluster.Tracking._parent == nil, "given back")
assert(icon1._strata == "MEDIUM", "strata restored too")
assert(iconCount:IsShown(), "the icon's own counter comes back")
assert(strayCount:IsShown(), "the loose counter comes back")
MM.infoBar = true; fire("UNIT_MAXPOWER")
local bar, top = ns.mini.infoBar, ns.mini.topBar
bar._scripts.OnUpdate(bar, 2)
assert(bar.left._text == "12:34" and bar.right._text == "42 ms", "bottom bar: time and ping")
assert(bar.ignoreInLayout and top.ignoreInLayout and bord.ignoreInLayout, "bars and border out of the layout too")
assert(top.left._text == "Ruins of Lordaeron" and top.right._text == "25.3, 60.7", "top bar: zone and coords")
assert(not MinimapCluster.ZoneTextButton:IsShown() and not TimeManagerClockButton:IsShown(), "Blizzard's own hidden")
assert(not MinimapCluster.BorderTop:IsShown(), "and the dark strip behind it")
-- day/night icon and nudging the whole minimap
MM.hideDayNight = true; fire("UNIT_MAXPOWER")
assert(not MinimapCluster.DielFrame:IsShown() and GameTimeFrame:IsShown(), "the dial hides, the calendar stays")
MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
MM.x, MM.y = -10, 5
fire("UNIT_MAXPOWER")
assert(MinimapCluster._point[4] == -30 and MinimapCluster._point[5] == -15, "moved by the offsets")
MM.x, MM.y = 0, 0
fire("UNIT_MAXPOWER")
assert(MinimapCluster._point[4] == -20 and MinimapCluster._point[5] == -20, "back where Edit Mode had it")
MM.hideDayNight = false; fire("UNIT_MAXPOWER")
assert(MinimapCluster.DielFrame:IsShown(), "dial back")
MM.infoBar, MM.border = false, false
fire("UNIT_MAXPOWER")
assert(not bar:IsShown() and not top:IsShown() and not bord:IsShown(), "off again")
assert(MinimapCluster.ZoneTextButton:IsShown() and TimeManagerClockButton:IsShown()
    and MinimapCluster.BorderTop:IsShown(), "Blizzard's own back")

-- Export / import: the profile string round-trips into a new profile (mouseover choices and
-- the account-wide combat font included); the WoW UI layout is its own string for Edit Mode
C_EditMode.ConvertStringToLayoutInfo = function(str) if str:match("^EDITMODE:") then return {} end end
prof().regular.gap = 9
prof().other.hover.bar3 = true
prof().other.minimap.square, prof().other.minimap.radius = true, "round"
prof().other.combatFont = ns.COMBAT_FONTS[4][2]
local exp = ns.exportString()
assert(exp:match("^WPA1:") and blobs[#blobs].editMode == nil, "profile string only")
assert(ns.editModeString() == "EDITMODE:MyLayout", "WoW UI layout string on its own")
local before = store.chars[S.name .. " - Realm"]
local name, em = ns.importString("  " .. exp .. "\n")
assert(name == before .. " 2" and em == nil, "imported as a new profile")
assert(prof() == store.profiles[name] and prof().regular.gap == 9 and prof() ~= store.profiles[before], "switched to the copy")
assert(prof().other.hover.bar3 == true, "mouseover choices survive")
assert(prof().other.minimap.square == true and prof().other.minimap.radius == "round", "minimap settings too")
assert(prof().other.combatFont == ns.COMBAT_FONTS[4][2], "combat font carried along")
prof().regular.gap = 3
assert(store.profiles[before].regular.gap == 9, "copy is independent")
-- Profiles must not share tables: a color set in one stays in that one
store.profiles["ColorA"] = ns.freshProfile("ColorA")
store.profiles["ColorB"] = ns.freshProfile("ColorB")
local A, B = store.profiles.ColorA.regular.bars.power, store.profiles.ColorB.regular.bars.power
assert(A ~= B and A.color ~= B.color, "each profile has tables of its own")
A.color[1], A.color[2], A.color[3] = 0.1, 0.2, 0.3
assert(B.color[1] ~= 0.1, "changing one leaves the other alone")
ns.useProfile("ColorA")
ns.useProfile("ColorB")
assert(store.profiles.ColorA.regular.bars.power.color[1] == 0.1
    and store.profiles.ColorB.regular.bars.power.color[1] ~= 0.1,
    "and switching between them keeps each one's own")
store.profiles.ColorA, store.profiles.ColorB = nil, nil

-- One string, every profile: each class lands on the one named after it
store.profiles["Alpha Priest"] = ns.freshProfile("Alpha Priest")
store.profiles["Alpha Priest"].regular.gap = 7
store.profiles["Alpha Warrior"] = ns.freshProfile("Alpha Warrior")
store.profiles["Alpha Warrior"].regular.gap = 11
local bundle = ns.exportString(true)
store.profiles["Alpha Priest"] = nil
store.profiles["Alpha Warrior"] = nil
local got, _, count = ns.importString(bundle)
assert(count and count >= 3, "every profile travelled: " .. tostring(count))
assert(store.profiles["Alpha Priest"].regular.gap == 7, "the priest one came back whole")
assert(store.profiles["Alpha Warrior"].regular.gap == 11, "and the warrior one")
assert(store.classProfiles.PRIEST == "Alpha Priest" and store.classProfiles.WARRIOR == "Alpha Warrior",
    "each class knows its own")
assert(got == store.chars[S.name .. " - Realm"], "and this character is on one of them")
login("PRIEST", 0)
assert(store.chars["PRIESTChar - Realm"] == "Alpha Priest", "a priest logs in on the priest profile")
assert(prof().regular.gap == 7, "with its settings")
login("ROGUE", 3)

local _, why = ns.importString("EDITMODE:MyLayout")
assert(why:find("Edit Mode"), "WoW UI string recognized and redirected")
assert(not ns.importString("hello"), "not ours")
assert(not ns.importString("WPA1:Bnope"), "damaged")
-- older combined strings still import; their layout is handed back
blobs[#blobs + 1] = { name = "Old", profile = {}, editMode = "EDITMODE:Old" }
local oldName, oldEM = ns.importString("WPA1:Bzblob" .. #blobs)
assert(oldName == "Old" and oldEM == "EDITMODE:Old", "old combined string")
-- untrusted content: bad types, silly numbers, broken order, unknown keys
blobs[#blobs + 1] = { name = string.rep("x", 50), combatFont = "Interface\\evil.ttf", profile = { evil = "x", locked = "yes",
    other = { hover = { bar1 = true, nope = true, bar2 = "yes" } },
    nameplate = { bars = { power = { stops = { { pos = 10, color = { 1, 0, 0, 1 } }, { pos = "x" },
        { pos = 90, color = { 0, 0, 1, 1 } } } } } },
    regular = { gap = -5, x = 1e9, order = { "health", "health", "bogus", "castbar" },
        bars = { health = { width = "wide", height = 0, radius = "pill", color = { 1, "red", 0, 1 } } } } } }
local bad = ns.importString("WPA1:Bzblob" .. #blobs)
local bp = store.profiles[bad]
assert(#bad == 32 and bp.evil == nil and bp.locked == true, "unknown key dropped, bad type defaulted")
assert(bp.other.hover.bar1 and bp.other.hover.nope == nil and bp.other.hover.bar2 == nil, "hover: known and true only")
assert(bp.other.combatFont == "", "unknown combat font path refused")
assert(bp.regular.gap == 2 and bp.regular.x == 0, "out-of-range numbers defaulted")
assert(bp.regular.order[1] == "health" and bp.regular.order[2] == "castbar" and #bp.regular.order == 9, "order repaired")
local ns2 = bp.nameplate.bars.power.stops
assert(#ns2 == 2 and ns2[1].pos == 10 and ns2[2].pos == 90 and ns2[1].color[1] == 1, "gradient points checked")
local hb2 = bp.regular.bars.health
assert(hb2.width == 220 and hb2.height == 18 and hb2.radius == "pill" and hb2.color[2] == 0.8, "bar values checked")
WolfpackAddonDB.combatFont = nil
-- the dialog: export shows both strings; import takes the profile string only
byText("Export")._scripts.OnClick(byText("Export"), "LeftButton")
local iof = WolfpackAddonIO
assert(iof:IsShown() and iof.area1.box._text:match("^WPA1:") and iof.area2:IsShown(), "export: profile box")
assert(iof.area2.box._text == "EDITMODE:MyLayout" and not iof.import:IsShown(), "export: WoW UI box")
byText("Import")._scripts.OnClick(byText("Import"), "LeftButton")
assert(iof.import:IsShown() and not iof.area2:IsShown() and iof.area1.box._text == "", "import dialog")
iof.area1.box._text = "EDITMODE:MyLayout"; iof.import._scripts.OnClick(iof.import)
assert(iof.note._text:find("Edit Mode"), "pasting the WoW UI string explains where it goes")
iof.area1.box._text = exp; iof.import._scripts.OnClick(iof.import)
assert(iof.note._text:find("Imported as profile") and not iof.area2:IsShown(), "imported")

-- Combat text font: 20 fonts + default; applied on ADDON_LOADED only for known paths
assert(#ns.COMBAT_FONTS == 21, "20 fonts + WoW default")
dds[9]:GenerateMenu()
assert(#dds[9]._items == 21, "combat font dropdown")
for _, it in ipairs(dds[9]._items) do
    local b = menuButton()
    assert(type(it.init(b)) == "number" and b._attached._text == "123", "combat font preview")
    checkColumn(b, 56)
end
dds[9]._items[6].set()
local picked = ns.COMBAT_FONTS[6][2]
assert(prof().other.combatFont == picked, "stored in the profile")
assert(DAMAGE_TEXT_FONT == picked and CombatTextFont._font[1] == picked, "applied as soon as it's picked")
DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
fire("ADDON_LOADED", "SomeOtherAddon")
assert(DAMAGE_TEXT_FONT == "Fonts\\FRIZQT__.TTF", "other addons' loads ignored")
fire("ADDON_LOADED", "WolfpackAddon")
assert(DAMAGE_TEXT_FONT == picked, "applied at load")
-- switching profiles takes its font along
local other = ns.freshProfile("Alpha")
other.other.combatFont = ns.COMBAT_FONTS[8][2]
WolfpackAddonDB.profiles["FontTest"] = other
ns.useProfile("FontTest")
assert(DAMAGE_TEXT_FONT == ns.COMBAT_FONTS[8][2], "the profile's font follows the profile")
ns.useProfile(store.chars[S.name .. " - Realm"] or "Rogue")
DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
prof().other.combatFont = "Interface\\evil.ttf"; fire("ADDON_LOADED", "WolfpackAddon")
assert(DAMAGE_TEXT_FONT == "Fonts\\FRIZQT__.TTF", "unknown path refused")
dds[9]._items[1].set()
assert(prof().other.combatFont == "", "WoW default is remembered, so the baked font stays off")
-- the baked-in export string is intact in the file (an edit truncating it would break defaults)
local src = io.open("WolfpackAddon/WolfpackAddon.lua"):read("*a")
local baked = src:match('local DEFAULT_PROFILE = "(WPA1:[^"]+)"')
assert(baked and #baked > 1000 and not baked:find("%s"), "baked profile string")
-- With no saved variables at all -- this beta never reads them back -- the font has to come
-- from the baked profile, or no pick ever reaches the game.
local bakedFont = ns.COMBAT_FONTS[5][2]
blobs[#blobs + 1] = { profile = {}, combatFont = bakedFont }
bakedStub = "zblob" .. #blobs
assert(ns.freshProfile("Alpha").other.combatFont == bakedFont, "new profiles carry the baked font")
-- an empty account is filled from the baked bundle, classes and all
blobs[#blobs + 1] = { profile = {}, profiles = { ["Alpha Warrior"] = { regular = { gap = 5 } } },
    classes = { WARRIOR = "Alpha Warrior" } }
bakedStub = "zblob" .. #blobs
local keptProfiles, keptClasses = WolfpackAddonDB.profiles, WolfpackAddonDB.classProfiles
WolfpackAddonDB.profiles, WolfpackAddonDB.classProfiles = {}, {}
ns.seedFromBaked()
assert(WolfpackAddonDB.profiles["Alpha Warrior"], "the baked bundle fills an empty account")
assert(WolfpackAddonDB.classProfiles.WARRIOR == "Alpha Warrior", "with each class on its own")
WolfpackAddonDB.profiles, WolfpackAddonDB.classProfiles = keptProfiles, keptClasses
-- new profiles start from it, or the plain defaults if it can't be read
local fresh = ns.freshProfile()
assert(fresh.regular and fresh.nameplate and fresh.other and fresh.quest, "a complete profile either way")

-- Every bundled font path points at a real file in the addon folder
for _, f in ipairs(ns.COMBAT_FONTS) do
    local rel = f[2]:match("^Interface\\AddOns\\(.*)")
    if rel then assert(io.open((rel:gsub("\\", "/"))), "missing combat font " .. rel) end
end
for _, f in ipairs(ns.FONTS) do
    local rel = f[2]:match("^Interface\\AddOns\\(.*)")
    if rel then assert(io.open((rel:gsub("\\", "/"))), "missing font file " .. rel) end
end

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
        if sc.OnDragStop then sc.OnDragStop(f) end -- picking a macro up has nothing to stop
    end
end
for _, m in ipairs({ "regular", "nameplate" }) do
    local seen = {}
    for _, k in ipairs(prof()[m].order) do seen[k] = true end
    assert(seen.health and seen.power and seen.combo and seen.druidmana and seen.castbar and seen.pethealth
        and seen.swing and seen.totems and seen.absorb and #prof()[m].order == 9, "order intact")
end

-- Totems: four element segments, each draining on its own; the bar is shaman-only and
-- leaves the stack when the last totem drops.
login("SHAMAN", 0)
local tb = ns.frames.totems
prof().locked = true
fire("UNIT_MAXPOWER")
assert(tb:IsShown(), "shaman: the bar stays up (an empty slot can't be told from a full one)")
fire("PLAYER_TOTEM_UPDATE", 1)
assert(tb:IsShown() and tb.n == 4, "four segments")
assert(tb.segs[1]._timer.slot == 1 and tb.segs[1]._dir == 1, "each segment drains its own slot")
assert(tb.segs[3]._timer.slot == 3, "in slot order")
assert(tb.segs[1]._sbc[1] == 1 and tb.segs[3]._sbc[3] == 1, "fire red, water blue")
-- reorder and recolor: air first, in green
local tc = prof().regular.bars.totems
tc.slots = { 4, 1, 2, 3 }
tc.slotColors[4] = { 0, 1, 0, 1 }
fire("UNIT_MAXPOWER") -- in game the options do this through changed()
assert(tb.segs[1]._sbc[2] == 1 and tb.segs[2]._sbc[1] == 1, "air segment first, fire second")
assert(tb.segs[2]._timer.slot == 1, "the fire totem moved with it")
tc.slots = { 1, 2, 3, 4 }
login("ROGUE", 3)
fire("UNIT_MAXPOWER")
assert(not ns.frames.totems:IsShown(), "not a shaman: never shows")

-- Mana regen spinner: the five-second rule, mana classes only
login("MAGE", 0)
local spin, FS = ns.fsr.frame, prof().other.fsr
S.costs = { [133] = { { type = 0, cost = 100 } }, [1953] = {} } -- Fireball costs mana, Blink here doesn't
FS.show, FS.bar, FS.size, FS.color = true, "power", 30, { 1, 0, 0, 0.5 }
FS.fill = true
S.time = 3000
fire("UNIT_MAXPOWER")
assert(not spin:IsShown() and spin._w == 30 and spin._swipe[1] == 1, "idle: placed but hidden")
assert(spin._parent == ns.frames.power and spin._level > ns.frames.power:GetFrameLevel(), "over its bar")
assert(spin._swipeTex:find("Ring") and spin._reverse == true, "a ring that fills up")
fire("PLAYER_REGEN_DISABLED")
fire("UNIT_SPELLCAST_START", "player", "cast1", 133)
assert(spin:IsShown() and spin._cd[1] == 3000 and spin._cd[2] == 5, "in combat: the five-second rule")
S.time = 3002; fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast1", 133)
assert(spin._cd[1] == 3000, "the same cast doesn't restart it")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast2", 133) -- an instant
assert(spin._cd[1] == 3002, "an instant starts its own window")
fire("PLAYER_REGEN_ENABLED")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast9", 133)
assert(spin._cd[2] == 7, "out of combat: regen takes until the seventh second")
S.time = 3012; ns.fsr:sync()
assert(not spin:IsShown(), "window over: regen is back")
fire("UNIT_SPELLCAST_START", "player", "cast3", 1953)
assert(not spin:IsShown(), "a free spell doesn't break regen")
fire("UNIT_SPELLCAST_START", "player", "cast4", 133)
fire("UNIT_SPELLCAST_FAILED", "player", "cast4", 133)
assert(not spin:IsShown(), "a failed cast paid nothing")
login("ROGUE", 3)
prof().other.fsr.show = true
fire("UNIT_SPELLCAST_START", "player", "cast5", 133)
assert(not ns.fsr.frame:IsShown(), "no mana, no spinner")

-- Shield bar: absorb points left, scaled against max health
local ab = ns.frames.absorb
prof().regular.bars.absorb.show = true -- the control-poking above left this bar off
prof().regular.bars.absorb.text = true
S.absorb = 420
fire("UNIT_MAXPOWER")
assert(ab:IsShown() and ab.segs[1]._value == 420 and ab.segs[1]._max == 1000, "no shield seen land: max health")
assert(ab.text._text == "420", "the points left are written out")
-- we cast a shield: the change right after the cast sets the bar's full width
S.time = 4000
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "castShield", 17)
fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(ab.segs[1]._value == 420 and ab.segs[1]._max == 420, "full width when it lands")
S.time = 4008; S.absorb = 105; fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(ab.segs[1]._value == 105 and ab.segs[1]._max == 420, "later changes are damage, same scale")
S.absorb = 0; fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
assert(ab.segs[1]._value == 0 and ab.segs[1]._max == 420, "shield gone: empty bar")
prof().regular.bars.absorb.show = false

-- Prediction overlays: incoming heals grow right from the health fill, a cast's cost grows left
-- from the power fill (the bar clips whatever runs past its edge).
local hb, pb = ns.frames.health, ns.frames.power
prof().regular.bars.health.heal = true
S.incomingHeal = 250
fire("UNIT_MAXPOWER")
assert(hb.over:IsShown() and hb.over._max == 1000 and hb.over._value == 250, "incoming heals drawn")
assert(hb.over._reverseFill == false and hb.over._sbc[4] == 0.45, "grows right, in the heal color")
S.incomingHeal = 0; fire("UNIT_HEAL_PREDICTION", "player")
assert(hb.over._value == 0, "heals landed: nothing left to draw")
prof().regular.bars.power.cost = true
S.costs[8] = { { type = 3, cost = 35 } } -- an energy cost, for the rogue this test ends as
fire("UNIT_SPELLCAST_START", "player", "c1", 8)
assert(pb.over:IsShown() and pb.over._value == 35 and pb.over._reverseFill == true, "cost reserved")
fire("UNIT_SPELLCAST_STOP", "player", "c1", 8)
assert(pb.over._value == 0, "cast over: nothing reserved")
prof().regular.bars.health.heal, prof().regular.bars.power.cost = false, false
fire("UNIT_MAXPOWER")
assert(not hb.over:IsShown() and not pb.over:IsShown(), "switched off: both overlays gone")

-- Buff check: who in the group is missing a buff somebody here can give
login("PRIEST", 0)
local bo = prof().buffs
bo.show, bo.locked, bo.onlyMissing, bo.skip = true, true, false, {}
prof().locked, ns.configOpen = true, false
S.group, S.members, S.raid = true, 3, false
S.units = { party1 = "DAMAGER", party2 = "DAMAGER" }
S.unitClasses = { player = "PRIEST", party1 = "PALADIN", party2 = "MAGE" }
S.auras = {} -- nobody is buffed yet
ns.bfEv._scripts.OnEvent(ns.bfEv, "GROUP_ROSTER_UPDATE")
local rows, texts = ns.bf.rows, {}
for i, r in ipairs(rows) do if r:IsShown() then texts[#texts + 1] = r.text._text end end
assert(#texts >= 3, "a row per buff this group can hand out")
assert(table.concat(texts, "|"):find("Stamina"), "the priest's stamina is checked")
assert(table.concat(texts, "|"):find("A blessing"), "and the paladin's blessing")
assert(not table.concat(texts, "|"):find("Thorns"), "no druid here, no thorns row")
-- one blessing is enough, whichever it is
S.auras = { { name = "Blessing of Kings" } }
ns.bfEv._scripts.OnEvent(ns.bfEv, "UNIT_AURA")
local blessing
for _, r in ipairs(rows) do
    if r:IsShown() and r.text._text:find("A blessing") then blessing = r.text._text end
end
assert(blessing == "A blessing: all set", "any single blessing satisfies it")
-- in combat the list steps aside rather than guessing
S.combat = true
ns.bfEv._scripts.OnEvent(ns.bfEv, "PLAYER_REGEN_DISABLED")
assert(not ns.bf.panel:IsShown(), "combat: out of the way")
S.combat = false
ns.bfEv._scripts.OnEvent(ns.bfEv, "PLAYER_REGEN_ENABLED")
assert(ns.bf.panel:IsShown(), "and back afterwards")

S.group, S.members = false, 0
login("ROGUE", 3)

-- Rogue poisons: one icon per bare weapon, and a warning when one is running out
S.unitClasses = nil
login("ROGUE", 3)
local ro = prof().rogue
ro.show, ro.locked, ro.size, ro.gap, ro.warn, ro.flash = true, true, 30, 4, 9, true
S.weapons = { [16] = 501, [17] = 502 } -- a weapon in each hand
S.mainEnchant, S.offEnchant, S.combat = false, false, false
ns.weEv._scripts.OnEvent(ns.weEv, "UNIT_INVENTORY_CHANGED")
local rp = ns.we.panels.rogue
assert(rp.frame:IsShown() and rp.entries[1]:IsShown() and rp.entries[2]:IsShown(), "both hands bare")
assert(rp.entries[1].icon._tex == 501 and rp.entries[2].icon._tex == 502, "each weapon's own icon")
assert(rp.lit[1] and rp.lit[2], "and both flash")
S.mainEnchant, S.mainMs = true, 20 * 60000 -- twenty minutes on the main hand
ns.weEv._scripts.OnEvent(ns.weEv, "UNIT_INVENTORY_CHANGED")
assert(rp.entries[1].icon._tex == 502 and not rp.entries[2]:IsShown(), "only the bare one is left")
S.offEnchant, S.offMs = true, 7 * 60000 -- and the off hand is running out
ns.weEv._scripts.OnEvent(ns.weEv, "UNIT_INVENTORY_CHANGED")
assert(rp.entries[1]:IsShown() and rp.entries[1].text._text == "7m", "seven minutes, on the icon")
assert(not rp.lit[1], "a poison that is merely fading does not flash")
S.combat = true
ns.weEv._scripts.OnEvent(ns.weEv, "UNIT_INVENTORY_CHANGED")
assert(not rp.entries[1]:IsShown(), "a fading poison in combat: nothing to be done, so quiet")
-- and in a fight the call is not asked at all: whatever was true at the pull still stands
S.combat = false
S.mainEnchant, S.offEnchant = false, false
ns.weEv._scripts.OnEvent(ns.weEv, "UNIT_INVENTORY_CHANGED")
assert(rp.entries[1]:IsShown() and rp.lit[1], "bare when the fight starts")
S.combat = true
S.mainEnchant, S.offEnchant, S.mainMs, S.offMs = true, true, 60 * 60000, 60 * 60000
ns.weEv._scripts.OnEvent(ns.weEv, "UNIT_INVENTORY_CHANGED")
assert(rp.entries[1]:IsShown() and rp.lit[1], "the call says otherwise mid-fight and is ignored")
S.combat, S.mainEnchant, S.offEnchant = false, true, true
S.mainMs, S.offMs = 30 * 60000, 30 * 60000
ns.weEv._scripts.OnEvent(ns.weEv, "UNIT_INVENTORY_CHANGED")
assert(not rp.entries[1]:IsShown(), "both fresh: nothing shown at all")
S.weapons, ro.show = nil, false

-- Warlock: the soul shards in the bags
S.unitClasses = nil
login("WARLOCK", 0)
local wo = prof().warlock
wo.show, wo.locked, wo.size, wo.low, wo.showCount = true, true, 30, 3, true
local keptBags2 = S.bags
S.bags = { [0] = {
    { itemID = 6265, stackCount = 1 }, { itemID = 6265, stackCount = 1 },
    { itemID = 1, stackCount = 5 },
} }
wo.armor, wo.flash, wo.gap, wo.grow = true, true, 4, "right"
assert(prof().warlock.armorOnlyMissing == true, "armored means out of the way, by default")
wo.armorOnlyMissing, wo.fontSize, wo.armorFontSize = false, 11, 18
S.book, S.level = nil, 60 -- the spellbook says nothing on this client; the level still does
S.auras = {}
ns.wlEv._scripts.OnEvent(ns.wlEv, "BAG_UPDATE")
local shard, armor = ns.wl.entries[1], ns.wl.entries[2]
assert(ns.wl.panel:IsShown() and shard.text._text == 2, "two shards, and nothing else counted")
assert(shard.text._color[1] == 1 and shard.text._color[2] == 0.4, "two is low, so it reads low")
assert(armor:IsShown() and ns.wl.lit == armor, "no armor: that icon is the one that flashes")
assert(armor.icon._desat == false, "and it keeps its colors while it does")
assert(shard.text._font[2] == 11 and armor.text._font[2] == 18, "one font size each")
S.auras = { { name = "Demon Armor" } }
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(armor:IsShown() and ns.wl.lit == nil, "armor up: no flashing")
wo.armorOnlyMissing = true
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(not armor:IsShown(), "and with only-when-missing it is out of the way entirely")
-- In a fight nothing answers, so what was true on the way in is what is believed.
S.combat, S.auras = true, {}
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(not armor:IsShown(), "armored walking in: still armored, whatever the aura calls do")
S.combat, S.auras = false, {}
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(armor:IsShown() and ns.wl.lit == armor, "it fell off out here: back to flashing")
S.combat = true
S.spellNames = { [706] = "Demon Armor" }
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(armor:IsShown() and ns.wl.lit == armor, "bare walking in: still bare")
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 706)
assert(not armor:IsShown(), "cast it mid-fight and the reminder goes away")
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_SPELLCAST_SUCCEEDED", "pet", "cast-2", 706)
assert(not armor:IsShown(), "somebody else's cast changes nothing")
-- Blizzard's buff bar counts too, where it can be read
S.combat, S.auras = false, {}
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
BuffButton1 = new()
BuffButton1.icon = new()
BuffButton1.icon._tex = 100 + 706 -- the demon armor icon, sitting on the buff bar
BuffButton1.icon.GetTexture = function(self) return self._tex end
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(not armor:IsShown(), "the buff bar says it is up, so nothing is shown")
BuffButton1 = nil
-- a warlock too young for Demon Armor: the aura route must find Demon Skin too
S.level = 12
S.combat, S.auras = false, {}
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(armor:IsShown() and ns.wl.lit == armor, "skin missing: it is the one being asked for")
assert(armor.icon._tex == 100 + 696, "and it wears Demon Skin's icon, not Armor's")
S.auras = { { name = "Demon Skin" } }
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(ns.wl.lit == nil, "skin up out of combat: no flashing")
-- and a warlock buffed with Demon Skin at 60 is armored: the better one is not nagged for
S.combat, S.auras = false, { { name = "Demon Skin" } }
S.level = 60
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(not armor:IsShown(), "any of the two counts as armored")
S.auras = {}
ns.wlEv._scripts.OnEvent(ns.wlEv, "UNIT_AURA")
assert(armor:IsShown() and armor.icon._tex == 100 + 706, "bare at 60: Demon Armor is the ask")
SlashCmdList.WOLFPACKADDON("armor") -- the probe reads every route without blowing up
assert(not ns.errored, "the armor probe runs clean")
S.combat, wo.armorOnlyMissing = false, false

S.bags = { [0] = {} }
S.auras = {}
ns.wlEv._scripts.OnEvent(ns.wlEv, "BAG_UPDATE")
assert(shard.text._text == 0 and shard.icon._desat == true, "none: a grey shard and a zero")
S.bags = keptBags2
login("ROGUE", 3)
ns.wlEv._scripts.OnEvent(ns.wlEv, "BAG_UPDATE")
assert(not ns.wl.panel:IsShown(), "nothing for anyone else")

-- Macros: kept here without limit, handed to the game one at a time
login("WARRIOR", 1)
S.gameMacros, S.cursor = {}, nil
local shelf = ns.mc.shelf("WARRIOR")
assert(#shelf == 0, "a fresh shelf is empty")
for i = 1, 200 do shelf[i] = { name = "Charge " .. i, body = "/cast Charge" } end
assert(#ns.mc.shelf("WARRIOR") == 200, "two hundred saved, well past what the game would hold")
assert(#ns.mc.shelf("MAGE") == 0, "another class has its own shelf")
assert(WolfpackAddonDB.macros.WARRIOR[7].name == "Charge 7", "and they are saved with the addon")
-- handing one over writes a real macro, and editing it keeps the same slot
local idx = ns.mc.toGame(shelf[1])
assert(idx == 1 and S.gameMacros[1].body == "/cast Charge", "the game took it")
shelf[1].body = "/cast Heroic Strike"
assert(ns.mc.toGame(shelf[1]) == 1 and #S.gameMacros == 1, "the same name overwrites its slot")
assert(S.gameMacros[1].body == "/cast Heroic Strike", "with the new text")
-- a macro casting something known arrives wearing that spell's icon
S.spellTextures = { Charge = 132337 }
assert(ns.mc.guessIcon("/cast Charge") == 132337, "icon comes from the spell it casts")
assert(ns.mc.guessIcon("/say hello") == nil, "and nothing to guess from otherwise")
-- picking one up puts it on the cursor, ready for an action bar
assert(ns.mc.pickUp(shelf[2]) and S.cursor.name == "Charge 2", "it is on the cursor")
-- the game full, and combat, are both said out loud rather than swallowed
S.macroRoom = #S.gameMacros
local ok, why = ns.mc.toGame(shelf[50])
assert(not ok and why:find("full"), "no room: " .. tostring(why))
S.macroRoom = nil
S.combat = true
ok, why = ns.mc.toGame(shelf[50])
assert(not ok and why:find("fighting"), "not in combat: " .. tostring(why))
S.combat = false
for i = 1, 200 do shelf[i] = nil end

-- Training: the trainer's list, cut down by level and by what is already learned
login("PRIEST", 0)
S.level, S.known = 20, {}
local tset = prof().training
tset.hideKnown, tset.fromMyLevel = false, false
local all = ns.tr.list()
assert(#all > 0, "a priest has a list")
local headers, spells = 0, 0
for _, e in ipairs(all) do
    if e.spell then spells = spells + 1 else headers = headers + 1 end
end
assert(headers > 1 and spells > headers, "levels, each with spells under it")
assert(all[1].level and all[1].level < all[#all].level, "lowest level first")
tset.fromMyLevel = true
local fromMe = ns.tr.list()
local below = false
for _, e in ipairs(fromMe) do if e.level < 20 then below = true end end
assert(below, "a level walked past stays while there is anything there left to learn")
for _, e in ipairs(fromMe) do
    if e.spell and e.level == 1 then
        assert(e.trainable, "and a spell down there is trainable right now, not 'not yet'")
    end
end
-- learn everything up to 10 and those levels drop off
S.known = {}
for L, spells in pairs(ns.training.PRIEST) do
    if L <= 10 then for _, sp in ipairs(spells) do S.known[sp.id] = true end end
end
local done = ns.tr.list()
for _, e in ipairs(done) do assert(e.level > 10, "a level you are finished with is gone") end
assert(#done < #fromMe, "and that is a shorter list")
S.known = {}
-- a rank whose predecessor is missing is listed, but not as something you can train
S.level = 60
local gated = false
for _, e in ipairs(ns.tr.list()) do
    if e.spell and e.spell.requiredIds and #e.spell.requiredIds > 0 then
        assert(not e.trainable, "the rank below it is not known, so it is not trainable")
        gated = true
    end
end
assert(gated, "a priest has ranks that build on each other")
S.level = 20
-- Power Word: Fortitude, learned at 1, drops out once it is known
tset.fromMyLevel, tset.hideKnown = false, true
local before = #ns.tr.list()
S.known = { [1243] = true }
local after = ns.tr.list()
assert(#after < before, "a spell you know is not on the list")
for _, e in ipairs(after) do assert(not (e.spell and e.spell.id == 1243), "that one, precisely") end
S.known = {}
-- a mage's faction-only spells follow the faction
login("MAGE", 8)
S.faction = "Horde"
local horde = {}
for _, e in ipairs(ns.tr.list()) do if e.spell then horde[e.spell.id] = true end end
S.faction = "Alliance"
local ally = {}
for _, e in ipairs(ns.tr.list()) do if e.spell then ally[e.spell.id] = true end end
local differs = false
for id in pairs(horde) do if not ally[id] then differs = true end end
assert(differs, "the portals each side gets are not the same")
S.faction = "Horde"

-- Hunter: what is in the ammo slot, and the face the pet is pulling
S.unitClasses = nil -- the group test above left everyone else's class behind
login("HUNTER", 2)
local ho = prof().hunter
ho.show, ho.locked, ho.ammo, ho.pet, ho.size, ho.gap = true, true, true, true, 30, 4
ho.grow, ho.radius, ho.low, ho.showCount = "right", 25, 200, true
S.ammoID, S.ammoCount, S.ammoIcon, S.happiness, S.petHP = 2512, 143, 4321, 3, 400
ns.hnEv._scripts.OnEvent(ns.hnEv, "BAG_UPDATE")
SlashCmdList.WOLFPACKADDON("pet") -- the probe walks every route without blowing up
assert(not ns.errored, "the pet probe runs clean")
SlashCmdList.WOLFPACKADDON("loot") -- and so does the one that asks about the encounter journal
assert(not ns.errored, "the loot probe runs clean")
local ammo, pet = ns.hn.entries[1], ns.hn.entries[2]
assert(ns.hn.panel:IsShown() and ammo:IsShown() and pet:IsShown(), "both icons up for a hunter")
assert(ammo.icon._tex == 4321 and ammo.text._text == 143, "the ammo, with how many you carry")
assert(ammo.text._color[1] == 1 and ammo.text._color[2] == 0.4, "143 is under 200, so it reads low")
assert(ammo.icon.iconMask and ammo.mask._tex:find("i25"), "and its corners are rounded")
assert(pet.icon._tex:find("Happiness") and pet.icon._coords[1] == 2 * 0.1875, "a happy pet's face")
S.happiness = 1
ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(pet.icon._coords[1] == 0, "an unhappy one's")
S.petHP = nil
ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_PET")
assert(not pet:IsShown(), "no pet, no face")
ho.ammo = false
ns.hnEv._scripts.OnEvent(ns.hnEv, "BAG_UPDATE")
assert(not ns.hn.entries[1]:IsShown(), "and the ammo can be switched off")
-- this build answers on C_PetInfo, and hands back a table on some days
local keptHappy, keptInfo = GetPetHappiness, C_PetInfo
GetPetHappiness, S.happyTable = nil, true
S.petHP, ho.ammo = 400, true
ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(ns.hn.entries[2]:IsShown(), "C_PetInfo stands in for the call that went away")
S.happyTable = nil
-- and Blizzard's own indicator will say it outright when nothing else answers
C_PetInfo = nil
PetFrameHappiness = new()
PetFrameHappiness.GetHappinessStats = function() return 3 end
local face = new()
face.GetObjectType = function() return "Texture" end
face.GetAtlas = function() return "UI-PetHappiness-Content" end
PetFrameHappiness._regions = { face }
ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(ns.hn.entries[2]:IsShown(), "the indicator frame stands in as well")
assert(pet.icon._atlas == "UI-PetHappiness-Content",
    "and the face it is wearing is copied, not cut out of the old file by hand")
PetFrameHappiness = nil
S.petHP, ho.ammo = 400, true -- with a pet out, so the face would be drawn if it could be
ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(not (ns.hn.entries[2] and ns.hn.entries[2]:IsShown()), "no happiness here, no face")
C_PetInfo = keptInfo
GetPetHappiness = keptHappy
S.ammoID, S.happiness = nil, nil
login("ROGUE", 3)
ns.hnEv._scripts.OnEvent(ns.hnEv, "BAG_UPDATE")
assert(not ns.hn.panel:IsShown(), "nothing at all for anyone else")

-- Mage: the conjured food and water in the bags, best rank only, on its own panel
S.unitClasses = nil -- the group test above left everyone else's class behind
login("MAGE", 0)
local mo = prof().mage
mo.show, mo.locked, mo.size, mo.gap, mo.grow, mo.low = true, true, 30, 4, "right", 5
local keptBags = S.bags
S.level = 60
S.bags = { [0] = {
    { itemID = 5349, stackCount = 20, quality = 1 }, -- Conjured Muffin, the lowest rank
    { itemID = 8076, stackCount = 12, quality = 1 }, -- Conjured Sweet Roll
    { itemID = 8076, stackCount = 8, quality = 1 },
    { itemID = 8079, stackCount = 3, quality = 1 },  -- Conjured Crystal Water
} }
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
local food, water = ns.mg.entries[1], ns.mg.entries[2]
assert(ns.mg.panel:IsShown() and food:IsShown(), "the panel shows for a mage")
assert(food.text._text == 20, "the best food, counted across its stacks")
assert(food.icon._tex == 1000 + 8076, "with the Sweet Roll icon, not the Muffin's")
assert(water.text._text == 3 and water.icon._tex == 1000 + 8079, "and the best water")
assert(water.text._color and water.text._color[1] == 1 and water.text._color[2] == 0.4,
    "three is low, so it is colored that way")
-- and which of the two comes first is yours to choose
mo.waterFirst = true
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(food.icon._tex == 1000 + 8079 and water.icon._tex == 1000 + 8076, "water leads, food follows")
mo.waterFirst = false
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(food.icon._tex == 1000 + 8076, "and back the other way round")

-- the number can be put in the middle of the icon, or hidden altogether
mo.countAt, mo.showCount = "center", true
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(food.text._point[1] == "CENTER" and food.text:IsShown(), "the count sits in the icon")
mo.showCount = false
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(not food.text:IsShown(), "or not at all")
mo.showCount, mo.countAt = true, "corner"
-- stacked instead of side by side
mo.grow = "down"
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(water._point[4] == 0 and water._point[5] == -34, "stacked, one under the other")
mo.grow = "right"
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(water._point[4] == 34 and water._point[5] == 0, "or side by side")

-- empty bags still show the rank your level conjures, grayed out
S.bags = { [0] = {} }
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(food.text._text == 0 and food.icon._tex == 1000 + 22895, "level 60 conjures Cinnamon Rolls")
assert(food.icon._desat == true, "and it is grayed out")
mo.radius = 50
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(food.icon.iconMask and food.mask._tex:find("i50"), "the mage icons round off too")
assert(food.icon._coords[1] == 0 and food.icon._coords[2] == 1,
    "and are shown whole, because a mask ignores a crop and shrinks the art")
mo.radius = 0
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(food.icon._coords[1] == 0.08, "square again: the icon border is trimmed as before")
S.level = 10
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(food.icon._tex == 1000 + 1113, "at level 10 it is Conjured Bread")
S.bags, S.level = keptBags, 60
login("ROGUE", 3)
ns.mgEv._scripts.OnEvent(ns.mgEv, "BAG_UPDATE")
assert(not ns.mg.panel:IsShown(), "and nothing at all for anyone else")


-- the crit probe records what a hit looks like, and survives a client that sends nothing
ns.critEv._scripts.OnEvent(ns.critEv, "UNIT_COMBAT", "target", "WOUND", "CRITICAL", 412, 1)
assert((ns.critSeen.counts.UNIT_COMBAT or 0) >= 1, "hits are counted")
assert(ns.critSeen.samples["UNIT_COMBAT CRIT"]:find("CRITICAL"), "and a critical one is kept apart")
UnitDistanceSquared = function() return 361 end
CheckInteractDistance = function(_, i) return i > 2 end
-- a hunter's book: a melee swing, a shot with a minimum range, and a long shot
-- Aspect of the Hawk comes first and has no range at all, like melee does: it must not take
-- the melee slot, because the game says nothing about it when an enemy is targeted.
-- Eagle Eye reaches a hundred yards and would swamp the reading, so it must be left out
S.book = { { "Aspect of the Hawk", 0, 0, "self" }, { "Raptor Strike", 0, 0 },
    { "Arcane Shot", 8, 35 }, { "Auto Shot", 8, 35 }, { "Eagle Eye", 10, 100 } }
C_Spell.GetSpellInfo = function(name)
    for _, sp in ipairs(S.book or {}) do
        if sp[1] == name then return { name = name, minRange = sp[2], maxRange = sp[3] } end
    end
    return { name = name }
end
C_Spell.IsSpellInRange = function(name, unit)
    for _, sp in ipairs(S.book or {}) do
        if sp[1] == name then
            if sp[4] == "self" then return nil end -- nothing to say about an enemy
            if S.neutral and sp[2] > 0 then return nil end -- stingier about a neutral one
            local d, max = S.distance or 3, sp[3] > 0 and sp[3] or 5
            return d >= sp[2] and d <= max
        end
    end
end
IsActionInRange = function(slot) return slot <= 2 end
SlashCmdList.WOLFPACKADDON("crit")
SlashCmdList.WOLFPACKADDON("auras") -- the probe must not error, whatever the client has
SlashCmdList.WOLFPACKADDON("")
realPrint("smoke ok")
