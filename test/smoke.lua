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
function M:SetPoint(...) self._point = { ... } end
function M:SetTexture(t) self._tex = t end
function M:SetScale(v) self._scale = v end
function M:SetTextureSliceMargins(...) self._slice = { ... } end
function M:SetAlpha(v) self._alpha = v end
function M:SetDesaturated(v) self._desat = v end
function M:SetAtlas(a) self._atlas = a end
function M:SetTexCoord(...) self._coords = { ... } end
function M:SetStatusBarColor(...) self._sbc = { ... } end
function M:SetTimerDuration(d, interp, dir) self._timer, self._dir = d, dir end
function M:GetAlpha() return self._alpha or 1 end
function M:SetColorTexture(...) self._color = { ... } end
function M:IsMouseOver() return S.mouseOver end
function M:GetStatusBarTexture() self._sbt = self._sbt or new(); return self._sbt end
function M:AddMaskTexture(m) self._masks = self._masks or {}; self._masks[m] = true end
function M:RemoveMaskTexture(m) if self._masks then self._masks[m] = nil end end
function M:GetParent() return self._parent end
function M:GetName() return self._name end
function M:GetCenter() return 100, 100 end
function M:GetTop() return 150 end
function M:GetFrameLevel() return 1 end
function M:GetWidth() return self._w or 140 end
function M:GetHeight() return self._h or 100 end
function M:SetAttribute(k, v) self._attr = self._attr or {}; self._attr[k] = v end
function M:GetUnboundedStringWidth() return 50 end
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
print = function(msg) error("addon reported: " .. tostring(msg), 0) end
GetCursorPosition = function() return 10, 20 end
strtrim = function(str) return (str:gsub("^%s+", ""):gsub("%s+$", "")) end
StaticPopupDialogs = {}
StaticPopup_Show = function(which, _, _, data) StaticPopupDialogs[which].OnAccept(nil, data) end -- clicks Yes
UnitName = function() return S.name end
InCombatLockdown = function() return S.combat end
MainActionBar = { EndCaps = { LeftEndCap = { Texture = new() }, RightEndCap = { Texture = new() } } }
S.calls = {}
local function record(name) return function() S.calls[#S.calls + 1] = name end end
AcceptQuest, ConfirmAcceptQuest = record("accept"), record("confirm")
AcknowledgeAutoAcceptQuest, StaticPopup_Hide = record("ack"), record("hidepopup")
IsShiftKeyDown = function() return S.shift end
IsInGroup = function() return S.group end
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
    SelectActiveQuest = function(id) S.calls[#S.calls + 1] = "gossip" .. id end,
}
GetNumActiveQuests = function() return #(S.greeting or {}) end
GetActiveTitle = function(i) return "Quest " .. i, S.greeting[i] end
SelectActiveQuest = function(i) S.calls[#S.calls + 1] = "greeting" .. i end
hooksecurefunc = function(t, name, fn)
    local orig = t[name]
    t[name] = function(...) orig(...); fn(...) end
end
PlayerCastingBarFrame = new()
PlayerCastingBarFrame._parent = UIParent
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
    SetupColorPickerAndShow = function(_, info) info.swatchFunc(); info.cancelFunc() end,
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
}
UnitClass = function(unit) -- "Rogue", "ROGUE"
    local token = unit == "target" and S.targetClass or S.class
    return token:sub(1, 1) .. token:sub(2):lower(), token
end
UnitIsPlayer = function(unit) return unit == "player" or (unit == "target" and S.targetIsPlayer) end
local CLASS = { ROGUE = { r = 1, g = 0.96, b = 0.41 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
C_ClassColor = { GetClassColor = function(token) return CLASS[token] end }
UnitPowerType = function() return S.ptype, TOKENS[S.ptype] end
UnitPower = function() return S.secret and SECRET or 3 end
UnitPowerMax = function(_, t) return S.secret and SECRET or (S.max[t] or 100) end
UnitHealth = function(unit) return unit == "target" and S.targetHP or SECRET end
UnitExists = function(unit) return unit == "target" and S.targetHP ~= nil end
UnitHealthMax = function() return 1000 end

local ns = {}
assert(loadfile("ComboPointDisplay/ComboPointDisplay.lua"))("ComboPointDisplay", ns)
local function fire(e, ...) evFrame._scripts.OnEvent(evFrame, e, ...) end
-- each class logs in as its own character
local function login(class, ptype) S.class, S.name, S.ptype = class, class .. "Char", ptype; fire("PLAYER_LOGIN") end
local function prof() return ComboPointDisplayDB.profiles[ComboPointDisplayDB.chars[S.name .. " - Realm"]] end
local function byText(text) for _, f in ipairs(created) do if f._text == text then return f end end end
local fr = ns.frames

-- Rogue, secret values: 5 pips, each lit when points >= i; stack = 18 + 2 + 14 + 2 + 12 + 2 + 14 (cast bar)
login("ROGUE", 3)
fire("UNIT_POWER_FREQUENT"); fire("UNIT_HEALTH")
assert(fr.combo:IsShown() and fr.combo.n == 5, "rogue combo pips")
for i = 1, 5 do
    local s = fr.combo.segs[i]
    assert(s._min == i - 1 and s._max == i and s._value == SECRET, "pip " .. i)
end
assert(not fr.druidmana:IsShown(), "rogue has no druid mana")
assert(ComboPointDisplayFrame._h == 64, "stack height " .. tostring(ComboPointDisplayFrame._h))

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

-- Per-bar offsets move only that bar; the next bar keeps its slot (18 + 2 = 20, then 20 + 14 + 2 = 36)
S.secret = true
login("ROGUE", 3)
local R = prof().regular.bars
R.power.x, R.power.y = 5, -3
fire("UNIT_MAXPOWER")
local pp, cp = fr.power._point, fr.combo._point
assert(pp[1] == "TOP" and pp[2] == ComboPointDisplayFrame and pp[4] == 5 and pp[5] == -23, "power offset")
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
assert(ComboPointDisplayFrame._w == 220, "stack width ignores the target bar")
S.targetHP = nil; fire("PLAYER_TARGET_CHANGED")
assert(not tf:IsShown() and fr.health._w == 220 and fr.health._point[1] == "TOP", "target gone: full width again")
prof().regular.bars.health.target = false

-- Cast bar: keeps its slot, invisible idle; casts fill up, channels drain; name centered, icon side
local cb = fr.castbar
assert(cb:IsShown() and cb:GetAlpha() == 0 and cb._point[5] == -50, "idle: slot kept, invisible")
S.cast = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
local cs = cb.segs[1]
assert(cb:GetAlpha() == 1 and cs._timer == "castDuration" and cs._dir == 0, "cast fills up")
assert(cb.text._text == "Fireball" and cb.text:IsShown() and cb.icon._tex == 136116 and cb.icon:IsShown(), "name + icon")
assert(cs._w == 204 and cs._point[4] == 16 and cb.icon._point[1] == "LEFT", "icon left: bar starts after 14 + 2")
S.cast = nil; S.channel = "Drain Life"; fire("UNIT_SPELLCAST_CHANNEL_START", "player")
assert(cs._timer == "channelDuration" and cs._dir == 1 and cb.text._text == "Drain Life", "channel drains")
prof().regular.bars.castbar.iconSide = "right"; fire("UNIT_MAXPOWER")
assert(cs._w == 204 and cs._point[4] == 0 and cb.icon._point[1] == "RIGHT", "icon right")
prof().regular.bars.castbar.icon = false; fire("UNIT_MAXPOWER")
assert(cs._w == 220 and not cb.icon:IsShown(), "no icon: full width")
S.channel = nil; fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
assert(cb:GetAlpha() == 0, "done: invisible")
prof().locked = false; fire("UNIT_MAXPOWER")
assert(cb:GetAlpha() == 1 and cb.text._text == "Cast Bar" and cb.icon._tex == 134400, "unlocked: preview")
prof().locked = true; fire("UNIT_MAXPOWER")
assert(cb:GetAlpha() == 0, "locked again: hidden")
prof().regular.bars.castbar.icon, prof().regular.bars.castbar.iconSide = true, "left"

-- In-combat icon: in combat only (or previewing), centered on the chosen bar's left edge
local ci, icon = prof().regular.combatIcon, ns.combatIcon
fire("UNIT_MAXPOWER")
assert(not icon:IsShown(), "out of combat: hidden")
fire("PLAYER_REGEN_DISABLED")
local ip = icon._point
assert(icon:IsShown() and ip[1] == "CENTER" and ip[2] == fr.health and ip[3] == "LEFT" and ip[4] == -12, "health bar's left edge")
assert(icon.tex._atlas == "UI-HUD-UnitFrame-Player-CombatIcon" and icon._w == 20, "default art and size")
ci.bar, ci.style = "druidmana", "classic"; fire("UNIT_MAXPOWER")
assert(icon._point[2] == ComboPointDisplayFrame, "attached bar hidden: falls back to the group")
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
for r = 1, 50 do assert(io.open("ComboPointDisplay/Media/Round/r" .. r .. ".tga"), "mask file r" .. r) end
hb.borderSize, hb.radius = 0, 0; fire("UNIT_MAXPOWER")
assert(not seg.border:IsShown() and seg._w == 220 and not seg.bg._masks[seg.mask], "off: square, no border")
assert(not seg:GetStatusBarTexture()._masks[seg.mask], "fill unmasked")

-- Highlight: overlay on every bar of the group while hovered; no polling unless it's on
local hl, anchorF = prof().regular.highlight, ComboPointDisplayFrame
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
assert(not ComboPointDisplayClicker, "no secure button unless asked")
R0.playerMenu = true; fire("UNIT_MAXPOWER")
local ck = ComboPointDisplayClicker
assert(ck._template == "SecureUnitButtonTemplate" and ck._attr.unit == "player" and ck._attr.type2 == "togglemenu", "menu button")
assert(ck._point[1] == "TOP" and ck._point[2] == UIParent and ck._point[4] == R0.x and ck._point[5] == R0.y, "over the bars")
assert(ck._w == 220 and ck._h == 64 and ck:IsShown(), "same size as the bars")
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
assert(ComboPointDisplayFrame._h == 64 and plateStack._h == 6, "stacks sized independently")
R.combo.show = false
N.health.show = true
fire("PLAYER_TARGET_CHANGED")
assert(not fr.combo:IsShown() and pf.combo:IsShown() and pf.health:IsShown(), "nameplate only")
assert(ComboPointDisplayFrame._h == 50 and plateStack._h == 15, "plate stack: 8 + 1 + 6")
fire("UNIT_POWER_FREQUENT"); fire("UNIT_HEALTH")
assert(pf.combo.segs[3]._value == SECRET, "plate bars get values")
N.combo.show = false
fire("PLAYER_TARGET_CHANGED")
assert(not fr.combo:IsShown() and not pf.combo:IsShown(), "neither")
S.plate = nil; fire("NAME_PLATE_UNIT_REMOVED")
assert(not plateStack:IsShown() and not pf.health:IsShown() and plateStack._parent == ComboPointDisplayFrame, "plate gone")
R.combo.show, N.health.show = true, false

-- Quest mobs: sword for open kill objectives, bag for open item objectives, from the tooltip
local L = Enum.TooltipDataLineType
S.quests = { { info = { questID = 7, isHeader = false }, objectives = {
    { text = "Boar Flank: 2/6", type = "item" }, { text = "Boar slain: 3/10", type = "monster" } } } }
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
S.tips.nameplate1[2].completed = true
fire("QUEST_LOG_UPDATE")
assert(not h.kill:IsShown() and h.loot:IsShown(), "finished kill objective hidden")
assert(h.loot._point[4] == 0 and h.box._w == 42, "lone bag slides to the row's left edge, row keeps its size")
-- Groups: QuestPlayer lines say whose objective follows; groupmates-only shows gray
S.tips.nameplate1 = { { type = L.QuestTitle, leftText = "Boars", id = 7 },
    { type = L.QuestPlayer, leftText = "ROGUEChar" }, { type = L.QuestObjective, leftText = "3/10 Boar slain" },
    { type = L.QuestPlayer, leftText = "Bob" }, { type = L.QuestObjective, leftText = "Boar Flank: 2/6" },
    { type = L.QuestObjective, leftText = "3/10 Boar slain" } }
S.group = true; fire("QUEST_LOG_UPDATE")
assert(h.kill:IsShown() and not h.kill._desat and h.loot:IsShown() and h.loot._desat, "kill mine, loot only Bob's")
S.related.nameplate1 = false
S.tips.nameplate1 = { { type = L.QuestTitle, leftText = "Boars", id = 7 }, { type = L.QuestPlayer, leftText = "Bob" },
    { type = L.QuestObjective, leftText = "Boar Flank: 2/6", completed = false } }
fire("QUEST_LOG_UPDATE")
assert(not h.kill:IsShown() and h.loot:IsShown() and h.loot._desat and h.loot._point[4] == 0, "not my quest mob: gray bag")
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
local mini = ComboPointDisplayMinimapButton
mini._scripts.OnDragStart(mini); mini._scripts.OnUpdate(mini); mini._scripts.OnDragStop(mini)
assert(ComboPointDisplayDB.minimapAngle ~= 220 and not mini._scripts.OnUpdate, "minimap drag")

-- Options window: typed numbers apply on Enter and clamp to the slider range (gap: 0-30)
SlashCmdList.COMBOPOINTDISPLAY("")
local boxes = {} -- profile name, gap, group X/Y, width, height, bar X/Y, border, font size, quest row X/Y/spacing, kill size, loot size, ...
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
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")
assert(gapBox._text == "30", "back on Combat Display")

-- Profiles: create copies the current one, dropdown switches, delete falls back to the class profile
nameBox._text = "  PvP "; nameBox._scripts.OnEnterPressed(nameBox)
assert(store.profiles.PvP and store.profiles.PvP.regular.gap == 30 and prof() == store.profiles.PvP, "create copies + switches")
prof().regular.gap = 5
assert(store.profiles.Rogue.regular.gap == 30, "profiles are independent")
local dds = {} -- profile, texture, bar color, border color, radius, font, kill icon, loot icon, combat icon, attach
for _, f in ipairs(created) do if f._gen then dds[#dds + 1] = f end end
local dd = dds[1]
dd:GenerateMenu()
local names = {}
for _, it in ipairs(dd._items) do names[#names + 1] = it.text .. (it.sel() and "*" or "") end
assert(table.concat(names, ",") == "Druid,Paladin,PvP*,Rogue,Warrior", table.concat(names, ","))
dd._items[4].set()
assert(prof() == store.profiles.Rogue, "dropdown switches")
dd._items[3].set()
byText("Delete")._scripts.OnClick(byText("Delete"), "LeftButton")
assert(not store.profiles.PvP and prof() == store.profiles.Rogue, "delete falls back to class profile")

-- Texture and font dropdowns: pick sets the selected bar (Health), previews render
local texDD, fontDD = dds[2], dds[6]
texDD:GenerateMenu(); fontDD:GenerateMenu()
assert(#texDD._items == 5 and #fontDD._items == 6, "dropdown entries")
-- Menu entries' regions refuse SetFont in the real client (Blizzard_Menu Compositor)
local function menuButton()
    local b = new()
    b.fontString = new()
    function b:AttachFontString()
        local fs = new()
        function fs:SetFont() error("Use of function 'SetFont' is disallowed") end
        return fs
    end
    return b
end
for _, it in ipairs(texDD._items) do assert(type(it.init(menuButton())) == "number", "texture preview") end
for _, it in ipairs(fontDD._items) do assert(type(it.init(menuButton())) == "number", "font preview") end
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
boxes[14]._text = "32"; boxes[14]._scripts.OnEnterPressed(boxes[14]) -- kill size
boxes[11]._text = "-5"; boxes[11]._scripts.OnEnterPressed(boxes[11]) -- row X
local Q = prof().quest
assert(Q.kill.icon == 135274 and Q.kill.size == 32 and Q.loot.size == 20 and Q.x == -5, "quest page edits")
assert(h.kill._tex == 135274 and h.kill._w == 32 and h.box._w == 54 and h.box._point[4] == -5, "live plate row restyled")
byText("Combat Display")._scripts.OnClick(byText("Combat Display"), "LeftButton")

-- Other: gryphons hidden via texture alpha only, untouched until the option is used
local caps = MainActionBar.EndCaps
assert(caps.LeftEndCap.Texture._alpha == nil, "gryphons untouched by default")
byText("Other")._scripts.OnClick(byText("Other"), "LeftButton")
local pages, gcheck = {} -- bars, quest, other: frames directly on the options window
for _, f in ipairs(created) do if f._kind == "Frame" and f._parent == ComboPointDisplayConfig then pages[#pages + 1] = f end end
for _, f in ipairs(created) do if f._kind == "CheckButton" and f._parent == pages[3] then gcheck = gcheck or f end end
gcheck._checked = true; gcheck._scripts.OnClick(gcheck)
assert(prof().other.hideGryphons and caps.LeftEndCap.Texture._alpha == 0 and caps.RightEndCap.Texture._alpha == 0, "hidden")
gcheck._checked = false; gcheck._scripts.OnClick(gcheck)
assert(caps.LeftEndCap.Texture._alpha == 1, "shown again")
dds[9]:GenerateMenu(); dds[10]:GenerateMenu() -- combat icon art, attach-to bar
assert(#dds[9]._items == 4 and #dds[10]._items == 5, "combat icon choices, one entry per bar")
for _, it in ipairs(dds[9]._items) do assert(type(it.init(menuButton())) == "number", "combat icon preview") end
dds[10]._items[2].set()
assert(prof().regular.combatIcon.bar == prof().regular.order[2], "attached to the second bar")
local opBox = boxes[#boxes] -- the last slider made: highlight opacity (%)
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
fire("GOSSIP_SHOW"); fire("QUEST_GREETING"); fire("QUEST_PROGRESS"); fire("QUEST_COMPLETE")
assert(calls() == "gossip12,greeting2,complete,reward0", "turns in")
S.choices = 1; fire("QUEST_COMPLETE")
S.choices = 3; fire("QUEST_COMPLETE")
S.choices, S.cost = 0, 500; fire("QUEST_COMPLETE")
S.cost, S.completable = 0, false; fire("QUEST_PROGRESS")
assert(calls() == "reward1", "single reward taken; choice, gold cost and unfinished left alone")
S.shift = true; fire("GOSSIP_SHOW"); fire("QUEST_COMPLETE"); S.shift = false
assert(calls() == "", "shift skips")
prof().other.autoComplete = false

-- Every bundled font path points at a real file in the addon folder
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
        sc.OnDragStop(f)
    end
end
for _, m in ipairs({ "regular", "nameplate" }) do
    local seen = {}
    for _, k in ipairs(prof()[m].order) do seen[k] = true end
    assert(seen.health and seen.power and seen.combo and seen.druidmana and seen.castbar and #prof()[m].order == 5, "order intact")
end

SlashCmdList.COMBOPOINTDISPLAY("")
realPrint("smoke ok")
