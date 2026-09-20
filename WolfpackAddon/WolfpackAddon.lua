-- Wolfpack Addon: stacked health / power / combo point / druid mana bars for WoW: Forever,
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

-- Combat text (damage numbers) fonts, all free (SIL OFL or Apache 2.0, license files next to
-- them). The game reads DAMAGE_TEXT_FONT once at startup, so a pick needs a full restart.
local CF = FONT_DIR .. "Combat\\"
local DEFAULT_DAMAGE_FONT = DAMAGE_TEXT_FONT
local COMBAT_FONTS = {
    { "WoW default", "" },
    { "Anton", FONT_DIR .. "Anton-Regular.ttf" },
    { "Fira Sans", FONT_DIR .. "FiraSans-Medium.ttf" },
    { "Bebas Neue", CF .. "BebasNeue-Regular.ttf" },
    { "Bangers", CF .. "Bangers-Regular.ttf" },
    { "Luckiest Guy", CF .. "LuckiestGuy-Regular.ttf" },
    { "Permanent Marker", CF .. "PermanentMarker-Regular.ttf" },
    { "Russo One", CF .. "RussoOne-Regular.ttf" },
    { "Black Ops One", CF .. "BlackOpsOne-Regular.ttf" },
    { "Press Start 2P", CF .. "PressStart2P-Regular.ttf" },
    { "Bungee", CF .. "Bungee-Regular.ttf" },
    { "Righteous", CF .. "Righteous-Regular.ttf" },
    { "Titan One", CF .. "TitanOne-Regular.ttf" },
    { "Lilita One", CF .. "LilitaOne-Regular.ttf" },
    { "Alfa Slab One", CF .. "AlfaSlabOne-Regular.ttf" },
    { "Archivo Black", CF .. "ArchivoBlack-Regular.ttf" },
    { "Passion One", CF .. "PassionOne-Bold.ttf" },
    { "Cinzel Decorative", CF .. "CinzelDecorative-Bold.ttf" },
    { "MedievalSharp", CF .. "MedievalSharp.ttf" },
    { "Pirata One", CF .. "PirataOne-Regular.ttf" },
    { "Creepster", CF .. "Creepster-Regular.ttf" },
}
ns.COMBAT_FONTS = COMBAT_FONTS

-- Called on ADDON_LOADED, before the world loads. Only known paths are accepted.
local function applyCombatFont()
    local pick = type(WolfpackAddonDB) == "table" and WolfpackAddonDB.combatFont
    for _, f in ipairs(COMBAT_FONTS) do
        if pick and pick ~= "" and f[2] == pick then DAMAGE_TEXT_FONT = pick end
    end
end

-- x/y = offset from the bar's slot in the stack.
local function barDefaults(show, width, height, r, g, b, text)
    return {
        show = show, x = 0, y = 0, width = width, height = height, texture = TEXTURES[1][2],
        color = { r, g, b, 1 }, bgColor = { 0, 0, 0, 0.5 },
        gradient = false, direction = "right", -- "right", "left", "down", "up"
        stops = { -- gradient points: percent across the bar, and a color
            { pos = 0, color = { r, g, b, 1 } },
            { pos = 100, color = { r * 0.4, g * 0.4, b * 0.4, 1 } },
        },
        text = text, padTop = 0, padBottom = 0, -- extra space above / below this bar
        font = FONTS[1][2], fontSize = 10, outline = false, textColor = { 1, 1, 1, 1 },
        colorMode = "custom", -- "custom", "class" or "power" (power bar only)
        borderSize = 0, borderColor = { 0, 0, 0, 1 }, borderMode = "custom", radius = 0, -- border: or "class", "bar"
    }
end

-- One layout per place the bars can show. x/y = the group's top-center: from the screen center
-- (regular) or from the bottom of the target's nameplate (nameplate).
-- One bar per weapon; the Swing Timer bar shows the ones ticked here.
local SWING_TYPES = { { "main", "Main hand", 0 }, { "off", "Off hand", 1 }, { "ranged", "Ranged", 2 } }

local function layoutDefaults(show, x, y, gap, width, h1, h2, h3, h4, h5, h6, h7)
    local l = {
        x = x, y = y, gap = gap, grow = "down", -- "up": the group's bottom edge stays put instead
        order = { "health", "power", "combo", "druidmana", "castbar", "pethealth", "swing" }, -- new bars go last
        bars = {
            health = barDefaults(show, width, h1, 0.2, 0.8, 0.2, show),
            power = barDefaults(show, width, h2, 1, 0.85, 0.1, show),
            combo = barDefaults(show, width, h3, 1, 0.3, 0.1, false),
            druidmana = barDefaults(show, width, h4, 0.2, 0.45, 1, false),
            castbar = barDefaults(show, width, h5, 1, 0.7, 0, true), -- text = spell name
            pethealth = barDefaults(show, width, h6, 0.3, 0.7, 0.3, show),
            swing = barDefaults(show, width, h7, 0.8, 0.8, 0.85, show), -- text = seconds left
        },
    }
    l.bars.power.colorMode = "power"
    l.bars.castbar.icon, l.bars.castbar.iconSide = true, "left"
    l.bars.swing.main, l.bars.swing.off, l.bars.swing.ranged = true, false, false
    return l
end

-- Quest mob icons on nameplates: a row (kill, then loot) whose top-right sits at the nameplate's
-- top-right corner plus x/y. Icons are file IDs.
local DEFAULTS = {
    locked = true,
    regular = layoutDefaults(true, 0, -120, 2, 220, 18, 14, 12, 6, 14, 10, 10),
    nameplate = layoutDefaults(false, 0, -2, 1, 110, 8, 6, 6, 4, 8, 5, 5),
    quest = {
        x = 0, y = 0, spacing = 2,
        kill = { show = true, icon = 131013, size = 20, count = false },
        loot = { show = true, icon = 131023, size = 20, count = false },
    },
    other = {
        hideGryphons = false, autoAccept = false, autoComplete = false, sellJunk = false,
        hover = {},         -- [key from HOVER_FRAMES] = true: that Blizzard element shows only on mouseover
        bagsOnOpen = false, -- bag bar only while bags are open, attached to them
    },
}

DEFAULTS.regular.bars.health.target = false -- target health bar right of it (Combat Display only)
DEFAULTS.regular.hidePlayerFrame = false -- hide Blizzard's player unit frame
DEFAULTS.regular.hideBlizzCastbar = false -- hide Blizzard's player cast bar
DEFAULTS.regular.playerMenu = false      -- right-click on the bars opens the player menu
DEFAULTS.regular.playerTarget = false    -- left-click on the bars targets yourself
DEFAULTS.regular.playerMouseover = false -- hovering the bars makes you @mouseover
DEFAULTS.regular.highlight = { show = false, color = { 1, 1, 1, 0.25 } } -- overlay while hovered
-- In-combat icon, centered on the left edge of a bar (or the group, if that bar is hidden) + x/y.
DEFAULTS.regular.combatIcon = { show = true, style = "atlas", bar = "health", size = 20, x = -12, y = 0 }

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
-- store = WolfpackAddonDB, account-wide: { profiles = { [name] = settings }, chars = { [char] = name } }
-- db = the active profile's settings.
local store, db, class, charKey, classProfile
local changed, placeMini, useProfile -- defined further down

-- Bars that only show while they are doing something (cast, swing) stay visible while the bars
-- are unlocked or the options are open, so they can be placed.
function ns.previewing() return not db.locked or ns.configOpen end
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
    pethealth = {
        label = "Pet Health",
        state = function() return UnitExists("pet"), 1 end,
        value = function() return UnitHealth("pet"), UnitHealthMax("pet") end,
    },
    castbar = {
        label = "Cast Bar",
        -- only while casting: the bars below close the gap. ns.previewing keeps it visible while
        -- the bars are unlocked or the options are open, for placing it.
        state = function()
            return (ns.previewing() or UnitCastingInfo("player") or UnitChannelInfo("player")) and true or false, 1
        end,
    },
    swing = {
        label = "Swing Timer",
        state = function() return true, 1 end, -- a row per ticked weapon, each only while that one swings
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

local anchor = CreateFrame("Frame", "WolfpackAddonFrame", UIParent)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)

-- The pinned edge decides which way the stack grows when a bar joins or leaves: pin the top and
-- it grows down, pin the bottom and it grows up.
local function growEdge(L) return L.grow == "up" and "BOTTOM" or "TOP" end

local function place()
    anchor:ClearAllPoints()
    anchor:SetPoint(growEdge(db.regular), UIParent, "CENTER", db.regular.x, db.regular.y)
end

-- Position = the pinned edge's center, in pixels from the screen center.
local function coords()
    local ux, uy = UIParent:GetCenter()
    local edge = db.regular.grow == "up" and anchor:GetBottom() or anchor:GetTop()
    return math.floor(anchor:GetCenter() - ux + 0.5), math.floor(edge - uy + 0.5)
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
local moving -- true while the group is being dragged: Refresh must not re-place it then
mover:SetScript("OnDragStart", function()
    moving = true
    anchor:StartMoving()
    mover:SetScript("OnUpdate", function() moverHint:SetFormattedText(HINT, coords()) end) -- live coordinates
end)
mover:SetScript("OnDragStop", function()
    anchor:StopMovingOrSizing()
    moving = nil
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

local swingFrames = { regular = {}, nameplate = {} }
ns.swingFrames = swingFrames

for key in pairs(BARS) do
    frames[key] = newBar(anchor, key, "regular")
    plateFrames[key] = newBar(plateAnchor, key, "nameplate")
end
for i in ipairs(SWING_TYPES) do
    swingFrames.regular[i] = newBar(anchor, "swing", "regular")
    swingFrames.regular[i].swing = i
    swingFrames.nameplate[i] = newBar(plateAnchor, "swing", "nameplate")
    swingFrames.nameplate[i].swing = i
end

local MAX_STOPS = 8

-- Gradient points in drawing order. "left" and "up" mirror the positions.
local function sortedStops(c)
    local out = {}
    local flip = c.direction == "left" or c.direction == "up"
    for _, stop in ipairs(c.stops) do
        out[#out + 1] = { pos = flip and 100 - stop.pos or stop.pos, color = stop.color }
    end
    table.sort(out, function(a, b) return a.pos < b.pos end)
    return out
end

-- WoW gradients take two colors, so more points are drawn as one slice per pair, masked by the
-- bar's own fill so they only show over the filled part (no math on hidden health/power values).
local function paintSlices(s, c, w, h)
    local stops = sortedStops(c)
    local vertical = c.direction == "down" or c.direction == "up"
    s.fillMask:SetAllPoints(s:GetStatusBarTexture())
    for i = 1, math.max(#stops - 1, #s.slices) do
        local t = s.slices[i]
        if i >= #stops then
            if t then t:Hide() end
        else
            if not t then
                t = s:CreateTexture(nil, "ARTWORK", nil, 1)
                t:AddMaskTexture(s.fillMask)
                s.slices[i] = t
            end
            local from, to = stops[i], stops[i + 1]
            t:SetTexture(c.texture)
            t:ClearAllPoints()
            if vertical then
                t:SetPoint("TOPLEFT", s, "TOPLEFT", 0, -h * from.pos / 100)
                t:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, -h * to.pos / 100)
                t:SetGradient("VERTICAL", CreateColor(unpack(to.color)), CreateColor(unpack(from.color)))
            else
                t:SetPoint("TOPLEFT", s, "TOPLEFT", w * from.pos / 100, 0)
                t:SetPoint("BOTTOMRIGHT", s, "BOTTOMLEFT", w * to.pos / 100, 0)
                t:SetGradient("HORIZONTAL", CreateColor(unpack(from.color)), CreateColor(unpack(to.color)))
            end
            t:Show()
        end
    end
end

local function paint(s, c, r, g, b, w, h)
    s:SetStatusBarTexture(c.texture) -- before colors: a new texture resets them
    if c.gradient and #c.stops > 1 then
        s:SetStatusBarColor(1, 1, 1, 0) -- the slices do the drawing; the fill only shapes them
        paintSlices(s, c, w, h)
    else
        for _, t in ipairs(s.slices) do t:Hide() end
        s:SetStatusBarColor(r, g, b, c.color[4])
    end
end

-- Rounded corners: WoW has no border-radius, so textures get a mask cut from a rounded
-- rectangle. Media/Round/r<N>.tga has corners of exactly N px (1-50); nine-sliced with N px
-- margins, the corners draw at that size on any bar size.
local MASK_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Round\\r"
local MAX_RADIUS = 50

local function newMask(owner)
    return owner:CreateMaskTexture()
end

-- Corner radius r on a w x h area; 0 = square (mask removed). Capped at half the short side,
-- which is also what "pill" asks for (r = huge).
local function round(tex, m, r, w, h)
    r = math.floor(math.min(r, w / 2, h / 2, MAX_RADIUS))
    if r > 0 and m.r ~= r then
        m:SetTexture(MASK_DIR .. r .. ".tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetTextureSliceMargins(r, r, r, r)
        m.r = r
    end
    if (r > 0) ~= (tex.cpdMask == m) then
        if r > 0 then tex:AddMaskTexture(m) else tex:RemoveMaskTexture(m) end
        tex.cpdMask = r > 0 and m or nil
    end
end

local hovered -- cursor over the Combat Display group (highlight option)

-- Class color of a unit; nil for NPCs other than you (they have classes too, which would look random).
local function classRGB(unit)
    if unit ~= "player" and not UnitIsPlayer(unit) then return end
    local _, token = UnitClass(unit)
    local cc = token and (C_ClassColor and C_ClassColor.GetClassColor(token) or RAID_CLASS_COLORS[token])
    if cc then return cc.r, cc.g, cc.b end
end

-- A bar's fill and border colors after the color modes. Alpha always comes from the swatch.
local function barColors(f, c)
    local r, g, b = unpack(c.color)
    if c.colorMode == "power" and f.key == "power" then
        local pc = PowerBarColor and PowerBarColor[select(2, UnitPowerType("player"))]
        if pc then r, g, b = pc.r, pc.g, pc.b end
    elseif c.colorMode == "class" then
        local cr, cg, cb = classRGB(f.unit or "player")
        if cr then r, g, b = cr, cg, cb end
    end
    local br, bg, bb, ba = unpack(c.borderColor)
    if c.borderMode == "bar" then
        br, bg, bb = r, g, b
    elseif c.borderMode == "class" then
        local cr, cg, cb = classRGB(f.unit or "player")
        if cr then br, bg, bb = cr, cg, cb end
    end
    return r, g, b, br, bg, bb, ba
end

local function layoutBar(f, n, width)
    local c = db[f.mode].bars[f.key]
    width = width or c.width
    f.width = width
    local r, g, b, br, bg, bb, ba = barColors(f, c)
    -- Cast bar spell icon: a square at one end, inside the bar's width.
    local lead, iconSpace = 0, 0
    if f.key == "castbar" then
        f.icon = f.icon or f:CreateTexture(nil, "ARTWORK")
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's built-in border
        f.icon:SetSize(c.height, c.height)
        f.icon:ClearAllPoints()
        f.icon:SetPoint(c.iconSide == "right" and "RIGHT" or "LEFT", f)
        f.icon:SetShown(c.icon and true or false)
        if c.icon then
            iconSpace = c.height + PIP_GAP
            if c.iconSide ~= "right" then lead = iconSpace end
        end
    end
    f:SetSize(width, c.height)
    local w = (width - iconSpace - (n - 1) * PIP_GAP) / n
    for i = 1, math.max(n, #f.segs) do
        local s = f.segs[i]
        if i > n then
            s:Hide()
        else
            if not s then
                s = CreateFrame("StatusBar", nil, f)
                s.bg = s:CreateTexture(nil, "BACKGROUND")
                s.bg:SetAllPoints()
                s.bg:SetColorTexture(0, 0, 0, 0.5) -- recolored per bar below
                s.border = s:CreateTexture(nil, "BACKGROUND", nil, -8) -- behind the background
                s.mask, s.borderMask = newMask(s), newMask(s)
                s.slices = {}
                s.fillMask = s:CreateMaskTexture() -- the filled part, for the gradient slices
                s.fillMask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                s.mask:SetAllPoints(s)
                s.borderMask:SetAllPoints(s.border)
                s.hl = s:CreateTexture(nil, "OVERLAY", nil, -8) -- hover highlight; text draws above it
                s.hl:SetAllPoints(s.border)
                f.segs[i] = s
            end
            -- The border sits inside the bar's size (like CSS border-box); the bar is inset by it.
            local t = math.min(c.borderSize, (c.height - 1) / 2, (w - 1) / 2)
            local iw, ih = w - 2 * t, c.height - 2 * t
            s:SetSize(iw, ih)
            s:SetPoint("LEFT", f, "LEFT", lead + (i - 1) * (w + PIP_GAP) + t, 0)
            s:SetMinMaxValues(i - 1, i) -- pip range; single bars get their real max in fill()
            s.bg:SetColorTexture(unpack(c.bgColor))
            paint(s, c, r, g, b, w, c.height)
            s.border:SetShown(t > 0)
            s.border:SetPoint("TOPLEFT", s, "TOPLEFT", -t, t)
            s.border:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", t, -t)
            s.border:SetColorTexture(br, bg, bb, ba)
            local radius = c.radius == "pill" and math.huge or c.radius
            round(s.border, s.borderMask, radius, w, c.height)
            s.hl:SetColorTexture(unpack(db.regular.highlight.color))
            s.hl:SetShown((f.mode == "regular" and hovered) or false)
            round(s.hl, s.borderMask, radius, w, c.height)
            local inner = math.max(radius - t, 0) -- inner corners follow the outer ones
            round(s.bg, s.mask, inner, iw, ih)
            round(s:GetStatusBarTexture(), s.mask, inner, iw, ih)
            s:Show()
        end
    end
    if not f.text then
        f.text = f.segs[1]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.text:SetPoint("CENTER") -- centered on the bar itself (not the cast bar's icon)
    end
    f.text:SetShown(c.text and n == 1)
    local flags = c.outline and "OUTLINE" or ""
    if not f.text:SetFont(c.font, c.fontSize, flags) then f.text:SetFont(FONTS[1][2], c.fontSize, flags) end
    f.text:SetTextColor(unpack(c.textColor))
    f.n = n
end

local function setText(fs, v) fs:SetText(AbbreviateNumbers(v)) end

-- The cast bar fills from the game's own cast duration object (no per-frame Lua): casts fill
-- up, channels drain. Not casting: the whole bar, border included, goes invisible.
local TIMER_ELAPSED, TIMER_REMAINING = 0, 1 -- Enum.StatusBarTimerDirection
local function fillCast(f)
    local name, _, icon = UnitCastingInfo("player")
    local duration, direction = name and UnitCastingDuration("player"), TIMER_ELAPSED
    if not name then
        name, _, icon = UnitChannelInfo("player")
        duration, direction = name and UnitChannelDuration("player"), TIMER_REMAINING
    end
    if not name then -- previewing (the bar only shows at all while casting)
        f.text:SetText(BARS.castbar.label)
        f.icon:SetTexture(134400) -- Interface/ICONS/INV_Misc_QuestionMark
        return
    end
    if duration then f.segs[1]:SetTimerDuration(duration, 0, direction) end
    f.text:SetText(name)
    f.icon:SetTexture(icon)
end

-- Swing timers come from the game's own PLAYER_SWING event (no combat log needed).
local swingState = {} -- [swing type] = { start, duration }

local function swingActive(kind)
    local now = GetTime()
    if kind then
        local st = swingState[kind]
        return (st and now < st.start + st.duration) and true or false
    end
    for _, st in pairs(swingState) do
        if now < st.start + st.duration then return true end
    end
    return false
end

local function fillSwing(f)
    local kind = SWING_TYPES[f.swing]
    local st = swingState[kind[3]]
    if not swingActive(kind[3]) then
        f.text:SetText(kind[2]) -- preview
        return
    end
    local elapsed = GetTime() - st.start
    f.segs[1]:SetMinMaxValues(0, st.duration)
    f.segs[1]:SetValue(elapsed)
    f.text:SetText(string.format("%.1f", st.duration - elapsed))
end

local function fill(f)
    if f.key == "castbar" then return fillCast(f) end
    if f.key == "swing" then return fillSwing(f) end
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

local QUEST_ORDER = { "kill", "loot" } -- left to right

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

-- kill, loot for a unit: "mine", "party" (only groupmates still need it) or nil, plus how many
-- are still needed (from the "3/10" in the tooltip line, so groupmates' numbers work too). Open
-- objectives only. In a group the tooltip names whose objective follows (QuestPlayer lines); where
-- it doesn't, the objective counts as yours. ponytail: objective types come from your own quest
-- log, so a groupmate's item objective for a quest you don't have shows as a kill.
local function questKinds(unit)
    local related = C_QuestLog.UnitIsRelatedToActiveQuest(unit)
    if not related and not IsInGroup() then return nil, nil, {} end -- solo: skip the tooltip
    local data = C_TooltipInfo.GetUnit(unit)
    local mine, party, anyObjective, own = {}, {}, false, true
    local left = {}
    for _, line in ipairs(data and data.lines or {}) do
        if line.type == LINE.QuestTitle then
            own = true
        elseif line.type == LINE.QuestPlayer then
            own = line.leftText == playerName
        elseif line.type == LINE.QuestObjective then
            anyObjective = true
            if not line.completed then
                local text = line.leftText or ""
                local kind = objectiveTypes[bareText(text)] == "item" and "loot" or "kill"
                if own then mine[kind] = true else party[kind] = true end
                local have, need = text:match("(%d+)%s*/%s*(%d+)")
                if have then -- one mob can serve several quests: the biggest count is what's left
                    left[kind] = math.max(left[kind] or 0, need - have)
                end
            end
        end
    end
    if not anyObjective and related then mine.kill = true end -- quest mob, but no objective named
    return mine.kill and "mine" or party.kill and "party" or nil,
        mine.loot and "mine" or party.loot and "party" or nil, left
end

-- Nameplates are recycled, so each plate keeps one icon holder; plateUnits maps the units
-- currently on screen to their holder.
local questHolders, plateUnits = {}, {}
ns.plateUnits = plateUnits

-- The row's box always has room for every enabled icon type; the icons a mob needs fill it from
-- the left, so a lone icon sits at the box's left edge.
local function styleQuest(h)
    local q, w, ht = db.quest, 0, 0
    for _, kind in ipairs(QUEST_ORDER) do
        local c = q[kind]
        if c.show then
            w = w + (w > 0 and q.spacing or 0) + c.size
            ht = math.max(ht, c.size)
        end
    end
    h.box:SetSize(math.max(w, 1), math.max(ht, 1))
    h.box:ClearAllPoints()
    h.box:SetPoint("TOPRIGHT", h, "TOPRIGHT", q.x, q.y)
    local x = 0
    for _, kind in ipairs(QUEST_ORDER) do
        local c, t = q[kind], h[kind]
        local on = (h.want[kind] and c.show) and true or false
        t:SetTexture(c.icon)
        t:SetDesaturated(h.want[kind] == "party") -- groupmates need it, you don't: grayscale
        t:SetSize(c.size, c.size)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", h.box, "TOPLEFT", x, 0)
        t:SetShown(on)
        local badge, count = h.badge[kind], h.left[kind]
        local showCount = (on and c.count and count and count > 0) and true or false
        badge.text:SetShown(showCount)
        badge.bg:SetShown(showCount)
        if showCount then
            badge.text:SetText(count)
            badge.bg:SetSize(badge.text:GetStringWidth() + 4, badge.text:GetStringHeight() + 2)
        end
        if on then x = x + c.size + q.spacing end
    end
end

local function evalQuest(unit)
    local h = plateUnits[unit]
    if not h then return end
    local ok, kill, loot, left = pcall(questKinds, unit)
    if ok then -- secret mid-combat: keep what we had
        h.want.kill, h.want.loot = kill, loot
        h.left.kill, h.left.loot = left.kill, left.loot
    end
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
        h.box = CreateFrame("Frame", nil, h)
        h.kill, h.loot, h.want, h.left = h.box:CreateTexture(nil, "OVERLAY"), h.box:CreateTexture(nil, "OVERLAY"), {}, {}
        h.badge = {}
        for _, kind in ipairs(QUEST_ORDER) do -- small "how many left" plate above the icon
            local bg = h.box:CreateTexture(nil, "OVERLAY", nil, 1)
            bg:SetColorTexture(0, 0, 0, 0.8)
            local text = h.box:CreateFontString(nil, "OVERLAY", nil, 2)
            text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            text:SetPoint("BOTTOM", h[kind], "TOP", 0, 2)
            bg:SetPoint("CENTER", text)
            h.badge[kind] = { bg = bg, text = text }
        end
        questHolders[plate] = h
    end
    h.want.kill, h.want.loot = nil, nil
    h.left.kill, h.left.loot = nil, nil
    plateUnits[unit] = h
    evalQuest(unit)
end

local function plateRemoved(unit)
    local h = plateUnits[unit]
    if not h then return end
    h.want.kill, h.want.loot = nil, nil
    styleQuest(h)
    plateUnits[unit] = nil
end

local function questLogChanged()
    scanQuestLog()
    for unit in pairs(plateUnits) do evalQuest(unit) end
end

-- Lays out one stack: shown bars in order, touching with the gap. Each bar sits in its slot
-- plus its own x/y offset; offsets don't push the other bars around.
local function stack(container, set, L, on, swings)
    local w, h = 0, 0
    for _, key in ipairs(L.order) do
        local f, c = set[key], L.bars[key]
        local shown, n = BARS[key].state()
        shown = (on and shown and c.show) and true or false
        if key == "swing" then -- one row per ticked weapon, sharing this bar's settings
            for i, kind in ipairs(SWING_TYPES) do
                local sf = swings[i]
                local rowShown = (shown and c[kind[1]] and (swingActive(kind[3]) or ns.previewing())) and true or false
                sf:SetShown(rowShown)
                if rowShown then
                    layoutBar(sf, 1)
                    fill(sf)
                    if h > 0 then h = h + L.gap end
                    h = h + c.padTop
                    sf:ClearAllPoints()
                    sf:SetPoint("TOP", container, "TOP", c.x, c.y - h)
                    h = h + c.height + c.padBottom
                    w = math.max(w, c.width)
                end
            end
            shown = false
        end
        f:SetShown(shown)
        if shown then
            -- f.split: the player health bar shares its width with the target health bar
            layoutBar(f, n, f.split and (c.width - L.gap) / 2 or nil)
            fill(f)
            if h > 0 then h = h + L.gap end
            h = h + c.padTop
            f:ClearAllPoints()
            if f.split then
                f:SetPoint("TOPLEFT", container, "TOP", c.x - c.width / 2, c.y - h)
            else
                f:SetPoint("TOP", container, "TOP", c.x, c.y - h)
            end
            h = h + c.height + c.padBottom
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
local castHidden, castParent, castHooked

-- Blizzard's player cast bar: parked under the hidden frame. Blizzard re-parents it itself when
-- the "lock to player frame" setting applies, so a secure hook parks it again and remembers where
-- Blizzard wanted it, for when the option goes off. No Blizzard fields or methods are touched.
local function syncCastbar()
    local bar = PlayerCastingBarFrame
    local hide = db.regular.hideBlizzCastbar and true or false
    if not bar or not (hide or castHidden) then return end
    if not castHooked then
        hooksecurefunc(bar, "SetParent", function(self, parent)
            if parent == hider then return end
            castParent = parent
            if castHidden and not InCombatLockdown() then self:SetParent(hider) end
        end)
        castHooked = true
    end
    if hide and not castHidden then castParent = bar:GetParent() end
    castHidden = hide
    local want = hide and hider or castParent
    if bar:GetParent() ~= want then bar:SetParent(want) end
end

local function syncProtected()
    if InCombatLockdown() then return end
    syncCastbar() -- may be attached to the (protected) player frame, so also out of combat only
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
        clicker = CreateFrame("Button", "WolfpackAddonClicker", UIParent, "SecureUnitButtonTemplate")
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

-- In-combat icon art: an atlas or a file (with a crop).
local COMBAT_ICONS = {
    { "Player frame swords", "atlas" },
    { "Classic swords", "classic" },
    { "Dual Wield icon", "dualwield" },
    { "Battle Stance icon", "battle" },
}
local COMBAT_ART = {
    atlas = { atlas = "UI-HUD-UnitFrame-Player-CombatIcon" },
    classic = { file = 130936, coords = { 0.5, 1, 0, 0.49 } },     -- Interface/CHARACTERFRAME/UI-StateIcon
    dualwield = { file = 132147, coords = { 0.08, 0.92, 0.08, 0.92 } }, -- Interface/ICONS/Ability_DualWield
    battle = { file = 132349, coords = { 0.08, 0.92, 0.08, 0.92 } }, -- Interface/ICONS/Ability_Warrior_OffensiveStance
}
local function setCombatArt(t, style)
    local a = COMBAT_ART[style] or COMBAT_ART.atlas
    if a.atlas then
        t:SetAtlas(a.atlas)
    else
        t:SetTexture(a.file)
        t:SetTexCoord(unpack(a.coords))
    end
end

local inCombat -- from PLAYER_REGEN_DISABLED / _ENABLED
local combatIcon = CreateFrame("Frame", nil, anchor)
combatIcon:SetFrameLevel(anchor:GetFrameLevel() + 15) -- above the bars
combatIcon.tex = combatIcon:CreateTexture(nil, "OVERLAY")
combatIcon.tex:SetAllPoints()
ns.combatIcon = combatIcon

local function syncCombatIcon()
    local ci = db.regular.combatIcon
    local bar = frames[ci.bar]
    local host = (bar and bar:IsShown()) and bar or anchor
    combatIcon:ClearAllPoints()
    combatIcon:SetPoint("CENTER", host, "LEFT", ci.x, ci.y)
    combatIcon:SetSize(ci.size, ci.size)
    setCombatArt(combatIcon.tex, ci.style)
    -- also shown as a preview while unlocked or in the options, for placing it
    combatIcon:SetShown((ci.show and (inCombat or not db.locked or ns.configOpen)) and true or false)
end

local function setHover(on)
    if on == (hovered or false) then return end
    hovered = on
    for _, f in pairs(frames) do
        for _, s in ipairs(f.segs) do s.hl:SetShown(on) end
    end
    for _, s in ipairs(targetFrame.segs) do s.hl:SetShown(on) end
end

-- IsMouseOver works without EnableMouse, so the highlight never blocks clicks.
local function checkHover() setHover(anchor:IsMouseOver()) end

-- Blizzard UI elements that can show only on mouseover. Protected bars may not be hidden in
-- combat, but their alpha may change: invisible, still clickable, keybinds still work.
local HOVER_FRAMES = {
    { "bar1", "Action bar 1", "MainActionBar" }, { "bar2", "Action bar 2", "MultiBarBottomLeft" },
    { "bar3", "Action bar 3", "MultiBarBottomRight" }, { "bar4", "Action bar 4", "MultiBarRight" },
    { "bar5", "Action bar 5", "MultiBarLeft" }, { "bar6", "Action bar 6", "MultiBar5" },
    { "bar7", "Action bar 7", "MultiBar6" }, { "bar8", "Action bar 8", "MultiBar7" },
    { "stance", "Stance bar", "StanceBar" }, { "pet", "Pet bar", "PetActionBar" },
    { "micro", "Micro menu", "MicroMenuContainer" }, { "bags", "Bag bar", "BagsBar" },
}
local FADE_TIME = 0.2
local faded = {} -- frame -> alpha we set

local hoverTicker = CreateFrame("Frame")
ns.hoverTicker = hoverTicker
local function hoverTick(_, elapsed)
    local editing = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local step = math.min(elapsed / FADE_TIME, 1)
    for _, e in ipairs(HOVER_FRAMES) do
        local f = _G[e[3]]
        if f and db.other.hover[e[1]] then
            local want = (editing or f:IsMouseOver()) and 1 or 0
            local a = faded[f] or f:GetAlpha()
            a = a + math.max(-step, math.min(step, want - a))
            f:SetAlpha(a)
            faded[f] = a
        elseif f and faded[f] then -- option turned off: back to normal
            f:SetAlpha(1)
            faded[f] = nil
        end
    end
end

local function syncHover()
    local any = false
    for _, e in ipairs(HOVER_FRAMES) do any = any or db.other.hover[e[1]] or false end
    if any or next(faded) then
        hoverTicker:SetScript("OnUpdate", hoverTick)
        if not any then hoverTick(nil, 0); hoverTicker:SetScript("OnUpdate", nil) end
    end
end

-- Bag bar only while bags are open, attached to them. Parked under the hidden frame otherwise
-- (so Blizzard showing it doesn't reveal it); its Edit Mode spot is restored when turned off.
local bagsHooked, bagsParked, bagsSaved

local function openBagFrame()
    for _, f in ipairs({ ContainerFrameCombinedBags, ContainerFrame1 }) do
        if f and f:IsShown() then return f end
    end
end

local function syncBags()
    local bar = BagsBar
    local on = db.other.bagsOnOpen
    if not bar or not (on or bagsSaved) then return end
    if not bagsSaved then -- first use: remember where Edit Mode put it
        bagsSaved = { parent = bar:GetParent() }
        for i = 1, bar:GetNumPoints() do bagsSaved[i] = { bar:GetPoint(i) } end
    end
    if not bagsHooked then
        for _, f in ipairs({ ContainerFrameCombinedBags, ContainerFrame1 }) do
            if f then
                f:HookScript("OnShow", function() syncBags() end)
                f:HookScript("OnHide", function() syncBags() end)
            end
        end
        bagsHooked = true
    end
    local bags = on and openBagFrame()
    bar:ClearAllPoints()
    if bags then
        bar:SetParent(bagsSaved.parent)
        if bags == ContainerFrameCombinedBags then
            bar:SetPoint("BOTTOMRIGHT", bags, "TOPRIGHT", 0, 4)
        else -- separate bags stack upward from the backpack, so go beside it
            bar:SetPoint("BOTTOMRIGHT", bags, "BOTTOMLEFT", -6, 0)
        end
    elseif on then
        bar:SetParent(hider)
    else -- turned off: back to the Edit Mode spot
        bar:SetParent(bagsSaved.parent)
        for _, pt in ipairs(bagsSaved) do bar:SetPoint(unpack(pt)) end
        bagsSaved = nil
    end
end

local function Refresh()
    if not moving then place() end -- keeps the pinned edge right after any settings change
    local health = frames.health
    health.split = (db.regular.bars.health.target and UnitExists("target")) and true or false
    stack(anchor, frames, db.regular, true, swingFrames.regular)
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
        plateAnchor:SetPoint(growEdge(db.nameplate), plate, "BOTTOM", db.nameplate.x, db.nameplate.y)
    end
    stack(plateAnchor, plateFrames, db.nameplate, plate ~= nil, swingFrames.nameplate)
    for _, h in pairs(questHolders) do styleQuest(h) end
    mover:SetShown(not db.locked)
    moverHint:SetFormattedText(HINT, db.regular.x, db.regular.y)
    syncProtected()
    syncGryphons()
    syncCombatIcon()
    syncHover()
    syncBags()
    anchor:SetScript("OnUpdate", db.regular.highlight.show and checkHover or nil)
    if not db.regular.highlight.show then setHover(false) end
end

-- One report per session, printed to chat: Lua errors are hidden by default and this client
-- stops delivering them after 100.
local function safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not ns.errored then
        ns.errored = true
        print("|cffff5555Wolfpack Addon error:|r " .. tostring(err))
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

-- A titled 1 px box that stacks rows: row(h) gives the y for a widget that tall. The lowest
-- box on any page decides how tall the options window needs to be.
local pageBottom = 0
local function group(parent, x, y, w, title)
    local g = { x = x + 8, cursor = y - 24, w = w }
    g.title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    g.title:SetPoint("TOPLEFT", x + 6, y)
    g.title:SetText(title)
    function g:row(h)
        local at = self.cursor
        self.cursor = at - h
        return at
    end
    function g:close()
        local top, bottom = y - 16, self.cursor - 8
        pageBottom = math.min(pageBottom, bottom)
        for _, side in ipairs({ { x, top, w, 1 }, { x, bottom, w, 1 }, { x, top, 1, top - bottom },
            { x + w - 1, top, 1, top - bottom } }) do
            local t = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
            t:SetColorTexture(1, 1, 1, 0.18)
            t:SetPoint("TOPLEFT", side[1], side[2])
            t:SetSize(side[3], side[4])
        end
        return self
    end
    return g
end

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
    s:SetSize(130, 16) -- 130 + 12 + 40 fits a box's inner width
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

-- Color swatch + picker. Optional `mode`: { get = fn, set = fn, effective = fn -> r, g, b } for
-- colors that can come from elsewhere (class, bar, power): the swatch and the picker show that
-- color, and picking a new one switches the mode to "custom". Opacity changes keep the mode.
ns.swatches = {}
local function swatch(parent, text, x, y, get, mode)
    local b = CreateFrame("Button", nil, parent)
    ns.swatches[text] = b
    b:SetSize(20, 20)
    b:SetPoint("TOPLEFT", x + 2, y)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(1, 1, 1)
    local fillTex = b:CreateTexture(nil, "ARTWORK")
    fillTex:SetPoint("TOPLEFT", 2, -2)
    fillTex:SetPoint("BOTTOMRIGHT", -2, 2)
    label(b, text):SetPoint("LEFT", b, "RIGHT", 6, 0)
    local function shown()
        local c = get()
        if mode then
            local r, g, bl = mode.effective()
            return r, g, bl, c[4]
        end
        return unpack(c)
    end
    b:SetScript("OnClick", function()
        local c = get()
        local old, oldMode = { c[1], c[2], c[3], c[4] }, mode and mode.get()
        local r0, g0, b0 = shown()
        local function apply(r, g, bl, a) c[1], c[2], c[3], c[4] = r, g, bl, a; changed() end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r0, g = g0, b = b0, opacity = c[4], hasOpacity = true,
            swatchFunc = function()
                local r, g, bl = ColorPickerFrame:GetColorRGB()
                if mode then mode.set("custom") end
                apply(r, g, bl, ColorPickerFrame:GetColorAlpha())
            end,
            opacityFunc = function() apply(c[1], c[2], c[3], ColorPickerFrame:GetColorAlpha()) end,
            cancelFunc = function()
                if mode then mode.set(oldMode) end
                apply(unpack(old))
            end,
        })
    end)
    onRefresh(function() fillTex:SetColorTexture(shown()) end)
    return b
end

-- Dropdown over a { {name, value}, ... } list; preview(button, value) decorates each entry and
-- returns its width.
local function dropdown(parent, text, x, y, list, get, set, preview)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", x, y - 14)
    dd:SetWidth(178)
    label(dd, text, "GameFontNormalSmall"):SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 2)
    dd:SetupMenu(function(_, root)
        for _, item in ipairs(type(list) == "function" and list() or list) do
            local radio = root:CreateRadio(item[1], function() return get() == item[2] end,
                function() set(item[2]); changed() end)
            radio:AddInitializer(function(button) return preview(button, item), 20 end)
        end
    end)
    onRefresh(function() dd:GenerateMenu() end)
    return dd
end

-- Menu entry previews sit in a fixed-width column right after the radio tick, and the name
-- starts after that column, so a preview can never cover a name, however wide the menu ends up.
-- Returns the entry width. (Name width falls back to an estimate if it can't be measured yet.)
local function beforeName(button, item, region, slot)
    if button.leftTexture1 then
        region:SetPoint("LEFT", button.leftTexture1, "RIGHT", 4, 0)
    else
        region:SetPoint("LEFT", button, "LEFT", 22, 0)
    end
    button.fontString:SetPoint("LEFT", region, "LEFT", slot + 10, 0)
    local nameW = math.max(button.fontString:GetUnboundedStringWidth(), #item[1] * 7)
    return 22 + slot + 10 + nameW + 12
end

local function textPreview(button, item)
    return 22 + math.max(button.fontString:GetUnboundedStringWidth(), #item[1] * 7) + 16
end

local function texturePreview(button, item)
    local t = button:AttachTexture()
    t:SetSize(90, 12)
    t:SetTexture(item[2])
    t:SetVertexColor(unpack(cur().color))
    return beforeName(button, item, t, 90)
end

-- Menu font strings refuse SetFont, so each font gets a Font object for SetFontObject.
-- Copying the default first keeps a usable font if a file fails to load.
for i, f in ipairs(FONTS) do
    f.object = CreateFont("WolfpackAddonFont" .. i)
    f.object:CopyFontObject(GameFontHighlight)
    f.object:SetFont(f[2], 14, "")
end

for i, f in ipairs(COMBAT_FONTS) do
    f.object = CreateFont("WolfpackAddonCombatFont" .. i)
    f.object:CopyFontObject(GameFontHighlight)
    f.object:SetFont(f[2] ~= "" and f[2] or DEFAULT_DAMAGE_FONT, 16, "OUTLINE")
end

local DAMAGE_YELLOW = { 1, 1, 0 } -- like the game's spell damage numbers

local function combatFontPreview(button, item)
    local fs = button:AttachFontString()
    fs:SetFontObject(item.object)
    fs:SetTextColor(unpack(DAMAGE_YELLOW))
    fs:SetText("123")
    return beforeName(button, item, fs, 56) -- widest: Press Start 2P, 48 px at 16 px
end

local function fontPreview(button, item)
    local fs = button:AttachFontString()
    fs:SetFontObject(item.object)
    fs:SetText("123")
    return beforeName(button, item, fs, 44)
end

local function iconPreview(button, item)
    local t = button:AttachTexture()
    t:SetSize(20, 20)
    t:SetTexture(item[2])
    return beforeName(button, item, t, 20)
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

------------------------------------------------------------------------------------------
-- Export / import. Two separate strings:
--  * the addon profile: "WPA1:" + base64(deflate(CBOR{ name, profile, combatFont })), imported here
--  * the WoW UI layout: Blizzard's own Edit Mode string, imported in Edit Mode itself, because
--    writing Edit Mode layouts from an addon would get overwritten or taint Edit Mode
------------------------------------------------------------------------------------------
local E = C_EncodingUtil

local function exportString()
    local data = { name = store.chars[charKey], profile = db, combatFont = store.combatFont }
    return "WPA1:" .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(data)))
end

local function editModeString()
    local ok, layout = pcall(function()
        return C_EditMode.ConvertLayoutInfoToString(EditModeManagerFrame:GetActiveLayoutInfo())
    end)
    return ok and type(layout) == "string" and layout or nil
end

-- An imported profile is untrusted: keep only settings DEFAULTS knows, with the same type and
-- sane numbers; the bar order keeps known bars once each and gets missing ones appended.
local MIN_NUMBER = { width = 1, height = 1, size = 1, fontSize = 1, borderSize = 0, gap = 0, spacing = 0 }

local function sanitize(src, template)
    local out = {}
    src = type(src) == "table" and src or {}
    for k, def in pairs(template) do
        local v = src[k]
        if k == "stops" then -- 2 to MAX_STOPS points, each a percent and a color
            out.stops = {}
            for _, stop in ipairs(type(v) == "table" and v or {}) do
                local pos, col = stop and stop.pos, stop and stop.color
                if type(pos) == "number" and pos == pos and pos >= 0 and pos <= 100 and type(col) == "table"
                    and #out.stops < MAX_STOPS then
                    out.stops[#out.stops + 1] = { pos = pos, color = sanitize(col, def[1].color) }
                end
            end
            if #out.stops < 2 then out.stops = sanitize(nil, def) end
        elseif k == "hover" then -- a map: only known elements, only true
            out.hover = {}
            for _, e in ipairs(HOVER_FRAMES) do
                if type(v) == "table" and v[e[1]] == true then out.hover[e[1]] = true end
            end
        elseif k == "order" then
            local seen = {}
            out.order = {}
            for _, key in ipairs(type(v) == "table" and v or {}) do
                if BARS[key] and not seen[key] then seen[key] = true; out.order[#out.order + 1] = key end
            end
            for _, key in ipairs(def) do
                if not seen[key] then out.order[#out.order + 1] = key end
            end
        elseif type(def) == "table" then
            out[k] = sanitize(v, def)
        elseif type(v) == "number" then
            if v == v and v >= (MIN_NUMBER[k] or -2000) and v <= 2000 then out[k] = v end
        elseif type(v) == type(def) or (k == "radius" and v == "pill") then
            out[k] = v
        end
    end
    return out
end

-- Returns the new profile's name (and the Edit Mode layout older combined strings carried), or
-- nil and an error.
local function importString(text)
    text = (text or ""):gsub("%s", "")
    local b64 = text:match("^WPA1:(.+)$") or text:match("^CPD1:(.+)$") -- CPD1: was the old name
    if not b64 then
        local ok, layout = pcall(C_EditMode.ConvertStringToLayoutInfo, text)
        if text ~= "" and ok and layout then
            return nil, "That's a WoW UI layout string. Paste it in Edit Mode instead: open Edit Mode, "
                .. "then Layout dropdown, Import."
        end
        return nil, "That's not a Wolfpack Addon string (those start with WPA1:)."
    end
    local ok, data = pcall(function() return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(b64))) end)
    if not ok or type(data) ~= "table" or type(data.profile) ~= "table" then
        return nil, "The string is damaged or incomplete. Copy it again in full."
    end
    local base = type(data.name) == "string" and strtrim(data.name):sub(1, 32) or ""
    if base == "" then base = "Imported" end
    local name, n = base, 2
    while store.profiles[name] do name, n = base .. " " .. n, n + 1 end
    store.profiles[name] = sanitize(data.profile, DEFAULTS)
    for _, f in ipairs(COMBAT_FONTS) do
        if data.combatFont == f[2] and f[2] ~= "" then store.combatFont = f[2] end
    end
    useProfile(name)
    return name, type(data.editMode) == "string" and data.editMode or nil
end
ns.exportString, ns.editModeString, ns.importString = exportString, editModeString, importString

StaticPopupDialogs.WOLFPACKADDON_DELETE = {
    text = "Delete Wolfpack Addon profile \"%s\"?",
    button1 = YES, button2 = NO,
    OnAccept = function(_, name) deleteProfile(name) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local openStops -- the gradient points dialog, defined below

local ioFrame

local function textArea(parent, y, h)
    local area = CreateFrame("Frame", nil, parent)
    area:SetPoint("TOPLEFT", 14, y)
    area:SetPoint("TOPRIGHT", -14, y)
    area:SetHeight(h)
    local bg = area:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    local sf = CreateFrame("ScrollFrame", nil, area, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 4, -4)
    sf:SetPoint("BOTTOMRIGHT", -26, 4)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(470)
    box:SetScript("OnEscapePressed", function() box:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function() box:HighlightText() end) -- click, Ctrl+C
    sf:SetScrollChild(box)
    area.box = box
    return area
end

local function openIO(mode)
    local f = ioFrame
    if not f then
        f = CreateFrame("Frame", "WolfpackAddonIO", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(540, 400)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        tinsert(UISpecialFrames, f:GetName())
        f.title = label(f, "")
        f.title:SetPoint("TOP", 0, -5)
        f.label1 = label(f, "", "GameFontNormal")
        f.label1:SetPoint("TOPLEFT", 16, -32)
        f.area1 = textArea(f, -50, 110)
        f.label2 = label(f, "2. WoW UI layout (Edit Mode). Import it in Edit Mode: Layout dropdown, Import.",
            "GameFontNormal")
        f.label2:SetPoint("TOPLEFT", 16, -172)
        f.area2 = textArea(f, -190, 110)
        f.note = label(f, "", "GameFontHighlightSmall")
        f.note:SetPoint("TOPLEFT", 16, -312)
        f.note:SetWidth(505)
        f.note:SetJustifyH("LEFT")
        f.import = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.import:SetSize(100, 22)
        f.import:SetPoint("BOTTOMRIGHT", -16, 14)
        f.import:SetText("Import")
        f.import:SetScript("OnClick", function()
            local name, extra = importString(f.area1.box:GetText())
            if not name then
                f.note:SetText("|cffff5555" .. extra .. "|r")
            else
                f.area1.box:SetText("")
                f.note:SetText("Imported as profile \"" .. name .. "\" and switched to it."
                    .. (extra and " This older string also held a WoW UI layout: it's in the box below, "
                        .. "for Edit Mode's Import." or ""))
                f.area2:SetShown(extra ~= nil)
                f.label2:SetShown(extra ~= nil)
                if extra then f.area2.box:SetText(extra) end
            end
        end)
        ioFrame = f
    end
    local export = mode == "export"
    f.title:SetText(export and "Export" or "Import profile")
    f.import:SetShown(not export)
    f.area2:SetShown(export)
    f.label2:SetShown(export)
    if export then
        f.label1:SetText("1. Addon profile. Import it here with Import (profile row).")
        f.area1.box:SetText(exportString())
        f.area2.box:SetText(editModeString() or "(The WoW UI layout isn't available right now.)")
        f.note:SetText("Click a box, then Ctrl+C. Keep the profile string somewhere safe: the beta forgets "
            .. "addon settings when the game restarts, and it brings them back.")
        f.area1.box:SetFocus()
    else
        f.label1:SetText("Paste an addon profile string (starts with WPA1:), then click Import.")
        f.area1.box:SetText("")
        f.note:SetText("It becomes a new profile. WoW UI layout strings go into Edit Mode's own Import.")
        f.area1.box:SetFocus()
    end
    f:Show()
end

-- Gradient points dialog: percent + color per point, for the bar picked in the options.
local stopsFrame
function openStops()
    local f = stopsFrame
    if not f then
        f = CreateFrame("Frame", "WolfpackAddonStops", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(330, 330)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        tinsert(UISpecialFrames, f:GetName())
        f.title = label(f, "Gradient points")
        f.title:SetPoint("TOP", 0, -5)
        label(f, "Percent across the bar, and the color there.", "GameFontDisableSmall")
            :SetPoint("TOPLEFT", 16, -30)
        f.rows = {}
        for i = 1, MAX_STOPS do
            local y = -50 - (i - 1) * 26
            local row = CreateFrame("Frame", nil, f)
            row:SetPoint("TOPLEFT", 16, y)
            row:SetSize(300, 24)
            local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            box:SetSize(40, 20)
            box:SetPoint("TOPLEFT", 6, 0)
            box:SetAutoFocus(false)
            box:SetMaxLetters(3)
            local function applyPos()
                local v = tonumber(box:GetText())
                local stop = cur().stops[i]
                if v and stop then stop.pos = math.max(0, math.min(100, math.floor(v))) end
                box:SetText(stop and tostring(stop.pos) or "")
                box:ClearFocus()
                changed()
            end
            box:SetScript("OnEnterPressed", applyPos)
            box:HookScript("OnEditFocusLost", applyPos)
            label(row, "%", "GameFontHighlight"):SetPoint("LEFT", box, "RIGHT", 4, 0)
            local spare = { 1, 1, 1, 1 } -- rows past the last point still refresh
            swatch(row, "Point " .. i, 62, 0, function() return cur().stops[i] and cur().stops[i].color or spare end)
            local del = button(row, "Delete", 64, 210, 0, function()
                table.remove(cur().stops, i)
                changed()
            end)
            row.box, row.del = box, del
            f.rows[i] = row
        end
        f.add = button(f, "Add point", 100, 16, -50 - MAX_STOPS * 26, function()
            local stops = cur().stops
            local last = stops[#stops]
            tinsert(stops, { pos = last and last.pos or 100, color = { 1, 1, 1, 1 } })
            changed()
        end)
        onRefresh(function()
            if not f:IsShown() then return end
            local stops = cur().stops
            for i, row in ipairs(f.rows) do
                row:SetShown(stops[i] ~= nil)
                if stops[i] then
                    if not row.box:HasFocus() then row.box:SetText(tostring(stops[i].pos)) end
                    row.del:SetShown(#stops > 2)
                end
            end
            f.add:SetShown(#stops < MAX_STOPS)
            f.title:SetText("Gradient points: " .. BARS[selected].label)
        end)
        stopsFrame = f
    end
    f:Show()
    changed()
end

local function buildConfig()
    cfg = CreateFrame("Frame", "WolfpackAddonConfig", UIParent, "BasicFrameTemplateWithInset")
    cfg:SetSize(990, 700)
    cfg:SetPoint("CENTER")
    cfg:SetFrameStrata("DIALOG")
    cfg:SetMovable(true)
    cfg:EnableMouse(true)
    cfg:RegisterForDrag("LeftButton")
    cfg:SetScript("OnDragStart", cfg.StartMoving)
    cfg:SetScript("OnDragStop", cfg.StopMovingOrSizing)
    tinsert(UISpecialFrames, cfg:GetName()) -- Escape closes it
    cfg:HookScript("OnShow", function() ns.configOpen = true; changed() end)
    cfg:HookScript("OnHide", function() ns.configOpen = false; changed() end)
    label(cfg, "Wolfpack Addon"):SetPoint("TOP", 0, -5)

    -- Top row: profile (account-wide, holds every page)
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
        StaticPopup_Show("WOLFPACKADDON_DELETE", name, nil, name)
    end)
    button(cfg, "Reset profile", 92, 570, -33, function()
        wipe(db)
        merge(db, DEFAULTS)
        place()
        changed()
    end)
    button(cfg, "Export", 64, 668, -33, function() openIO("export") end)
    button(cfg, "Import", 64, 738, -33, function() openIO("import") end)

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
    barsPage:SetSize(846, 700) -- height is set once every page is built
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

    local tabNote = label(barsPage, "", "GameFontDisableSmall")
    tabNote:SetPoint("TOPLEFT", 252, -74)
    onRefresh(function()
        tabNote:SetText(mode == "regular" and "Health, power and combo bars on your screen."
            or "Bars under your target's nameplate. Needs enemy nameplates on (V key).")
    end)

    -- Four columns of boxes; a box's rows are stacked by g:row(height).
    local COL, TOP = { 8, 218, 428, 638 }, -100
    local ROW, SLIDER, DROP, SWATCH, BUTTON = 24, 44, 48, 26, 26

    -- Bars page, column 1: which bars, and where the group sits
    local bars = group(barsPage, COL[1], TOP, 202, "Bars, top to bottom")
    for i = 1, #db.regular.order do
        local y = bars:row(ROW)
        local sel = button(barsPage, "", 96, bars.x, y, function() selected = L().order[i]; changed() end)
        button(barsPage, "Up", 34, bars.x + 100, y, function() move(i, -1) end)
        button(barsPage, "Down", 44, bars.x + 136, y, function() move(i, 1) end)
        onRefresh(function()
            local key = L().order[i]
            sel:SetText(BARS[key].label)
            if key == selected then sel:LockHighlight() else sel:UnlockHighlight() end
        end)
    end
    slider(barsPage, "Gap between bars", bars.x, bars:row(SLIDER), 0, 30,
        function() return L().gap end, function(v) L().gap = v end)
    bars:close()

    local grp = group(barsPage, COL[1], bars.cursor - 20, 202, "Group position")
    local groupNote = label(barsPage, "", "GameFontDisableSmall")
    groupNote:SetPoint("TOPLEFT", grp.x, grp:row(16))
    onRefresh(function()
        groupNote:SetText((L().grow == "up" and "bottom-center" or "top-center")
            .. (mode == "regular" and ", from the screen center" or ", from under the nameplate"))
    end)
    local grow = button(barsPage, "", 186, grp.x, grp:row(BUTTON), function()
        L().grow = L().grow == "up" and "down" or "up"
        place()
        changed()
    end)
    onRefresh(function() grow:SetText("Grows: " .. (L().grow == "up" and "Upwards" or "Downwards")) end)
    local function xr() return mode == "regular" and math.floor(UIParent:GetWidth() / 2) or 200 end
    local function yr() return mode == "regular" and math.floor(UIParent:GetHeight() / 2) or 200 end
    slider(barsPage, "X (left / right)", grp.x, grp:row(SLIDER), function() return -xr() end, xr,
        function() return L().x end, function(v) L().x = v; place() end)
    slider(barsPage, "Y (down / up)", grp.x, grp:row(SLIDER), function() return -yr() end, yr,
        function() return L().y end, function(v) L().y = v; place() end)
    local lock = button(barsPage, "", 96, grp.x, grp:row(BUTTON), function() db.locked = not db.locked; changed() end)
    onRefresh(function()
        lock:SetShown(mode == "regular")
        lock:SetText(db.locked and "Unlock" or "Lock")
    end)
    grp:close()
    label(barsPage, "Mouse wheel on a slider changes it by 1.", "GameFontDisableSmall")
        :SetPoint("TOPLEFT", grp.x, grp.cursor - 24)

    -- Column 2: the selected bar's size and spacing
    local function selFrame() return (mode == "regular" and frames or plateFrames)[selected] end
    local size = group(barsPage, COL[2], TOP, 202, "")
    onRefresh(function()
        local shown = selFrame():IsShown()
        size.title:SetText(BARS[selected].label .. (shown and "" or " |cff888888(hidden)|r"))
    end)
    check(barsPage, "Show", size.x, size:row(ROW), function() return cur().show end, function(v) cur().show = v end)
    slider(barsPage, "Width", size.x, size:row(SLIDER), 10, 600, function() return cur().width end, function(v) cur().width = v end)
    slider(barsPage, "Height", size.x, size:row(SLIDER), 2, 100, function() return cur().height end, function(v) cur().height = v end)
    slider(barsPage, "Extra space above", size.x, size:row(SLIDER), 0, 60,
        function() return cur().padTop end, function(v) cur().padTop = v end)
    slider(barsPage, "Extra space below", size.x, size:row(SLIDER), 0, 60,
        function() return cur().padBottom end, function(v) cur().padBottom = v end)
    slider(barsPage, "Offset X", size.x, size:row(SLIDER), -300, 300, function() return cur().x end, function(v) cur().x = v end)
    slider(barsPage, "Offset Y", size.x, size:row(SLIDER), -300, 300, function() return cur().y end, function(v) cur().y = v end)
    size:close()

    local only = group(barsPage, COL[2], size.cursor - 20, 202, "Just for this bar")
    local target = check(barsPage, "Target health beside it", only.x, only:row(ROW),
        function() return cur().target end, function(v) cur().target = v end)
    local swingChecks = {}
    for i, kind in ipairs(SWING_TYPES) do
        swingChecks[i] = check(barsPage, kind[2], only.x, only:row(0) - (i - 1) * ROW,
            function() return cur()[kind[1]] end, function(v) cur()[kind[1]] = v end)
    end
    local castIcon = check(barsPage, "Show spell icon", only.x, only:row(ROW),
        function() return cur().icon end, function(v) cur().icon = v end)
    local castSide = button(barsPage, "", 186, only.x, only:row(BUTTON), function()
        cur().iconSide = cur().iconSide == "right" and "left" or "right"
        changed()
    end)
    local onlyNote = label(barsPage, "", "GameFontDisableSmall")
    onlyNote:SetPoint("TOPLEFT", only.x, only:row(16))
    onRefresh(function()
        target:SetShown(selected == "health" and mode == "regular")
        for _, w in ipairs(swingChecks) do w:SetShown(selected == "swing") end
        castIcon:SetShown(selected == "castbar")
        castSide:SetShown(selected == "castbar" and cur().icon or false)
        castSide:SetText("Icon side: " .. (cur().iconSide == "right" and "Right" or "Left"))
        local none = not (selected == "castbar" or selected == "swing"
            or (selected == "health" and mode == "regular"))
        onlyNote:SetText(none and "Nothing extra for this one." or "")
    end)
    only:close()

    -- Column 3: colors and border
    local look = group(barsPage, COL[3], TOP, 202, "Colors")
    dropdown(barsPage, "Texture", look.x, look:row(DROP), TEXTURES, function() return cur().texture end,
        function(v) cur().texture = v end, texturePreview)
    dropdown(barsPage, "Bar color", look.x, look:row(DROP), function()
        local list = { { "Custom", "custom" }, { "Class color", "class" } }
        if selected == "power" then list[3] = { "Power type color", "power" } end
        return list
    end, function() return cur().colorMode end, function(v) cur().colorMode = v end, textPreview)
    swatch(barsPage, "Custom color", look.x, look:row(SWATCH), function() return cur().color end, {
        get = function() return cur().colorMode end, set = function(v) cur().colorMode = v end,
        effective = function() return barColors(selFrame(), cur()) end,
    })
    swatch(barsPage, "Background color", look.x, look:row(SWATCH), function() return cur().bgColor end)
    look:close()

    local bord = group(barsPage, COL[3], look.cursor - 20, 202, "Border")
    slider(barsPage, "Thickness", bord.x, bord:row(SLIDER), 0, 10,
        function() return cur().borderSize end, function(v) cur().borderSize = v end)
    dropdown(barsPage, "Color", bord.x, bord:row(DROP), { { "Custom", "custom" }, { "Class color", "class" },
        { "Same as bar color", "bar" } }, function() return cur().borderMode end, function(v) cur().borderMode = v end,
        textPreview)
    swatch(barsPage, "Custom border color", bord.x, bord:row(SWATCH), function() return cur().borderColor end, {
        get = function() return cur().borderMode end, set = function(v) cur().borderMode = v end,
        effective = function() return select(4, barColors(selFrame(), cur())) end,
    })
    dropdown(barsPage, "Corner radius", bord.x, bord:row(DROP), { { "None", 0 }, { "2 px", 2 }, { "4 px", 4 },
        { "8 px", 8 }, { "16 px", 16 }, { "32 px", 32 }, { "Pill (50% of height)", "pill" } },
        function() return cur().radius end, function(v) cur().radius = v end, textPreview)
    bord:close()

    -- Column 4: gradient and text
    local grad = group(barsPage, COL[4], TOP, 202, "Gradient")
    check(barsPage, "Gradient", grad.x, grad:row(ROW), function() return cur().gradient end,
        function(v) cur().gradient = v end)
    local DIRECTIONS = { { "right", "Left to right" }, { "left", "Right to left" },
        { "down", "Top to bottom" }, { "up", "Bottom to top" } }
    local dir = button(barsPage, "", 186, grad.x, grad:row(BUTTON), function()
        local i = 1
        for n, d in ipairs(DIRECTIONS) do
            if d[1] == cur().direction then i = n end
        end
        cur().direction = DIRECTIONS[i % #DIRECTIONS + 1][1]
        changed()
    end)
    local points = button(barsPage, "Gradient points...", 186, grad.x, grad:row(BUTTON), function() openStops() end)
    onRefresh(function()
        dir:SetShown(cur().gradient)
        points:SetShown(cur().gradient)
        for _, d in ipairs(DIRECTIONS) do
            if d[1] == cur().direction then dir:SetText("Direction: " .. d[2]) end
        end
    end)
    grad:close()

    local txt = group(barsPage, COL[4], grad.cursor - 20, 202, "Text")
    local textWidgets = {
        check(barsPage, "Show text", txt.x, txt:row(ROW), function() return cur().text end, function(v) cur().text = v end),
        dropdown(barsPage, "Font", txt.x, txt:row(DROP), FONTS, function() return cur().font end,
            function(v) cur().font = v end, fontPreview),
        slider(barsPage, "Size", txt.x, txt:row(SLIDER), 6, 32, function() return cur().fontSize end,
            function(v) cur().fontSize = v end),
        check(barsPage, "Outline", txt.x, txt:row(ROW), function() return cur().outline end, function(v) cur().outline = v end),
        swatch(barsPage, "Text color", txt.x, txt:row(SWATCH), function() return cur().textColor end),
    }
    local noText = label(barsPage, "", "GameFontDisableSmall")
    noText:SetPoint("TOPLEFT", txt.x, txt:row(16))
    onRefresh(function()
        for _, w in ipairs(textWidgets) do w:SetShown(selected ~= "combo") end
        noText:SetText(selected == "combo" and "Combo points show no text." or "")
    end)
    txt:close()

    -- Quest mobs page
    local qinfo = group(questPage, COL[1], TOP, 202, "Quest mobs")
    local desc = label(questPage, "Marks enemies you still need for a quest.\n\nSword: you need to kill it.\n"
        .. "Bag: it drops an item you need.\nGray: only groupmates still need it.\n\nThe icons sit in a row at "
        .. "the nameplate's top-right corner; a lone icon keeps to the row's left. Needs enemy nameplates on "
        .. "(V key).", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", qinfo.x, qinfo:row(186))
    desc:SetWidth(182)
    desc:SetJustifyH("LEFT")
    qinfo:close()

    local Q = function() return db.quest end
    local row = group(questPage, COL[1], qinfo.cursor - 20, 202, "Icon row")
    slider(questPage, "X (left / right)", row.x, row:row(SLIDER), -200, 200, function() return Q().x end,
        function(v) Q().x = v end)
    slider(questPage, "Y (down / up)", row.x, row:row(SLIDER), -200, 200, function() return Q().y end,
        function(v) Q().y = v end)
    slider(questPage, "Spacing", row.x, row:row(SLIDER), 0, 20, function() return Q().spacing end,
        function(v) Q().spacing = v end)
    row:close()

    for i, kind in ipairs({ { "kill", "Kill it (sword)" }, { "loot", "Drops a quest item (bag)" } }) do
        local function q() return db.quest[kind[1]] end
        local g = group(questPage, COL[i + 1], TOP, 202, kind[2])
        check(questPage, "Show", g.x, g:row(ROW), function() return q().show end, function(v) q().show = v end)
        dropdown(questPage, "Icon", g.x, g:row(DROP), QUEST_ICONS[kind[1]], function() return q().icon end,
            function(v) q().icon = v end, iconPreview)
        slider(questPage, "Size", g.x, g:row(SLIDER), 8, 64, function() return q().size end, function(v) q().size = v end)
        check(questPage, "Show how many are left", g.x, g:row(ROW), function() return q().count end,
            function(v) q().count = v end)
        g:close()
    end

    -- Other page, column 1: quests and merchants
    local quests = group(otherPage, COL[1], TOP, 202, "Quests")
    check(otherPage, "Auto-accept (Shift skips)", quests.x, quests:row(ROW),
        function() return db.other.autoAccept end, function(v) db.other.autoAccept = v end)
    check(otherPage, "Auto-complete (Shift skips)", quests.x, quests:row(ROW),
        function() return db.other.autoComplete end, function(v) db.other.autoComplete = v end)
    local qnote = label(otherPage, "Quests with a reward choice or a gold cost stay with you.",
        "GameFontDisableSmall")
    qnote:SetPoint("TOPLEFT", quests.x, quests:row(34))
    qnote:SetWidth(182)
    qnote:SetJustifyH("LEFT")
    quests:close()

    local merch = group(otherPage, COL[1], quests.cursor - 20, 202, "Merchants")
    check(otherPage, "Auto-sell junk (gray items)", merch.x, merch:row(ROW),
        function() return db.other.sellJunk end, function(v) db.other.sellJunk = v end)
    merch:close()

    local cfont = group(otherPage, COL[1], merch.cursor - 20, 202, "Combat text font")
    dropdown(otherPage, "Damage numbers", cfont.x, cfont:row(DROP), COMBAT_FONTS,
        function() return store.combatFont or "" end,
        function(v) store.combatFont = v ~= "" and v or nil end, combatFontPreview)
    local big = otherPage:CreateFontString(nil, "OVERLAY")
    big:SetPoint("TOPLEFT", cfont.x, cfont:row(40))
    onRefresh(function()
        if not big:SetFont(store.combatFont or DEFAULT_DAMAGE_FONT, 30, "OUTLINE") then
            big:SetFont(DEFAULT_DAMAGE_FONT, 30, "OUTLINE")
        end
        big:SetTextColor(unpack(DAMAGE_YELLOW))
        big:SetText("123")
    end)
    local restart = label(otherPage, "Needs a full game restart. Addon settings don't survive a restart on this "
        .. "beta yet, so it applies once Blizzard fixes that.", "GameFontDisableSmall")
    restart:SetPoint("TOPLEFT", cfont.x, cfont:row(46))
    restart:SetWidth(182)
    restart:SetJustifyH("LEFT")
    cfont:close()

    -- Other page, column 2: Blizzard's own frames
    local blizz = group(otherPage, COL[2], TOP, 202, "Blizzard frames")
    check(otherPage, "Hide player frame", blizz.x, blizz:row(ROW),
        function() return db.regular.hidePlayerFrame end, function(v) db.regular.hidePlayerFrame = v end)
    check(otherPage, "Hide cast bar", blizz.x, blizz:row(ROW),
        function() return db.regular.hideBlizzCastbar end, function(v) db.regular.hideBlizzCastbar = v end)
    check(otherPage, "Hide action bar gryphons", blizz.x, blizz:row(ROW),
        function() return db.other.hideGryphons end, function(v) db.other.hideGryphons = v end)
    check(otherPage, "Bag bar only with bags", blizz.x, blizz:row(ROW),
        function() return db.other.bagsOnOpen end, function(v) db.other.bagsOnOpen = v end)
    local bagNote = label(otherPage, "The bag bar attaches to the bags. Hiding applies out of combat.",
        "GameFontDisableSmall")
    bagNote:SetPoint("TOPLEFT", blizz.x, blizz:row(34))
    bagNote:SetWidth(182)
    bagNote:SetJustifyH("LEFT")
    blizz:close()

    local mouse = group(otherPage, COL[2], blizz.cursor - 20, 202, "Bar group mouse")
    check(otherPage, "Left-click: target yourself", mouse.x, mouse:row(ROW),
        function() return db.regular.playerTarget end, function(v) db.regular.playerTarget = v end)
    check(otherPage, "Right-click: player menu", mouse.x, mouse:row(ROW),
        function() return db.regular.playerMenu end, function(v) db.regular.playerMenu = v end)
    check(otherPage, "Mouseover macros", mouse.x, mouse:row(ROW),
        function() return db.regular.playerMouseover end, function(v) db.regular.playerMouseover = v end)
    check(otherPage, "Highlight on mouseover", mouse.x, mouse:row(ROW),
        function() return db.regular.highlight.show end, function(v) db.regular.highlight.show = v end)
    swatch(otherPage, "Highlight color", mouse.x, mouse:row(SWATCH), function() return db.regular.highlight.color end)
    slider(otherPage, "Highlight opacity (%)", mouse.x, mouse:row(SLIDER), 0, 100,
        function() return math.floor(db.regular.highlight.color[4] * 100 + 0.5) end,
        function(v) db.regular.highlight.color[4] = v / 100 end)
    local mnote = label(otherPage, "Click and mouseover options apply out of combat and block clicks through "
        .. "the bars. The highlight doesn't.", "GameFontDisableSmall")
    mnote:SetPoint("TOPLEFT", mouse.x, mouse:row(40))
    mnote:SetWidth(182)
    mnote:SetJustifyH("LEFT")
    mouse:close()

    -- Other page, column 3: show on mouseover only
    local hover = group(otherPage, COL[3], TOP, 202, "Show only on mouseover")
    for _, e in ipairs(HOVER_FRAMES) do
        check(otherPage, e[2], hover.x, hover:row(22),
            function() return db.other.hover[e[1]] end, function(v) db.other.hover[e[1]] = v or nil end)
    end
    local hnote = label(otherPage, "They fade in under the cursor, stay clickable and show while Edit Mode is "
        .. "open.", "GameFontDisableSmall")
    hnote:SetPoint("TOPLEFT", hover.x, hover:row(40))
    hnote:SetWidth(182)
    hnote:SetJustifyH("LEFT")
    hover:close()

    -- Other page, column 4: the in-combat icon
    local CI = function() return db.regular.combatIcon end
    local icon = group(otherPage, COL[4], TOP, 202, "In-combat icon")
    check(otherPage, "Show", icon.x, icon:row(ROW), function() return CI().show end, function(v) CI().show = v end)
    dropdown(otherPage, "Icon", icon.x, icon:row(DROP), COMBAT_ICONS, function() return CI().style end,
        function(v) CI().style = v end, function(button, item)
            local t = button:AttachTexture()
            t:SetSize(20, 20)
            setCombatArt(t, item[2])
            return beforeName(button, item, t, 20)
        end)
    dropdown(otherPage, "Attach to bar", icon.x, icon:row(DROP), function()
        local list = {}
        for _, key in ipairs(db.regular.order) do list[#list + 1] = { BARS[key].label, key } end
        return list
    end, function() return CI().bar end, function(v) CI().bar = v end, textPreview)
    slider(otherPage, "Size", icon.x, icon:row(SLIDER), 8, 64, function() return CI().size end, function(v) CI().size = v end)
    slider(otherPage, "X (from the bar's left)", icon.x, icon:row(SLIDER), -200, 200,
        function() return CI().x end, function(v) CI().x = v end)
    slider(otherPage, "Y (down / up)", icon.x, icon:row(SLIDER), -200, 200,
        function() return CI().y end, function(v) CI().y = v end)
    icon:close()

    ns.configHeight = -pageBottom + 24 -- what the tallest column needs
    local height = math.min(ns.configHeight, math.floor(UIParent:GetHeight()) - 40)
    cfg:SetHeight(height)
    barsPage:SetHeight(height)
end

function ns.ToggleConfig()
    if not db then return end
    if not cfg then buildConfig() end
    cfg:SetShown(not cfg:IsShown())
    if cfg:IsShown() then changed() end
end
WolfpackAddon_Toggle = ns.ToggleConfig -- addon compartment (retail only, Forever has none)

SLASH_WOLFPACKADDON1 = "/wolfpack"
SLASH_WOLFPACKADDON2 = "/wp"
SLASH_WOLFPACKADDON3 = "/cpd" -- the old name still works
SlashCmdList.WOLFPACKADDON = function() safe(ns.ToggleConfig) end

-- Minimap icon: left-click options, right-click lock/unlock, drag to move around the minimap.
-- ponytail: assumes a round minimap; square minimap addons would need corner math.
local mini = CreateFrame("Button", "WolfpackAddonMinimapButton", Minimap)
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
    GameTooltip:AddLine("Wolfpack Addon")
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

-- Auto-complete: hand in the items and take the reward. Several rewards to choose from, or a
-- gold cost, stay with you.
local function autoComplete(event)
    if not db.other.autoComplete or IsShiftKeyDown() then return end
    if event == "QUEST_PROGRESS" then
        if IsQuestCompletable() then CompleteQuest() end
    elseif event == "QUEST_COMPLETE" then
        local choices = GetNumQuestChoices()
        if choices <= 1 and (GetQuestMoneyToGet() or 0) == 0 then GetQuestReward(choices) end
    end
end

-- An NPC's quest list (gossip window, or the old multi-quest greeting): turn in what's finished,
-- then take the next quest, one per opening. Trainer, vendor and other gossip options are never
-- touched. `picked` stops a window that reopens from looping on the same quest; it is dropped
-- when another NPC is used, or once the quest windows have been closed for a moment.
local picked, pickedFrom = {}, nil

local function npcQuests()
    if IsShiftKeyDown() then return end
    local guid = UnitGUID("npc")
    if guid ~= pickedFrom then
        wipe(picked)
        pickedFrom = guid
    end
    local function take(key, fn, ...)
        if picked[key] then return false end
        picked[key] = true
        fn(...)
        return true
    end
    if db.other.autoComplete then
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if q.isComplete and take("done" .. q.questID, C_GossipInfo.SelectActiveQuest, q.questID) then return end
        end
        for i = 1, GetNumActiveQuests() do
            if select(2, GetActiveTitle(i)) and take("greetDone" .. i, SelectActiveQuest, i) then return end
        end
    end
    if db.other.autoAccept then
        for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            if take("new" .. q.questID, C_GossipInfo.SelectAvailableQuest, q.questID) then return end
        end
        for i = 1, GetNumAvailableQuests() do
            if take("greetNew" .. i, SelectAvailableQuest, i) then return end
        end
    end
end

local swingTicker = CreateFrame("Frame")
ns.swingTicker = swingTicker
local swingShown = 0 -- which rows were up last tick; a change means the stack must re-flow
local function swingTick()
    local mask = 0
    for i, kind in ipairs(SWING_TYPES) do
        if swingActive(kind[3]) then mask = mask + 2 ^ (i - 1) end
    end
    if mask ~= swingShown then
        swingShown = mask
        safe(Refresh)
    else
        for _, set in pairs(swingFrames) do
            for _, f in ipairs(set) do
                if f:IsShown() then safe(fill, f) end
            end
        end
    end
    if not swingActive() then swingTicker:SetScript("OnUpdate", nil) end
end

local petEv = CreateFrame("Frame") -- same handler as ev, for pet unit events

-- Auto-sell junk: gray items that have a sell price, one every 0.2 s while the merchant window
-- is open. Nothing else is ever sold, and closing the window stops it.
local sellTicker
local function sellJunk()
    if sellTicker or not db.other.sellJunk then return end
    local poor = (Enum.ItemQuality and Enum.ItemQuality.Poor) or 0
    local queue, before = {}, GetMoney()
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == poor and not info.hasNoValue and not info.isLocked then
                queue[#queue + 1] = { bag, slot }
            end
        end
    end
    if #queue == 0 then return end
    local i = 0
    sellTicker = C_Timer.NewTicker(0.2, function(ticker)
        i = i + 1
        local item = queue[i]
        if item and MerchantFrame and MerchantFrame:IsShown() then
            C_Container.UseContainerItem(item[1], item[2])
            return
        end
        ticker:Cancel()
        sellTicker = nil
        C_Timer.After(0.5, function() -- the money arrives a moment after the last sale
            local earned = GetMoney() - before
            if earned > 0 then print("|cff33ff99Wolfpack Addon|r sold junk for " .. GetMoneyString(earned)) end
        end)
    end, #queue + 1)
end

local function stopSelling()
    if sellTicker then
        sellTicker:Cancel()
        sellTicker = nil
    end
end

local function fillShown(...)
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if frames[key]:IsShown() then safe(fill, frames[key]) end
        if plateFrames[key]:IsShown() then safe(fill, plateFrames[key]) end
    end
end

ev:SetScript("OnEvent", function(_, event, unit, arg2)
    if event == "ADDON_LOADED" then
        if unit == ADDON then applyCombatFont() end
    elseif event == "PLAYER_LOGIN" then
        -- ponytail: settings saved before profiles existed are dropped (the beta never loaded them anyway)
        store = type(WolfpackAddonDB) == "table" and WolfpackAddonDB.profiles and WolfpackAddonDB
            or { profiles = {}, chars = {} }
        WolfpackAddonDB = store
        store.minimapAngle = store.minimapAngle or 220
        classProfile, class = UnitClass("player")
        playerName = UnitName("player")
        charKey = playerName .. " - " .. GetRealmName()
        for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
            "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
            listen(e, "player")
        end
        listen("UNIT_HEALTH", "player", "target")
        listen("UNIT_MAXHEALTH", "player", "target")
        listen("UNIT_PET", "player") -- pet summoned, dismissed or swapped
        pcall(petEv.RegisterUnitEvent, petEv, "UNIT_HEALTH", "pet")
        pcall(petEv.RegisterUnitEvent, petEv, "UNIT_MAXHEALTH", "pet")
        for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_QUEST_LOG_CHANGED" }) do
            listen(e, "player")
        end
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
            "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED",
            "QUEST_DETAIL", "QUEST_ACCEPT_CONFIRM", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_GREETING",
            "PLAYER_REGEN_DISABLED", "PLAYER_SWING", "MERCHANT_SHOW", "MERCHANT_CLOSED", "GOSSIP_CLOSED" }) do
            listen(e)
        end
        inCombat = InCombatLockdown() -- a /reload mid-fight
        local mine = store.chars[charKey]
        useProfile(store.profiles[mine or ""] and mine or classProfile)
        placeMini()
    elseif event == "UNIT_HEALTH" then
        fillShown("health", "pethealth")
        if targetFrame:IsShown() then safe(fill, targetFrame) end
    elseif event == "UNIT_POWER_FREQUENT" then
        fillShown("power", "combo", "druidmana")
    elseif event:find("^UNIT_SPELLCAST_") then
        safe(Refresh) -- the cast bar joins or leaves the stack
    elseif event == "PLAYER_SWING" then -- unit, arg2 = duration, swing type
        swingState[arg2] = { start = GetTime(), duration = unit }
        swingTicker:SetScript("OnUpdate", swingTick)
        swingTick()
    elseif event == "MERCHANT_SHOW" then
        safe(sellJunk)
    elseif event == "MERCHANT_CLOSED" then
        stopSelling()
    elseif event == "QUEST_DETAIL" or event == "QUEST_ACCEPT_CONFIRM" then
        safe(autoAccept, event, unit) -- for QUEST_DETAIL the first arg is the quest-starting item
    elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        safe(autoComplete, event)
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        safe(npcQuests)
    elseif event == "GOSSIP_CLOSED" then -- walked away: let the same quests be offered again
        C_Timer.After(1, function()
            local busy = (GossipFrame and GossipFrame:IsShown()) or (QuestFrame and QuestFrame:IsShown())
            if not busy then pickedFrom = nil end
        end)
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        safe(questLogChanged)
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        safe(Refresh)
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        safe(questLogChanged) -- tooltips may have been secret during combat
        safe(Refresh)         -- and protected frames couldn't change
    else
        if event == "NAME_PLATE_UNIT_ADDED" then safe(plateAdded, unit) end
        if event == "NAME_PLATE_UNIT_REMOVED" then safe(plateRemoved, unit) end
        -- form, max, target or nameplate changes: re-layout (target change moves the nameplate bars)
        safe(Refresh)
    end
end)
petEv:SetScript("OnEvent", ev:GetScript("OnEvent"))
listen("ADDON_LOADED")
listen("PLAYER_LOGIN")
