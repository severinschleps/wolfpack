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
function M:HasFocus() return self._focus == true end
function M:Insert(t) self._text = (self._text or "") .. t end
function M:SetMinMaxValues(a, b) self._min, self._max = a, b end
function M:SetValue(v) assert(v ~= nil, "bad argument #1 to 'SetValue'"); self._value = v end -- the game refuses nil
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
function M:SetAlpha(v) self._alpha, self._alphaSets = v, (self._alphaSets or 0) + 1 end
function M:SetDesaturated(v) self._desat = v end
function M:SetAtlas(a) self._atlas = a end
function M:SetTexCoord(...) self._coords = { ... } end
function M:SetStatusBarColor(...) self._sbc = { ... } end
function M:SetStatusBarTexture(t) self._tex = t end
function M:SetCooldown(start, dur) self._cd = { start, dur } end
function M:SetSwipeTexture(t) self._swipeTex = t end
function M:SetHideCountdownNumbers(v) self._hideNums = v end
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
function M:SetClipsChildren(v) self._clips = v end
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
function M:SetHeight(h) self._h = h end
function M:SetAttribute(k, v) self._attr = self._attr or {}; self._attr[k] = v end
function M:GetUnboundedStringWidth() return 50 end
function M:GetStringWidth() return 8 end
function M:GetStringHeight() return 10 end
function M:GetNumPoints() return self._point and 1 or 0 end
function M:GetChildren() return unpack(self._children or self._kids or {}) end
function M:GetRegions() return unpack(self._regions or {}) end
function M:GetText() return self._text end
function M:IsObjectType(t) return self._kind == t end
function M:SetMaskTexture(m) self._mask = m end
-- like the game: SetPoint("TOPLEFT", x, y) reads back as relative to the parent
function M:GetPoint()
    local p = self._point
    if not p then return end
    if type(p[2]) == "number" then return p[1], self._parent, p[1], p[2], p[3] end
    return unpack(p)
end
-- children and regions are remembered, for code that walks a frame's contents
function M:CreateTexture() local t = new("Texture"); t._parent = self; self._regions = self._regions or {}
    table.insert(self._regions, t); return t end
function M:CreateFontString() local t = new("FontString"); t._parent = self; self._regions = self._regions or {}
    table.insert(self._regions, t); return t end
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
    GetBestMapForUnit = function() return S.bestMap or 84 end,
    GetMapArtLayers = function(id) return (S.mapArt or {})[id] and { S.mapArt[id].layer } or nil end,
    GetMapArtLayerTextures = function(id) return (S.mapArt or {})[id]
        and S.mapArt[id].tiles or nil end,
    GetPlayerMapPosition = function()
        if S.playerX == false then return nil end -- outside the place: the game says nothing
        return { GetXY = function() return S.playerX or 0.253, S.playerY or 0.607 end }
    end,
    -- a small map tree: the world, one continent, two zones
    GetMapInfo = function(id) return ({ [947] = { name = "Azeroth", mapType = 2 },
        [13] = { name = "Eastern Kingdoms", mapType = 2 },
        [52] = { name = "Westfall", mapType = 3 },
        [84] = { name = "Stormwind City", mapType = 3 },
        [291] = { name = "The Deadmines", mapType = 4 } })[id] end,
    GetMapChildrenInfo = function(id)
        if id == 947 then return { { mapID = 13 } } end
        if id == 13 then return { { mapID = 52 }, { mapID = 84 } } end
        return {}
    end,
    SetUserWaypoint = function(point) S.waypoint = point end,
}
GetPlayerFacing = function() return S.facing end
-- the older map API, from before map ids: this build is the reason it is still asked
SetMapToCurrentZone = function() S.mapPointed = true end
GetMapInfo = function() return S.oldFolder end
GetCurrentMapDungeonLevel = function() return S.oldFloor or 0 end
GetPlayerMapPosition = function() return S.oldX, S.oldY end
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
IsAltKeyDown = function() return S.alt end
IsControlKeyDown = function() return S.ctrl end
S.binds = {}
RegisterStateDriver = function(f, kind, rule) f._driver = rule end
UnregisterStateDriver = function(f) f._driver = nil end
ClearOverrideBindings = function(owner) S.binds = {} end
SetOverrideBindingClick = function(owner, prio, key, name, btn) S.binds[key] = name end
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
UnregisterUnitWatch = function(f) f._watched = false end
GetNumGroupMembers = function() return S.members or 0 end
UnitIsDeadOrGhost = function() return false end
UnitLevel = function() return S.level or 60 end
UnitOnTaxi = function() return S.onTaxi or false end
TaxiNodeName = function(slot) return (S.taxiNodes or {})[slot] end
GetSubZoneText = function() return S.subZone or "" end
GetZoneText = function() return S.zone or "Elwynn Forest" end
UnitRace = function() return "Orc", "Orc", S.raceID or 2 end
UnitFactionGroup = function() return S.faction or "Horde" end
IsResting = function() return S.resting end
IsSpellKnown = function(id) return (S.known or {})[id] == true end
GetMoneyString = function(c) return tostring(math.floor(c / 10000)) .. "g" end
GameTooltip.SetSpellByID = function(_, id) S.tooltip = id end
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
UnitCastingInfo = function(unit)
    if unit == "target" then
        if S.targetCast then return S.targetCast, "", 136116, 0, 0, false, nil, S.targetLocked end
        return nil
    end
    if S.cast then return S.cast, "", 136116 end
end
UnitChannelInfo = function(unit)
    if unit == "target" then
        if S.targetChannel then return S.targetChannel, "", 136197, 0, 0, false, S.targetLocked end
        return nil
    end
    if S.channel then return S.channel, "", 136197 end
end
UnitCastingDuration = function(unit)
    if unit == "target" then return S.targetCast and "targetCastDuration" or nil end
    return S.cast and "castDuration"
end
UnitChannelDuration = function(unit)
    if unit == "target" then return S.targetChannel and "targetChannelDuration" or nil end
    return S.channel and "channelDuration"
end
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
UnitGUID = function(unit) return unit == "player" and "Player-1" or S.npc end
GetBuildInfo = function() return "2.5.6", "1", "", 20506 end -- Anniversary
-- the combat log, as Anniversary and Classic Era still hand it to addons
CombatLogGetCurrentEventInfo = function() return unpack(S.cleu or {}, 1, 21) end
UnitAttackSpeed = function() return 2.4, 1.6 end
UnitRangedDamage = function() return 3.0 end
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
TargetFrame = new()
TargetFrame._parent = UIParent
MainMenuExpBar = new()
MainMenuExpBar._parent = UIParent
UnitXP = function() return S.xp or 300 end
UnitXPMax = function() return S.xpMax or 1000 end
GetRealmName = function() return "Realm" end
CreateFrame = function(kind, name, parent, template)
    local f = new(kind)
    f._name, f._parent, f._template = name, parent, template
    if name then _G[name] = f end
    if type(parent) == "table" then -- kept apart from _children, which some tests set by hand
        parent._kids = rawget(parent, "_kids") or {}
        table.insert(parent._kids, f)
    end
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
GetItemCount = function(id) return (S.items or {})[id] or 0 end
GetFactionInfoByID = function(id) return "Faction", "", (S.standing or {})[id] or 4 end
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
CompactUnitFrame_SetUpFrame = function() end -- Blizzard's; the addon hooks it
assert(loadfile("WolfpackAddon/UI.lua"))("WolfpackAddon", ns) -- loaded first, per the toc
-- one copy for every client: Classic Era, Forever, Anniversary, Classic (Mists) and Midnight must all be in the toc
S.toc = io.open("WolfpackAddon/WolfpackAddon.toc"):read("*a")
for _, v in ipairs({ "11509", "16001", "20506", "50504", "120105" }) do
    assert(S.toc:match("## Interface:[^\n]*" .. v), "the toc names interface " .. v)
end
assert(loadfile("WolfpackAddon/WolfpackAddon.lua"))("WolfpackAddon", ns)
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

-- Enemy health: in the stack while you have a target, its resource always right under it
local eh, ef = prof().regular.bars.enemyhealth, fr.enemyhealth
local rf = ef.resFrame
fire("PLAYER_TARGET_CHANGED")
assert(not ef:IsShown(), "off until you turn it on")
eh.show = true
fire("PLAYER_TARGET_CHANGED")
assert(not ef:IsShown(), "no target")
S.targetHP = 500
fire("PLAYER_TARGET_CHANGED")
assert(ef:IsShown() and ef.segs[1]._value == 500 and ef.segs[1]._max == 1000 and ef.texts.current._text == "500" and not ef.text:IsShown(),
    "target values")
assert(ef._point[1] == "TOP" and ef._point[5] == -20, "its own slot, right after your health")
-- three numbers, each optional, each in its own spot, size and color
local et = ef.texts
assert(et.current:IsShown() and not et.percent:IsShown() and not et.currentmax:IsShown(), "current only, as before")
eh.texts.percent.show, eh.texts.currentmax.show = true, true
eh.texts.percent.size, eh.texts.percent.color, eh.texts.percent.y = 14, { 1, 0, 0, 1 }, 2
fire("PLAYER_TARGET_CHANGED")
assert(et.percent._text == "50%" and et.currentmax._text == "500 / 1000" and et.current._text == "500", "all three")
assert(et.percent._point[1] == "RIGHT" and et.percent._point[4] == -4 and et.percent._point[5] == 2
    and et.currentmax._point[1] == "LEFT" and et.percent._color[1] == 1 and et.percent._color[2] == 0,
    "percent on the right in red, current / max on the left")
assert(et.percent._font[2] == 14, "its own size")
eh.text = false; fire("PLAYER_TARGET_CHANGED")
assert(not et.percent:IsShown() and not et.current:IsShown(), "Show text off: all of them")
eh.text = true
-- secret numbers: the percent comes from the game's own call
local realHP = UnitHealth
UnitHealth = function(u) return u == "target" and SECRET or realHP(u) end
CurveConstants, UnitHealthPercent = { ScaleTo100 = 1 }, function(u, pred, curve) return curve == 1 and 42.4 end
fire("PLAYER_TARGET_CHANGED")
assert(et.percent._text == "42%", "percent from the game when the numbers are secret")
UnitHealth, CurveConstants, UnitHealthPercent = realHP, nil, nil
eh.texts.percent.show, eh.texts.currentmax.show = false, false
fire("PLAYER_TARGET_CHANGED")
assert(rf:IsShown() and rf._point[1] == "BOTTOM" and rf._point[2] == ef and rf._point[3] == "BOTTOM"
    and rf._point[4] == 0 and rf._point[5] == 3, "the resource sits inside it, 3 up from its bottom")
assert(rf:GetFrameLevel() > ef:GetFrameLevel(), "drawn over the health bar")
assert(ef._h == 18 and rf._h == 4 and rf._w == 198 and fr.power._point[5] == -20 - 18 - 2,
    "4 tall, 90% of 220 wide, and the slot is just the health bar")
assert(rf.segs[1]._sbc[1] == 1 and rf.segs[1]._sbc[2] == 1 and rf.segs[1]._sbc[3] == 0,
    "the resource wears its power's color (energy, your yellow)")
-- level and name, inset at its left: the level in the game's difficulty color
local realLevel, realName = UnitLevel, UnitName
GetQuestDifficultyColor = function(l) return l >= 65 and { r = 1, g = 0.1, b = 0.1 } or { r = 0.5, g = 0.5, b = 0.5 } end
UnitLevel = function(u) return u == "target" and S.tLevel or 60 end
UnitClassification = function() return S.tKind or "normal" end
S.tLevel = 70; fire("PLAYER_TARGET_CHANGED")
local tl, tn = ef.tag_level, ef.tag_name
assert(tl:IsShown() and tl._text == "70" and tl._color[1] == 1 and tl._color[2] == 0.1 and tl._point[1] == "LEFT"
    and tl._point[2] == ef and tl._point[4] == 4 and not tn:IsShown(), "level on by default, red, inset left")
S.tLevel, S.tKind = 50, "elite"; eh.tagName = true; fire("PLAYER_TARGET_CHANGED")
assert(tl._text == "50+" and tl._color[1] == 0.5 and tn._text == S.name, "grey elite, and the name")
eh.nameAnchor, eh.nameX, eh.nameY, eh.tagAnchor, eh.tagY = "RIGHT", -6, 2, "CENTER", -3
fire("PLAYER_TARGET_CHANGED")
assert(tn._point[1] == "RIGHT" and tn._point[4] == -6 and tn._point[5] == 2 and tl._point[1] == "CENTER"
    and tl._point[5] == -3, "each in its own spot")
-- the level beside the name: next to its box, its own padding clear of it; X/Y still nudge it
eh.nameAnchor = "LEFT"
eh.tagAttach, eh.tagX, eh.tagY = "right", 1, 0; fire("PLAYER_TARGET_CHANGED")
assert(tl._point[1] == "LEFT" and tl._point[2] == tn.box and tl._point[3] == "RIGHT"
    and tl._point[4] == 1 + eh.tagBg.pad, "right of the name")
-- on the side the name starts from, the level takes the name's spot and the name moves over
eh.tagAttach = "left"; fire("PLAYER_TARGET_CHANGED")
assert(tl._point[1] == "LEFT" and tl._point[2] == ef and tl._point[4] == eh.nameX and tl._point[5] == eh.nameY,
    "left of a name on the left: the level in the name's spot")
assert(tn._point[1] == "LEFT" and tn._point[2] == tl.box and tn._point[3] == "RIGHT"
    and tn._point[4] == -1 + eh.nameBg.pad, "and the name right after it")
eh.nameAnchor, eh.tagAttach = "RIGHT", "right"; fire("PLAYER_TARGET_CHANGED")
assert(tl._point[1] == "RIGHT" and tl._point[2] == ef and tn._point[1] == "RIGHT" and tn._point[2] == tl.box
    and tn._point[3] == "LEFT", "the same on the right, mirrored")
eh.tagAttach = "top"; fire("PLAYER_TARGET_CHANGED")
assert(tl._point[1] == "BOTTOM" and tl._point[3] == "TOP" and tl._point[5] == eh.tagBg.pad, "above the name")
eh.tagName = false; fire("PLAYER_TARGET_CHANGED")
assert(tl._point[2] == ef and tl._point[1] == "CENTER", "no name shown: back to its own spot")
eh.tagName, eh.tagAttach, eh.tagX, eh.tagY = true, "free", 4, -3
S.tLevel = -1; fire("PLAYER_TARGET_CHANGED")
assert(tl._text == "??", "a skull reads ??")
UnitName = function(u) return u == "target" and SECRET or realName(u) end
fire("PLAYER_TARGET_CHANGED")
assert(tn._text == SECRET and tl._text == "??", "a secret name still draws, the level too")
UnitName = realName
-- a background each: off by default; on, it wraps the text with the padding, rounded if asked
UnitName = realName
assert(not tl.bg:IsShown() and not tn.bg:IsShown(), "no backgrounds by default")
eh.tagBg.show, eh.tagBg.pad, eh.tagBg.radius, eh.tagBg.color = true, 3, 4, { 0.2, 0, 0, 0.5 }
fire("PLAYER_TARGET_CHANGED")
assert(tl.bg:IsShown() and not tn.bg:IsShown() and tl.bg._color[1] == 0.2 and tl.bg._color[4] == 0.5,
    "the level's own background, in its color")
local p1, p2 = tl.box._points[1], tl.box._points[2]
assert(p1[2] == tl and p1[4] == -3 and p1[5] == 3 and p2[1] == "BOTTOMRIGHT" and p2[4] == 3 and p2[5] == -3,
    "padding all round")
assert(tl.bg._masks and tl.bg._masks[tl.mask] and tl.mask.r == 4, "rounded 4 px")
eh.tagBg.radius = 0; fire("PLAYER_TARGET_CHANGED")
assert(not tl.bg._masks[tl.mask], "square again")
eh.tagBg = { show = false, color = { 0, 0, 0, 0.6 }, pad = 2, radius = 0 }
eh.tagLevel, eh.tagName = false, false; fire("PLAYER_TARGET_CHANGED")
assert(not tl:IsShown() and not tn:IsShown(), "both off: nothing")
eh.tagLevel, S.tLevel, S.tKind = true, nil, nil
UnitLevel, GetQuestDifficultyColor, UnitClassification = realLevel, nil, nil
-- PvP flag on the bar: an icon, or text of your own
UnitIsPVP = function() return S.tPvP end
UnitIsPVPFreeForAll = function() return S.tFFA end
S.tPvP = true; fire("UNIT_FACTION", "target")
local pv = ef.pvpIcon
assert(pv:IsShown() and pv.tex._tex == "Interface\\TargetingFrame\\UI-PVP-Horde" and pv._point[1] == "CENTER"
    and pv._point[2] == ef and pv._point[3] == "TOPLEFT" and pv._w == 20, "flagged: its faction's emblem at top left")
eh.pvpIcon.style, eh.pvpIcon.point, eh.pvpIcon.x, eh.pvpIcon.size = "banner", "RIGHT", 5, 30
fire("UNIT_FACTION", "target")
assert(pv.tex._tex:find("INV_BannerPVP_01") and pv._point[3] == "RIGHT" and pv._point[4] == 5 and pv._w == 30,
    "another look, anchor, nudge and size")
S.tFFA = true; eh.pvpIcon.style = "faction"; fire("UNIT_FACTION", "target")
assert(pv.tex._tex:find("UI%-PVP%-FFA"), "free-for-all has its own")
-- text instead: its own words and color, the name's font and size
eh.pvpIcon.style, eh.pvpIcon.text, eh.pvpIcon.textColor = "text", "PVP!", { 0, 1, 0, 1 }
eh.tagSize = 13; fire("UNIT_FACTION", "target")
assert(pv:IsShown() and pv.text:IsShown() and not pv.tex:IsShown() and pv.text._text == "PVP!"
    and pv.text._color[2] == 1 and pv.text._font[2] == 13, "text, in its color, at the name's size")
-- on the name: outside it, on the side asked for; the name hidden: back on the bar
eh.pvpIcon.anchorTo, eh.pvpIcon.point, eh.pvpIcon.x = "name", "LEFT", -2
eh.tagName = true; fire("PLAYER_TARGET_CHANGED")
assert(pv._point[1] == "RIGHT" and pv._point[2] == ef.tag_name.box and pv._point[3] == "LEFT"
    and pv._point[4] == -2, "left of the name")
eh.pvpIcon.anchorTo = "level"; fire("UNIT_FACTION", "target")
assert(pv._point[2] == ef.tag_level.box, "or of the level")
eh.tagName, eh.pvpIcon.anchorTo = false, "name"; fire("PLAYER_TARGET_CHANGED")
assert(pv._point[2] == ef and pv._point[3] == "LEFT", "the name hidden: on the bar")
eh.tagSize = 10
S.tPvP, S.tFFA = false, false; fire("UNIT_FACTION", "target")
assert(not pv:IsShown(), "not flagged: gone")
UnitIsPVP = function() return SECRET end; fire("UNIT_FACTION", "target")
assert(not pv:IsShown(), "a secret answer: not shown, no error")
-- drinking: the name's place reads "Drinking!", flashing, in its color -- even with the name off
local tn2 = ef.tag_name
assert(not tn2:IsShown(), "name off, not drinking: nothing")
S.auras = { { name = "Drink", icon = 1 } }; fire("UNIT_AURA", "target")
assert(tn2:IsShown() and tn2._text == "Drinking!" and tn2._color[3] == 1 and tn2.box._scripts.OnUpdate,
    "drinking: says so, flashing")
tn2.box._scripts.OnUpdate(tn2.box)
eh.drinking.color = { 1, 0, 1, 1 }; fire("UNIT_AURA", "target")
assert(tn2._color[1] == 1 and tn2._color[2] == 0, "in the color you pick")
S.auras = { { name = SECRET, icon = 1 } }; fire("UNIT_AURA", "target")
assert(not tn2:IsShown() and not tn2.box._scripts.OnUpdate and tn2.box._alpha == 1, "a secret name can't be told: back")
eh.drinking.show = false; S.auras = { { name = "Drink", icon = 1 } }; fire("UNIT_AURA", "target")
assert(not tn2:IsShown(), "turned off")
eh.drinking = { show = true, color = { 0.35, 0.75, 1, 1 } }
eh.pvpIcon = { show = true, style = "faction", anchorTo = "bar", point = "TOPLEFT", x = 0, y = 0, size = 20,
    text = "PvP", textColor = { 1, 0.25, 0.25, 1 } }
S.auras, UnitIsPVP, UnitIsPVPFreeForAll = nil, nil, nil
fire("UNIT_AURA", "target")
-- buffs and debuffs: each group in a box; buffs hang above the bar, debuffs above the buffs
S.auras = { { icon = 111, duration = 10, expirationTime = 20 }, { icon = 112, applications = 3 } }
S.debuffs = { { icon = 221 } }
fire("UNIT_AURA", "target")
local bi, di = ef.auraIcons.buffs, ef.auraIcons.debuffs
local bb, db_ = ef.auraBoxes.buffs, ef.auraBoxes.debuffs
assert(bi[1]:IsShown() and bi[2]:IsShown() and bi[1].tex._tex == 111 and bi[2].count._text == 3
    and bi[1].cd._cd[1] == 10 and bi[1].cd._cd[2] == 10, "the target's buffs, with timer and stacks")
assert(bb._point[1] == "BOTTOMLEFT" and bb._point[2] == ef and bb._point[3] == "TOPLEFT" and bb._point[5] == 2
    and bb._w == 42 and bb._h == 20, "the buff box: above the bar, as big as two icons and a gap")
assert(bi[2]._point[2] == bb and bi[2]._point[4] == 22, "icons grow right, 20 + 2 apart")
assert(di[1].tex._tex == 221 and db_._point[2] == bb and db_._point[3] == "TOPLEFT" and db_._point[5] == 4,
    "debuffs hang on the buffs, a group gap up")
-- options open (or unlocked): dummies fill each group's grid, with timers and stacks, to tune by
prof().locked = false; fire("UNIT_AURA", "target")
assert(bi[8]:IsShown() and bi[1].tex._tex:find("Spell_Holy_WordFortitude") and di[16]:IsShown()
    and bi[1].cd._cd and bi[3].count._text == 3, "a full grid of stand-ins: 8 buffs, 16 debuffs")
prof().locked = true; fire("UNIT_AURA", "target")
assert(bi[1].tex._tex == 111 and not bi[3]:IsShown(), "closed again: the real ones")
-- debuffs on the bar, buffs on the debuffs: the other way round
eh.debuffs.anchorTo, eh.buffs.anchorTo, eh.buffs.spot = "bar", "other", "right"
fire("UNIT_AURA", "target")
assert(db_._point[2] == ef and bb._point[2] == db_ and bb._point[1] == "TOPLEFT" and bb._point[3] == "TOPRIGHT"
    and bb._point[4] == 4, "buffs to the right of the debuffs, a group gap across")
-- both on each other: buffs take the bar, nothing hangs in the air
eh.debuffs.anchorTo = "other"; fire("UNIT_AURA", "target")
assert(bb._point[2] == ef and db_._point[2] == bb, "a loop is broken at the buffs")
eh.buffs.anchorTo, eh.buffs.spot, eh.debuffs.spot = "bar", "above_right", "below_left"
eh.buffs.cols, eh.buffs.rows = 1, 2; fire("UNIT_AURA", "target")
assert(bi[2]._point[4] == 0 and bi[2]._point[5] == 22 and bb._h == 42, "one column: the second buff goes up a row")
eh.buffs.max = 1; fire("UNIT_AURA", "target")
assert(bi[1]:IsShown() and not bi[2]:IsShown(), "most icons caps it")
-- rounded icons, the swipe rounded with them; the timer text can go
eh.buffs.radius, eh.buffs.hideTimer = 25, true; fire("UNIT_AURA", "target")
assert(bi[1].tex._masks[bi[1].mask] and bi[1].cd._swipeTex:find("i25"), "rounded, swipe too")
assert(bi[1].tex._coords[1] == 0.08 and bi[1].tex._coords[2] == 0.92, "zoom 8: just the icon's own border cut")
eh.buffs.zoom = 20; fire("UNIT_AURA", "target")
assert(bi[1].tex._coords[1] == 0.2 and bi[1].tex._coords[4] == 0.8, "zoom 20: a fifth off each side, rounded too")
eh.buffs.zoom = 8
assert(bi[1].cd._hideNums == true and di[1].cd._hideNums == false, "buff timer text hidden, debuffs keep theirs")
eh.buffs.radius = 0; fire("UNIT_AURA", "target")
assert(not bi[1].tex._masks[bi[1].mask] and bi[1].cd._swipeTex:find("WHITE8X8"), "square again")
S.combat = true; S.auras = {}; fire("UNIT_AURA", "target")
assert(bi[1]:IsShown(), "the game refuses: the icons stay")
S.combat = false; fire("UNIT_AURA", "target")
assert(not bi[1]:IsShown() and bb._w == 1, "no buffs, no icons, a box of 1 px (never none: see below)")
-- the game draws nothing hung on a frame of no size, so debuffs never hang on empty buffs: they
-- take the buffs' own anchor on the bar until buffs show up again
assert(di[1]:IsShown() and db_._point[1] == "TOPRIGHT" and db_._point[2] == ef and db_._point[3] == "TOPLEFT"
    and db_._point[4] == eh.buffs.x and db_._point[5] == eh.buffs.y, "debuffs take the buffs' anchor")
eh.buffs.show = false; S.auras = { { icon = 111 } }; fire("UNIT_AURA", "target")
assert(db_._point[2] == ef and db_._point[3] == "TOPLEFT", "buffs turned off counts as empty")
eh.buffs.show = true; fire("UNIT_AURA", "target")
assert(db_._point[2] == bb and db_._point[5] == -4, "buffs back: debuffs hang on them again (below, a gap down)")
S.auras = {}
eh.debuffs.show = false; fire("UNIT_AURA", "target")
assert(not di[1]:IsShown(), "debuffs off")
-- grow up or down: a line is a column (rows icons tall); new columns go along the bar's edge
-- when growing straight away from it, else away from the bar
S.auras = { { icon = 1 }, { icon = 2 }, { icon = 3 } }
eh.debuffs.show = false
eh.buffs = { show = true, anchorTo = "bar", spot = "topright", grow = "up", x = 0, y = 0, size = 20, radius = 0,
    cols = 2, rows = 2, max = 4, hideTimer = false }
fire("UNIT_AURA", "target")
assert(bb._point[1] == "BOTTOMRIGHT" and bb._point[3] == "TOPRIGHT", "starts at the bar's top right corner")
assert(bi[2]._point[1] == "BOTTOMRIGHT" and bi[2]._point[4] == 0 and bi[2]._point[5] == 22, "the next one goes up")
assert(bi[3]._point[4] == -22 and bi[3]._point[5] == 0, "a new column: inward, to the left")
assert(bb._w == 42 and bb._h == 42, "two columns of two")
eh.buffs.spot, eh.buffs.grow = "righttop", "down"; fire("UNIT_AURA", "target")
assert(bb._point[1] == "TOPLEFT" and bb._point[3] == "TOPRIGHT" and bi[2]._point[5] == -22
    and bi[3]._point[4] == 22 and bi[3]._point[5] == 0, "right side, down, new columns away to the right")
-- grow then wrap, both chosen: up then left, right then down
eh.buffs.spot, eh.buffs.grow, eh.buffs.wrap = "topleft", "up", "left"; fire("UNIT_AURA", "target")
assert(bi[1]._point[1] == "BOTTOMRIGHT" and bi[2]._point[5] == 22 and bi[3]._point[4] == -22
    and bi[3]._point[5] == 0, "up, then a new column to the left")
eh.buffs.grow, eh.buffs.wrap = "right", "down"; fire("UNIT_AURA", "target")
assert(bi[1]._point[1] == "TOPLEFT" and bi[2]._point[4] == 22 and bi[3]._point[5] == -22,
    "right, then a new row down (into the bar: asked for)")
eh.buffs.wrap = "left"; fire("UNIT_AURA", "target")
assert(bi[3]._point[5] == 22, "a wrap along the growing makes no sense: auto")
eh.buffs.wrap = "auto"
-- the center line: right of the bar, buffs above it and debuffs below, a gap each way; alone, centered
eh.buffs.anchorTo, eh.buffs.spot, eh.buffs.y, eh.buffs.lineEdge = "line", "righttop", 0, "bottom"
eh.debuffs.anchorTo, eh.debuffs.spot, eh.debuffs.y, eh.debuffs.lineEdge = "line", "righttop", 0, "top"
eh.debuffs.show, eh.auraLineGap = true, 3
S.debuffs = { { icon = 221 } }; fire("UNIT_AURA", "target")
assert(bb._point[1] == "BOTTOMLEFT" and bb._point[2] == ef and bb._point[3] == "RIGHT" and bb._point[5] == 3,
    "buffs: bottom edge on the line, 3 above it")
assert(db_._point[1] == "TOPLEFT" and db_._point[3] == "RIGHT" and db_._point[5] == -3, "debuffs: top edge, 3 below")
S.debuffs = {}; fire("UNIT_AURA", "target")
assert(bb._point[1] == "LEFT" and bb._point[3] == "RIGHT" and bb._point[5] == 0, "buffs alone: centered on the line")
S.debuffs, S.auras = { { icon = 221 } }, {}; fire("UNIT_AURA", "target")
assert(db_._point[1] == "LEFT" and db_._point[5] == 0, "debuffs alone: centered too")
eh.buffs.spot = "lefttop"; eh.debuffs.anchorTo = "other"; S.auras = {}; fire("UNIT_AURA", "target")
assert(db_._point[1] == "RIGHT" and db_._point[3] == "LEFT", "hung on empty buffs on the line: their place, centered")
S.auras = { { icon = 1 }, { icon = 2 }, { icon = 3 } }
eh.debuffs.anchorTo, eh.debuffs.spot, eh.debuffs.lineEdge, eh.debuffs.show = "other", "topleft", "top", false
eh.buffs.anchorTo, eh.buffs.spot, eh.buffs.lineEdge, eh.buffs.y, eh.auraLineGap = "bar", "topright", "bottom", 0, 1
S.debuffs = nil
-- the old one-in-all choice converts by itself
eh.buffs.spot, eh.buffs.grow = "below_left", nil; fire("UNIT_AURA", "target")
assert(eh.buffs.spot == "bottomright" and eh.buffs.grow == "left" and bb._point[1] == "TOPRIGHT"
    and bb._point[3] == "BOTTOMRIGHT", "below_left: the bottom right corner, growing left")
eh.buffs = { show = true, anchorTo = "bar", spot = "topleft", grow = "right", wrap = "auto", x = 0, y = 2, size = 20, radius = 0,
    cols = 8, rows = 1, max = 8, hideTimer = false, zoom = 8 }
eh.debuffs = { show = true, anchorTo = "other", spot = "topleft", grow = "right", x = 0, y = 0, size = 24, radius = 0,
    cols = 8, rows = 2, max = 16, hideTimer = false, zoom = 8 }
S.auras, S.debuffs = nil, nil
eh.resWidth, eh.resHeight, eh.resX, eh.resY = 50, 8, -20, 5
fire("PLAYER_TARGET_CHANGED")
assert(rf._w == 110 and rf._h == 8 and rf._point[4] == -20 and rf._point[5] == 5, "sliders size and place it")
eh.resWidth, eh.resHeight, eh.resX, eh.resY = 90, 4, 0, 3
-- the resource's own text switch and border, over enemy health's look
assert(rf.text:IsShown() and rf.segs[1].border._shown == false, "text like enemy health, no border yet")
eh.resHideText, eh.resBorderSize, eh.resRadius = true, 1, 4
eh.resBorderMode, eh.resBorderColor = "custom", { 0, 0, 1, 1 }
fire("PLAYER_TARGET_CHANGED")
assert(not rf.text:IsShown() and ef.texts.current:IsShown(), "resource text hidden, health text kept")
assert(rf.segs[1].border._shown and rf.segs[1].border._color[3] == 1 and rf.segs[1]._w == 196 and rf.segs[1]._h == 2,
    "a 1 px blue border inside its size")
assert(rf.segs[1].borderMask._tex:match("r2%.tga$"), "its own corner radius, capped at half its 4 px height")
assert(ef.segs[1].border._shown == false, "enemy health's border untouched")
eh.resBorderMode = "bar"
fire("PLAYER_TARGET_CHANGED")
assert(rf.segs[1].border._color[1] == 1 and rf.segs[1].border._color[3] == 0.25, "same as bar: a lighter energy yellow")
eh.resHideText, eh.resBorderSize, eh.resRadius = false, 0, 0
fire("PLAYER_TARGET_CHANGED")
-- an empty resource hides; a secret one can't be looked at, so it stays
assert(rf:GetAlpha() == 1, "secret power: shown")
S.realPower = UnitPower
UnitPower = function() return 0 end
fire("UNIT_POWER_FREQUENT", "target")
assert(rf:GetAlpha() == 0, "nothing left: hidden")
UnitPower = function() return 40 end
fire("UNIT_POWER_FREQUENT", "target")
assert(rf:GetAlpha() == 1, "power back: shown again")
UnitPower = S.realPower
eh.resource = false
fire("PLAYER_TARGET_CHANGED")
assert(not rf:IsShown(), "resource off")
eh.resource = true

-- Beside your health: the two share its width and its height
eh.beside = true
fire("PLAYER_TARGET_CHANGED")
local tp, hp = ef._point, fr.health._point
assert(ef:IsShown() and tp[1] == "TOPLEFT" and tp[2] == fr.health and tp[3] == "TOPRIGHT" and tp[4] == 2,
    "beside health")
assert(fr.health._w == 109 and ef._w == 109, "220 wide, 2 gap: two halves of 109")
assert(hp[1] == "TOPLEFT" and hp[3] == "TOP" and hp[4] == -110, "player half starts at the bar's left edge")
assert(ef._h == 18 and rf._h == 4 and rf._w == 98, "as tall as your health; the resource 90% of its half")
assert(fr.power._point[5] == -20, "and it no longer takes a slot in the stack")
prof().regular.bars.health.colorMode, eh.colorMode = "class", "class"
S.targetClass = "MAGE"; fire("PLAYER_TARGET_CHANGED")
assert(ef.segs[1]._sbc[1] == 0.8 and fr.health.segs[1]._sbc[1] == 1, "NPC target: custom color, you: class")
S.targetIsPlayer = true; fire("PLAYER_TARGET_CHANGED")
assert(ef.segs[1]._sbc[1] == 0.25, "player target: their class color")
S.targetIsPlayer, prof().regular.bars.health.colorMode, eh.colorMode = nil, "custom", "custom"
-- standing toward you: reaction mode, and class mode's choice for an NPC
UnitReaction = function() return S.reaction end
S.reaction, eh.colorMode = 2, "reaction"; fire("PLAYER_TARGET_CHANGED")
assert(ef.segs[1]._sbc[1] == 0.85 and ef.segs[1]._sbc[2] == 0.2, "hostile: the palette's hostile")
S.reaction = 4; fire("PLAYER_TARGET_CHANGED")
assert(ef.segs[1]._sbc[2] == 0.8 and ef.segs[1]._sbc[1] == 0.95, "neutral")
eh.colorMode = "class"; S.reaction = 5; fire("PLAYER_TARGET_CHANGED")
assert(ef.segs[1]._sbc[1] == 0.2 and ef.segs[1]._sbc[2] == 0.8, "class mode, an NPC: friendly by standing")
UnitReaction, S.reaction, eh.colorMode = nil, nil, "custom"
fire("PLAYER_TARGET_CHANGED")
S.targetHP = 250; fire("UNIT_HEALTH", "target")
assert(ef.segs[1]._value == 250 and fr.health.segs[1]._value == SECRET, "target updates, player keeps its own")
-- Target of target: right of enemy health (its height, own width), below it (the two share the
-- slot), or in the stack; enemy health's buffs then hang on the two together
S.saved = { eh.beside, eh.show }
eh.show, eh.beside = true, true
S.TT = prof().regular.bars.tothealth
S.units = S.units or {}
S.units.targettarget = true
S.TT.show = true; fire("UNIT_TARGET", "target")
S.tf = fr.tothealth
assert(S.tf:IsShown() and S.tf._point[1] == "TOPLEFT" and S.tf._point[2] == ef and S.tf._point[3] == "TOPRIGHT"
    and S.tf._point[4] == prof().regular.gap and S.tf._w == 90 and S.tf._h == ef._h, "right of enemy health: its height, own width")
assert(ef.span and ef.auraBoxes.buffs._point[2] == ef.span and ef.span._points[2][2] == S.tf,
    "enemy buffs hang on enemy health and its target together")
S.TT.anchor = "below"; fire("UNIT_TARGET", "target")
assert(S.tf._point[2] == ef and S.tf._point[3] == "BOTTOMLEFT" and S.tf._point[5] == -prof().regular.gap and S.tf._w == ef._w,
    "below: enemy health's width")
assert(ef._h == 18 - S.TT.height - prof().regular.gap, "beside you, the two together as tall as your health")
-- its health is asked for (nothing tells), five times a second
S.realHP = UnitHealth
UnitHealth = function(u) return u == "targettarget" and 77 or S.realHP(u) end
ns.totPoll._scripts.OnUpdate(ns.totPoll, 1)
assert(S.tf.segs[1]._value == 77, "health polled")
UnitHealth = S.realHP
S.units.targettarget = nil; fire("UNIT_TARGET", "target")
assert(not S.tf:IsShown() and ef._h == 18, "no target of target: enemy health takes it all back")
S.units.targettarget = true
assert(S.tf.tag_name:IsShown(), "its name, by default")
S.TT.tagName = false; fire("UNIT_TARGET", "target")
assert(not S.tf.tag_name:IsShown(), "name hidden")
S.TT.tagName = true
S.TT.anchor = "stack"; fire("UNIT_TARGET", "target")
assert(S.tf:IsShown() and S.tf._point[2] == WolfpackAddonFrame, "in the stack like any other bar")
S.TT.show, S.TT.anchor = false, "right"
S.units.targettarget = nil
-- Your pet below your health: as wide as it, the bars below move down, and enemy health beside
-- you grows to match the two
S.PB = prof().regular.bars.pethealth
S.petHP, S.PB.show, S.PB.anchor = 100, true, "below"; fire("UNIT_PET", "player")
S.pf = fr.pethealth
assert(S.pf:IsShown() and S.pf._point[1] == "TOPLEFT" and S.pf._point[2] == fr.health and S.pf._point[3] == "BOTTOMLEFT"
    and S.pf._w == fr.health._w, "under your health, as wide as it")
assert(ef._h == 18 + prof().regular.gap + S.PB.height, "enemy health beside you: your health and pet together")
assert(fr.power._point[5] == -(18 + prof().regular.gap + S.PB.height + prof().regular.gap), "the stack makes room")
S.units.targettarget, S.TT.show, S.TT.anchor = true, true, "below"; fire("UNIT_TARGET", "target")
assert(ef._h == 18 + prof().regular.gap + S.PB.height - S.TT.height - prof().regular.gap, "and target of target below shares that")
S.units.targettarget, S.TT.show, S.TT.anchor = nil, false, "right"
S.PB.anchor = "left"; fire("UNIT_PET", "player")
assert(S.pf._point[1] == "TOPRIGHT" and S.pf._point[3] == "TOPLEFT" and S.pf._point[4] == -prof().regular.gap and S.pf._h == fr.health._h,
    "left of your health, its height")
assert(fr.health.span and fr.health.auraBoxes.buffs._point[2] == fr.health.span
    and fr.health.span._points[1][2] == S.pf and fr.health.span._points[2][2] == fr.health,
    "your buffs hang on pet and health together, the pet starting the block")
S.PB.anchor = "below"; fire("UNIT_PET", "player")
assert(fr.health.span._points[1][2] == fr.health and fr.health.span._points[2][2] == S.pf, "below: health starts it")
S.PB.anchor = "left"
S.petHP = nil; fire("UNIT_PET", "player")
assert(not S.pf:IsShown(), "no pet: gone")
assert(fr.health.auraBoxes.buffs._point[2] == fr.health, "no pet: back on your health")
S.PB.anchor = "stack"
eh.beside, eh.show = S.saved[1], S.saved[2]
fire("PLAYER_TARGET_CHANGED")
rf.segs[1]._value = nil; fire("UNIT_POWER_FREQUENT", "target")
assert(rf.segs[1]._value == SECRET, "its resource follows the target's power")
assert(WolfpackAddonFrame._w == 220, "stack width ignores the enemy bar")
S.targetHP = nil; fire("PLAYER_TARGET_CHANGED")
assert(not ef:IsShown() and fr.health._w == 220 and fr.health._point[1] == "TOP", "target gone: full width again")
eh.show, eh.beside = false, false

-- the old "Target health beside it" switch becomes Enemy Health beside you
prof().regular.bars.health.target = true
fire("PLAYER_LOGIN")
assert(eh.show and eh.beside and not prof().regular.bars.health.target, "old switch carried over")
eh.show, eh.beside = false, false

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
-- the border is a lighter shade of where the fill starts, not of the plain color
S.gc = gb.stops[1].color
gb.stops[1].color = { 0, 0, 1, 1 }
fire("UNIT_MAXPOWER")
assert(gs.border._color[1] == 0.25 and gs.border._color[3] == 1, "gradient border from its start")
gb.stops[1].color = S.gc
fire("UNIT_MAXPOWER")
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
-- "Casting / channeling": the palette's channel color while channeling, its cast color while casting
prof().regular.bars.castbar.colorMode = "cast"; fire("UNIT_SPELLCAST_CHANNEL_START", "player")
assert(cs._sbc[1] == 0.3 and cs._sbc[3] == 1, "channeling: the channel color")
S.channel, S.cast = nil, "Fireball"; fire("UNIT_SPELLCAST_START", "player")
assert(cs._sbc[1] == 1 and cs._sbc[2] == 0.7, "casting: the cast color")
S.cast, S.channel = nil, "Drain Life"; fire("UNIT_SPELLCAST_CHANNEL_START", "player")
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
-- a swing whose numbers come back secret can't be timed: skipped, and nothing breaks
fire("PLAYER_SWING", SECRET, 1)
fire("PLAYER_SWING", 2.0, SECRET)
fire("PLAYER_SWING")
S.time = 1001.5; ns.swingTicker._scripts.OnUpdate()
assert(not swf[2]:IsShown() and swf[1]:IsShown() and swf[1].text._text == "1.1", "secret swings skipped, main hand runs on")
S.time = 1001
fire("PLAYER_SWING", 1.8, 2) -- ranged
assert(swf[3]:IsShown() and WolfpackAddonFrame._h == 72 and swf[3]._point[5] == -62, "ranged joins below it")
S.time = 1010; ns.swingTicker._scripts.OnUpdate()
assert(not swf[1]:IsShown() and not swf[3]:IsShown(), "done: rows leave")
assert(WolfpackAddonFrame._h == 48 and not ns.swingTicker._scripts.OnUpdate, "stack closed up, ticker stopped")
-- Anniversary and Classic Era: no PLAYER_SWING; the combat log says when you swing, and the
-- weapon's speed how long the next one takes
assert(ns.swingLog, "a client with a combat log and no swing timer API reads the log")
local function logged(sub, source, a12, a13, a21)
    S.cleu = { 0, sub, false, source, "", 0, 0, "Mob-1", "", 0, 0, a12, a13 }
    S.cleu[21] = a21
    fire("COMBAT_LOG_EVENT_UNFILTERED")
end
logged("SWING_DAMAGE", "Player-2", 10)
assert(not swf[1]:IsShown(), "someone else's swing: nothing starts")
logged("SPELL_DAMAGE", "Player-1", 133)
assert(not swf[1]:IsShown(), "not a swing: nothing starts")
logged("SWING_DAMAGE", "Player-1", 25, 0, nil)
assert(swf[1].segs[1]._max == 2.4 and swf[1].segs[1]._value == 0, "a main-hand hit: the next swing, at your speed")
logged("SWING_MISSED", "Player-1", "DODGE", true)
assert(swf[2]:IsShown() and swf[2].segs[1]._max == 1.6, "an off-hand dodge: the off hand's next swing")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 75)
assert(swf[3]:IsShown() and swf[3].segs[1]._max == 3.0, "Auto Shot: the ranged swing")
S.cleu = nil
S.time = 1020; ns.swingTicker._scripts.OnUpdate()
assert(not swf[1]:IsShown() and not swf[2]:IsShown() and not swf[3]:IsShown(), "all three ran out")
prof().locked = false; fire("UNIT_MAXPOWER")
assert(swf[1]:IsShown() and swf[3]:IsShown() and swf[1].text._text == "Main hand", "unlocked: preview rows")
assert(swf[1].segs[1]._value == 1 and swf[1].segs[1]._max == 1, "a full bar to place, not the last swing's fill")
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

-- Status icon on your health bar: the combat icon in a fight, else rested while resting
local st, sti = prof().regular.bars.health.statusIcon, nil
fire("UNIT_MAXPOWER")
sti = fr.health.statusIcon
assert(not sti:IsShown(), "out of combat, not resting: nothing")
fire("PLAYER_REGEN_DISABLED")
assert(sti:IsShown() and sti.tex._atlas == "UI-HUD-UnitFrame-Player-CombatIcon" and sti._w == 20
    and sti._point[1] == "CENTER" and sti._point[2] == fr.health and sti._point[3] == "LEFT" and sti._point[4] == -12,
    "in a fight: the combat icon, just left of the bar")
st.style = "classic"; fire("UNIT_MAXPOWER")
assert(sti.tex._tex == 130936 and sti.tex._coords[1] == 0.5, "classic swords cropped from the state icon")
st.style = "atlas"
fire("PLAYER_REGEN_ENABLED")
assert(not sti:IsShown(), "combat over")
S.resting = true; fire("PLAYER_UPDATE_RESTING")
assert(sti:IsShown() and sti.tex._tex == 130936 and sti.tex._coords[1] == 0, "resting: the rested icon")
-- or a text of your own, one font string per letter, in the bar's font size and its own color
st.restStyle, st.restText, st.restColor = "text", "Zzé", { 0.1, 0.2, 0.3, 1 }
prof().regular.bars.health.fontSize = 11; fire("PLAYER_UPDATE_RESTING")
assert(sti:IsShown() and not sti.tex:IsShown() and sti.waveN == 3 and sti.letters[1]._text == "Z"
    and sti.letters[3]._text == "é" and sti.letters[2]._font[2] == 11 and sti.letters[1]._color[3] == 0.3,
    "three letters (é is one), its size and color")
assert(sti.letters[2]._point[2] == sti and sti.letters[2]._point[4] == 8, "side by side")
-- the wave: each letter fades in and out a step behind the one before
assert(sti._scripts.OnUpdate, "the letters fade in turn")
sti._scripts.OnUpdate(sti)
assert(sti.letters[1]._alpha ~= sti.letters[2]._alpha, "staggered")
st.restWave = false; fire("PLAYER_UPDATE_RESTING")
assert(not sti._scripts.OnUpdate and sti.letters[1]._alpha == 1, "no wave: plain text")
st.restText = "Ab"; fire("PLAYER_UPDATE_RESTING")
assert(sti.waveN == 2 and not sti.letters[3]:IsShown(), "a shorter text hides the letters left over")
st.restStyle, st.restText, st.restWave = "icon", "Zzz", true
prof().regular.bars.health.fontSize = 10; fire("PLAYER_UPDATE_RESTING")
assert(sti.tex:IsShown() and not sti.letters[1]:IsShown(), "back to the icon")
st.rested = false; fire("PLAYER_UPDATE_RESTING")
assert(not sti:IsShown(), "rested icon off")
st.rested, S.resting = true, false
prof().locked = false; fire("UNIT_MAXPOWER")
assert(sti:IsShown(), "unlocked: preview for placing it")
prof().locked = true; fire("UNIT_MAXPOWER")
-- the old in-combat icon moves onto it, where it was
WolfpackAddonDB.profiles.OldIcon = { regular = { combatIcon = { show = false, style = "battle", bar = "health",
    size = 30, x = -40, y = 5, fromCenter = true } } }
local home2 = WolfpackAddonDB.chars[S.name .. " - Realm"]
ns.useProfile("OldIcon")
local mst = prof().regular.bars.health.statusIcon
assert(mst.show == false and mst.style == "battle" and mst.size == 30 and mst.point == "CENTER" and mst.x == -40
    and mst.y == 5 and prof().regular.combatIcon == nil, "moved over, from the bar's middle")
ns.useProfile(home2)
WolfpackAddonDB.profiles.OldIcon = nil
-- your own PvP flag on your health bar
UnitIsPVP = function(u) return u == "player" end
fire("UNIT_FACTION", "player")
assert(fr.health.pvpIcon:IsShown() and fr.health.pvpIcon.tex._tex:find("UI%-PVP%-Horde"), "your PvP flag")
prof().regular.bars.health.pvpIcon.style, prof().regular.bars.health.fontSize = "text", 12
fire("UNIT_FACTION", "player")
assert(fr.health.pvpIcon.text._text == "PvP" and fr.health.pvpIcon.text._font[2] == 12, "text: the bar's font size")
prof().regular.bars.health.pvpIcon.style = "faction"
UnitIsPVP = function() return false end; fire("UNIT_FACTION", "player")
assert(not fr.health.pvpIcon:IsShown(), "not flagged")
UnitIsPVP = nil

-- incoming heals are cut at the bar's edge by a frame of their own: the bar itself never clips,
-- or every icon, buff and text hung outside it would be cut off too (seen in game)
prof().regular.bars.health.heal = true; fire("UNIT_MAXPOWER")
assert(fr.health.over and fr.health.over:GetParent()._clips and not fr.health._clips,
    "the heal overlay's own frame clips, the bar doesn't")
prof().regular.bars.health.heal = false; fire("UNIT_MAXPOWER")
-- buffs and debuffs on your own health bar, the same options as enemy health; all your debuffs
S.auras, S.debuffs = { { icon = 501 }, { icon = 502 } }, { { icon = 601 } }
fire("UNIT_AURA", "player")
S.hb2, S.hd2 = fr.health.auraIcons.buffs, fr.health.auraIcons.debuffs
assert(S.hb2[1]:IsShown() and S.hb2[2].tex._tex == 502 and S.hd2[1].tex._tex == 601, "your buffs and debuffs")
assert(fr.health.auraBoxes.buffs._point[2] == fr.health and fr.health.auraBoxes.debuffs._point[2]
    == fr.health.auraBoxes.buffs, "above your bar, debuffs over the buffs")
prof().regular.bars.health.buffs.show = false; fire("UNIT_AURA", "player")
assert(not S.hb2[1]:IsShown() and S.hd2[1]:IsShown(), "each switches on its own")
prof().regular.bars.health.buffs.show = true
S.auras, S.debuffs = nil, nil; fire("UNIT_AURA", "player")

-- Border and radius: border inside the bar's size, bar inset by it; one mask file per radius,
-- sliced at native size (Media/Round/r<N>.tga)
local hb = prof().regular.bars.health -- 220 x 18
local function maskR(m) return m._tex:match("r(%d+)%.tga$") + 0, m._slice[1] end
hb.borderFrom, hb.borderSize, hb.radius = "own", 2, 8
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
-- shared: every bar not set to its own takes the profile's border width and corners
hb.borderFrom = "shared"
prof().colors.borderSize, prof().colors.radius = 2, 8; fire("UNIT_MAXPOWER")
assert(seg._w == 216 and seg.border:IsShown() and maskR(seg.borderMask) == 8, "shared width and corners")
assert(fr.power.segs[1].border:IsShown(), "on every shared bar")
hb.borderFrom, hb.borderSize = "own", 0; fire("UNIT_MAXPOWER")
assert(seg._w == 220 and not seg.border:IsShown(), "its own (none) wins")
hb.borderFrom = "shared"
prof().colors.borderSize, prof().colors.radius = 0, 0; fire("UNIT_MAXPOWER")
-- the texture the same way: shared by default, or the bar's own
S.T2 = ns.TEXTURES[2][2]
prof().colors.texture = S.T2; fire("UNIT_MAXPOWER")
assert(seg._tex == S.T2 and fr.power.segs[1]._tex == S.T2, "the shared texture on every bar")
hb.textureFrom, hb.texture = "own", ns.TEXTURES[3][2]; fire("UNIT_MAXPOWER")
assert(seg._tex == ns.TEXTURES[3][2] and fr.power.segs[1]._tex == S.T2, "its own wins")
hb.textureFrom, hb.texture = "shared", ns.TEXTURES[1][2]
prof().colors.texture = ns.TEXTURES[1][2]; fire("UNIT_MAXPOWER")
-- an older profile: a bar with a border of its own keeps it, once
WolfpackAddonDB.profiles.OldBorder = { regular = { bars = { power = { borderSize = 3 },
    castbar = { texture = "Interface\\Old\\Tex" } } } }
S.homeB = WolfpackAddonDB.chars[S.name .. " - Realm"]
ns.useProfile("OldBorder")
assert(prof().regular.bars.power.borderFrom == "own" and prof().regular.bars.health.borderFrom == "shared"
    and prof().colors.bordersSet, "a border of its own stays its own; the rest share")
assert(prof().regular.bars.castbar.textureFrom == "own" and prof().regular.bars.power.textureFrom == "shared",
    "a texture of its own stays its own")
ns.useProfile(S.homeB)
WolfpackAddonDB.profiles.OldBorder = nil
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
hc.borderFrom, hc.colorMode, hc.borderSize, hc.borderMode = "own", "class", 1, "bar"; fire("UNIT_MAXPOWER")
assert(hs._sbc[1] == 1 and hs._sbc[3] == 0.41 and math.abs(hs.border._color[3] - 0.5575) < 1e-6
    and hs.border._color[1] == 1, "class bar, border = the bar's color, a quarter of the way to white")
-- the palette: the border shade, class, power and health colors live there, the bars pick
local PAL = prof().colors
PAL.borderShade = -50; fire("UNIT_MAXPOWER")
assert(math.abs(hs.border._color[1] - 0.5) < 1e-6 and math.abs(hs.border._color[3] - 0.205) < 1e-6,
    "shade -50: the class color halfway to black")
PAL.borderShade = 25
PAL.class.ROGUE = { 0.1, 0.2, 0.3, 1 }; fire("UNIT_MAXPOWER")
assert(hs._sbc[1] == 0.1 and hs._sbc[3] == 0.3, "class color as set on the Colors page")
PAL.class.ROGUE = { 1, 0.96, 0.41, 1 }
hc.colorMode = "health"; PAL.health = { 0.3, 0.6, 0.9, 1 }; fire("UNIT_MAXPOWER")
assert(hs._sbc[1] == 0.3 and hs._sbc[3] == 0.9, "health color from the palette")
PAL.health = { 0.2, 0.8, 0.2, 1 }
hc.colorMode, hc.borderMode = "custom", "custom"; fire("UNIT_MAXPOWER")
assert(hs._sbc[1] == 0.2 and hs.border._color[1] == 0, "custom bar, custom border")
hc.borderSize, hc.borderMode = 0, "custom"
-- a color per power: rage, energy, mana, focus and more, all on the Colors page
assert(PAL.power.RAGE and PAL.power.ENERGY and PAL.power.MANA and PAL.power.FOCUS and PAL.power.RUNIC_POWER,
    "power colors in the palette")
PAL.power.ENERGY = { 0.1, 0.8, 0.9, 1 }; fire("UNIT_MAXPOWER")
assert(fr.power.segs[1]._sbc[1] == 0.1 and fr.power.segs[1]._sbc[3] == 0.9, "energy wears the palette's")
prof().regular.bars.power.colorMode = "custom"; fire("UNIT_MAXPOWER")
assert(fr.power.segs[1]._sbc[1] ~= 0.1, "only while the bar wears its power's color")
prof().regular.bars.power.colorMode = "power"
PAL.power.ENERGY = { 1, 1, 0, 1 }; fire("UNIT_MAXPOWER")

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
-- the target frame the same way, on its own switch
assert(TargetFrame._parent == UIParent, "target frame untouched by default")
R0.hideTargetFrame = true; fire("UNIT_MAXPOWER")
assert(TargetFrame._parent == hider and PlayerFrame._parent == UIParent, "target frame hidden, player frame not")
S.combat = true; R0.hideTargetFrame = false; fire("UNIT_MAXPOWER")
assert(TargetFrame._parent == hider, "waits for combat to end")
S.combat = false; fire("PLAYER_REGEN_ENABLED")
assert(TargetFrame._parent == UIParent, "given back")
-- Blizzard's experience bar the same way (classic: MainMenuExpBar; modern holders aren't there)
R0.hideXPBar = true; fire("UNIT_MAXPOWER")
assert(MainMenuExpBar._parent == hider, "experience bar hidden")
R0.hideXPBar = false; fire("UNIT_MAXPOWER")
assert(MainMenuExpBar._parent == UIParent, "and given back")
-- the experience bar: like the power bar, your experience to the next level
S.XB = R0.bars.experience
S.XB.show = true; fire("UNIT_MAXPOWER") -- a setting changed: re-laid out
assert(fr.experience:IsShown() and fr.experience.segs[1]._value == 300 and fr.experience.segs[1]._max == 1000
    and fr.experience.texts.current._text == "300", "300 of 1000")
assert(fr.experience.segs[1]._sbc[1] == 0.58 and fr.experience.segs[1]._sbc[3] == 0.55, "the palette's purple")
S.xp = 450; fire("PLAYER_XP_UPDATE")
assert(fr.experience.segs[1]._value == 450, "follows experience")
S.XB.hideInCombat = true; fire("PLAYER_REGEN_DISABLED")
assert(not fr.experience:IsShown(), "hidden in combat")
fire("PLAYER_REGEN_ENABLED")
assert(fr.experience:IsShown(), "back after")
IsPlayerAtEffectiveMaxLevel = function() return true end; fire("UNIT_MAXPOWER")
assert(not fr.experience:IsShown(), "top level: nothing to gain")
S.XB.hideAtMax = false; fire("UNIT_MAXPOWER")
assert(fr.experience:IsShown() and fr.experience.segs[1]._value == 1, "kept at the top level: a full bar")
-- or the faction you watch, colored by standing; or honor; or experience, then the faction
C_Reputation = { GetWatchedFactionData = function() return S.faction2 end }
S.faction2 = { name = "Stormwind", reaction = 6, currentReactionThreshold = 3000, nextReactionThreshold = 9000,
    currentStanding = 4500 }
S.XB.source = "rep"; fire("UPDATE_FACTION")
assert(fr.experience.segs[1]._value == 1500 and fr.experience.segs[1]._max == 6000
    and fr.experience.segs[1]._sbc[2] == 0.8, "1500 into a 6000 standing, friendly green")
S.faction2 = nil; fire("UPDATE_FACTION")
assert(not fr.experience:IsShown(), "no faction watched: nothing")
S.faction2 = { name = "Stormwind", reaction = 6, currentReactionThreshold = 3000, nextReactionThreshold = 9000,
    currentStanding = 4500 }
S.XB.source = "auto"; fire("UPDATE_FACTION")
assert(fr.experience.segs[1]._max == 6000, "auto at the top level: the faction")
IsPlayerAtEffectiveMaxLevel = function() return false end; fire("UPDATE_FACTION")
assert(fr.experience.segs[1]._max == 1000, "auto below it: experience")
UnitHonor, UnitHonorMax = function() return 200 end, function() return 800 end
S.XB.source = "honor"; fire("HONOR_XP_UPDATE"); fire("UNIT_MAXPOWER")
assert(fr.experience.segs[1]._value == 200 and fr.experience.segs[1]._sbc[1] == 1 and fr.experience.segs[1]._sbc[2] == 0.4,
    "honor, in the palette's honor color")
UnitHonor, UnitHonorMax, C_Reputation, S.faction2 = nil, nil, nil, nil
S.XB.source, S.XB.hideAtMax = "xp", true
IsPlayerAtEffectiveMaxLevel, S.XB.show, S.XB.hideInCombat, S.xp = nil, false, false, nil
fire("UNIT_MAXPOWER")

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

-- Right-click menu: secure unit buttons over your health and power bars only, synced out of
-- combat, off while unlocked
assert(not (WolfpackAddonClicker and WolfpackAddonClicker:IsShown()), "no secure button shown unless asked (one may exist, hidden, for a pet to hang on)")
R0.playerMenu = true; fire("UNIT_MAXPOWER")
local ck, cp = WolfpackAddonClicker, WolfpackAddonClickerPower
assert(ck._template == "SecureUnitButtonTemplate" and ck._attr.unit == "player" and ck._attr.type2 == "togglemenu", "menu button")
assert(cp._attr.unit == "player" and cp._attr.type2 == "togglemenu", "one on the power bar too")
assert(ck._point[1] == "TOP" and ck._point[2] == UIParent and ck._point[3] == "CENTER" and ck._point[4] == R0.x
    and ck._point[5] == R0.y and ck._w == 220 and ck._h == 18 and ck:IsShown(), "exactly over your health bar")
assert(cp._point[4] == R0.x and cp._point[5] == R0.y - 20 and cp._w == 220 and cp._h == 14, "and over power, under it")
R0.grow = "up"; fire("UNIT_MAXPOWER")
assert(ck._point[5] == R0.y + WolfpackAddonFrame._h, "growing up: counted from the group's top all the same")
R0.grow = "down"
-- enemy health beside yours: the health button covers your half only, target or not
R0.bars.enemyhealth.show, R0.bars.enemyhealth.beside = true, true; fire("UNIT_MAXPOWER")
assert(ck._point[1] == "TOPLEFT" and ck._point[4] == R0.x - 110 and ck._w == (220 - R0.gap) / 2, "your half")
R0.bars.enemyhealth.show, R0.bars.enemyhealth.beside = false, false
-- a hidden bar takes its button with it
R0.bars.power.show = false; fire("UNIT_MAXPOWER")
assert(ck:IsShown() and not cp:IsShown(), "power hidden: no button there")
R0.bars.power.show = true
prof().locked = false; fire("UNIT_MAXPOWER")
assert(not ck:IsShown() and not cp:IsShown(), "unlocked: drag handle gets the mouse")
assert(ck._attr.type1 == nil, "left click off by default")
prof().locked, R0.playerTarget = true, true; fire("UNIT_MAXPOWER")
assert(ck:IsShown() and ck._attr.type1 == "target" and ck._attr.type2 == "togglemenu", "left targets, right menu")
assert(cp._attr.type1 == "target", "on power as well")
R0.playerMenu = false; fire("UNIT_MAXPOWER")
assert(ck:IsShown() and ck._attr.type1 == "target" and ck._attr.type2 == nil, "left click alone")
R0.playerTarget = false; fire("UNIT_MAXPOWER")
assert(not ck:IsShown() and not cp:IsShown(), "both off")
R0.playerMouseover = true; fire("UNIT_MAXPOWER")
assert(ck:IsShown() and ck._attr.unit == "player" and not ck._attr.type1 and not ck._attr.type2, "mouseover only: no clicks")
R0.playerMouseover = false; fire("UNIT_MAXPOWER")
-- enemy health: its own button, unit "target", right-click menu only, shown by the unit watch
local ct = WolfpackAddonClickerTarget
assert(ct and ct._attr.unit == "target" and ct._attr.type2 == "togglemenu" and not ct._attr.type1, "target menu button")
R0.bars.enemyhealth.show, R0.bars.enemyhealth.beside = true, true; fire("UNIT_MAXPOWER")
local half = (220 - R0.gap) / 2
assert(ct._watched and ct._point[1] == "TOPLEFT" and ct._point[4] == R0.x - 110 + half + R0.gap
    and ct._w == half and ct._h == 18, "beside: over the enemy half, watched for a target")
R0.targetMenu = false; fire("UNIT_MAXPOWER")
assert(not ct._watched and not ct:IsShown(), "option off: gone")
R0.targetMenu, R0.bars.enemyhealth.show, R0.bars.enemyhealth.beside = true, false, false; fire("UNIT_MAXPOWER")
assert(not ct._watched, "enemy health hidden: no button")
-- your pet and your target's target: a menu each, shown by the unit watch; hung on another bar,
-- theirs hangs on that bar's button
S.PB, S.TT = R0.bars.pethealth, R0.bars.tothealth
S.PB.show, S.PB.anchor, S.petHP = true, "left", 100; fire("UNIT_PET", "player")
S.cpet = WolfpackAddonClickerPet
assert(S.cpet and S.cpet._attr.unit == "pet" and S.cpet._attr.type2 == "togglemenu" and S.cpet._watched,
    "pet: a menu, while there is a pet")
assert(S.cpet._attr.type1 == "target", "left click targets your pet")
assert(S.cpet._point[1] == "TOPRIGHT" and S.cpet._point[2] == WolfpackAddonClicker and S.cpet._point[3] == "TOPLEFT"
    and S.cpet._point[4] == -R0.gap and S.cpet._w == S.PB.width and S.cpet._h == WolfpackAddonClicker._h,
    "left of your health's button, its height")
S.PB.anchor = "below"; fire("UNIT_PET", "player")
assert(S.cpet._point[1] == "TOPLEFT" and S.cpet._point[3] == "BOTTOMLEFT" and S.cpet._point[5] == -R0.gap
    and S.cpet._w == WolfpackAddonClicker._w and S.cpet._h == S.PB.height, "below it, its width")
R0.petMenu = false; fire("UNIT_PET", "player")
assert(not S.cpet._watched, "pet menu off")
R0.petMenu, S.PB.show, S.PB.anchor, S.petHP = true, false, "stack", nil
R0.bars.enemyhealth.show, S.TT.show, S.TT.anchor = true, true, "right"; fire("UNIT_MAXPOWER")
S.ctot = WolfpackAddonClickerToT
assert(S.ctot and S.ctot._attr.unit == "targettarget" and S.ctot._attr.type1 == "target" and S.ctot._watched and S.ctot._point[2] == WolfpackAddonClickerTarget
    and S.ctot._point[3] == "TOPRIGHT" and S.ctot._point[4] == R0.gap, "target of target: right of enemy health's button")
S.TT.anchor = "below"; fire("UNIT_MAXPOWER")
assert(S.ctot._point[1] == "BOTTOMLEFT" and S.ctot._point[3] == "BOTTOMLEFT" and S.ctot._h == S.TT.height
    and S.ctot:GetFrameLevel() > WolfpackAddonClickerTarget:GetFrameLevel(), "below: the bottom of enemy health's slot, over its button")
S.TT.show, S.TT.anchor, R0.bars.enemyhealth.show = false, "right", false; fire("UNIT_MAXPOWER")

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
-- Anniversary and Classic Era: no C_QuestLog list, the old global calls instead
S.newLog = C_QuestLog
C_QuestLog = { UnitIsRelatedToActiveQuest = S.newLog.UnitIsRelatedToActiveQuest }
GetNumQuestLogEntries = function() return 2 end
GetQuestLogTitle = function(i)
    if i == 1 then return "The Barrens", 0, nil, true end
    return "Boars", 12, nil, false, false, nil, 0, 7
end
GetNumQuestLeaderBoards = function(i) return i == 2 and 2 or 0 end
GetQuestLogLeaderBoard = function(j)
    if j == 1 then return "Boar Flank: 3/6", "item", false end
    return "Boar slain: 3/10", "monster", false
end
fire("QUEST_LOG_UPDATE")
assert(h.loot:IsShown() and h.badge.loot.text._text == 3, "item objective read from the old calls: 3 left")
C_QuestLog, GetNumQuestLogEntries, GetQuestLogTitle = S.newLog, nil, nil
GetNumQuestLeaderBoards, GetQuestLogLeaderBoard = nil, nil
fire("QUEST_LOG_UPDATE")
assert(h.badge.loot.text._text == 4, "back on the modern list")
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
-- the very first opening counts as open too (a new frame is shown already, so no OnShow fires):
-- that is what puts the dummy buffs and debuffs up for tuning
assert(ns.configOpen, "options open from the first click")
assert(fr.health.auraIcons.buffs[8]:IsShown() and fr.health.auraIcons.debuffs[16]:IsShown(),
    "dummy buffs and debuffs on your health bar while the options are open")
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
for _, name in ipairs({ "Combat Display", "Nameplates", "Buff check", "Other",
    "Hunter", "Mage", "Rogue", "Shaman", "Warlock" }) do
    local b = byText(name)
    assert(b, "sidebar entry missing: " .. name)
    b._scripts.OnClick(b, "LeftButton")
end
-- The window is 680 wide and scrolls; each page's columns 3 and 4 sit under columns 1 and 2
assert(ns.cfg._w == 680, "a third narrower than the old 998")
local function regionWithText(page, text)
    for _, r in ipairs({ page:GetRegions() }) do if r._text == text then return r end end
end
local colors, bars = regionWithText(ns.pages.combat, "Colors"), regionWithText(ns.pages.combat, "Bars, top to bottom")
assert(bars._point[2] == 28 and bars._point[3] == -112, "column 1 stays")
assert(colors._point[1] == "TOPLEFT" and colors._point[2] == ns.pages.combat and colors._point[4] == 28
    and colors._point[5] < -400, "column 3 moved under column 1")
assert(regionWithText(ns.pages.combat, "Gradient")._point[4] == 238, "column 4 under column 2")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
assert(ns.pages.combat.need > 1000 and ns.content._h == ns.pages.combat.need - 90 + 16,
    "the scroll area is as tall as the page")
-- Profiles has its own page; the header names the profile in use and opens that page
assert(byText("Export") and byText("Import") and byText("Reset to defaults") and byText("Create"), "profile page")
local inUse
for _, f in ipairs(created) do
    if type(f._text) == "string" and f._text:find("^Profile: ") then inUse = f end
end
assert(inUse and inUse._text:find(WolfpackAddonDB.chars[S.name .. " - Realm"], 1, true), "header names the profile")
inUse._scripts.OnClick(inUse, "LeftButton")
assert(ns.pages.profile:IsShown() and not ns.pages.combat:IsShown(), "header opens the Profiles page")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
-- Reset asks first; No leaves the profile alone (on a scratch profile, the real one stays as is)
local home = WolfpackAddonDB.chars[S.name .. " - Realm"]
ns.useProfile("Scratch")
local asked, realShow = nil, StaticPopup_Show
StaticPopup_Show = function(which, a) asked = { which, a } end
prof().regular.bars.health.width = 333
byText("Reset to defaults")._scripts.OnClick(byText("Reset to defaults"), "LeftButton")
assert(asked[1] == "WOLFPACKADDON_RESET" and prof().regular.bars.health.width == 333, "reset waits for Yes")
StaticPopupDialogs.WOLFPACKADDON_RESET.OnAccept()
assert(prof().regular.bars.health.width ~= 333, "Yes resets")
StaticPopup_Show = realShow
-- an older profile's text size and color become the "current" number's, once
WolfpackAddonDB.profiles.OldText = { regular = { bars = { health = { fontSize = 13, textColor = { 0, 1, 0, 1 } } } } }
ns.useProfile("OldText")
local hc = prof().regular.bars.health
assert(hc.texts.current.size == 13 and hc.texts.current.color[2] == 1 and hc.textsSet, "moved onto current")
hc.texts.current.size = 9; ns.useProfile("OldText")
assert(hc.texts.current.size == 9, "only once")
ns.useProfile("Scratch")
WolfpackAddonDB.profiles.OldText = nil
-- colors that lived on single bars move into the palette, once; class borders follow the bar
WolfpackAddonDB.profiles.OldColors = { regular = { bars = {
    power = { powerColors = { ENERGY = { 0.5, 0.5, 0.5, 1 } } },
    targetcast = { harmColor = { 0.7, 0, 0, 1 }, healColor = { 0, 0.7, 0, 1 } },
    health = { borderMode = "class" } } } }
ns.useProfile("OldColors")
assert(prof().colors.power.ENERGY[1] == 0.5 and prof().colors.cast.harm[1] == 0.7
    and prof().colors.cast.heal[2] == 0.7 and prof().colors.moved, "moved into the palette")
assert(prof().regular.bars.power.powerColors == nil and prof().regular.bars.targetcast.harmColor == nil
    and prof().regular.bars.health.borderMode == "bar", "gone from the bars; a class border follows the bar")
ns.useProfile("Scratch")
WolfpackAddonDB.profiles.OldColors = nil
-- Copy from: another profile's settings (and Bar Stack's) land on the current one, name kept
local here = WolfpackAddonDB.chars[S.name .. " - Realm"]
WolfpackAddonDB.profiles.Source = { regular = { bars = { health = { width = 321 } } } }
local bsFrom
ns.bs = { CopyFrom = function(n) bsFrom = n end }
ns.copyFromMenu:GenerateMenu()
local pick
for _, it in ipairs(ns.copyFromMenu._items) do
    assert(it.text ~= here, "the current profile is not offered")
    if it.text == "Source" then pick = it end
end
pick.set()
assert(WolfpackAddonDB.chars[S.name .. " - Realm"] == here and prof().regular.bars.health.width == 321,
    "copied onto the current profile")
assert(prof() ~= WolfpackAddonDB.profiles.Source, "a copy, not the same table")
assert(bsFrom == "Source", "Bar Stack's sets come along")
ns.bs, WolfpackAddonDB.profiles.Source = nil, nil
ns.useProfile(home)
WolfpackAddonDB.profiles.Scratch = nil
-- the swing timer draws in its rows, so it is "(hidden)" only when no row is up
prof().locked = false
byText("Swing Timer")._scripts.OnClick(byText("Swing Timer"), "LeftButton")
assert(ns.swingFrames.regular[1]:IsShown() and regionWithText(ns.pages.combat, "Swing Timer"),
    "rows up while placing: not called hidden")
prof().regular.bars.swing.main = false; fire("UNIT_MAXPOWER")
byText("Swing Timer")._scripts.OnClick(byText("Swing Timer"), "LeftButton")
assert(regionWithText(ns.pages.combat, "Swing Timer |cff888888(hidden)|r"), "no row ticked: hidden")
prof().regular.bars.swing.main, prof().locked = true, true
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
-- Bar Stack is a page of this window, not a window of its own
ns.bs = { ShowConfig = function(page) S.bsPage = page end }
byText("Bar Stack")._scripts.OnClick(byText("Bar Stack"), "LeftButton")
assert(S.bsPage and S.bsPage:IsShown(), "the Bar Stack entry shows its page and builds the editor on it")
ns.ShowBarStack()
assert(not ns.cfg:IsShown(), "/bs on the Bar Stack page closes the window")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
ns.ShowBarStack()
assert(ns.cfg:IsShown() and S.bsPage:IsShown(), "/bs opens it on Bar Stack")
ns.bs = nil
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
for _, f in ipairs(created) do if f._gen and f ~= ns.copyFromMenu and f ~= ns.sitsMenu and f ~= ns.xpMenu and f ~= ns.borderFromMenu and f ~= ns.sharedRadiusMenu and f ~= ns.textureFromMenu and f ~= ns.sharedTextureMenu and not (f._parent == ns.pages.actionbars) then dds[#dds + 1] = f end end
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
byText("Delete profile")._scripts.OnClick(byText("Delete profile"), "LeftButton")
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

-- The options window sizes itself to its tallest column -- now the sidebar, with three shelves
-- on it. It clamps to the screen, so this only guards against it growing without anyone noticing.
assert(ns.configHeight > 400 and ns.configHeight < 840, "window height " .. ns.configHeight)

-- Other: gryphons hidden via texture alpha only, untouched until the option is used
local caps = MainActionBar.EndCaps
assert(caps.LeftEndCap.Texture._alpha == nil, "gryphons untouched by default")
byText("Other")._scripts.OnClick(byText("Other"), "LeftButton")
prof().other.hideGryphons = true; fire("UNIT_MAXPOWER")
assert(caps.LeftEndCap.Texture._alpha == 0 and caps.RightEndCap.Texture._alpha == 0, "hidden")
prof().other.hideGryphons = false; fire("UNIT_MAXPOWER")
assert(caps.LeftEndCap.Texture._alpha == 1, "shown again")
local opBox = boxes[19] -- highlight opacity (%), after the party/raid one
opBox._text = "60"; opBox._scripts.OnEnterPressed(opBox)
assert(math.abs(prof().regular.highlight.color[4] - 0.6) < 1e-9 and opBox._text == "60", "opacity typed")
-- Enemy health's resource settings open in a window beside the options, only for that bar
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
local rb = byText("Resource settings")
byText("Enemy Health")._scripts.OnClick(byText("Enemy Health"), "LeftButton")
assert(rb:IsShown() and not ns.resDialog:IsShown(), "a button for it, closed")
rb._scripts.OnClick(rb, "LeftButton")
assert(ns.resDialog:IsShown() and ns.resDialog._point[2] == ns.cfg, "opens beside the window")
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
local tb = byText("Level and name")
byText("Enemy Health")._scripts.OnClick(byText("Enemy Health"), "LeftButton")
tb._scripts.OnClick(tb, "LeftButton")
assert(ns.tagDialog:IsShown() and not ns.resDialog:IsShown(), "level and name: its own window, one at a time")
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
assert(not rb:IsShown() and not ns.resDialog:IsShown(), "another bar picked: closed")
assert(not tb:IsShown() and not ns.tagDialog:IsShown(), "and that one too")
local pb2 = byText("PvP flag")
byText("Enemy Health")._scripts.OnClick(byText("Enemy Health"), "LeftButton")
pb2._scripts.OnClick(pb2, "LeftButton")
assert(ns.iconDialog:IsShown(), "PvP flag: a window of its own")
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
assert(not pb2:IsShown() and not ns.iconDialog:IsShown(), "closed with the bar")
-- the Colors page: the palette, in the sidebar
byText("Colors & borders")._scripts.OnClick(byText("Colors & borders"), "LeftButton")
assert(ns.pages.colors:IsShown() and ns.swatches["Mana"]:IsShown() and ns.swatches["Warrior"]
    and ns.swatches["Channeling"] and ns.swatches["Hostile"], "class, power, cast and standing colors")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
byText("Target of Target")._scripts.OnClick(byText("Target of Target"), "LeftButton")
assert(byText("Level and name"):IsShown(), "target of target: level and name window")
S.totNameCheck = nil
for _, f in ipairs(created) do
    if rawget(f, "Text") and f.Text._text == "Show name" and f._parent == ns.pages.combat then S.totNameCheck = f end
end
assert(S.totNameCheck and S.totNameCheck:IsShown(), "and Show name right there")
S.totNameCheck._checked = false; S.totNameCheck._scripts.OnClick(S.totNameCheck)
assert(prof().regular.bars.tothealth.tagName == false, "ticked off: name hidden")
prof().regular.bars.tothealth.tagName = true
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
assert(not S.totNameCheck:IsShown(), "only for target of target")
local sb = byText("Status and PvP icons")
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
sb._scripts.OnClick(sb, "LeftButton")
assert(sb:IsShown() and ns.statusDialog:IsShown(), "your health: status and PvP icons window")
byText("Power")._scripts.OnClick(byText("Power"), "LeftButton")
assert(not sb:IsShown() and not ns.statusDialog:IsShown(), "only for your health")
assert(not byText("In-combat icon"), "the old combat icon card is gone")
-- Health, power and enemy health: a Numbers window instead of the one size and color
local nb = byText("Numbers")
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
assert(nb:IsShown() and not ns.swatches["Text color"]:IsShown(), "numbers button, no single text color")
nb._scripts.OnClick(nb, "LeftButton")
assert(ns.textDialog:IsShown(), "opens")
byText("Cast Bar")._scripts.OnClick(byText("Cast Bar"), "LeftButton")
assert(not nb:IsShown() and not ns.textDialog:IsShown() and ns.swatches["Text color"]:IsShown(),
    "cast bar: one text, as before")
local ab = byText("Buffs and debuffs")
byText("Enemy Health")._scripts.OnClick(byText("Enemy Health"), "LeftButton")
tb._scripts.OnClick(tb, "LeftButton")
ab._scripts.OnClick(ab, "LeftButton")
assert(ns.auraDialog:IsShown() and not ns.tagDialog:IsShown(), "buffs and debuffs: its own window too")
byText("Debuffs")._scripts.OnClick(byText("Debuffs"), "LeftButton")
assert(byText("Debuffs").locked and not byText("Buffs").locked, "a tab each: debuffs now")
byText("Buffs")._scripts.OnClick(byText("Buffs"), "LeftButton")
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
assert(ab:IsShown() and ns.auraDialog:IsShown(), "your health has them too: the window stays, now for it")
byText("Power")._scripts.OnClick(byText("Power"), "LeftButton")
assert(not ab:IsShown() and not ns.auraDialog:IsShown(), "closed with a bar that has none")
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
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
-- Anniversary and Classic Era have neither the area-trigger nor the auto-accept call
S.trig, S.auto = QuestIsFromAreaTrigger, QuestGetAutoAccept
QuestIsFromAreaTrigger, QuestGetAutoAccept = nil, nil
fire("QUEST_DETAIL", 0)
assert(calls() == "accept", "accepted all the same")
QuestIsFromAreaTrigger, QuestGetAutoAccept = S.trig, S.auto
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
-- the old flat gossip lists (Anniversary, Classic Era): 6 values per active quest, 7 per new one
S.gossipInfo = C_GossipInfo
C_GossipInfo = nil
GetGossipActiveQuests = function() return "Boars", 12, false, false, false, false, "Wolves", 14, false, true, false, false end
GetGossipAvailableQuests = function() return "Raptors", 15, false, 0, false, false, false end
SelectGossipActiveQuest = function(i) S.calls[#S.calls + 1] = "oldTurnin" .. i end
SelectGossipAvailableQuest = function(i) S.calls[#S.calls + 1] = "oldTake" .. i end
S.greetNew, S.greeting = 0, {}
S.npc = "npc-old"
fire("GOSSIP_SHOW"); fire("GOSSIP_SHOW"); fire("GOSSIP_SHOW")
assert(calls() == "oldTurnin2,oldTake1", "the finished one (Wolves, 2nd) handed in, then the new one taken, once each")
C_GossipInfo, GetGossipActiveQuests, GetGossipAvailableQuests = S.gossipInfo, nil, nil
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
-- Blizzard's bar is only ever touched while the fade is actually moving: touching a settled
-- one taints it, and then its own cooldowns cannot be drawn
S.mouseOver = true
tick(nil, 5) -- all the way in, and staying there
local settled = MainActionBar._alphaSets
for _ = 1, 10 do tick(nil, 0.1) end
assert(MainActionBar._alphaSets == settled, "a bar that is not moving is left alone")
S.mouseOver = false
tick(nil, 0.1)
assert(MainActionBar._alphaSets > settled, "and is touched again the moment it does move")
tick(nil, 5) -- all the way out
local hidden = MainActionBar._alphaSets
for _ = 1, 10 do tick(nil, 0.1) end
assert(MainActionBar._alphaSets == hidden, "the same once it has faded all the way out")
S.mouseOver = true; tick(nil, 5)
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
assert(sw.Rage and sw.Energy and sw.Mana and sw.Focus, "a swatch per power, on the Colors page")
hcol.colorMode, hcol.borderMode = "class", "bar"
sw["Custom border color"]._scripts.OnClick()
assert(S.picker.r == 1 and math.abs(S.picker.b - 0.5575) < 1e-6, "border picker opens on the border as drawn")
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
-- Bar Stack has no string of its own: its profile rides in this one and comes back on import
local bsGot
ns.bs = { profile = { groups = { { name = "Mine" } } }, ImportProfile = function(p) bsGot = p; return true end }
local withBS = ns.exportString()
ns.bs.profile = nil
ns.importString(withBS)
assert(bsGot and bsGot.groups[1].name == "Mine", "importing hands Bar Stack its profile back")
ns.bs = nil
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
assert(bp.regular.order[1] == "health" and bp.regular.order[2] == "castbar" and #bp.regular.order == 14, "order repaired")
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
prof().colors.borderShade = 25 -- poked to 42 above, like every slider
for _, m in ipairs({ "regular", "nameplate" }) do
    local seen = {}
    for _, k in ipairs(prof()[m].order) do seen[k] = true end
    assert(seen.health and seen.power and seen.combo and seen.druidmana and seen.castbar and seen.pethealth
        and seen.swing and seen.totems and seen.absorb and seen.flight and seen.targetcast
        and seen.enemyhealth and #prof()[m].order == 14, "order intact")
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
-- "Same as bar color": each segment's border a lighter shade of its own element's color
assert(tc.borderMode == "bar", "the default border follows the bar")
assert(tb.segs[1].border._color[2] == 1 and tb.segs[1].border._color[1] == 0.25
    and tb.segs[2].border._color[1] == 1 and tb.segs[2].border._color[2] == 0.475, "green and red edges")
tc.slots = { 1, 2, 3, 4 }
login("ROGUE", 3)
fire("UNIT_MAXPOWER")
assert(not ns.frames.totems:IsShown(), "not a shaman: never shows")

-- the options window closes here (the mock fires no OnHide, so say what it would)
ns.cfg:Hide(); ns.configOpen = false
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
assert(not spin:IsShown(), "window over: regen is back (a secret mana number: can't tell it refills)")
-- regenerating: once the window is over and mana isn't full, a full ring breathes in its own color
S.secret = false; fire("UNIT_POWER_FREQUENT", "player")
-- on a frame of its own: the game hides a finished cooldown frame by itself (seen in game)
S.sp = ns.fsr.spin
assert(S.sp:IsShown() and not spin:IsShown() and ns.fsr.arc._tex:find("Arc20") and S.sp._parent == ns.frames.power
    and S.sp._w == 30, "mana 3 of 100: regenerating, a fifth of the ring turning, where the spinner sits")
assert(ns.fsr.arc._vertex and ns.fsr.arc._vertex[2] == 1, "in the regenerating color")
S.sp._scripts.OnUpdate(S.sp, 0.1)
S.realUP = UnitPower
UnitPower = function() return 100 end -- full, and no event about it
S.sp._scripts.OnUpdate(S.sp, 1)
assert(not S.sp:IsShown(), "it looks by itself: full, gone")
UnitPower = S.realUP; ns.fsr:sync()
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast8", 133)
assert(spin:IsShown() and spin._cd[2] == 7 and spin._swipe[1] == 1 and not S.sp:IsShown(),
    "spending mana: the window's sweep again")
S.time = 3030; FS.regen = false; ns.fsr:sync()
assert(not spin:IsShown() and not ns.fsr.spin:IsShown(), "regen ring off")
FS.regen, S.secret = true, true
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

-- The target's cast bar: shown while they cast, colored by what kind of cast it is
assert(ns.castKind("Shadow Bolt", false) == "harm", "a nasty one")
assert(ns.castKind("Greater Heal", false) == "heal", "a mending one")
assert(ns.castKind("greater heal", false) == "heal", "whatever its capitals")
assert(ns.castKind("Greater Heal", true) == "locked", "one you cannot stop beats both")
assert(ns.castKind(nil, false) == "harm", "and nothing known is treated as harm")
prof().regular.bars.targetcast.show = true
S.targetCast, S.targetLocked = nil, false
fire("UNIT_MAXPOWER")
assert(not ns.frames.targetcast:IsShown(), "nothing cast, no bar")
S.targetCast = "Shadow Bolt"
fire("UNIT_SPELLCAST_START", "target")
assert(ns.targetCasting, "the event said they started, which is what the bar goes by")
assert(ns.frames.targetcast:IsShown(), "they started casting, so the bar joined the stack")
-- it sits in the stack with the rest, not floating over them
S.above = ns.frames.castbar
assert(ns.frames.targetcast._points and ns.frames.targetcast._points[1], "it is placed at all")
assert(ns.frames.targetcast._points[1][2] == ns.frames.health._points[1][2],
    "against the same anchor as every other bar")
assert(ns.frames.targetcast.text._text == "Shadow Bolt", "wearing the spell's name")
assert(ns.frames.targetcast.icon._tex == 136116, "and its icon")
assert(ns.frames.targetcast.castKind == "harm", "a damaging cast")
assert(ns.frames.targetcast.segs[1]._timer
    and ns.frames.targetcast.segs[1]._timer == "targetCastDuration",
    "the game's own duration drains it, rather than it sitting there full")
assert(ns.frames.targetcast.segs[1]._sbc[1] > 0.5 and ns.frames.targetcast.segs[1]._sbc[2] < 0.5,
    "drawn in the damage color")
S.targetCast = "Greater Heal"
fire("UNIT_SPELLCAST_START", "target")
assert(ns.frames.targetcast.castKind == "heal", "a heal, which is the one to stop")
assert(ns.frames.targetcast.segs[1]._sbc[2] > 0.5, "drawn in the healing color")
S.hb = ns.frames.targetcast.segs[1].border._color -- a lighter heal green: 0.2, 0.9, 0.3 lifted
assert(math.abs(S.hb[1] - 0.4) < 1e-9 and math.abs(S.hb[2] - 0.925) < 1e-9, "its border follows the kind")
S.targetLocked = true
fire("UNIT_SPELLCAST_START", "target")
assert(ns.frames.targetcast.castKind == "locked", "one the game says you cannot stop")
-- Auto color is a choice: any other mode keeps the bar its one color whatever is cast
local tcc = prof().regular.bars.targetcast
assert(tcc.colorMode == "auto" and tcc.autoSet, "auto by default")
tcc.colorMode, tcc.color = "custom", { 0.1, 0.2, 0.9, 1 }
fire("UNIT_SPELLCAST_START", "target")
assert(ns.frames.targetcast.segs[1]._sbc[3] == 0.9 and ns.frames.targetcast.segs[1]._sbc[1] == 0.1,
    "custom: its own color, not the grey for a cast you cannot stop")
fire("PLAYER_LOGIN")
assert(tcc.colorMode == "custom", "a picked mode sticks across logins")
-- a profile from before the choice existed (always colored by kind) is moved onto auto, once
tcc.autoSet = false
fire("PLAYER_LOGIN")
assert(tcc.colorMode == "auto" and tcc.autoSet, "older profile: auto, as it always looked")
tcc.color = { 0.8, 0.3, 0.3, 1 }
S.targetCast, S.targetLocked = nil, false
S.targetChannel = "Drain Life"
fire("UNIT_SPELLCAST_CHANNEL_START", "target")
assert(ns.frames.targetcast:IsShown() and ns.frames.targetcast.text._text == "Drain Life",
    "a channel shows the same way")
assert(ns.frames.targetcast.segs[1]._timer == "targetChannelDuration",
    "drained by the channel's own duration, not the cast's")
-- and a cast nobody will time reads empty rather than full
S.targetChannel, S.targetCast = nil, "Mystery"
fire("UNIT_SPELLCAST_START", "target")
S.keptDur, UnitCastingDuration = UnitCastingDuration, function() return nil end
ns.fill(ns.frames.targetcast)
assert(ns.frames.targetcast.segs[1]._value == 0, "no duration, an empty bar rather than a full one")
UnitCastingDuration = S.keptDur
S.targetCast = nil
S.targetChannel = nil
fire("UNIT_SPELLCAST_CHANNEL_STOP", "target")
assert(not ns.frames.targetcast:IsShown(), "and goes when they stop")
-- somebody else's cast is not your target's, and a new target starts quiet
S.targetCast = "Shadow Bolt"
fire("UNIT_SPELLCAST_START", "target")
assert(ns.frames.targetcast:IsShown(), "your target is casting again")
fire("UNIT_SPELLCAST_START", "party1")
assert(ns.targetCasting, "a party member's cast changes nothing either way")
fire("PLAYER_TARGET_CHANGED")
assert(not ns.targetCasting and not ns.frames.targetcast:IsShown(),
    "and a new target is quiet until it says otherwise")
S.targetCast = nil
SlashCmdList.WOLFPACKADDON("cast")
assert(not ns.errored, "the cast probe runs clean")
-- on this client the name and the cannot-be-stopped flag can both be secret: held, never read
S.secretLocked = setmetatable({}, { __eq = function() error("secret compared") end,
    __lt = function() error("secret compared") end })
S.secretName = setmetatable({}, { __index = function() error("secret read") end })
S.secrets = { [S.secretLocked] = true, [S.secretName] = true }
-- a secret may not be compared, truth-tested, or checked against nil: the real client raises
-- on every one of those, so the mock does too and the fill must survive it
S.strictSecret = setmetatable({}, {
    __eq = function() error("a secret was compared") end,
    __lt = function() error("a secret was compared") end,
    __index = function() error("a secret was read") end,
    __call = function() error("a secret was called") end,
})
issecretvalue = function(v) return (S.secrets or {})[v] == true end
assert(ns.castKind("Greater Heal", S.secretLocked) == "heal",
    "a secret flag decides nothing, and the name still can")
assert(ns.castKind(S.secretName, false) == "harm", "a secret name decides nothing either")
S.targetCast, S.targetLocked = "Shadow Bolt", S.secretLocked
fire("UNIT_SPELLCAST_START", "target")
assert(not ns.errored, "and the bar is drawn without any of it being compared")
-- the same with a flag that raises on any look at all, which is what the client really does
S.secrets[S.strictSecret] = true
S.targetLocked = S.strictSecret
ns.fill(ns.frames.targetcast)
assert(not ns.errored, "a flag that bites back is held, never looked at")
assert(ns.frames.targetcast.castKind == "harm", "so it decides nothing")
assert(ns.frames.targetcast:IsShown(), "it is still shown")
S.targetLocked, S.secrets = false, nil
issecretvalue = nil
prof().regular.bars.targetcast.show = false
fire("UNIT_MAXPOWER")
-- a profile saved before this bar existed still gets it, at the end of the order
S.oldOrder = { "health", "power", "combo", "druidmana", "castbar", "pethealth", "swing",
    "totems", "absorb" }
WolfpackAddonDB.profiles.OldOne = { regular = { order = S.oldOrder } }
fire("PLAYER_LOGIN")
S.repaired = WolfpackAddonDB.profiles.OldOne.regular.order
S.found = false
for _, k in ipairs(S.repaired) do if k == "targetcast" then S.found = true end end
assert(S.found, "an older profile is given the new bar rather than never seeing it")
WolfpackAddonDB.profiles.OldOne = nil

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
-- a client with no prediction calculator falls back to the plain call rather than drawing zero
S.keptCalc, S.keptDetail = CreateUnitHealPredictionCalculator, UnitGetDetailedHealPrediction
UnitGetDetailedHealPrediction = nil
UnitGetIncomingHeals = function() return S.plainHeal or 0 end
S.plainHeal = 175
fire("UNIT_HEAL_PREDICTION", "player")
assert(hb.over._value == 175, "the plain call carries it: " .. tostring(hb.over._value))
assert(hb.over._max == UnitHealthMax("player"), "scaled against your health")
-- and a client with neither draws nothing rather than erroring
UnitGetIncomingHeals = nil
fire("UNIT_HEAL_PREDICTION", "player")
assert(hb.over._value == 0 and not ns.errored, "neither call, no heals, no error")
UnitGetDetailedHealPrediction, S.plainHeal = S.keptDetail, nil
SlashCmdList.WOLFPACKADDON("heal")
assert(not ns.errored, "the heal probe runs clean")
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

-- Flight timer: nobody will say how long a ride takes, so the first one is timed and the next
-- counts down
S.taxiNodes = { [7] = "Menethil Harbor" }
S.subZone, S.onTaxi = "Ironforge", false
WolfpackAddonDB.flights = {}
ns.ft.taking(7) -- clicking the flight point is where both ends of the route are known
assert(ns.ft.key() == "Ironforge > Menethil Harbor", "the route: " .. tostring(ns.ft.key()))
-- a click the game tells us nothing about must not wipe a route we did catch
ns.ft.taking(99)
assert(ns.ft.key() == "Ironforge > Menethil Harbor", "an unknown slot leaves the route alone")
SlashCmdList.WOLFPACKADDON("flight")
assert(not ns.errored, "the flight probe runs clean")
assert(ns.ft.known() == nil, "never flown, so nothing is known about it")
S.time, S.onTaxi = 1000, true
ns.ft.tick()
assert(ns.ft.startedAt == 1000, "the ride is being timed")
S.time = 1042
assert(select(1, ns.ft.progress()) == nil, "no total for a route never flown")
assert(math.abs(select(2, ns.ft.progress()) - 42) < 0.01, "but the time so far is counted")
-- and if the route was never caught the bar says so, rather than looking like a first flight
prof().regular.bars.flight.show = true
fire("UNIT_MAXPOWER")
ns.fill(ns.frames.flight)
assert(ns.frames.flight.text._text == "0:42 so far", "a caught route counts up quietly")
ns.ft.route = nil
ns.fill(ns.frames.flight)
assert(ns.frames.flight.text._text:find("not caught"), "a missed one says so: "
    .. ns.frames.flight.text._text)
ns.ft.route = { from = "Ironforge", to = "Menethil Harbor" }
prof().regular.bars.flight.show = false
S.onTaxi = false
ns.ft.tick()
assert(WolfpackAddonDB.flights["Ironforge > Menethil Harbor"] == 42, "and written down on landing")
-- the next ride down the same route counts down from what was learned
ns.ft.taking(7)
S.time, S.onTaxi = 2000, true
ns.ft.tick()
S.time = 2010
assert(select(1, ns.ft.progress()) == 42, "the ride is 42 seconds")
assert(math.abs(select(2, ns.ft.progress()) - 10) < 0.01, "and you are 10 seconds into it")
-- and the bar says so, once it is switched on
prof().regular.bars.flight.show = true
fire("UNIT_MAXPOWER")
assert(ns.frames.flight:IsShown(), "the bar joins the stack while you are flying")
ns.fill(ns.frames.flight)
assert(ns.frames.flight.segs[1]._max == 42, "the bar is as long as the ride")
assert(math.abs(ns.frames.flight.segs[1]._value - 32) < 0.01, "and drains with it")
assert(ns.frames.flight.text._text == "0:32", "the clock reads what is left")
S.onTaxi = false
ns.ft.tick()
-- every completed ride re-learns the route, so a changed flight path corrects itself
assert(WolfpackAddonDB.flights["Ironforge > Menethil Harbor"] == 10, "the latest ride is the one kept")
-- a hop of a few seconds is somebody dismounting, not a route worth remembering
ns.ft.taking(7)
S.time, S.onTaxi = 3000, true
ns.ft.tick()
S.time, S.onTaxi = 3003, false
ns.ft.tick()
assert(WolfpackAddonDB.flights["Ironforge > Menethil Harbor"] == 10,
    "a three second hop does not overwrite what was learned")
S.onTaxi, WolfpackAddonDB.flights = false, {}
fire("UNIT_MAXPOWER")
assert(not ns.frames.flight:IsShown(), "and leaves it again once you are down")
prof().regular.bars.flight.show = false

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
-- a raid frame shows its overlay only while the cursor is on it, and is set up only once
(function()
    local plate = new()
    plate._name = "NamePlate1UnitFrame"
    CompactUnitFrame_SetUpFrame(plate)
    assert(not ns.raidHover[plate], "nameplates get no hover overlay")
    local rf = new()
    rf._name = "CompactRaidFrame1"
    CompactUnitFrame_SetUpFrame(rf)
    CompactUnitFrame_SetUpFrame(rf)
    local ov = ns.raidHover[rf]
    assert(ov and not ov:IsShown(), "raid frame overlay starts hidden")
    prof().other.raidHover.show = true -- earlier checks click every box on the page
    rf._scripts.OnEnter(); assert(ov:IsShown(), "overlay shows on hover")
    rf._scripts.OnLeave(); assert(not ov:IsShown(), "and hides on leave")
    prof().other.raidHover.show = false
    rf._scripts.OnEnter(); assert(not ov:IsShown(), "switched off, hovering shows nothing")
end)()
SlashCmdList.WOLFPACKADDON("crit")
SlashCmdList.WOLFPACKADDON("auras") -- the probe must not error, whatever the client has
SlashCmdList.WOLFPACKADDON("")
-- Action bars: a pool of 120 slots, each bar a fixed run of them; secure buttons built and laid
-- out out of combat; keybinds as override bindings, set by hovering in keybind mode
S.combat = false
S.A = prof().actionbars
;(function() for k, v in pairs(ns.AB_BAR) do S.A.bars[1][k] = type(v) == "table" and { unpack(v) } or v end end)() -- poked above
assert(#S.A.bars == 1 and S.A.bars[1].first == 1 and S.A.bars[1].cols == 12, "one bar to start: slots 1-12")
fire("UNIT_MAXPOWER")
S.ab = ns.ab.buttons[1]
assert(#S.ab == 12 and S.ab[1]._template == "ActionBarButtonTemplate" and S.ab[1]._attr.action == 1
    and S.ab[12]._attr.action == 12, "twelve buttons on slots 1-12")
assert(S.ab[2]._point[1] == "TOPLEFT" and S.ab[2]._point[4] == 40 and ns.ab.frames[1]._point[1] == "BOTTOM",
    "right then down, 36 + 4 apart, at the screen's bottom")
S.A.bars[1].grow, S.A.bars[1].cols, S.A.bars[1].rows = "leftup", 6, 2; fire("UNIT_MAXPOWER")
assert(S.ab[7]._point[1] == "BOTTOMRIGHT" and S.ab[7]._point[4] == 0 and S.ab[7]._point[5] == 40
    and S.ab[2]._point[4] == -40, "left, then up: the seventh starts a row above")
S.A.bars[1].radius, S.A.bars[1].zoom, S.A.bars[1].borderSize = 25, 15, 2; fire("UNIT_MAXPOWER")
assert(S.ab[1].wpIcon._coords[1] == 0.15 and S.ab[1].wpIcon._masks[S.ab[1].wpMask] and S.ab[1].wpEdge:IsShown()
    and S.ab[1].wpIcon._points[1][4] == 2, "zoomed, rounded, a 2 px border")
-- a second bar takes the next free slots; the first can't grow into them
S.i2 = ns.abNew()
assert(S.i2 == 2 and S.A.bars[2].first == 13 and ns.abCount(2) == 12, "bar 2: slots 13-24")
S.A.bars[1].rows = 3; fire("UNIT_MAXPOWER")
assert(ns.abCount(1) == 12 and not (S.ab[13] and S.ab[13]:IsShown()), "bar 1 stops where bar 2 starts")
assert(ns.ab.buttons[2][1]._attr.action == 13 and ns.abUsed() == 24, "24 of 120 in use")
-- keybind mode: hover a button, press a key; Escape on it unbinds; a key moves, it's never on two
ns.abBindMode(true)
S.ab[3]._scripts.OnEnter(S.ab[3])
S.shift = true; ns.abKey("LSHIFT"); ns.abKey("3"); S.shift = false
assert(S.A.binds["3"] == "SHIFT-3" and S.binds["SHIFT-3"] == "WolfpackActionBar1Button3"
    and S.ab[3].wpKey._text == "S3", "shift-3 on slot 3, shown short")
S.ab[3]._scripts.OnLeave(S.ab[3]); ns.ab.buttons[2][1]._scripts.OnEnter(ns.ab.buttons[2][1])
S.shift = true; ns.abKey("3"); S.shift = false
assert(S.A.binds["13"] == "SHIFT-3" and not S.A.binds["3"] and S.ab[3].wpKey._text == "", "the key moved")
ns.abKey("ESCAPE")
assert(not S.A.binds["13"] and not S.binds["SHIFT-3"], "Escape on a button: unbound")
S.combat = true; ns.abKey("Q"); S.combat = false
assert(not S.A.binds["13"], "no binding in combat")
ns.ab.buttons[2][1]._scripts.OnLeave(ns.ab.buttons[2][1]); ns.abKey("ESCAPE")
assert(not ns.ab.binding and not ns.ab.binder:IsShown(), "Escape off the buttons: done")
-- deleting a bar frees its slots; its frame goes
StaticPopupDialogs.WOLFPACKADDON_DELBAR.OnAccept(nil, 2)
assert(#S.A.bars == 1 and not ns.ab.frames[2]:IsShown() and ns.abRoom(1) == 120, "deleted: the room is back")
-- in the profile string: bars and binds come back
S.A.binds["5"] = "CTRL-F"
S.A.bars[1].cols = 7
S.nm = ns.importString(ns.exportString())
assert(S.nm and prof().actionbars.binds["5"] == "CTRL-F" and #prof().actionbars.bars == 1
    and prof().actionbars.bars[1].cols == 7, "bars and binds travel in the profile string")
-- Stance and pet bars: Blizzard's own buttons, moved into bars of yours; given back when off
StanceBar = new(); StanceBar._parent = UIParent
;(function()
    for i = 1, 3 do
        _G["StanceButton" .. i] = new(); _G["StanceButton" .. i]._parent = StanceBar
        _G["StanceButton" .. i]._name = "StanceButton" .. i
        _G["StanceButton" .. i]:SetPoint("LEFT", StanceBar, "LEFT", (i - 1) * 30, 0)
    end
    for i = 1, 10 do _G["PetActionButton" .. i] = new(); _G["PetActionButton" .. i]._parent = UIParent end
end)()
S.SB, S.PT = prof().actionbars.stance, prof().actionbars.pet
S.SB.show = true; fire("UNIT_MAXPOWER")
S.sf = ns.ab.special.stance.frame
assert(StanceButton1._parent == S.sf and StanceButton2._point[2] == S.sf and StanceButton2._point[4] == 34
    and StanceButton1._w == 30, "the stance buttons in a bar of yours, 30 + 4 apart")
assert(S.sf._point[1] == "BOTTOMLEFT" and S.sf._point[2] == ns.ab.frames[1] and S.sf._point[3] == "TOPLEFT"
    and S.sf._point[5] == S.SB.gap, "on top of bar 1")
S.PT.show, S.PT.anchorTo, S.PT.side = true, "stance", "right"; fire("UNIT_MAXPOWER")
S.pf2 = ns.ab.special.pet.frame
assert(S.pf2._driver == "[pet] show; hide" and PetActionButton1._parent == S.pf2, "pet bar: only with a pet")
assert(S.pf2._point[2] == S.sf and S.pf2._point[1] == "TOPLEFT" and S.pf2._point[3] == "TOPRIGHT",
    "right of the stance bar")
S.SB.cols, S.SB.rows = 2, 1; fire("UNIT_MAXPOWER")
assert(StanceButton3._parent ~= S.sf and StanceButton3._parent ~= StanceBar, "a third doesn't fit two: parked")
-- keybind mode works on them too, by their own slot names
ns.abBindMode(true); StanceButton1._scripts.OnEnter(StanceButton1); ns.abKey("F1")
assert(prof().actionbars.binds["stance:1"] == "F1" and S.binds.F1 == "StanceButton1", "F1 on the first stance")
StanceButton1._scripts.OnLeave(StanceButton1); ns.abBindMode(false)
S.SB.show, S.SB.cols = false, 10; fire("UNIT_MAXPOWER")
assert(StanceButton1._parent == StanceBar and StanceButton2._point[2] == StanceBar and StanceButton2._point[4] == 30,
    "off: given back where they were")
assert(S.pf2._point[1] == "BOTTOM" and S.pf2._point[2] == UIParent, "its anchor gone: the pet bar on the screen")
S.PT.show = false; fire("UNIT_MAXPOWER")
assert(not S.pf2._driver and PetActionButton1._parent == UIParent, "pet bar off too")
-- Blizzard's own stance bar hidden
prof().regular.hideStanceBar = true; fire("UNIT_MAXPOWER")
assert(StanceBar._parent ~= UIParent, "Blizzard's stance bar hidden")
prof().regular.hideStanceBar = false; fire("UNIT_MAXPOWER")
assert(StanceBar._parent == UIParent, "and back")
-- Blizzard's action bars, hidden the same way as its unit frames
MultiBarBottomLeft = new(); MultiBarBottomLeft._parent = UIParent
prof().regular.hideActionBars = true; fire("UNIT_MAXPOWER")
assert(MultiBarBottomLeft._parent ~= UIParent, "Blizzard's bars hidden")
prof().regular.hideActionBars = false; fire("UNIT_MAXPOWER")
assert(MultiBarBottomLeft._parent == UIParent, "and back")
realPrint("smoke ok")
