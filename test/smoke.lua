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
function M:HookScript(k, fn) -- as the game: after the script already there, not instead of it
    local old = self._scripts[k]
    self._scripts[k] = old and function(...) old(...); return fn(...) end or fn
end
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
-- does `r` hang (through its anchors) on `target`? The game refuses a loop (seen in game)
local function dependsOn(r, target, seen)
    if r == target then return true end
    seen = seen or {}
    if type(r) ~= "table" or seen[r] then return false end
    seen[r] = true
    for _, p in ipairs(rawget(r, "_points") or {}) do
        if dependsOn(p[2], target, seen) then return true end
    end
    return false
end
function M:SetPoint(...)
    local rel = select(2, ...)
    if type(rel) == "table" and dependsOn(rel, self) then error("Cannot anchor to a region dependent on it\n" .. debug.traceback(), 2) end
    self._point = { ... }
    self._points = self._points or {}
    self._points[#self._points + 1] = { ... }
end
function M:ClearAllPoints() self._points = {} end
function M:SetJustifyH(j) -- the game refuses anything else (seen in game with "TOP")
    assert(j == "LEFT" or j == "CENTER" or j == "RIGHT", "SetJustifyH: bad argument " .. tostring(j))
    self._justify = j
end
function M:SetGradient(orient, c1, c2) self._grad = { orient, c1, c2 } end
function M:SetTexture(t) self._tex = t end
function M:SetScale(v) self._scale = v end
function M:GetScale() return self._scale or 1 end
function M:SetTextureSliceMargins(...) self._slice = { ... } end
function M:SetAlpha(v) self._alpha, self._alphaSets = v, (self._alphaSets or 0) + 1 end
function M:SetDesaturated(v) self._desat = v end
function M:SetRotation(v) self._rot = v end
function M:SetEnabled(v) self._enabled = v end
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
function M:EnableMouseWheel(v) self._wheel = v end
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
function M:SetColorTexture(r, ...) assert(type(r) == "number", "SetColorTexture(color [, a])"); self._color = { r, ... } end
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
function M:GetRight() return 140 end
function M:GetLeft() return 40 end
function M:GetFrameLevel() return self._level or 1 end
function M:SetFrameLevel(v) self._level = v end
function M:GetFrameStrata() return self._strata or "MEDIUM" end
function M:SetFrameStrata(v) self._strata = v end
function M:IsMouseEnabled() return true end
function M:GetWidth() return self._w or 140 end
function M:GetHeight() return self._h or 100 end
function M:SetHeight(h) self._h = h end
function M:SetWidth(w) self._w = w end
function M:SetDrawLayer(l, sub) self._layer = { l, sub } end
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
function M:RegisterEvent(e) evFrame = self; self._ev = self._ev or {}; if e then self._ev[e] = true end end
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
HasAction = function(slot) return (S.hasAction or {})[slot] and true or false end
RegisterStateDriver = function(f, kind, rule) f._driver = rule end
UnregisterStateDriver = function(f) f._driver = nil end
ClearOverrideBindings = function(owner) S.binds = {} end
SetOverrideBindingClick = function(owner, prio, key, name, btn) S.binds[key] = name; S.bindPrio = prio end
GetBindingAction = function(key) return S.binds[key] and ("CLICK " .. S.binds[key] .. ":LeftButton") or "" end
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
        if S.filters then S.filters[filter] = true end
        if filter:find("^HARMFUL") then return (S.debuffs or {})[i] end
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
ReloadUI = function() S.reloaded = (S.reloaded or 0) + 1 end
TargetFrame._parent = UIParent
MainMenuExpBar = new()
MainMenuExpBar._parent = UIParent
UnitXP = function() return S.xp or 300 end
UnitXPMax = function() return S.xpMax or 1000 end
GetRealmName = function() return "Realm" end
SecureHandlerWrapScript = function(f, script, header, pre)
    f._wrap = rawget(f, "_wrap") or {}
    f._wrap[script] = pre
end
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
assert(loadfile("WolfpackAddon/Dots.lua"))("WolfpackAddon", ns) -- next in the toc
assert(loadfile("WolfpackAddon/Borrow.lua"))("WolfpackAddon", ns)
assert(loadfile("WolfpackAddon/Macros.lua"))("WolfpackAddon", ns) -- next in the toc
UseInventoryItem = function() end -- the game's: Trinkets.lua watches it
assert(loadfile("WolfpackAddon/Trinkets.lua"))("WolfpackAddon", ns)
local function fire(e, ...) evFrame._scripts.OnEvent(evFrame, e, ...) end
-- each class logs in as its own character; once S.perClass is set, on a profile of its own (named
-- after the class, as the tests below were written for), else on Alpha like a real first login
local function login(class, ptype)
    S.class, S.name, S.ptype = class, class .. "Char", ptype
    local db = WolfpackAddonDB
    if S.perClass and db and db.profiles and not (db.classProfiles or {})[class] then -- a tie wins
        local own, key = class:sub(1, 1) .. class:sub(2):lower(), S.name .. " - Realm"
        if db.chars[key] == nil or db.chars[key] == "Alpha" then db.chars[key] = own end
        db.profiles[own] = db.profiles[own] or {}
    end
    fire("PLAYER_LOGIN")
end
local function prof() return WolfpackAddonDB.profiles[WolfpackAddonDB.chars[S.name .. " - Realm"]] end
local function byText(text) for _, f in ipairs(created) do if f._text == text then return f end end end
local fr = ns.frames

-- Rogue, secret values: 5 pips, each lit when points >= i; stack = health 18, power 14, combo 12,
-- cast bar and swing rows only join the stack while they run
-- the panels hear about the world before a profile exists, and must sit that out quietly
for _, evf in ipairs({ ns.hnEv }) do
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

-- Combo points as circles: per point a background disc, the fill over it (lit like a pip, so
-- a secret count still works), a ring on top; the row as tall as the biggest layer
do
    local CB = prof().regular.bars.combo
    local o = CB.circles
    o.on, o.gap = true, 4
    o.bg.size, o.fill.size, o.ring.size, o.ring.width = 20, 12, 18, 2
    o.bg.from, o.fill.from, o.ring.from = "bar", "custom", "bar"
    o.fill.color = { 0, 1, 0, 1 }
    fire("UNIT_MAXPOWER")
    local f = fr.combo
    local p1, p3 = f.circles[1], f.circles[3]
    assert(not f.segs[1]:IsShown() and p1:IsShown() and f._w == 5 * 20 + 4 * 4 and f._h == 20, "five circles in a row")
    assert(p3._point[4] == 2 * 24 and p1.bg._w == 20 and p1.fill._w == 12 and p1.ring._w == 18, "each layer its size")
    assert(p1.fill._min == 0 and p1.fill._max == 1 and p3.fill._min == 2 and p3.fill._value == SECRET,
        "the fill lights like a pip")
    assert(p1.fill._sbc[2] == 1 and p1.bg._vertex[1] == CB.bgColor[1], "custom fill, the bar's background")
    assert(p1.ring._masks[p1.disc] and p1.ring._masks[p1.hole] and p1.hole._w == 2 * 2 * 7, "a ring: a disc, holed")
    assert(WolfpackAddonFrame._h == 48 + 20 - CB.height, "the stack makes room for the row")
    assert(p1.top:GetFrameLevel() > p1.fill:GetFrameLevel() and p1.fill:GetFrameLevel() > p1:GetFrameLevel(),
        "ring over fill over background")
    o.ring.width = 9 -- all but solid: a plain disc
    fire("UNIT_MAXPOWER")
    assert(not p1.ring._masks[p1.hole], "too thick for a hole")
    o.on = false
    fire("UNIT_MAXPOWER")
    assert(f.segs[1]:IsShown() and not p1:IsShown() and WolfpackAddonFrame._h == 48, "back to pips")
    o.ring.width, o.fill.from = 2, "bar"
end

-- The grid: health on the center line (18 high, so 9 above it), combo points then power below it
-- in the middle column, the gap (2) between. Extra space above / below a bar pushes the rest of
-- its column.
assert(fr.health._point[5] == 0 and fr.combo._point[5] == -20 and fr.power._point[5] == -34
    and WolfpackAddonFrame._h == 48, "the line, then combo and power below it")
-- the three icon stacks (Bar Stack groups hang there): thirds of the middle column, the gap above the line
assert(ns.iconSlots[2]._point[1] == "BOTTOM" and ns.iconSlots[2]._point[2] == WolfpackAddonFrame
    and ns.iconSlots[2]._point[4] == 0 and ns.iconSlots[2]._point[5] == 2
    and math.abs(ns.iconSlots[1]._point[4] + 220 / 3) < 0.01 and math.abs(ns.iconSlots[1]._w - 220 / 3) < 0.01,
    "icon stacks over the middle column")
prof().regular.bars.power.padTop = 6
fire("UNIT_MAXPOWER")
assert(fr.power._point[5] == -40 and WolfpackAddonFrame._h == 54, "space above power")
prof().regular.bars.power.padTop, prof().regular.bars.combo.padBottom = 0, 4
fire("UNIT_MAXPOWER")
assert(fr.power._point[5] == -38, "space below combo")
prof().regular.bars.combo.padBottom = 0
fire("UNIT_MAXPOWER")
-- any element can leave the grid and hang on another: power under your health's left end
S.PWR = prof().regular.bars.power
S.PWR.attach, S.PWR.attachPoint, S.PWR.attachRel, S.PWR.y = "health", "TOPLEFT", "BOTTOMLEFT", -3
fire("UNIT_MAXPOWER")
assert(fr.power._point[1] == "TOPLEFT" and fr.power._point[2] == fr.health and fr.power._point[3] == "BOTTOMLEFT"
    and fr.power._point[5] == -3 and WolfpackAddonFrame._h == 32, "power hangs on health; the middle column closes up")
-- two on each other is a loop: both stay on the grid
prof().regular.bars.health.attach = "power"; fire("UNIT_MAXPOWER")
assert(fr.power._point[2] == WolfpackAddonFrame and fr.health._point[2] == WolfpackAddonFrame, "a loop: the grid")
prof().regular.bars.health.attach, S.PWR.attach = "", "nothing-by-that-name"; fire("UNIT_MAXPOWER")
assert(fr.power._point[2] == WolfpackAddonFrame, "an unknown element: the grid")
-- a row too: your debuffs on the whole display's bottom
S.PWR.attach, S.PWR.y = "", 0
prof().regular.bars.health.debuffs.attach = "display"
prof().regular.bars.health.debuffs.attachPoint, prof().regular.bars.health.debuffs.attachRel = "TOP", "BOTTOM"
fire("UNIT_MAXPOWER")
assert(ns.auraSlots.debuffs._point[2] == WolfpackAddonFrame and ns.auraSlots.debuffs._point[3] == "BOTTOM",
    "a row hung on the display")
assert(#ns.attachTargets("power") > 10 and ns.attachTargets("power")[1][2] == "", "the menu: the grid first, not itself")
for _, e in ipairs(ns.attachTargets("power")) do assert(e[2] ~= "power", "never itself") end
prof().regular.bars.health.debuffs.attach = ""; fire("UNIT_MAXPOWER")

-- Druid: caster = no combo, no extra mana; cat = both; bear = mana only
login("DRUID", 0)
assert(not fr.combo:IsShown() and not fr.druidmana:IsShown(), "druid caster")
S.ptype = 3; fire("UPDATE_SHAPESHIFT_FORM")
assert(fr.combo:IsShown() and fr.druidmana:IsShown(), "druid cat")
S.ptype = 1; fire("UPDATE_SHAPESHIFT_FORM")
assert(not fr.combo:IsShown() and fr.druidmana:IsShown(), "druid bear")
-- out of cat form, the combo points still on the target show, and go with them
GetComboPoints = function(_, unit) return unit == "target" and S.combo or 0 end
S.combo = 3; fire("PLAYER_TARGET_CHANGED")
assert(fr.combo:IsShown() and fr.combo.segs[1]._value == 3, "bear: the target's 3 points show")
S.combo = 0; fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
assert(not fr.combo:IsShown(), "points gone: hidden again")
GetComboPoints = nil

-- Other classes: resource shows only when its max is readable and > 0
login("PALADIN", 0)
assert(not fr.combo:IsShown(), "secret holy power hidden")
S.secret, S.max[9] = false, 5; fire("UNIT_MAXPOWER")
assert(fr.combo:IsShown() and fr.combo.n == 5, "readable holy power shown")
S.max[9] = 0; fire("UNIT_MAXPOWER")
assert(not fr.combo:IsShown(), "no holy power on this client")
login("WARRIOR", 1)
assert(not fr.combo:IsShown() and fr.power:IsShown(), "warrior")

-- Profiles: shared account-wide; a character with no pick of its own and no profile tied to
-- its class starts on Alpha
local store = WolfpackAddonDB
assert(store.profiles.Alpha and store.chars["WARRIORChar - Realm"] == "Alpha"
    and store.chars["ROGUEChar - Realm"] == "Alpha", "every character starts on Alpha")
S.perClass = true -- from here on each test class keeps a profile of its own
login("WARRIOR", 1)

-- Per-bar offsets move only that bar; the next bar keeps its slot. The middle column is 220
-- wide, so its bars' left edge is at -110.
S.secret = true
login("ROGUE", 3)
local R = prof().regular.bars
R.power.x, R.power.y = 5, -3
R.combo.y = 2
fire("UNIT_MAXPOWER")
local pp, cp = fr.power._point, fr.combo._point
assert(pp[1] == "TOPLEFT" and pp[2] == WolfpackAddonFrame and pp[3] == "TOP" and pp[4] == -105 and pp[5] == -37,
    "power offset")
assert(cp[4] == -110 and cp[5] == -18, "combo: its own nudge")
R.power.x, R.power.y, R.combo.y = 0, 0, 0

-- Enemy health: right of the middle column while you have a target; its resource can sit inside
local eh, ef = prof().regular.bars.enemyhealth, fr.enemyhealth
local rf = ef.resFrame
R.tothealth.show, R.pethealth.show, eh.resource = false, false, true
fire("PLAYER_TARGET_CHANGED")
assert(eh.show and not ef:IsShown(), "on by default, hidden with no target")
S.targetHP = 500
fire("PLAYER_TARGET_CHANGED")
assert(ef:IsShown() and ef.segs[1]._value == 500 and ef.segs[1]._max == 1000 and ef.texts.current._text == "500" and not ef.text:IsShown(),
    "target values")
assert(ef._point[1] == "TOPLEFT" and ef._point[4] == 112 and ef._point[5] == 0, "on the line, right of the middle")
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
assert(ef._h == 18 and rf._h == 4 and rf._w == 198 and fr.power._point[5] == -34,
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
-- eating the same way, in its own color; both at once say so
S.auras = { { name = "Food", icon = 1 } }; fire("UNIT_AURA", "target")
assert(tn2:IsShown() and tn2._text == "Eating!" and tn2._color[1] == 1 and tn2._color[2] == 0.8
    and tn2.box._scripts.OnUpdate, "eating: says so, flashing, in its color")
S.auras = { { name = "Food & Drink", icon = 1 } }; fire("UNIT_AURA", "target")
assert(tn2._text == "Eating & drinking!", "both")
eh.eating.show = false; S.auras = { { name = "Food", icon = 1 } }; fire("UNIT_AURA", "target")
assert(not tn2:IsShown(), "eating turned off")
eh.eating.show = true
eh.drinking.show = false; S.auras = { { name = "Drink", icon = 1 } }; fire("UNIT_AURA", "target")
assert(not tn2:IsShown(), "turned off")
eh.drinking = { show = true, color = { 0.35, 0.75, 1, 1 } }
eh.pvpIcon = { show = true, style = "faction", anchorTo = "bar", point = "TOPLEFT", x = 0, y = 0, size = 20,
    text = "PvP", textColor = { 1, 0.25, 0.25, 1 } }
S.auras, UnitIsPVP, UnitIsPVPFreeForAll = nil, nil, nil
fire("UNIT_AURA", "target")
-- buffs and debuffs: each group in a box on its row of the grid; your target's buffs under its
-- health (right column), its debuffs under them
S.auras = { { icon = 111, duration = 10, expirationTime = 20 }, { icon = 112, applications = 3 } }
S.debuffs = { { icon = 221 } }
fire("UNIT_AURA", "target")
local bi, di = ef.auraIcons.buffs, ef.auraIcons.debuffs
local bb, db_ = ef.auraBoxes.buffs, ef.auraBoxes.debuffs
assert(bi[1]:IsShown() and bi[2]:IsShown() and bi[1].tex._tex == 111 and bi[2].count._text == 3
    and bi[1].cd._cd[1] == 10 and bi[1].cd._cd[2] == 10, "the target's buffs, with timer and stacks")
assert(bb._point[1] == "TOPLEFT" and bb._point[2] == ns.auraSlots.tbuffs and bb._w == 42 and bb._h == 20,
    "the buff box: on its row, as big as two icons and a gap")
assert(bi[2]._point[2] == bb and bi[2]._point[4] == 22, "icons grow right, 20 + 2 apart")
-- as on your side: buffs right under enemy health, debuffs under them, its power after
assert(ns.auraSlots.tbuffs._point[4] == 112 and ns.auraSlots.tbuffs._point[5] == -20, "buffs under enemy health")
assert(di[1].tex._tex == 221 and db_._point[1] == "TOPLEFT" and db_._point[2] == ns.auraSlots.tdebuffs
    and ns.auraSlots.tdebuffs._point[4] == 112 and ns.auraSlots.tdebuffs._point[5] == -20 - 20 - 2,
    "debuffs under the buffs")
assert(fr.combo._point[5] == -20, "the middle as it was")
-- options open (or unlocked): dummies fill each group's grid, with timers and stacks, to tune by
prof().locked = false; fire("UNIT_AURA", "target")
assert(bi[8]:IsShown() and bi[1].tex._tex:find("Spell_Holy_WordFortitude") and di[16]:IsShown()
    and bi[1].cd._cd and bi[3].count._text == 3, "a full grid of stand-ins: 8 buffs, 16 debuffs")
prof().locked = true; fire("UNIT_AURA", "target")
assert(bi[1].tex._tex == 111 and not bi[3]:IsShown(), "closed again: the real ones")
eh.buffs.cols, eh.buffs.rows, eh.buffs.spot = 1, 2, "above_right"
fire("UNIT_AURA", "target")
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
assert(not bi[1]:IsShown() and bb._w == 1, "no buffs, no icons, a box of 1 px")
S.auras = {}
eh.debuffs.show = false; fire("UNIT_AURA", "target")
assert(not di[1]:IsShown() and ns.auraSlots.tdebuffs.h == 0, "debuffs off: their row takes no room")
-- filters: only yours, a list of the only ones, a list of never these (names in any case, or IDs)
eh.debuffs.show = true
S.debuffs = { { icon = 1, name = "Rend", sourceUnit = "player" }, { icon = 2, name = "Sunder Armor", sourceUnit = "target" },
    { icon = 3, name = "Hamstring", spellId = 1715, sourceUnit = "player" } }
fire("UNIT_AURA", "target")
assert(di[3]:IsShown(), "all three by default")
eh.debuffs.mine, S.filters = true, {}; fire("UNIT_AURA", "target")
assert(S.filters["HARMFUL|PLAYER"] and di[1].tex._tex == 1 and di[2].tex._tex == 3 and not di[3]:IsShown(),
    "only mine: the game is asked for yours, and Sunder (theirs) goes")
eh.debuffs.mine, eh.debuffs.allow, S.filters = false, " sunder armor , 1715", nil; fire("UNIT_AURA", "target")
assert(di[1].tex._tex == 2 and di[2].tex._tex == 3 and not di[3]:IsShown(), "only these: by name or ID")
eh.debuffs.allow, eh.debuffs.block = "", "Rend"; fire("UNIT_AURA", "target")
assert(di[1].tex._tex == 2 and di[2].tex._tex == 3 and not di[3]:IsShown(), "never these")
eh.debuffs.max, eh.debuffs.block = 1, "Sunder Armor"; fire("UNIT_AURA", "target")
assert(di[1].tex._tex == 1 and not di[2]:IsShown(), "most icons counts what is left")
eh.debuffs.max, S.debuffs[1].name = 16, SECRET; S.debuffs[2].name = SECRET; fire("UNIT_AURA", "target")
assert(di[3]:IsShown(), "a secret name can't be checked: it shows")
eh.debuffs.block, eh.debuffs.show, S.debuffs = "", false, nil; fire("UNIT_AURA", "target")
-- the crowd control icon over your target's cast bar: the kind that matters most (a stun over a
-- silence), centered in the column, the grid making room above the line
S.debuffs = { { icon = 11, name = "Silence", duration = 5, expirationTime = 105 }, { icon = 12, name = "Sunder Armor" },
    { icon = 13, name = "Kidney Shot", duration = 6, expirationTime = 106 } }
fire("UNIT_AURA", "target")
S.big = ns.bigFrames.enemyhealth
assert(S.big:IsShown() and S.big.tex._tex == 13 and S.big._w == 36 and S.big._point[4] == 112 + (220 - 36) / 2
    and S.big._point[5] == 0 and ef._point[5] == -38, "a stun over a silence, above enemy health")
S.debuffs = { { icon = 11, name = "Silence" }, { icon = 12, name = "Sunder Armor" } }; fire("UNIT_AURA", "target")
assert(S.big.tex._tex == 11, "a silence alone shows")
S.debuffs = { { icon = 12, name = "Sunder Armor" } }; fire("UNIT_AURA", "target")
assert(not S.big:IsShown() and ef._point[5] == 0, "no crowd control: gone, the grid closes up")
eh.big.show, S.debuffs = false, { { icon = 13, name = "Kidney Shot" } }; fire("UNIT_AURA", "target")
assert(not S.big:IsShown(), "turned off")
eh.big.show, S.debuffs = true, nil; fire("UNIT_AURA", "target")
-- a client that keeps auras from addons in combat (Forever): your target's rows take Blizzard's
-- own target frame buttons, oldest aura first, never reading them; ours stand down
S.bz = { new(), new(), new() }
S.bz[1].auraInstanceID, S.bz[2].auraInstanceID, S.bz[3].auraInstanceID = 30, 10, 20
S.bzList = S.bz
S.bz[2].Icon, S.bz[2].Border, S.bz[2].Cooldown, S.bz[2].Count = new(), new(), new(), new()
TargetFrame.auraPools = { EnumerateActiveByTemplate = function(_, t)
    local i, l = 0, t == "TargetDebuffFrameTemplate" and S.bzList or {}
    return function() i = i + 1; return l[i] end
end }
eh.debuffs.show, S.combat = true, true; fire("UNIT_AURA", "target")
assert(S.bz[2]._parent == db_ and S.bz[3]._parent == db_ and S.bz[1]._parent == db_ and db_.n == 3
    and S.bz[2]._point[4] == 0 and S.bz[3]._point[4] == 26 and S.bz[1]._point[4] == 52 and S.bz[2]._w == 24,
    "Blizzard's debuff buttons in the row, oldest first, while the game refuses us")
assert(not di[1]:IsShown(), "ours stand down")
assert(S.bz[2].Border._alpha == 0 and S.bz[2].Icon._coords[1] == 0.08 and S.bz[2].Icon._coords[2] == 0.92
    and S.bz[2].Cooldown._swipeTex:find("WHITE8X8") and S.bz[2].Count._point[1] == "BOTTOMRIGHT",
    "reskinned like ours: no border, the picture trimmed, our swipe, the count bottom right")
S.bzList = { S.bz[2], S.bz[3] }; fire("UNIT_AURA", "target")
assert(db_.n == 2 and S.bz[1]._parent == ns.borrow.away, "one gone: out of sight")
S.combat, TargetFrame.auraPools, eh.debuffs.show = false, nil, false; fire("UNIT_AURA", "target")
assert(S.bz[2]._parent == ns.borrow.away, "a client that answers: ours again, Blizzard's put away")
-- grow up or down: a line is a column (rows icons tall); new columns go along the bar's edge
-- when growing straight away from it, else away from the bar
S.auras = { { icon = 1 }, { icon = 2 }, { icon = 3 } }
eh.buffs = { show = true, anchorTo = "bar", spot = "topright", grow = "up", x = 0, y = 0, size = 20, radius = 0,
    cols = 2, rows = 2, max = 4, hideTimer = false }
fire("UNIT_AURA", "target")
assert(bi[2]._point[1] == "BOTTOMRIGHT" and bi[2]._point[4] == 0 and bi[2]._point[5] == 22, "the next one goes up")
assert(bi[3]._point[4] == -22 and bi[3]._point[5] == 0, "a new column: inward, to the left")
assert(bb._w == 42 and bb._h == 42, "two columns of two")
eh.buffs.spot, eh.buffs.grow = "righttop", "down"; fire("UNIT_AURA", "target")
assert(bi[2]._point[5] == -22 and bi[3]._point[4] == 22 and bi[3]._point[5] == 0, "down, new columns to the right")
-- grow then wrap, both chosen: up then left, right then down
eh.buffs.spot, eh.buffs.grow, eh.buffs.wrap = "topleft", "up", "left"; fire("UNIT_AURA", "target")
assert(bi[1]._point[1] == "BOTTOMRIGHT" and bi[2]._point[5] == 22 and bi[3]._point[4] == -22
    and bi[3]._point[5] == 0, "up, then a new column to the left")
eh.buffs.grow, eh.buffs.wrap = "right", "down"; fire("UNIT_AURA", "target")
assert(bi[1]._point[1] == "TOPLEFT" and bi[2]._point[4] == 22 and bi[3]._point[5] == -22, "right, then a new row down")
eh.buffs.wrap = "left"; fire("UNIT_AURA", "target")
assert(bi[3]._point[5] == 22, "a wrap along the growing makes no sense: auto")
eh.buffs.wrap = "auto"
-- the old one-in-all choice converts by itself
eh.buffs.spot, eh.buffs.grow = "below_left", nil; fire("UNIT_AURA", "target")
assert(eh.buffs.spot == "bottomright" and eh.buffs.grow == "left", "below_left: the bottom right corner, growing left")
-- top center: each line centered, spread both ways; new rows go up
eh.buffs.spot, eh.buffs.grow = "topcenter", "up"; fire("UNIT_AURA", "target")
assert(bi[1]._point[1] == "BOTTOM" and bi[1]._point[4] == -11 and bi[2]._point[4] == 11
    and bi[1]._point[5] == 0, "two in a row: one each side of the middle (grow ignored)")
assert(bi[3]._point[4] == 0 and bi[3]._point[5] == 22, "the lone one on the next row up: centered")
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
assert(rf.segs[1].border._shown and rf.segs[1].border._vertex[3] == 1 and rf.segs[1]._w == 196 and rf.segs[1]._h == 2,
    "a 1 px blue border inside its size")
assert(rf.segs[1].borderMask._tex:match("r2%.tga$"), "its own corner radius, capped at half its 4 px height")
assert(ef.segs[1].border._shown == false, "enemy health's border untouched")
eh.resBorderMode = "bar"
fire("PLAYER_TARGET_CHANGED")
assert(rf.segs[1].border._vertex[1] == 1 and rf.segs[1].border._vertex[3] == 0.25, "same as bar: a lighter energy yellow")
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
eh.resHideEmpty = false
UnitPower = function() return 0 end
fire("UNIT_POWER_FREQUENT", "target")
assert(rf:GetAlpha() == 1, "Hide when empty off: an empty bar stays")
eh.resHideEmpty = true
-- its own color: power color by default, or a custom one
assert(rf.segs[1]._sbc[1] == 1 and rf.segs[1]._sbc[3] == 0, "power color: energy yellow")
eh.resColorMode, eh.resColor = "custom", { 0, 0.5, 0, 1 }
fire("PLAYER_TARGET_CHANGED")
assert(rf.segs[1]._sbc[1] == 0 and rf.segs[1]._sbc[2] == 0.5, "custom color")
eh.resColorMode = "power"
UnitPower = S.realPower
eh.resource = false
fire("PLAYER_TARGET_CHANGED")
assert(not rf:IsShown(), "resource off")
eh.resource = true
-- Enemy health's color
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
-- a player you can attack: their class color while they can fight back, neutral while not
S.reaction, S.targetIsPlayer = 2, true
UnitCanAttack = function(a) return a == "player" or S.fightsBack end
S.fightsBack = true; fire("PLAYER_TARGET_CHANGED")
assert(ef.segs[1]._sbc[1] == 0.25, "an enemy player: their class color")
S.fightsBack = false; fire("PLAYER_TARGET_CHANGED")
assert(ef.segs[1]._sbc[2] == 0.8 and ef.segs[1]._sbc[1] == 0.95, "one who cannot attack you: neutral")
UnitCanAttack, S.targetIsPlayer, S.fightsBack = nil, nil, nil
eh.colorMode = "class"; S.reaction = 5; fire("PLAYER_TARGET_CHANGED")
assert(ef.segs[1]._sbc[1] == 0.2 and ef.segs[1]._sbc[2] == 0.8, "class mode, an NPC: friendly by standing")
UnitReaction, S.reaction, eh.colorMode = nil, nil, "custom"
fire("PLAYER_TARGET_CHANGED")
S.targetHP = 250; fire("UNIT_HEALTH", "target")
assert(ef.segs[1]._value == 250 and fr.health.segs[1]._value == SECRET, "target updates, player keeps its own")
-- Target of target: right of enemy health, in a column of its own (its own width). With none,
-- enemy health takes its room as well.
S.TT = prof().regular.bars.tothealth
S.units = S.units or {}
S.units.targettarget = true
S.TT.show = true; fire("UNIT_TARGET", "target")
S.tf = fr.tothealth
assert(S.tf:IsShown() and S.tf._point[1] == "TOPLEFT" and S.tf._point[4] == 110 + 2 + 220 + 2 and S.tf._w == 90
    and ef._w == 220, "right of enemy health, its own width")
-- its health is asked for (nothing tells), five times a second
S.realHP = UnitHealth
UnitHealth = function(u) return u == "targettarget" and 77 or S.realHP(u) end
ns.totPoll._scripts.OnUpdate(ns.totPoll, 1)
assert(S.tf.segs[1]._value == 77, "health polled")
UnitHealth = S.realHP
S.units.targettarget = nil; fire("UNIT_TARGET", "target")
assert(not S.tf:IsShown() and ef._w == 220 and ef._point[4] == 112, "no target of target: enemy health keeps its width")
S.units.targettarget = true; fire("UNIT_TARGET", "target")
assert(S.tf.tag_name:IsShown(), "its name, by default")
S.TT.tagName = false; fire("UNIT_TARGET", "target")
assert(not S.tf.tag_name:IsShown(), "name hidden")
S.TT.tagName, S.TT.show = true, false
S.units.targettarget = nil; fire("UNIT_TARGET", "target")
assert(ef._w == 220, "target of target turned off: no room kept for it")
-- Your pet: left of your health, in a column of its own; with none out, your health keeps its width
S.PB = prof().regular.bars.pethealth
S.PB.show = true; fire("UNIT_PET", "player")
assert(not fr.pethealth:IsShown() and fr.health._w == 220 and fr.health._point[4] == -332,
    "no pet: your health as it is")
S.petHP = 100; fire("UNIT_PET", "player")
S.pf = fr.pethealth
assert(S.pf:IsShown() and S.pf._point[4] == -334 - 120 and S.pf._w == 120 and fr.health._w == 220
    and fr.health._point[4] == -332, "your pet left of your health")
S.petHP, S.PB.show = nil, false; fire("UNIT_PET", "player")
assert(fr.health._w == 220, "pet bar off: your health its own width")
-- Your target's power: a bar of its own under enemy health, or inset in it (enemy health's
-- resource strip, one switch for both)
eh.resource = false; fire("PLAYER_TARGET_CHANGED")
S.EP = fr.enemypower
assert(S.EP:IsShown() and not rf:IsShown() and S.EP._point[4] == 112 and S.EP._point[5] == -20, "under enemy health")
S.EP.segs[1]._value = nil; fire("UNIT_POWER_FREQUENT", "target")
assert(S.EP.segs[1]._value == SECRET and S.EP.segs[1]._sbc[1] == 1 and S.EP.segs[1]._sbc[3] == 0,
    "follows the target's power, in its color (energy, your yellow)")
eh.resource = true; fire("PLAYER_TARGET_CHANGED")
assert(not S.EP:IsShown() and rf:IsShown() and rf._point[2] == ef, "inside enemy health: the strip, the bar out of the grid")
-- Focus: above target of target's column
S.units.focus = true; fire("PLAYER_FOCUS_CHANGED")
assert(fr.focushealth:IsShown() and fr.focushealth._point[4] == 334 and fr.focushealth._point[5] == 0
    and fr.health._point[5] == -20, "focus: above the line on the right; the frame now starts at its top")
S.units.focus = nil; fire("PLAYER_FOCUS_CHANGED")
assert(not fr.focushealth:IsShown(), "no focus: gone")
fire("PLAYER_TARGET_CHANGED")
rf.segs[1]._value = nil; fire("UNIT_POWER_FREQUENT", "target")
assert(rf.segs[1]._value == SECRET, "its resource follows the target's power")
S.targetHP = nil; fire("PLAYER_TARGET_CHANGED")
assert(not ef:IsShown() and not S.EP:IsShown() and fr.health._w == 220, "target gone")

-- the old "Target health beside it" switch turns Enemy Health on
prof().regular.bars.health.target, eh.show = true, false
fire("PLAYER_LOGIN")
assert(eh.show and not prof().regular.bars.health.target, "old switch carried over")

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
assert(gs.border._vertex[1] == 0.25 and gs.border._vertex[3] == 1, "gradient border from its start")
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

-- The frame is pinned by the center line: its top sits as far above x / y as the bars reach
local R1 = prof().regular
fire("PLAYER_ENTERING_WORLD")
assert(WolfpackAddonFrame._point[1] == "TOP" and WolfpackAddonFrame._point[4] == R1.x
    and WolfpackAddonFrame._point[5] == R1.y + 9, "the line at x / y, half the health bar above it")
local mover2
for _, f in ipairs(created) do if f._scripts.OnMouseUp and f._scripts.OnDragStart and not f._name then mover2 = f end end
mover2._scripts.OnDragStart(mover2); mover2._scripts.OnDragStop(mover2)
assert(R1.y == 41, "drag stores the line (top 150, 9 above the line, from 100)")
R1.x, R1.y = 0, -120
fire("PLAYER_ENTERING_WORLD")

-- Cast bar: away while idle, above your health while casting; channels drain; icon side
local cb = fr.castbar
assert(not cb:IsShown() and WolfpackAddonFrame._h == 48, "idle: away")
S.cast = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
local cs = cb.segs[1]
assert(cb:IsShown() and WolfpackAddonFrame._h == 64 and cb._point[5] == 0 and cb._point[4] == -332
    and fr.health._point[5] == -16, "casting: above your health, growing up from the line")
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
sw.classes[S.class].off, sw.classes[S.class].ranged = true, true -- your class's rows
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
sw.classes[S.class].off, sw.classes[S.class].ranged = false, false
fire("UNIT_MAXPOWER")

-- Pet health: only with a pet; own value; on the line, left of your health
local pb = fr.pethealth
prof().regular.bars.pethealth.show = true; fire("UNIT_PET", "player")
assert(not pb:IsShown() and WolfpackAddonFrame._h == 48, "no pet: no bar")
S.petHP = 300; fire("UNIT_PET", "player")
assert(pb:IsShown() and pb.segs[1]._value == 300 and pb.segs[1]._max == 1000 and pb.text._text == "300", "pet bar")
assert(WolfpackAddonFrame._h == 48 and pb._point[4] == -454 and pb._point[5] == -4, "on the line, centered on it")
S.petHP = 120; fire("UNIT_HEALTH", "pet")
assert(pb.segs[1]._value == 120 and fr.health.segs[1]._value == SECRET, "pet updates on its own")
S.petHP = nil; fire("UNIT_PET", "player")
assert(not pb:IsShown() and WolfpackAddonFrame._h == 48 and fr.health._w == 220, "pet gone: your health as it is")
prof().regular.bars.pethealth.show = false

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
-- while you drink: your text on the power bar, where you put it
S.wasOpen2, ns.configOpen = ns.configOpen, false
S.DT = prof().regular.bars.power.drinkText
fire("UNIT_AURA", "player")
assert(not (fr.power.drinkText and fr.power.drinkText:IsShown()), "not drinking: nothing")
S.auras = { { name = "Drink", icon = 1 } }; fire("UNIT_AURA", "player")
assert(fr.power.drinkText:IsShown() and fr.power.drinkText._text == "Drinking" and fr.power.drinkText._point[1] == "LEFT"
    and fr.power.drinkText._point[2] == fr.power, "drinking: says so on the power bar")
assert(fr.power.drinkHost._scripts.OnUpdate, "flashing")
fr.power.drinkHost._scripts.OnUpdate(fr.power.drinkHost)
S.DT.text, S.DT.point, S.DT.x = "Glug", "CENTER", 7; fire("UNIT_AURA", "player")
assert(fr.power.drinkText._text == "Glug" and fr.power.drinkText._point[1] == "CENTER"
    and fr.power.drinkText._point[4] == 7, "your words, your spot")
S.DT.text, S.DT.point, S.DT.x, S.auras = "Drinking", "LEFT", 4, nil; fire("UNIT_AURA", "player")
assert(not fr.power.drinkText:IsShown() and not fr.power.drinkHost._scripts.OnUpdate
    and fr.power.drinkHost._alpha == 1, "done drinking: gone, no flashing")
-- and eating: the same on your health bar
S.auras = { { name = "Food", icon = 1 } }; fire("UNIT_AURA", "player")
assert(fr.health.eatText:IsShown() and fr.health.eatText._text == "Eating" and fr.health.eatHost._scripts.OnUpdate
    and not fr.power.drinkText:IsShown(), "eating: flashing on your health bar, not drinking")
S.auras = { { name = "Food & Drink", icon = 1 } }; fire("UNIT_AURA", "player")
assert(fr.health.eatText:IsShown() and fr.power.drinkText:IsShown(), "food and drink: both")
S.auras = nil; fire("UNIT_AURA", "player")
assert(not fr.health.eatText:IsShown() and fr.health.eatHost._alpha == 1, "done eating")
ns.configOpen = S.wasOpen2

-- buffs and debuffs on your own health bar, the same options as enemy health; all your debuffs
S.auras, S.debuffs = { { icon = 501 }, { icon = 502 } }, { { icon = 601 } }
fire("UNIT_AURA", "player")
S.hb2, S.hd2 = fr.health.auraIcons.buffs, fr.health.auraIcons.debuffs
assert(S.hb2[1]:IsShown() and S.hb2[2].tex._tex == 502 and S.hd2[1].tex._tex == 601, "your buffs and debuffs")
-- rows under your health: buffs (after the class buffs), then debuffs, each its icons' height
assert(fr.health.auraBoxes.buffs._point[2] == ns.auraSlots.buffs and fr.health.auraBoxes.debuffs._point[2]
    == ns.auraSlots.debuffs, "your buffs and debuffs on their rows")
assert(ns.auraSlots.buffs._point[4] == -332 and ns.auraSlots.buffs._point[5] == -20
    and ns.auraSlots.debuffs._point[5] == -20 - 20 - 2, "under your health, buffs first, the gap between")
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
assert(hs._sbc[1] == 1 and hs._sbc[3] == 0.41 and math.abs(hs.border._vertex[3] - 0.5575) < 1e-6
    and hs.border._vertex[1] == 1, "class bar, border = the bar's color, a quarter of the way to white")
-- the palette: the border shade, class, power and health colors live there, the bars pick
local PAL = prof().colors
PAL.borderShade = -50; fire("UNIT_MAXPOWER")
assert(math.abs(hs.border._vertex[1] - 0.5) < 1e-6 and math.abs(hs.border._vertex[3] - 0.205) < 1e-6,
    "shade -50: the class color halfway to black")
PAL.borderShade = 25
PAL.class.ROGUE = { 0.1, 0.2, 0.3, 1 }; fire("UNIT_MAXPOWER")
assert(hs._sbc[1] == 0.1 and hs._sbc[3] == 0.3, "class color as set on the Colors page")
PAL.class.ROGUE = { 1, 0.96, 0.41, 1 }
hc.colorMode = "health"; PAL.health = { 0.3, 0.6, 0.9, 1 }; fire("UNIT_MAXPOWER")
assert(hs._sbc[1] == 0.3 and hs._sbc[3] == 0.9, "health color from the palette")
PAL.health = { 0.2, 0.8, 0.2, 1 }
hc.colorMode, hc.borderMode = "custom", "custom"; fire("UNIT_MAXPOWER")
assert(hs._sbc[1] == 0.2 and hs.border._vertex[1] == 0, "custom bar, custom border")
hc.borderSize, hc.borderMode = 0, "custom"
-- border textures (shared, or the bar's own) and the palette's gradient overlays
;(function()
    local P, stripes, flat = PAL, "Interface\\AddOns\\WolfpackAddon\\Media\\Bar\\Stripes", "Interface\\Buttons\\WHITE8X8"
    local keptFrom, keptSize = hc.borderFrom, P.borderSize
    hc.borderFrom, P.borderSize, P.borderTexture = "shared", 2, stripes
    fire("UNIT_MAXPOWER")
    assert(hs.border._tex == stripes, "the shared border texture")
    hc.borderFrom, hc.borderSize, hc.borderTexture = "own", 2, flat
    fire("UNIT_MAXPOWER")
    assert(hs.border._tex == flat, "or the bar's own")
    hc.borderFrom = "shared"
    fire("UNIT_MAXPOWER")
    assert(not hs.shine:IsShown() and not hs.edgeShine:IsShown(), "no overlays to start")
    P.barShine.show, P.borderShine.show = true, true
    fire("UNIT_MAXPOWER")
    local g = hs.shine._grad
    assert(hs.shine:IsShown() and g[1] == "VERTICAL" and g[2][4] == 0 and g[3][4] == 0.25, "bar overlay, top to bottom")
    assert(hs.edgeShine:IsShown() and hs.edgeShine._grad[3][1] == 1, "border overlay")
    P.barShine.dir = "right"
    fire("UNIT_MAXPOWER")
    assert(hs.shine._grad[1] == "HORIZONTAL" and hs.shine._grad[2][4] == 0.25, "or left to right")
    -- either end can take the bar's color, at the swatch's opacity
    P.barShine.fromMode = "bar"
    fire("UNIT_MAXPOWER")
    local from = hs.shine._grad[2]
    assert(from[1] == hs.rgb[1] and from[2] == hs.rgb[2] and from[3] == hs.rgb[3] and from[4] == 0.25
        and hs.shine._grad[3][1] == 1, "from: the bar's color, to: its own")
    P.barShine.fromMode = "custom"
    P.borderSize = 0
    fire("UNIT_MAXPOWER")
    assert(not hs.edgeShine:IsShown(), "no border, no border overlay")
    -- the empty bar: a shape under the fill, its size and corners, in place of the background
    assert(hs.bg:IsShown() and not hs.empty:IsShown(), "no empty bar to start: the background")
    local E, stripes2 = P.emptyBar, "Interface\\AddOns\\WolfpackAddon\\Media\\Bar\\Stripes"
    E.show, E.texture, E.darken = true, stripes2, 50
    fire("UNIT_MAXPOWER")
    local em = hs.empty
    assert(em:IsShown() and not hs.bg:IsShown() and em._tex == stripes2 and em._layer == nil
        and math.abs(em._vertex[2] - hs.rgb[2] / 2) < 1e-9 and em._vertex[4] == 1, "the bar's color, darker, own texture")
    E.mode = "custom"
    fire("UNIT_MAXPOWER")
    assert(em._vertex[1] == 0.1 and em._vertex[4] == 1, "or a color of its own")
    E.show, E.mode, E.darken = false, "bar", 70
    fire("UNIT_MAXPOWER")
    assert(hs.bg:IsShown() and not em:IsShown(), "off: the background again")
    -- inner shadow: strips fading in from the edges, the offset thickening the far side; over
    -- the fill or between border and bar. Drop shadow: behind the border, offset
    P.borderSize = 2
    fire("UNIT_MAXPOWER")
    assert(not hs.inner[1]:IsShown() and not hs.drop:IsShown(), "no shadows to start")
    P.innerShadow.show, P.dropShadow.show = true, true
    fire("UNIT_MAXPOWER")
    local top, bottom, left = hs.inner[1], hs.inner[2], hs.inner[3]
    assert(top._h == 6 and bottom._h == 2 and left._w == 4 and top._layer[1] == "ARTWORK"
        and top._grad[3][4] == 0.6 and top._grad[2][4] == 0 and top._point[2] == hs, "inner: over the fill, top darker")
    P.innerShadow.on, P.innerShadow.y = "border", 2
    fire("UNIT_MAXPOWER")
    assert(top._h == 2 and bottom._h == 6 and top._layer[1] == "BACKGROUND" and top._layer[2] == -6
        and top._point[2] == hs.border, "or between border and bar")
    P.innerShadow.size, P.innerShadow.y = 0, 0
    fire("UNIT_MAXPOWER")
    assert(not top:IsShown(), "size 0: none")
    local d = hs.drop
    assert(d:IsShown() and d._tex:find("Shadow\\s4.tga") and d._points[1][2] == hs.border and d._points[1][4] == -2
        and d._points[1][5] == 2 and d._points[2][4] == 6 and d._points[2][5] == -6, "drop shadow: soft, offset")
    -- spread grows the shape (negative: shrinks it); the bar's own drop shadow hangs on the fill
    P.dropShadow.spread, P.barShadow.show, P.barShadow.spread = -3, true, 1
    fire("UNIT_MAXPOWER")
    local bd = hs.barDrop
    assert(d._points[1][4] == 1 and d._points[1][5] == -1 and d._points[2][4] == 3 and d._points[2][5] == -3,
        "spread -3: the border's shadow 3 smaller each side")
    assert(bd:IsShown() and bd._points[1][2] == hs and bd._points[1][4] == -3 and bd._points[1][5] == 3
        and bd._points[2][4] == 5 and bd._tex:find("s3.tga") and bd._vertex[4] == 0.6, "the bar's drop shadow")
    P.innerShadow.show, P.innerShadow.on, P.innerShadow.size, P.innerShadow.y = false, "bar", 4, -2
    P.dropShadow.show, P.dropShadow.spread, P.barShadow.show, P.barShadow.spread = false, 0, false, 0
    fire("UNIT_MAXPOWER")
    assert(not d:IsShown() and not left:IsShown() and not bd:IsShown(), "all off again")
    P.barShine.show, P.borderShine.show, P.barShine.dir = false, false, "down"
    hc.borderFrom, P.borderSize, P.borderTexture = keptFrom, keptSize, flat
    fire("UNIT_MAXPOWER")
    -- frame art: edges laid end to end and cut to the bar, corners over them, cut to half the bar
    local keptW, keptH = hc.width, hc.height
    hc.width, hc.height, P.frameArt.show, P.frameArt.size, P.frameArt.offset = 400, 40, true, 9, 2
    fire("UNIT_MAXPOWER")
    local by = {}
    for _, t in ipairs(hs.art) do
        if t:IsShown() then local n = t._tex:match("(%w+)%.tga$"); by[n] = by[n] or {}; table.insert(by[n], t) end
    end
    local function near(a, b) return math.abs(a - b) < 1e-9 end
    assert(#by.top == 2 and by.top[1]._w == 335 and near(by.top[2]._w, 29) and by.top[1]._points[1][4] == 18
        and by.top[2]._points[1][4] == 353 and near(by.top[1]._coords[2], 338 / 512) and by.top[1]._h == 9,
        "404 px, 364 between the bends: the top edge twice, the second cut")
    assert(#by.side == 2 and by.side[1]._h == 4 and by.side[1]._points[1][5] == -18 and by.side[2]._coords[1] == 9 / 16
        and by.side[2]._coords[2] == 0 and near(by.side[1]._coords[4], 7 / 256),
        "44 px high: one side piece each, cut, the right one mirrored")
    local br = by.br[1]
    assert(br._w == 52 and br._h == 22 and br._layer[2] == -1 and by.top[1]._layer[2] == -2
        and near(br._coords[3], 25 / 64) and near(br._coords[4], 47 / 64) and br._points[1][4] == 2
        and br._points[1][5] == -2, "a corner over the edges, cut to half the bar from its outer edge")
    hc.height = 10
    fire("UNIT_MAXPOWER")
    assert(near(by.top[1]._h, 9 * 14 / 40), "a small bar: thinner, so both bends fit")
    P.frameArt.show = false
    fire("UNIT_MAXPOWER")
    for _, t in ipairs(hs.art) do assert(not t:IsShown(), "off: no frame") end
    hc.width, hc.height = keptW, keptH
    fire("UNIT_MAXPOWER")
end)()
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
-- over your health on the line (left of the middle column), and over power below it
R0.bars.pethealth.show, R0.bars.tothealth.show = false, false; fire("UNIT_MAXPOWER")
S.top0 = R0.y + ns.gridTop -- the frame's top edge
assert(ck._point[1] == "TOPLEFT" and ck._point[2] == UIParent and ck._point[3] == "CENTER" and ck._point[4] == R0.x - 332
    and ck._point[5] == S.top0 + fr.health._point[5] and ck._w == 220 and ck._h == 18 and ck:IsShown(),
    "exactly over your health bar")
assert(cp._point[4] == R0.x - 110 and cp._point[5] == S.top0 + fr.power._point[5] and cp._w == 220 and cp._h == 14,
    "and over power")
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
-- enemy health: its own button, unit "target", right-click menu only, shown by the unit watch;
-- placed with no target yet, where the bar will be
local ct = WolfpackAddonClickerTarget
assert(ct and ct._attr.unit == "target" and ct._attr.type2 == "togglemenu" and not ct._attr.type1, "target menu button")
R0.bars.enemyhealth.show = true; fire("UNIT_MAXPOWER")
assert(ct._watched and ct._point[1] == "TOPLEFT" and ct._point[4] == R0.x + 112 and ct._w == 220 and ct._h == 18,
    "right of the middle column, watched for a target")
R0.targetMenu = false; fire("UNIT_MAXPOWER")
assert(not ct._watched and not ct:IsShown(), "option off: gone")
R0.targetMenu, R0.bars.enemyhealth.show = true, false; fire("UNIT_MAXPOWER")
assert(not ct._watched, "enemy health hidden: no button")
-- your pet and your target's target: a menu each, shown by the unit watch, on their own columns
S.PB, S.TT = R0.bars.pethealth, R0.bars.tothealth
S.PB.show, S.petHP = true, 100; fire("UNIT_PET", "player")
S.cpet = WolfpackAddonClickerPet
assert(S.cpet and S.cpet._attr.unit == "pet" and S.cpet._attr.type2 == "togglemenu" and S.cpet._watched,
    "pet: a menu, while there is a pet")
assert(S.cpet._attr.type1 == "target", "left click targets your pet")
assert(S.cpet._point[2] == UIParent and S.cpet._point[4] == R0.x - 334 - S.PB.width and S.cpet._w == S.PB.width,
    "over the pet's column")
R0.petMenu = false; fire("UNIT_PET", "player")
assert(not S.cpet._watched, "pet menu off")
R0.petMenu, S.PB.show, S.petHP = true, false, nil
R0.bars.enemyhealth.show, S.TT.show = true, true; fire("UNIT_MAXPOWER")
S.ctot = WolfpackAddonClickerToT
assert(S.ctot and S.ctot._attr.unit == "targettarget" and S.ctot._attr.type1 == "target" and S.ctot._watched
    and S.ctot._point[4] == R0.x + 334 and S.ctot._w == S.TT.width, "target of target: over its column")
S.TT.show, R0.bars.enemyhealth.show = false, false; fire("UNIT_MAXPOWER")

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
local kp, lp = h.kill._point, h.loot._point
assert(lp[1] == "TOPRIGHT" and lp[2] == h and lp[3] == "TOPRIGHT" and lp[4] == 0 and lp[5] == 0,
    "Blizzard's plate: the bag in its top-right corner")
assert(kp[1] == "RIGHT" and kp[2] == h.loot and kp[3] == "LEFT" and kp[4] == -2 and h.kill._tex == 131013,
    "the sword left of the bag")
-- how many are left, from the tooltip's "3/10" (kill) and "2/6" (item)
local Q = prof().quest
assert(not h.badge.kill.text:IsShown(), "no numbers unless asked")
Q.kill.count, Q.loot.count = true, true
fire("QUEST_LOG_UPDATE")
assert(h.badge.kill.text:IsShown() and h.badge.kill.text._text == 7, "7 kills left")
assert(h.badge.loot.text._text == 4 and h.badge.loot.bg._color[1] == 0, "4 items left, black plate")
assert(h.badge.kill.bg._point[1] == "BOTTOM" and h.badge.kill.bg._point[2] == h.kill and h.badge.kill.bg._point[3] == "TOP"
    and h.badge.kill.text._point[2] == h.badge.kill.bg, "the plate centered above the icon, the number in it")
assert(h.badge.kill.bg._w == 12 and h.badge.kill.bg._h == 14, "plate hugs the number, 2 px padding")
Q.kill.fontSize, Q.kill.textColor, Q.kill.bg, Q.kill.radius, Q.kill.pad = 14, { 1, 0.8, 0, 1 }, { 0.2, 0, 0, 0.5 }, 4, 3
fire("QUEST_LOG_UPDATE")
local kb = h.badge.kill
assert(kb.text._font[2] == 14 and kb.text._color[2] == 0.8 and kb.bg._color[1] == 0.2 and kb.bg._w == 14
    and kb.bg._masks[kb.mask] and kb.mask.r == 4 and kb.bg._h == 16, "number font, color, plate color, radius, padding")
-- the number sits where its spot says, nudged; the plate grows with it
Q.kill.countSpot, Q.kill.countX, Q.kill.countY = "inside", -1, 2
kb.text.GetStringWidth = function(self) return #tostring(self._text) * 6 end
fire("QUEST_LOG_UPDATE")
assert(kb.bg._point[1] == "TOPRIGHT" and kb.bg._point[2] == h.kill and kb.bg._point[4] == -1 and kb.bg._point[5] == 2,
    "inside the icon's top right, 1 left and 2 up")
assert(kb.bg._w == 6 + 6, "one digit: its width plus padding")
S.keptLeft, ns.QUEST_DUMMY.left.kill, S.wasOpenQ = ns.QUEST_DUMMY.left.kill, 12, ns.configOpen
ns.configOpen = true; fire("QUEST_LOG_UPDATE")
assert(kb.text._text == 12 and kb.bg._w == 12 + 6, "two digits: a wider plate")
ns.QUEST_DUMMY.left.kill, ns.configOpen = S.keptLeft, S.wasOpenQ
kb.text.GetStringWidth = nil
Q.kill.countSpot, Q.kill.countX, Q.kill.countY = "abovecenter", 0, 1
Q.kill.fontSize, Q.kill.textColor, Q.kill.bg, Q.kill.radius, Q.kill.pad = 10, { 1, 1, 1, 1 }, { 0, 0, 0, 0.8 }, 0, 2
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
assert(h.loot._point[2] == h and h.loot._point[1] == "TOPRIGHT", "the bag stays in its corner")
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
assert(h.kill._point[2] == h and h.kill._point[1] == "TOPRIGHT", "the bag not there: the sword takes its place")
Q.loot.anchorTo = "other"; fire("QUEST_LOG_UPDATE")
assert(h.kill._point[2] == h, "both on each other: the sword takes the plate")
Q.loot.anchorTo = "bar"
S.tips.nameplate1 = { { type = L.QuestObjective, leftText = SECRET } }
fire("QUEST_LOG_UPDATE")
assert(h.kill:IsShown(), "secret tooltip keeps the last answer")
S.related.nameplate1 = false
fire("QUEST_LOG_UPDATE")
assert(not h.kill:IsShown() and not h.loot:IsShown(), "not a quest mob")
S.related.nameplate1 = true; S.tips.nameplate1 = {}
fire("QUEST_LOG_UPDATE")
-- no quest lines on the tooltip (Classic Era, Anniversary): Questie's list for this creature
S.related.nameplate1 = false
Questie = { ICON_TYPE_SLAY = 1, ICON_TYPE_LOOT = 2, ICON_TYPE_OBJECT = 4 }
local qtips = { lookupByKey = { m_448 = {
    a = { objective = { Icon = 2, Needed = 6, Collected = 2, Completed = false } },
    b = { objective = { Icon = 1, Needed = 5, Collected = 5, Completed = true } } } } }
QuestieLoader = { ImportModule = function(_, name) return name == "QuestieTooltips" and qtips or {} end }
local keptNpc = S.npc
S.npc = "Creature-0-1-2-3-448-0000ABCD"
fire("QUEST_LOG_UPDATE")
assert(h.loot:IsShown() and not h.loot._desat and not h.kill:IsShown() and h.badge.loot.text._text == 4,
    "Questie: a drop, 4 left; its done kill objective hidden")
qtips.lookupByKey.m_448.b.objective.Completed = false
qtips.lookupByKey.m_448.b.objective.Collected = 1
fire("QUEST_LOG_UPDATE")
assert(h.kill:IsShown() and h.badge.kill.text._text == 4, "Questie: a kill, 4 left")
S.npc = "Creature-0-1-2-3-999-0000ABCD"
fire("QUEST_LOG_UPDATE")
assert(not h.kill:IsShown() and not h.loot:IsShown(), "Questie: not one of yours")
Questie, QuestieLoader, S.npc = nil, nil, keptNpc
S.related.nameplate1 = true
fire("QUEST_LOG_UPDATE")
fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
assert(not h.kill:IsShown() and not ns.plateUnits.nameplate1, "removed plate cleared")
fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert(ns.plateUnits.nameplate1 == h, "recycled plate reuses its holder")
-- settings open: every row shows both icons, counts too, to place them by; closed, the real ones
S.related.nameplate1 = false
fire("QUEST_LOG_UPDATE")
assert(not h.kill:IsShown(), "nothing needed from this mob")
S.wasOpen = ns.configOpen
ns.configOpen = true; fire("UNIT_MAXPOWER")
assert(h.kill:IsShown() and h.loot:IsShown(), "settings open: dummy icons")
ns.configOpen = false; fire("UNIT_MAXPOWER")
assert(not h.kill:IsShown() and not h.loot:IsShown(), "closed: the real ones again")
ns.configOpen = S.wasOpen

-- Plates: a bar of ours on every nameplate, Blizzard's own plate made invisible
;(function()
    local P, plate = prof().plates.bars.enemyhealth, new()
    plate.UnitFrame = new()
    S.plates.nameplate4 = plate
    S.units = S.units or {}; S.units.nameplate4 = "NONE" -- a plate's unit exists
    local function npFire(e, u) ns.npEv._scripts.OnEvent(ns.npEv, e, u) end
    npFire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    fire("NAME_PLATE_UNIT_ADDED", "nameplate4") -- the quest icon holder
    assert(not ns.np.units.nameplate4 and P.show == false, "off to start: Blizzard's plates stay")
    P.show = true
    ns.np.all()
    local f = ns.np.units.nameplate4
    assert(f and f._parent == plate and f:IsShown() and f.unit == "nameplate4" and f.resFrame.unit == "nameplate4",
        "turned on: a bar on the plate already up, for its unit")
    assert(f._point[1] == "CENTER" and f._point[2] == plate, "centered on the plate")
    assert(not plate.UnitFrame:IsShown(), "Blizzard's plate hidden (its highlight ignores alpha)")
    plate.UnitFrame:Show(); plate.UnitFrame._scripts.OnShow(plate.UnitFrame)
    assert(not plate.UnitFrame:IsShown(), "and kept so when the game shows it")
    assert(f.tag_name:IsShown() and f.tag_level:IsShown(), "name and level")
    assert(f.tag_name._text == UnitName("nameplate4"), "the unit's own name")
    -- stand-in auras belong to the preview only: a real plate never wears them, open options,
    -- unlocked bars or not, and closing the options in combat (no aura data) leaves none behind
    local function dummies()
        for _, k in ipairs({ "buffs", "debuffs" }) do
            for _, b in ipairs(f.auraIcons[k]) do if b:IsShown() then return true end end
        end
    end
    local wasOpen, wasLocked = ns.configOpen, prof().locked
    ns.configOpen, prof().locked = true, false; ns.np.all()
    assert(not dummies(), "no dummy auras on a real plate while placing")
    ns.configOpen, prof().locked = wasOpen, wasLocked
    S.combat = true; ns.np.all(); S.combat = nil
    assert(not dummies(), "and none left after")
    assert(f.tag_name._justify == "CENTER", "a name on the TOP anchor centers (the game takes no TOP)")
    -- the name sits on any of the bar's nine points, nudged by X / Y
    P.nameAnchor, P.nameX, P.nameY, P.tagAttach = "BOTTOMRIGHT", 3, -4, "free"
    ns.np.all()
    local np = f.tag_name._point
    assert(np[1] == "TOPRIGHT" and np[2] == f and np[3] == "BOTTOMRIGHT" and np[4] == 3 and np[5] == -4
        and f.tag_name._justify == "RIGHT", "bottom right: under the bar, right-aligned, 3 right and 4 down")
    P.tagAttach = "right"
    ns.np.all()
    assert(f.tag_level._point[1] == "TOPRIGHT" and f.tag_level._point[3] == "BOTTOMRIGHT" and f.tag_level._point[2] == f,
        "level beside it, on its side: takes its spot")
    P.nameAnchor, P.nameX, P.nameY = "TOP", 0, 12
    ns.np.all()
    -- the level right of a centered name: the two centered as one (gap 4 + level 8 + its padding 4)
    assert(f.tag_name._point[1] == "BOTTOM" and f.tag_name._point[3] == "TOP" and f.tag_name._point[4] == -8
        and f.tag_level._point[2] == f.tag_name.box, "on top of the bar: name and level centered together")
    P.tagAttach = "left"
    ns.np.all()
    -- on the left its gap of 4 points toward the name: it adds 8 + 4 padding - 4 = 8
    assert(f.tag_name._point[4] == 4, "the level on the left: the name moves right by half of it")
    -- the PvP tag on the name counts too: level right (16) and a 20 px tag right of the name, 2 off
    P.tagAttach = "right"
    S.pvpKept, S.openKept = {}, ns.configOpen
    for k, v in pairs(P.pvpIcon) do S.pvpKept[k] = v end
    P.pvpIcon.show, P.pvpIcon.anchorTo, P.pvpIcon.point, P.pvpIcon.x, P.pvpIcon.y = true, "name", "RIGHT", 2, 0
    ns.configOpen = true -- placing: the tag shows
    ns.np.all()
    assert(f.pvpIcon:IsShown() and f.tag_name._point[4] == -19, "level and PvP tag on the right: the row centered")
    P.pvpIcon.point, P.pvpIcon.x = "LEFT", -2
    ns.np.all()
    assert(f.tag_name._point[4] == 3, "tag on the left, level on the right: (22 - 16) / 2")
    P.pvpIcon.anchorTo = "bar"
    ns.np.all()
    assert(f.tag_name._point[4] == -8, "a tag on the bar is not part of the row")
    P.tagAttach, P.pvpIcon.anchorTo, P.pvpIcon.point, P.pvpIcon.x = "left", "name", "RIGHT", 0
    ns.np.all()
    assert(f.tag_name._point[4] == (8 - 20) / 2, "level left, PvP right (as in game): centered as a row")
    -- on a right anchor the row ends at the bar's right edge, PvP tag and all (seen in game)
    P.nameAnchor = "TOPRIGHT"
    ns.np.all()
    assert(f.tag_name._point[1] == "BOTTOMRIGHT" and f.tag_name._point[4] == P.nameX - 20,
        "top right: the name moves left by the tag right of it")
    -- on a left anchor it starts at the left edge, with a tag left of the name
    P.nameAnchor, P.tagAttach, P.pvpIcon.point = "TOPLEFT", "right", "LEFT"
    ns.np.all()
    assert(f.tag_name._point[4] == P.nameX + 20, "top left: the name moves right by the tag left of it")
    P.nameAnchor, P.pvpIcon.point = "TOP", "RIGHT"
    P.tagAttach = "right"
    P.pvpIcon, ns.configOpen = S.pvpKept, S.openKept
    P.nameAnchor, P.tagAttach = "LEFT", "right"
    ns.np.all()
    assert(f.tag_name._point[2] == f and f.tag_name._point[4] == P.nameX, "a name on the left keeps its spot")
    P.nameAnchor, P.tagAttach = "TOP", "right"
    ns.np.all()
    local r = f.resFrame
    assert(r:IsShown() and r._point[1] == "TOP" and r._point[2] == f and r._point[3] == "BOTTOM", "power underneath")
    P.resPlace = "inside"; ns.np.all()
    assert(r._point[1] == "BOTTOM" and r._point[3] == "BOTTOM", "or inside it")
    P.resPlace, P.resPoint = "outside", "LEFT"; ns.np.all()
    assert(r._point[1] == "RIGHT" and r._point[3] == "LEFT", "or hung on any edge")
    P.resource = false; ns.np.all()
    assert(not r:IsShown(), "or hidden")
    P.resource, P.resPoint = true, "BOTTOM"
    -- each quest icon hangs on a part of our plate, where Sits says; a part not shown: the bar
    local h, QL = ns.plateUnits.nameplate4, prof().quest.loot
    QL.spot = "above"; ns.np.all()
    assert(h.loot._point[1] == "BOTTOMRIGHT" and h.loot._point[2] == f and h.loot._point[3] == "TOPRIGHT", "bag above the bar")
    QL.anchorTo, QL.spot, QL.x, QL.y = "res", "belowcenter", 3, -1; ns.np.all()
    assert(h.loot._point[2] == f.resFrame and h.loot._point[1] == "TOP" and h.loot._point[3] == "BOTTOM"
        and h.loot._point[4] == 3 and h.loot._point[5] == -1, "under the power bar, x / y on top")
    QL.anchorTo = "name"; ns.np.all()
    assert(h.loot._point[2] == f.tag_name.box, "on the name")
    QL.anchorTo = "buffs"; ns.np.all()
    assert(h.loot._point[2] == f, "buffs off: the bar instead")
    QL.anchorTo, QL.spot, QL.x, QL.y = "cast", "right", 0, 0; ns.np.all()
    assert(h.loot._point[2] == f, "no cast going: the bar")
    -- the bar's own settings are enemy health's, of this layout only
    P.width = 150; ns.np.all()
    assert(f.width == 150 and prof().regular.bars.enemyhealth.width ~= 150, "its own width")
    npFire("UNIT_HEALTH", "nameplate4")
    npFire("NAME_PLATE_UNIT_REMOVED", "nameplate4")
    fire("NAME_PLATE_UNIT_REMOVED", "nameplate4")
    assert(not f:IsShown() and not ns.np.units.nameplate4 and plate.UnitFrame:IsShown(), "removed: Blizzard's back")
    npFire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    assert(ns.np.units.nameplate4 == f, "a recycled plate keeps its bar")
    -- its cast bar: only while that unit casts, under the power bar hanging below
    S.npOpen, S.npLocked, ns.configOpen, prof().locked = ns.configOpen, prof().locked, false, true
    local cb = f.castBar
    ns.np.all()
    assert(not cb:IsShown(), "no cast, no cast bar")
    S.keptInfo = UnitCastingInfo
    UnitCastingInfo = function(u) if u == "nameplate4" then return "Fireball", "", 135812, 0, 0 end end
    npFire("UNIT_SPELLCAST_START", "nameplate4")
    assert(cb:IsShown() and cb.text._text == "Fireball" and cb.unit == "nameplate4", "its own unit's cast")
    assert(h.loot._point[2] == cb, "the bag moves onto the cast bar while it shows")
    assert(cb._point[1] == "TOP" and cb._point[2] == f.resFrame and cb._point[3] == "BOTTOM", "under the power bar")
    assert(not ns.frames.targetcast:IsShown() or ns.targetCasting, "your target's cast bar is not touched")
    npFire("UNIT_SPELLCAST_STOP", "nameplate4")
    assert(not cb:IsShown(), "gone when it stops")
    npFire("NAME_PLATE_UNIT_REMOVED", "nameplate4")
    npFire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    assert(cb:IsShown(), "a plate that comes into view mid-cast shows it")
    UnitCastingInfo = S.keptInfo
    npFire("UNIT_SPELLCAST_STOP", "nameplate4")
    -- the target trail: a stroke running round the target's health bar, cut into pieces per edge,
    -- fading from tail to head, joined at the corners, a round dot on each end
    local T = prof().plates.trail
    S.keptPlate, S.plate = S.plate, plate
    -- your target's plate wears the targeted look, and the standard one again once you look away
    local PT = prof().platesTarget.bars.enemyhealth
    assert(PT.show and not prof().platesTarget.trail, "a targeted look of its own, the trail not in it")
    PT.width, prof().platesTarget.x = 150, 7
    npFire("PLAYER_TARGET_CHANGED")
    assert(f.mode == "platesTarget" and f.width == 150 and f._point[4] == 7 and f.castBar.mode == "platesTarget",
        "targeted: its own size and spot")
    S.plate = nil; npFire("PLAYER_TARGET_CHANGED")
    assert(f.mode == "plates" and f._point[4] == prof().plates.x, "not targeted: the standard look")
    PT.show, S.plate = false, plate; npFire("PLAYER_TARGET_CHANGED")
    assert(f.mode == "plates", "the targeted look can be turned off")
    PT.show = true
    T.show = true
    npFire("PLAYER_TARGET_CHANGED")
    local tr = ns.np.trailFrame
    assert(tr:IsShown() and tr._parent == f and tr.bar == f, "on the target's plate")
    f.edge, T.length = 0, 20
    tr.head = 0.1 -- the path: 150 x 10, 320 round; the head 32 along the top, the tail 12
    ns.np.trailDraw(tr)
    local l1, l2 = tr.lines[1], tr.lines[2]
    assert(l1:IsShown() and not l2:IsShown() and l1._w == 20 and l1._h == 2 and l1._point[4] == 12
        and l1._point[5] == 9, "one piece along the top")
    assert(l1._grad[1] == "HORIZONTAL" and l1._grad[2][4] == 0 and l1._grad[3][4] == 1, "fading in from the tail")
    assert(tr.glows[1]:IsShown() and tr.glows[1]._w == 32 and tr.caps[1]._point[4] == 32, "glow round it, a cap on the head")
    tr.head = 0.5 -- the head 160 along: round the top right corner
    ns.np.trailDraw(tr)
    assert(l1._w == 11 and l2:IsShown() and l2._w == 2 and l2._h == 11 and l2._point[4] == 149 and l2._point[5] == 0
        and l2._grad[1] == "VERTICAL" and l2._grad[2][4] == 1 and math.abs(l2._grad[3][4] - 0.5) < 1e-9,
        "two pieces joined at the corner, the fade running on down the right side")
    tr.head = 0.5
    tr._scripts.OnUpdate(tr, T.states.idle.lap / 4)
    assert(math.abs(tr.head - 0.75) < 1e-9, "a quarter of the round in a quarter of the lap")
    -- what the target is up to: green and slow when just targeted, red and fast in combat,
    -- flashing too when it has you targeted
    local St = T.states
    tr.head = 0.1 -- on the top: the gradient's second color is the head's
    ns.np.trailDraw(tr)
    assert(tr.state == "idle" and l1._grad[3][1] == 0.25 and St.idle.lap > St.combat.lap, "targeted: green, slow")
    S.keptUAC, S.keptTT = UnitAffectingCombat, S.targetUnit
    UnitAffectingCombat = function(u) return u == "target" end
    tr.poll = 0
    tr._scripts.OnUpdate(tr, 0)
    assert(tr.state == "combat" and l1._grad[3][1] == 1 and l1._grad[3][2] == 0.2
        and math.abs(l1._grad[3][4] - 1) < 1e-9, "in combat: red, steady")
    S.keptUII = UnitIsUnit
    UnitIsUnit = function(a, b) return (a == "targettarget" and b == "player") or S.keptUII(a, b) end
    tr.poll, tr.clock = 0, 1 / (2 * T.flashRate) - 0 -- half a flash in: at its dimmest
    tr._scripts.OnUpdate(tr, 0)
    assert(tr.state == "aggro" and l1._grad[3][1] == 1 and math.abs(l1._grad[3][4] - 0.25) < 1e-6, "aggro: flashing")
    tr._scripts.OnUpdate(tr, 0.05) -- polled again only every 0.2 s
    assert(tr.poll > 0, "polled, not every frame")
    UnitAffectingCombat, UnitIsUnit = S.keptUAC, S.keptUII
    tr.poll = 0
    tr._scripts.OnUpdate(tr, 0)
    assert(tr.state == "idle", "out of combat: back to green")
    T.glow, T.caps = false, false
    ns.np.trailDraw(tr)
    assert(not tr.glows[1]:IsShown() and not tr.caps[1]:IsShown(), "glow and caps can go")
    S.plate = nil
    npFire("PLAYER_TARGET_CHANGED")
    assert(not tr:IsShown(), "no target, no trail")
    T.show, T.glow, T.caps, T.length, S.plate = false, true, true, 15, S.keptPlate
    ns.configOpen, prof().locked = S.npOpen, S.npLocked
    P.show = false; ns.np.all()
    assert(not f:IsShown() and plate.UnitFrame:IsShown(), "turned off: Blizzard's plates again")
    npFire("NAME_PLATE_UNIT_REMOVED", "nameplate4")
    fire("NAME_PLATE_UNIT_REMOVED", "nameplate4")
    QL.anchorTo, QL.spot, S.units.nameplate4 = "bar", "inside", nil
end)()

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
local nameBox, gapBox, xBox, yBox = boxes[1], boxes[2], boxes[4], boxes[5]
boxes[3]._text = "180"; boxes[3]._scripts.OnEnterPressed(boxes[3])
assert(prof().regular.centerWidth == 180 and fr.combo._w == 220 and fr.power._point[4] == -110, "the middle column: bars keep their width")
assert(fr.health._point[4] == -90 - 2 - 220, "your health moves in with it")
prof().regular.centerWidth = 220
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
assert(prof().regular.x == 0 and prof().regular.y == 50 - ns.gridTop and not mover._scripts.OnUpdate,
    "drag stores the line (the top, less what is above the line)")

-- Sidebar: Nameplates is the enemy nameplate, its health bar and its cast bar, apart from
-- Combat Display; the bar picked there comes back on leaving
byText("Nameplates")._scripts.OnClick(byText("Nameplates"), "LeftButton")
assert(gapBox._text == "2" and xBox._text == "0" and yBox._text == "0", "the nameplate's own values")
gapBox._text = "4"; gapBox._scripts.OnEnterPressed(gapBox)
boxes[6]._text = "130"; boxes[6]._scripts.OnEnterPressed(boxes[6])
assert(prof().plates.gap == 4 and prof().plates.bars.enemyhealth.width == 130, "nameplate edits")
assert(ns.np.preview:IsShown() and ns.np.preview.width == 130 and ns.np.preview._point[2] == ns.cfg,
    "a preview plate beside the window while the page is open")
assert(not byText("Target bars") and byText("Health"), "one nameplate: no second bar stack")
ns.tagAnchorMenus.name:GenerateMenu()
assert(#ns.tagAnchorMenus.name._items == 9 and ns.tagAnchorMenus.name._items[4].sel(), "nine anchor points, Top picked")
byText("Cast bar")._scripts.OnClick(byText("Cast bar"), "LeftButton")
boxes[6]._text = "100"; boxes[6]._scripts.OnEnterPressed(boxes[6])
assert(prof().plates.bars.targetcast.width == 100 and prof().plates.bars.enemyhealth.width == 130, "its cast bar")
assert(ns.np.preview.castBar:IsShown() and ns.np.preview.castBar.width == 100, "previewed under it")
assert(prof().regular.gap == 30 and prof().regular.x == 0 and prof().regular.bars.health.width == 220, "regular untouched")
-- Targeted: the same editor on your target's plate's own look, with the trail listed there too
local function click(t) byText(t)._scripts.OnClick(byText(t), "LeftButton") end
click("Targeted")
byText("Health")._scripts.OnClick(byText("Health"), "LeftButton")
assert(boxes[6]._text == tostring(prof().platesTarget.bars.enemyhealth.width), "the targeted look's values")
boxes[6]._text = "160"; boxes[6]._scripts.OnEnterPressed(boxes[6])
assert(prof().platesTarget.bars.enemyhealth.width == 160 and prof().plates.bars.enemyhealth.width == 130,
    "edits the targeted look only")
assert(ns.np.preview.mode == "platesTarget" and ns.np.preview.width == 160, "the preview wears it")
click("Trail")
assert(ns.trailPage:IsShown() and not ns.pages.combat:IsShown(), "the trail opens in place of a bar")
click("Standard")
assert(ns.pages.combat:IsShown() and not ns.trailPage:IsShown() and ns.np.preview.mode == "plates"
    and boxes[6]._text == "130", "back on the standard look")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
assert(not ns.np.preview:IsShown() and boxes[6]._text == "220", "back on Combat Display's health bar")
-- every sidebar entry is really there, opens its page, and that page has settings on it
-- the class pages are gone: no Mage, Rogue, Shaman or Warlock entry, nor their settings
for _, name in ipairs({ "Mage", "Warlock", "Shaman" }) do assert(not byText(name), name .. " is gone") end
assert(prof().mage == nil and prof().warlock == nil and prof().rogue == nil, "and their settings")
for _, name in ipairs({ "Combat Display", "Nameplates", "Other" }) do
    local b = byText(name)
    assert(b, "sidebar entry missing: " .. name)
    b._scripts.OnClick(b, "LeftButton")
end
-- The window is 680 wide and scrolls; each page's columns 3 and 4 sit under columns 1 and 2
assert(ns.cfg._w == 680, "a third narrower than the old 998")
local function regionWithText(page, text)
    for _, r in ipairs({ page:GetRegions() }) do if r._text == text then return r end end
end
local colors, bars = regionWithText(ns.pages.combat, "Colors"), regionWithText(ns.pages.combat, "Bars")
assert(bars._point[2] == 28 and bars._point[3] == -112, "column 1 stays")
assert(colors._point[1] == "TOPLEFT" and colors._point[2] == ns.pages.combat and colors._point[4] == 28
    and colors._point[5] < -400, "column 3 moved under column 1")
assert(regionWithText(ns.pages.combat, "Gradient")._point[4] == 238, "column 4 under column 2")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
assert(ns.pages.combat.need > 1000 and ns.content._h == ns.pages.combat.need - 90 + 16,
    "the scroll area is as tall as the page")
-- Profiles has its own page; the header names the profile in use and opens that page
assert(byText("Export") and byText("Import") and byText("Reset to defaults") and byText("Create"), "profile page")
S.pp = byText("Create")._parent
assert(ns.boxesOn[S.pp] == 5 and regionWithText(S.pp, "|cffffd1001|r   Pick the parent")
    and regionWithText(S.pp, "Loaded now") and regionWithText(S.pp, "Manage"),
    "five cards: 1 the parent, 2 it or a child, loaded now, manage, share")
local inUse
for _, f in ipairs(created) do
    if type(f._text) == "string" and f._text:find("^Profile: ") then inUse = f end
end
assert(inUse and inUse._text:find(WolfpackAddonDB.chars[S.name .. " - Realm"], 1, true), "header names the profile")
inUse._scripts.OnClick(inUse, "LeftButton")
assert(ns.pages.profile:IsShown() and not ns.pages.combat:IsShown(), "header opens the Profiles page")
-- one icon everywhere: the title bar, and (toc) the AddOns list and the compartment
assert(ns.cfg.wpLogo._tex == ns.ICON and ns.cfg.TitleText._point[2] == ns.cfg.wpLogo, "the paw in the title bar")
assert(io.open("WolfpackAddon/WolfpackAddon.toc"):read("*a"):find("## IconTexture: " .. ns.ICON, 1, true),
    "the toc names the same icon")
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
    targetcast = { harmColor = { 0.7, 0, 0, 1 }, healColor = { 0, 0.7, 0, 1 }, lockedColor = {} },
    health = { borderMode = "class" } } } }
ns.useProfile("OldColors")
assert(prof().colors.power.ENERGY[1] == 0.5 and prof().colors.cast.harm[1] == 0.7
    and prof().colors.cast.heal[2] == 0.7 and prof().colors.moved, "moved into the palette")
assert(prof().colors.cast.locked[1], "an empty leftover color keeps the palette's")
assert(prof().regular.bars.power.powerColors == nil and prof().regular.bars.targetcast.harmColor == nil
    and prof().regular.bars.health.borderMode == "bar", "gone from the bars; a class border follows the bar")
ns.useProfile("Scratch")
WolfpackAddonDB.profiles.OldColors = nil
-- Copy from: another profile's settings (and Bar Stack's) land on the current one, name kept
local here = WolfpackAddonDB.chars[S.name .. " - Realm"]
WolfpackAddonDB.profiles.Source = { regular = { bars = { health = { width = 321 } } } }
local bsTouched
ns.bs = { CopyFrom = function() bsTouched = true end, LoadProfile = function() bsTouched = true end }
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
assert(not bsTouched, "Bar Stack is not part of a profile: copying leaves it alone")
ns.bs, WolfpackAddonDB.profiles.Source = nil, nil
ns.useProfile(home)
WolfpackAddonDB.profiles.Scratch = nil
-- the swing timer draws in its rows, so it is "(hidden)" only when no row is up
prof().locked = false
byText("Swing Timer")._scripts.OnClick(byText("Swing Timer"), "LeftButton")
assert(ns.swingFrames.regular[1]:IsShown() and regionWithText(ns.pages.combat, "Swing Timer"),
    "rows up while placing: not called hidden")
prof().regular.bars.swing.classes[S.class].main = false; fire("UNIT_MAXPOWER")
byText("Swing Timer")._scripts.OnClick(byText("Swing Timer"), "LeftButton")
assert(regionWithText(ns.pages.combat, "Swing Timer |cff888888(hidden)|r"), "no row ticked: hidden")
prof().regular.bars.swing.classes[S.class].main, prof().locked = true, true
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
for section, page in pairs(ns.pages) do -- Macros builds its own page (Macros.lua), when first opened
    assert(section == "macros" or (ns.boxesOn[page] or 0) > 0, "nothing on the " .. section .. " page")
end
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
assert(gapBox._text == "30", "back on Combat Display")

-- Profiles, in two steps: 1 picks the parent (and loads it), 2 uses it as it is or a child of
-- it. Create makes a plain child of the parent; a name taken gets a number; delete falls back
-- to Alpha
local function pick(menu, text)
    menu:GenerateMenu()
    for _, it in ipairs(menu._items) do if it.text == text then return it.set() end end
    error("no menu entry " .. text)
end
nameBox._text = "  PvP "; nameBox._scripts.OnEnterPressed(nameBox)
assert(store.profiles.PvP and store.parents.PvP == "Rogue" and prof() == store.profiles.PvP
    and prof().regular.gap == 30, "create: a child of the parent, loaded")
prof().regular.gap = 5
assert(store.profiles.Rogue.regular.gap == 30, "the child's change stays its own")
nameBox._text = "PvP"; nameBox._scripts.OnEnterPressed(nameBox)
assert(store.profiles["PvP 2"] and prof() == store.profiles["PvP 2"], "same name again: PvP 2")
store.profiles["PvP 2"], store.parents["PvP 2"] = nil, nil
ns.useProfile("PvP")
local dds = {} -- step 1's parent, texture, bar color, border color, kill icon, loot icon, combat icon, attach
for _, f in ipairs(created) do if f._gen and f ~= ns.copyFromMenu and f ~= ns.childPick and f ~= ns.countSpotMenus[1] and f ~= ns.countSpotMenus[2] and f ~= ns.sharedBorderTexMenu and f ~= ns.ownBorderTexMenu and f ~= ns.shineMenus[1] and f ~= ns.shineMenus[2] and f ~= ns.resPlaceMenu and f ~= ns.resPointMenu and f ~= ns.attachMenus[1] and f ~= ns.attachMenus[2] and f ~= ns.attachMenus[3] and f ~= ns.xpMenu and f ~= ns.borderFromMenu and f ~= ns.sharedRadiusMenu and f ~= ns.fontMenus[1] and f ~= ns.fontMenus[2] and f ~= ns.fontMenus[3] and f ~= ns.fontMenus[4] and f ~= ns.textureFromMenu and f ~= ns.sharedTextureMenu and not (f._parent == ns.pages.actionbars) then dds[#dds + 1] = f end end
assert(dds[1] == ns.parentPick, "step 1 comes first")
do
    local names = {}
    ns.parentPick:GenerateMenu()
    for _, it in ipairs(ns.parentPick._items) do names[#names + 1] = it.text .. (it.sel() and "*" or "") end
    assert(table.concat(names, ",") == "Alpha,Rogue*,Warrior", "step 1: parents only, PvP's picked: "
        .. table.concat(names, ","))
    names = {}
    ns.childPick:GenerateMenu()
    for _, it in ipairs(ns.childPick._items) do names[#names + 1] = it.text .. (it.sel() and "*" or "") end
    assert(table.concat(names, ","):find("^Rogue itself,PvP |cff888888%(child%)|r%*"), "step 2: " .. table.concat(names, ","))
end
pick(ns.parentPick, "Alpha")
assert(prof() == store.profiles.Alpha, "step 1 loads the parent")
pick(ns.parentPick, "Rogue")
pick(ns.childPick, "PvP |cff888888(child)|r")
assert(prof() == store.profiles.PvP, "step 2 loads the child")
byText("Delete profile")._scripts.OnClick(byText("Delete profile"), "LeftButton")
assert(not store.profiles.PvP and prof() == store.profiles.Alpha, "delete falls back to Alpha")
ns.useProfile("Rogue") -- back on the test rogue's own profile

-- The child keeps only what it changes itself, and the parent's later changes reach it
ns.useProfile("Mom")
local mom = prof()
mom.regular.gap, mom.regular.bars.health.height = 4, 20
nameBox._text = "Kid"; nameBox._scripts.OnEnterPressed(nameBox)
assert(store.parents.Kid == "Mom" and ns.inh.count("Kid") == 0, "a new child: nothing of its own yet")
prof().regular.bars.health.height = 33 -- its own change
assert(ns.inh.count("Kid") == 1, "one change of its own")
ns.useProfile("Mom")
assert(store.overrides.Kid.regular.bars.health.height == 33 and store.overrides.Kid.regular.gap == nil,
    "left: only the change is kept")
mom.regular.gap, mom.regular.bars.health.height = 9, 50 -- Mom is updated
ns.useProfile("Kid")
assert(prof().regular.gap == 9 and prof().regular.bars.health.height == 33, "the update reaches it; its own stays")
do
    ns.parentPick:GenerateMenu()
    for _, it in ipairs(ns.parentPick._items) do assert(it.text ~= "Kid", "a child is no parent to pick") end
end
-- saved at logout too
prof().regular.bars.health.width = 111
fire("PLAYER_LOGOUT")
assert(store.overrides.Kid.regular.bars.health.width == 111, "written down before the game saves")
-- for tools/bake.py: the bundle's string, and when the settings last changed (first time: 0)
time = function() return S.now or 1000 end
store.bake = nil
fire("PLAYER_LOGOUT")
local bake = store.bake
assert(bake.text:find("^WPA1:") and bake.at == 0 and bake.sum, "first logout: the string, stamped 0")
S.now = 2000; fire("PLAYER_LOGOUT")
assert(bake.at == 0, "nothing changed: no news")
prof().regular.bars.health.width = 112
fire("PLAYER_LOGOUT")
assert(bake.at == 2000, "a setting changed: stamped now")
-- a setting the child removed stays removed
local d = ns.inh.diff({ a = 1 }, { a = 1, b = 2 })
assert(d.b == ns.inh.NIL and ns.inh.apply({ a = 1, b = 2 }, d).b == nil, "a removal is kept")
-- what is loaded says whose child it is, and so does the header
ns.cfg:Show(); byText("Profiles")._scripts.OnClick(byText("Profiles"), "LeftButton")
assert(regionWithText(S.pp, "Child of |cffffd100Mom|r\n2 changes of its own; the rest is Mom's"), "loaded now: Kid, Mom's child")
assert(inUse._text == "Profile: |cffffffffKid|r |cff888888(child of|r Mom|cff888888)|r", "the header says so too")
assert(ns.undoButton:IsShown() and ns.detachButton._text == "Detach from Mom", "undo and detach")
ns.undoButton._scripts.OnClick(ns.undoButton)
assert(prof().regular.bars.health.height == 50 and ns.inh.count("Kid") == 0, "undo: Mom's in full again")
prof().regular.bars.health.height = 44
-- the parent deleted: the child keeps what it had and stands alone
ns.useProfile("Mom")
byText("Delete profile")._scripts.OnClick(byText("Delete profile"), "LeftButton")
assert(not store.parents.Kid and store.profiles.Kid.regular.bars.health.height == 44
    and store.profiles.Kid.regular.gap == 9, "Mom gone: Kid stands alone, as it was")
store.profiles.Kid = nil
-- Alpha is the base: never a child. A link made the wrong way round (Alpha set to follow
-- Rogue) is turned round at login: Rogue becomes a plain child of Alpha
ns.useProfile("Alpha")
ns.inh.link("Alpha", "Rogue")
assert(not store.parents.Alpha, "Alpha can't be given a parent")
store.profiles.Rogue.regular.bars.health.height = 61
store.parents.Alpha, store.overrides.Alpha = "Rogue", {}
login("ROGUE", 3)
assert(not store.parents.Alpha and store.parents.Rogue == "Alpha" and next(store.overrides.Rogue) == nil
    and prof().regular.bars.health.height == store.profiles.Alpha.regular.bars.health.height,
    "turned round: Rogue is a plain child of Alpha")
-- step 2 can make a standalone profile a child: when it differs it asks, plain or keep its own
store.parents.Rogue, store.overrides.Rogue = nil, nil
prof().regular.bars.health.height = 62
ns.useProfile("Alpha")
pick(ns.childPick, "|cff888888Make|r Rogue |cff888888a child|r") -- the popup: Plain child
assert(store.parents.Rogue == "Alpha" and next(store.overrides.Rogue) == nil and prof() == store.profiles.Rogue
    and prof().regular.bars.health.height == store.profiles.Alpha.regular.bars.health.height, "plain child")
store.parents.Rogue, store.overrides.Rogue = nil, nil
prof().regular.bars.health.height = 62
StaticPopupDialogs.WOLFPACKADDON_LINK.OnAlt(nil, { "Rogue", "Alpha" })
assert(store.overrides.Rogue.regular.bars.health.height == 62, "or keeping its own")
store.parents.Rogue, store.overrides.Rogue = nil, nil
ns.useProfile("Rogue")

-- Texture and font dropdowns: pick sets the selected bar (Health), previews render
local texDD, fontDD = dds[2], ns.fontMenus[1]
texDD:GenerateMenu(); fontDD:GenerateMenu()
assert(#texDD._items == 11 and #fontDD._items == 6, "dropdown entries")
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
-- Corners: one dropdown per kind on the Colors page, setting every place of that kind
do local cm = ns.cornerMenus
cm[1]:GenerateMenu()
assert(#cm[1]._items == 7 and cm[1]._items[7].text == "Pill (50% of height)", "bar radius presets")
cm[1]._items[7].set()
assert(prof().regular.bars.health.radius == "pill" and prof().colors.radius == "pill"
    and prof().plates.bars.enemyhealth.resRadius == "pill" and cm[1]._items[7].sel(), "every bar takes it")
cm[1]._items[1].set()
cm[2]:GenerateMenu(); cm[2]._items[3].set()
assert(prof().regular.bars.health.buffs.radius == 25 and prof().unitframes.g40.debuffs.radius == 25, "every buff and debuff")
cm[2]._items[1].set()
cm[3]:GenerateMenu(); cm[3]._items[4].set()
assert(prof().actionbars.bars[1].radius == 50 and prof().actionbars.pet.radius == 50 and prof().trinkets.radius == 50,
    "every action button, the trinket buttons too")
cm[3]._items[1].set()
cm[5]:GenerateMenu(); cm[5]._items[4].set()
assert(prof().regular.bars.targetcast.iconRadius == 50 and prof().plates.bars.targetcast.iconRadius == 50
    and prof().regular.bars.castbar.iconRadius == 50 and prof().regular.bars.durability.iconRadius == 50,
    "both cast bars' spell icons, with the item icons")
cm[5]._items[1].set() end
assert(prof().regular.bars.health.texture == "Interface\\Buttons\\WHITE8X8", "texture picked")
assert(prof().regular.bars.health.font:match("Anton%-Regular%.ttf$") and fontDD._items[6].sel(), "font picked")
-- Fonts: one dropdown per kind on the Colors page, setting every text of that kind
assert(prof().plates.bars.enemyhealth.tagFont:match("Anton") and prof().unitframes.bars.power.font:match("Anton")
    and prof().regular.bars.castbar.font:match("Anton"), "every bar's text, level and name too")
ns.fontMenus[2]:GenerateMenu(); ns.fontMenus[2]._items[6].set()
assert(prof().actionbars.bars[1].keyFont:match("Anton") and prof().actionbars.pet.macroFont:match("Anton")
    and prof().trinkets.keyFont:match("Anton"), "every action button's keys and macro names, the trinkets' too")
ns.fontMenus[2]._items[1].set()

-- Quest page: icon style, size and position per icon
byText("Nameplates")._scripts.OnClick(byText("Nameplates"), "LeftButton")
byText("Quest mobs")._scripts.OnClick(byText("Quest mobs"), "LeftButton")
assert(ns.np.preview:IsShown() and ns.np.preview.quest.kill:IsShown() and ns.np.preview.quest.loot:IsShown(),
    "the Quest mobs tab: a preview plate with dummy icons beside the window")
-- the n-th control labeled `text` on a page: a dropdown, or a slider's typing box
local function control(page, text, n)
    n = n or 1
    for _, w in ipairs(created) do
        local labeled = false
        for _, r in ipairs(w._regions or {}) do if r._text == text then labeled = true end end
        if labeled and w._parent == page then
            n = n - 1
            if n == 0 then
                for _, b in ipairs(created) do if b._kind == "EditBox" and b._parent == w then return b end end
                return w
            end
        end
    end
end
local qp = ns.pages.nameplates
local killIcon, lootIcon = control(qp, "Icon", 1), control(qp, "Icon", 2)
killIcon:GenerateMenu(); lootIcon:GenerateMenu()
assert(#killIcon._items == 4 and #lootIcon._items == 4, "icon choices")
for _, it in ipairs(killIcon._items) do assert(type(it.init(menuButton())) == "number", "icon preview") end
killIcon._items[3].set()
local function typeIn(b, v) b._text = v; b._scripts.OnEnterPressed(b) end
typeIn(control(qp, "Size", 1), "32")
typeIn(control(qp, "X (left / right)", 2), "-5") -- the bag's X
local anchorTo = control(qp, "Anchor to", 2)
anchorTo:GenerateMenu()
assert(#anchorTo._items == 9 and anchorTo._items[9].text == "The sword", "every part of the plate, and the sword")
anchorTo._items[2].set()
local Q = prof().quest
assert(Q.kill.icon == 135274 and Q.kill.size == 32 and Q.loot.size == 20 and Q.loot.x == -5
    and Q.loot.anchorTo == "res" and Q.kill.x == -2, "quest page edits")
assert(h.kill._tex == 135274 and h.kill._w == 32 and h.loot._point[4] == -5, "live plate restyled")
typeIn(control(qp, "Font size", 1), "13"); typeIn(control(qp, "Padding", 2), "4")
assert(Q.kill.fontSize == 13 and Q.loot.pad == 4 and Q.loot.fontSize == 10, "number settings, each its own")
Q.kill.fontSize, Q.loot.pad, Q.loot.x, Q.loot.anchorTo = 10, 2, 0, "bar"
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
local opBox = boxes[38] -- highlight opacity (%), after the party/raid one and the target trail's nine
opBox._text = "60"; opBox._scripts.OnEnterPressed(opBox)
assert(math.abs(prof().regular.highlight.color[4] - 0.6) < 1e-9 and opBox._text == "60", "opacity typed")
-- Enemy health's resource settings open in a window beside the options, only for that bar
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
prof().regular.bars.enemyhealth.resource = true -- off by default: Enemy Power is a bar of its own
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

-- Bags: our window replaces Blizzard's, open while theirs is (parked out of sight); quest items
-- group apart under the bags, a quiver gets its own group, and the bag bar rides on top
;(function()
    tContains = tContains or function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
    ITEM_QUALITY_COLORS = { [2] = { r = 0.1, g = 1, b = 0 }, [4] = { r = 0.64, g = 0.2, b = 0.93 } }
    GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, id == 77 and 12 or 0 end
    local B, o, kept, keptBags = ns.bags, prof().bags, { C_Container.GetContainerNumSlots,
        C_Container.GetContainerNumFreeSlots }, S.bags
    C_Container.GetContainerNumSlots = function(bag) return ({ [0] = 4, [1] = 2 })[bag] or 0 end
    C_Container.GetContainerNumFreeSlots = function(bag) return 0, bag == 1 and 1 or 0 end -- bag 1: a quiver
    S.bags = { [0] = { { itemID = 1, iconFileID = 11, quality = 0, stackCount = 1 },
        { itemID = 77, iconFileID = 12, quality = 1, stackCount = 1 },
        { itemID = 3, iconFileID = 13, quality = 4, stackCount = 1 } },
        [1] = { { itemID = 5, iconFileID = 15, quality = 1, stackCount = 200 } } }
    ContainerFrame1.GetID = function() return 0 end
    local bank = new()
    bank.GetID, bank._shown, bank._parent = function() return 6 end, true, UIParent
    ContainerFrame2 = bank
    ContainerFrame1._shown, ContainerFrame1._parent = true, UIParent
    B.sync()
    assert(ContainerFrame1._parent == UIParent and not (B.frame and B.frame:IsShown()), "off: Blizzard's bags as they are")
    o.show = true
    -- the game's button template brings art of its own (a glow, here): hidden; hover highlight kept
    S.realCF = CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local b = S.realCF(kind, name, parent, template)
        if template == "ContainerFrameItemButtonTemplate" then
            S.glow, S.hl = b:CreateTexture(), b:CreateTexture()
            S.glow._kind, S.hl._kind = "Texture", "Texture"
            b.GetHighlightTexture = function() return S.hl end
        end
        return b
    end
    B.sync()
    CreateFrame = S.realCF
    assert(S.glow._alpha == 0 and S.hl._alpha ~= 0, "the template's glow hidden, the hover highlight kept")
    local f = B.frame
    assert(f:IsShown() and ContainerFrame1._parent == hider, "on: ours open, Blizzard's parked")
    assert(bank._parent == UIParent, "a bank bag's window stays Blizzard's")
    local junk, quest, epic, empty = unpack(B.holders[0].buttons)
    local ammo = B.holders[1].buttons[1]
    assert(junk._point[2] == f and junk._point[5] == -8 and epic._point[4] == 48 and empty._point[4] == 88,
        "main group: the bags in order, quest item left out")
    assert(quest._point[5] == -70 and quest._point[4] == 8 and f.tags.quest:IsShown(), "quest items apart, labeled")
    assert(ammo._point[5] == -132 and f.tags.ammo:IsShown() and not f.tags.soul:IsShown(), "the quiver in a group of its own")
    assert(epic.wpEdge._color[1] == 0.64 and junk.wpEdge._color[1] == 0 and quest.wpEdge._color[2] == 0.82,
        "borders: quality colors, quest items gold")
    assert(junk.wpJunk:IsShown() and not epic.wpJunk:IsShown(), "junk marked")
    o.sort = true
    B.layout()
    assert(epic._point[4] == 8 and junk._point[4] == 48 and empty._point[4] == 88, "kept sorted: best first, empty last")
    o.quality, o.junk = false, false
    B.layout()
    assert(epic.wpEdge._color[1] == 0 and not junk.wpJunk:IsShown(), "both can be turned off")
    -- your class's bags are there by themselves (a rogue: poisons, tools), filled by item, and
    -- need no button on the strip. The + makes a bag by hand (an item held on it goes in);
    -- dropped again, the item goes back.
    o.sort = false
    local cursor, keptCursor = nil, { GetCursorInfo, ClearCursor }
    GetCursorInfo, ClearCursor = function() if cursor then return "item", cursor end end, function() cursor = nil end
    S.bags[0][4] = { itemID = 5060, iconFileID = 16, quality = 1, stackCount = 1 } -- thieves' tools
    B.layout()
    local side = f.side.btns
    local tools = B.holders[0].buttons[4]
    assert(not side[1].wpBag and not (side[2] and side[2]:IsShown()), "the strip: only the +")
    assert(#o.custom == 0 and f.tags.c2._text == "Tools and powders" and tools._point[5] == -132,
        "the tools bag holds its item without being made or told")
    cursor = 3
    side[1]._scripts.OnClick(side[1], "LeftButton")
    assert(cursor == nil and o.custom[1].name == "Bag 1" and o.custom[1].items[3] == true, "made with the held item")
    assert(f.tags.c3:IsShown() and f.tags.c3._text == "Bag 1" and side[1].wpBag == 3 and not side[2].wpBag,
        "it groups apart, after the class bags; its button first on the strip")
    cursor = 3
    side[1]._scripts.OnReceiveDrag(side[1])
    assert(o.custom[1].items[3] == nil and not f.tags.c3:IsShown(), "dropped again: back")
    side[1]._scripts.OnClick(side[1], "RightButton")
    assert(#o.custom == 0, "a hand-made bag can be removed (the popup says yes here)")
    -- a hand-made bag of a class preset, from before: its items move into the class bag
    o.custom = { { name = "Poisons", preset = "poisons", items = { [777] = true } } }
    B.layout()
    assert(#o.custom == 0 and o.classItems["ROGUE:poisons"][777] == true, "moved into the class bag")
    -- turned off: no class bags
    o.classBags = false
    B.layout()
    assert(not side[1].wpBag and #B.all() == 0, "off: only the +")
    o.classBags, o.classItems = true, {}
    o.custom = {}
    S.bags[0][4] = nil
    -- the keyring: its button joins the bag bar, its keys show in our look above it
    KeyRingButton, KEYRING_CONTAINER = new(), -2
    KeyRingButton._parent = UIParent
    local numSlots = C_Container.GetContainerNumSlots
    C_Container.GetContainerNumSlots = function(bag) return bag == -2 and 2 or numSlots(bag) end
    S.bags[-2] = { { itemID = 9, iconFileID = 19, quality = 1, stackCount = 1 } }
    local ring = new()
    ring.GetID, ring._parent, ring._shown = function() return -2 end, UIParent, false
    ContainerFrame3 = ring
    B.sync()
    assert(KeyRingButton._parent == f and KeyRingButton._point[2] == BagsBar and not f.keys:IsShown(),
        "the keyring button on the bar")
    KeyRingButton.wpHome, KeyRingButton._parent = nil, BagsBar -- Forever: the game's bar holds it
    B.sync()
    assert(KeyRingButton._parent == BagsBar and not KeyRingButton.wpHome, "a keyring in the game's bar stays there")
    KeyRingButton._parent = UIParent
    B.sync()
    ring._shown = true
    B.sync()
    local key = B.holders[-2].buttons[1]
    assert(ring._parent == hider and f.keys:IsShown() and key._point[2] == f.keys and key.wpIcon._tex == 19
        and B.holders[-2].buttons[2]:IsShown() and f.keys._point[2] == BagsBar, "the keys above the bar")
    o.keyring = false
    B.sync()
    assert(ring._parent == UIParent and not f.keys:IsShown() and KeyRingButton._parent == UIParent,
        "off: the keyring is Blizzard's again")
    ring._shown, ContainerFrame3, KeyRingButton, KEYRING_CONTAINER, S.bags[-2] = false, nil, nil, nil, nil
    C_Container.GetContainerNumSlots, o.keyring = numSlots, true
    GetCursorInfo, ClearCursor = keptCursor[1], keptCursor[2]
    o.quality, o.junk = false, false
    B.layout()
    assert(BagsBar._parent == f and BagsBar._point[1] == "BOTTOMRIGHT" and BagsBar._point[3] == "TOPRIGHT", "bag bar on top")
    -- the game putting it back on its own spot (Edit Mode's layout, after a loading screen): on the window again
    BagsBar:SetParent(UIParent)
    BagsBar:SetPoint("TOPRIGHT", "MicroButtonAndBagsBar", "TOPRIGHT", 0, 0)
    assert(BagsBar._parent == f and BagsBar._point[2] == f and BagsBar._point[3] == "TOPRIGHT", "moved by the game: back")
    local keptEM = EditModeManagerFrame
    EditModeManagerFrame = { IsEditModeActive = function() return true end }
    BagsBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    assert(BagsBar._point[1] == "CENTER", "in Edit Mode: left where you put it")
    EditModeManagerFrame = keptEM
    ContainerFrame1:Hide(); ContainerFrame1:Show()
    assert(BagsBar._parent == f and BagsBar._point[2] == f, "the bags opened: on the window again")
    -- the key closes Blizzard's window while it sits under the hidden parent: Hide() fires no
    -- OnHide there (nothing becomes invisible), so ours must hear the call itself (seen in game)
    -- dragged: there for now, the setting untouched; closed, back to the spot set on the page
    local keptX = o.x
    f:SetPoint("CENTER", UIParent, "CENTER", 5, 5) -- where the drag left it (the mock's StartMoving moves nothing)
    f._scripts.OnDragStop(f)
    B.layout()
    assert(f._point[1] == "CENTER" and o.x == keptX, "dragged: left there, the setting kept")
    ContainerFrame1:Hide()
    assert(not f:IsShown() and ContainerFrame1._parent == UIParent, "closed with Blizzard's, theirs given back")
    ContainerFrame1:Show()
    assert(f:IsShown() and f._point[1] == "BOTTOMRIGHT" and f._point[4] == o.x, "opened again: at the set spot")
    ContainerFrame1:Hide()
    o.show = false
    B.sync()
    assert(BagsBar._parent == UIParent and BagsBar._point[2] == "MicroButtonAndBagsBar", "off: the bag bar goes home")
    o.sort, o.quality, o.junk = false, true, true
    C_Container.GetContainerNumSlots, C_Container.GetContainerNumFreeSlots = kept[1], kept[2]
    S.bags, ContainerFrame2, bank._shown = keptBags, nil, false
end)()

-- The bank: a window like the bags' for its slots and its bags; Blizzard's parked without its
-- OnHide (which closes the bank), its bag slots and buy button on our window's top. Escape on
-- ours closes the bank; the bank closing closes ours and gives Blizzard's back.
;(function()
    local B, o = ns.bags, prof().bags
    local keptSlots, keptBags = C_Container.GetContainerNumSlots, S.bags
    o.show, NUM_BANKBAGSLOTS = true, 2 -- your bags are 0-1 here, so the bank's are 2 and 3
    C_Container.GetContainerNumSlots = function(bag) return ({ [-1] = 3, [2] = 2 })[bag] or 0 end
    S.bags = { [-1] = { { itemID = 1, iconFileID = 11, quality = 1, stackCount = 1 } },
        [2] = { nil, { itemID = 77, iconFileID = 12, quality = 1, stackCount = 1 } } }
    BankFrame = new()
    BankFrame._shown, BankFrame._parent = true, UIParent
    BankFrame.GetScript = function(self, k) return self._scripts[k] end
    local blizzHide = function() end
    BankFrame._scripts.OnHide = blizzHide
    local slot = new()
    slot.isBag, slot._parent, slot.GetID = 1, BankFrame, function() return 1 end
    BankFrame._children = { slot }
    BankFramePurchaseButton = new()
    BankFramePurchaseButton._parent = BankFrame
    GetNumBankSlots = function() return 1, false end
    CloseBankFrame = function() S.bankClosed = true end
    local bankBagWin = new()
    bankBagWin.GetID, bankBagWin._shown, bankBagWin._parent = function() return 2 end, true, UIParent
    ContainerFrame4 = bankBagWin
    local templates = {}
    S.realCF = CreateFrame
    CreateFrame = function(kind, name, parent, tpl)
        if name then templates[name] = tpl end
        return S.realCF(kind, name, parent, tpl)
    end
    B.ev._scripts.OnEvent(B.ev, "BANKFRAME_OPENED")
    CreateFrame = S.realCF
    local f = B.bankFrame
    assert(f:IsShown() and BankFrame._parent == hider and BankFrame._scripts.OnHide == blizzHide,
        "open: ours shows, Blizzard's parked, its OnHide kept")
    assert(templates.WolfpackBagM1Slot1 == nil and templates["WolfpackBag-1Slot1"] == "BankItemButtonGenericTemplate"
        and templates.WolfpackBag2Slot2 == "ContainerFrameItemButtonTemplate", "the bank's slots: the game's bank buttons")
    assert(B.holders[-1]:GetParent() == f and B.holders[2]:GetParent() == f and B.holders[-1].buttons[3]:IsShown()
        and B.holders[2].buttons[2].wpIcon._tex == 12 and f.money._text == "Bank", "its slots and its bag's, in our window")
    assert(slot._parent == f and slot._point[1] == "BOTTOMLEFT" and BankFramePurchaseButton._point[2] == slot
        and BankFramePurchaseButton:IsShown(), "the bag slots and the buy button on top")
    B.sync()
    assert(bankBagWin._parent == hider and not B.frame:IsShown(), "a bank bag's window: parked, the bags stay shut")
    S.bankClosed = nil
    f._scripts.OnHide(f)
    assert(S.bankClosed, "closed by hand: the bank closes")
    S.bankClosed = nil
    B.ev._scripts.OnEvent(B.ev, "BANKFRAME_CLOSED")
    assert(not f:IsShown() and BankFrame._parent == UIParent and slot._parent == BankFrame and not S.bankClosed,
        "the bank closed: ours shut, Blizzard's given back")
    o.bank = false
    B.ev._scripts.OnEvent(B.ev, "BANKFRAME_OPENED")
    assert(not f:IsShown() and BankFrame._parent == UIParent, "off: Blizzard's bank as it is")
    B.ev._scripts.OnEvent(B.ev, "BANKFRAME_CLOSED")
    o.bank, o.show = true, false
    bankBagWin._shown = false
    B.sync()
    -- the classic clients: bags 0-4, the reagent bag's number 5, then bank bags 6-12 (Enum.BagIndex)
    local keptEnum, keptNum = Enum, NUM_BAG_SLOTS
    Enum, NUM_BAG_SLOTS, NUM_BANKBAGSLOTS = { BagIndex = { Bank = -1, ReagentBag = 5, BankBag_1 = 6 } }, 4, 7
    assert(table.concat(B.bankList(), ",") == "-1,6,7,8,9,10,11,12", "every bank bag, the 7th too")
    Enum, NUM_BAG_SLOTS = keptEnum, keptNum
    BankFrame, BankFramePurchaseButton, ContainerFrame4, NUM_BANKBAGSLOTS = nil, nil, nil, nil
    C_Container.GetContainerNumSlots, S.bags = keptSlots, keptBags
end)()

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

-- Leave form: a secure "/cancelform" button over the flight map, only while you are in a form
do local lf, form = ns.leaveForm, 0
assert(lf._attr.type == "macro" and lf._attr.macrotext == "/cancelform" and lf._attr.useOnKeyDown == false,
    "a secure click cancels the form")
local was = GetShapeshiftForm
GetShapeshiftForm = function() return form end
TaxiFrame = new(); TaxiFrame:Show()
ns.leaveFormSync()
assert(not lf:IsShown(), "not in a form: no button")
form = 1
ns.leaveFormSync()
assert(lf:IsShown() and lf._points[1][2] == TaxiFrame, "in Ghost Wolf at the flight master: above the map")
TaxiFrame:Hide(); ns.leaveFormSync()
assert(not lf:IsShown(), "map closed: gone")
TaxiFrame:Show(); prof().other.leaveForm = false; ns.leaveFormSync()
assert(not lf:IsShown(), "turned off: never")
prof().other.leaveForm = true
TaxiFrame, GetShapeshiftForm = nil, was end

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
-- Bar Stack has no string of its own: the bars this character loads ride in this one
local bsGot
ns.bs = { profile = {}, ExportSet = function() return { groups = { { name = "Mine" } } } end,
    ImportProfile = function(p) bsGot = p; return true end }
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
    plates = { bars = { power = { stops = { { pos = 10, color = { 1, 0, 0, 1 } }, { pos = "x" },
        { pos = 90, color = { 0, 0, 1, 1 } } } } } },
    regular = { gap = -5, x = 1e9, order = { "health", "health", "bogus", "castbar" },
        bars = { health = { width = "wide", height = 0, radius = "pill", color = { 1, "red", 0, 1 } } } } } }
local bad = ns.importString("WPA1:Bzblob" .. #blobs)
local bp = store.profiles[bad]
assert(#bad == 32 and bp.evil == nil and bp.locked == true, "unknown key dropped, bad type defaulted")
assert(bp.other.hover.bar1 and bp.other.hover.nope == nil and bp.other.hover.bar2 == nil, "hover: known and true only")
assert(bp.other.combatFont == "", "unknown combat font path refused")
assert(bp.regular.gap == 2 and bp.regular.x == 0, "out-of-range numbers defaulted")
assert(bp.regular.order[1] == "health" and bp.regular.order[2] == "castbar" and #bp.regular.order == 18, "order repaired")
local ns2 = bp.plates.bars.power.stops
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
dds[11]:GenerateMenu()
assert(#dds[11]._items == 21, "combat font dropdown")
for _, it in ipairs(dds[11]._items) do
    local b = menuButton()
    assert(type(it.init(b)) == "number" and b._attached._text == "123", "combat font preview")
    checkColumn(b, 56)
end
dds[11]._items[6].set()
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
dds[11]._items[1].set()
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
-- an empty account is filled from the baked bundle: its profiles, and Alpha
blobs[#blobs + 1] = { profile = {}, profiles = { ["Alpha Warrior"] = { regular = { gap = 5 } } },
    classes = { WARRIOR = "Alpha Warrior" } }
bakedStub = "zblob" .. #blobs
local keptProfiles, keptClasses = WolfpackAddonDB.profiles, WolfpackAddonDB.classProfiles
WolfpackAddonDB.profiles, WolfpackAddonDB.classProfiles = {}, {}
ns.seedFromBaked()
assert(WolfpackAddonDB.profiles["Alpha Warrior"], "the baked bundle fills an empty account")
assert(next(WolfpackAddonDB.classProfiles) == nil and WolfpackAddonDB.profiles.Alpha,
    "no class tied to a profile, so everyone starts on Alpha, made from the bundle's own profile")
WolfpackAddonDB.profiles, WolfpackAddonDB.classProfiles = keptProfiles, keptClasses
-- new profiles start from it, or the plain defaults if it can't be read
local fresh = ns.freshProfile()
assert(fresh.regular and fresh.plates and fresh.bags and fresh.other and fresh.quest, "a complete profile either way")

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
WolfpackAddonDB.load = {} -- the Load page was poked too: everything loads again
for _, m in ipairs({ "regular", "plates" }) do
    local seen = {}
    for _, k in ipairs(prof()[m].order) do seen[k] = true end
    assert(seen.health and seen.power and seen.combo and seen.druidmana and seen.castbar and seen.pethealth
        and seen.swing and seen.totems and seen.absorb and seen.flight and seen.targetcast
        and seen.enemyhealth and #prof()[m].order == 18, "order intact")
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
assert(tb.segs[1].border._vertex[2] == 1 and tb.segs[1].border._vertex[1] == 0.25
    and tb.segs[2].border._vertex[1] == 1 and tb.segs[2].border._vertex[2] == 0.475, "green and red edges")
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
assert(not ns.frames.targetcast.icon.iconMask, "square by default")
prof().regular.bars.targetcast.iconRadius = 50 -- the Corners card's "Icons on bars"
fire("UNIT_SPELLCAST_START", "target")
assert(ns.frames.targetcast.icon.iconMask, "the enemy cast icon takes the corners")
prof().regular.bars.targetcast.iconRadius = 0
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
S.hb = ns.frames.targetcast.segs[1].border._vertex -- a lighter heal green: 0.2, 0.9, 0.3 lifted
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
-- the classic clients have no duration object, but plain start and end times: the bar runs on them
S.keptInfo = UnitCastingInfo
UnitCastingInfo = function() return "Frostbolt", "", 135846, 1000, 3000 end
S.keptTime, S.time = S.time, 2
ns.fill(ns.frames.targetcast)
S.seg = ns.frames.targetcast.segs[1]
assert(S.seg._max == 2 and S.seg._value == 1 and S.seg._scripts.OnUpdate, "halfway through a 2 s cast, and ticking")
S.time = 9; S.seg._scripts.OnUpdate(S.seg)
assert(S.seg._value == 2, "full at the end, never past it")
UnitCastingInfo, S.time = S.keptInfo, S.keptTime
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
-- DoT damage left: the last tick times the ticks the debuff has left, a darker stretch over the
-- end of the health fill and the number beside it. A function of its own: the main chunk is at
-- Lua's 200 locals, and a do block's count toward them.
;(function()
    local eb, keepNpc, keepHP = ns.frames.enemyhealth, S.npc, S.targetHP
    S.npc, S.targetHP = "Mob-1", 800
    local keepRes = prof().regular.bars.enemyhealth.resource
    prof().regular.bars.enemyhealth.show, prof().regular.bars.enemyhealth.resource = true, false
    fire("UNIT_MAXPOWER")
    fire("PLAYER_TARGET_CHANGED")
    assert(eb.dot and eb.dot:IsShown() and eb.dot._reverseFill, "on by default on a Classic client, growing left")
    assert(ns.logAllowed(11509) and ns.logAllowed(20506) and ns.logAllowed(50504), "Era, Anniversary, Classic: the log")
    assert(not ns.logAllowed(16001) and not ns.logAllowed(120105), "Forever and Midnight: never asked for")
    local function tick(sub, amount, crit)
        S.cleu = { 0, sub, false, "Player-1", "", 0, 0, "Mob-1", "", 0, 0, 172, "Corruption", 32, amount }
        S.cleu[21] = crit
        fire("COMBAT_LOG_EVENT_UNFILTERED")
    end
    S.debuffs = { { name = "Corruption", expirationTime = S.time + 12, sourceUnit = "player" } }
    tick("SPELL_PERIODIC_DAMAGE", 50)
    assert(eb.dot._value == 200 and eb.dot._max == 1000 and eb.dot.text._text == "200",
        "12 s left at 3 s a tick: four more of 50, drawn on the first tick: " .. tostring(eb.dot._value))
    S.time = S.time + 2
    tick("SPELL_PERIODIC_DAMAGE", 90, true)
    assert(eb.dot._value == 250, "a 2 s gap: five ticks in the 10 s left, a crit doesn't set the size")
    S.time = S.time + 2
    tick("SPELL_PERIODIC_MISSED")
    assert(eb.dot._value == 200, "a resisted tick still counts down")
    S.time = S.time + 1
    fire("UNIT_HEALTH", "target")
    assert(eb.dot._value == 200, "between ticks: the next one is still to come")
    S.debuffs = {}; fire("UNIT_AURA", "target")
    assert(eb.dot._value == 0 and eb.dot.text._text == "", "dispelled: nothing left")
    local ec = prof().regular.bars.enemyhealth
    assert(eb.dot._tex == ec.texture and eb.dot.text._shown, "by default: the bar's texture, the number shown")
    ec.dotsTexture, ec.dotsHideText = "Interface\\Buttons\\WHITE8X8", true
    fire("UNIT_MAXPOWER")
    assert(eb.dot._tex == "Interface\\Buttons\\WHITE8X8", "a texture of its own")
    assert(not eb.dot.text._shown and eb.dot.kill._point[2] == eb.dot:GetStatusBarTexture(),
        "the number hidden: the skull sits right by the stretch")
    ec.dotsTexture, ec.dotsHideText = "bar", false
    fire("UNIT_MAXPOWER")
    assert(eb.dot.text._shown and eb.dot.kill._point[2] == eb.dot.text, "and back")
    -- its color: the bar's, darker (a texture shows through), else your own
    fire("UNIT_HEALTH", "target")
    local rgb, sbc = eb.segs[1].rgb, eb.dot._sbc
    assert(sbc[1] == rgb[1] * 0.5 and sbc[2] == rgb[2] * 0.5 and sbc[3] == rgb[3] * 0.5 and sbc[4] == 1,
        "by default the bar's color, half as bright")
    ec.dotsColorFrom, ec.dotsColor = "custom", { 0.2, 0.4, 0.6, 0.7 }
    fire("UNIT_MAXPOWER")
    fire("UNIT_HEALTH", "target")
    sbc = eb.dot._sbc
    assert(sbc[1] == 0.2 and sbc[3] == 0.6 and sbc[4] == 0.7, "custom: your own color, kept at every fill")
    ec.dotsColorFrom = "bar"
    fire("UNIT_MAXPOWER")
    tick("UNIT_DIED")
    assert(ns.dots["Mob-1"] == nil, "a death forgets the ticks")
    -- the tooltip's numbers: total, school, duration (and the tick gap where it says)
    local t, s, d, e = ns.readDot("Corrupts the target, causing 180 Shadow damage over 18 sec.")
    assert(t == 180 and s == 32 and d == 18 and e == nil, "a plain DoT")
    t, s, d = ns.readDot("Burns the enemy for 11 Fire damage and then an additional 20 Fire damage over 15 sec.")
    assert(t == 20 and s == 4 and d == 15, "a hit and a DoT: the DoT part")
    local rip = "Finishing move that causes damage over time:\n 1 point : 42 damage over 12 sec.\n 2 points: 66 damage over 12 sec."
    assert(ns.readDot(rip, 2) == 66 and ns.readDot(rip) == 42 and ns.readDot(rip, 5) == 66, "a finisher, by combo points")
    t, s, d, e = ns.readDot("Transfers 15 health from the target to the caster every 3 sec. Lasts 30 sec.")
    assert(t == 150 and d == 30 and e == 3, "so much every so often, for so long")
    assert(ns.readDot("Heals the target of 830 damage over 15 sec.") == nil, "a heal isn't a DoT")
    -- before its first tick: the tooltip's share for every tick still to come
    local keepSpell = C_Spell
    C_Spell = setmetatable({ GetSpellDescription = function(id) return (S.descs or {})[id] end,
        GetSpellName = function(id) return (S.names or {})[id] end }, { __index = keepSpell })
    S.descs = { [172] = "Corrupts the target, causing 180 Shadow damage over 18 sec.",
        [348] = "Burns the enemy for 11 Fire damage and then an additional 20 Fire damage over 15 sec." }
    S.names = { [172] = "Corruption", [348] = "Immolate" }
    S.debuffs = { { name = "Corruption", spellId = 172, duration = 18, expirationTime = S.time + 18 } }
    fire("UNIT_AURA", "target")
    assert(eb.dot._value == 180, "no tick yet: all six of 30: " .. tostring(eb.dot._value))
    S.time = S.time + 4; fire("UNIT_HEALTH", "target")
    assert(eb.dot._value == 150, "one beat gone by: five left")
    -- Agony ticks small, then more: the ticks still to come follow its shape
    S.debuffs = { { name = "Curse of Agony", spellId = 980, duration = 24, expirationTime = S.time + 24 } }
    S.time = S.time + 2
    S.cleu = { 0, "SPELL_PERIODIC_DAMAGE", false, "Player-1", "", 0, 0, "Mob-1", "", 0, 0, 980, "Curse of Agony", 32, 15 }
    fire("COMBAT_LOG_EVENT_UNFILTERED")
    assert(eb.dot._value == 345, "a first tick of 15 is half an average 30; 11 to come: " .. tostring(eb.dot._value))
    -- the skull: a bar of the health, filled by the damage to come (full: it shows)
    assert(eb.dot.killBar._max == 800 and eb.dot.killBar._value == 345, "the skull's sum, left to the bar")
    S.debuffs = {}; fire("UNIT_AURA", "target")
    assert(eb.dot.killBar._value == 0, "no DoTs, no skull")
    ns.dots["Mob-1"], S.cleu = nil, nil
    -- Forever: no log. Your DoT casts start one from the tooltip; hits of its school on its beat
    -- are its ticks, and teach its size.
    ns.dotLog = false
    ns.dotSent("cast-1")
    ns.dotCast("cast-1", 172)
    assert(eb.dot._value == 180, "cast: the tooltip's 180")
    S.time = S.time + 3
    ns.dotHit("target", "WOUND", nil, 40, 32)
    assert(eb.dot._value == 200 and WolfpackAddonDB.dotTicks[172] == 40, "a tick of 40 on the beat: five more")
    S.time = S.time + 0.2
    ns.dotHit("target", "WOUND", nil, 41, 1)
    S.time = S.time + 1.3
    ns.dotHit("target", "WOUND", nil, 40, 32)
    assert(eb.dot._value == 200, "a melee hit, a Shadow hit off the beat: neither is a tick")
    ns.dotCast("cast-2", 348) -- Immolate, never ticks: resisted
    S.time = S.time + 7
    fire("UNIT_HEALTH", "target")
    assert(eb.dot._value == 120, "two beats missed: Immolate goes; Corruption runs on unseen: three left: "
        .. tostring(eb.dot._value))
    ns.dotLog, C_Spell, S.descs, S.names = true, keepSpell, nil, nil
    S.cleu, S.npc, S.targetHP = nil, keepNpc, keepHP
    prof().regular.bars.enemyhealth.show, prof().regular.bars.enemyhealth.resource = false, keepRes
    fire("UNIT_MAXPOWER")
    fire("PLAYER_TARGET_CHANGED")
end)()
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


S.group, S.members = false, 0
login("ROGUE", 3)

S.unitClasses = nil
login("ROGUE", 3)

-- The durability bar on the Combat Display: out of combat only, your most worn item; the weapon
-- enchant bars are gone (the class buffs show those)
do
    local R = prof().regular.bars
    assert(R.enchantmh == nil and fr.enchantmh == nil and not tContains(prof().regular.order, "enchantmh"),
        "no weapon enchant bars")
    R.durability.show = true
    S.weapons = { [16] = 501, [5] = 505 }
    S.dur = { [5] = { 20, 100 }, [16] = { 90, 100 } }
    GetInventoryItemDurability = function(slot) local d = S.dur[slot]; if d then return d[1], d[2] end end
    fire("UNIT_MAXPOWER")
    local du = fr.durability
    assert(du:IsShown() and du.text._text == "20%" and du.icon._tex == 505, "durability: the most worn item")
    R.durability.iconZoom, R.durability.iconRadius = 20, 50
    fire("UNIT_MAXPOWER")
    assert(du.icon._coords[1] == 0.2 and du.icon._coords[2] == 0.8 and du.icon.iconMask, "zoomed in, round")
    S.dur[5] = { 0, 100 }
    ns.wb.ticker._scripts.OnUpdate(ns.wb.ticker, 1)
    ns.wb.ticker._scripts.OnUpdate(ns.wb.ticker, 0.3)
    assert(du.wbEmpty and du._alpha < 1, "broken: it flashes")
    fire("PLAYER_REGEN_DISABLED")
    assert(not du:IsShown(), "gone in combat")
    fire("PLAYER_REGEN_ENABLED")
    assert(du:IsShown(), "back after")
    S.weapons, S.dur, GetInventoryItemDurability = nil, nil, nil
    R.durability.show = false
    fire("UNIT_MAXPOWER")
end


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

-- Hunter: the ammo count on the power bar, a happiness dot on the pet bar (the old panel is gone)
S.unitClasses = nil -- the group test above left everyone else's class behind
login("HUNTER", 2)
S.ammoID, S.ammoCount, S.ammoIcon, S.happiness, S.petHP = 2512, 143, 4321, 3, 400
fire("UNIT_PET", "player")
ns.hnEv._scripts.OnEvent(ns.hnEv, "BAG_UPDATE")
SlashCmdList.WOLFPACKADDON("pet") -- the probe walks every route without blowing up
assert(not ns.errored, "the pet probe runs clean")
SlashCmdList.WOLFPACKADDON("loot") -- and so does the one that asks about the encounter journal
assert(not ns.errored, "the loot probe runs clean")
-- the ammo bar: beside the power bar, the two as wide as the power bar is set; its number is the
-- ammo in your bags, its fill how full your quiver is
S.AM, S.PW = prof().regular.bars.ammo, prof().regular.bars.power
C_Container = C_Container or {}
S.keptCC = { C_Container.GetContainerNumFreeSlots, C_Container.GetContainerNumSlots }
C_Container.GetContainerNumFreeSlots = function(bag) return 0, bag == 2 and 1 or 0 end -- bag 2: a quiver
C_Container.GetContainerNumSlots = function(bag) return 4 end
C_Item = C_Item or {}
C_Item.GetItemMaxStackSizeByID = function() return 200 end
S.AM.show, S.AM.width = true, 60; fire("UNIT_MAXPOWER")
assert(not ns.hn.panel:IsShown(), "no panel any more")
S.af = fr.ammo
assert(S.af:IsShown() and S.af._w == 60 and fr.power._w == S.PW.width and S.af._point[2] == WolfpackAddonFrame
    and S.af._point[4] == -30 and S.af._point[5] < fr.power._point[5], "in the middle column under power, its own width")
assert(S.af.segs[1]._value == 143 and S.af.segs[1]._max == 800 and S.af.text._text == "143",
    "143 arrows, of a quiver of 4 x 200")
assert(S.af.segs[1]._sbc[1] == 0.67, "the hunter class color")
S.dot = fr.pethealth.happyDot
assert(S.dot and S.dot:IsShown() and S.dot.tex._vertex[2] == 0.85 and S.dot.tex._masks[S.dot.mask],
    "a happy pet: a green round dot on its bar")
S.happiness = 1; ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(S.dot.tex._vertex[1] == 0.9 and S.dot.tex._vertex[2] == 0.2, "unhappy: red")
S.happiness = 2; ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(S.dot.tex._vertex[2] == 0.6, "content: orange")
prof().regular.bars.pethealth.happy.x = -3; ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(S.dot._point[3] == "LEFT" and S.dot._point[4] == -3, "where you put it")
-- other builds: C_PetInfo, sometimes a table; Blizzard's indicator as a last resort; or nothing
S.keptHappy, S.keptInfo = GetPetHappiness, C_PetInfo
GetPetHappiness, S.happyTable = nil, true
ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(S.dot:IsShown(), "C_PetInfo stands in for the call that went away")
S.happyTable, C_PetInfo = nil, nil
PetFrameHappiness = new()
PetFrameHappiness.GetHappinessStats = function() return 3 end
ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(S.dot:IsShown() and S.dot.tex._vertex[2] == 0.85, "the indicator frame stands in as well")
PetFrameHappiness = nil
S.wasOpen, ns.configOpen = ns.configOpen, false -- with the options open it would show, to place it
ns.hnEv._scripts.OnEvent(ns.hnEv, "UNIT_HAPPINESS")
assert(not S.dot:IsShown(), "no happiness here, no dot")
ns.configOpen = S.wasOpen
C_PetInfo, GetPetHappiness = S.keptInfo, S.keptHappy
S.AM.show = false; fire("UNIT_MAXPOWER")
assert(not S.af:IsShown() and fr.power._w == S.PW.width, "the ammo bar off: the power bar takes its width back")
C_Container.GetContainerNumFreeSlots, C_Container.GetContainerNumSlots = S.keptCC[1], S.keptCC[2]
-- an older profile's Hunter page settings move over, once
WolfpackAddonDB.profiles.OldHunter = { hunter = { show = true, ammo = false, pet = true, fontSize = 16, low = 50 } }
ns.useProfile("OldHunter")
assert(prof().regular.bars.ammo.show == false and prof().regular.bars.ammo.fontSize == 16
    and prof().regular.bars.pethealth.happy.show, "moved over")
S.ammoID, S.happiness, S.petHP = nil, nil, nil
login("ROGUE", 3)
ns.hnEv._scripts.OnEvent(ns.hnEv, "BAG_UPDATE")
assert(not fr.ammo:IsShown(), "no ammo bar for anyone else")



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
-- a right-click is renamed by a secure snippet, so the template never reads its tainted b.action
assert(S.ab[1]._wrap and S.ab[1]._wrap.OnClick == ns.AB_RIGHT and ns.ab.header._template == "SecureHandlerBaseTemplate",
    "the click is wrapped")
do local pre = assert(loadstring("local self, button = ... " .. ns.AB_RIGHT))
assert(pre(S.ab[1], "RightButton") == "WolfpackRight" and pre(S.ab[1], "LeftButton") == nil, "right renamed, left as it was") end
-- the game's dark slot background behind the icon: shown, or hidden on request; a client that
-- has only some of these textures still gets them all switched
S.slotArt = new("Texture")
rawset(S.ab[1], "SlotArt", S.slotArt)
S.A.bars[1].slotBg = false
ns.abLook(S.ab[1], S.A.bars[1], 1)
assert(S.slotArt._alpha == 0, "slot background hidden (no SlotBackground on this button)")
S.A.bars[1].slotBg = true
ns.abLook(S.ab[1], S.A.bars[1], 1)
assert(S.slotArt._alpha == 1, "and shown again")
-- the template's red Auto Shot flash sits over the icon, not the hidden frame art, rounded with it
S.fl = new("Texture")
S.fl.SetAllPoints = function(self, to) self._all = to end
rawset(S.ab[1], "Flash", S.fl)
S.A.bars[1].radius = 25
ns.abLook(S.ab[1], S.A.bars[1], 1)
assert(S.fl._all == S.ab[1].wpIcon and S.fl._masks[S.ab[1].wpMask], "flash over the icon, rounded")
S.A.bars[1].radius = 0
ns.abLook(S.ab[1], S.A.bars[1], 1)
assert(not S.fl._masks[S.ab[1].wpMask], "square again")
assert(#S.ab >= 12 and not (S.ab[13] and S.ab[13]:IsShown()) and S.ab[1]._template == "ActionBarButtonTemplate" and S.ab[1]._attr.action == 1
    and S.ab[12]._attr.action == 12, "twelve buttons on slots 1-12")
assert(S.ab[2]._point[1] == "TOPLEFT" and S.ab[2]._point[4] == 40 and ns.ab.frames[1]._point[1] == "BOTTOM",
    "right then down, 36 + 4 apart, at the screen's bottom")
-- smaller buttons are scaled, not resized (the template's art has fixed sizes); gaps stay true
S.A.bars[1].size = 18; fire("UNIT_MAXPOWER")
assert(S.ab[1]._scale == 0.5 and S.ab[1]._w == nil and S.ab[2]._point[4] * 0.5 == 22,
    "half scale; the next one 18 + 4 on, in the bar's units")
assert(S.ab[1].wpKey._font[2] == 22 and S.ab[1].wpIcon._points[1][4] == 2, "text and border keep their size")
S.A.bars[1].size = 36; fire("UNIT_MAXPOWER")
S.A.bars[1].grow, S.A.bars[1].cols, S.A.bars[1].rows = "leftup", 6, 2; fire("UNIT_MAXPOWER")
assert(S.ab[7]._point[1] == "BOTTOMRIGHT" and S.ab[7]._point[4] == 0 and S.ab[7]._point[5] == 40
    and S.ab[2]._point[4] == -40, "left, then up: the seventh starts a row above")
-- empty slots hidden: only buttons with something on them show; the template shows them while dragging
S.hasAction, S.A.bars[1].hideEmpty = { [1] = true, [3] = true }, true; fire("UNIT_MAXPOWER")
assert(S.ab[1]:IsShown() and not S.ab[2]:IsShown() and S.ab[3]:IsShown() and S.ab[2]._attr.showgrid == 0,
    "empty ones hidden, the rest keep their place")
-- picking up a spell shows every hidden slot to drop it on; dropping it there keeps that one
fire("ACTIONBAR_SHOWGRID")
assert(S.ab[2]:IsShown() and S.ab[5]:IsShown(), "dragging: the empty slots show")
fire("ACTIONBAR_HIDEGRID") -- the drag ends first: the slot is still empty then (as in game)
assert(not S.ab[2]:IsShown(), "drag over, nothing landed yet")
assert(evFrame._ev.ACTIONBAR_SLOT_CHANGED, "listening for a slot's contents changing")
S.hasAction[2] = true; fire("ACTIONBAR_SLOT_CHANGED", 2)
assert(S.ab[2]:IsShown() and not S.ab[5]:IsShown(), "the spell lands on slot 2: it shows, the rest stay hidden")
GetCursorInfo = function() return S.cursor end
S.cursor = "item"; fire("CURSOR_CHANGED")
assert(S.ab[5]:IsShown(), "an item on the cursor counts too")
S.cursor = nil; fire("CURSOR_CHANGED")
assert(not S.ab[5]:IsShown(), "cursor empty: hidden again")
S.hasAction[2] = nil
S.A.bars[1].hideEmpty = false; fire("UNIT_MAXPOWER")
assert(S.ab[2]:IsShown() and S.ab[2]._attr.showgrid == 1, "shown again")
-- mouseover: faded out, in under the cursor; the buttons stay (only the alpha changes)
S.f1 = ns.ab.frames[1]
S.A.bars[1].mouseover = true; ns.configOpen = false; fire("UNIT_MAXPOWER")
S.mouseOver = false; S.f1._scripts.OnUpdate(S.f1, 1)
assert(S.f1._alpha == 0 and S.ab[1]:IsShown(), "away from it: faded out, still there")
S.mouseOver = true; S.f1._scripts.OnUpdate(S.f1, 1)
assert(S.f1._alpha == 1, "under the cursor: in")
S.mouseOver = false; ns.ab.dragging = true; S.f1._scripts.OnUpdate(S.f1, 1)
assert(S.f1._alpha == 1, "dragging a spell to it: in")
ns.ab.dragging = false
S.A.bars[1].mouseover = false; fire("UNIT_MAXPOWER")
assert(not S.f1._scripts.OnUpdate and S.f1._alpha == 1, "off: always shown")
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
assert(S.bindPrio == true, "over other addons' bindings on the same key")
ns.abBindMode(true); S.ab[3]._scripts.OnEnter(S.ab[3]); ns.abKey("Q")
assert(S.A.binds["3"] == "Q" and S.binds.Q == "WolfpackActionBar1Button3", "a plain key binds too")
-- the Mac's Command key: never bound by itself, and part of the chord
IsMetaKeyDown = function() return S.meta end
S.meta = true; ns.abKey("LMETA"); ns.abKey("E"); S.meta = false
assert(S.A.binds["3"] == "META-E" and S.binds["META-E"] and S.ab[3].wpKey._text == "ME", "Command+E, shown ME")
-- mouse: the wheel and the middle / side buttons bind on the hovered button; clicks cast nothing
assert(S.ab[3]._wheel == true and #S.ab[3]._clicks == 0, "binding: wheel on, clicks off")
S.ab[3]._scripts.OnMouseWheel(S.ab[3], 1)
assert(S.A.binds["3"] == "MOUSEWHEELUP" and S.ab[3].wpKey._text == "WU", "wheel up")
S.ab[3]._scripts.OnMouseDown(S.ab[3], "Button4")
assert(S.A.binds["3"] == "BUTTON4" and S.ab[3].wpKey._text == "B4", "side button, shown B4")
S.ab[3]._scripts.OnMouseDown(S.ab[3], "MiddleButton")
assert(S.A.binds["3"] == "BUTTON3", "middle button")
S.ab[3]._scripts.OnMouseDown(S.ab[3], "LeftButton")
assert(S.A.binds["3"] == "BUTTON3", "left click: left for dragging and Done")
S.A.binds["3"] = "SHIFT-3"; ns.abBinds()
SlashCmdList.WOLFPACKADDON("binds") -- the report runs
S.ab[3]._scripts.OnLeave(S.ab[3]); ns.ab.buttons[2][1]._scripts.OnEnter(ns.ab.buttons[2][1])
S.shift = true; ns.abKey("3"); S.shift = false
assert(S.A.binds["13"] == "SHIFT-3" and not S.A.binds["3"] and S.ab[3].wpKey._text == "", "the key moved")
ns.abKey("ESCAPE")
assert(not S.A.binds["13"] and not S.binds["SHIFT-3"], "Escape on a button: unbound")
S.combat = true; ns.abKey("Q"); S.combat = false
assert(not S.A.binds["13"], "no binding in combat")
ns.ab.buttons[2][1]._scripts.OnLeave(ns.ab.buttons[2][1]); ns.abKey("ESCAPE")
assert(not ns.ab.binding and not ns.ab.binder:IsShown(), "Escape off the buttons: done")
assert(S.ab[3]._wheel == false and S.ab[3]._clicks[1] == "AnyUp", "done: wheel off, clicks back")
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
assert(StanceButton1._parent == S.sf and StanceButton2._point[2] == S.sf
    and math.abs(StanceButton2._point[4] * StanceButton2._scale - 34) < 1e-9
    and math.abs(StanceButton1._scale * 36 - 30) < 1e-9, "the stance buttons in a bar of yours, 30 + 4 apart")
assert(S.sf._point[1] == "BOTTOM" and S.sf._point[2] == ns.ab.frames[1] and S.sf._point[3] == "TOP"
    and S.sf._point[5] == S.SB.gap, "on top of bar 1, centered")
S.SB.align = "start"; fire("UNIT_MAXPOWER")
assert(S.sf._point[1] == "BOTTOMLEFT" and S.sf._point[3] == "TOPLEFT", "or at its left end")
S.SB.align = "center"
S.PT.show, S.PT.anchorTo, S.PT.side = true, "stance", "right"; fire("UNIT_MAXPOWER")
S.pf2 = ns.ab.special.pet.frame
assert(S.pf2._driver == "[pet] show; hide" and PetActionButton1._parent == S.pf2, "pet bar: only with a pet")
assert(S.pf2._point[2] == S.sf and S.pf2._point[1] == "LEFT" and S.pf2._point[3] == "RIGHT",
    "right of the stance bar, centered on it")
S.SB.cols, S.SB.rows = 2, 1; fire("UNIT_MAXPOWER")
assert(StanceButton3._parent ~= S.sf and StanceButton3._parent ~= StanceBar, "a third doesn't fit two: parked")
-- keybind mode works on them too, by their own slot names
ns.abBindMode(true); StanceButton1._scripts.OnEnter(StanceButton1); ns.abKey("F1")
assert(prof().actionbars.binds["stance:1"] == "F1" and S.binds.F1 == "StanceButton1", "F1 on the first stance")
StanceButton1._scripts.OnLeave(StanceButton1); ns.abBindMode(false)
S.SB.show, S.SB.cols = false, 10; fire("UNIT_MAXPOWER")
assert(StanceButton1._parent == StanceBar and StanceButton2._point[2] == StanceBar and StanceButton2._point[4] == 30
    and StanceButton1._scale == 1, "off: given back where they were, at their own scale")
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
-- Unit frames: a block with one side fixed, frames in lines of `per`, players by role order then
-- their pets; a stand-in group while the options are open; laid out out of combat only
;(function()
    local U, o = ns.uf, prof().unitframes
    local keptOpen, keptUnits = ns.configOpen, S.units
    CompactRaidFrameContainer = new()
    CompactRaidFrameContainer._parent = UIParent
    -- the options pages have been clicked through above: start from known settings
    o.show, o.replace, U.preview = true, true, 10
    o.pets, o.petHeight, o.power, o.roleIcon, o.marker, o.rangeFirst = true, 14, true, true, true, true
    for _, g in ipairs({ o.g5, o.g10 }) do -- a party and a raid of ten, set alike
        g.fixed, g.grow, g.size, g.per, g.gap, g.frameHeight, g.frameWidth = "width", "down", 400, 5, 4, 40, 90
        g.x, g.y = -500, 200
        g.buffs.mode, g.buffs.max, g.buffs.cols, g.buffs.rows, g.buffs.size = "mine", 3, 3, 1, 14
        g.buffs.point, g.buffs.x, g.buffs.y = "TOPRIGHT", -2, -2
    end
    o.roles, o.bars.tothealth.colorMode = { "TANK", "HEALER", "DAMAGER" }, "class"
    o.res.place, o.res.point, o.res.inset, o.res.x, o.res.y, o.res.width = "below", "BOTTOM", 2, 0, 0, 0
    ns.configOpen = true
    U.sync()
    local B = U.buttons
    local function used() local n = 0; for _, b in ipairs(B) do if b.entry then n = n + 1 end end; return n end
    assert(CompactRaidFrameContainer._parent == hider, "Blizzard's raid frames hidden")
    -- ten stand-ins: two tanks, four healers, four damage dealers; a hunter's and a warlock's pet
    assert(used() == 12 and B[1].entry.dummy == 1 and B[2].entry.dummy == 9 and B[3].entry.role == "HEALER"
        and B[7].entry.role == "DAMAGER" and B[11].entry.pet and B[12].entry.pet, "tanks, healers, damage, pets")
    -- fixed width 400, five a row, gap 4: frames 76.8 wide, 40 high (set), rows going down
    local p2, p6 = B[2]._point, B[6]._point
    local function near(a, b) return math.abs(a - b) < 1e-9 end
    assert(B[1]._point[1] == "TOPLEFT" and near(p2[4], 80.8) and p2[5] == 0 and p6[4] == 0
        and near(p6[5], -44) and near(B[2]._w, 76.8) and B[2]._h == 40, "rows of five")
    assert(near(B[11]._point[5], -88) and B[11]._h == 14 and B[11]._point[4] == 0, "pets in a line of their own, own height")
    assert(B[11].health.segs[1]._sbc[1] == prof().colors.class.HUNTER[1], "a pet in its owner's class color")
    assert(U.frame._point[1] == "TOPLEFT" and U.frame._w == 400 and near(U.frame._h, 102), "the block: as tall as it needs")
    assert(B[1].role:IsShown() and B[1].marker:IsShown() and not B[2].marker:IsShown(), "role icon, a raid marker")
    -- auras: up to three buffs in a row from the top right; ten members take the 10's settings
    o.g10.buffs.x = -6
    U.sync()
    local ic = B[1].icons.buffs
    assert(U.cur == o.g10 and #ic == 3 and ic[1]._point[1] == "TOPRIGHT" and ic[1]._point[4] == -6
        and ic[2]._point[4] == -6 - 15, "buffs: the 10's spot, growing left")
    -- icons inset by their border, the edge in the border color
    o.g10.buffs.border, o.g10.buffs.borderColor = 2, { 0.2, 0.4, 0.6, 1 }
    U.sync()
    assert(ic[1].tex._points[1][2] == 2 and ic[1].tex._points[2][3] == 2 and ic[1].edge:IsShown()
        and ic[1].edge._color[3] == 0.6, "buff border: inset, colored")
    o.g10.buffs.border = 0
    U.sync()
    assert(not ic[1].edge:IsShown(), "no border")
    -- hover: a fill and a border over the frame, in its shape
    local hv = B[1].hover
    o.hover.color, o.hover.borderColor, o.hover.borderSize = { 1, 0, 0, 0.3 }, { 0, 1, 0, 0.9 }, 2
    U.sync()
    assert(not hv:IsShown(), "no hover yet")
    B[1]._scripts.OnEnter(B[1])
    assert(hv:IsShown() and hv.fill._color[1] == 1 and hv.fill._color[4] == 0.3 and hv.edges[1]._color[2] == 1
        and hv.edges[1]._h == 2 and hv.edges[3]._w == 2 and hv.fill._points[1][2] == 2, "hovered: fill and border")
    B[1]._scripts.OnLeave(B[1])
    assert(not hv:IsShown(), "and gone again")
    o.hover.show = false
    B[1]._scripts.OnEnter(B[1])
    assert(not hv:IsShown(), "turned off")
    -- with round corners the border follows them: straight edges between, quarter rings at the
    -- corners (a disc of r, a hole of r - t); thick enough, the hole closes
    local keptRadius = prof().colors.radius
    prof().colors.radius = 6
    U.sync()
    local q = hv.corners[1]
    assert(q:IsShown() and q._w == 6 and q.disc._w == 12 and q.hole._w == 16 and q._masks[q.hole]
        and hv.edges[1]._points[1][2] == 6 and hv.fill._points[1][2] == 2, "round border: rings at the corners")
    o.hover.borderSize = 6
    U.sync()
    assert(q:IsShown() and not q._masks[q.hole], "as thick as the corner: no hole")
    prof().colors.radius, o.hover.borderSize = keptRadius, 2
    U.sync()
    assert(not q:IsShown() and hv.edges[1]._points[1][2] == 0, "square: plain edges")
    -- the resource bar: below the health bar, or inside the frame at its anchor, inset
    o.powerHeight, o.res.place = 4, "below"
    U.sync()
    assert(B[1].health._h == 36 and B[1].power._point[1] == "TOPLEFT" and B[1].power._point[2] == B[1].health,
        "resources below")
    o.res.place, o.res.point, o.res.inset, o.res.y = "inside", "BOTTOM", 2, 1
    U.sync()
    assert(B[1].health._h == 40 and B[1].power._point[1] == "BOTTOM" and B[1].power._point[5] == 3
        and near(B[1].power._w, 76.8 - 4), "resources inside: anchored, inset")
    o.res.width = 30
    U.sync()
    assert(B[1].power._w == 30, "resource width set")
    o.res.width = 0
    o.res.place, o.res.y = "below", 0
    o.hover.show, o.g10.buffs.border = true, 1
    U.preview = 4
    U.sync()
    assert(U.cur == o.g5 and ic[1]._point[4] == -2 and not B[6]:IsShown(), "four: the 5's spot, the rest hidden")
    -- dragged while the options are open: the block's corner lands where it was dropped (mock: left
    -- 40, top 150, screen center 100,100), kept in the shown size's settings
    B[1]._scripts.OnDragStart(B[1])
    assert(U.moving, "dragging")
    B[1]._scripts.OnDragStop(B[1])
    assert(not U.moving and o.g5.x == -60 and o.g5.y == 50 and U.frame._point[4] == -60, "dropped: the 5's spot")
    o.g5.x, o.g5.y = -500, 200
    -- a group size's tab in the options: stand-ins of that size, in its settings
    U.preview = 20
    U.sync()
    assert(U.cur == o.g20 and B[20].entry and B[20].entry.dummy == 20, "the 20's tab: twenty stand-ins")
    U.preview = 4
    U.sync()
    -- the 20 man tab, clicked on the Unit frames page: its page, and the stand-ins follow
    assert(ns.ufTabs and ns.pages.uf20, "a tab and a page per group size")
    local function players() -- stand-ins laid out right now, pets aside
        local n = 0
        for _, b in ipairs(B) do if b.entry and b.entry.dummy and not b.entry.pet then n = n + 1 end end
        return n
    end
    byText("Unit frames")._scripts.OnClick(byText("Unit frames"), "LeftButton")
    -- each click lays out the clicked tab's group, not the one before it
    for i, size in ipairs({ 5, 10, 20, 40 }) do
        ns.ufTabs[i + 1]._scripts.OnClick(ns.ufTabs[i + 1])
        assert(ns.ufTab == size and players() == size and ns.pages["uf" .. size]:IsShown(), size .. " man tab")
    end
    ns.ufTabs[1]._scripts.OnClick(ns.ufTabs[1])
    assert(ns.ufTab == "general" and players() == 5 and ns.pages.unitframes:IsShown(), "General: five")
    byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
    assert(U.preview == nil and players() == 0, "another page: no stand-ins")
    U.preview = 4
    U.sync()
    o.g5.buffs.mode = "hide"
    U.sync()
    assert(not ic[1]:IsShown(), "buffs hidden")
    -- role order changed: damage first
    o.roles = { "DAMAGER", "TANK", "HEALER" }
    U.sync()
    assert(B[1].entry.role == "DAMAGER", "role order")
    -- fixed height 300, five a column, growing left: frames 56.8 high, 90 wide (set)
    o.g10.fixed, o.g10.grow, o.g10.size = "height", "left", 300
    U.preview = 6
    U.sync()
    assert(B[1]._point[1] == "TOPRIGHT" and near(B[6]._point[4], -94) and near(B[2]._point[5], -60.8)
        and B[2]._w == 90 and near(B[2]._h, 56.8), "columns of five, growing left")
    -- the first frame's corner, picked: from the bottom right, columns going left, frames going up
    o.g10.start = "BOTTOMRIGHT"
    U.sync()
    assert(B[1]._point[1] == "BOTTOMRIGHT" and U.frame._point[1] == "BOTTOMRIGHT" and near(B[6]._point[4], -94)
        and near(B[2]._point[5], 60.8), "from the bottom right")
    o.g10.fixed, o.g10.start = "width", "TOPRIGHT" -- rows going down, frames going left
    o.g10.size = 400
    U.sync()
    assert(B[1]._point[1] == "TOPRIGHT" and near(B[2]._point[4], -80.8) and near(B[6]._point[5], -44), "rows from the right")
    o.g10.fixed, o.g10.start, o.g10.size = "height", "", 300
    -- a real party: you and party1 (a healer); clicks target and open the menu, the game shows them
    ns.configOpen, U.preview = false, nil
    o.roles = { "TANK", "HEALER", "DAMAGER" } -- you have no role: damage, after the healer
    S.members, S.units = 2, { party1 = "HEALER" }; S.keptRaid, S.raid = S.raid, false
    U.sync()
    assert(B[1].unit == "party1" and B[2].unit == "player" and B[1]._watched and B[1]._attr.unit == "party1"
        and B[1]._attr.type1 == "target" and B[1]._attr.type2 == "togglemenu" and not B[3]._watched, "the party, by role")
    -- in your healing range first: the healer out of range drops behind you, back once in range;
    -- out of combat it is noticed by itself, in combat the order holds
    S.keptInRange = UnitInRange
    UnitInRange = function(u) return u ~= "party1", true end
    U.frame._scripts.OnUpdate(U.frame, 1)
    assert(B[1].unit == "player" and B[2].unit == "party1", "out of range: after you")
    UnitInRange = function() return true, true end
    S.combat = true
    U.frame._scripts.OnUpdate(U.frame, 1)
    assert(B[1].unit == "player", "in combat: held")
    S.combat = false
    U.frame._scripts.OnUpdate(U.frame, 1)
    assert(B[1].unit == "party1", "in range again: by role")
    o.rangeFirst = false
    UnitInRange = function(u) return u ~= "party1", true end
    U.sync()
    assert(B[1].unit == "party1", "range sort off: by role only")
    o.rangeFirst, UnitInRange = true, S.keptInRange
    U.sync()
    ns.configOpen = true -- the options on another page: still the real group
    U.sync()
    assert(B[1].unit == "party1" and not B[1].entry.dummy, "stand-ins only on the Unit frames page")
    ns.configOpen = false
    -- in combat nothing secure moves: once it ends, the new roster
    S.combat, S.members, S.units = true, 0, {} -- left the group: solo
    ns.uf.ev._scripts.OnEvent(ns.uf.ev, "GROUP_ROSTER_UPDATE")
    assert(B[1].unit == "party1" and U.pending, "in combat: waits")
    S.combat = false
    ns.uf.ev._scripts.OnEvent(ns.uf.ev, "PLAYER_REGEN_ENABLED")
    assert(not B[1]._watched and not U.pending, "after combat: solo, no frames")
    o.show = false
    U.sync()
    assert(CompactRaidFrameContainer._parent == UIParent and not U.frame:IsShown(), "off: Blizzard's again")
    ns.configOpen, S.units, S.members, CompactRaidFrameContainer, S.raid = keptOpen, keptUnits, nil, nil, S.keptRaid
    o.roles, o.g5.buffs.mode, o.g10.buffs.x = { "TANK", "HEALER", "DAMAGER" }, "mine", -2
    o.g10.fixed, o.g10.grow, o.g10.size = "width", "down", 400
end)()

-- Tooltips: the game's default spot moved to a point of the screen or the cursor; a sample while
-- the Tooltip page is open
do
    local keptTip = GameTooltip
    GameTooltip = new()
    GameTooltip.SetOwner = function(self, owner, anchor, x, y) self._owner = { owner, anchor, x, y } end
    GameTooltip_SetDefaultAnchor = function(tt, parent) tt:SetOwner(parent, "ANCHOR_NONE"); tt._default = true end
    local o = prof().tooltip
    o.mode, o.point, o.x, o.y = "screen", "TOPRIGHT", -20, -40
    ns.cfg:Show(); byText("Tooltip")._scripts.OnClick(byText("Tooltip"), "LeftButton")
    assert(GameTooltip:IsShown() and GameTooltip._point[1] == "TOPRIGHT" and GameTooltip._point[2] == UIParent
        and GameTooltip._point[4] == -20 and GameTooltip._point[5] == -40, "a sample, at the point picked")
    o.mode = "cursor"
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    assert(GameTooltip._owner[2] == "ANCHOR_CURSOR_RIGHT" and GameTooltip._owner[3] == -20, "beside the cursor")
    o.mode = "game"
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    assert(GameTooltip._owner[2] == "ANCHOR_NONE" and GameTooltip._owner[3] == nil, "the game's own spot: left alone")
    byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
    assert(not GameTooltip:IsShown(), "the sample goes with the page")
    ns.cfg:Hide()
    GameTooltip = keptTip
end

-- Micro menu: the game's buttons in a row of ours on a panel, placed on the screen or on the bag
-- bar, faded until hovered if asked; out of combat only; taken again when the game moves them
-- back; home again when turned off
do
    login("ROGUE", 3)
    MICRO_BUTTONS = { "CharacterMicroButton", "SpellbookMicroButton", "MainMenuMicroButton" }
    UpdateMicroButtonsParent = function(p) for _, n in ipairs(MICRO_BUTTONS) do _G[n]:SetParent(p) end end
    local home = new()
    local btns = {}
    for i, n in ipairs(MICRO_BUTTONS) do
        local b = new()
        b._parent, b._w, b._h = home, 28, 58
        b:SetPoint("LEFT", home, "LEFT", (i - 1) * 28, 0)
        b.GetHitRectInsets = function() return 0, 0, 18, 0 end -- the classic art: its top is see-through
        _G[n], btns[i] = b, b
    end
    local o = prof().micro
    o.show, o.anchor, o.point, o.x, o.y, o.gap, o.pad, o.scale, o.hover = true, "screen", "BOTTOMRIGHT", -10, 5, 2, 4, 1, false
    ns.micro.sync()
    local f = ns.micro.frame
    assert(btns[1]._parent == f and btns[3]._parent == f, "the game's buttons, in ours")
    assert(btns[2]._point[1] == "BOTTOMLEFT" and btns[2]._point[4] == 34 and btns[2]._point[5] == 4,
        "in a row, the gap between")
    assert(f._w == 96 and f._h == 48 and f._point[1] == "BOTTOMRIGHT" and f._point[2] == UIParent
        and f._point[4] == -10 and f._point[5] == 5, "the panel round them, on the screen's corner")
    assert(btns[1].wpBack:IsShown() and btns[1].wpBack.edge._points[1][5] == -18, "a dark square on the drawn part")
    -- on the bag bar: the game's whole bar where it has one, else its buttons (left: the last bag)
    o.anchor, o.side = "bagbar", "left"
    ns.micro.sync()
    assert(f._point[1] == "RIGHT" and f._point[2] == BagsBar and f._point[3] == "LEFT", "left of the bag bar")
    local keptBar = BagsBar
    BagsBar, CharacterBag3Slot, MainMenuBarBackpackButton = nil, new(), new()
    ns.micro.sync()
    assert(f._point[2] == CharacterBag3Slot, "a client without one: left of its last bag")
    o.side = "above"
    ns.micro.sync()
    assert(f._point[1] == "BOTTOM" and f._point[2] == MainMenuBarBackpackButton, "above it: the backpack's")
    BagsBar = keptBar
    o.hover = true
    ns.micro.sync()
    assert(f._scripts.OnUpdate == ns.abFade, "faded until hovered")
    -- the game takes them back: taken again
    UpdateMicroButtonsParent(home)
    assert(btns[1]._parent == f, "the game's move undone")
    -- not in combat
    S.combat, o.x = true, 40
    ns.micro.sync()
    assert(f._point[4] == -10 and ns.micro.pending, "in combat: waits")
    S.combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(f._point[4] == 40 and not ns.micro.pending, "placed once combat ends")
    -- off: home again
    o.show = false
    ns.micro.sync()
    assert(btns[1]._parent == home and btns[2]._point[2] == home and btns[2]._point[4] == 28 and not f:IsShown(),
        "turned off: back where the game had them")
    for _, n in ipairs(MICRO_BUTTONS) do _G[n] = nil end
    MICRO_BUTTONS, UpdateMicroButtonsParent, CharacterBag3Slot, MainMenuBarBackpackButton = nil, nil, nil, nil
end

-- Macros: one library for every character, a General tab and one per class, written into the
-- game's own slots (General: the account's, your class's: this character's); sorted by name
-- there, as the game does
do
    local game = { account = {}, char = {} }
    MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS = 120, 18
    local function at(i) return i > 120 and game.char[i - 120] or game.account[i] end
    local function sorted(l) table.sort(l, function(a, b) return a.name < b.name end) end
    local function names(l) local o = {}; for _, m in ipairs(l) do o[#o + 1] = m.name end; return table.concat(o, ",") end
    GetNumMacros = function() return #game.account, #game.char end
    GetMacroInfo = function(i) local m = at(i); if m then return m.name, m.icon, m.body end end
    CreateMacro = function(name, icon, body, per)
        local l = per and game.char or game.account
        l[#l + 1] = { name = name, icon = icon, body = body }
        sorted(l)
    end
    EditMacro = function(i, name, icon, body) local m = at(i); m.name, m.icon, m.body = name, icon, body end
    DeleteMacro = function(i) if i > 120 then table.remove(game.char, i - 120) else table.remove(game.account, i) end end
    PickupMacro = function(i) S.pickedMacro = i end
    GetMacroIcons = function(l) l[1], l[2] = 111, 222 end
    login("ROGUE", 3)
    local mac = ns.mac
    game.account = { { name = "Mount", icon = 5, body = "/use Horse" } }
    game.char = { { name = "Poison", icon = 6, body = "/use Poison" } }
    prof().macros = nil
    mac.sync()
    assert(names(mac.tab("general")) == "Mount" and names(mac.tab("ROGUE")) == "Poison",
        "the first time: the ones there are taken in")
    -- the page: tabs, a grid, the editor
    mac.P.tab, mac.P.pick, mac.P.picking = "general", 1, false -- the controls were all poked above
    ns.cfg:Show(); byText("Macros")._scripts.OnClick(byText("Macros"), "LeftButton")
    local f = mac.f
    assert(f and ns.pages.macros:IsShown() and f.tabs[1].key == "general", "the Macros page, General first")
    local mine
    for _, b in ipairs(f.tabs) do if b.key == "ROGUE" then mine = b end end
    assert(mine._text == "Rogue (you)", "your class's tab says so")
    -- a new one on General, renamed and written into the account's slots
    f.cells[2]._scripts.OnClick(f.cells[2]) -- the +
    assert(names(game.account) == "Mount,New macro" and mac.P.pick == 2, "+ makes one, in the game too")
    f.name._text, f.body._text = "Taunt", "/cast Taunt"
    f.save._scripts.OnClick(f.save)
    assert(names(game.account) == "Mount,Taunt" and game.account[2].body == "/cast Taunt", "saved: renamed, its text in")
    -- the icon picker
    f.iconBtn._scripts.OnClick(f.iconBtn)
    assert(mac.P.picking and f.iconCells[2]:IsShown() and f.iconCells[2].icon == 111, "icons to pick")
    f.iconCells[2]._scripts.OnClick(f.iconCells[2])
    f.save._scripts.OnClick(f.save)
    assert(game.account[2].icon == 111, "the icon picked")
    -- dragged to a bar: the macro on the cursor
    f.drag._scripts.OnClick(f.drag)
    assert(S.pickedMacro == 2, "picked up for a bar")
    -- the rogue tab: into this character's slots
    mine._scripts.OnClick(mine)
    local k = mac.new("ROGUE")
    mac.save("ROGUE", k, "Kick", nil, "/cast Kick")
    assert(names(game.char) == "Kick,Poison", "a class macro in the character's slots")
    -- another rogue: its own slots get the class's macros; a mage gets General only
    game.char = {}
    mac.sync()
    assert(names(game.char) == "Kick,Poison" and names(game.account) == "Mount,Taunt", "another rogue: the same")
    login("MAGE", 0)
    game.char = {}
    mac.sync()
    assert(#game.char == 0 and names(mac.tab("MAGE")) == "", "a mage: none of the rogue's")
    -- deleted on one rogue: gone from the next rogue's slots too
    login("ROGUE", 3)
    mac.delete("ROGUE", mac.find(mac.tab("ROGUE"), "Kick"))
    game.char = { { name = "Kick", icon = 1, body = "/cast Kick" }, { name = "Poison", icon = 6, body = "/use Poison" } }
    mac.sync()
    assert(names(game.char) == "Poison", "deleted everywhere")
    -- one made in Blizzard's window is left alone
    CreateMacro("Mine", 1, "/wave", true)
    mac.sync()
    assert(names(game.char) == "Mine,Poison", "a macro of the game's own stays")
    -- in combat nothing is written; once it ends, it is
    S.combat = true
    mac.save("general", 1, "Mount", nil, "/use Bigger Horse")
    assert(game.account[1].body == "/use Horse" and mac.pending, "in combat: waits")
    S.combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(game.account[1].body == "/use Bigger Horse" and not mac.pending, "written once combat ends")
    byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
    ns.cfg:Hide()
    -- the library is the profile's: the rogue's stays on the rogue's profile
    assert(names(prof().macros.tabs.general) == "Mount,Taunt", "in the profile")
    -- a library from before, beside the profiles: moved into Alpha, and a child of Alpha inherits it
    local store = WolfpackAddonDB
    store.profiles.Alpha = store.profiles.Alpha or {}
    store.profiles.Alpha.macros = nil
    store.macros = { tabs = { general = { { name = "Old", icon = 1, body = "/old" } } }, deleted = {} }
    login("ROGUE", 3)
    assert(store.macros == nil and names(store.profiles.Alpha.macros.tabs.general) == "Old", "moved into Alpha")
    ns.useProfile("Alpha")
    store.parents.Rogue, store.overrides.Rogue = "Alpha", {}
    ns.useProfile("Rogue")
    assert(names(mac.tab("general")) == "Old" and names(game.account):find("Old"), "the child gets Alpha's macros")
    store.parents.Rogue, store.overrides.Rogue = nil, nil
    -- from an import string: junk dropped, names and text cut to the game's limits
    local c = mac.clean({ tabs = { general = { { name = ("x"):rep(30), icon = {}, body = 5 }, "junk", { name = "" } },
        [7] = {} }, deleted = { general = { Gone = true, Bad = 1 } } })
    assert(#c.tabs.general == 1 and #c.tabs.general[1].name == 16 and c.tabs.general[1].icon == mac.QUESTION
        and c.tabs.general[1].body == "" and c.tabs[7] == nil, "an imported library, cleaned")
    assert(c.deleted.general.Gone and c.deleted.general.Bad == nil, "only true tombstones")
    -- the question mark shows what the macro would cast now, as on a bar
    S.spellTextures = { Kick = 501, ["Sinister Strike"] = 502 }
    local q = { name = "Q", icon = mac.QUESTION, body = "#showtooltip\n/cast [mod:shift] Kick; Sinister Strike" }
    assert(mac.shown("MAGE", q) == 501, "no option parser: the first choice")
    assert(mac.read("/castsequence reset=3 Sinister Strike, Kick") == 502 and mac.read("/say hi") == nil,
        "a sequence: its first step; no spell: nothing")
    QueryCastSequence = function() return "Kick" end
    assert(mac.read("/castsequence reset=3 Sinister Strike, Kick") == 501, "a sequence: the step it is on")
    QueryCastSequence = nil
    SecureCmdOptionParse = function() return S.shift and "Kick" or "Sinister Strike" end
    assert(mac.shown("MAGE", q) == 502, "its conditions, read: no shift")
    S.shift = true
    assert(mac.shown("MAGE", q) == 501, "shift held: the other spell")
    assert(mac.shown("MAGE", { name = "C", icon = 7, body = "/cast Kick" }) == 7, "an icon picked stays")
    -- in the game's slots, the game says what it casts
    game.char = { { name = "Q", icon = 1, body = "" } }
    GetMacroSpell = function(i) return i == 121 and 42 or nil end
    assert(mac.shown("ROGUE", { name = "Q", icon = mac.QUESTION, body = "" }) == 142, "asked of the game")
    SecureCmdOptionParse, GetMacroSpell, S.shift, S.spellTextures = nil, nil, nil, nil
end

-- Blizzard's own combo points: see-through when asked, also through its own fades; given back
do
    local bf = CreateFrame("Frame")
    RogueComboPointBarFrame = bf
    assert(ns.comboHide, "the option, under the combo points")
    ns.blizzCombo()
    assert(bf._alphaSets == nil, "untouched until asked")
    prof().regular.hideBlizzCombo = true
    ns.blizzCombo()
    assert(bf:GetAlpha() == 0, "hidden")
    bf:SetAlpha(1) -- Blizzard fading its points in
    assert(bf:GetAlpha() == 0, "stays hidden through Blizzard's fades")
    prof().regular.hideBlizzCombo = false
    ns.blizzCombo()
    bf:SetAlpha(0.5)
    assert(bf:GetAlpha() == 0.5, "given back: Blizzard's again")
    RogueComboPointBarFrame = nil
end

-- Swing timer per class: one set from before is copied into every class, once; then each class its own
do
    local here = WolfpackAddonDB.chars[S.name .. " - Realm"]
    local sw, swf = prof().regular.bars.swing, ns.swingFrames.regular
    sw.classesSet, sw.off = false, true
    ns.useProfile(here)
    assert(sw.classesSet and sw.classes.MAGE.off and sw.classes.WARRIOR.off, "the old ticks, in every class")
    sw.off = false
    ns.useProfile(here)
    assert(sw.classes.MAGE.off, "only once: the per-class ticks stay")
    sw.classes[S.class].off, sw.classes[S.class].ranged = false, false
    prof().locked = false; fire("UNIT_MAXPOWER") -- placing: every ticked row shows
    assert(swf[1]:IsShown() and not swf[2]:IsShown(), "another class's off hand is not yours")
    sw.classes[S.class].off = true; fire("UNIT_MAXPOWER")
    assert(swf[2]:IsShown(), "your class's tick")
    sw.classes[S.class].off, prof().locked = false, true
    fire("UNIT_MAXPOWER")
    assert(ns.swingDialog and ns.swingButton, "the per-class window, from the swing timer's settings")
end

-- Trinket manager: one list, top first; a slot on cooldown pulls the next ready one
do
    local T, O = ns.trink, prof().trinkets
    local worn, cds, equips = { [13] = 101, [14] = 102 }, {}, {}
    local bag = { 103, 900 } -- a trinket and something else
    local keep = { GetInventoryItemID, C_Container.GetContainerItemID, C_Container.GetContainerNumSlots,
        C_Container.GetItemCooldown, C_Item.GetItemInfoInstant, EquipItemByName }
    GetInventoryItemID = function(_, s) return worn[s] end
    C_Container.GetContainerNumSlots = function(b) return b == 0 and #bag or 0 end
    C_Container.GetContainerItemID = function(b, i) return b == 0 and bag[i] or nil end
    C_Item.GetItemInfoInstant = function(id) return id, nil, nil, id < 900 and "INVTYPE_TRINKET" or "INVTYPE_HEAD" end
    C_Container.GetItemCooldown = function(id) local c = cds[id]; if c then return c[1], c[2], 1 end return 0, 0, 1 end
    EquipItemByName = function(id, slot)
        equips[#equips + 1] = id .. ">" .. slot
        for s, x in pairs(worn) do if x == id then worn[s] = nil end end
        for i, x in ipairs(bag) do if x == id then table.remove(bag, i) end end
        if worn[slot] then bag[#bag + 1] = worn[slot] end
        worn[slot] = id
    end
    S.time, T.busyUntil, T.hold, T.queued = 5000, nil, {}, {}
    O.queue = {}
    assert(table.concat(T.list(), ",") == "101,102,103", "your trinkets, worn and in the bags; nothing else")
    -- none in the rotation (as new ones start): nothing is swapped in
    O.rotation = {}
    O.queue = { 103, 101, 102 }
    T.apply()
    assert(#equips == 0, "out of the rotation: left in the bags")
    O.rotation = { 101, 102, 103 }
    -- you put 103 first: the slot not wearing a top-two one gets it
    O.queue = { 103, 101, 102 }
    T.apply()
    assert(equips[1] == "103>14" and worn[13] == 101 and worn[14] == 103, "the top two worn")
    -- 103 used: 2 min cooldown. The next ready one comes in; 103 back once it is ready
    cds[103] = { 5000, 120 }
    T.busyUntil = nil; T.apply()
    assert(worn[14] == 102, "on cooldown: the next of the list")
    cds[102] = { 5005, 30 } -- just put on: locked 30 s, which counts as ready
    S.time = 5100; T.busyUntil = nil; T.apply()
    assert(worn[14] == 103, "within 30 s of ready: the higher one back")
    -- picked by hand: worn until it is used, whatever the list says
    cds[102], cds[103] = nil, nil
    T.pick(1, 102)
    assert(worn[13] == 102 and T.hold[1], "picked: worn in that slot")
    T.busyUntil = nil; T.apply()
    assert(worn[13] == 102, "held against the list")
    cds[102] = { 5200, 90 }; S.time = 5201
    T.busyUntil = nil; T.apply()
    assert(not T.hold[1] and worn[13] == 101, "used: the list takes over again")
    -- the key on a trinket on cooldown: the next; in combat, once combat ends
    O.queue, cds[103], cds[102] = { 101, 102, 103 }, { 5201, 120 }, nil
    worn[13], worn[14], bag = 103, 101, { 102 }
    O.auto = false
    S.combat = true
    T.press(T.buttons[1])
    assert(worn[13] == 103 and T.queued[1], "in combat: asked for, not done")
    S.combat = false
    T.t, T.n = 1, 0
    T.tick(nil, 0)
    assert(worn[13] == 102 and not T.queued[1], "combat over: the next ready one")
    O.auto = true
    -- dragged onto a bar: one macro per slot, "/use 13", made once and put on the cursor
    ;(function()
        local made, picked = {}, nil
        local keptGI, keptCM, keptPM = GetMacroIndexByName, CreateMacro, PickupMacro
        GetMacroIndexByName = function(n) for i, m in ipairs(made) do if m.name == n then return i end end return 0 end
        CreateMacro = function(n, icon, body, per) made[#made + 1] = { name = n, icon = icon, body = body, per = per } end
        PickupMacro = function(n) picked = n end
        local b = T.buttons[1]
        b._scripts.OnDragStart(b)
        assert(#made == 1 and made[1].body == "#showtooltip\n/use 13" and not made[1].per and picked == "WP Trinket 1",
            "a macro of the account's, on the cursor")
        b._scripts.OnDragStart(b)
        assert(#made == 1, "made once")
        S.combat = true; picked = nil
        b._scripts.OnDragStart(b)
        assert(picked == nil, "not in combat: bars can't change then")
        S.combat = false
        GetMacroIndexByName, CreateMacro, PickupMacro = keptGI, keptCM, keptPM
        -- used from the bar, on cooldown: the button's own pull
        worn[13], cds[102], cds[103] = 102, { S.time, 120 }, nil
        T.busyUntil, T.buttons[1].wpLast = nil, nil
        UseInventoryItem(13)
        assert(worn[13] == 103, "used from a bar on cooldown: the next ready one pulled")
        cds[102] = nil
    end)()
    -- the moving arrows, and the import
    T.move(102, -1)
    assert(table.concat(T.list(), ",") == "102,101,103", "one up")
    assert(table.concat(T.clean({ 5, "x", 2.5, -1, 7 }), ",") == "5,7", "an imported list: item IDs only")
    -- a key on each: bound only while the buttons show
    prof().actionbars.binds["trinket:1"] = "F"
    O.show = false; ns.abBinds()
    assert(S.binds.F ~= "WolfpackTrinket1", "hidden: no key")
    O.show = true; ns.abBinds()
    assert(S.binds.F == "WolfpackTrinketKey1", "shown: the key uses trinket 1, by its key twin")
    assert(T.buttons[1]:GetAttribute("useOnKeyDown") == false
        and T.buttons[1].wpKeyButton:GetAttribute("useOnKeyDown") == nil, "the mouse on release; the key as set")
    -- no key of its own: it shows the key of the bar button its macro sits on (yours, else the game's)
    do
        local kept = { GetMacroIndexByName, GetActionInfo, GetBindingKey }
        prof().actionbars.binds["trinket:1"] = nil
        GetMacroIndexByName = function(n) return n == "WP Trinket 1" and 7 or 0 end
        GetActionInfo = function(slot) if slot == 27 then return "macro", 7 end end
        GetBindingKey = function(cmd) if cmd == "MULTIACTIONBAR3BUTTON3" then return "SHIFT-4" end end
        fire("ACTIONBAR_SLOT_CHANGED")
        assert(T.buttons[1].wpKey._text == "S4" and T.buttons[2].wpKey._text == "",
            "the macro on the right bar's 3rd button: its key, S4; the other slot has none")
        prof().actionbars.binds["27"] = "Q"
        fire("UPDATE_BINDINGS")
        assert(T.buttons[1].wpKey._text == "Q", "on one of your bars: your key for it")
        prof().actionbars.binds["27"] = nil
        GetMacroIndexByName, GetActionInfo, GetBindingKey = kept[1], kept[2], kept[3]
        prof().actionbars.binds["trinket:1"] = "F"
    end
    T.sync()
    assert(T.holder:IsShown() and T.buttons[2]._point, "the two buttons, placed")
    -- the action bars' look, and a clear mark on the one under the mouse
    ;(function() -- a function of its own: this file's main chunk is at Lua's 200 locals
    O.borderColor, O.hoverColor = { 0, 0, 0, 1 }, { 1, 0.82, 0, 0.3 }
    local bars = prof().actionbars.bars
    local bar1 = bars[1]
    bars[1] = bar1 or {}
    local keptR = bars[1].radius
    bars[1].radius, O.radius = 25, 0 -- corners: your action bars' (the Colors page's Action buttons ones)
    T.sync()
    assert(O.radius == 25, "the action bars' corners")
    local b1 = T.buttons[1]
    assert(b1.wpIcon._masks and b1.wpIcon._masks[b1.wpMask] and b1.wpHover._masks[b1.wpMask], "rounded, hover too")
    b1._scripts.OnEnter(b1)
    assert(b1.wpHover:IsShown() and b1.wpEdge._color[1] == 1 and b1.wpEdge._color[4] == 1, "hovered: lit, gold border")
    assert(not T.buttons[2].wpHover:IsShown(), "only that one")
    b1._scripts.OnLeave(b1)
    assert(not b1.wpHover:IsShown() and b1.wpEdge._color[1] == 0, "left: as it was")
    -- the flyout: icons only, the list's first nearest the button; it waits for the mouse to cross over
    O.flyout, O.size = "up", 36
    S.mouseOver = true
    T.open(b1)
    local f, n = T.flyout, #T.list()
    assert(f:IsShown() and f.icons[1]:IsShown() and f.icons[n]:IsShown() and not f.icons[n + 1],
        "an icon per trinket")
    assert(f.icons[1]._point[1] == "BOTTOM" and f.icons[2]._point[5] == 44 and f._point[2] == b1,
        "first nearest, going up, touching the button")
    assert(f.icons[1].tex._masks and f.icons[1].tex._masks[f.icons[1].mask], "the icons rounded as the buttons")
    S.mouseOver = false
    f._scripts.OnUpdate(f, 0.2)
    assert(f:IsShown(), "on the way over: still open")
    S.mouseOver = true
    f._scripts.OnUpdate(f, 0.3)
    S.mouseOver = false
    f._scripts.OnUpdate(f, 0.3)
    assert(f:IsShown(), "back on it: the wait starts again")
    f._scripts.OnUpdate(f, 0.2)
    assert(not f:IsShown(), "gone a moment after the mouse left both")
    -- the sidebar: arrows move it along the list, each pointing the way it goes; a toggle, in the rotation
    T.open(b1)
    assert(f._point[4] == 20 and f.icons[1]._point[4] == -20, "the icons in line with the button, the sidebar beside")
    local second = T.list()[2]
    assert(f.icons[1].earlier._enabled == false and f.icons[2].earlier._enabled == true, "the first can't go higher")
    assert(f.icons[2].earlier.tex._rot == math.pi, "going up: higher in the list points down, at the button")
    f.icons[2].earlier._scripts.OnClick(f.icons[2].earlier)
    assert(T.list()[1] == second, "up the list")
    f.icons[1].later._scripts.OnClick(f.icons[1].later)
    assert(T.list()[2] == second, "down the list")
    local r = f.icons[2].rot
    assert(r._checked == true, "in the rotation: checked")
    r:SetChecked(false); r._scripts.OnClick(r)
    assert(not T.inRot(second) and f.icons[2].tex._desat and f.icons[3].num._text == 2, "out: grey, unnumbered")
    r:SetChecked(true); r._scripts.OnClick(r)
    assert(T.inRot(second) and not f.icons[2].tex._desat, "back in")
    T.busyUntil = nil
    f.icons[3]._scripts.OnClick(f.icons[3], "LeftButton")
    assert(T.hold[1] and T.hold[1].id == T.list()[3], "a click: picked for this button")
    T.hold[1] = nil
    S.mouseOver = nil
    T.flyout:Hide()
    bars[1].radius = keptR
    if not bar1 then bars[1] = nil end
    O.radius = 0
    end)()
    O.show, prof().actionbars.binds["trinket:1"] = false, nil
    T.sync(); ns.abBinds()
    GetInventoryItemID, C_Container.GetContainerItemID, C_Container.GetContainerNumSlots,
        C_Container.GetItemCooldown, C_Item.GetItemInfoInstant, EquipItemByName = unpack(keep)
end

-- Class buffs: one row of what you can put on yourself; on you a plain buff, missing it flashes
do
    local keep = { C_Spell.GetSpellInfo, S.known, S.auras, S.weapons, S.mainEnchant, S.mainMs, S.combat }
    S.combat = nil
    local NAMES = { [1459] = "Arcane Intellect", [23028] = "Arcane Brilliance", [168] = "Frost Armor",
        [7302] = "Ice Armor", [6117] = "Mage Armor", [30482] = "Molten Armor", [2842] = "Poisons" }
    C_Spell.GetSpellInfo = function(id) return NAMES[id] and { name = NAMES[id] } end
    login("MAGE", 0)
    S.known = { [1459] = true, [168] = true } -- not Molten Armor, not Brilliance
    S.auras = { { name = "Arcane Brilliance", icon = 7, duration = 3600, expirationTime = S.time + 100 } }
    local row = ns.classBuffs()
    assert(#row == 2 and row[1].aura and row[1].aura.name == "Arcane Brilliance",
        "the group version fills Arcane Intellect")
    assert(row[2].missing and row[2].icon == 268, "no armor on: missing, with Frost Armor's icon")
    S.known = {}
    assert(#ns.classBuffs() == 0, "nothing learned: nothing shows")
    -- drawn on your health: the missing one flashes
    S.known = { [1459] = true, [168] = true }
    local hp = prof().regular.bars.health
    hp.show, hp.selfbuffs.show = true, true
    hp.buffs.anchorTo = "class"
    fire("UNIT_AURA", "player")
    local f = ns.frames.health
    local cb, icons = f.auraBoxes.selfbuffs, f.auraIcons.selfbuffs
    assert(cb and cb.n == 2 and icons[1]:IsShown() and icons[2].missing and not icons[1].missing, "two icons, one missing")
    ns.cbTick(cb, 0.5)
    assert(icons[2]._alpha < 1 and icons[1]._alpha == 1, "the missing one flashes")
    -- the class buffs open the buffs row; your other buffs follow them, the group gap apart
    local pt = f.auraBoxes.buffs._points[1]
    assert(cb._points[1][2] == ns.auraSlots.buffs and pt[1] == "TOPLEFT" and pt[2] == cb and pt[3] == "TOPRIGHT"
        and pt[4] == hp.auraGroupGap, "buffs after the class buffs, on one row")
    hp.buffs.anchorTo = "bar"
    -- every weapon you hold too, whatever the class: bare, it flashes in its own picture; with a
    -- stone or oil on, its time left
    S.weapons, S.mainEnchant, S.mainMs = { [16] = 777 }, false, 0
    hp.selfbuffs.weapons = true -- (on by default; the options test above clicked every box)
    row = ns.classBuffs()
    assert(#row == 3 and row[3].missing and row[3].icon == 777, "a bare main hand flashes")
    S.mainEnchant, S.mainMs = true, 30000
    row = ns.classBuffs()
    assert(row[3].hand and row[3].icon == 777 and not row[3].missing, "an oil on it: shown, with its time")
    hp.selfbuffs.weapons = false
    assert(#ns.classBuffs() == 2, "turned off: your class's own only")
    hp.selfbuffs.weapons, S.weapons, S.mainEnchant, S.mainMs = true, nil, false, 0
    -- a rogue: a poison on each weapon there is
    login("ROGUE", 3)
    S.known, S.auras = { [2842] = true }, {}
    S.weapons = { [16] = 555 }
    S.mainEnchant, S.mainMs = true, 60000
    row = ns.classBuffs()
    assert(#row == 1 and row[1].hand and row[1].icon == 555, "the poisoned main hand; no off hand, no slot")
    S.mainEnchant, S.mainMs = false, 0
    row = ns.classBuffs()
    assert(row[1].missing and row[1].icon == 100 + 2842, "the bare weapon flashes, with the Poisons icon")
    C_Spell.GetSpellInfo, S.known, S.auras, S.weapons, S.mainEnchant, S.mainMs, S.combat = unpack(keep, 1, 7)
end

-- Absorb shields (MiniOvershields): stripes from the far end of your health and the target's,
-- as deep as the shields
do
    local hb, eh = ns.frames.health, ns.frames.enemyhealth
    S.absorb = 300
    fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    assert(hb.shield:IsShown() and hb.shield._value == 300 and hb.shield._max == 1000
        and hb.shield._reverseFill == true, "your shield, from the right")
    assert(eh.shield and not eh.resFrame.shield, "the target's health has one, its resource none")
    prof().regular.bars.health.shield = false
    fire("UNIT_MAXPOWER")
    assert(not hb.shield:IsShown(), "switched off")
    prof().regular.bars.health.shield, S.absorb = true, 0
    fire("UNIT_MAXPOWER")
    assert(hb.shield._value == 0, "no shield, no stripes")
    ns.configOpen = true; fire("UNIT_MAXPOWER")
    assert(hb.shield._value == 0.3 and hb.shield._max == 1, "a sample while the options are open")
    ns.configOpen = false; fire("UNIT_MAXPOWER")
end


-- The Load page: what starts at all, for every character; unticked parts start nothing and
-- leave the sidebar
do
    local L = WolfpackAddonDB.load
    assert(type(L) == "table" and ns.loads("combat") and ns.loads("bags"), "everything loads by default")
    L.combat = false; fire("UNIT_MAXPOWER")
    assert(not WolfpackAddonFrame:IsShown() and not fr.health:IsShown() and not fr.power:IsShown(),
        "Combat Display off: no bars")
    fire("UNIT_HEALTH", "player"); fire("UNIT_AURA", "player") -- events for bars that never were: nothing breaks
    assert(not ns.errored, "quiet")
    L.combat = nil; fire("UNIT_MAXPOWER")
    assert(WolfpackAddonFrame:IsShown() and fr.health:IsShown(), "back")
    prof().bags.show, L.bags = true, false
    assert(not ns.bags.on(), "bags off however the profile has them")
    L.bags, prof().bags.show = nil, false
    -- the page: a tick per part, and the sidebar without the unloaded ones
    byText("Load")._scripts.OnClick(byText("Load"), "LeftButton")
    local bagsCheck
    for _, f in ipairs(created) do
        if type(rawget(f, "Text")) == "table" and f.Text._text == "Bags and bank" then bagsCheck = f end
    end
    assert(ns.pages.load:IsShown() and bagsCheck and byText("Reload now"), "the page")
    bagsCheck.GetChecked = function() return false end
    bagsCheck._scripts.OnClick(bagsCheck)
    assert(L.bags == false, "unticked: off")
    local bagsEntry
    for _, s in ipairs(ns.sideEntries) do if s[1] == "bags" then bagsEntry = s[2] end end
    assert(bagsEntry and not bagsEntry:IsShown(), "its page leaves the sidebar")
    bagsCheck.GetChecked = function() return true end
    bagsCheck._scripts.OnClick(bagsCheck)
    assert(L.bags == nil and bagsEntry:IsShown(), "ticked again: back")
    byText("Reload now")._scripts.OnClick(byText("Reload now"), "LeftButton")
    assert((S.reloaded or 0) > 0, "Reload now reloads")
end
realPrint("smoke ok")
