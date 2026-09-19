-- ComboPointDisplay: stacked health / power / combo point / druid mana bars for WoW: Forever,
-- plus quest mob icons (sword = kill, bag = drops an item) on nameplates.
--
-- Forever runs the Retail (Midnight) API: UnitPower and friends return "secret" values that
-- addon code may not compare or do math on. So values only ever go into StatusBar:SetValue and
-- FontString:SetText; combo pips are StatusBars with range (i-1, i), which light up when
-- value >= i without Lua ever comparing the number.
local ADDON, ns = ...
local PT = Enum.PowerType
local isSecret = issecretvalue or function() return false end
local PIP_GAP = 2 -- ponytail: fixed spacing between combo pips; make it a setting if wanted

local TEXTURES = {
    { "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
    { "Flat", "Interface\\Buttons\\WHITE8X8" },
    { "Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { "Raid Resource", "Interface\\RaidFrame\\Raid-Bar-Resource-Fill" },
    { "Skills", "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}

-- Bundled fonts are free (SIL Open Font License, see Fonts/OFL-*.txt). Static TTFs: WoW only
-- renders the default instance of variable fonts.
local FONT_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Fonts\\"
local FONTS = {
    { "WoW default", STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" },
    { "Arvo (slab)", FONT_DIR .. "Arvo-Regular.ttf" },
    { "Fira Sans (sans serif)", FONT_DIR .. "FiraSans-Medium.ttf" },
    { "PT Serif (serif)", FONT_DIR .. "PT_Serif-Web-Regular.ttf" },
    { "Lato Thin (thin)", FONT_DIR .. "Lato-Thin.ttf" },
    { "Anton (bold)", FONT_DIR .. "Anton-Regular.ttf" },
}
ns.FONTS = FONTS

-- x/y = offset from the bar's slot in the stack.
local function barDefaults(show, width, height, r, g, b, text)
    return {
        show = show, x = 0, y = 0, width = width, height = height, texture = TEXTURES[1][2],
        color = { r, g, b, 1 }, gradient = false, color2 = { r * 0.4, g * 0.4, b * 0.4, 1 },
        vertical = false, text = text,
        font = FONTS[1][2], fontSize = 10, outline = false, textColor = { 1, 1, 1, 1 },
        borderSize = 0, borderColor = { 0, 0, 0, 1 }, radius = 0,
    }
end

-- One layout per place the bars can show. x/y = the group's top-center: from the screen center
-- (regular) or from the bottom of the target's nameplate (nameplate).
local function layoutDefaults(show, x, y, gap, width, h1, h2, h3, h4)
    local l = {
        x = x, y = y, gap = gap,
        order = { "health", "power", "combo", "druidmana" },
        bars = {
            health = barDefaults(show, width, h1, 0.2, 0.8, 0.2, show),
            power = barDefaults(show, width, h2, 1, 0.85, 0.1, show),
            combo = barDefaults(show, width, h3, 1, 0.3, 0.1, false),
            druidmana = barDefaults(show, width, h4, 0.2, 0.45, 1, false),
        },
    }
    l.bars.power.powerColor = true
    return l
end

-- Quest mob icons on nameplates; x/y from the nameplate's center. Icons are file IDs.
local DEFAULTS = {
    locked = true,
    regular = layoutDefaults(true, 0, -120, 2, 220, 18, 14, 12, 6),
    nameplate = layoutDefaults(false, 0, -2, 1, 110, 8, 6, 6, 4),
    quest = {
        kill = { show = true, icon = 131013, size = 20, x = -72, y = 0 },
        loot = { show = true, icon = 131023, size = 20, x = 72, y = 0 },
    },
    other = { hideGryphons = false, autoAccept = false, autoComplete = false },
}

DEFAULTS.regular.bars.health.target = false -- target health bar right of it (Combat Display only)
DEFAULTS.regular.hidePlayerFrame = false -- hide Blizzard's player unit frame
DEFAULTS.regular.playerMenu = false      -- right-click on the bars opens the player menu
DEFAULTS.regular.playerTarget = false    -- left-click on the bars targets yourself
DEFAULTS.regular.playerMouseover = false -- hovering the bars makes you @mouseover

local function merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

------------------------------------------------------------------------------------------
-- Data sources
------------------------------------------------------------------------------------------
-- store = ComboPointDisplayDB, account-wide: { profiles = { [name] = settings }, chars = { [char] = name } }
-- db = the active profile's settings.
local store, db, class, charKey, classProfile
local changed, placeMini, useProfile -- defined further down
local CLASS_POWER = {
    ROGUE = PT.ComboPoints, DRUID = PT.ComboPoints, PALADIN = PT.HolyPower, WARLOCK = PT.SoulShards,
    MONK = PT.Chi, MAGE = PT.ArcaneCharges, EVOKER = PT.Essence,
}

local function classPower()
    if class == "DRUID" and UnitPowerType("player") ~= PT.Energy then return nil end -- cat form only
    return CLASS_POWER[class]
end

-- state() -> shown, segment count. value(unit) -> current, max (both possibly secret).
local BARS = {
    health = {
        label = "Health",
        state = function() return true, 1 end,
        value = function(unit) return UnitHealth(unit), UnitHealthMax(unit) end,
    },
    power = {
        label = "Power",
        state = function() return true, 1 end,
        value = function()
            local t = UnitPowerType("player")
            return UnitPower("player", t), UnitPowerMax("player", t)
        end,
    },
    combo = {
        label = "Combo Points",
        state = function()
            local t = classPower()
            if not t then return false end
            local max = UnitPowerMax("player", t)
            -- ponytail: max is secret on the Forever beta, so assume 5 combo points and hide other
            -- class resources; drop this line once Blizzard un-secrets class resources.
            if isSecret(max) then max = t == PT.ComboPoints and 5 or 0 end
            return max > 0, max
        end,
        value = function() return UnitPower("player", classPower()) end,
    },
    druidmana = {
        label = "Druid Mana",
        -- in caster form the power bar already is mana
        state = function() return class == "DRUID" and UnitPowerType("player") ~= PT.Mana, 1 end,
        value = function() return UnitPower("player", PT.Mana), UnitPowerMax("player", PT.Mana) end,
    },
}

------------------------------------------------------------------------------------------
-- Bars
------------------------------------------------------------------------------------------
local frames = {}
ns.frames = frames

local anchor = CreateFrame("Frame", "ComboPointDisplayFrame", UIParent)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)

local function place()
    anchor:ClearAllPoints()
    anchor:SetPoint("TOP", UIParent, "CENTER", db.regular.x, db.regular.y)
end

-- Position = top-center of the stack, in pixels from the screen center.
local function coords()
    local ux, uy = UIParent:GetCenter()
    return math.floor(anchor:GetCenter() - ux + 0.5), math.floor(anchor:GetTop() - uy + 0.5)
end

-- Drag handle shown while unlocked; sits above the bars.
local HINT = "X %d  Y %d  -  drag to move, right-click for options"
local mover = CreateFrame("Frame", nil, anchor)
mover:SetAllPoints()
mover:SetFrameLevel(anchor:GetFrameLevel() + 20)
mover:Hide()
mover:EnableMouse(true)
mover:RegisterForDrag("LeftButton")
local moverTex = mover:CreateTexture(nil, "OVERLAY")
moverTex:SetAllPoints()
moverTex:SetColorTexture(0.2, 1, 0.2, 0.3)
local moverHint = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
moverHint:SetPoint("BOTTOM", mover, "TOP", 0, 2)
mover:SetScript("OnDragStart", function()
    anchor:StartMoving()
    mover:SetScript("OnUpdate", function() moverHint:SetFormattedText(HINT, coords()) end) -- live coordinates
end)
mover:SetScript("OnDragStop", function()
    anchor:StopMovingOrSizing()
    mover:SetScript("OnUpdate", nil)
    db.regular.x, db.regular.y = coords()
    place()
    changed()
end)
mover:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.ToggleConfig() end
end)

-- Every bar exists twice: in the regular stack and in a second stack under the target nameplate.
local plateAnchor = CreateFrame("Frame", nil, anchor)
local plateFrames = {}
ns.plateFrames = plateFrames

local function newBar(parent, key, mode)
    local f = CreateFrame("Frame", nil, parent)
    f.key, f.mode, f.segs = key, mode, {}
    return f
end

-- Target health: styled like the player's health bar; the two split its width while you have a target.
local targetFrame = newBar(anchor, "health", "regular")
targetFrame.unit = "target"
ns.targetFrame = targetFrame

for key in pairs(BARS) do
    frames[key] = newBar(anchor, key, "regular")
    plateFrames[key] = newBar(plateAnchor, key, "nameplate")
end

local function paint(s, c, r, g, b)
    s:SetStatusBarTexture(c.texture) -- before colors: a new texture resets them
    if c.gradient then
        s:SetStatusBarColor(1, 1, 1, 1)
        local c1, c2 = CreateColor(r, g, b, c.color[4]), CreateColor(unpack(c.color2))
        if c.vertical then
            s:GetStatusBarTexture():SetGradient("VERTICAL", c2, c1) -- min is the bottom edge
        else
            s:GetStatusBarTexture():SetGradient("HORIZONTAL", c1, c2)
        end
    else
        s:SetStatusBarColor(r, g, b, c.color[4])
    end
end

-- Rounded corners: WoW has no border-radius, so textures get a mask cut from a rounded
-- rectangle image. The image is nine-sliced so its corners keep their size at any bar size, and
-- the mask is scaled so a corner (MASK_MARGIN px in the file) comes out `radius` px on screen.
-- ponytail: assumes slice corners follow region scale; if in-game corners ignore the radius,
-- the fallback is one mask file per radius.
local MASK = "Interface\\AddOns\\" .. ADDON .. "\\Media\\RoundedMask.tga"
local MASK_MARGIN = 60

local function newMask(owner)
    local m = owner:CreateMaskTexture()
    m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetTextureSliceMargins(MASK_MARGIN, MASK_MARGIN, MASK_MARGIN, MASK_MARGIN) -- default mode: stretched
    return m
end

-- Corner radius r on a w x h area; 0 = square (mask removed). Capped at half the short side.
local function round(tex, m, r, w, h)
    r = math.min(r, w / 2, h / 2)
    if r > 0 then m:SetScale(r / MASK_MARGIN) end
    if (r > 0) ~= (tex.cpdMask == m) then
        if r > 0 then tex:AddMaskTexture(m) else tex:RemoveMaskTexture(m) end
        tex.cpdMask = r > 0 and m or nil
    end
end

local function layoutBar(f, n, width)
    local c = db[f.mode].bars[f.key]
    width = width or c.width
    f.width = width
    local r, g, b = unpack(c.color)
    if f.key == "power" and c.powerColor then
        local pc = PowerBarColor and PowerBarColor[select(2, UnitPowerType("player"))]
        if pc then r, g, b = pc.r, pc.g, pc.b end
    end
    f:SetSize(width, c.height)
    local w = (width - (n - 1) * PIP_GAP) / n
    for i = 1, math.max(n, #f.segs) do
        local s = f.segs[i]
        if i > n then
            s:Hide()
        else
            if not s then
                s = CreateFrame("StatusBar", nil, f)
                s.bg = s:CreateTexture(nil, "BACKGROUND")
                s.bg:SetAllPoints()
                s.bg:SetColorTexture(0, 0, 0, 0.5)
                s.border = s:CreateTexture(nil, "BACKGROUND", nil, -8) -- behind the background
                s.mask, s.borderMask = newMask(s), newMask(s)
                s.mask:SetAllPoints(s)
                s.borderMask:SetAllPoints(s.border)
                f.segs[i] = s
            end
            -- The border sits inside the bar's size (like CSS border-box); the bar is inset by it.
            local t = math.min(c.borderSize, (c.height - 1) / 2, (w - 1) / 2)
            local iw, ih = w - 2 * t, c.height - 2 * t
            s:SetSize(iw, ih)
            s:SetPoint("LEFT", f, "LEFT", (i - 1) * (w + PIP_GAP) + t, 0)
            s:SetMinMaxValues(i - 1, i) -- pip range; single bars get their real max in fill()
            paint(s, c, r, g, b)
            s.border:SetShown(t > 0)
            s.border:SetPoint("TOPLEFT", s, "TOPLEFT", -t, t)
            s.border:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", t, -t)
            s.border:SetColorTexture(unpack(c.borderColor))
            round(s.border, s.borderMask, c.radius, w, c.height)
            local inner = math.max(c.radius - t, 0) -- inner corners follow the outer ones
            round(s.bg, s.mask, inner, iw, ih)
            round(s:GetStatusBarTexture(), s.mask, inner, iw, ih)
            s:Show()
        end
    end
    if not f.text then
        f.text = f.segs[1]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.text:SetPoint("CENTER", f)
    end
    f.text:SetShown(c.text and n == 1)
    local flags = c.outline and "OUTLINE" or ""
    if not f.text:SetFont(c.font, c.fontSize, flags) then f.text:SetFont(FONTS[1][2], c.fontSize, flags) end
    f.text:SetTextColor(unpack(c.textColor))
    f.n = n
end

local function setText(fs, v) fs:SetText(AbbreviateNumbers(v)) end

local function fill(f)
    local v, max = BARS[f.key].value(f.unit or "player")
    if f.n == 1 then
        f.segs[1]:SetMinMaxValues(0, max)
        f.segs[1]:SetValue(v)
        if f.text:IsShown() and not pcall(setText, f.text, v) then f.text:SetText("") end
    else
        for i = 1, f.n do f.segs[i]:SetValue(v) end
    end
end

local function targetPlate()
    local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok and p and not (p.IsForbidden and p:IsForbidden()) then return p end
end

------------------------------------------------------------------------------------------
-- Quest mobs: a sword on nameplates of mobs you still need to kill, a bag on mobs that drop
-- an item you still need. Read from the unit tooltip's quest lines; the quest log says which
-- objective is an item.
------------------------------------------------------------------------------------------
local QUEST_ICONS = {
    kill = {
        { "Sword cursor", 131013 },     -- Interface/CURSOR/Attack
        { "Crosshair sword", 4675619 }, -- Interface/CURSOR/Crosshair/Attack
        { "Sword", 135274 },            -- Interface/ICONS/INV_Sword_04
        { "Crossed swords", 132147 },   -- Interface/ICONS/Ability_DualWield
    },
    loot = {
        { "Loot cursor", 131023 },      -- Interface/CURSOR/LootAll
        { "Crosshair loot", 4675637 },  -- Interface/CURSOR/Crosshair/LootAll
        { "Bag", 133633 },              -- Interface/ICONS/INV_Misc_Bag_08
        { "Coin bag", 901746 },         -- Interface/ICONS/INV_Misc_CoinBag_Special
    },
}

local LINE = Enum.TooltipDataLineType
local objectiveTypes = {} -- objective text without numbers -> "monster", "item", ...
local playerName

-- "Boar Flank: 2/6" and "2/6 Boar Flank" both become "BoarFlank".
local function bareText(text) return (text:gsub("[%d%p%s]", "")) end

local function scanQuestLog()
    wipe(objectiveTypes)
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                if o.text then objectiveTypes[bareText(o.text)] = o.type end
            end
        end
    end
end

-- kill, loot for a unit. Finished objectives and other party members' objectives don't count.
local function questKinds(unit)
    if not C_QuestLog.UnitIsRelatedToActiveQuest(unit) then return false, false end
    local data = C_TooltipInfo.GetUnit(unit)
    local kill, loot, anyObjective, mine = false, false, false, true
    for _, line in ipairs(data and data.lines or {}) do
        if line.type == LINE.QuestTitle then
            mine = true
        elseif line.type == LINE.QuestPlayer then
            mine = line.leftText == playerName
        elseif line.type == LINE.QuestObjective then
            anyObjective = true
            if mine and not line.completed then
                if objectiveTypes[bareText(line.leftText or "")] == "item" then loot = true else kill = true end
            end
        end
    end
    if not anyObjective then kill = true end -- quest-related, but the tooltip names no objective
    return kill, loot
end

-- Nameplates are recycled, so each plate keeps one icon holder; plateUnits maps the units
-- currently on screen to their holder.
local questHolders, plateUnits = {}, {}
ns.plateUnits = plateUnits

local function styleQuest(h)
    for kind in pairs(QUEST_ICONS) do
        local c, t = db.quest[kind], h[kind]
        t:SetTexture(c.icon)
        t:SetSize(c.size, c.size)
        t:ClearAllPoints()
        t:SetPoint("CENTER", h, "CENTER", c.x, c.y)
        t:SetShown((h.want[kind] and c.show) and true or false)
    end
end

local function evalQuest(unit)
    local h = plateUnits[unit]
    if not h then return end
    local ok, kill, loot = pcall(questKinds, unit)
    if ok then h.want.kill, h.want.loot = kill, loot end -- secret mid-combat: keep what we had
    styleQuest(h)
end

local function plateAdded(unit)
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or plate:IsForbidden() then return end
    local h = questHolders[plate]
    if not h then
        h = CreateFrame("Frame", nil, plate)
        h:SetAllPoints()
        h:SetFrameLevel(plate:GetFrameLevel() + 10)
        h.kill, h.loot, h.want = h:CreateTexture(nil, "OVERLAY"), h:CreateTexture(nil, "OVERLAY"), {}
        questHolders[plate] = h
    end
    h.want.kill, h.want.loot = false, false
    plateUnits[unit] = h
    evalQuest(unit)
end

local function plateRemoved(unit)
    local h = plateUnits[unit]
    if not h then return end
    h.want.kill, h.want.loot = false, false
    styleQuest(h)
    plateUnits[unit] = nil
end

local function questLogChanged()
    scanQuestLog()
    for unit in pairs(plateUnits) do evalQuest(unit) end
end

-- Lays out one stack: shown bars in order, touching with the gap. Each bar sits in its slot
-- plus its own x/y offset; offsets don't push the other bars around.
local function stack(container, set, L, on)
    local w, h = 0, 0
    for _, key in ipairs(L.order) do
        local f, c = set[key], L.bars[key]
        local shown, n = BARS[key].state()
        shown = (on and shown and c.show) and true or false
        f:SetShown(shown)
        if shown then
            -- f.split: the player health bar shares its width with the target health bar
            layoutBar(f, n, f.split and (c.width - L.gap) / 2 or nil)
            fill(f)
            if h > 0 then h = h + L.gap end
            f:ClearAllPoints()
            if f.split then
                f:SetPoint("TOPLEFT", container, "TOP", c.x - c.width / 2, c.y - h)
            else
                f:SetPoint("TOP", container, "TOP", c.x, c.y - h)
            end
            h = h + c.height
            w = math.max(w, c.width)
        end
    end
    container:SetSize(h > 0 and w or 20, h > 0 and h or 10) -- keeps an empty stack grabbable while unlocked
end

------------------------------------------------------------------------------------------
-- Blizzard player frame: hide it, and/or give the bars its right-click menu. Both touch
-- protected frames, which can only change out of combat; PLAYER_REGEN_ENABLED catches up.
------------------------------------------------------------------------------------------
local hider = CreateFrame("Frame")
hider:Hide()
local playerFrameHidden, playerFrameParent, clicker

local function syncProtected()
    if InCombatLockdown() then return end
    local hide = db.regular.hidePlayerFrame and true or false
    if PlayerFrame and hide ~= (playerFrameHidden or false) then -- never touch it unless asked
        if hide then playerFrameParent = PlayerFrame:GetParent() end
        PlayerFrame:SetParent(hide and hider or playerFrameParent)
        playerFrameHidden = hide
    end
    -- A secure unit button over the bars, clicking like Blizzard's player frame: left targets
    -- you, right opens the menu. Its "unit" attribute is also what makes the game treat you as
    -- @mouseover while the cursor is on it. ponytail: not a child of the bars (it would lock
    -- their layout in combat), so its size and spot follow them out of combat only.
    local R = db.regular
    local wanted = (R.playerMenu or R.playerTarget or R.playerMouseover) and true or false
    if wanted and not clicker then
        clicker = CreateFrame("Button", "ComboPointDisplayClicker", UIParent, "SecureUnitButtonTemplate")
        clicker:SetAttribute("unit", "player")
        clicker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    if clicker then
        clicker:SetAttribute("type1", R.playerTarget and "target" or nil)
        clicker:SetAttribute("type2", R.playerMenu and "togglemenu" or nil)
        clicker:ClearAllPoints()
        clicker:SetPoint("TOP", UIParent, "CENTER", R.x, R.y)
        clicker:SetSize(anchor:GetWidth(), anchor:GetHeight())
        clicker:SetShown(wanted and db.locked or false) -- unlocked: dragging wins
    end
end

-- Action bar gryphons (Forever: MainActionBar.EndCaps). Only their textures' alpha changes, so
-- Blizzard's Edit Mode code on those frames stays untouched. Left alone unless the option was on.
local gryphonsHidden
local function syncGryphons()
    local hide = db.other.hideGryphons and true or false
    local caps = MainActionBar and MainActionBar.EndCaps
    if not caps or hide == (gryphonsHidden or false) then return end
    for _, cap in ipairs({ caps.LeftEndCap, caps.RightEndCap }) do
        if cap and cap.Texture then cap.Texture:SetAlpha(hide and 0 or 1) end
    end
    gryphonsHidden = hide
end

local function Refresh()
    local health = frames.health
    health.split = (db.regular.bars.health.target and UnitExists("target")) and true or false
    stack(anchor, frames, db.regular, true)
    targetFrame:SetShown(health.split and health:IsShown())
    if targetFrame:IsShown() then
        layoutBar(targetFrame, 1, health.width) -- the other half
        fill(targetFrame)
        targetFrame:ClearAllPoints()
        targetFrame:SetPoint("LEFT", health, "RIGHT", db.regular.gap, 0)
    end
    local plate = targetPlate()
    plateAnchor:SetParent(plate or anchor)
    plateAnchor:SetShown(plate ~= nil)
    if plate then
        plateAnchor:ClearAllPoints()
        plateAnchor:SetPoint("TOP", plate, "BOTTOM", db.nameplate.x, db.nameplate.y)
    end
    stack(plateAnchor, plateFrames, db.nameplate, plate ~= nil)
    for _, h in pairs(questHolders) do styleQuest(h) end
    mover:SetShown(not db.locked)
    moverHint:SetFormattedText(HINT, db.regular.x, db.regular.y)
    syncProtected()
    syncGryphons()
end

-- One report per session, printed to chat: Lua errors are hidden by default and this client
-- stops delivering them after 100.
local function safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not ns.errored then
        ns.errored = true
        print("|cffff5555ComboPointDisplay error:|r " .. tostring(err))
    end
end

------------------------------------------------------------------------------------------
-- Options window (/cpd)
------------------------------------------------------------------------------------------
-- section = sidebar entry, sub = tab inside Nameplates, mode = which bar layout is being edited
local cfg, selected, mode, section, sub = nil, "health", "regular", "combat", "bars"
local refreshers = {}

changed = function()
    safe(Refresh)
    for _, fn in ipairs(refreshers) do fn() end
end

local function L() return db[mode] end
local function cur() return L().bars[selected] end
local function onRefresh(fn) refreshers[#refreshers + 1] = fn end

local function label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetText(text)
    return fs
end

local function button(parent, text, w, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onClick)
    return b
end

local function check(parent, text, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    label(cb, text):SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cb:SetScript("OnClick", function(self) set(self:GetChecked()); changed() end)
    onRefresh(function() cb:SetChecked(get()) end)
    return cb
end

local SLIDER_BACKDROP = {
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
}

local function num(v) return type(v) == "function" and v() or v end

-- min/max may be functions, for ranges that depend on the open tab.
local function slider(parent, text, x, y, min, max, get, set)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetSize(150, 16)
    s:SetPoint("TOPLEFT", x, y - 16)
    s:SetBackdrop(SLIDER_BACKDROP)
    s:SetOrientation("HORIZONTAL")
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:GetThumbTexture():SetSize(32, 32)
    s:SetMinMaxValues(num(min), num(max))
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true) -- wheel = +/-1 for exact values
    label(s, text, "GameFontNormalSmall"):SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
    local syncing
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        if not syncing and v ~= get() then set(v); changed() end
    end)
    s:SetScript("OnMouseWheel", function(_, d) s:SetValue(s:GetValue() + d) end)

    -- Typed value: Enter or clicking away applies it (clamped to the slider range), Escape cancels.
    local box = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
    box:SetSize(40, 20)
    box:SetPoint("LEFT", s, "RIGHT", 12, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(5) -- not SetNumeric: X/Y need a minus sign; tonumber() rejects the rest
    local function apply()
        local v = tonumber(box:GetText())
        if v then
            set(math.max(num(min), math.min(num(max), math.floor(v))))
            changed()
        end
        box:SetText(tostring(get()))
        box:ClearFocus()
    end
    box:SetScript("OnEnterPressed", apply)
    box:HookScript("OnEditFocusLost", apply)
    box:SetScript("OnEscapePressed", function()
        box:SetText(tostring(get()))
        box:ClearFocus()
    end)

    onRefresh(function()
        syncing = true
        s:SetMinMaxValues(num(min), num(max))
        s:SetValue(get())
        syncing = false
        if not box:HasFocus() then box:SetText(tostring(get())) end
    end)
    return s
end

local function swatch(parent, text, x, y, get)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b:SetPoint("TOPLEFT", x + 2, y)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(1, 1, 1)
    local fillTex = b:CreateTexture(nil, "ARTWORK")
    fillTex:SetPoint("TOPLEFT", 2, -2)
    fillTex:SetPoint("BOTTOMRIGHT", -2, 2)
    label(b, text):SetPoint("LEFT", b, "RIGHT", 6, 0)
    b:SetScript("OnClick", function()
        local c = get()
        local old = { c[1], c[2], c[3], c[4] }
        local function apply(r, g, bl, a) c[1], c[2], c[3], c[4] = r, g, bl, a; changed() end
        local function picked()
            local r, g, bl = ColorPickerFrame:GetColorRGB()
            apply(r, g, bl, ColorPickerFrame:GetColorAlpha())
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c[1], g = c[2], b = c[3], opacity = c[4], hasOpacity = true,
            swatchFunc = picked, opacityFunc = picked,
            cancelFunc = function() apply(unpack(old)) end,
        })
    end)
    onRefresh(function() fillTex:SetColorTexture(unpack(get())) end)
    return b
end

-- Dropdown over a { {name, value}, ... } list; preview(button, value) decorates each entry and
-- returns its width.
local function dropdown(parent, text, x, y, list, get, set, preview)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", x, y - 14)
    dd:SetWidth(200)
    label(dd, text, "GameFontNormalSmall"):SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 2)
    dd:SetupMenu(function(_, root)
        for _, item in ipairs(list) do
            local radio = root:CreateRadio(item[1], function() return get() == item[2] end,
                function() set(item[2]); changed() end)
            radio:AddInitializer(function(button) return preview(button, item), 20 end)
        end
    end)
    onRefresh(function() dd:GenerateMenu() end)
    return dd
end

local function texturePreview(button, item)
    local t = button:AttachTexture()
    t:SetSize(90, 12)
    t:SetPoint("RIGHT", -6, 0)
    t:SetTexture(item[2])
    t:SetVertexColor(unpack(cur().color))
    return button.fontString:GetUnboundedStringWidth() + 130
end

-- Menu font strings refuse SetFont, so each font gets a Font object for SetFontObject.
-- Copying the default first keeps a usable font if a file fails to load.
for i, f in ipairs(FONTS) do
    f.object = CreateFont("ComboPointDisplayFont" .. i)
    f.object:CopyFontObject(GameFontHighlight)
    f.object:SetFont(f[2], 14, "")
end

local function fontPreview(button, item)
    local fs = button:AttachFontString()
    fs:SetPoint("RIGHT", -6, 0)
    fs:SetFontObject(item.object)
    fs:SetText("12345")
    return button.fontString:GetUnboundedStringWidth() + fs:GetUnboundedStringWidth() + 50
end

local function iconPreview(button, item)
    local t = button:AttachTexture()
    t:SetSize(20, 20)
    t:SetPoint("RIGHT", -6, 0)
    t:SetTexture(item[2])
    return button.fontString:GetUnboundedStringWidth() + 60
end

local function move(i, d)
    local o, j = L().order, i + d
    if o[j] then
        o[i], o[j] = o[j], o[i]
        changed()
    end
end

------------------------------------------------------------------------------------------
-- Profiles (account-wide). Each character starts on its class profile, e.g. "Rogue".
------------------------------------------------------------------------------------------
useProfile = function(name)
    store.profiles[name] = merge(store.profiles[name] or {}, DEFAULTS)
    store.chars[charKey] = name
    db = store.profiles[name]
    place()
    changed()
end

local function profileNames()
    local names = {}
    for name in pairs(store.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

-- New profiles start as a copy of the current one; an existing name just switches to it.
local function createProfile(name)
    name = strtrim(name or "")
    if name == "" then return end
    if not store.profiles[name] then store.profiles[name] = merge({}, db) end
    useProfile(name)
end

-- Characters on the deleted profile fall back to their class profile (recreated if needed).
local function deleteProfile(name)
    store.profiles[name] = nil
    for char, p in pairs(store.chars) do
        if p == name then store.chars[char] = nil end
    end
    useProfile(classProfile)
end

StaticPopupDialogs.COMBOPOINTDISPLAY_DELETE = {
    text = "Delete ComboPointDisplay profile \"%s\"?",
    button1 = YES, button2 = NO,
    OnAccept = function(_, name) deleteProfile(name) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local function buildConfig()
    cfg = CreateFrame("Frame", "ComboPointDisplayConfig", UIParent, "BasicFrameTemplateWithInset")
    cfg:SetSize(820, 600)
    cfg:SetPoint("CENTER")
    cfg:SetFrameStrata("DIALOG")
    cfg:SetMovable(true)
    cfg:EnableMouse(true)
    cfg:RegisterForDrag("LeftButton")
    cfg:SetScript("OnDragStart", cfg.StartMoving)
    cfg:SetScript("OnDragStop", cfg.StopMovingOrSizing)
    tinsert(UISpecialFrames, cfg:GetName()) -- Escape closes it
    label(cfg, "ComboPointDisplay"):SetPoint("TOP", 0, -5)

    -- Top row: profile (account-wide, holds both tabs)
    label(cfg, "Profile", "GameFontNormal"):SetPoint("TOPLEFT", 16, -38)
    local dd = CreateFrame("DropdownButton", nil, cfg, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", 66, -32)
    dd:SetWidth(170)
    dd:SetupMenu(function(_, root)
        for _, name in ipairs(profileNames()) do
            root:CreateRadio(name, function() return name == store.chars[charKey] end, function() useProfile(name) end)
        end
    end)
    onRefresh(function() dd:GenerateMenu() end)
    label(cfg, "New (copy):", "GameFontNormalSmall"):SetPoint("TOPLEFT", 252, -39)
    local nameBox = CreateFrame("EditBox", nil, cfg, "InputBoxTemplate")
    nameBox:SetSize(100, 20)
    nameBox:SetPoint("TOPLEFT", 326, -34)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(32)
    local function create()
        createProfile(nameBox:GetText())
        nameBox:SetText("")
        nameBox:ClearFocus()
    end
    nameBox:SetScript("OnEnterPressed", create)
    nameBox:SetScript("OnEscapePressed", function() nameBox:ClearFocus() end)
    button(cfg, "Create", 56, 432, -33, create)
    button(cfg, "Delete", 64, 500, -33, function()
        local name = store.chars[charKey]
        StaticPopup_Show("COMBOPOINTDISPLAY_DELETE", name, nil, name)
    end)
    button(cfg, "Reset profile", 92, 570, -33, function()
        wipe(db)
        merge(db, DEFAULTS)
        place()
        changed()
    end)

    -- Sidebar: one entry per module
    local SIDEBAR = { { "combat", "Combat Display", "regular" }, { "nameplates", "Nameplates", "nameplate" },
        { "other", "Other", "regular" } }
    for i, e in ipairs(SIDEBAR) do
        local b = button(cfg, e[2], 118, 12, -104 - (i - 1) * 26, function()
            section, mode = e[1], e[3]
            changed()
        end)
        onRefresh(function() if section == e[1] then b:LockHighlight() else b:UnlockHighlight() end end)
    end
    local divider = cfg:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.15)
    divider:SetPoint("TOPLEFT", 138, -64)
    divider:SetPoint("BOTTOMLEFT", 138, 10)
    divider:SetWidth(1)

    -- Pages to the right of the sidebar. The bars page edits the layout picked by `mode`.
    local barsPage = CreateFrame("Frame", nil, cfg)
    barsPage:SetPoint("TOPLEFT", 134, 0)
    barsPage:SetSize(686, 600)
    local questPage = CreateFrame("Frame", nil, cfg)
    questPage:SetAllPoints(barsPage)
    local otherPage = CreateFrame("Frame", nil, cfg)
    otherPage:SetAllPoints(barsPage)

    local title = label(cfg, "Combat Display", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 150, -72)
    local tabs = {}
    for i, t in ipairs({ { "bars", "Bars" }, { "quest", "Quest mobs" } }) do
        tabs[i] = button(cfg, t[2], 110, 150 + (i - 1) * 116, -68, function() sub = t[1]; changed() end)
        onRefresh(function() if sub == t[1] then tabs[i]:LockHighlight() else tabs[i]:UnlockHighlight() end end)
    end
    onRefresh(function()
        local np = section == "nameplates"
        title:SetShown(not np)
        title:SetText(section == "other" and "Other" or "Combat Display")
        for _, t in ipairs(tabs) do t:SetShown(np) end
        barsPage:SetShown(section == "combat" or (np and sub == "bars"))
        questPage:SetShown(np and sub == "quest")
        otherPage:SetShown(section == "other")
    end)

    check(otherPage, "Hide action bar gryphons", 16, -104,
        function() return db.other.hideGryphons end, function(v) db.other.hideGryphons = v end)
    check(otherPage, "Auto-accept quests (hold Shift to read one first)", 16, -128,
        function() return db.other.autoAccept end, function(v) db.other.autoAccept = v end)
    check(otherPage, "Auto-complete quests (hold Shift to skip)", 16, -152,
        function() return db.other.autoComplete end, function(v) db.other.autoComplete = v end)
    label(otherPage, "Auto-complete leaves quests with a reward choice or a gold cost to you.",
        "GameFontDisableSmall"):SetPoint("TOPLEFT", 42, -178)

    local tabNote = label(barsPage, "", "GameFontDisableSmall")
    tabNote:SetPoint("TOPLEFT", 252, -74)
    onRefresh(function()
        tabNote:SetText(mode == "regular" and "Health, power and combo bars on your screen."
            or "Bars under your target's nameplate. Needs enemy nameplates on (V key).")
    end)

    -- Column 1: order, gap, group position, lock
    label(barsPage, "Bars, top to bottom", "GameFontNormal"):SetPoint("TOPLEFT", 16, -104)
    for i = 1, #db.regular.order do
        local y = -124 - (i - 1) * 26
        local sel = button(barsPage, "", 110, 16, y, function() selected = L().order[i]; changed() end)
        button(barsPage, "Up", 36, 128, y, function() move(i, -1) end)
        button(barsPage, "Down", 46, 166, y, function() move(i, 1) end)
        onRefresh(function()
            local key = L().order[i]
            sel:SetText(BARS[key].label)
            if key == selected then sel:LockHighlight() else sel:UnlockHighlight() end
        end)
    end
    slider(barsPage, "Gap between bars", 16, -236, 0, 30, function() return L().gap end, function(v) L().gap = v end)
    label(barsPage, "Group position", "GameFontNormal"):SetPoint("TOPLEFT", 16, -282)
    local groupNote = label(barsPage, "", "GameFontDisableSmall")
    groupNote:SetPoint("TOPLEFT", 16, -298)
    onRefresh(function()
        groupNote:SetText(mode == "regular" and "top-center, from the screen center" or "top-center, from under the nameplate")
    end)
    local function xr() return mode == "regular" and math.floor(UIParent:GetWidth() / 2) or 200 end
    local function yr() return mode == "regular" and math.floor(UIParent:GetHeight() / 2) or 200 end
    slider(barsPage, "X (left / right)", 16, -316, function() return -xr() end, xr,
        function() return L().x end, function(v) L().x = v; place() end)
    slider(barsPage, "Y (down / up)", 16, -358, function() return -yr() end, yr,
        function() return L().y end, function(v) L().y = v; place() end)
    local lock = button(barsPage, "", 96, 16, -404, function() db.locked = not db.locked; changed() end)
    onRefresh(function()
        lock:SetShown(mode == "regular")
        lock:SetText(db.locked and "Unlock" or "Lock")
    end)
    local playerFrameOpts = {
        check(barsPage, "Hide Blizzard player frame", 16, -436,
            function() return db.regular.hidePlayerFrame end, function(v) db.regular.hidePlayerFrame = v end),
        check(barsPage, "Right-click: player menu", 16, -460,
            function() return db.regular.playerMenu end, function(v) db.regular.playerMenu = v end),
        check(barsPage, "Left-click: target yourself", 16, -484,
            function() return db.regular.playerTarget end, function(v) db.regular.playerTarget = v end),
        check(barsPage, "Mouseover macros (@mouseover)", 16, -508,
            function() return db.regular.playerMouseover end, function(v) db.regular.playerMouseover = v end),
    }
    onRefresh(function() for _, w in ipairs(playerFrameOpts) do w:SetShown(mode == "regular") end end)
    label(barsPage, "Mouse wheel on a slider changes it by 1.\nPlayer frame options apply out of combat.\n"
        .. "Click and mouseover options block clicks through the bars.", "GameFontDisableSmall"):SetPoint("TOPLEFT", 16, -540)

    -- Column 2: the selected bar's show, size, offset, look
    local X = 240
    local header = label(barsPage, "", "GameFontNormal")
    header:SetPoint("TOPLEFT", X, -104)
    onRefresh(function()
        local shown = (mode == "regular" and frames or plateFrames)[selected]:IsShown()
        header:SetText(BARS[selected].label .. (shown and "" or " |cff888888(hidden now)|r"))
    end)
    check(barsPage, "Show", X, -122, function() return cur().show end, function(v) cur().show = v end)
    slider(barsPage, "Width", X, -150, 10, 600, function() return cur().width end, function(v) cur().width = v end)
    slider(barsPage, "Height", X, -192, 2, 100, function() return cur().height end, function(v) cur().height = v end)
    slider(barsPage, "Bar offset X", X, -234, -300, 300, function() return cur().x end, function(v) cur().x = v end)
    slider(barsPage, "Bar offset Y", X, -276, -300, 300, function() return cur().y end, function(v) cur().y = v end)
    dropdown(barsPage, "Texture", X, -318, TEXTURES, function() return cur().texture end,
        function(v) cur().texture = v end, texturePreview)
    swatch(barsPage, "Bar color", X, -366, function() return cur().color end)
    local powerColor = check(barsPage, "Use power type color", X, -390,
        function() return cur().powerColor end, function(v) cur().powerColor = v end)
    local target = check(barsPage, "Show target health next to it", X, -390,
        function() return cur().target end, function(v) cur().target = v end)
    onRefresh(function()
        powerColor:SetShown(selected == "power")
        target:SetShown(selected == "health" and mode == "regular")
    end)

    -- Column 3: border, gradient and text (combo pips have no text)
    local X3 = 464
    slider(barsPage, "Border", X3, -104, 0, 10, function() return cur().borderSize end, function(v) cur().borderSize = v end)
    swatch(barsPage, "Border color", X3, -148, function() return cur().borderColor end)
    slider(barsPage, "Corner radius", X3, -174, 0, 30, function() return cur().radius end, function(v) cur().radius = v end)
    check(barsPage, "Gradient", X3, -220, function() return cur().gradient end, function(v) cur().gradient = v end)
    local c2 = swatch(barsPage, "Gradient end color", X3, -246, function() return cur().color2 end)
    local dir = button(barsPage, "", 200, X3, -272, function() cur().vertical = not cur().vertical; changed() end)
    onRefresh(function()
        c2:SetShown(cur().gradient)
        dir:SetShown(cur().gradient)
        dir:SetText("Direction: " .. (cur().vertical and "Vertical" or "Horizontal"))
    end)
    local textWidgets = {
        check(barsPage, "Show text", X3, -306, function() return cur().text end, function(v) cur().text = v end),
        dropdown(barsPage, "Font", X3, -332, FONTS, function() return cur().font end,
            function(v) cur().font = v end, fontPreview),
        slider(barsPage, "Font size", X3, -380, 6, 32, function() return cur().fontSize end, function(v) cur().fontSize = v end),
        check(barsPage, "Outline", X3, -426, function() return cur().outline end, function(v) cur().outline = v end),
        swatch(barsPage, "Text color", X3, -452, function() return cur().textColor end),
    }
    onRefresh(function()
        for _, w in ipairs(textWidgets) do w:SetShown(selected ~= "combo") end
    end)

    -- Quest mobs page
    label(questPage, "Quest mobs", "GameFontNormal"):SetPoint("TOPLEFT", 16, -104)
    local desc = label(questPage, "Marks enemies you still need for a quest.\n\nSword: you need to kill it.\n"
        .. "Bag: it drops an item you need.\n\nFinished objectives show nothing. X/Y are from the "
        .. "nameplate's center. Needs enemy nameplates on (V key).", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 16, -126)
    desc:SetWidth(200)
    desc:SetJustifyH("LEFT")
    for i, kind in ipairs({ { "kill", "Kill it (sword)" }, { "loot", "Drops a quest item (bag)" } }) do
        local X = 16 + i * 224
        local function q() return db.quest[kind[1]] end
        label(questPage, kind[2], "GameFontNormal"):SetPoint("TOPLEFT", X, -104)
        check(questPage, "Show", X, -122, function() return q().show end, function(v) q().show = v end)
        dropdown(questPage, "Icon", X, -150, QUEST_ICONS[kind[1]], function() return q().icon end,
            function(v) q().icon = v end, iconPreview)
        slider(questPage, "Size", X, -198, 8, 64, function() return q().size end, function(v) q().size = v end)
        slider(questPage, "X (left / right)", X, -240, -200, 200, function() return q().x end, function(v) q().x = v end)
        slider(questPage, "Y (down / up)", X, -282, -200, 200, function() return q().y end, function(v) q().y = v end)
    end
end

function ns.ToggleConfig()
    if not db then return end
    if not cfg then buildConfig() end
    cfg:SetShown(not cfg:IsShown())
    if cfg:IsShown() then changed() end
end
ComboPointDisplay_Toggle = ns.ToggleConfig -- addon compartment (retail only, Forever has none)

SLASH_COMBOPOINTDISPLAY1 = "/cpd"
SLASH_COMBOPOINTDISPLAY2 = "/cpb"
SlashCmdList.COMBOPOINTDISPLAY = function() safe(ns.ToggleConfig) end

-- Minimap icon: left-click options, right-click lock/unlock, drag to move around the minimap.
-- ponytail: assumes a round minimap; square minimap addons would need corner math.
local mini = CreateFrame("Button", "ComboPointDisplayMinimapButton", Minimap)
mini:SetSize(31, 31)
mini:SetFrameStrata("MEDIUM")
mini:SetFrameLevel(8)
mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local miniIcon = mini:CreateTexture(nil, "BACKGROUND")
miniIcon:SetSize(20, 20)
miniIcon:SetPoint("TOPLEFT", 7, -5)
miniIcon:SetTexture("Interface\\Icons\\Ability_Rogue_Eviscerate")
local miniBorder = mini:CreateTexture(nil, "OVERLAY")
miniBorder:SetSize(53, 53)
miniBorder:SetPoint("TOPLEFT")
miniBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

placeMini = function()
    local a, r = math.rad(store.minimapAngle), Minimap:GetWidth() / 2 + 10
    mini:ClearAllPoints()
    mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mini:RegisterForDrag("LeftButton")
mini:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
        db.locked = not db.locked
        changed()
    else
        safe(ns.ToggleConfig)
    end
end)
mini:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        store.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
        placeMini()
    end)
end)
mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mini:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ComboPointDisplay")
    GameTooltip:AddLine("Left-click: options", 1, 1, 1)
    GameTooltip:AddLine("Right-click: lock / unlock bars", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this icon", 1, 1, 1)
    GameTooltip:Show()
end)
mini:SetScript("OnLeave", function() GameTooltip:Hide() end)

------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------
local ev = CreateFrame("Frame")

-- Registering an event this client lacks throws, so each one is guarded.
local function listen(event, ...)
    if ... then pcall(ev.RegisterUnitEvent, ev, event, ...) else pcall(ev.RegisterEvent, ev, event) end
end

-- Auto-accept: quest windows and party members' escort quests. Quests started from items or
-- area triggers are left to Blizzard, which already turns those into popups.
local function autoAccept(event, startItem)
    if not db.other.autoAccept or IsShiftKeyDown() then return end
    if event == "QUEST_ACCEPT_CONFIRM" then
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")
    elseif (startItem or 0) == 0 and not QuestIsFromAreaTrigger() then
        if QuestGetAutoAccept() then AcknowledgeAutoAcceptQuest() else AcceptQuest() end
    end
end

-- Auto-complete: pick finished quests at the NPC (gossip or greeting window), hand in the items,
-- take the reward. Several rewards to choose from, or a gold cost, stay with you.
local function autoComplete(event)
    if not db.other.autoComplete or IsShiftKeyDown() then return end
    if event == "QUEST_PROGRESS" then
        if IsQuestCompletable() then CompleteQuest() end
    elseif event == "QUEST_COMPLETE" then
        local choices = GetNumQuestChoices()
        if choices <= 1 and (GetQuestMoneyToGet() or 0) == 0 then GetQuestReward(choices) end
    elseif event == "GOSSIP_SHOW" then
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if q.isComplete then return C_GossipInfo.SelectActiveQuest(q.questID) end
        end
    elseif event == "QUEST_GREETING" then
        for i = 1, GetNumActiveQuests() do
            if select(2, GetActiveTitle(i)) then return SelectActiveQuest(i) end
        end
    end
end

local function fillShown(...)
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if frames[key]:IsShown() then safe(fill, frames[key]) end
        if plateFrames[key]:IsShown() then safe(fill, plateFrames[key]) end
    end
end

ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        -- ponytail: settings saved before profiles existed are dropped (the beta never loaded them anyway)
        store = type(ComboPointDisplayDB) == "table" and ComboPointDisplayDB.profiles and ComboPointDisplayDB
            or { profiles = {}, chars = {} }
        ComboPointDisplayDB = store
        store.minimapAngle = store.minimapAngle or 220
        classProfile, class = UnitClass("player")
        playerName = UnitName("player")
        charKey = playerName .. " - " .. GetRealmName()
        listen("UNIT_HEALTH", "player", "target")
        listen("UNIT_MAXHEALTH", "player", "target")
        for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_QUEST_LOG_CHANGED" }) do
            listen(e, "player")
        end
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
            "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED",
            "QUEST_DETAIL", "QUEST_ACCEPT_CONFIRM", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_GREETING" }) do
            listen(e)
        end
        local mine = store.chars[charKey]
        useProfile(store.profiles[mine or ""] and mine or classProfile)
        placeMini()
    elseif event == "UNIT_HEALTH" then
        fillShown("health")
        if targetFrame:IsShown() then safe(fill, targetFrame) end
    elseif event == "UNIT_POWER_FREQUENT" then
        fillShown("power", "combo", "druidmana")
    elseif event == "QUEST_DETAIL" or event == "QUEST_ACCEPT_CONFIRM" then
        safe(autoAccept, event, unit) -- for QUEST_DETAIL the first arg is the quest-starting item
    elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" or event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        safe(autoComplete, event)
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        safe(questLogChanged)
    elseif event == "PLAYER_REGEN_ENABLED" then
        safe(questLogChanged) -- tooltips may have been secret during combat
        safe(Refresh)         -- and protected frames couldn't change
    else
        if event == "NAME_PLATE_UNIT_ADDED" then safe(plateAdded, unit) end
        if event == "NAME_PLATE_UNIT_REMOVED" then safe(plateRemoved, unit) end
        -- form, max, target or nameplate changes: re-layout (target change moves the nameplate bars)
        safe(Refresh)
    end
end)
listen("PLAYER_LOGIN")
