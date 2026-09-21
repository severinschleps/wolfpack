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
-- them). Setting DAMAGE_TEXT_FONT and the CombatTextFont object covers the scrolling text the UI
-- draws; the numbers the engine floats over enemies come from the client's own font files.
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

-- The layout new profiles start from: an export string, read through the same checks as one you
-- paste in. `decodeExport` is defined with the import code; until then DEFAULTS are used.
local DEFAULT_PROFILE = "WPA1:7VlbaBxVGJ6JrZQgKtKHbZBiH5Q+2D54gTy0WTc7s5tZU5O2KUZZKCc7Z3aHzM6ZnjnTdINClQg+iH0TFIVetQpWBMH4IqXFavFuvSD0RQSltI87xU4e9Jy57WRmJ3sxhRIyD5uzM+f855/v+y/n25wqGhgpqgbPSDqoQ0MDBL6ba2zLHeFEhGWIXxUNNAdxoQaBRmpiBdVnkCRjS5XrQAfFCjDJDMCSAYk/w5xT9WqBIALrpkAfmWf9L4tbisgimqrDpiSrGFaIinQRq9UaEU2CDPPlk9S8hvDCUvbPx90rOeDzBjK51sTvFvdef2XrYnLgTszIXVgUTQ0Rc4EfuGtDcaaad+dzHHdrmCvNuBDsV+ch97Q3Dh/zJbbM/WouLPBL2SuB3c/eZNdb/AK1sJT9VXGvpezl4HY4pM95vuWaO/3GN+z6li8SeIRYGE4/LOkEYgVUYHkK4CokDF1MqSofkHbsJ4BY5ijA9I6sWiYnGUAeRYSgOie5b74HybBQsSi+dcGsobmmwAw3cw1OnFNlUsvoBbpkChkcZXxMQTphbzsosNG+Av0wy4V90vN7pw4e3Dk1VaBhwPjaOFZlG0KdNH2MIvtIbAcPJ55eXkAsDlEX9SqUm61NkktDtq55CEUG1322eqEogkYiwtJ3iEXYz/N/FM9tfjEy+OXCsfJ2+6IfYT0ylaAlpC6WE2GyUK480vJIUZpx2tKYEupA1W1KapIyLxBiNPkJ/mn3OXo5gWAQ4jEEP3GBeyGCoH8nnqPpFldgPUJySMVQi4pRiz7SzfKzY9KUODw97MO9KRkscWKS4RnPndf6yZ27Y0TY8Xxx623XPPBh4LYqTwz/3wM0/cBdyp5uhz/nZLedOMmvJaw3dMC61bZ6iPuw0P8VlPYr7SvH50FL+pH92XsjvBOP+3SLPXLRW7NYDVr+b/toW4uCU0X3JwY+xI5LjX6fBW45+tGV3aEtqBWk2z1iPsYW7VdlKGhQIakMJAEPqr/tIdVt+W9x0WoBm1qwJ5iOJ0Z4wuunIVz1DzGpjeDLwd3Gqd8GQ3JSG0FoaW0mQrw+xRPBO2730gsSp9C0bAiLU9te0M7S2qQg3o7jFOSrwBgQqhjNCTKa04sYVi0N4A9btyaoaGowxywTosMQ21KNGtaY8ZNe1wlA5flbT7SVVRH5FBNY3uk5KIi+kmI+bcw1hm/RFx33dvcgtidqtMRMundcrO0SswcIRVOnso4ik3mDBk1DgyIgGjAFk0KU2eq5mWc7eG6sC7c7TbjZ8Wi/2k+0D64Lt6RwW+EEm6bWMg/1JNe28I/2qtcGOhxd/URdzKTm5gos9SO0Bpax5IwcPfoS730WiBvfzV4kwUoMr5qwTGbS8hyK0NJLEmW238ESbue5j5aflpzsAx98HOVxVUSck7339WNOdvKHn7ru1HYn3O9zcZ9+suVLTpYnmCtIUwxQmaVfkV72eMnhw2jHPq8Z7yRECbgZWkuSz8k+duC51ebOGbl06SsnW/37mjvq46TVZ95s6kBNUvbZt032ObueOn/BGbl58x9n9/nzF2Kobz0wnYK6K/66qnRtFV+MiV3Hj59wstLlr52RB99+p6P6s9t3kz4zJuRtc6vrREvbukZcZYHSZ9p0/MFwXSTedg7u6cBBydeAULfsSabBRjV1fj7v1TO7oKHKLJRt8ZAFTXLG1WGcMKtq2ulQIFo6TXJWMoY4/t8vXF22uWjSHKaIDAgaQiRl7vfeXBHRtobPijUmQU+IdbWCkV2sq7paB8b7BfOQBTBsCgSDRrPgodT0HBln/gqg8Qx70eY4m+F6D7DcLKq6gigDzaB+jQOLoDyqGxok0HaXFnHDqNHKZ5fYs1ylAg1i5xUTv+c5TDXnI4JCXzaig3lW2Jjf9zPR6Z2XSjOgak5QOQ11e8yEmlay9NlAwDJmpotd1bm8u6A8CTGtTZSxPQDPQhytfAL7V6cATFn5Dw=="
-- Ready-made profiles, listed in the profile dropdown even before they exist.
local PRESETS = { { "Alpha", DEFAULT_PROFILE } }
local decodeExport
-- Declared up here because the code below closes over `db`: further down it would bind to a
-- global of the same name instead, which is always nil.
local store, db, class, charKey, classProfile

-- Called on ADDON_LOADED, before the world loads. Only known paths are accepted.
-- The font of the active profile, or — before a profile is loaded, which is when this matters
-- most — the one baked into the addon.
local function applyCombatFont()
    local pick = db and db.other and db.other.combatFont
    if pick == nil then -- no profile loaded yet: this is the load-time case that matters
        local data = decodeExport and decodeExport(DEFAULT_PROFILE)
        pick = data and data.combatFont
    end
    for _, f in ipairs(COMBAT_FONTS) do
        if pick and pick ~= "" and f[2] == pick then
            DAMAGE_TEXT_FONT = pick -- read by the engine at startup: the floating numbers
            -- The scrolling combat text is drawn from a font object, so that one can change now.
            if CombatTextFont and CombatTextFont.GetFont then
                local _, size, flags = CombatTextFont:GetFont()
                pcall(CombatTextFont.SetFont, CombatTextFont, pick, size or 25, flags)
            end
        end
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

-- Incoming heals come from a calculator object: it takes the secret numbers and hands the bar a
-- value it can draw, so nothing is read here either. The cost of the spell being cast is read
-- once per cast and only ever passed on.
local healCalc = CreateUnitHealPredictionCalculator and CreateUnitHealPredictionCalculator()
local castCost = { value = nil, have = false }

-- Only the cost of the power the bar is showing counts, and the number itself may be secret:
-- a plain flag says whether one was found.
function castCost:track(event, spellID)
    self.have = false
    if event ~= "UNIT_SPELLCAST_START" and event ~= "UNIT_SPELLCAST_CHANNEL_START" then return end
    local ptype = UnitPowerType("player")
    pcall(function()
        for _, cost in ipairs(C_Spell.GetSpellPowerCost(spellID) or {}) do
            if cost.type == ptype then self.value, self.have = cost.cost, true end
        end
    end)
end

-- The Shield bar fills to the size the shield had when it landed. That size can't be computed
-- from a secret, and the aura payload that would announce a new shield is secret through and
-- through -- even its isFullUpdate flag. What is readable is the clock and our own casts, so an
-- absorb change right after a cast of ours counts as a shield landing, and anything later counts
-- as damage eating it. A shield cast by someone else leaves the bar on its previous scale.
local absorb = { max = nil, have = false, castAt = 0 }
local ABSORB_CAST_WINDOW = 0.4

-- The Totems bar is one segment per element. Order and colors are per profile; these are the
-- game's slot numbers, which never move.
local TOTEM_SLOTS = { "Fire", "Earth", "Water", "Air" }

-- Everything about a totem's timer is secret, IsZero included: the duration object may only be
-- handed to the bar, never asked about. So the addon can't tell an empty slot from a full one,
-- which is why this bar stays in the stack instead of collapsing like the cast bar. An empty
-- slot's duration is zero, so its segment simply draws empty.
local function totemDuration(slot)
    local ok, d = pcall(GetTotemDuration, slot)
    if ok then return d end
end

local function layoutDefaults(show, x, y, gap, width, h1, h2, h3, h4, h5, h6, h7, h8, h9)
    local l = {
        x = x, y = y, gap = gap, grow = "down", -- "up": the group's bottom edge stays put instead
        order = { "health", "power", "combo", "druidmana", "castbar", "pethealth", "swing", "totems",
            "absorb" },
        bars = {
            health = barDefaults(show, width, h1, 0.2, 0.8, 0.2, show),
            power = barDefaults(show, width, h2, 1, 0.85, 0.1, show),
            combo = barDefaults(show, width, h3, 1, 0.3, 0.1, false),
            druidmana = barDefaults(show, width, h4, 0.2, 0.45, 1, false),
            castbar = barDefaults(show, width, h5, 1, 0.7, 0, true), -- text = spell name
            pethealth = barDefaults(show, width, h6, 0.3, 0.7, 0.3, show),
            swing = barDefaults(show, width, h7, 0.8, 0.8, 0.85, show), -- text = seconds left
            totems = barDefaults(show, width, h8, 0.6, 0.6, 0.6, false), -- colored per element instead
            absorb = barDefaults(false, width, h9, 0.9, 0.9, 0.7, true), -- text = points left
        },
    }
    l.bars.power.colorMode = "power"
    l.bars.castbar.icon, l.bars.castbar.iconSide = true, "left"
    l.bars.swing.main, l.bars.swing.off, l.bars.swing.ranged = true, false, false
    l.bars.health.heal, l.bars.health.healColor = false, { 0.4, 1, 0.5, 0.45 } -- incoming heals
    l.bars.power.cost, l.bars.power.costColor = false, { 1, 1, 1, 0.35 } -- what the cast will take
    l.bars.totems.slots = { 1, 2, 3, 4 } -- left to right: which totem slot each segment shows
    l.bars.totems.slotColors = { { 1, 0.3, 0.1, 1 }, { 0.5, 0.35, 0.2, 1 }, -- by slot, so a color
        { 0.2, 0.5, 1, 1 }, { 0.6, 0.5, 0.9, 1 } }                          -- sticks to its element
    return l
end

-- An aura's corner: the point it hangs from, and which way the next one in that corner grows.
local CORNERS = { { "topleft", "TOPLEFT", 1, -1 }, { "topright", "TOPRIGHT", -1, -1 },
    { "bottomleft", "BOTTOMLEFT", 1, 1 }, { "bottomright", "BOTTOMRIGHT", -1, 1 } }
local CORNER_BY_KEY = {}
for _, c in ipairs(CORNERS) do CORNER_BY_KEY[c[1]] = c end

-- The buffs each class can put on someone, listed by name so every rank matches, with one
-- spell ID each for the game's own icon.
local CLASS_BUFFS = {
    PRIEST = { { "Power Word: Shield", 17 }, { "Renew", 139 }, { "Power Word: Fortitude", 1243 },
        { "Divine Spirit", 14752 }, { "Shadow Protection", 976 }, { "Inner Fire", 588 },
        { "Fear Ward", 6346 }, { "Prayer of Fortitude", 21562 }, { "Prayer of Spirit", 27681 },
        { "Prayer of Shadow Protection", 27683 }, { "Levitate", 1706 }, { "Abolish Disease", 552 } },
    DRUID = { { "Rejuvenation", 774 }, { "Regrowth", 8936 }, { "Mark of the Wild", 1126 },
        { "Gift of the Wild", 21849 }, { "Thorns", 467 }, { "Abolish Poison", 2893 },
        { "Innervate", 29166 }, { "Nature's Grasp", 16689 }, { "Barkskin", 22812 } },
    PALADIN = { { "Blessing of Might", 19740 }, { "Blessing of Wisdom", 19742 },
        { "Blessing of Kings", 20217 }, { "Blessing of Salvation", 1038 }, { "Blessing of Light", 19977 },
        { "Blessing of Sanctuary", 20911 }, { "Blessing of Freedom", 1044 },
        { "Blessing of Protection", 1022 }, { "Blessing of Sacrifice", 6940 }, { "Divine Shield", 642 } },
    MAGE = { { "Arcane Intellect", 1459 }, { "Arcane Brilliance", 23028 }, { "Ice Barrier", 13031 },
        { "Mana Shield", 1463 }, { "Dampen Magic", 604 }, { "Amplify Magic", 1008 },
        { "Slow Fall", 130 }, { "Ice Block", 45438 } },
    SHAMAN = { { "Lightning Shield", 324 }, { "Earth Shield", 974 }, { "Water Walking", 546 },
        { "Water Breathing", 131 }, { "Stoneskin", 8071 }, { "Strength of Earth", 8075 } },
    WARLOCK = { { "Unending Breath", 5697 }, { "Detect Invisibility", 132 }, { "Demon Skin", 696 },
        { "Soulstone Resurrection", 20707 }, { "Shadow Ward", 6229 } },
    WARRIOR = { { "Battle Shout", 6673 }, { "Shield Wall", 871 }, { "Last Stand", 12975 },
        { "Berserker Rage", 18499 } },
    HUNTER = { { "Aspect of the Hawk", 13165 }, { "Aspect of the Cheetah", 5118 },
        { "Trueshot Aura", 19506 }, { "Mend Pet", 136 }, { "Rapid Fire", 3045 } },
    ROGUE = { { "Slice and Dice", 5171 }, { "Sprint", 2983 }, { "Evasion", 5277 }, { "Stealth", 1784 } },
}

-- What each class can take off someone, and the color the frame border turns when it can.
local DISPELS = {
    PRIEST = { Magic = true, Disease = true },
    PALADIN = { Magic = true, Poison = true, Disease = true },
    DRUID = { Curse = true, Poison = true },
    MAGE = { Curse = true },
    SHAMAN = { Poison = true, Disease = true },
    WARLOCK = { Magic = true }, -- the felhunter's Devour Magic
}
local DISPEL_TYPES = { "Magic", "Curse", "Poison", "Disease" }

-- One group-frame layout per group size. Frames grow in `grow`, wrapping after `perLine`.
local function groupDefaults(perLine, w, h, ph, y)
    return {
        show = true, test = false, x = 0, y = y, width = w, height = h, powerHeight = ph,
        gap = 2, perLine = perLine, grow = "right", -- "left", "down", "up"
        texture = TEXTURES[1][2], borderSize = 1, borderColor = { 0, 0, 0, 1 }, radius = 0,
        classColor = true, color = { 0.2, 0.6, 0.2, 1 }, bgColor = { 0, 0, 0, 0.6 },
        font = FONTS[1][2], fontSize = 10, outline = true, nameColor = { 1, 1, 1, 1 },
        role = true, roleSize = 12, roleX = 0, roleY = 0,
        pets = false, petHeight = 8,
    }
end

-- Quest mob icons on nameplates: a row (kill, then loot) whose top-right sits at the nameplate's
-- top-right corner plus x/y. Icons are file IDs.
local DEFAULTS = {
    locked = true,
    regular = layoutDefaults(true, 0, -120, 2, 220, 18, 14, 12, 6, 14, 10, 10, 10, 10),
    nameplate = layoutDefaults(false, 0, -2, 1, 110, 8, 6, 6, 4, 8, 5, 5, 5, 5),
    quest = {
        x = 0, y = 0, spacing = 2,
        kill = { show = true, icon = 131013, size = 20, count = false },
        loot = { show = true, icon = 131023, size = 20, count = false },
    },
    other = {
        hideGryphons = false, autoAccept = false, autoComplete = false, sellJunk = false,
        hover = {},         -- [key from HOVER_FRAMES] = true: that Blizzard element shows only on mouseover
        bagsOnOpen = false, -- bag bar only while bags are open, attached to them
        combatFont = "",    -- damage-number font; "" = WoW's own, picked on purpose
        minimap = { square = false, border = false, radius = 0, tray = false, trayBlizzard = false,
            infoBar = false, hideDayNight = false, x = 0, y = 0 },
        -- five-second-rule spinner: centered on a bar (or the group, if that bar is hidden) + x/y
        fsr = { show = false, bar = "power", size = 28, x = 0, y = 0, color = { 0.3, 0.6, 1, 0.7 },
            fill = true },
    },
}

-- Group frames: four layouts, plus the auras of yours that show on them.
DEFAULTS.group = {
    locked = true,
    party = groupDefaults(5, 90, 40, 4, 200),
    raid10 = groupDefaults(5, 80, 36, 3, 200),
    raid20 = groupDefaults(5, 74, 32, 3, 200),
    raid40 = groupDefaults(8, 64, 28, 3, 200),
    spells = {}, -- { id, corner, show }: which of your auras show, and where
    -- what a frame looks like under the cursor
    hover = { show = true, color = { 1, 1, 1, 0.15 }, border = true, borderColor = { 1, 1, 1, 0.8 } },
    -- border color when the unit has something you can take off
    dispel = { show = true, Magic = { 0.2, 0.5, 1, 1 }, Curse = { 0.65, 0.25, 0.95, 1 },
        Poison = { 0.2, 0.85, 0.25, 1 }, Disease = { 0.95, 0.6, 0.15, 1 } },
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
local changed, placeMini, useProfile, gf -- defined further down

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
    absorb = {
        label = "Shield",
        -- How much damage the absorb shields still swallow. The amount is secret like health is,
        -- so it can only be passed on, never read: `absorb.have` tracks whether a snapshot of the
        -- shield's full size exists, because testing the snapshot itself would be a read.
        state = function() return true, 1 end,
        value = function(unit)
            local ok, points = pcall(UnitGetTotalAbsorbs, unit)
            local max
            if unit == "player" and absorb.have then max = absorb.max else max = UnitHealthMax(unit) end
            return ok and points or 0, max
        end,
    },
    totems = {
        label = "Totems",
        state = function() return class == "SHAMAN", #TOTEM_SLOTS end,
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
            if f.key == "totems" then -- each segment wears its element's color
                local col = c.slotColors[c.slots[i]]
                paint(s, c, col[1], col[2], col[3], w, c.height)
            else
                paint(s, c, r, g, b, w, c.height)
            end
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
    -- Prediction overlay: incoming heals grow right from the health fill, a cast's cost grows
    -- left from the power fill. Both hang off the fill texture, so no value is ever read to
    -- place them, and the bar clips whatever runs past its edge.
    local over = (f.key == "health" and c.heal) or (f.key == "power" and c.cost)
    if over and n == 1 then
        local seg = f.segs[1]
        if not f.over then
            f.over = CreateFrame("StatusBar", nil, f)
            f:SetClipsChildren(true)
        end
        local o, col = f.over, f.key == "health" and c.healColor or c.costColor
        o:SetFrameLevel(seg:GetFrameLevel() + 1)
        o:SetStatusBarTexture(c.texture)
        o:SetStatusBarColor(col[1], col[2], col[3], col[4])
        o:SetSize(seg:GetWidth(), seg:GetHeight())
        o:ClearAllPoints()
        o:SetReverseFill(f.key == "power")
        o:SetPoint(f.key == "power" and "RIGHT" or "LEFT", seg:GetStatusBarTexture(),
            f.key == "power" and "RIGHT" or "RIGHT", 0, 0)
        o:Show()
    elseif f.over then
        f.over:Hide()
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

-- The overlay shares the bar's scale, so the same max goes in: incoming heals for health, the
-- cost of the cast in flight for power.
local function fillOverlay(f, max)
    f.over:SetMinMaxValues(0, max)
    if f.key == "power" then
        if castCost.have then f.over:SetValue(castCost.value) else f.over:SetValue(0) end
        return
    end
    if not healCalc then return f.over:SetValue(0) end
    local ok = pcall(function()
        healCalc:SetIncomingHealClampMode(0) -- 0 = stop at missing health, no overheal drawn
        healCalc:SetIncomingHealOverflowPercent(1.0)
        UnitGetDetailedHealPrediction(f.unit or "player", "player", healCalc)
        f.over:SetMinMaxValues(0, healCalc:GetMaximumHealth())
        f.over:SetValue(healCalc:GetIncomingHeals())
    end)
    if not ok then f.over:SetValue(0) end
end

local function fill(f)
    if f.key == "castbar" then return fillCast(f) end
    if f.key == "swing" then return fillSwing(f) end
    if f.key == "totems" then -- the bar drains itself from the duration object, in C
        local c = db[f.mode].bars[f.key]
        for i = 1, f.n do
            local d = totemDuration(c.slots[i])
            if d then
                f.segs[i]:SetTimerDuration(d, 0, TIMER_REMAINING)
            else -- no such API on this build: show a full bar while placing it, nothing otherwise
                f.segs[i]:SetMinMaxValues(0, 1)
                f.segs[i]:SetValue(ns.previewing() and 1 or 0)
            end
        end
        return
    end
    local v, max = BARS[f.key].value(f.unit or "player")
    if f.n == 1 then
        f.segs[1]:SetMinMaxValues(0, max)
        f.segs[1]:SetValue(v)
        if f.over and f.over:IsShown() then fillOverlay(f, max) end
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
local objectiveInfo = {} -- objective text without numbers -> { type, left } from your own quest log
local playerName

-- "Boar Flank: 2/6" and "2/6 Boar Flank" both become "BoarFlank".
local function bareText(text) return (text:gsub("[%d%p%s]", "")) end

local function scanQuestLog()
    wipe(objectiveInfo)
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                if o.text and not o.finished then
                    objectiveInfo[bareText(o.text)] = { type = o.type,
                        left = math.max((o.numRequired or 0) - (o.numFulfilled or 0), 0) }
                end
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
                local info = objectiveInfo[bareText(text)]
                local kind = (info and info.type == "item") and "loot" or "kill"
                -- your own quest log wins over the tooltip's player labels: if you still need it,
                -- the icon is yours (in a group the tooltip doesn't always name you)
                local isMine = own or info ~= nil
                if isMine then mine[kind] = true else party[kind] = true end
                local remaining
                if isMine and info then
                    remaining = info.left
                else
                    local have, need = text:match("(%d+)%s*/%s*(%d+)")
                    if have then remaining = need - have end
                end
                if remaining and remaining > 0 then -- several quests on one mob: the biggest count
                    left[kind] = math.max(left[kind] or 0, remaining)
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

-- Five-second rule: spending mana stops Spirit-based regen for five seconds. This spinner runs
-- for exactly that window. It's a cooldown swipe, so the animation happens in C and nothing about
-- it ever has to be read back.
local fsr = { classes = { DRUID = true, HUNTER = true, MAGE = true, PALADIN = true,
    PRIEST = true, SHAMAN = true, WARLOCK = true } }
fsr.frame = CreateFrame("Cooldown", nil, anchor, "CooldownFrameTemplate")
fsr.frame:SetHideCountdownNumbers(true)
fsr.frame:SetDrawEdge(false)
fsr.frame:SetDrawBling(false)
-- The swipe is masked to a ring texture, so it sweeps as a ring instead of a pie slice.
fsr.frame:SetSwipeTexture("Interface\\AddOns\\WolfpackAddon\\Media\\Ring")
fsr.frame:Hide()
ns.fsr = fsr

-- Spell costs are static data, but a pcall keeps a missing API (or a secret cost) from erroring:
-- when we can't tell, assume the cast cost mana.
function fsr.costsMana(spellID)
    local ok, mana = pcall(function()
        for _, cost in ipairs(C_Spell.GetSpellPowerCost(spellID) or {}) do
            if cost.type == PT.Mana then return true end
        end
        return false
    end)
    return (not ok) or mana
end

function fsr:on() return (db.other.fsr.show and self.classes[class]) and true or false end

function fsr:sync()
    local o = db.other.fsr
    local bar = frames[o.bar]
    local host = (bar and bar:IsShown()) and bar or anchor
    self.frame:SetParent(host)
    self.frame:SetFrameLevel(host:GetFrameLevel() + 20) -- over the bars, like the in-combat icon
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", host, "CENTER", o.x, o.y)
    self.frame:SetSize(o.size, o.size)
    self.frame:SetSwipeColor(o.color[1], o.color[2], o.color[3], o.color[4])
    self.frame:SetReverse(o.fill and true or false) -- fill up, or drain away
    if self:on() and ns.previewing() then
        self.frame:SetCooldown(GetTime(), 3600) -- a sweep too slow to see: a full ring, to place it
        self.endTime = nil
        self.frame:Show()
    else
        self.frame:SetShown(self:on() and (self.endTime or 0) > GetTime())
    end
end

-- In combat the window is the plain five-second rule; out of combat regen takes until the
-- seventh second to come back.
function fsr:start()
    if not self:on() then return end
    local seconds = inCombat and 5 or 7
    self.endTime = GetTime() + seconds
    self:sync()
    self.frame:SetCooldown(GetTime(), seconds)
    self.frame:Show()
    C_Timer.After(seconds, function() pcall(self.sync, self) end) -- safe() isn't defined yet
end

-- The window opens when the mana is paid: at cast start, or on success for an instant. A cast
-- that failed never paid, so it takes the spinner back down.
function fsr:cast(event, castGUID, spellID)
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if self.costsMana(spellID) then
            self.castID = castGUID
            self:start()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if castGUID ~= self.castID and self.costsMana(spellID) then self:start() end
    elseif event == "UNIT_SPELLCAST_FAILED" and castGUID == self.castID then
        self.endTime = nil
        self:sync()
    end
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

local mini = {} -- the minimap module: its state and helpers live in one table

-- Anything hung on the minimap must stay out of its layout, or Edit Mode's outline (and the
-- cluster's own sizing) grows around it. Blizzard's own day/night dial does the same.
local function ignoreLayout(f)
    f.ignoreInLayout = true
    return f
end
ns.mini = mini

------------------------------------------------------------------------------------------
-- Minimap: square shape, a 1 px mini.border, a mini.tray that collects the addon buttons around it, and
-- a bar underneath with the time, latency and coordinates.
------------------------------------------------------------------------------------------
mini.SQUARE_MASK, mini.ROUND_MASK = "Interface\\Buttons\\WHITE8X8", "ui-hud-minimap-frame-generic-mask"

-- The minimap's mask can't be nine-sliced, so it stretches to fit: Media/MinimapRound/m<N>.tga
-- are 128 px squares whose corner is N px, and the one whose corner ratio is closest to the
-- radius wanted on this minimap wins.
mini.MINIMAP_MASKS = { 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64 }
mini.MINIMAP_MASK_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\MinimapRound\\m"

function mini.roundedMaskFor(radius, size)
    local wanted, best, bestOff = radius / math.max(size, 1), mini.MINIMAP_MASKS[1], math.huge
    for _, r in ipairs(mini.MINIMAP_MASKS) do
        local off = math.abs(r / 128 - wanted)
        if off < bestOff then best, bestOff = r, off end
    end
    return mini.MINIMAP_MASK_DIR .. best .. ".tga"
end

function mini.minimapMask()
    local m = db.other.minimap
    if not m.square then return mini.ROUND_MASK end
    if m.radius == "round" then return mini.ROUND_MASK end
    if (m.radius or 0) <= 0 then return mini.SQUARE_MASK end
    return mini.roundedMaskFor(m.radius, Minimap:GetWidth())
end

mini.minimapDone = {} -- what we have already changed, so nothing is touched unless asked

function mini.minimapShape()
    local mask = mini.minimapMask()
    if mask == mini.minimapDone.mask then return end
    if not mini.minimapDone.mask and mask == mini.ROUND_MASK then return end -- default shape: leave it alone
    mini.minimapDone.mask = mask
    Minimap:SetMaskTexture(mask)
    if MinimapCompassTexture then -- the round frame art only fits the round mask
        MinimapCompassTexture:SetAlpha(mask == mini.ROUND_MASK and 1 or 0)
    end
end

-- The mini.border is a black plate behind the minimap, 1 px larger and cut to the same shape, so it
-- shows as an outline whatever the corners look like.
function mini.minimapBorder()
    local want = db.other.minimap.border and true or false
    if not mini.border then
        if not want then return end
        mini.border = ignoreLayout(CreateFrame("Frame", nil, MinimapCluster or UIParent))
        mini.border:SetFrameLevel(math.max(Minimap:GetFrameLevel() - 1, 0))
        mini.border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -1, 1)
        mini.border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 1, -1)
        mini.border.tex = mini.border:CreateTexture(nil, "BACKGROUND")
        mini.border.tex:SetAllPoints()
        mini.border.tex:SetColorTexture(0, 0, 0, 1)
        mini.border.mask = mini.border:CreateMaskTexture()
        mini.border.mask:SetAllPoints(mini.border.tex)
    end
    mini.border:SetShown(want)
    if not want then return end
    local mask = mini.minimapMask()
    if mask == mini.ROUND_MASK or mask == mini.SQUARE_MASK then
        if mini.border.masked then
            mini.border.tex:RemoveMaskTexture(mini.border.mask)
            mini.border.masked = nil
        end
        if mask == mini.ROUND_MASK then -- the round minimap brings its own frame art
            mini.border:Hide()
        end
    else
        mini.border.mask:SetTexture(mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if not mini.border.masked then
            mini.border.tex:AddMaskTexture(mini.border.mask)
            mini.border.masked = true
        end
    end
end

-- What the mini.tray leaves alone: the minimap's own parts and the mini.tray itself. Our own icon goes in
-- like any other addon's.
mini.TRAY_SKIP = { MinimapZoomIn = true, MinimapZoomOut = true, MinimapCompassTexture = true,
    MinimapBackdrop = true, MinimapCluster = true, WolfpackAddonTray = true,
    MinimapZoneTextButton = true, MinimapNorthTag = true, MinimapBorderTop = true }

mini.trayHeld = {} -- button -> { parent, points } so everything can go back
mini.strayText = {} -- loose counter font strings on the minimap, hidden while the mini.tray is on

-- A button's counter usually travels with it. One left behind on the minimap itself (a number
-- floating next to nothing) is hidden while the mini.tray is on, and shown again afterwards.
function mini.trayStrayText(hide)
    for _, holder in ipairs({ Minimap, MinimapCluster }) do
        for _, region in ipairs(holder and holder.GetRegions and { holder:GetRegions() } or {}) do
            if region:IsObjectType("FontString") and tonumber((region:GetText() or ""):match("^%s*(%d+)%s*$" ) or "") then
                if hide then
                    if mini.strayText[region] == nil then mini.strayText[region] = region:IsShown() end
                    region:Hide()
                elseif mini.strayText[region] ~= nil then
                    region:SetShown(mini.strayText[region])
                    mini.strayText[region] = nil
                end
            end
        end
    end
end

-- The mini.tray rides the minimap's edge: a circle when it's round, the square's edge when it's square
-- (the same angle, pushed out until it meets the side).
function mini.trayPlace()
    if not mini.tray then return end
    local angle = math.rad(store.trayAngle or 180)
    local x, y = math.cos(angle), math.sin(angle)
    if db.other.minimap.square then
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
    end
    local out = Minimap:GetWidth() / 2 + 6
    mini.tray:ClearAllPoints()
    mini.tray:SetPoint("CENTER", Minimap, "CENTER", x * out, y * out)
end

-- Minimap buttons are Buttons, but some are Frames carrying their own button and counter text;
-- anything named, mouse-enabled and icon-sized counts, so a counter travels with its icon.
function mini.trayWorthy(f)
    local name = f.GetName and f:GetName()
    if not name or mini.TRAY_SKIP[name] or not f.GetWidth then return false end
    local w = f:GetWidth() or 0
    if w < 12 or w > 48 then return false end
    return f:IsObjectType("Button") or (f.IsMouseEnabled and f:IsMouseEnabled())
end

function mini.trayCollect()
    local found = {}
    for _, parent in ipairs({ Minimap, MinimapBackdrop, MinimapCluster }) do
        for _, child in ipairs(parent and parent.GetChildren and { parent:GetChildren() } or {}) do
            if mini.trayWorthy(child) then found[#found + 1] = child end
        end
    end
    if db.other.minimap.trayBlizzard then
        for _, f in ipairs({ MinimapCluster and MinimapCluster.Tracking, GameTimeFrame }) do
            if f then found[#found + 1] = f end
        end
    end
    return found
end

-- Counters drawn on a collected icon are noise once it sits in the tray.
function mini.trayNumbers(f, hide, kept)
    for _, region in ipairs(f.GetRegions and { f:GetRegions() } or {}) do
        if region:IsObjectType("FontString") and tonumber((region:GetText() or ""):match("^%s*(%d+)%s*$") or "") then
            if hide then
                kept.numbers[region] = region:IsShown()
                region:Hide()
            elseif kept.numbers[region] ~= nil then
                region:SetShown(kept.numbers[region])
            end
        end
    end
end

function mini.trayRelease(f)
    local kept = mini.trayHeld[f]
    if not kept then return end
    mini.trayNumbers(f, false, kept)
    f:SetParent(kept.parent)
    f:SetFrameStrata(kept.strata)
    f:SetFrameLevel(kept.level)
    f:ClearAllPoints()
    for _, pt in ipairs(kept.points) do f:SetPoint(unpack(pt)) end
    mini.trayHeld[f] = nil
end

function mini.trayLayout()
    local held, cell = {}, 28
    for f in pairs(mini.trayHeld) do
        held[#held + 1] = f
        cell = math.max(cell, math.min((f:GetWidth() or 0) + 2, 48)) -- the biggest icon sets the grid
    end
    table.sort(held, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
    local perRow = math.min(math.max(#held, 1), 4)
    for i, f in ipairs(held) do
        f:ClearAllPoints()
        f:SetPoint("CENTER", mini.trayPanel, "TOPLEFT",
            6 + cell / 2 + ((i - 1) % 4) * cell, -6 - cell / 2 - math.floor((i - 1) / 4) * cell)
        f:SetFrameStrata("MEDIUM") -- the backdrop sits in BACKGROUND strata, so icons stay above it
        f:SetFrameLevel(mini.trayPanel:GetFrameLevel() + 2)
    end
    mini.trayPanel:SetSize(12 + perRow * cell, 12 + math.ceil(#held / 4) * cell)
    mini.trayPanel:SetShown(#held > 0 and mini.trayPanel.open or false)
    mini.trayBg:SetShown(mini.trayPanel:IsShown())
end

function mini.trayUpdate()
    local on = db.other.minimap.tray
    if not mini.tray then
        if not on then return end
        mini.tray = ignoreLayout(CreateFrame("Button", "WolfpackAddonTray", Minimap))
        mini.tray:SetSize(28, 28)
        mini.tray:SetFrameStrata("MEDIUM")
        mini.tray:SetFrameLevel(Minimap:GetFrameLevel() + 20) -- above the minimap and its mini.border
        local icon = mini.tray:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(133633) -- a bag: the mini.tray holds the other icons
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        mini.tray:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        mini.tray:RegisterForDrag("LeftButton")
        mini.tray:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local cx, cy = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale()
                store.trayAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
                mini.trayPlace()
            end)
        end)
        mini.tray:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
        mini.trayPanel = ignoreLayout(CreateFrame("Frame", nil, mini.tray))
        mini.trayPanel:SetPoint("TOPRIGHT", mini.tray, "TOPLEFT", -4, 0)
        mini.trayPanel:SetFrameStrata("MEDIUM")
        mini.trayPanel:Hide()
        -- the backdrop is its own frame in the lowest strata, so no icon can end up under it
        mini.trayBg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        mini.trayBg:SetFrameStrata("BACKGROUND")
        mini.trayBg:SetPoint("TOPLEFT", mini.trayPanel, "TOPLEFT")
        mini.trayBg:SetPoint("BOTTOMRIGHT", mini.trayPanel, "BOTTOMRIGHT")
        mini.trayBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1 })
        mini.trayBg:SetBackdropColor(0, 0, 0, 0.85)
        mini.trayBg:SetBackdropBorderColor(0, 0, 0, 1)
        mini.tray:SetScript("OnClick", function()
            mini.trayPanel.open = not mini.trayPanel.open
            mini.trayLayout()
        end)
    end
    mini.tray:SetShown(on)
    if on then
        mini.trayPlace()
        for _, f in ipairs(mini.trayCollect()) do
            if not mini.trayHeld[f] then
                local points = {}
                for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) } end
                mini.trayHeld[f] = { parent = f:GetParent(), points = points, numbers = {},
                    strata = f:GetFrameStrata(), level = f:GetFrameLevel() }
                mini.trayNumbers(f, true, mini.trayHeld[f])
                f:SetParent(mini.trayPanel)
            end
        end
    else
        for f in pairs(mini.trayHeld) do mini.trayRelease(f) end
        if mini.trayPanel then mini.trayPanel:Hide() end
    end
    mini.trayStrayText(on)
    if mini.trayPanel then mini.trayLayout() end
end
-- Two strips: the zone and coordinates above the minimap, the time and latency below it.
mini.blizzBars = {} -- Blizzard's zone text and clock, hidden while ours are up

function mini.makeBar(where)
    local bar = ignoreLayout(CreateFrame("Frame", nil, Minimap))
    bar:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", 0, 2)
    bar:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, 2)
    if where == "bottom" then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -2)
        bar:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -2)
    end
    bar:SetHeight(14)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    for _, side in ipairs({ { "left", "LEFT", 4 }, { "right", "RIGHT", -4 } }) do
        local fs = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint(side[2], side[3], 0)
        fs:SetJustifyH(side[2])
        bar[side[1]] = fs
    end
    return bar
end

function mini.minimapInfo()
    local on = db.other.minimap.infoBar
    if not mini.infoBar then
        if not on then return end
        mini.topBar, mini.infoBar = mini.makeBar("top"), mini.makeBar("bottom")
        mini.topBar.left:SetPoint("RIGHT", mini.topBar.right, "LEFT", -6, 0) -- a long zone name gets cut, not overlapped
        mini.topBar.left:SetJustifyH("LEFT")
        mini.topBar.left:SetWordWrap(false)
        mini.infoBar.next = 0
        mini.infoBar:SetScript("OnUpdate", function(self, elapsed)
            self.next = self.next - elapsed
            if self.next > 0 then return end
            self.next = 1
            self.left:SetText(date("%H:%M"))
            local _, _, _, world = GetNetStats()
            self.right:SetText((world or 0) .. " ms")
            mini.topBar.left:SetText(GetMinimapZoneText() or "")
            local map = C_Map.GetBestMapForUnit("player")
            local pos = map and C_Map.GetPlayerMapPosition(map, "player")
            local x, y
            if pos then x, y = pos:GetXY() end -- "and" would keep only the first return
            mini.topBar.right:SetText(x and string.format("%.1f, %.1f", x * 100, y * 100) or "--")
        end)
    end
    mini.infoBar:SetShown(on)
    mini.topBar:SetShown(on)
    -- Blizzard's own zone name and clock would sit on top of ours
    -- the zone text, its dark backing strip, and the clock
    for _, f in ipairs({ MinimapCluster and MinimapCluster.ZoneTextButton,
        MinimapCluster and MinimapCluster.BorderTop, TimeManagerClockButton }) do
        if type(f) == "table" and f.IsShown then
            if on then
                if mini.blizzBars[f] == nil then mini.blizzBars[f] = f:IsShown() end
                f:Hide()
            elseif mini.blizzBars[f] ~= nil then
                f:SetShown(mini.blizzBars[f])
                mini.blizzBars[f] = nil
            end
        end
    end
end

-- Forever's day/night dial in the minimap's corner (its own frame, not the calendar button).
function mini.minimapDayNight()
    local dial = MinimapCluster and MinimapCluster.DielFrame
    local hide = db.other.minimap.hideDayNight and true or false
    if type(dial) ~= "table" or not dial.Hide or hide == (mini.dayNightShown == false) then return end
    if hide then
        mini.dayNightShown = false
        dial:Hide()
    elseif mini.dayNightShown == false then
        mini.dayNightShown = nil
        dial:Show()
    end
end

-- Nudging the whole minimap, e.g. tighter into the screen corner. Its Edit Mode anchors are kept
-- and restored; Blizzard re-applies them on layout changes, and Refresh puts the offset back.
function mini.minimapOffset()
    local m = db.other.minimap
    local dx, dy = m.x or 0, m.y or 0
    if not MinimapCluster or (dx == 0 and dy == 0 and not mini.minimapAnchors) then return end
    if not mini.minimapAnchors then
        mini.minimapAnchors = {}
        for i = 1, MinimapCluster:GetNumPoints() do mini.minimapAnchors[i] = { MinimapCluster:GetPoint(i) } end
    end
    if dx == 0 and dy == 0 then -- back to where Edit Mode had it
        MinimapCluster:ClearAllPoints()
        for _, pt in ipairs(mini.minimapAnchors) do MinimapCluster:SetPoint(unpack(pt)) end
        mini.minimapAnchors = nil
        return
    end
    MinimapCluster:ClearAllPoints()
    for _, pt in ipairs(mini.minimapAnchors) do
        MinimapCluster:SetPoint(pt[1], pt[2], pt[3], (pt[4] or 0) + dx, (pt[5] or 0) + dy)
    end
end

function mini.syncMinimap()
    if not Minimap then return end
    mini.minimapShape()
    mini.minimapBorder()
    mini.trayUpdate()
    mini.minimapInfo()
    mini.minimapDayNight()
    mini.minimapOffset()
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
    gf.refresh()
    fsr:sync()
    syncHover()
    syncBags()
    mini.syncMinimap()
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
-- Group frames: one frame per party or raid member, health and power, your own auras in the
-- corners. Plain frames, not secure ones: they show what is going on, they are not click-cast
-- targets, which keeps them out of combat lockdown entirely.
------------------------------------------------------------------------------------------
gf = { frames = {}, pets = {}, bucket = "party" }
gf.anchor = CreateFrame("Frame", "WolfpackAddonGroupFrames", UIParent)
gf.anchor:SetSize(10, 10)
gf.anchor:SetMovable(true)
gf.anchor:SetClampedToScreen(true)
gf.anchor:RegisterForDrag("LeftButton")
gf.anchor:SetScript("OnDragStart", function(a) a:StartMoving() end)
gf.anchor:SetScript("OnDragStop", function(a)
    a:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    local cfg = db.group[gf.bucket]
    cfg.x = math.floor(a:GetCenter() - ux + 0.5)
    cfg.y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
    gf.place()
    changed()
end)
ns.gf = gf

-- Your class's buffs, added to the profile once so they can be ticked off in the options.
function gf.knownSpells()
    local list, seen = db.group.spells, {}
    for _, sp in ipairs(list) do if sp.name then seen[sp.name] = sp end end
    local mine = {}
    for _, e in ipairs(CLASS_BUFFS[class or ""] or {}) do
        local sp = seen[e[1]]
        if not sp then
            sp = { name = e[1], id = e[2], corner = "topleft", size = 14, show = false }
            list[#list + 1] = sp
        end
        sp.id = sp.id ~= 0 and sp.id or e[2]
        mine[#mine + 1] = sp
    end
    return mine
end

-- The icon the game uses for that spell, so it looks right even when the aura itself is secret.
function gf.spellIcon(sp)
    gf.icons = gf.icons or {}
    if gf.icons[sp.name] == nil then
        local ok, tex = pcall(function()
            return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sp.id))
                or GetSpellTexture(sp.id)
        end)
        gf.icons[sp.name] = (ok and tex) or 134400 -- a question mark, if the id is unknown here
    end
    return gf.icons[sp.name]
end

-- Which layout the current group calls for, and the units it holds.
function gf.pick()
    if ns.groupEdit and ns.previewing() then return ns.groupEdit end
    if not IsInRaid() then return "party" end
    local n = GetNumGroupMembers() or 0
    if n <= 10 then return "raid10" elseif n <= 20 then return "raid20" else return "raid40" end
end

local BUCKET_SIZE = { party = 5, raid10 = 10, raid20 = 20, raid40 = 40 }

function gf.units(key)
    local t, n = {}, BUCKET_SIZE[key]
    if key == "party" then
        t[1] = "player"
        for i = 1, n - 1 do t[i + 1] = "party" .. i end
    else
        for i = 1, n do t[i] = "raid" .. i end
    end
    return t
end

function gf.petUnit(key, i)
    if key ~= "party" then return "raidpet" .. i end
    return i == 1 and "pet" or ("partypet" .. (i - 1))
end

-- Secure unit buttons: the game turns the click into a target or the unit menu itself, and
-- @mouseover macros find them the same way they find Blizzard's raid frames. Attributes can
-- only be set out of combat, so anything set in combat waits for the fight to end.
function gf.make(parent)
    local f = CreateFrame("Button", nil, parent, "SecureUnitButtonTemplate")
    f:RegisterForClicks("AnyUp")
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.border = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.mask = newMask(f)
    f.health = CreateFrame("StatusBar", nil, f)
    f.power = CreateFrame("StatusBar", nil, f)
    f.name = f.health:CreateFontString(nil, "OVERLAY")
    f.name:SetPoint("CENTER")
    f.role = f:CreateTexture(nil, "OVERLAY")
    f.role:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
    f.ring = f:CreateTexture(nil, "OVERLAY", nil, -8) -- dispel ring, for frames with no border
    f.ring:Hide()
    f.hl = f:CreateTexture(nil, "OVERLAY", nil, -7)
    f.hlBorder = f:CreateTexture(nil, "OVERLAY", nil, -6)
    f.hl:Hide()
    f.hlBorder:Hide()
    f:SetScript("OnEnter", function(self) gf.hover(self, true) end)
    f:SetScript("OnLeave", function(self) gf.hover(self, false) end)
    f.icons = {}
    return f
end

-- Under the cursor, or your current target: an overlay in the chosen color and a border.
function gf.hover(f, on)
    local h = db.group.hover
    local lit = on or (f.unit and UnitIsUnit(f.unit, "target")) or false
    f.hl:SetShown((lit and h.show) and true or false)
    f.hlBorder:SetShown((lit and h.border) and true or false)
end

-- Hands the frame to the game: which unit it is, what a left and a right click do.
function gf.secure(f, unit)
    f.unit = unit
    -- Attributes are locked down in combat; PLAYER_REGEN_ENABLED refreshes and sets them then.
    if InCombatLockdown() then return end
    f:SetAttribute("unit", unit)
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    if not f.watched then
        pcall(RegisterUnitWatch, f) -- the game shows and hides it with the unit
        f.watched = true
    end
end

-- One aura icon: the spell's icon with a bar over it that drains with the aura.
function gf.icon(f, i, size)
    local ic = f.icons[i]
    if not ic then
        ic = CreateFrame("Frame", nil, f)
        ic.tex = ic:CreateTexture(nil, "ARTWORK")
        ic.tex:SetAllPoints()
        ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ic.bar = CreateFrame("StatusBar", nil, ic)
        ic.bar:SetAllPoints()
        ic.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        ic.bar:SetStatusBarColor(0, 0, 0, 0.45) -- a see-through sweep, the icon stays readable
        ic.bar:SetOrientation("VERTICAL")
        ic.bar:SetFrameLevel(ic:GetFrameLevel() + 1)
        f.icons[i] = ic
    end
    ic:SetSize(size, size)
    ic:SetFrameLevel(f.health:GetFrameLevel() + 2)
    return ic
end

-- Your own helpful auras, in the corners you picked for them. Every read is wrapped: on this
-- client an aura that is not whitelisted is secret, and touching its fields throws.
function gf.auras(f, cfg, unit)
    local want, used, n = {}, { 0, 0, 0, 0 }, 0
    for _, sp in ipairs(db.group.spells) do
        if sp.show then want[sp.name] = sp end -- by name, so every rank of it counts
    end
    for i = 1, 40 do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL|PLAYER")
        if not ok or not data then break end
        pcall(function()
            local sp = want[data.name]
            if not sp then return end
            local c, ci = CORNER_BY_KEY[sp.corner], 0
            for k, v in ipairs(CORNERS) do if v[1] == sp.corner then ci = k end end
            n = n + 1
            local ic = gf.icon(f, n, sp.size)
            ic.tex:SetTexture(gf.spellIcon(sp))
            ic:ClearAllPoints()
            ic:SetPoint(c[2], f, c[2], c[3] * (2 + used[ci] * (sp.size + 1)), c[4] * 2)
            used[ci] = used[ci] + 1
            local dur = select(2, pcall(C_UnitAuras.GetAuraDuration, unit, data.auraInstanceID))
            if dur then ic.bar:SetTimerDuration(dur, 0, TIMER_REMAINING) end
            ic:Show()
        end)
    end
    for i = n + 1, #f.icons do f.icons[i]:Hide() end
end

-- First name only, at most eight letters, counted in characters so an accented one isn't
-- cut in half.
function gf.shortName(unit)
    local name = UnitName(unit) or ""
    name = name:match("^[^%s%-]+") or name
    local out, n = "", 0
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if n >= 8 then break end
        out, n = out .. ch, n + 1
    end
    return out
end

-- A debuff you can take off turns the border its color: blue for magic, purple for a curse,
-- green for poison, orange for disease. Debuff data can be secret, so every read is wrapped.
function gf.dispel(f, cfg, unit)
    local can, found = DISPELS[class or ""], nil
    if can and db.group.dispel.show then
        for i = 1, 40 do
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
            if not ok or not data then break end
            pcall(function()
                local kind = data.dispelName
                if kind and can[kind] then found = kind end
            end)
            if found then break end
        end
    end
    local col = found and db.group.dispel[found]
    local t = math.min(cfg.borderSize, (cfg.height - 1) / 2, (cfg.width - 1) / 2)
    if col and t > 0 then -- there is a border already: recolor it
        f.border:SetColorTexture(col[1], col[2], col[3], col[4])
        f.ring:Hide()
    elseif col then -- no border on this layout: a ring around the frame instead
        f.ring:SetColorTexture(col[1], col[2], col[3], col[4])
        f.ring:Show()
    else
        f.border:SetColorTexture(unpack(cfg.borderColor))
        f.ring:Hide()
    end
end

-- Health, power, name, role and auras for one unit.
function gf.update(f, cfg, unit)
    if not UnitExists(unit) then
        f:Hide()
        return
    end
    f:Show()
    f.health:SetMinMaxValues(0, UnitHealthMax(unit))
    f.health:SetValue(UnitHealth(unit))
    local ptype = UnitPowerType(unit)
    f.power:SetMinMaxValues(0, UnitPowerMax(unit, ptype))
    f.power:SetValue(UnitPower(unit, ptype))
    f.name:SetText(gf.shortName(unit))
    local _, token = UnitClass(unit)
    local col = cfg.classColor and token and C_ClassColor.GetClassColor(token)
    if col then
        f.health:SetStatusBarColor(col.r, col.g, col.b)
    else
        f.health:SetStatusBarColor(cfg.color[1], cfg.color[2], cfg.color[3])
    end
    local role = cfg.role and UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        f.role:SetTexCoord(GetTexCoordsForRoleSmallCircle(role))
        f.role:Show()
    else
        f.role:Hide()
    end
    gf.auras(f, cfg, unit)
    gf.dispel(f, cfg, unit)
end

-- Size, colors and border of one frame; the same shape the bars use.
function gf.style(f, cfg)
    f:SetSize(cfg.width, cfg.height)
    local t = math.min(cfg.borderSize, (cfg.height - 1) / 2, (cfg.width - 1) / 2)
    local ph = math.max(math.min(cfg.powerHeight, cfg.height - 2 * t - 4), 0)
    f.health:ClearAllPoints()
    f.health:SetPoint("TOPLEFT", t, -t)
    f.health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -t, t + ph)
    f.health:SetStatusBarTexture(cfg.texture)
    f.power:ClearAllPoints()
    f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, 0)
    f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -t, t)
    f.power:SetStatusBarTexture(cfg.texture)
    f.power:SetShown(ph > 0)
    f.power:SetStatusBarColor(0.3, 0.4, 0.9)
    f.bg:SetColorTexture(unpack(cfg.bgColor))
    f.border:SetShown(t > 0)
    f.border:ClearAllPoints()
    f.border:SetPoint("TOPLEFT", -0, 0)
    f.border:SetPoint("BOTTOMRIGHT", 0, 0)
    f.border:SetColorTexture(unpack(cfg.borderColor))
    local radius = cfg.radius == "pill" and math.huge or cfg.radius
    round(f.bg, f.mask, radius, cfg.width, cfg.height)
    local flags = cfg.outline and "OUTLINE" or ""
    if not f.name:SetFont(cfg.font, cfg.fontSize, flags) then f.name:SetFont(FONTS[1][2], cfg.fontSize, flags) end
    f.name:SetTextColor(unpack(cfg.nameColor))
    f.ring:ClearAllPoints()
    f.ring:SetPoint("TOPLEFT", -1, 1)
    f.ring:SetPoint("BOTTOMRIGHT", 1, -1)
    local h = db.group.hover
    f.hl:SetAllPoints()
    f.hl:SetColorTexture(unpack(h.color))
    round(f.hl, f.mask, radius, cfg.width, cfg.height)
    f.hlBorder:ClearAllPoints()
    f.hlBorder:SetPoint("TOPLEFT", -1, 1)
    f.hlBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    f.hlBorder:SetColorTexture(unpack(h.borderColor))
    f.role:SetSize(cfg.roleSize, cfg.roleSize)
    f.role:ClearAllPoints()
    f.role:SetPoint("CENTER", f, "CENTER", cfg.roleX, cfg.roleY)
end

-- Where frame number i sits: along `grow`, wrapping to a new line every `perLine`.
function gf.spot(cfg, i)
    local line, at = math.floor((i - 1) / cfg.perLine), (i - 1) % cfg.perLine
    local dx, dy = cfg.width + cfg.gap, cfg.height + cfg.gap
    if cfg.grow == "right" then return at * dx, -line * dy end
    if cfg.grow == "left" then return -at * dx, -line * dy end
    if cfg.grow == "down" then return line * dx, -at * dy end
    return line * dx, at * dy -- "up"
end

function gf.place()
    local cfg = db.group[gf.bucket]
    gf.anchor:ClearAllPoints()
    gf.anchor:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
end

-- Builds, styles and fills every frame of the layout in use.
function gf.refresh()
    local key = gf.pick()
    gf.bucket = key
    local cfg = db.group[key]
    local preview = ns.previewing() or cfg.test
    local on = cfg.show and (IsInGroup() or preview) and true or false
    gf.anchor:SetShown(on)
    local dragging = not db.group.locked
    gf.anchor:EnableMouse(dragging)
    if not on then return end
    gf.place()
    gf.knownSpells()
    local units = gf.units(key)
    for i = 1, BUCKET_SIZE[key] do
        local f = gf.frames[i] or gf.make(gf.anchor)
        gf.frames[i] = f
        gf.style(f, cfg)
        if not InCombatLockdown() then f:EnableMouse(not dragging) end -- unlocked: the block drags
        f:ClearAllPoints()
        local x, y = gf.spot(cfg, i)
        f:SetPoint("TOPLEFT", gf.anchor, "TOPLEFT", x, y)
        local unit = units[i]
        if cfg.test and not UnitExists(unit) then unit = "player" end -- so they can be placed
        gf.secure(f, unit)
        gf.update(f, cfg, unit)
        gf.hover(f, false) -- re-lights it if this is the unit you have targeted
    end
    for i = BUCKET_SIZE[key] + 1, #gf.frames do gf.frames[i]:Hide() end
    -- Pets hang under the group as their own block.
    local rows = math.ceil(BUCKET_SIZE[key] / cfg.perLine)
    for i = 1, BUCKET_SIZE[key] do
        local f = gf.pets[i]
        if cfg.pets then
            f = f or gf.make(gf.anchor)
            gf.pets[i] = f
            local petCfg = setmetatable({ height = math.max(cfg.petHeight, 6), powerHeight = 0 }, { __index = cfg })
            gf.style(f, petCfg)
            gf.secure(f, gf.petUnit(key, i))
            f:ClearAllPoints()
            local x, y = gf.spot(cfg, i)
            f:SetPoint("TOPLEFT", gf.anchor, "TOPLEFT", x, y - rows * (cfg.height + cfg.gap) - cfg.gap)
            gf.update(f, petCfg, gf.petUnit(key, i))
        elseif f then
            f:Hide()
        end
    end
end

-- Group events come in for units we do not show, so the cheap move is a full refresh.
local gfEv = CreateFrame("Frame")
ns.gfEv = gfEv
gfEv:SetScript("OnEvent", function() safe(gf.refresh) end)
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER", "UNIT_AURA", "UNIT_NAME_UPDATE", "UNIT_PET", "PLAYER_ROLES_ASSIGNED",
    "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED" }) do
    pcall(gfEv.RegisterEvent, gfEv, e)
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
local function slider(parent, text, x, y, min, max, get, set, step)
    step = step or 1 -- whole numbers unless a caller wants finer
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetSize(130, 16) -- 130 + 12 + 40 fits a box's inner width
    s:SetPoint("TOPLEFT", x, y - 16)
    s:SetBackdrop(SLIDER_BACKDROP)
    s:SetOrientation("HORIZONTAL")
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:GetThumbTexture():SetSize(32, 32)
    s:SetMinMaxValues(num(min), num(max))
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true) -- wheel = +/-1 for exact values
    label(s, text, "GameFontNormalSmall"):SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
    local syncing
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        if not syncing and v ~= get() then set(v); changed() end
    end)
    s:SetScript("OnMouseWheel", function(_, d) s:SetValue(s:GetValue() + d * step) end)

    -- Typed value: Enter or clicking away applies it (clamped to the slider range), Escape cancels.
    local box = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
    box:SetSize(40, 20)
    box:SetPoint("LEFT", s, "RIGHT", 12, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(5) -- not SetNumeric: X/Y need a minus sign; tonumber() rejects the rest
    local function apply()
        local v = tonumber(box:GetText())
        if v then
            set(math.max(num(min), math.min(num(max), math.floor(v / step + 0.5) * step)))
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
    b.label = label(b, text)
    b.label:SetPoint("LEFT", b, "RIGHT", 6, 0)
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
    store.profiles[name] = merge(store.profiles[name] or ns.freshProfile(name), DEFAULTS)
    store.chars[charKey] = name
    db = store.profiles[name]
    applyCombatFont() -- the font travels with the profile
    place()
    changed()
end

-- Your profiles plus the ready-made ones you haven't used yet.
local function profileNames()
    local names, seen = {}, {}
    for name in pairs(store.profiles) do
        names[#names + 1] = name
        seen[name] = true
    end
    for _, preset in ipairs(PRESETS) do
        if not seen[preset[1]] then names[#names + 1] = preset[1] end
    end
    table.sort(names)
    return names
end

-- A name nobody is using yet: "Alpha", then "Alpha 2", "Alpha 3"...
local function freeName(base)
    local name, n = base, 2
    while store.profiles[name] do
        name, n = base .. " " .. n, n + 1
    end
    return name
end

-- New profiles start as a copy of the current one; a name already taken gets a number.
local function createProfile(name)
    name = strtrim(name or "")
    if name == "" then return end
    name = freeName(name)
    store.profiles[name] = merge({}, db)
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
    local data = { name = store.chars[charKey], profile = db, combatFont = db.other.combatFont }
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
        elseif k == "spells" then -- one entry per buff: { name, id, corner, size, show }
            out.spells = {}
            for _, sp in ipairs(type(v) == "table" and v or {}) do
                local name = type(sp) == "table" and sp.name
                local size = type(sp) == "table" and tonumber(sp.size) or 14
                if type(name) == "string" and name ~= "" and CORNER_BY_KEY[sp.corner] then
                    out.spells[#out.spells + 1] = { name = name:sub(1, 64), corner = sp.corner,
                        id = tonumber(sp.id) or 0, show = sp.show == true,
                        size = math.max(6, math.min(40, size == size and size or 14)) }
                end
            end
        elseif k == "slots" then -- a permutation of the totem slots, no gaps, no repeats
            local seen = {}
            out.slots = {}
            for _, n in ipairs(type(v) == "table" and v or {}) do
                if type(n) == "number" and def[n] and not seen[n] then
                    seen[n] = true
                    out.slots[#out.slots + 1] = n
                end
            end
            for i = 1, #def do
                if not seen[i] then out.slots[#out.slots + 1] = i end
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
        elseif type(v) == type(def) or (k == "radius" and (v == "pill" or v == "round")) then
            out[k] = v
        end
    end
    return out
end

-- The data inside an export string, or nil: shared by Import and the baked default profile.
decodeExport = function(text)
    local b64 = (text or ""):gsub("%s", ""):match("^WPA1:(.+)$") or (text or ""):match("^CPD1:(.+)$")
    if not b64 then return nil end
    local ok, data = pcall(function() return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(b64))) end)
    if ok and type(data) == "table" and type(data.profile) == "table" then return data end
end

-- A profile as it starts out: the ready-made one of that name, else the built-in layout, and
-- the plain defaults for anything those don't decode or don't set.
function ns.freshProfile(name)
    local from = DEFAULT_PROFILE
    for _, preset in ipairs(PRESETS) do
        if preset[1] == name then from = preset[2] end
    end
    local data = decodeExport(from)
    local prof = merge(data and sanitize(data.profile, DEFAULTS) or {}, DEFAULTS)
    for _, f in ipairs(COMBAT_FONTS) do -- strings from before the font moved into the profile
        if data and data.combatFont == f[2] and f[2] ~= "" then prof.other.combatFont = f[2] end
    end
    return prof
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
    local name = freeName(base)
    store.profiles[name] = sanitize(data.profile, DEFAULTS)
    for _, f in ipairs(COMBAT_FONTS) do -- older strings carried the font outside the profile
        if data.combatFont == f[2] and f[2] ~= "" then store.profiles[name].other.combatFont = f[2] end
    end
    useProfile(name)
    return name, type(data.editMode) == "string" and data.editMode or nil
end
ns.exportString, ns.editModeString, ns.importString = exportString, editModeString, importString
ns.useProfile = useProfile

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
        merge(db, ns.freshProfile(store.chars[charKey]))
        place()
        changed()
    end)
    button(cfg, "Export", 64, 668, -33, function() openIO("export") end)
    button(cfg, "Import", 64, 738, -33, function() openIO("import") end)

    -- Sidebar: one entry per module
    local SIDEBAR = { { "combat", "Combat Display", "regular" }, { "nameplates", "Nameplates", "nameplate" },
        { "group", "Group frames", "regular" }, { "other", "Other", "regular" } }
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
    local groupPage = CreateFrame("Frame", nil, cfg)
    groupPage:SetAllPoints(barsPage)

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
        title:SetText(section == "other" and "Other"
            or section == "group" and "Group frames" or "Combat Display")
        for _, t in ipairs(tabs) do t:SetShown(np) end
        barsPage:SetShown(section == "combat" or (np and sub == "bars"))
        questPage:SetShown(np and sub == "quest")
        otherPage:SetShown(section == "other")
        groupPage:SetShown(section == "group")
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
    -- Totems: one row per segment, in the order they appear, each with its element's color.
    local totemRows = {}
    local function moveTotem(i, d)
        local s, j = cur().slots, i + d
        if not s then return end -- another bar is selected; these rows are hidden
        if s[j] then
            s[i], s[j] = s[j], s[i]
            changed()
        end
    end
    for i = 1, #TOTEM_SLOTS do
        local y = only:row(0) - (i - 1) * ROW
        local sw = swatch(barsPage, "Totem " .. i, only.x, y, function()
            local c = cur()
            return c.slots and c.slotColors[c.slots[i]] or { 0, 0, 0, 1 } -- another bar is selected
        end)
        local up = button(barsPage, "Up", 34, only.x + 106, y, function() moveTotem(i, -1) end)
        local down = button(barsPage, "Down", 44, only.x + 142, y, function() moveTotem(i, 1) end)
        totemRows[i] = { sw, up, down }
        onRefresh(function()
            if cur().slots then sw.label:SetText(TOTEM_SLOTS[cur().slots[i]]) end
        end)
    end
    -- Health and power each get a prediction overlay, on the same rows as the totem list
    local healCheck = check(barsPage, "Show incoming heals", only.x, only:row(0), 
        function() return cur().heal end, function(v) cur().heal = v end)
    local healColor = swatch(barsPage, "Heal color", only.x, only:row(0) - ROW,
        function() return cur().healColor or { 0, 0, 0, 1 } end)
    local costCheck = check(barsPage, "Show the cast's cost", only.x, only:row(0),
        function() return cur().cost end, function(v) cur().cost = v end)
    local costColor = swatch(barsPage, "Cost color", only.x, only:row(0) - ROW,
        function() return cur().costColor or { 0, 0, 0, 1 } end)
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
        healCheck:SetShown(selected == "health")
        healColor:SetShown(selected == "health")
        costCheck:SetShown(selected == "power")
        costColor:SetShown(selected == "power")
        for _, w in ipairs(swingChecks) do w:SetShown(selected == "swing") end
        for _, row in ipairs(totemRows) do
            for _, w in ipairs(row) do w:SetShown(selected == "totems") end
        end
        castIcon:SetShown(selected == "castbar")
        castSide:SetShown(selected == "castbar" and cur().icon or false)
        castSide:SetText("Icon side: " .. (cur().iconSide == "right" and "Right" or "Left"))
        local none = not (selected == "castbar" or selected == "swing" or selected == "power"
            or selected == "health")
        onlyNote:SetText(selected ~= "totems" and none and "Nothing extra for this one." or "")
    end)
    only:row(28) -- room for the four totem rows, which sit over the other controls
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

    -- Other page, column 4: what the mouse does over the bars, and the regen spinner
    local mouse = group(otherPage, COL[4], TOP, 202, "Bar group mouse")
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

    -- Other page, column 3: combat text and the minimap
    local cfont = group(otherPage, COL[3], TOP, 202, "Combat text font")
    dropdown(otherPage, "Damage numbers", cfont.x, cfont:row(DROP), COMBAT_FONTS,
        function() return db.other.combatFont end,
        function(v) db.other.combatFont = v; applyCombatFont() end, combatFontPreview)
    local big = otherPage:CreateFontString(nil, "OVERLAY")
    big:SetPoint("TOPLEFT", cfont.x, cfont:row(40))
    onRefresh(function()
        local pick = db.other.combatFont
        if pick == "" then pick = DEFAULT_DAMAGE_FONT end
        if not big:SetFont(pick, 30, "OUTLINE") then
            big:SetFont(DEFAULT_DAMAGE_FONT, 30, "OUTLINE")
        end
        big:SetTextColor(unpack(DAMAGE_YELLOW))
        big:SetText("123")
    end)
    local restart = label(otherPage, "Changes the scrolling text at your character right away. The "
        .. "numbers floating over enemies are drawn by the game itself, which an addon can't reach: "
        .. "for those, copy the .ttf over Fonts\\SKURRI.TTF in your WoW folder and restart.",
        "GameFontDisableSmall")
    restart:SetPoint("TOPLEFT", cfont.x, cfont:row(46))
    restart:SetWidth(182)
    restart:SetJustifyH("LEFT")
    cfont:close()

    -- Other page, column 1: show on mouseover only
    local hover = group(otherPage, COL[1], merch.cursor - 20, 202, "Show only on mouseover")
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

    local CI = function() return db.regular.combatIcon end
    local icon = group(otherPage, COL[2], blizz.cursor - 20, 202, "In-combat icon")
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

    local look2 = group(otherPage, COL[3], cfont.cursor - 20, 202, "Minimap look")
    local MM = function() return db.other.minimap end
    check(otherPage, "Square shape", look2.x, look2:row(ROW), function() return MM().square end,
        function(v) MM().square = v end)
    check(otherPage, "1 px border", look2.x, look2:row(ROW), function() return MM().border end,
        function(v) MM().border = v end)
    dropdown(otherPage, "Corner radius", look2.x, look2:row(DROP), { { "None (square)", 0 }, { "4 px", 4 },
        { "8 px", 8 }, { "16 px", 16 }, { "32 px", 32 }, { "Round", "round" } },
        function() return MM().radius end, function(v) MM().radius = v end, textPreview)
    check(otherPage, "Hide day/night dial", look2.x, look2:row(ROW), function() return MM().hideDayNight end,
        function(v) MM().hideDayNight = v end)
    look2:close()

    local mm = group(otherPage, COL[3], look2.cursor - 20, 202, "Minimap tray and bars")
    check(otherPage, "Tray for addon icons", mm.x, mm:row(ROW), function() return MM().tray end,
        function(v) MM().tray = v end)
    check(otherPage, "Tray holds tracking + calendar", mm.x, mm:row(ROW),
        function() return MM().trayBlizzard end, function(v) MM().trayBlizzard = v end)
    slider(otherPage, "Tray position (%)", mm.x, mm:row(SLIDER), 0, 100,
        function() return math.floor(((store.trayAngle or 180) + 180) / 3.6 + 0.5) % 101 end,
        function(v) store.trayAngle = v * 3.6 - 180; mini.trayPlace() end)
    check(otherPage, "Info bars (zone, coords, time, ping)", mm.x, mm:row(ROW),
        function() return MM().infoBar end, function(v) MM().infoBar = v end)
    slider(otherPage, "Move X (left / right)", mm.x, mm:row(SLIDER), -1000, 1000,
        function() return MM().x end, function(v) MM().x = v end)
    slider(otherPage, "Move Y (down / up)", mm.x, mm:row(SLIDER), -1000, 1000,
        function() return MM().y end, function(v) MM().y = v end)
    local mmNote = label(otherPage, "Drag the tray icon around the minimap, or use the slider; click it to open.",
        "GameFontDisableSmall")
    mmNote:SetPoint("TOPLEFT", mm.x, mm:row(34))
    mmNote:SetWidth(182)
    mmNote:SetJustifyH("LEFT")
    mm:close()

    ----------------------------------------------------------------------------------
    -- Group frames page: one set of settings per group size, plus the aura list
    ----------------------------------------------------------------------------------
    ns.groupEdit = "party"
    local G = function() return db.group[ns.groupEdit] end
    local sizes = group(groupPage, COL[1], TOP, 202, "Group size")
    for _, e in ipairs({ { "party", "Party (5)" }, { "raid10", "Raid (10)" }, { "raid20", "Raid (20)" },
        { "raid40", "Raid (40)" } }) do
        local b = button(groupPage, e[2], 186, sizes.x, sizes:row(BUTTON), function()
            ns.groupEdit = e[1]
            changed()
        end)
        onRefresh(function()
            if ns.groupEdit == e[1] then b:LockHighlight() else b:UnlockHighlight() end
        end)
    end
    check(groupPage, "Show these frames", sizes.x, sizes:row(ROW), function() return G().show end,
        function(v) G().show = v end)
    check(groupPage, "Show without a group", sizes.x, sizes:row(ROW), function() return G().test end,
        function(v) G().test = v end)
    local glock = button(groupPage, "", 186, sizes.x, sizes:row(BUTTON), function()
        db.group.locked = not db.group.locked
        changed()
    end)
    onRefresh(function()
        glock:SetText(db.group.locked and "Locked (click to unlock)" or "Unlocked - drag them")
    end)
    slider(groupPage, "X (left / right)", sizes.x, sizes:row(SLIDER), -1200, 1200,
        function() return G().x end, function(v) G().x = v end)
    slider(groupPage, "Y (down / up)", sizes.x, sizes:row(SLIDER), -800, 800,
        function() return G().y end, function(v) G().y = v end)
    sizes:close()

    local shape = group(groupPage, COL[2], TOP, 202, "Frame shape")
    slider(groupPage, "Width", shape.x, shape:row(SLIDER), 30, 300, function() return G().width end,
        function(v) G().width = v end)
    slider(groupPage, "Height", shape.x, shape:row(SLIDER), 12, 200, function() return G().height end,
        function(v) G().height = v end)
    slider(groupPage, "Power bar height", shape.x, shape:row(SLIDER), 0, 30,
        function() return G().powerHeight end, function(v) G().powerHeight = v end)
    slider(groupPage, "Gap", shape.x, shape:row(SLIDER), 0, 30, function() return G().gap end,
        function(v) G().gap = v end)
    slider(groupPage, "Per row / column", shape.x, shape:row(SLIDER), 1, 40,
        function() return G().perLine end, function(v) G().perLine = v end)
    dropdown(groupPage, "Grows", shape.x, shape:row(DROP), { { "Right, then down", "right" },
        { "Left, then down", "left" }, { "Down, then right", "down" }, { "Up, then right", "up" } },
        function() return G().grow end, function(v) G().grow = v end, textPreview)
    check(groupPage, "Pet frames below", shape.x, shape:row(ROW), function() return G().pets end,
        function(v) G().pets = v end)
    slider(groupPage, "Pet frame height", shape.x, shape:row(SLIDER), 4, 40,
        function() return G().petHeight end, function(v) G().petHeight = v end)
    shape:close()

    local nm = group(groupPage, COL[1], sizes.cursor - 20, 202, "Name")
    dropdown(groupPage, "Name font", nm.x, nm:row(DROP), FONTS, function() return G().font end,
        function(v) G().font = v end, fontPreview)
    slider(groupPage, "Name size", nm.x, nm:row(SLIDER), 6, 24, function() return G().fontSize end,
        function(v) G().fontSize = v end)
    check(groupPage, "Outline", nm.x, nm:row(ROW), function() return G().outline end,
        function(v) G().outline = v end)
    swatch(groupPage, "Name color", nm.x, nm:row(SWATCH), function() return G().nameColor end)
    nm:close()

    local look3 = group(groupPage, COL[3], TOP, 202, "Colors and border")
    dropdown(groupPage, "Texture", look3.x, look3:row(DROP), TEXTURES, function() return G().texture end,
        function(v) G().texture = v end, texturePreview)
    check(groupPage, "Class colors", look3.x, look3:row(ROW), function() return G().classColor end,
        function(v) G().classColor = v end)
    swatch(groupPage, "Health color", look3.x, look3:row(SWATCH), function() return G().color end)
    swatch(groupPage, "Background", look3.x, look3:row(SWATCH), function() return G().bgColor end)
    slider(groupPage, "Border thickness", look3.x, look3:row(SLIDER), 0, 8,
        function() return G().borderSize end, function(v) G().borderSize = v end)
    swatch(groupPage, "Border color", look3.x, look3:row(SWATCH), function() return G().borderColor end)
    dropdown(groupPage, "Corner radius", look3.x, look3:row(DROP), { { "None (square)", 0 }, { "2 px", 2 },
        { "4 px", 4 }, { "8 px", 8 }, { "16 px", 16 }, { "Pill", "pill" } },
        function() return G().radius end, function(v) G().radius = v end, textPreview)
    look3:close()

    local hov = group(groupPage, COL[3], look3.cursor - 20, 202, "Highlights")
    local GH = function() return db.group.hover end
    check(groupPage, "Highlight overlay", hov.x, hov:row(ROW), function() return GH().show end,
        function(v) GH().show = v end)
    swatch(groupPage, "Overlay color", hov.x, hov:row(SWATCH), function() return GH().color end)
    slider(groupPage, "Overlay opacity (%)", hov.x, hov:row(SLIDER), 0, 100,
        function() return math.floor(GH().color[4] * 100 + 0.5) end,
        function(v) GH().color[4] = v / 100 end)
    check(groupPage, "Border", hov.x, hov:row(ROW), function() return GH().border end,
        function(v) GH().border = v end)
    swatch(groupPage, "Border color", hov.x, hov:row(SWATCH), function() return GH().borderColor end)
    -- The border also says what you could take off this unit, in the colors below.
    local GD = function() return db.group.dispel end
    check(groupPage, "Border on dispellable", hov.x, hov:row(ROW), function() return GD().show end,
        function(v) GD().show = v end)
    for _, kind in ipairs(DISPEL_TYPES) do
        swatch(groupPage, kind, hov.x, hov:row(SWATCH), function() return GD()[kind] end)
    end
    hov:close()


    -- Column 4: your class's buffs, ticked on or off, and the settings of the one you picked
    local aur = group(groupPage, COL[4], TOP, 202, "Your buffs")
    local pickedSpell = 1
    for i = 1, 12 do
        local y = aur:row(22)
        local row = CreateFrame("Button", nil, groupPage)
        row:SetSize(122, 20)
        row:SetPoint("TOPLEFT", aur.x + 26, y - 1)
        row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
        local icon = groupPage:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("TOPLEFT", aur.x + 4, y - 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local nameLbl = label(row, "", "GameFontHighlightSmall")
        nameLbl:SetPoint("LEFT", 2, 0)
        nameLbl:SetWidth(120)
        nameLbl:SetJustifyH("LEFT")
        local onBtn = check(groupPage, "", aur.x + 154, y + 2, function()
            local sp = ns.gf.knownSpells()[i]
            return sp and sp.show
        end, function(v)
            local sp = ns.gf.knownSpells()[i]
            if sp then sp.show = v end
        end)
        row:SetScript("OnClick", function() pickedSpell = i; changed() end)
        onRefresh(function()
            local sp = ns.gf.knownSpells()[i]
            row:SetShown(sp ~= nil)
            icon:SetShown(sp ~= nil)
            onBtn:SetShown(sp ~= nil)
            if not sp then return end
            icon:SetTexture(ns.gf.spellIcon(sp))
            nameLbl:SetText(sp.name)
            nameLbl:SetTextColor(1, 1, 1, sp.show and 1 or 0.45)
            if pickedSpell == i then row:LockHighlight() else row:UnlockHighlight() end
        end)
    end
    local aurNote = label(groupPage, "", "GameFontDisableSmall")
    aurNote:SetPoint("TOPLEFT", aur.x, aur:row(26))
    aurNote:SetWidth(182)
    aurNote:SetJustifyH("LEFT")
    onRefresh(function()
        aurNote:SetText(#ns.gf.knownSpells() == 0 and "No buffs listed for your class yet."
            or "Tick a buff to show it, click its name to set it up below.")
    end)
    aur:close()

    local one = group(groupPage, COL[4], aur.cursor - 20, 202, "The buff you picked")
    local S1 = function() return ns.gf.knownSpells()[pickedSpell] end
    local oneName = label(groupPage, "", "GameFontNormalSmall")
    oneName:SetPoint("TOPLEFT", one.x, one:row(18))
    local corner = button(groupPage, "", 186, one.x, one:row(BUTTON), function()
        local sp = S1()
        if not sp then return end
        for k, c in ipairs(CORNERS) do
            if c[1] == sp.corner then
                sp.corner = CORNERS[k % #CORNERS + 1][1]
                break
            end
        end
        changed()
    end)
    slider(groupPage, "Icon size", one.x, one:row(SLIDER), 6, 40,
        function() local sp = S1() return sp and sp.size or 14 end,
        function(v) local sp = S1() if sp then sp.size = v end end)
    onRefresh(function()
        local sp = S1()
        oneName:SetText(sp and sp.name or "")
        corner:SetText("Corner: " .. (sp and ({ topleft = "Top left", topright = "Top right",
            bottomleft = "Bottom left", bottomright = "Bottom right" })[sp.corner] or "-"))
    end)
    local oneNote = label(groupPage, "Several buffs in one corner line up away from it, and a spell "
        .. "the client keeps secret can't be read at all.", "GameFontDisableSmall")
    oneNote:SetPoint("TOPLEFT", one.x, one:row(30))
    oneNote:SetWidth(182)
    oneNote:SetJustifyH("LEFT")
    one:close()


    local rl = group(groupPage, COL[2], shape.cursor - 20, 202, "Role icon")
    check(groupPage, "Show role icon", rl.x, rl:row(ROW), function() return G().role end,
        function(v) G().role = v end)
    slider(groupPage, "Size", rl.x, rl:row(SLIDER), 6, 40, function() return G().roleSize end,
        function(v) G().roleSize = v end)
    slider(groupPage, "X (from the center)", rl.x, rl:row(SLIDER), -100, 100,
        function() return G().roleX end, function(v) G().roleX = v end)
    slider(groupPage, "Y (from the center)", rl.x, rl:row(SLIDER), -100, 100,
        function() return G().roleY end, function(v) G().roleY = v end)
    rl:close()

    local FS = function() return db.other.fsr end
    local spin = group(otherPage, COL[4], mouse.cursor - 20, 202, "Mana regen spinner")
    check(otherPage, "Show", spin.x, spin:row(ROW), function() return FS().show end,
        function(v) FS().show = v end)
    dropdown(otherPage, "Attach to bar", spin.x, spin:row(DROP), function()
        local list = {}
        for _, key in ipairs(db.regular.order) do list[#list + 1] = { BARS[key].label, key } end
        return list
    end, function() return FS().bar end, function(v) FS().bar = v end, textPreview)
    slider(otherPage, "Size", spin.x, spin:row(SLIDER), 8, 96, function() return FS().size end,
        function(v) FS().size = v end)
    local spinDir = button(otherPage, "", 186, spin.x, spin:row(BUTTON), function()
        FS().fill = not FS().fill
        changed()
    end)
    onRefresh(function() spinDir:SetText(FS().fill and "Ring: Fills up" or "Ring: Drains away") end)
    slider(otherPage, "X (left / right)", spin.x, spin:row(SLIDER), -200, 200,
        function() return FS().x end, function(v) FS().x = v end)
    slider(otherPage, "Y (down / up)", spin.x, spin:row(SLIDER), -200, 200,
        function() return FS().y end, function(v) FS().y = v end)
    swatch(otherPage, "Color", spin.x, spin:row(SWATCH), function() return FS().color end)
    local spinNote = label(otherPage, "Runs until Spirit regen is back: 5 s in combat, 7 s out of it. "
        .. "Mana classes only.", "GameFontDisableSmall")
    spinNote:SetPoint("TOPLEFT", spin.x, spin:row(28))
    spinNote:SetWidth(182)
    spinNote:SetJustifyH("LEFT")
    spin:close()

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
local miniBtn = ignoreLayout(CreateFrame("Button", "WolfpackAddonMinimapButton", Minimap))
miniBtn:SetSize(31, 31)
miniBtn:SetFrameStrata("MEDIUM")
miniBtn:SetFrameLevel(8)
miniBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local miniIcon = miniBtn:CreateTexture(nil, "BACKGROUND")
miniIcon:SetSize(20, 20)
miniIcon:SetPoint("TOPLEFT", 7, -5)
miniIcon:SetTexture("Interface\\Icons\\Ability_Rogue_Eviscerate")
local miniBorder = miniBtn:CreateTexture(nil, "OVERLAY")
miniBorder:SetSize(53, 53)
miniBorder:SetPoint("TOPLEFT")
miniBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

placeMini = function()
    local a, r = math.rad(store.minimapAngle), Minimap:GetWidth() / 2 + 10
    miniBtn:ClearAllPoints()
    miniBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

miniBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
miniBtn:RegisterForDrag("LeftButton")
miniBtn:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
        db.locked = not db.locked
        changed()
    else
        safe(ns.ToggleConfig)
    end
end)
miniBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        store.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
        placeMini()
    end)
end)
miniBtn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
miniBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Wolfpack Addon")
    GameTooltip:AddLine("Left-click: options", 1, 1, 1)
    GameTooltip:AddLine("Right-click: lock / unlock bars", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this icon", 1, 1, 1)
    GameTooltip:Show()
end)
miniBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

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

ev:SetScript("OnEvent", function(_, event, unit, arg2, arg3)
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
            "UNIT_SPELLCAST_SUCCEEDED",
            "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
            listen(e, "player")
        end
        listen("UNIT_HEALTH", "player", "target")
        listen("UNIT_MAXHEALTH", "player", "target")
        listen("UNIT_ABSORB_AMOUNT_CHANGED", "player")
        listen("UNIT_HEAL_PREDICTION", "player", "target")
        listen("UNIT_PET", "player") -- pet summoned, dismissed or swapped
        pcall(petEv.RegisterUnitEvent, petEv, "UNIT_HEALTH", "pet")
        pcall(petEv.RegisterUnitEvent, petEv, "UNIT_MAXHEALTH", "pet")
        for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_QUEST_LOG_CHANGED" }) do
            listen(e, "player")
        end
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
            "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED",
            "QUEST_DETAIL", "QUEST_ACCEPT_CONFIRM", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_GREETING",
            "PLAYER_REGEN_DISABLED", "PLAYER_SWING", "PLAYER_TOTEM_UPDATE", "MERCHANT_SHOW", "MERCHANT_CLOSED",
            "GOSSIP_CLOSED" }) do
            listen(e)
        end
        inCombat = InCombatLockdown() -- a /reload mid-fight
        local mine = store.chars[charKey]
        useProfile(store.profiles[mine or ""] and mine or classProfile)
        placeMini()
    elseif event == "UNIT_HEAL_PREDICTION" then
        fillShown("health")
        if targetFrame:IsShown() then safe(fill, targetFrame) end
    elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        if GetTime() - absorb.castAt <= ABSORB_CAST_WINDOW then -- our cast just put a shield up
            local ok, points = pcall(UnitGetTotalAbsorbs, "player")
            absorb.max, absorb.have = ok and points, ok
        end
        fillShown("absorb")
    elseif event == "UNIT_HEALTH" then
        fillShown("health", "pethealth")
        fillShown("absorb") -- max health scales it
        if targetFrame:IsShown() then safe(fill, targetFrame) end
    elseif event == "UNIT_POWER_FREQUENT" then
        fillShown("power", "combo", "druidmana")
    elseif event:find("^UNIT_SPELLCAST_") then
        if unit == "player" then
            safe(fsr.cast, fsr, event, arg2, arg3)
            safe(castCost.track, castCost, event, arg3)
            if event == "UNIT_SPELLCAST_SUCCEEDED" then absorb.castAt = GetTime() end
        end
        safe(Refresh) -- the cast bar joins or leaves the stack
    elseif event == "PLAYER_SWING" then -- unit, arg2 = duration, swing type
        swingState[arg2] = { start = GetTime(), duration = unit }
        swingTicker:SetScript("OnUpdate", swingTick)
        swingTick()
    elseif event == "PLAYER_TOTEM_UPDATE" then -- hand the new timers over; they run themselves
        fillShown("totems")
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
