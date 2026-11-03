-- Wolfpack Addon: stacked health / power / combo point / druid mana bars for WoW: Forever and
-- Midnight, plus quest mob icons (sword = kill, bag = drops an item) on nameplates.
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
-- our own, grayscale so the bar's color tints them (Media/Bar)
for _, n in ipairs({ "Smooth", "Gloss", "Soft", "Inset", "Stripes", "Grain" }) do
    TEXTURES[#TEXTURES + 1] = { n, "Interface\\AddOns\\" .. ADDON .. "\\Media\\Bar\\" .. n }
end

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
ns.TEXTURES = TEXTURES

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
local DEFAULT_PROFILE = "WPA1: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"
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
        borderSize = 0, borderColor = { 0, 0, 0, 1 }, borderMode = "bar", radius = 0, -- border: or "class", "custom"
        borderFrom = "shared", -- width and corner radius: the profile's shared ones, or "own" (the two above)
        borderTexture = "Interface\\Buttons\\WHITE8X8", -- with "own": the border's texture
        textureFrom = "shared", -- the profile's shared texture, or "own" (texture above)
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

local function layoutDefaults(show, x, y, gap, width, h1, h2, h3, h4, h5, h6, h7, h8, h9, h10)
    local l = {
        x = x, y = y, gap = gap, grow = "down", -- "up": the group's bottom edge stays put instead
        order = { "health", "enemyhealth", "tothealth", "power", "combo", "druidmana", "castbar", "targetcast", "pethealth",
            "swing", "totems", "absorb", "flight", "experience", "ammo" },
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
            flight = barDefaults(false, width, h10 or h5, 0.4, 0.7, 1, true), -- text = time left
            -- your experience to the next level; hideInCombat: gone while you fight
            experience = barDefaults(false, width, h2, 0.58, 0, 0.55, true),
            -- hunters: the ammo in your bags; filled as far as your quiver / ammo pouch is
            ammo = barDefaults(show, 60, h2, 0.67, 0.83, 0.45, true),
            -- the color is picked from what is being cast, so its own is only a fallback
            targetcast = barDefaults(false, width, h5, 0.8, 0.3, 0.3, true),
            -- your target's health; its resource (mana, rage...) always sits right under it
            enemyhealth = barDefaults(false, width, h1, 0.8, 0.25, 0.2, show),
            -- your target's target; it can hang below or right of enemy health instead of stacking
            tothealth = barDefaults(false, width, math.max(4, math.floor(h1 * 0.4)), 0.8, 0.25, 0.2, false),
        },
    }
    -- beside: right of your health bar, the two sharing its width and its height. The resource
    -- sits inside the health bar: width in percent of it, x/y from its bottom center.
    -- Health, power and enemy health: three numbers, each with its own switch, spot, size and
    -- color (the bar's font and outline). textsSet: useProfile has moved an older profile's text
    -- size and color onto "current" (once).
    for _, key in ipairs({ "health", "power", "enemyhealth", "experience" }) do
        local function num(show, anchor, x)
            return { show = show, anchor = anchor, x = x, y = 0, size = 10, color = { 1, 1, 1, 1 } }
        end
        l.bars[key].texts = { percent = num(false, "RIGHT", -4), current = num(true, "CENTER", 0),
            currentmax = num(false, "LEFT", 4) }
        l.bars[key].textsSet = false
    end
    local eh = l.bars.enemyhealth
    eh.beside, eh.resource = false, true
    eh.resHeight, eh.resWidth, eh.resX, eh.resY = math.max(2, math.floor(h1 / 4)), 90, 0, 3
    -- resPlace "inside": drawn over the bar at its point resPoint; "outside": hung on the bar's
    -- edge at resPoint (BOTTOM: underneath it, TOPLEFT: above its left end...)
    eh.resPlace, eh.resPoint = "inside", "BOTTOM"
    -- its own text switch, color and border; the rest of its look (texture, font...) is enemy health's
    eh.resHideText, eh.resBorderSize, eh.resBorderMode, eh.resBorderColor, eh.resRadius =
        false, 0, "bar", { 0, 0, 0, 1 }, 0
    eh.resColorMode, eh.resColor, eh.resHideEmpty = "power", { 0.2, 0.4, 1, 1 }, true -- "power" or "custom"
    -- level and name, inset in the bar; the level always wears the game's difficulty color
    eh.tagLevel, eh.tagName, eh.tagFont, eh.tagSize, eh.tagOutline = true, false, FONTS[1][2], 10, true
    eh.tagAnchor, eh.tagX, eh.tagY, eh.tagNameColor = "LEFT", 4, 0, { 1, 1, 1, 1 } -- tag*: the level's spot
    eh.nameAnchor, eh.nameX, eh.nameY = "LEFT", 28, 0
    eh.tagAttach = "free" -- the level: "free" on the bar, or "left"/"right"/"top"/"bottom" of the name
    -- a box behind each: color (with opacity), padding around the text, corner radius
    eh.tagBg = { show = false, color = { 0, 0, 0, 0.6 }, pad = 2, radius = 0 }
    eh.nameBg = { show = false, color = { 0, 0, 0, 0.6 }, pad = 2, radius = 0 }
    -- buffs and debuffs, on your health and on enemy health: each group sits in a spot of the bar
    -- or of the other group (anchorTo "bar" / "other", auraGroupGap apart), with its own nudge,
    -- icon size, corner radius and grid
    for _, key in ipairs({ "health", "enemyhealth" }) do
        local b = l.bars[key]
        b.buffs = { show = true, anchorTo = "bar", spot = "topleft", grow = "right", wrap = "auto", x = 0, y = 2, size = 20,
            radius = 0, cols = 8, rows = 1, max = 8, hideTimer = false, zoom = 8, lineEdge = "bottom" }
        b.debuffs = { show = true, anchorTo = "other", spot = "topleft", grow = "right", wrap = "auto", x = 0, y = 0, size = 24,
            radius = 0, cols = 8, rows = 2, max = 16, hideTimer = false, zoom = 8, lineEdge = "top" }
        b.auraGap, b.auraGroupGap, b.auraLineGap = 2, 4, 1
    end
    -- small icons on the bar: PvP flag (in one of a few looks) and drinking; centered on a
    -- point of the bar, nudged by x/y
    -- anchorTo: "bar", or "name" / "level" (then it sits outside that box, on the side of point).
    -- style "text": text instead of an icon, in the name's font and size, its own color.
    eh.pvpIcon = { show = true, style = "faction", anchorTo = "bar", point = "TOPLEFT", x = 0, y = 0, size = 20,
        text = "PvP", textColor = { 1, 0.25, 0.25, 1 } }
    -- drinking: the name reads "Drinking!" instead, flashing, in this color
    eh.drinking = { show = true, color = { 0.35, 0.75, 1, 1 } }
    eh.eating = { show = true, color = { 1, 0.8, 0.3, 1 } } -- ... and "Eating!" while it eats
    -- target of target: anchor "stack" (like any bar), "below" enemy health (the two then share
    -- enemy health's height: your health's while beside it) or "right" of it (its height, own
    -- width). It has enemy health's level and name, the name shown.
    -- your pet: anchor "stack", "below" your health (your health's width; enemy health beside you
    -- grows to match the two), or "left" / "right" of it (its height, own width)
    l.bars.pethealth.anchor = "stack"
    -- hunters: a dot on the pet bar in its happiness color, the ammo count on the power bar
    l.bars.pethealth.happy = { show = true, point = "LEFT", x = 6, y = 0, size = 8 }
    -- while you drink: a text of your own on the power bar (the bar's font)
    l.bars.power.drinkText = { show = true, text = "Drinking", point = "LEFT", x = 4, y = 0, size = 10,
        color = { 0.35, 0.75, 1, 1 } }
    -- ... and while you eat, the same on your health bar
    l.bars.health.eatText = { show = true, text = "Eating", point = "LEFT", x = 4, y = 0, size = 10,
        color = { 1, 0.8, 0.3, 1 } }
    -- the ammo bar: beside the power bar ("left" / "right": the two share its width) or in the stack
    l.bars.ammo.anchor, l.bars.ammo.colorMode, l.bars.ammo.hunterSet = "right", "class", false
    local tt = l.bars.tothealth
    tt.anchor, tt.width, tt.colorMode = "right", 90, "class"
    local function copy(v)
        if type(v) ~= "table" then return v end
        local t = {}
        for k, x in pairs(v) do t[k] = copy(x) end
        return t
    end
    for _, k in ipairs({ "tagLevel", "tagName", "tagFont", "tagSize", "tagOutline", "tagAnchor", "tagX", "tagY",
        "tagNameColor", "nameAnchor", "nameX", "nameY", "tagAttach", "tagBg", "nameBg", "drinking", "eating" }) do
        tt[k] = copy(eh[k])
    end
    tt.tagLevel, tt.tagName, tt.nameX = false, true, 4
    -- your health: a status icon (the combat icon in a fight, else rested while resting) and
    -- your own PvP flag
    -- resting: the Zzz icon, or your own text (bar's font and size, its own color), whose letters
    -- can fade in and out one after another
    l.bars.health.statusIcon = { show = true, style = "atlas", rested = true, point = "LEFT", x = -12, y = 0,
        size = 20, restStyle = "icon", restText = "Zzz", restColor = { 0.6, 0.8, 1, 1 }, restWave = true }
    l.bars.health.pvpIcon = { show = true, style = "faction", anchorTo = "bar", point = "TOPLEFT", x = 0, y = 0,
        size = 20, text = "PvP", textColor = { 1, 0.25, 0.25, 1 } } -- text: in the bar's font and size
    l.bars.power.colorMode = "power"
    -- source: "xp", "rep" (the faction you watch), "honor", or "auto" (experience, then the
    -- watched faction once you are at the top level)
    l.bars.experience.colorMode, l.bars.experience.hideInCombat = "experience", false
    l.bars.experience.source, l.bars.experience.hideAtMax = "xp", true
    l.bars.health.colorMode, l.bars.enemyhealth.colorMode, l.bars.castbar.colorMode = "health", "reaction", "cast"
    l.bars.druidmana.colorMode = "power"
    l.bars.castbar.icon, l.bars.castbar.iconSide = true, "left"
    l.bars.targetcast.icon, l.bars.targetcast.iconSide = true, "left"
    -- what your target is casting. "Auto color": one color each for a cast you cannot stop, a
    -- heal, and everything else. autoSet: useProfile has moved an older profile, which always
    -- colored by kind, onto auto (once, so picking another mode sticks)
    l.bars.targetcast.colorMode, l.bars.targetcast.autoSet = "auto", false
    l.bars.swing.main, l.bars.swing.off, l.bars.swing.ranged = true, false, false
    l.bars.health.heal, l.bars.health.healColor = false, { 0.4, 1, 0.5, 0.45 } -- incoming heals
    l.bars.power.cost, l.bars.power.costColor = false, { 1, 1, 1, 0.35 } -- what the cast will take
    l.bars.totems.slots = { 1, 2, 3, 4 } -- left to right: which totem slot each segment shows
    l.bars.totems.slotColors = { { 1, 0.3, 0.1, 1 }, { 0.5, 0.35, 0.2, 1 }, -- by slot, so a color
        { 0.2, 0.5, 1, 1 }, { 0.6, 0.5, 0.9, 1 } }                          -- sticks to its element
    return l
end

-- Holding a secret value is fine; testing one throws. This client can say which is which, so
-- ask before comparing anything that came out of an aura.
local function readable(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return true
end

-- Quest mob icons on nameplates, each on its own: anchorTo, an element of the nameplate (a key
-- of ns.questElement's list, or "other": the other quest icon); spot, a key of ns.QUEST_SPOTS;
-- then x/y. Icons are file IDs. The "how many left" number has a font, a color and a plate
-- behind it (bg color, radius, padding).
function ns.questIcon(icon, to, spot, x)
    return { show = true, icon = icon, size = 20, count = false, anchorTo = to, spot = spot, x = x, y = 0,
        font = FONTS[1][2], fontSize = 10, textColor = { 1, 1, 1, 1 }, bg = { 0, 0, 0, 0.8 }, radius = 0, pad = 2,
        -- the count's plate: where it sits on its icon (a QUEST_SPOTS key), nudged by countX / countY
        countSpot = "abovecenter", countX = 0, countY = 1 }
end
local DEFAULTS = {
    locked = true,
    regular = layoutDefaults(true, 0, -120, 2, 220, 18, 14, 12, 6, 14, 10, 10, 10, 10),
    -- the bag in the bar's top right corner, the sword left of it (alone, in the bag's place)
    quest = { kill = ns.questIcon(131013, "other", "left", -2), loot = ns.questIcon(131023, "bar", "inside", 0) },
    other = {
        hideGryphons = false, autoAccept = false, autoComplete = false, sellJunk = false,
        autoRepair = false,
        hover = {},         -- [key from HOVER_FRAMES] = true: that Blizzard element shows only on mouseover
        bagsOnOpen = false, -- bag bar only while bags are open, attached to them
        raidHover = { show = true, color = { 1, 1, 1, 0.2 } }, -- overlay on hovered party/raid frames
        combatFont = "",    -- damage-number font; "" = WoW's own, picked on purpose
        minimap = { square = false, border = false, radius = 0, tray = false, trayBlizzard = false,
            infoBar = false, hideDayNight = false, x = 0, y = 0 },
        -- five-second-rule spinner: centered on a bar (or the group, if that bar is hidden) + x/y
        -- regen: once the window is over, a pulsing full ring in regenColor while mana refills
        fsr = { show = false, bar = "power", size = 28, x = 0, y = 0, color = { 0.3, 0.6, 1, 0.7 },
            fill = true, regen = true, regenColor = { 0.3, 1, 0.5, 0.7 } },
    },
}

-- Our own nameplates: every nameplate gets an enemy health bar, set up like one on the Plates
-- tab. Only enemy health of this layout is used; show = Blizzard's plates are replaced. x / y:
-- the bar's center from the plate's center.
do
    local l = layoutDefaults(false, 0, 0, 2, 120, 10, 6, 6, 4, 8, 5, 5, 5, 5)
    local e = l.bars.enemyhealth
    e.tagName, e.tagLevel, e.tagSize = true, true, 9
    e.nameAnchor, e.nameX, e.nameY, e.tagAttach = "TOP", 0, 1, "right"
    e.resource, e.resPlace, e.resPoint, e.resWidth, e.resHeight, e.resX, e.resY = true, "outside", "BOTTOM", 100, 3, 0, -1
    e.buffs.show, e.debuffs.anchorTo, e.debuffs.spot, e.debuffs.size, e.debuffs.y = false, "bar", "topleft", 18, 16
    for _, t in pairs(e.texts) do t.show = false end
    l.bars.targetcast.show = true -- while the unit casts
    -- your target's plate: a stroke running round its health bar, centered on the border's line
    -- (the bar's edge without one) plus offset. length / thickness / glowSize in px; fade: the tail
    -- fades out; caps: round ends. Its color, speed (lap: seconds per round) and flashing follow the
    -- target: idle (not in combat), combat, aggro (in combat with you as its target)
    l.trail = { show = false, length = 15, thickness = 2, offset = 0, caps = true, fade = true,
        glow = true, glowSize = 6, glowAlpha = 0.6, flashRate = 3,
        states = { idle = { color = { 0.25, 1, 0.35, 1 }, lap = 4, flash = false },
            combat = { color = { 1, 0.2, 0.15, 1 }, lap = 1, flash = false },
            aggro = { color = { 1, 0.2, 0.15, 1 }, lap = 1, flash = true } } }
    DEFAULTS.plates = l
end

-- Bags: show = our window replaces Blizzard's. The look is the action bars' (size, gap, border,
-- corners, zoom); x / y: its bottom-right corner from the screen's. sort: shown sorted.
-- keyring: where the game has one, its button joins the bag bar and its keys show in our look
-- above it. side: the custom bags' strip left of the window; custom = { { name, preset, items =
-- { [itemID] = true (in) / false (kept out of the preset) } } }, a group each, in this order.
DEFAULTS.bags = { show = false, cols = 10, size = 36, gap = 4, sectionGap = 12, borderSize = 1,
    borderColor = { 0, 0, 0, 1 }, radius = 0, zoom = 8, quality = true, junk = true, sort = false,
    countSize = 11, font = FONTS[1][2], bg = { 0.05, 0.05, 0.06, 0.6 }, x = -60, y = 110,
    keyring = true, side = true, custom = {} }

-- Unit frames: your party or raid, a frame each, in a block with one side fixed. fixed "width":
-- `size` px wide, `per` frames a row, rows growing "down" / "up"; fixed "height": `size` px high,
-- `per` a column, columns growing "right" / "left". cross: the other side of a frame. x / y: the
-- block's start corner from the screen center. roles: the order they come in. Pets come after
-- everyone, `petHeight` high, in their owner's class color. Buffs and debuffs: which (mode), how
-- many in what grid, and where on the frame: `small` up to `breakpoint` members, `large` above.
-- bars: the health and power bars' look (Colors page settings apply as on any bar).
function ns.ufAuraDefaults(mode, point, x, y)
    return { mode = mode, max = 3, cols = 3, rows = 1, size = 14, radius = 0, hideTimer = true,
        small = { point = point, x = x, y = y }, large = { point = point, x = x, y = y } }
end
DEFAULTS.unitframes = { show = false, replace = true, fixed = "width", size = 400, per = 5, grow = "down",
    cross = 36, gap = 4, x = -500, y = 200, fontSize = 10, power = true, powerHeight = 4,
    pets = true, petHeight = 14, roleIcon = true, marker = true, dummy = 10, breakpoint = 5,
    roles = { "TANK", "HEALER", "DAMAGER" },
    buffs = ns.ufAuraDefaults("mine", "TOPRIGHT", -2, -2), debuffs = ns.ufAuraDefaults("dispel", "BOTTOMLEFT", 2, 2),
    bars = { tothealth = barDefaults(true, 80, 32, 0.2, 0.8, 0.2, false), power = barDefaults(true, 80, 4, 0.2, 0.4, 1, false) } }
DEFAULTS.unitframes.bars.tothealth.colorMode = "class" -- "tothealth": a bar of another unit's health
DEFAULTS.unitframes.bars.power.colorMode = "power"

-- Rogue and shaman: what is on each weapon, and when it is nearly gone.
-- (a local would put this file over Lua's limit of 200 of them, so it hangs off ns)
function ns.weaponDefaults(y)
    return {
        show = true, locked = true, x = 0, y = y, size = 32, gap = 4, grow = "right", radius = 0,
        warn = 9, flash = true, countAt = "corner",
        font = FONTS[1][2], fontSize = 12, outline = true,
        color = { 1, 1, 1, 1 }, warnColor = { 1, 0.75, 0.2, 1 },
    }
end
DEFAULTS.rogue = ns.weaponDefaults(-260)
DEFAULTS.shaman = ns.weaponDefaults(-260)

-- Warlock: the soul shards in your bags.

DEFAULTS.warlock = {
    show = true, locked = true, x = 0, y = -220, size = 32, radius = 0,
    armor = true, armorSize = 32, armorFontSize = 12, armorOnlyMissing = true,
    flash = true, gap = 4, grow = "right",
    countAt = "corner", showCount = true, low = 3,
    font = FONTS[1][2], fontSize = 12, outline = true,
    color = { 1, 1, 1, 1 }, lowColor = { 1, 0.4, 0.4, 1 },
}

-- Hunter: ammunition left, and how the pet feels.
DEFAULTS.hunter = {
    show = true, locked = true, x = 0, y = -180, size = 32, gap = 4, grow = "right", radius = 0,
    ammo = true, pet = true, countAt = "corner", showCount = true, low = 200,
    font = FONTS[1][2], fontSize = 12, outline = true,
    color = { 1, 1, 1, 1 }, lowColor = { 1, 0.4, 0.4, 1 },
}

-- Mage: the conjured food and water in your bags, best rank only.
DEFAULTS.mage = {
    show = true, locked = true, x = 0, y = -140, size = 32, gap = 4, grow = "right",
    countAt = "corner", showCount = true, low = 5, radius = 0, waterFirst = false,
    font = FONTS[1][2], fontSize = 12, outline = true,
    color = { 1, 1, 1, 1 }, lowColor = { 1, 0.4, 0.4, 1 },
}

-- Buff check: who in the group is missing a buff somebody here can hand out.
DEFAULTS.buffs = {
    show = false, locked = true, x = -300, y = 0, size = 18, fontSize = 12, outline = true,
    font = FONTS[1][2], color = { 1, 0.5, 0.5, 1 }, onlyMissing = false, lowCount = 5,
    skip = {}, -- [check key] = true: leave that one out
}

-- the old "Target health beside it" switch; useProfile turns it into Enemy Health beside you
DEFAULTS.regular.bars.health.target = false
DEFAULTS.regular.hidePlayerFrame = false -- hide Blizzard's player unit frame
DEFAULTS.regular.hideTargetFrame = false -- hide Blizzard's target unit frame
DEFAULTS.regular.hideXPBar = false       -- hide Blizzard's experience bar
DEFAULTS.regular.hideActionBars = false  -- hide Blizzard's action bars

-- Action bars of your own. They share the game's 120 action slots: each bar owns a fixed run of
-- them from `first`, so resizing one never moves the spells on another. binds: action slot ->
-- key, applied as override bindings (the game's own key settings stay as they are).
ns.AB_POOL = 120
ns.AB_BAR = { first = 1, rows = 1, cols = 12, size = 36, gap = 4, radius = 0, zoom = 8, borderSize = 1,
    borderColor = { 0, 0, 0, 1 }, grow = "rightdown", point = "BOTTOM", x = 0, y = 60,
    keyFont = FONTS[1][2], keySize = 11, macroFont = FONTS[1][2], macroSize = 10, macroText = true,
    hideEmpty = false, -- hideEmpty: a slot with nothing in it shows no button (they show while dragging)
    mouseover = false, -- mouseover: the bar fades in only under the mouse (its keys work either way)
    slotBg = true } -- slotBg: the game's dark square behind the icon (seen in the corners of a rounded one)
DEFAULTS.actionbars = { bars = {}, binds = {}, seeded = false }
-- Stance and pet bars: Blizzard's own buttons, moved into a bar of yours. anchorTo: "screen", "bar:N"
-- (one of your bars) or the other of the two; side: where on it ("above", "below", "left", "right").
for _, key in ipairs({ "stance", "pet" }) do
    local b = {}
    for k, v in pairs(ns.AB_BAR) do b[k] = type(v) == "table" and { unpack(v) } or v end
    b.show, b.cols, b.size, b.anchorTo, b.side, b.y = false, 10, 30, "bar:1", "above", 0
    b.align = "center" -- along that side: "start" (left / top), "center" or "end" (right / bottom)
    b.first = nil
    DEFAULTS.actionbars[key] = b
end
DEFAULTS.regular.hideStanceBar = false
DEFAULTS.regular.hidePetBar = false
DEFAULTS.regular.hideBlizzCastbar = false -- hide Blizzard's player cast bar
DEFAULTS.regular.playerMenu = false      -- right-click on the bars opens the player menu
DEFAULTS.regular.targetMenu = true       -- right-click on the enemy health bar opens the target's menu
DEFAULTS.regular.petMenu = true          -- ... on the pet bar, your pet's
DEFAULTS.regular.totMenu = true          -- ... on target of target, its menu
DEFAULTS.regular.playerTarget = false    -- left-click on the bars targets yourself
DEFAULTS.regular.playerMouseover = false -- hovering the bars makes you @mouseover
DEFAULTS.regular.highlight = { show = false, color = { 1, 1, 1, 0.25 } } -- overlay while hovered

------------------------------------------------------------------------------------------
-- Colors: one palette for the whole profile. A bar picks which of these it wears (or a color of
-- its own); anything new that needs a class, power, health or cast color takes it from here.
-- borderShade: how a "same as bar" border differs from the bar, -100 (black) to 100 (white).
------------------------------------------------------------------------------------------
ns.CLASS_ORDER = { { "WARRIOR", "Warrior" }, { "PALADIN", "Paladin" }, { "HUNTER", "Hunter" }, { "ROGUE", "Rogue" },
    { "PRIEST", "Priest" }, { "DEATHKNIGHT", "Death Knight" }, { "SHAMAN", "Shaman" }, { "MAGE", "Mage" },
    { "WARLOCK", "Warlock" }, { "MONK", "Monk" }, { "DRUID", "Druid" }, { "DEMONHUNTER", "Demon Hunter" },
    { "EVOKER", "Evoker" } }
ns.POWER_ORDER = { { "MANA", "Mana" }, { "RAGE", "Rage" }, { "ENERGY", "Energy" }, { "FOCUS", "Focus" },
    { "RUNIC_POWER", "Runic power" }, { "LUNAR_POWER", "Astral power" }, { "MAELSTROM", "Maelstrom" },
    { "INSANITY", "Insanity" }, { "FURY", "Fury" }, { "PAIN", "Pain" } }
do
    local CLASS = { WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
        ROGUE = { 1, 0.96, 0.41 }, PRIEST = { 1, 1, 1 }, DEATHKNIGHT = { 0.77, 0.12, 0.23 },
        SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 },
        MONK = { 0, 1, 0.6 }, DRUID = { 1, 0.49, 0.04 }, DEMONHUNTER = { 0.64, 0.19, 0.79 },
        EVOKER = { 0.2, 0.58, 0.5 } }
    local POWER = { MANA = { 0, 0, 1 }, RAGE = { 1, 0, 0 }, ENERGY = { 1, 1, 0 }, FOCUS = { 1, 0.5, 0.25 },
        RUNIC_POWER = { 0, 0.82, 1 }, LUNAR_POWER = { 0.3, 0.52, 0.9 }, MAELSTROM = { 0, 0.5, 1 },
        INSANITY = { 0.4, 0, 0.8 }, FURY = { 0.79, 0.26, 0.99 }, PAIN = { 1, 0.61, 0 } }
    local p = { class = {}, power = {} }
    for token, c in pairs(CLASS) do -- the game's own, where it says
        local ok, cc = pcall(function() return C_ClassColor and C_ClassColor.GetClassColor(token) or RAID_CLASS_COLORS[token] end)
        p.class[token] = ok and cc and { cc.r, cc.g, cc.b, 1 } or { c[1], c[2], c[3], 1 }
    end
    for token, c in pairs(POWER) do p.power[token] = { c[1], c[2], c[3], 1 } end
    p.health = { 0.2, 0.8, 0.2, 1 }
    p.experience = { 0.58, 0, 0.55, 1 } -- Blizzard's experience purple
    p.honor = { 1, 0.4, 0, 1 }
    p.happiness = { unhappy = { 0.9, 0.2, 0.2, 1 }, content = { 1, 0.6, 0.1, 1 }, happy = { 0.2, 0.85, 0.3, 1 } }
    p.reaction = { hostile = { 0.85, 0.2, 0.2, 1 }, neutral = { 0.95, 0.8, 0.2, 1 }, friendly = { 0.2, 0.8, 0.2, 1 } }
    -- your cast bar: casting / channeling; your target's: what kind of cast (auto color)
    p.cast = { cast = { 1, 0.7, 0, 1 }, channel = { 0.3, 0.7, 1, 1 }, harm = { 0.9, 0.3, 0.2, 1 },
        heal = { 0.2, 0.9, 0.3, 1 }, locked = { 0.6, 0.6, 0.65, 1 } }
    p.borderShade = 25
    p.borderSize, p.radius = 0, 0 -- every bar's border width and corner radius, unless it has its own
    p.bordersSet = false -- useProfile has given bars with a border or corners of their own "own" (once)
    p.texture = TEXTURES[1][2] -- every bar's texture, unless it has its own
    p.borderTexture = TEXTURES[2][2] -- every border's (flat), tinted by its color, unless the bar has its own
    -- a gradient laid over every bar's fill, and one over every border: from one color to the
    -- other (opacity included), top to bottom ("down") or left to right ("right")
    -- fromMode / toMode "bar": that end is the bar's color, at the swatch's opacity
    p.barShine = { show = false, dir = "down", from = { 1, 1, 1, 0.25 }, to = { 1, 1, 1, 0 },
        fromMode = "custom", toMode = "custom" }
    p.borderShine = { show = false, dir = "down", from = { 1, 1, 1, 0.35 }, to = { 0, 0, 0, 0.35 },
        fromMode = "custom", toMode = "custom" }
    -- every bar's shadows. Inner: fading in from the edges, over the fill ("bar") or between the
    -- border and the bar ("border"). Drop: behind the border. size: how far they fade; x / y: offset (y up)
    -- every bar's empty bar: a shape under the fill in a texture of its own, in a color of its own
    -- ("custom") or the bar's, darker by `darken` % ("bar"), at the color's opacity
    p.emptyBar = { show = false, texture = TEXTURES[1][2], mode = "bar", color = { 0.1, 0.1, 0.1, 1 }, darken = 70 }
    p.innerShadow = { show = false, on = "bar", color = { 0, 0, 0, 0.6 }, size = 4, x = 0, y = -2 }
    -- spread: grows (or, negative, shrinks) the drop shadows' shape before it fades. The bar's
    -- drop shadow is the fill's, between border and bar; the border's is behind the border
    p.dropShadow = { show = false, color = { 0, 0, 0, 0.6 }, size = 4, x = 2, y = -2, spread = 0 }
    p.barShadow = { show = false, color = { 0, 0, 0, 0.6 }, size = 3, x = 1, y = -1, spread = 0 }
    p.texturesSet = false -- ... and bars with a texture of their own "own" (once)
    p.moved = false -- useProfile has moved the per-bar power and cast colors in here (once)
    DEFAULTS.colors = p
end

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
local changed, placeMini, useProfile, bf, mg, hn, wl, we, lt, mc, ft, seedFromBaked

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
------------------------------------------------------------------------------------------
-- Flight times. Nothing in the game will say how long a taxi ride takes -- the flight point
-- knows the price and nothing else -- so the first ride on a route is timed and written down,
-- account-wide, and every ride after that counts down from it. A route you have never flown
-- shows the time so far instead of a guess.
ft = { }
ns.ft = ft

function ft.flying()
    local ok, on = pcall(UnitOnTaxi, "player")
    return ok and on == true
end

-- The name of the flight point you are standing on, and of one on the map by its slot.
function ft.nodeName(slot)
    local ok, name = pcall(function()
        if TaxiNodeName then return TaxiNodeName(slot) end
    end)
    if ok and type(name) == "string" and name ~= "" then return name end
    local ok2, found = pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(map) or {}) do
            if node.slotIndex == slot then return node.name end
        end
    end)
    return ok2 and found or nil
end

function ft.here()
    local ok, name = pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(map) or {}) do
            if node.state == 0 or node.state == Enum.FlightPathState.Current then return node.name end
        end
    end)
    if ok and type(name) == "string" then return name end
    local ok2, zone = pcall(GetSubZoneText)
    return (ok2 and zone ~= "" and zone) or (select(2, pcall(GetZoneText)))
end

-- Clicking a flight point is the only moment both ends of the route are known. Which call the
-- flight map makes has moved between builds, so every one of them is hooked and whichever fires
-- wins; ft.hooked says which were there to hook at all.
function ft.taking(slot)
    local from, to = ft.here(), ft.nodeName(slot)
    if not to then return end -- a call that told us nothing is not a route
    ft.route = { from = from or "?", to = to }
    ft.caught = GetTime()
end

function ft.hook()
    ft.hooked = {}
    for _, name in ipairs({ "TakeTaxiNode", "TaxiNodeOnButtonEnter" }) do
        if type(_G[name]) == "function" then ft.hooked[#ft.hooked + 1] = name end
    end
    pcall(hooksecurefunc, "TakeTaxiNode", function(slot) safe(ft.taking, slot) end)
    -- some builds route the click through the map frame's own handler instead
    pcall(function()
        if TaxiFrame and TaxiFrame.TakeTaxiNode then
            hooksecurefunc(TaxiFrame, "TakeTaxiNode", function(_, slot) safe(ft.taking, slot) end)
            ft.hooked[#ft.hooked + 1] = "TaxiFrame:TakeTaxiNode"
        end
    end)
end

function ft.key()
    return ft.route and (ft.route.from .. " > " .. ft.route.to) or nil
end

function ft.known(key)
    return store and store.flights and store.flights[key or ft.key() or ""] or nil
end

-- How long this ride takes and how far into it you are. The first is nil on a route never
-- flown; the second is always the time since takeoff, so the two never mean different things.
function ft.progress()
    if not ft.startedAt then return nil, nil end
    return ft.total, GetTime() - ft.startedAt
end

function ft.tick()
    local on = ft.flying()
    if on and not ft.startedAt then
        ft.startedAt, ft.total = GetTime(), ft.known()
        ft.moved = true
    elseif not on and ft.startedAt then
        ft.moved = true
        local flown, key = GetTime() - ft.startedAt, ft.key()
        -- a ride under five seconds is somebody dismounting, not a route
        if key and flown > 5 and store then
            store.flights = store.flights or {}
            store.flights[key] = math.floor(flown + 0.5)
        end
        ft.startedAt, ft.total, ft.route = nil, nil, nil
    end
    return ft.moved -- set on the tick where the ride began or ended, cleared by the ticker
end

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
    targetcast = {
        label = "Enemy Cast",
        -- Only while your target is casting. What comes back can be secret on this client, and
        -- a secret may not even be tested for truth -- so the test is wrapped, and a refusal is
        -- taken as a yes: the game only has something to hide when there is something there.
        state = function()
            return (ns.previewing() or ns.targetCasting == true) and true or false, 1
        end,
    },
    ammo = {
        label = "Ammunition",
        state = function()
            return (class == "HUNTER" and (hn.ammo() ~= nil or ns.previewing())) and true or false, 1
        end,
        value = function()
            local id, count = hn.ammo()
            if not id then return 1, 1 end -- placing it: a full bar
            return count, hn.capacity(id, count)
        end,
    },
    experience = {
        label = "Experience",
        -- while there is experience to gain (never at the top level), and while placing the bars
        state = function() return (ns.previewing() or ns.xpTrack() ~= nil) and true or false, 1 end,
        value = function()
            local kind, v, max = ns.xpTrack()
            if not kind then return 1, 1 end -- previewing with nothing to show: a full bar
            return v, max
        end,
    },
    flight = {
        label = "Flight",
        -- only while the griffin has you. Nobody will say how long a route takes, so the first
        -- time you fly one it is timed and remembered, and after that it counts down.
        state = function() return (ns.previewing() or ft.flying()) and true or false, 1 end,
    },
    enemyhealth = {
        label = "Enemy Health",
        -- while you have a target, and while placing the bars
        state = function() return (UnitExists("target") or ns.previewing()) and true or false, 1 end,
        value = function(unit)
            if not UnitExists(unit) then return 1, 1 end -- previewing: a full bar
            return UnitHealth(unit), UnitHealthMax(unit)
        end,
    },
    tothealth = {
        label = "Target of Target",
        state = function() return (UnitExists("targettarget") or ns.previewing()) and true or false, 1 end,
        value = function(unit)
            if not UnitExists(unit) then return 1, 1 end -- previewing: a full bar
            return UnitHealth(unit), UnitHealthMax(unit)
        end,
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

local function newBar(parent, key, mode)
    local f = CreateFrame("Frame", nil, parent)
    f.key, f.mode, f.segs = key, mode, {}
    return f
end

local swingFrames = { regular = {} }
ns.swingFrames = swingFrames

for key in pairs(BARS) do
    frames[key] = newBar(anchor, key, "regular")
end
-- Enemy health reads your target; its resource bar sits inside it and wears its look
for _, set in ipairs({ frames }) do
    set.tothealth.unit = "targettarget"
    local f = set.enemyhealth
    f.unit = "target"
    f.resFrame = newBar(f, "enemyhealth", f.mode)
    f.resFrame.unit, f.resFrame.res = "target", true
    f.resFrame:Hide() -- until laid out: power events fill only shown bars
end
for i in ipairs(SWING_TYPES) do
    swingFrames.regular[i] = newBar(anchor, "swing", "regular")
    swingFrames.regular[i].swing = i
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

-- Class color of a unit, from the palette; nil for NPCs other than you (they have classes too,
-- which would look random).
local function classRGB(unit)
    if unit ~= "player" and not UnitIsPlayer(unit) then return end
    local _, token = UnitClass(unit)
    local c = token and db.colors.class[token]
    if c then return c[1], c[2], c[3] end
end

-- A power's color from the palette (the game's own for one it has no swatch for).
function ns.powerRGB(token)
    local c, pc = db.colors.power[token], PowerBarColor and PowerBarColor[token]
    if c then return c[1], c[2], c[3] end
    if pc then return pc.r, pc.g, pc.b end
end

-- How the unit stands to you: hostile, neutral or friendly, from the palette; nil if unknown.
function ns.reactionRGB(unit)
    local ok, r = pcall(UnitReaction, unit, "player")
    if not (ok and readable(r) and type(r) == "number") then return end
    local c = db.colors.reaction[r <= 3 and "hostile" or r == 4 and "neutral" or "friendly"]
    return c[1], c[2], c[3]
end

-- A gradient overlay from the palette (o: show, dir, from, to) on a white texture. fromMode /
-- toMode "bar": that end takes the bar's color (rgb), keeping its own opacity.
function ns.shine(tex, o, allowed, rgb)
    local on = o.show and allowed ~= false
    tex:SetShown(on and true or false)
    if not on then return end
    local function col(c, m)
        if m == "bar" and rgb then return CreateColor(rgb[1], rgb[2], rgb[3], c[4]) end
        return CreateColor(unpack(c))
    end
    local from, to = col(o.from, o.fromMode), col(o.to, o.toMode)
    tex:SetColorTexture(1, 1, 1, 1)
    if o.dir == "right" then
        tex:SetGradient("HORIZONTAL", from, to)
    else -- VERTICAL runs bottom to top: the "to" color is the bottom one
        tex:SetGradient("VERTICAL", to, from)
    end
end

-- The palette's empty bar: a solid shape under each segment, its size and corners, in a texture
-- and color of its own (one of its own, or the bar's color darker). It stands in for the
-- background, so the border no longer shows through.
function ns.emptyFill(s, c)
    local e = db.colors.emptyBar
    s.empty = s.empty or s:CreateTexture(nil, "BACKGROUND", nil, -4)
    s.empty:SetShown(e.show and true or false)
    s.bg:SetShown(not e.show)
    if not e.show then return end
    s.empty:SetAllPoints(s)
    s.empty:SetTexture(e.texture)
    local col = e.color
    if e.mode == "bar" and s.rgb then
        local k = 1 - e.darken / 100
        col = { s.rgb[1] * k, s.rgb[2] * k, s.rgb[3] * k, e.color[4] }
    end
    s.empty:SetVertexColor(unpack(col))
end

-- The palette's inner shadow on a bar segment: four strips fading in from the edges, masked to its
-- corners. Over the fill, or over the border and under the bar. An offset thickens the edges it
-- moves away from (y up: a negative y darkens the top).
function ns.innerShadow(s, w, h, iw, ih, radius, inner)
    local o = db.colors.innerShadow
    s.inner = s.inner or { s:CreateTexture(), s:CreateTexture(), s:CreateTexture(), s:CreateTexture() }
    local onBar = o.on ~= "border"
    local box, mask = onBar and s or s.border, onBar and s.mask or s.borderMask
    local bw, bh = onBar and iw or w, onBar and ih or h
    local r, g, b, a = unpack(o.color)
    local solid, clear = CreateColor(r, g, b, a), CreateColor(r, g, b, 0)
    local sizes = { o.size - o.y, o.size + o.y, o.size + o.x, o.size - o.x } -- top, bottom, left, right
    for i, tex in ipairs(s.inner) do
        local n = math.min(math.max(sizes[i], 0), i <= 2 and bh or bw)
        local on = o.show and n > 0
        tex:SetShown(on and true or false)
        if on then
            tex:SetDrawLayer(onBar and "ARTWORK" or "BACKGROUND", onBar and 4 or -6)
            tex:SetColorTexture(1, 1, 1, 1)
            tex:ClearAllPoints()
            local side = ({ "TOP", "BOTTOM", "LEFT", "RIGHT" })[i]
            if i <= 2 then
                tex:SetPoint(side .. "LEFT", box, side .. "LEFT")
                tex:SetPoint(side .. "RIGHT", box, side .. "RIGHT")
                tex:SetHeight(n)
                tex:SetGradient("VERTICAL", i == 1 and clear or solid, i == 1 and solid or clear)
            else
                tex:SetPoint("TOP" .. side, box, "TOP" .. side)
                tex:SetPoint("BOTTOM" .. side, box, "BOTTOM" .. side)
                tex:SetWidth(n)
                tex:SetGradient("HORIZONTAL", i == 3 and solid or clear, i == 3 and clear or solid)
            end
            if tex.cpdMask and tex.cpdMask ~= mask then -- moved between bar and border
                tex:RemoveMaskTexture(tex.cpdMask)
                tex.cpdMask = nil
            end
            round(tex, mask, onBar and inner or radius, bw, bh)
        end
    end
end

-- The palette's drop shadows: a soft copy of a shape (`box`), offset, grown by `spread` (shrunk
-- when negative) and fading out over `size`. The border's sits on the bar's frame, so under every
-- segment; the bar's on the segment, over its border and under its background.
function ns.dropShadow(tex, o, box)
    local n = math.max(1, math.min(math.floor(o.size), 20))
    tex:SetShown(o.show and true or false)
    if not o.show then return end
    tex:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\Shadow\\s" .. n .. ".tga")
    pcall(tex.SetTextureSliceMargins, tex, n, n, n, n)
    tex:SetVertexColor(unpack(o.color))
    tex:ClearAllPoints()
    local e = n + (o.spread or 0)
    tex:SetPoint("TOPLEFT", box, "TOPLEFT", o.x - e, o.y + e)
    tex:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", o.x + e, o.y - e)
end

-- A "same as bar" border: the bar's color, lighter or darker by the palette's border shade.
function ns.shade(r, g, b)
    local s = (db.colors.borderShade or 0) / 100
    if s >= 0 then return r + (1 - r) * s, g + (1 - g) * s, b + (1 - b) * s end
    return r * (1 + s), g * (1 + s), b * (1 + s)
end

-- The palette color a bar wears in its mode, or nil (then its own color). f.castKind / f.channel:
-- what the cast bars are showing right now.
function ns.modeRGB(f, c)
    local m, unit = c.colorMode, f.unit or "player"
    if m == "health" then
        local h = db.colors.health
        return h[1], h[2], h[3]
    elseif m == "power" then
        local token = f.key == "druidmana" and "MANA" or select(2, UnitPowerType(unit))
        return ns.powerRGB(token)
    elseif m == "class" then
        local r, g, b = classRGB(unit)
        if r or (f.key ~= "enemyhealth" and f.key ~= "tothealth") then return r, g, b end
        return ns.reactionRGB(unit) -- an NPC has no class color of its own: how it stands to you
    elseif m == "experience" then -- its kind's color: experience, honor, a faction's by standing
        local kind, _, _, standing = ns.xpTrack()
        local x = kind == "honor" and db.colors.honor or db.colors.experience
        if kind == "rep" and standing then
            x = db.colors.reaction[standing <= 3 and "hostile" or standing == 4 and "neutral" or "friendly"]
        end
        return x[1], x[2], x[3]
    elseif m == "reaction" then
        return ns.reactionRGB(unit)
    elseif m == "auto" or m == "cast" then
        local kind = m == "auto" and (f.castKind or "harm") or (f.channel and "channel" or "cast")
        local k = db.colors.cast[kind]
        return k[1], k[2], k[3]
    end
end

-- A bar's fill and border colors after the color modes. Alpha always comes from the swatch.
local function barColors(f, c)
    local r, g, b = unpack(c.color)
    local mr, mg, mb = ns.modeRGB(f, c)
    if mr then r, g, b = mr, mg, mb end
    local br, bg, bb, ba = unpack(c.borderColor)
    if c.borderMode ~= "custom" then -- the bar's color, shaded, so the edge reads
        local first = c.gradient and sortedStops(c)[1] -- a gradient: where the fill starts
        if first then
            br, bg, bb = ns.shade(first.color[1], first.color[2], first.color[3])
        else
            br, bg, bb = ns.shade(r, g, b)
        end
    end
    return r, g, b, br, bg, bb, ba
end

-- A cast bar's color changes with the cast, after layout: recolor the fill and its border.
function ns.wearColor(f, c)
    local r, g, b = ns.modeRGB(f, c)
    if not r or c.gradient then return end
    local s = f.segs[1]
    s:SetStatusBarColor(r, g, b, c.color[4] or 1)
    s.rgb = { r, g, b }
    ns.emptyFill(s, c)
    if s.shine then -- the overlays' "same as bar" ends follow the cast
        ns.shine(s.shine, db.colors.barShine, nil, s.rgb)
        ns.shine(s.edgeShine, db.colors.borderShine, s.border:IsShown(), s.rgb)
    end
    if c.borderMode ~= "custom" then
        local br, bg, bb = ns.shade(r, g, b)
        s.border:SetVertexColor(br, bg, bb, c.borderColor[4]) -- tints its texture
    end
end

-- over: settings that replace the bar's own for this layout (enemy health's height while it sits
-- beside your health, its resource bar's height and colors)
local function layoutBar(f, n, width, over)
    local c = db[f.mode].bars[f.key]
    if c.borderFrom ~= "own" or c.textureFrom ~= "own" then -- the profile's shared border and texture
        local shared = {}
        if c.borderFrom ~= "own" then
            shared.borderSize, shared.radius, shared.borderTexture = db.colors.borderSize, db.colors.radius,
                db.colors.borderTexture
        end
        if c.textureFrom ~= "own" then shared.texture = db.colors.texture end
        c = setmetatable(shared, { __index = c })
    end
    if over then c = setmetatable(over, { __index = c }) end
    width = width or c.width
    f.width = width
    local r, g, b, br, bg, bb, ba = barColors(f, c)
    -- Cast bar spell icon: a square at one end, inside the bar's width. Both cast bars have one.
    local lead, iconSpace = 0, 0
    if f.key == "castbar" or f.key == "targetcast" then
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
            if i == 1 then f.edge = t end -- the border's width, for what runs along it
            local iw, ih = w - 2 * t, c.height - 2 * t
            f.segWidth = iw
            s:SetSize(iw, ih)
            s:SetPoint("LEFT", f, "LEFT", lead + (i - 1) * (w + PIP_GAP) + t, 0)
            s:SetMinMaxValues(i - 1, i) -- pip range; single bars get their real max in ns.fill()
            s.bg:SetColorTexture(unpack(c.bgColor))
            local sr, sg, sb = br, bg, bb
            s.rgb = { r, g, b } -- what "same as bar" overlay colors take
            if f.key == "totems" then -- each segment wears its element's color, border included
                local col = c.slotColors[c.slots[i]]
                s.rgb = { col[1], col[2], col[3] }
                paint(s, c, col[1], col[2], col[3], w, c.height)
                if c.borderMode ~= "custom" and not c.gradient then sr, sg, sb = ns.shade(col[1], col[2], col[3]) end
            else
                paint(s, c, r, g, b, w, c.height)
            end
            ns.emptyFill(s, c)
            s.border:SetShown(t > 0)
            s.border:SetPoint("TOPLEFT", s, "TOPLEFT", -t, t)
            s.border:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", t, -t)
            s.border:SetTexture(c.borderTexture or "Interface\\Buttons\\WHITE8X8")
            s.border:SetVertexColor(sr, sg, sb, ba)
            local radius = c.radius == "pill" and math.huge or c.radius
            round(s.border, s.borderMask, radius, w, c.height)
            -- the palette's gradient overlays: over the fill (it follows the fill), over the border
            local inner0 = math.max(radius - t, 0)
            s.shine = s.shine or s:CreateTexture(nil, "ARTWORK", nil, 3)
            s.shine:SetAllPoints(s:GetStatusBarTexture())
            ns.shine(s.shine, db.colors.barShine, nil, s.rgb)
            round(s.shine, s.mask, inner0, iw, ih)
            s.edgeShine = s.edgeShine or s:CreateTexture(nil, "BACKGROUND", nil, -7) -- over the border, under the bar
            s.edgeShine:SetAllPoints(s.border)
            ns.shine(s.edgeShine, db.colors.borderShine, t > 0, s.rgb)
            round(s.edgeShine, s.borderMask, radius, w, c.height)
            ns.innerShadow(s, w, c.height, iw, ih, radius, inner0)
            s.drop = s.drop or f:CreateTexture(nil, "BACKGROUND", nil, -8)
            ns.dropShadow(s.drop, db.colors.dropShadow, s.border)
            s.barDrop = s.barDrop or s:CreateTexture(nil, "BACKGROUND", nil, -5)
            ns.dropShadow(s.barDrop, db.colors.barShadow, s)
            s.hl:SetColorTexture(unpack(db.regular.highlight.color))
            s.hl:SetShown((f.mode == "regular" and hovered) or false)
            round(s.hl, s.borderMask, radius, w, c.height)
            local inner = math.max(radius - t, 0) -- inner corners follow the outer ones
            round(s.bg, s.mask, inner, iw, ih)
            round(s.empty, s.mask, inner, iw, ih)
            round(s:GetStatusBarTexture(), s.mask, inner, iw, ih)
            s:Show()
        end
    end
    -- Prediction overlay: incoming heals grow right from the health fill, a cast's cost grows
    -- left from the power fill. Both hang off the fill texture, so no value is ever read to
    -- place them, and a frame over the bar clips whatever runs past its edge. Only that frame
    -- clips: the bar itself must not, or every icon, buff and text hung outside it is cut off.
    local over = (f.key == "health" and c.heal) or (f.key == "power" and c.cost)
    if over and n == 1 then
        local seg = f.segs[1]
        if not f.over then
            local clip = CreateFrame("Frame", nil, f)
            clip:SetAllPoints(f)
            clip:SetClipsChildren(true)
            f.over = CreateFrame("StatusBar", nil, clip)
        end
        local o, col = f.over, f.key == "health" and c.healColor or c.costColor
        o:GetParent():SetFrameLevel(seg:GetFrameLevel() + 1)
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
    if ns.TEXT_BARS[f.key] and not f.res then -- three numbers of its own instead
        f.text:Hide()
        ns.layoutTexts(f, c, n)
    end
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
    f.channel = direction == TIMER_REMAINING
    ns.wearColor(f, db[f.mode].bars.castbar)
end

-- What your target is casting, as far as anything will say. Whether it can be stopped the game
-- tells us outright. Whether it heals it does not, and no list of spells on Wowhead separates
-- heals from buffs cleanly, so these are matched by name -- the names that matter are the ones
-- a mob healer casts at you from across the room.
-- Whether your target is casting is tracked from the events rather than asked for: the events
-- say which unit plainly, where the cast itself comes back secret and cannot even be tested for
-- truth. A refusal to read is not the same as a cast, which is what made the bar sit there.
ns.targetCasting = false

function ns.watchTargetCast(event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        ns.targetCasting, ns.targetChannelling = false, false
        return true
    end
    if unit ~= "target" then return false end
    return ns.castState(ns, event)
end

-- st.targetCasting / st.targetChannelling from a cast event: your target's (st = ns) or a
-- nameplate's own. False when the event says nothing about casting.
function ns.castState(st, event)
    if event == "UNIT_SPELLCAST_START" then
        st.targetCasting, st.targetChannelling = true, false
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        st.targetCasting, st.targetChannelling = true, true
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_SUCCEEDED" then
        st.targetCasting = false
    else
        return false
    end
    return true
end

ns.HEALING_CASTS = {}
for _, name in ipairs({ "Heal", "Lesser Heal", "Greater Heal", "Flash Heal", "Renew",
    "Prayer of Healing", "Holy Light", "Flash of Light", "Holy Nova", "Healing Wave",
    "Lesser Healing Wave", "Chain Heal", "Healing Touch", "Regrowth", "Rejuvenation",
    "Mend Pet", "Dark Mending", "Healing Ward", "Healing Totem", "Renew Life",
    "Lay on Hands", "Divine Shield", "Shield of Reckoning", "Bandage", "First Aid",
    "Mending", "Greater Healing Wave", "Holy Smite Heal" }) do
    ns.HEALING_CASTS[name:lower()] = true
end

-- "locked" when it cannot be stopped, "heal" when it mends, "harm" for the rest. Either of
-- those can arrive secret, which may be passed on but never looked at -- so an unreadable one
-- simply does not decide anything.
function ns.castKind(name, locked)
    if readable(locked) and locked == true then return "locked" end
    if readable(name) and type(name) == "string" and ns.HEALING_CASTS[name:lower()] then
        return "heal"
    end
    return "harm"
end

-- Your target's cast, drained by the game's own duration object where there is one.
function ns.fillTargetCast(f)
    -- Nothing here is compared, tested for truth, or checked against nil: on this client a
    -- target's cast comes back secret, and a secret may be handed to a bar or a font string but
    -- not looked at in any way. Which of the two calls to ask, and whether anything is being
    -- cast at all, come from the events instead -- asking the cast would mean reading it.
    local unit, st, s = f.unit or "target", f.castState or ns, f.segs[1]
    local channel = st.targetChannelling == true
    local info = { pcall(channel and UnitChannelInfo or UnitCastingInfo, unit) }
    local name, icon = info[2], info[4]
    local locked = info[channel and 8 or 9]  -- picked by index: choosing it with `and` reads it

    -- the color is only known once the cast is read, which is after the bar was laid out
    local function wear(kind)
        f.castKind, f.channel = kind, channel
        local c = db[f.mode] and db[f.mode].bars.targetcast
        if c then ns.wearColor(f, c) end
    end

    s:SetScript("OnUpdate", nil)
    if st.targetCasting ~= true then -- previewing, or nothing being cast
        f.text:SetText(BARS.targetcast.label)
        f.icon:SetTexture(134400)
        f.segs[1]:SetMinMaxValues(0, 1)
        f.segs[1]:SetValue(ns.previewing() and 1 or 0)
        wear("harm")
        return
    end

    -- The duration object is what drains the bar, in C. Whether one came back is counted, not
    -- compared: a call that returned nothing leaves the table one long.
    local got = { pcall(channel and UnitChannelDuration or UnitCastingDuration, unit) }
    local ticking = #got > 1 and pcall(s.SetTimerDuration, s, got[2], 0,
        channel and TIMER_REMAINING or TIMER_ELAPSED)
    -- no duration object (the classic clients): there the cast's start and end are plain numbers
    local from, to = info[5], info[6]
    if not ticking and readable(from) and readable(to) and type(from) == "number" and type(to) == "number"
        and to > from then
        from, to = from / 1000, to / 1000
        s:SetMinMaxValues(0, to - from)
        local function tick(self)
            local gone = math.min(math.max(GetTime() - from, 0), to - from)
            self:SetValue(channel and (to - from) - gone or gone)
        end
        s:SetScript("OnUpdate", tick)
        tick(s)
    elseif not ticking then -- nobody will say how long: an empty bar is less of a lie than a full one
        s:SetMinMaxValues(0, 1)
        s:SetValue(0)
    end
    pcall(f.text.SetText, f.text, name)        -- a secret name still draws
    pcall(f.icon.SetTexture, f.icon, icon)
    wear(ns.castKind(name, locked))
end

-- The flight bar drains for a route we have flown before, and counts up the first time so the
-- ride is at least measured while it happens.
local function fillFlight(f)
    local total, gone = ft.progress()
    local function clock(t)
        return ("%d:%02d"):format(math.floor(t / 60), math.floor(t % 60))
    end
    if not gone then -- previewing, on the ground
        f.segs[1]:SetMinMaxValues(0, 1)
        f.segs[1]:SetValue(1)
        f.text:SetText(BARS.flight.label)
        return
    end
    if total then
        f.segs[1]:SetMinMaxValues(0, total)
        f.segs[1]:SetValue(math.max(total - gone, 0))
        f.text:SetText(clock(math.max(total - gone, 0)))
    else -- never flown this one: a full bar, and the time so far
        f.segs[1]:SetMinMaxValues(0, 1)
        f.segs[1]:SetValue(1)
        f.text:SetText(clock(gone) .. (ft.route and " so far" or " -- route not caught"))
    end
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
    if not swingActive(kind[3]) then -- preview: a full bar, not the last swing's frozen fill
        f.segs[1]:SetMinMaxValues(0, 1)
        f.segs[1]:SetValue(1)
        f.text:SetText(kind[2])
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
    local unit = f.unit or "player"
    -- the calculator is the good way, where the client has one
    if healCalc and UnitGetDetailedHealPrediction then
        local ok = pcall(function()
            healCalc:SetIncomingHealClampMode(0) -- 0 = stop at missing health, no overheal
            healCalc:SetIncomingHealOverflowPercent(1.0)
            UnitGetDetailedHealPrediction(unit, "player", healCalc)
            f.over:SetMinMaxValues(0, healCalc:GetMaximumHealth())
            f.over:SetValue(healCalc:GetIncomingHeals())
        end)
        if ok then return end
    end
    -- and the plain one otherwise. The number may be secret, which a bar can still be given.
    local ok, heals = pcall(function()
        if UnitGetIncomingHeals then return UnitGetIncomingHeals(unit) end
    end)
    if ok and heals ~= nil then
        f.over:SetMinMaxValues(0, max)
        f.over:SetValue(heals)
    else
        f.over:SetValue(0)
    end
end

-- on the namespace rather than a local: this chunk is at Lua's 200-local ceiling, and the
-- flight ticker needs to reach it
function ns.fill(f)
    if f.key == "castbar" then return fillCast(f) end
    if f.key == "targetcast" then return ns.fillTargetCast(f) end
    if f.key == "flight" then return fillFlight(f) end
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
    local v, max = (f.res and ns.resValue or BARS[f.key].value)(f.unit or "player")
    -- an empty enemy resource (none at all, or nothing left) goes invisible, border and all, unless
    -- Hide when empty is off. A secret number can't be looked at, so the bar stays while the game
    -- keeps it secret.
    if f.res then -- (a unit frame's power bar reads like one too, with no enemy health of its own)
        local eh = db[f.mode].bars.enemyhealth
        local empty = eh and eh.resHideEmpty
            and ((readable(max) and max <= 0) or (readable(v) and v <= 0))
        f:SetAlpha(empty and 0 or 1)
    end
    if f.n == 1 then
        f.segs[1]:SetMinMaxValues(0, max)
        f.segs[1]:SetValue(v)
        if f.over and f.over:IsShown() then fillOverlay(f, max) end
        if f.text:IsShown() and not pcall(setText, f.text, v) then f.text:SetText("") end
        if f.texts and not f.res then ns.fillTexts(f, v, max) end
    else
        for i = 1, f.n do f.segs[i]:SetValue(v) end
    end
end

------------------------------------------------------------------------------------------
-- Health, power and enemy health numbers: percent, current, current / max -- any of them,
-- each in its own spot, size and color. In a fight the game may keep the numbers secret: they
-- still draw (the game formats them), and a percent comes from the game's own percent call.
------------------------------------------------------------------------------------------
ns.TEXT_BARS = { health = true, power = true, enemyhealth = true, experience = true }

-- The faction you watch: progress within its standing, the standing's size, the standing (1-8).
function ns.watchedFaction()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local ok, d = pcall(C_Reputation.GetWatchedFactionData)
        if ok and type(d) == "table" and d.name then
            return d.currentStanding - d.currentReactionThreshold, d.nextReactionThreshold - d.currentReactionThreshold,
                d.reaction
        end
    elseif GetWatchedFactionInfo then
        local ok, name, standing, low, high, value = pcall(GetWatchedFactionInfo)
        if ok and name then return value - low, high - low, standing end
    end
end

-- What the experience bar shows now: "xp", "rep" or "honor" (nil: nothing), its value and max,
-- and a faction's standing. ponytail: one setting for both layouts, your Combat Display's.
function ns.xpTrack()
    local c = db.regular.bars.experience
    local src = c.source == "auto" and (ns.xpDone() and "rep" or "xp") or c.source
    if src == "xp" then
        if ns.xpDone() then
            if not c.hideAtMax then return "xp", 1, 1 end -- the top level, kept: a full bar
            return
        end
        local ok, v, max = pcall(function() return UnitXP("player"), UnitXPMax("player") end)
        if ok and type(max) == "number" and max > 0 then return "xp", v, max end
    elseif src == "rep" then
        local v, max, standing = ns.watchedFaction()
        if v then
            if max <= 0 then return "rep", 1, 1, standing end -- the last standing: full
            return "rep", v, max, standing
        end
    elseif src == "honor" then
        local ok, v, max = pcall(function() return UnitHonor("player"), UnitHonorMax("player") end)
        if ok and type(max) == "number" and max > 0 then return "honor", v, max end
    end
end

-- No experience to gain: the top level, or experience turned off.
function ns.xpDone()
    local ok, off = pcall(IsXPUserDisabled)
    if ok and off then return true end
    local ok2, top = pcall(IsPlayerAtEffectiveMaxLevel)
    if ok2 and top ~= nil then return top and true or false end
    local ok3, maxLevel = pcall(GetMaxPlayerLevel)
    local level = UnitLevel("player")
    if ok3 and type(maxLevel) == "number" and readable(level) then return level >= maxLevel end
    local ok4, max = pcall(UnitXPMax, "player")
    return not (ok4 and type(max) == "number" and max > 0)
end
ns.TEXT_KINDS = { "percent", "current", "currentmax" }

function ns.layoutTexts(f, c, n)
    f.texts = f.texts or {}
    local flags = c.outline and "OUTLINE" or ""
    for _, k in ipairs(ns.TEXT_KINDS) do
        local o, t = c.texts[k], f.texts[k]
        if not t then
            t = f.segs[1]:CreateFontString(nil, "OVERLAY")
            t:SetWordWrap(false)
            f.texts[k] = t
        end
        t:SetShown((c.text and o.show and n == 1) and true or false)
        if not t:SetFont(c.font, o.size, flags) then t:SetFont(FONTS[1][2], o.size, flags) end
        t:SetTextColor(unpack(o.color))
        t:ClearAllPoints()
        t:SetPoint(o.anchor, f.segs[1], o.anchor, o.x, o.y)
        t:SetJustifyH(ns.justify(o.anchor))
    end
end

ns.TEXT_FORMAT = {
    current = function(t, v) t:SetText(AbbreviateNumbers(v)) end,
    currentmax = function(t, v, max)
        local now = AbbreviateNumbers(v)
        if not pcall(function() t:SetText(now .. " / " .. AbbreviateNumbers(max)) end) then t:SetText(now) end
    end,
    percent = function(t, v, max, f)
        if readable(v) and readable(max) then
            t:SetText(max > 0 and math.floor(v / max * 100 + 0.5) .. "%" or "")
            return
        end
        local unit, curve = f.unit or "player", CurveConstants.ScaleTo100
        local p = f.key == "power" and UnitPowerPercent(unit, UnitPowerType(unit), true, curve)
            or UnitHealthPercent(unit, true, curve)
        t:SetText(string.format("%.0f%%", p))
    end,
}

function ns.fillTexts(f, v, max)
    for k, t in pairs(f.texts) do
        if t:IsShown() and not pcall(ns.TEXT_FORMAT[k], t, v, max, f) then t:SetText("") end
    end
end

function ns.resValue(unit)
    if not UnitExists(unit) then return 1, 1 end -- previewing: a full bar
    return UnitPower(unit), UnitPowerMax(unit)
end

-- The resource bar's settings: its own size, text switch, color and border, over enemy health's look.
function ns.resConf(c)
    return setmetatable({ height = c.resHeight, colorMode = c.resColorMode, color = c.resColor,
        text = c.text and not c.resHideText,
        borderSize = c.resBorderSize, borderMode = c.resBorderMode, borderColor = c.resBorderColor,
        radius = c.resRadius }, { __index = c })
end

-- The resource bar inside enemy health, drawn over it: a share of its width, placed from its
-- bottom center.
function ns.layoutRes(f)
    local r, c = f.resFrame, db[f.mode].bars.enemyhealth
    r:SetShown(c.resource and true or false)
    if not c.resource then return end
    r:SetFrameLevel(f:GetFrameLevel() + 5)
    layoutBar(r, 1, math.max(1, math.floor(f.width * c.resWidth / 100 + 0.5)), ns.resConf(c))
    ns.fill(r)
    r:ClearAllPoints()
    local p = c.resPoint or "BOTTOM"
    r:SetPoint(c.resPlace == "outside" and ns.OPPOSITE[p] or p, f, p, c.resX, c.resY)
end
-- the point of a frame hung outside another's point: TOP of it on the BOTTOM edge, and so on
ns.OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT", CENTER = "CENTER",
    TOPLEFT = "BOTTOMLEFT", TOPRIGHT = "BOTTOMRIGHT", BOTTOMLEFT = "TOPLEFT", BOTTOMRIGHT = "TOPRIGHT" }

-- Level and name, inset in enemy health. The level takes the color the game gives it (grey: no
-- experience, red: far above you), "+" for an elite, "??" for a skull. Without a target (placing
-- the bars) it shows your own level and "Target".
function ns.levelColor(level)
    local ok, c = pcall(GetCreatureDifficultyColor or GetQuestDifficultyColor, level)
    if ok and type(c) == "table" then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- the level beside the name: its point, the name box's point, which way its padding pushes
ns.TAG_SIDES = { left = { "RIGHT", "LEFT", -1, 0 }, right = { "LEFT", "RIGHT", 1, 0 },
    top = { "BOTTOM", "TOP", 0, 1 }, bottom = { "TOP", "BOTTOM", 0, -1 } }

-- a text's justification from its anchor point: SetJustifyH knows only LEFT, CENTER, RIGHT
function ns.justify(point)
    return point:find("LEFT") and "LEFT" or point:find("RIGHT") and "RIGHT" or "CENTER"
end

function ns.layoutTag(f)
    local c = db[f.mode].bars[f.key]
    local unit = UnitExists(f.unit) and f.unit
    local flags = c.tagOutline and "OUTLINE" or ""
    -- the level and the name: one font string each, in its own spot, on a frame that wraps it
    -- (padding all round) and wears its background
    for _, key in ipairs({ "tag_name", "tag_level" }) do
        if not f[key] then
            local box = CreateFrame("Frame", nil, f)
            local t = box:CreateFontString(nil, "OVERLAY")
            t:SetWordWrap(false)
            t.box, t.bg, t.mask = box, box:CreateTexture(nil, "BACKGROUND"), box:CreateMaskTexture()
            t.bg:SetAllPoints()
            t.mask:SetAllPoints(t.bg)
            f[key] = t
        end
    end
    -- The level beside the name, on the side the name starts from (left of a name on the left,
    -- right of one on the right): the level takes the name's spot and the name moves over.
    -- drinking: the name's place says so, flashing, even with the name itself turned off
    local drinking = (c.drinking.show and unit and ns.drinking(unit)) and true or false
    local eating = (c.eating.show and unit and ns.eating(unit)) and true or false
    local meal = drinking or eating -- the name's place says so, flashing
    local nameOn = c.tagName or meal
    local side = nameOn and ns.TAG_SIDES[c.tagAttach]
    local leads = side and c.tagLevel and ((c.tagAttach == "left" and ns.justify(c.nameAnchor) == "LEFT")
        or (c.tagAttach == "right" and ns.justify(c.nameAnchor) == "RIGHT"))
    -- both loose first: last pass one may hang on the other, and this pass the other way round,
    -- which the game refuses as a loop (seen in game)
    f.tag_name:ClearAllPoints()
    f.tag_level:ClearAllPoints()
    for _, which in ipairs({ "name", "level" }) do
        local lvl = which == "level"
        local t = f["tag_" .. which]
        local on = (lvl and c.tagLevel or not lvl and nameOn) and true or false
        t:SetShown(on)
        t.box:SetShown(on)
        local flash = on and not lvl and meal
        t.box:SetScript("OnUpdate", flash and function(self) self:SetAlpha(0.55 + 0.45 * math.cos(GetTime() * 6)) end or nil)
        if not flash then t.box:SetAlpha(1) end
        if on then
            if not t:SetFont(c.tagFont, c.tagSize, flags) then t:SetFont(FONTS[1][2], c.tagSize, flags) end
            local point, x, y, bg = c.tagAnchor, c.tagX, c.tagY, c.tagBg
            if not lvl then point, x, y, bg = c.nameAnchor, c.nameX, c.nameY, c.nameBg end
            t.box:SetFrameLevel(f:GetFrameLevel() + 7) -- over the resource bar
            t:ClearAllPoints()
            if leads and lvl then -- in the name's spot
                point = c.nameAnchor
                t:SetPoint(ns.FLIP_V[point] or point, f, point, c.nameX, c.nameY)
            elseif leads then -- the name after the level, as far from it as the level would be
                t:SetPoint(side[2], f.tag_level.box, side[1], -c.tagX - side[3] * bg.pad, -c.tagY - side[4] * bg.pad)
            elseif lvl and side then -- next to the name's box, its own padding clear of it
                t:SetPoint(side[1], f.tag_name.box, side[2], x + side[3] * bg.pad, y + side[4] * bg.pad)
            else -- top / bottom points: above / below the bar; left, right, center: in it
                t:SetPoint(ns.FLIP_V[point] or point, f, point, x, y)
            end
            t:SetJustifyH(ns.justify(point))
            if lvl then
                local level = unit and (UnitEffectiveLevel or UnitLevel)(unit) or UnitLevel("player")
                local kind = unit and UnitClassification and UnitClassification(unit)
                if readable(level) then
                    local r, g, b = 1, 0.1, 0.1
                    if level > 0 then r, g, b = ns.levelColor(level) end
                    t:SetTextColor(r, g, b, 1)
                    t:SetText(level <= 0 and "??" or level .. ((kind == "elite" or kind == "rareelite") and "+" or ""))
                else
                    t:SetText("")
                end
            else
                if meal then
                    t:SetTextColor(unpack((drinking and c.drinking or c.eating).color))
                    t:SetText(drinking and eating and "Eating & drinking!" or drinking and "Drinking!" or "Eating!")
                else
                    t:SetTextColor(unpack(c.tagNameColor))
                    pcall(t.SetText, t, unit and UnitName(unit) or "Target") -- a secret name still draws
                end
            end
            -- as wide as its text, up to the bar's width (then "..."); a secret name's width
            -- can't be read, so that one is never cut
            t:SetWidth(0)
            local w, most = t:GetStringWidth(), math.max(1, f.width - 2 * math.abs(x))
            if readable(w) and w > most then t:SetWidth(most) end
            t.box:ClearAllPoints()
            t.box:SetPoint("TOPLEFT", t, "TOPLEFT", -bg.pad, bg.pad)
            t.box:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", bg.pad, -bg.pad)
            t.bg:SetShown(bg.show and true or false)
            t.bg:SetColorTexture(unpack(bg.color))
            local h = c.tagSize + 2 * bg.pad -- the box's height, near enough, for the radius cap
            round(t.bg, t.mask, bg.radius == "pill" and math.huge or bg.radius, h * 2, h)
        end
    end
    ns.centerTag(f)
end

-- The name and what hangs beside it (the level, the PvP tag on the name or on that level) are
-- one row, aligned as a whole on the name's anchor: centered, or ending at the bar's right or
-- left edge. The name moves by what the other side adds (half of each, centered).
function ns.centerTag(f)
    local c, n = db[f.mode].bars[f.key], f.tag_name
    if not (n and n:IsShown()) then return end
    local j = ns.justify(c.nameAnchor)
    local left, right = 0, 0
    local side = ns.TAG_SIDES[c.tagAttach]
    local beside = side and side[4] == 0 and c.tagLevel and f.tag_level:IsShown() and side[3] or nil
    -- the level on the anchor's side takes the name's spot and starts the row itself
    if (beside == -1 and j == "LEFT") or (beside == 1 and j == "RIGHT") then return end
    if beside then
        local lw = f.tag_level:GetStringWidth()
        if not readable(lw) then return end
        -- its gap is an offset on the screen (right is +), so it widens the row on the right and
        -- narrows it on the left
        local adds = beside * c.tagX + lw + 2 * c.tagBg.pad
        if beside > 0 then right = right + adds else left = left + adds end
    end
    local pv, b = c.pvpIcon, f.pvpIcon
    if pv and b and b:IsShown() then
        local dir = ns.justify(pv.point) == "RIGHT" and 1 or ns.justify(pv.point) == "LEFT" and -1 or 0
        local on = pv.anchorTo == "name" or (pv.anchorTo == "level" and beside == dir)
        if on and dir > 0 then right = right + b:GetWidth() + pv.x end
        if on and dir < 0 then left = left + b:GetWidth() - pv.x end
    end
    local dx = j == "CENTER" and (left - right) / 2 or j == "RIGHT" and -right or left
    n:ClearAllPoints()
    n:SetPoint(ns.FLIP_V[c.nameAnchor] or c.nameAnchor, f, c.nameAnchor, c.nameX + dx, c.nameY)
end
-- a text on a top point sits on the bar (its bottom on the bar's top), on a bottom point under it
ns.FLIP_V = { TOP = "BOTTOM", TOPLEFT = "BOTTOMLEFT", TOPRIGHT = "BOTTOMRIGHT",
    BOTTOM = "TOP", BOTTOMLEFT = "TOPLEFT", BOTTOMRIGHT = "TOPRIGHT" }

------------------------------------------------------------------------------------------
-- Buffs and debuffs on the enemy health bar: what Blizzard's target frame shows. Every buff;
-- on an enemy only your own debuffs (on a friend, and on clients before Dragonflight, all of
-- them). Nothing is compared: what the game hands over goes straight to the icon, secret or not.
------------------------------------------------------------------------------------------
-- Where a group starts: a corner of what it hangs on, and which way is away from it (x, y).
-- grow: the way each next icon goes. wrap: the way a new line goes (across grow); "auto": away
-- from what it hangs on -- or, when the icons already grow away, along its edge, inward.
ns.AURA_SPOTS = {
    topleft = { "TOPLEFT", 0, 1 }, topright = { "TOPRIGHT", 0, 1 },
    bottomleft = { "BOTTOMLEFT", 0, -1 }, bottomright = { "BOTTOMRIGHT", 0, -1 },
    righttop = { "TOPRIGHT", 1, 0 }, lefttop = { "TOPLEFT", -1, 0 },
    -- centered: each line sits centered on the edge and grows out both ways at once
    topcenter = { "TOP", 0, 1 }, bottomcenter = { "BOTTOM", 0, -1 },
}
ns.AURA_GROW = { right = { 1, 0 }, left = { -1, 0 }, up = { 0, 1 }, down = { 0, -1 } }
-- the old one-in-all choices, as a start corner and a direction
ns.AURA_OLD_SPOTS = { above_right = { "topleft", "right" }, above_left = { "topright", "left" },
    below_right = { "bottomleft", "right" }, below_left = { "bottomright", "left" },
    right = { "righttop", "right" }, left = { "lefttop", "left" } }

-- The group's own corner (where its first icon sits), its grow and new-line directions, its spot
function ns.auraDirs(o)
    local old = ns.AURA_OLD_SPOTS[o.spot]
    if old then o.spot, o.grow = old[1], old[2] end
    local sp, g = ns.AURA_SPOTS[o.spot] or ns.AURA_SPOTS.topleft, ns.AURA_GROW[o.grow] or ns.AURA_GROW.right
    local centered = sp[1] == "TOP" or sp[1] == "BOTTOM"
    if centered then g = ns.AURA_GROW.right end -- lines run sideways; the spreading is done per line
    local w, wd = { sp[2], sp[3] }, ns.AURA_GROW[o.wrap or ""]
    if wd and wd[1] * g[1] + wd[2] * g[2] == 0 then -- new lines the way asked (across the growing)
        w = { wd[1], wd[2] }
    elseif g[1] * sp[2] + g[2] * sp[3] ~= 0 then -- growing straight away (or back): new lines go along
        w = sp[3] ~= 0 and { sp[1]:find("LEFT") and 1 or -1, 0 } or { 0, -1 }
    end
    local hx, vy = g[1] ~= 0 and g[1] or w[1], g[2] ~= 0 and g[2] or w[2]
    if centered then return vy > 0 and "BOTTOM" or "TOP", g, w, sp end
    return (vy > 0 and "BOTTOM" or "TOP") .. (hx > 0 and "LEFT" or "RIGHT"), g, w, sp
end

function ns.debuffFilter(unit)
    if unit == "player" or select(4, GetBuildInfo()) < 100000 then return "HARMFUL" end
    local ok, enemy = pcall(function() return UnitCanAttack("player", unit) and true or false end)
    return (ok and enemy) and "HARMFUL|PLAYER" or "HARMFUL"
end

-- Up to max auras, or nil when the game refuses to say (the icons then stay as they are).
function ns.auraList(unit, filter, max)
    local out = {}
    for i = 1, 40 do
        if #out >= max then break end
        local a
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok then return nil end
            a = d
        elseif UnitAura then -- older clients: plain values
            local name, icon, count, _, duration, expires = UnitAura(unit, i, filter)
            a = name and { name = name, icon = icon, applications = count, duration = duration,
                expirationTime = expires }
        end
        if type(a) ~= "table" then break end
        out[#out + 1] = a
    end
    return out
end

-- Stand-ins while the options are open: as many as the group can hold, with running timers and
-- a stack count here and there, so size, zoom, timer text and the grid can all be judged.
ns.DUMMY_ICONS = {
    buffs = { "Spell_Holy_WordFortitude", "Spell_Nature_Regeneration", "Spell_Holy_MagicalSentry",
        "Spell_Holy_PowerWordShield" },
    debuffs = { "Spell_Shadow_ShadowWordPain", "Spell_Shadow_CurseOfSargeras", "Spell_Frost_FrostShock",
        "Ability_Warrior_Sunder" },
}
function ns.dummyAuras(k, max)
    local out, icons, now = {}, ns.DUMMY_ICONS[k], GetTime()
    for i = 1, max do
        out[i] = { icon = "Interface\\Icons\\" .. icons[(i - 1) % #icons + 1], duration = 60,
            expirationTime = now + 60 - i * 7 % 60, applications = i % 3 == 0 and 3 or nil }
    end
    return out
end

-- a = nil: a plain question mark
function ns.drawAura(b, unit, a)
    pcall(b.tex.SetTexture, b.tex, a and a.icon or 134400)
    b.count:SetText("")
    pcall(b.cd.Clear, b.cd)
    if not a then return end
    local id = a.auraInstanceID
    local timed = id and C_UnitAuras.GetAuraDuration and pcall(function()
        b.cd:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration(unit, id))
    end)
    if not timed and readable(a.duration) and readable(a.expirationTime) and a.duration > 0 then
        b.cd:SetCooldown(a.expirationTime - a.duration, a.duration)
    end
    if id and C_UnitAuras.GetAuraApplicationDisplayCount then
        pcall(function() b.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit, id, 2, 99)) end)
    elseif readable(a.applications) and a.applications > 1 then
        b.count:SetText(a.applications)
    end
end

-- The center line: across the middle of the bar (or of the bar with its pet / target of target).
-- A group sits on it with its bottom edge (above it), its center, or its top edge (below it),
-- gap away; on the side its start corner says. Alone there (the other group empty), centered.
ns.LINE_SIDES = { righttop = { "LEFT", "RIGHT" }, lefttop = { "RIGHT", "LEFT" }, topleft = { "LEFT", "LEFT" },
    bottomleft = { "LEFT", "LEFT" }, topright = { "RIGHT", "RIGHT" }, bottomright = { "RIGHT", "RIGHT" },
    topcenter = { "", "CENTER" }, bottomcenter = { "", "CENTER" } }
function ns.linePlace(o, alone, gap)
    local side = ns.LINE_SIDES[o.spot] or ns.LINE_SIDES.righttop
    local edge, v, dy = alone and "center" or o.lineEdge, "", 0
    if edge == "top" then v, dy = "TOP", -gap elseif edge == "bottom" then v, dy = "BOTTOM", gap end
    local gp = v .. side[1]
    return gp == "" and "CENTER" or gp, side[2], o.x, o.y + dy
end

-- Each group lives in a box as big as its icons; the box hangs on the bar or on the other
-- group's box. Both on each other would hang in the air, so then buffs take the bar. One that
-- hangs on an empty group borrows that group's own anchor on the bar while it is empty: the
-- game draws nothing that hangs on a frame of no size (seen in game).
ns.AURA_BARS = { health = true, enemyhealth = true }
function ns.layoutAuras(f)
    local c = db[f.mode].bars[f.key]
    local unit = f.key == "health" and "player" or (UnitExists(f.unit) and f.unit)
    f.auraIcons = f.auraIcons or { buffs = {}, debuffs = {} }
    f.auraBoxes = f.auraBoxes or { buffs = CreateFrame("Frame", nil, f), debuffs = CreateFrame("Frame", nil, f) }
    -- with target of target hung on enemy health, or your pet on your health, "the bar" is the
    -- two together (a pet on the left starts the block)
    local host, other = f, nil
    if f.mode == "regular" and f.key == "enemyhealth" and ns.totPlaced() then other = frames.tothealth end
    if f.mode == "regular" and f.key == "health" and ns.petPlaced() then other = frames.pethealth end
    if other then
        local first = (other == frames.pethealth and db.regular.bars.pethealth.anchor == "left") and other or f
        f.span = f.span or CreateFrame("Frame", nil, f)
        f.span:ClearAllPoints()
        f.span:SetPoint("TOPLEFT", first, "TOPLEFT")
        f.span:SetPoint("BOTTOMRIGHT", first == f and other or f, "BOTTOMRIGHT")
        host = f.span
    end
    for _, k in ipairs({ "buffs", "debuffs" }) do
        local o, icons, box = c[k], f.auraIcons[k], f.auraBoxes[k]
        local corner, g, w = ns.auraDirs(o)
        local step = o.size + c.auraGap
        local across = g[1] ~= 0 -- growing sideways: a line is a row; up or down: a column
        local per = across and o.cols or o.rows
        local max = math.min(o.max, o.cols * o.rows)
        local list = {}
        -- the options are open: a full grid to tune it by (never on a real nameplate)
        local dummy = o.show and ns.previewing() and not f.plate
        if dummy then
            list = ns.dummyAuras(k, max)
        elseif o.show and unit then
            list = ns.auraList(unit, k == "buffs" and "HELPFUL" or ns.debuffFilter(unit), max)
        end
        -- the game refusing (in combat) right after the preview: no stand-ins left behind
        if not list and box.dummy then list = {} end
        box.dummy = dummy
        if list then -- nil: the game refused, the icons stay as they are
            local n = math.min(#list, max)
            local file = ns.ICON_MASKS[o.radius]
            for i = 1, math.max(n, #icons) do
                local b = icons[i]
                if not b and i <= n then
                    b = CreateFrame("Frame", nil, box)
                    b.tex = b:CreateTexture(nil, "ARTWORK")
                    b.tex:SetAllPoints()
                    b.mask = b:CreateMaskTexture()
                    b.mask:SetAllPoints(b.tex)
                    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
                    b.cd:SetAllPoints()
                    b.cd:SetReverse(true)
                    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
                    icons[i] = b
                end
                if b then
                    b:SetShown(i <= n)
                    if i <= n then
                        local a, l = (i - 1) % per, math.floor((i - 1) / per) -- place in its line, which line
                        if corner == "TOP" or corner == "BOTTOM" then -- centered: its line spread evenly both ways
                            a = a - (math.min(per, n - l * per) - 1) / 2
                        end
                        b:SetSize(o.size, o.size)
                        b:SetFrameLevel(f:GetFrameLevel() + 6)
                        b:ClearAllPoints()
                        b:SetPoint(corner, box, corner, (g[1] * a + w[1] * l) * step, (g[2] * a + w[2] * l) * step)
                        -- zoom: the share cut from each side of the picture (8: just its own border)
                        local z = (o.zoom or 8) / 100
                        ns.iconCorners(b.tex, b.mask, o.radius, { z, 1 - z, z, 1 - z })
                        -- the swipe takes the icon's shape too
                        b.cd:SetSwipeTexture(file and "Interface\\AddOns\\WolfpackAddon\\Media\\Icon\\"
                            .. file .. ".tga" or "Interface\\Buttons\\WHITE8X8")
                        b.cd:SetSwipeColor(0, 0, 0, 0.7)
                        b.cd:SetHideCountdownNumbers(o.hideTimer and true or false)
                        ns.drawAura(b, unit, list[i] or nil)
                    end
                end
            end
            local along, lines = math.min(n, per) * step - c.auraGap, math.ceil(n / per) * step - c.auraGap
            box:SetSize(n > 0 and (across and along or lines) or 1, n > 0 and (across and lines or along) or 1)
            box.n = n
        end
    end
    -- both loose first: either may still hang on the other from last time (a loop, refused)
    f.auraBoxes.buffs:ClearAllPoints()
    f.auraBoxes.debuffs:ClearAllPoints()
    for _, k in ipairs({ "buffs", "debuffs" }) do -- now that both know how many they hold
        local o, box = c[k], f.auraBoxes[k]
        local other = k == "buffs" and "debuffs" or "buffs"
        local corner, _, _, sp = ns.auraDirs(o)
        local toOther = o.anchorTo == "other" and not (k == "buffs" and c.debuffs.anchorTo == "other")
        local into = f.auraBoxes[other]
        local alone = (into.n or 0) == 0
        if o.anchorTo == "line" then -- on the center line; alone on it, centered
            local gp, hp, x, y = ns.linePlace(o, alone, c.auraLineGap or 0)
            box:SetPoint(gp, host, hp, x, y)
        elseif toOther and alone and c[other].anchorTo == "line" then -- the empty one's place on the line
            local gp, hp, x, y = ns.linePlace(c[other], true, 0)
            box:SetPoint(gp, host, hp, x, y)
        elseif toOther and alone then -- the empty group's anchor (it hangs on the bar)
            local _, _, _, osp = ns.auraDirs(c[other])
            box:SetPoint(corner, host, osp[1], c[other].x, c[other].y)
        else
            local gap = toOther and c.auraGroupGap or 0 -- away from the group it hangs on
            box:SetPoint(corner, toOther and into or host, sp[1], o.x + sp[2] * gap, o.y + sp[3] * gap)
        end
    end
end

------------------------------------------------------------------------------------------
-- Small icons on the bars: PvP flag and drinking on enemy health, status (combat / rested)
-- and your PvP flag on your health
------------------------------------------------------------------------------------------
-- Combat icon art: an atlas or a file (with a crop). Rested: the Zzz from the same state icon.
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

local REST_ART = { file = 130936, coords = { 0, 0.5, 0, 0.421875 } } -- Interface/CHARACTERFRAME/UI-StateIcon
ns.BADGES = { health = { "statusIcon", "pvpIcon" }, enemyhealth = { "pvpIcon" } }
-- the badge's own point that meets a point of the name / level box, so it sits outside on that side
ns.OPPOSITE = { TOPLEFT = "BOTTOMRIGHT", TOP = "BOTTOM", TOPRIGHT = "BOTTOMLEFT", LEFT = "RIGHT", CENTER = "CENTER",
    RIGHT = "LEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOM = "TOP", BOTTOMRIGHT = "TOPLEFT" }
-- looks for the PvP icon: a file (or one per faction, FFA for free-for-all) and its crop
ns.PVP_STYLES = {
    faction = { file = "Interface\\TargetingFrame\\UI-PVP-%s", coords = { 0, 0.62, 0, 0.62 } },
    banner = { Alliance = "Interface\\Icons\\INV_BannerPVP_02", Horde = "Interface\\Icons\\INV_BannerPVP_01",
        FFA = "Interface\\Icons\\INV_BannerPVP_01", coords = { 0.08, 0.92, 0.08, 0.92 } },
    swords = { file = "Interface\\WorldStateFrame\\CombatSwords", coords = { 0, 0.5, 0, 0.5 } },
    skull = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", coords = { 0, 1, 0, 1 } },
}

-- "Alliance", "Horde" or "FFA" while the unit is flagged, else nil
function ns.pvpFlag(unit)
    local ok, ffa = pcall(UnitIsPVPFreeForAll, unit)
    if ok and readable(ffa) and ffa then return "FFA" end
    local ok2, on = pcall(UnitIsPVP, unit)
    if not (ok2 and readable(on) and on) then return end
    local faction = UnitFactionGroup(unit)
    return (faction == "Alliance" or faction == "Horde") and faction or "FFA"
end

-- Whether it is drinking: a buff called Drink, Food & Drink or Refreshment (or the game's own
-- name for Drink in this language). A name the game keeps secret can't be told: not drinking.
function ns.hasBuffNamed(unit, names, spellID)
    names = setmetatable({}, { __index = names })
    local ok, own = pcall(function() return C_Spell and C_Spell.GetSpellName(spellID) or GetSpellInfo(spellID) end)
    if ok and type(own) == "string" then rawset(names, own:lower(), true) end
    for _, a in ipairs(ns.auraList(unit, "HELPFUL", 40) or {}) do
        if readable(a.name) and type(a.name) == "string" and names[a.name:lower()] then return true end
    end
    return false
end
function ns.drinking(unit)
    return ns.hasBuffNamed(unit, { drink = true, ["food & drink"] = true, refreshment = true }, 430)
end
-- Eating: a buff called Food, Food & Drink or Refreshment (or the game's own name for Food).
function ns.eating(unit)
    return ns.hasBuffNamed(unit, { food = true, ["food & drink"] = true, refreshment = true }, 433)
end

-- A text one letter per font string, side by side, so each can fade on its own: a wave of
-- fading in and out runs along it while o.restWave is on. Up to 16 letters (UTF-8 aware).
function ns.waveLetters(b)
    local t = GetTime()
    for i = 1, b.waveN do b.letters[i]:SetAlpha(0.15 + 0.85 * (0.5 + 0.5 * math.sin(t * 3 - i * 0.7))) end
end

function ns.layoutLetters(b, str, c, o)
    b.letters = b.letters or {}
    local n, x = 0, 0
    if str then
        local flags = c.outline and "OUTLINE" or ""
        for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            if n == 16 then break end
            n = n + 1
            local l = b.letters[n] or b:CreateFontString(nil, "OVERLAY")
            b.letters[n] = l
            if not l:SetFont(c.font, c.fontSize, flags) then l:SetFont(FONTS[1][2], c.fontSize, flags) end
            l:SetTextColor(unpack(o.restColor))
            l:SetText(ch)
            l:ClearAllPoints()
            l:SetPoint("LEFT", b, "LEFT", x, 0)
            l:SetAlpha(1)
            l:Show()
            local w = l:GetStringWidth()
            x = x + (readable(w) and w or c.fontSize * 0.6)
        end
        b:SetSize(math.max(1, x), c.fontSize)
    end
    for i = n + 1, #b.letters do b.letters[i]:Hide() end
    b.waveN = n
    b:SetScript("OnUpdate", (str and n > 0 and o.restWave) and ns.waveLetters or nil)
end

function ns.layoutBadges(f)
    local c = db[f.mode].bars[f.key]
    local unit = f.key == "health" and "player" or (UnitExists(f.unit) and f.unit)
    local preview = ns.previewing()
    for _, k in ipairs(ns.BADGES[f.key]) do
        local o, b = c[k], f[k]
        if not b then
            b = CreateFrame("Frame", nil, f)
            b.tex = b:CreateTexture(nil, "OVERLAY")
            b.tex:SetAllPoints()
            b.text = b:CreateFontString(nil, "OVERLAY")
            b.text:SetPoint("CENTER")
            f[k] = b
        end
        local art, text, letters -- art: { file, coords } or a combat icon style; text: PvP; letters: resting
        if not o.show then
            art = nil
        elseif k == "pvpIcon" then
            local flag = unit and ns.pvpFlag(unit) or (preview and (UnitFactionGroup("player") or "FFA"))
            local st = ns.PVP_STYLES[o.style] or ns.PVP_STYLES.faction
            if flag and o.style == "text" then
                text = o.text
            elseif flag then
                art = { file = st[flag] or (st.file and st.file:format(flag)) or st.Horde, coords = st.coords }
            end
        elseif ns.inCombat then
            art = o.style
        elseif o.rested and IsResting() then
            if o.restStyle == "text" then letters = o.restText or "" else art = REST_ART end
        elseif preview then -- status: shown while placing it, for placing it
            art = o.style
        end
        b:SetShown(art ~= nil or text ~= nil or letters ~= nil)
        b.tex:SetShown(art ~= nil)
        b.text:SetShown(text ~= nil)
        ns.layoutLetters(b, letters, c, o)
        if art or text or letters then
            if letters then
                -- sized by layoutLetters
            elseif text then -- the font and size of the name on enemy health, of the bar's text on yours
                local font, size, outline = c.font, c.fontSize, c.outline
                if f.key == "enemyhealth" then font, size, outline = c.tagFont, c.tagSize, c.tagOutline end
                local flags = outline and "OUTLINE" or ""
                if not b.text:SetFont(font, size, flags) then b.text:SetFont(FONTS[1][2], size, flags) end
                b.text:SetTextColor(unpack(o.textColor))
                b.text:SetText(text)
                local w = b.text:GetStringWidth()
                b:SetSize(readable(w) and math.max(1, w) or size, size)
            else
                if type(art) == "string" then setCombatArt(b.tex, art)
                else
                    b.tex:SetTexture(art.file)
                    b.tex:SetTexCoord(unpack(art.coords))
                end
                b:SetSize(o.size, o.size)
            end
            b:SetFrameLevel(f:GetFrameLevel() + 8)
            b:ClearAllPoints()
            -- on the bar, centered on its point; or outside the name / level, on that side of it
            local host = (o.anchorTo == "name" and f.tag_name) or (o.anchorTo == "level" and f.tag_level)
            if host and host:IsShown() then
                b:SetPoint(ns.OPPOSITE[o.point] or "CENTER", host.box, o.point, o.x, o.y)
            else
                b:SetPoint("CENTER", f, o.point, o.x, o.y)
            end
        end
    end
    if f.tag_name then ns.centerTag(f) end -- a PvP tag beside the name widens the row
end

------------------------------------------------------------------------------------------
-- Target of target, hung on enemy health (your Combat Display only; on nameplates it stacks)
------------------------------------------------------------------------------------------
function ns.totPlaced()
    local t = db.regular.bars.tothealth
    return (t.show and t.anchor ~= "stack" and (UnitExists("targettarget") or ns.previewing())) and true or false
end
function ns.totBelow() return ns.totPlaced() and db.regular.bars.tothealth.anchor == "below" end
function ns.totShare() return db.regular.bars.tothealth.height + db.regular.gap end -- what it takes below

-- the ammo bar beside the power bar (your Combat Display only)
function ns.ammoBeside()
    local a = db.regular.bars.ammo
    return (a.show and a.anchor ~= "stack" and BARS.ammo.state()) and true or false
end

-- your pet, hung on your health
function ns.petPlaced()
    local c = db.regular.bars.pethealth
    return (c.show and c.anchor ~= "stack" and (UnitExists("pet") or ns.previewing())) and true or false
end
function ns.petBelow() return ns.petPlaced() and db.regular.bars.pethealth.anchor == "below" end

-- Below your health it is part of the stack: placed right under it, as wide as it is; returns
-- the room it takes.
function ns.petUnder(hf)
    if not ns.petBelow() then return 0 end
    local c, pf, gap = db.regular.bars.pethealth, frames.pethealth, db.regular.gap
    pf:Show()
    layoutBar(pf, 1, hf.width)
    pf:ClearAllPoints()
    pf:SetPoint("TOPLEFT", hf, "BOTTOMLEFT", 0, -gap)
    ns.fill(pf)
    ns.layoutHappy(pf)
    return gap + c.height
end

function ns.placePet()
    local c, pf, hf, gap = db.regular.bars.pethealth, frames.pethealth, frames.health, db.regular.gap
    if c.anchor == "stack" then return end
    local on = (ns.petPlaced() and hf:IsShown()) and true or false
    pf:SetShown(on)
    if not on or c.anchor == "below" then return end -- below: the stack placed it
    layoutBar(pf, 1, c.width, { height = hf:GetHeight() }) -- your health's height, its own width
    pf:ClearAllPoints()
    if c.anchor == "left" then
        pf:SetPoint("TOPRIGHT", hf, "TOPLEFT", -gap, 0)
    else
        pf:SetPoint("TOPLEFT", hf, "TOPRIGHT", gap, 0)
    end
    ns.fill(pf)
    ns.layoutHappy(pf)
end

function ns.placeToT()
    local c, tf, ef = db.regular.bars.tothealth, frames.tothealth, frames.enemyhealth
    if c.anchor == "stack" then return end
    local on = (ns.totPlaced() and ef:IsShown()) and true or false
    tf:SetShown(on)
    if not on then return end
    local gap = db.regular.gap
    tf:ClearAllPoints()
    if c.anchor == "below" then -- enemy health's width, its own height
        layoutBar(tf, 1, ef.width)
        tf:SetPoint("TOPLEFT", ef, "BOTTOMLEFT", 0, -gap)
    else -- enemy health's height, its own width
        layoutBar(tf, 1, c.width, { height = ef:GetHeight() })
        tf:SetPoint("TOPLEFT", ef, "TOPRIGHT", gap, 0)
    end
    ns.fill(tf)
    ns.layoutTag(tf)
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

-- The modern clients list quests in C_QuestLog; Anniversary (2.5) and Classic Era (1.15) still
-- have the old global calls, whose objectives are text like "Boar Flank: 2/6".
local function scanQuestLog()
    wipe(objectiveInfo)
    local Q = C_QuestLog or {}
    local count = Q.GetNumQuestLogEntries or GetNumQuestLogEntries
    if not count then return end
    for i = 1, count() or 0 do
        local header, questID
        if Q.GetInfo then
            local info = Q.GetInfo(i)
            header, questID = not info or info.isHeader, info and info.questID
        else
            local _
            _, _, _, header, _, _, _, questID = GetQuestLogTitle(i)
        end
        if not header then
            local objectives = Q.GetQuestObjectives and questID and Q.GetQuestObjectives(questID)
            if not objectives and GetNumQuestLeaderBoards then
                objectives = {}
                for j = 1, GetNumQuestLeaderBoards(i) or 0 do
                    local text, kind, finished = GetQuestLogLeaderBoard(j, i)
                    local have, need = (text or ""):match("(%d+)%s*/%s*(%d+)")
                    objectives[j] = { text = text, type = kind, finished = finished,
                        numFulfilled = tonumber(have), numRequired = tonumber(need) }
                end
            end
            for _, o in ipairs(objectives or {}) do
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
    -- the icons are read off the unit's tooltip data, which older clients don't hand to addons
    if not (C_TooltipInfo and LINE and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest) then
        return nil, nil, {}
    end
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

-- Where a quest icon sits on what it hangs on: { label, its point, that element's point }
ns.QUEST_SPOTS = { inside = { "Inside, top right", "TOPRIGHT", "TOPRIGHT" },
    insideleft = { "Inside, top left", "TOPLEFT", "TOPLEFT" }, center = { "Centered on it", "CENTER", "CENTER" },
    above = { "Above, right end", "BOTTOMRIGHT", "TOPRIGHT" }, aboveleft = { "Above, left end", "BOTTOMLEFT", "TOPLEFT" },
    abovecenter = { "Above, centered", "BOTTOM", "TOP" },
    right = { "Right of it", "LEFT", "RIGHT" }, left = { "Left of it", "RIGHT", "LEFT" },
    below = { "Below, right end", "TOPRIGHT", "BOTTOMRIGHT" }, belowleft = { "Below, left end", "TOPLEFT", "BOTTOMLEFT" },
    belowcenter = { "Below, centered", "TOP", "BOTTOM" } }
ns.QUEST_SPOT_ORDER = { "inside", "insideleft", "center", "above", "aboveleft", "abovecenter", "right", "left",
    "below", "belowleft", "belowcenter" }
-- what a quest icon can hang on (besides the other quest icon)
ns.QUEST_ANCHORS = { { "Health bar", "bar" }, { "Power bar", "res" }, { "Cast bar", "cast" }, { "Name", "name" },
    { "Level", "level" }, { "Buffs", "buffs" }, { "Debuffs", "debuffs" }, { "PvP icon", "pvp" } }

-- The element `to` of our nameplate under holder h; our bar itself when that one is hidden or
-- empty (the cast bar between casts), and Blizzard's whole plate when ours is off.
function ns.questElement(h, to)
    local f = h.ownBar or (ns.np and ns.np.bars[h.plate])
    if not (f and f:IsShown()) then return h end
    local boxes = f.auraBoxes or {}
    local e = ({ res = f.resFrame, cast = f.castBar, name = f.tag_name and f.tag_name.box,
        level = f.tag_level and f.tag_level.box, pvp = f.pvpIcon, buffs = boxes.buffs, debuffs = boxes.debuffs })[to]
    if e and (to == "buffs" or to == "debuffs") and (e.n or 0) == 0 then e = nil end
    return (e and e:IsShown()) and e or f
end

-- Nameplates are recycled, so each plate keeps one icon holder; plateUnits maps the units
-- currently on screen to their holder.
local questHolders, plateUnits = {}, {}
ns.plateUnits = plateUnits

-- Each icon hangs on its own element. One hung on the other icon while that one isn't shown
-- takes the other's place; both on each other would hang in the air, so then the sword takes
-- the bar.
local function styleQuest(h)
    local q = db.quest
    -- settings open: every plate shows both icons (and counts), to place them by
    local want, left = h.want, h.left
    if ns.configOpen then want, left = ns.QUEST_DUMMY.want, ns.QUEST_DUMMY.left end
    for _, kind in ipairs(QUEST_ORDER) do
        local c, t = q[kind], h[kind]
        t:SetTexture(c.icon)
        t:SetDesaturated(want[kind] == "party") -- groupmates need it, you don't: grayscale
        t:SetSize(c.size, c.size)
        t:SetShown((want[kind] and c.show) and true or false)
    end
    for _, kind in ipairs(QUEST_ORDER) do
        local c, t = q[kind], h[kind]
        local other = kind == "kill" and "loot" or "kill"
        local o = q[other]
        local toOther = c.anchorTo == "other" and not (kind == "kill" and o.anchorTo == "other")
        local spot = ns.QUEST_SPOTS[c.spot] or ns.QUEST_SPOTS.inside
        t:ClearAllPoints()
        if toOther and h[other]:IsShown() then
            t:SetPoint(spot[2], h[other], spot[3], c.x, c.y)
        elseif toOther then
            local os = ns.QUEST_SPOTS[o.spot] or ns.QUEST_SPOTS.inside
            t:SetPoint(os[2], ns.questElement(h, o.anchorTo), os[3], o.x, o.y)
        else
            t:SetPoint(spot[2], ns.questElement(h, c.anchorTo), spot[3], c.x, c.y)
        end
        local badge, count = h.badge[kind], left[kind]
        local showCount = (t:IsShown() and c.count and count and count > 0) and true or false
        badge.text:SetShown(showCount)
        badge.bg:SetShown(showCount)
        if showCount then
            local text = badge.text
            if not text:SetFont(c.font, c.fontSize, "OUTLINE") then text:SetFont(FONTS[1][2], c.fontSize, "OUTLINE") end
            text:SetTextColor(unpack(c.textColor))
            text:SetText(count)
            -- the plate fits the number: wider for "12" than for "3", taller for a bigger font
            local w, ht = text:GetStringWidth() + 2 * c.pad, text:GetStringHeight() + 2 * c.pad
            local cs = ns.QUEST_SPOTS[c.countSpot] or ns.QUEST_SPOTS.abovecenter
            badge.bg:ClearAllPoints()
            badge.bg:SetPoint(cs[2], t, cs[3], c.countX, c.countY)
            badge.bg:SetSize(w, ht)
            badge.bg:SetColorTexture(unpack(c.bg))
            round(badge.bg, badge.mask, c.radius == "pill" and math.huge or c.radius, w, ht)
        end
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
        h = ns.questHolder(plate)
        h.plate = plate
        questHolders[plate] = h
    end
    h.want.kill, h.want.loot = nil, nil
    h.left.kill, h.left.loot = nil, nil
    plateUnits[unit] = h
    evalQuest(unit)
end

-- the quest icons' frame, over the whole of `parent` (a nameplate, or the preview plate)
function ns.questHolder(parent)
    local h = CreateFrame("Frame", nil, parent)
    do
        h:SetAllPoints()
        h:SetFrameLevel(parent:GetFrameLevel() + 10)
        h.kill, h.loot, h.want, h.left = h:CreateTexture(nil, "OVERLAY"), h:CreateTexture(nil, "OVERLAY"), {}, {}
        h.badge = {}
        for _, kind in ipairs(QUEST_ORDER) do -- small "how many left" plate above the icon
            local bg = h:CreateTexture(nil, "OVERLAY", nil, 1)
            local text = h:CreateFontString(nil, "OVERLAY", nil, 2)
            local mask = h:CreateMaskTexture()
            text:SetPoint("CENTER", bg) -- the plate is placed; the number sits in its middle
            mask:SetAllPoints(bg)
            h.badge[kind] = { bg = bg, text = text, mask = mask }
        end
    end
    return h
end
-- what every row shows while the settings are open
ns.QUEST_DUMMY = { want = { kill = "mine", loot = "mine" }, left = { kill = 3, loot = 2 } }

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
        if key == "enemyhealth" and c.beside and L == db.regular then shown = false end -- Refresh places it
        if key == "experience" and c.hideInCombat and ns.inCombat and not ns.previewing() then shown = false end
        -- hung on another bar (your Combat Display only): placed with that bar, or by Refresh
        local hung = L == db.regular and (key == "tothealth" or key == "pethealth" or key == "ammo")
            and c.anchor ~= "stack"
        if key == "swing" then -- one row per ticked weapon, sharing this bar's settings
            for i, kind in ipairs(SWING_TYPES) do
                local sf = swings[i]
                local rowShown = (shown and c[kind[1]] and (swingActive(kind[3]) or ns.previewing())) and true or false
                sf:SetShown(rowShown)
                if rowShown then
                    layoutBar(sf, 1)
                    ns.fill(sf)
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
        if hung then shown = false else f:SetShown(shown) end
        if shown then
            -- f.split: the player health bar shares its width with the enemy health bar
            -- target of target below enemy health: the two share enemy health's slot
            local over = key == "enemyhealth" and L == db.regular and ns.totBelow()
                and { height = math.max(2, c.height - ns.totShare()) } or nil
            -- the ammo bar beside the power bar: the two share its width
            local ammo = key == "power" and L == db.regular and ns.ammoBeside()
            local aw = ammo and math.min(L.bars.ammo.width, c.width - L.gap - 1) or 0
            local width = f.split and (c.width - L.gap) / 2 or (ammo and c.width - aw - L.gap) or nil
            layoutBar(f, n, width, over)
            ns.fill(f)
            if h > 0 then h = h + L.gap end
            h = h + c.padTop
            f:ClearAllPoints()
            if f.split then
                f:SetPoint("TOPLEFT", container, "TOP", c.x - c.width / 2, c.y - h)
            elseif ammo then
                local left = c.x - c.width / 2
                local af = frames.ammo
                af:Show()
                layoutBar(af, 1, aw, { height = c.height })
                af:ClearAllPoints()
                if L.bars.ammo.anchor == "left" then
                    af:SetPoint("TOPLEFT", container, "TOP", left, c.y - h)
                    f:SetPoint("TOPLEFT", container, "TOP", left + aw + L.gap, c.y - h)
                else
                    f:SetPoint("TOPLEFT", container, "TOP", left, c.y - h)
                    af:SetPoint("TOPLEFT", f, "TOPRIGHT", L.gap, 0)
                end
                ns.fill(af)
            else
                f:SetPoint("TOP", container, "TOP", c.x, c.y - h)
            end
            if f.resFrame or key == "tothealth" then ns.layoutTag(f) end
            if f.resFrame then ns.layoutRes(f) end
            if ns.AURA_BARS[key] then ns.layoutAuras(f) end
            if ns.BADGES[key] then ns.layoutBadges(f) end
            if key == "pethealth" then ns.layoutHappy(f) end
            if ns.MEAL_TEXTS[key] then ns.layoutMealText(f) end
            h = h + c.height
            if key == "health" and L == db.regular then h = h + ns.petUnder(f) end -- your pet below it
            h = h + c.padBottom
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
-- Blizzard unit frames hidden by parking them under `hider`: the option for each, and where it
-- was before (to give it back). Never touched unless asked.
-- The experience bar: the status bar holder on modern clients (it also holds reputation and
-- honor), the bar itself on classic ones (and the plain bar shown in its place at the top level).
ns.unitFrameHides = { { "PlayerFrame", "hidePlayerFrame" }, { "TargetFrame", "hideTargetFrame" },
    { "MainStatusTrackingBarContainer", "hideXPBar" }, { "StatusTrackingBarManager", "hideXPBar" },
    { "MainMenuExpBar", "hideXPBar" }, { "MainMenuBarMaxLevelBar", "hideXPBar" } }
for _, name in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
    "MultiBar5", "MultiBar6", "MultiBar7" }) do
    table.insert(ns.unitFrameHides, { name, "hideActionBars" })
end
if MainMenuBarArtFrame then -- classic: the main bar also holds bags and menu, so only its buttons and art go
    for i = 1, 12 do table.insert(ns.unitFrameHides, { "ActionButton" .. i, "hideActionBars" }) end
    for _, name in ipairs({ "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
        "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "ActionBarUpButton", "ActionBarDownButton",
        "MainMenuBarPageNumber" }) do
        table.insert(ns.unitFrameHides, { name, "hideActionBars" })
    end
else
    table.insert(ns.unitFrameHides, { "MainActionBar", "hideActionBars" })
    table.insert(ns.unitFrameHides, { "MainMenuBar", "hideActionBars" })
end
for _, u in ipairs({ { "StanceBar", "hideStanceBar" }, { "StanceBarFrame", "hideStanceBar" },
    { "ShapeshiftBarFrame", "hideStanceBar" }, { "PetActionBar", "hidePetBar" }, { "PetActionBarFrame", "hidePetBar" } }) do
    table.insert(ns.unitFrameHides, u)
end
ns.unitFrameParents = {}
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
    local seen = {} -- one frame under two names (MainMenuBar / MainActionBar): handled once
    for _, u in ipairs(ns.unitFrameHides) do
        local frame, hide = _G[u[1]], db.regular[u[2]] and true or false
        local was = ns.unitFrameParents[u[1]]
        local dup = frame and seen[frame]
        if frame then seen[frame] = true end
        if frame and not dup and hide ~= (was ~= nil) then
            if hide then ns.unitFrameParents[u[1]] = frame:GetParent() end
            frame:SetParent(hide and hider or was)
            if not hide then ns.unitFrameParents[u[1]] = nil end
        end
    end
    ns.syncClickers()
    ns.syncActionBars()
end

------------------------------------------------------------------------------------------
-- Action bars: secure buttons of the game's own action button template, built, placed and
-- bound out of combat only (the game allows nothing else). ponytail: laid out on every
-- refresh out of combat; cheap enough, and nothing to keep in step.
------------------------------------------------------------------------------------------
ns.ab = { frames = {}, buttons = {}, owner = CreateFrame("Frame") }

-- The slots bar i may use: from its first up to the next bar's first.
function ns.abRoom(i)
    local bars = db.actionbars.bars
    local b, limit = bars[i], ns.AB_POOL + 1
    for _, o in ipairs(bars) do
        if o.first > b.first and o.first < limit then limit = o.first end
    end
    return limit - b.first
end
function ns.abCount(i)
    local b = db.actionbars.bars[i]
    return math.max(0, math.min(b.rows * b.cols, ns.abRoom(i)))
end

-- A new bar on the first free slot, 12 wide or as much as fits there; nil when the pool is used up.
function ns.abNew()
    local bars = db.actionbars.bars
    for slot = 1, ns.AB_POOL do
        local taken = false
        for i, b in ipairs(bars) do
            if slot >= b.first and slot < b.first + ns.abCount(i) then taken = true end
        end
        if not taken then
            local bar = merge({ first = slot, y = 60 + 44 * #bars }, ns.AB_BAR)
            bars[#bars + 1] = bar
            bar.cols = math.min(12, ns.abRoom(#bars))
            return #bars
        end
    end
end

function ns.abUsed()
    local n = 0
    for i in ipairs(db.actionbars.bars) do n = n + ns.abCount(i) end
    return n
end

-- A key as short as fits a button: SHIFT-1 -> S1, META-E -> ME, BUTTON4 -> B4
function ns.abKeyText(slot)
    local key = db.actionbars.binds[tostring(slot)]
    if not key then return "" end
    -- M: the Mac's Command key, so mouse buttons are B (BUTTON4 -> B4)
    return (key:gsub("ALT%-", "A"):gsub("CTRL%-", "C"):gsub("SHIFT%-", "S"):gsub("META%-", "M"):gsub("NUMPAD", "N")
        :gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD"):gsub("BUTTON", "B"))
end
function ns.abHotkey(b)
    if not b.wpKey then return end
    local slot = b.wpSlot or b:GetAttribute("action")
    if b.wpBlizz and not db.actionbars.binds[tostring(slot)] then return end -- the game's own key text
    b.wpKey:SetText(ns.abKeyText(slot))
    b.wpKey:Show()
end

-- Keybind mode on a button: hovering makes it the target; the middle and side mouse buttons and
-- the wheel bind there too (left and right stay for clicking Done and dragging spells).
function ns.abHooks(b)
    b:HookScript("OnEnter", function(self) if ns.ab.binding then ns.ab.target = self end end)
    b:HookScript("OnLeave", function(self) if ns.ab.target == self then ns.ab.target = nil end end)
    b:HookScript("OnMouseDown", function(self, btn)
        local n = btn == "MiddleButton" and 3 or tonumber((btn or ""):match("^Button(%d+)$"))
        if ns.ab.binding and n then
            ns.ab.target = self
            ns.abKey("BUTTON" .. n)
        end
    end)
    b:HookScript("OnMouseWheel", function(self, delta)
        if ns.ab.binding then
            ns.ab.target = self
            ns.abKey(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
        end
    end)
end

function ns.abButton(f, i, j)
    local name = ("WolfpackActionBar%dButton%d"):format(i, j)
    local b = CreateFrame("CheckButton", name, f, "ActionBarButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown") -- the template keeps the one the key-down setting wants
    b:SetAttribute("showgrid", 1) -- empty slots show, to drag spells onto (unless the bar hides them)
    b.showgrid = 1
    b.wpIcon = rawget(b, "icon") or _G[name .. "Icon"] or b:CreateTexture(nil, "ARTWORK")
    b.wpKey = rawget(b, "HotKey") or _G[name .. "HotKey"] or b:CreateFontString(nil, "OVERLAY")
    b.wpName = rawget(b, "Name") or _G[name .. "Name"] or b:CreateFontString(nil, "OVERLAY")
    b.wpEdge = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    b.wpEdge:SetAllPoints()
    b.wpEdgeMask, b.wpMask = b:CreateMaskTexture(), b:CreateMaskTexture()
    b.wpEdgeMask:SetAllPoints(b.wpEdge)
    b.wpMask:SetAllPoints(b.wpIcon)
    local mask = rawget(b, "IconMask") -- modern buttons round their icon off; ours set their own
    if mask then pcall(b.wpIcon.RemoveMaskTexture, b.wpIcon, mask) end
    -- the game writes its own key text over ours when bindings change: write ours back
    if type(rawget(b, "UpdateHotkeys")) == "function" then hooksecurefunc(b, "UpdateHotkeys", ns.abHotkey) end
    ns.abHooks(b)
    return b
end

-- Buttons are scaled to size, never resized: the game's template draws its highlight, glow,
-- cooldown and slot art at fixed sizes, which spilled into the gap on a smaller button (seen in
-- game). So a button keeps its own size, and offsets, border and text are divided by the scale.
function ns.abScale(b, size)
    if not b.wpNative then
        local w = b:GetWidth()
        b.wpNative = (type(w) == "number" and w > 1 and w < 100) and w or 36
    end
    local s = size / b.wpNative
    b:SetScale(s)
    return s
end

function ns.abLook(b, bar, slot, blizz)
    local nt = b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end -- the game's frame art: the border is ours
    local sc = b.wpScale or 1
    local t, z = bar.borderSize / sc, bar.zoom / 100
    b.wpEdge:SetColorTexture(unpack(bar.borderColor))
    b.wpEdge:SetShown(t > 0)
    b.wpIcon:ClearAllPoints()
    b.wpIcon:SetPoint("TOPLEFT", b, "TOPLEFT", t, -t)
    b.wpIcon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -t, t)
    ns.iconCorners(b.wpIcon, b.wpMask, bar.radius, { z, 1 - z, z, 1 - z })
    ns.iconCorners(b.wpEdge, b.wpEdgeMask, bar.radius, { 0, 1, 0, 1 })
    -- the slot's own dark background: shown, or gone so only our border and the icon are left
    local name = b:GetName() or ""
    for _, art in ipairs({ rawget(b, "SlotBackground") or false, rawget(b, "SlotArt") or false,
        _G[name .. "FloatingBG"] or false }) do -- each client has some of them
        if art then art:SetAlpha(bar.slotBg == false and 0 or 1) end
    end
    -- the red auto-attack / Auto Shot flash: the template fits it to its frame art, which is
    -- hidden here, so it goes over the icon instead, rounded like it (its own atlas coords kept)
    local fl = rawget(b, "Flash") or _G[(b:GetName() or "") .. "Flash"]
    if fl then
        fl:ClearAllPoints()
        fl:SetAllPoints(b.wpIcon)
        local round = ns.ICON_MASKS[bar.radius] and true or false
        if round ~= (fl.wpMasked or false) then
            if round then fl:AddMaskTexture(b.wpMask) else fl:RemoveMaskTexture(b.wpMask) end
            fl.wpMasked = round
        end
    end
    if not b.wpKey:SetFont(bar.keyFont, bar.keySize / sc, "OUTLINE") then
        b.wpKey:SetFont(FONTS[1][2], bar.keySize / sc, "OUTLINE")
    end
    if blizz then return ns.abHotkey(b) end -- the game keeps its own buttons up to date
    if not b.wpName:SetFont(bar.macroFont, bar.macroSize / sc, "OUTLINE") then
        b.wpName:SetFont(FONTS[1][2], bar.macroSize / sc, "OUTLINE")
    end
    b.wpName:SetShown(bar.macroText and true or false)
    if not (pcall(b.UpdateAction, b, true)) then pcall(ActionButton_UpdateAction, b) end
    ns.abHotkey(b)
end

-- A mouseover bar: faded out, in under the cursor, while dragging something to it, in keybind mode
-- and with the options open. Only its alpha changes, which the game allows in combat too; the
-- buttons stay clickable and their keys work while it is faded.
function ns.abFade(self, elapsed)
    local want = (self:IsMouseOver() or ns.ab.dragging or ns.ab.binding or ns.previewing()) and 1 or 0
    local a = self:GetAlpha()
    if a ~= want then self:SetAlpha(a + (want - a) * math.min(1, (elapsed or 1) * 10)) end
    if math.abs(self:GetAlpha() - want) < 0.02 then self:SetAlpha(want) end
end
function ns.abFadeSet(f, on)
    f:SetScript("OnUpdate", on and ns.abFade or nil)
    if not on then f:SetAlpha(1) end
end

-- each next button goes this way (x), each next row that way (y)
ns.AB_GROW = { rightdown = { 1, -1 }, rightup = { 1, 1 }, leftdown = { -1, -1 }, leftup = { -1, 1 } }
function ns.syncActionBars()
    if InCombatLockdown() then return end
    local A, ab = db.actionbars, ns.ab
    for i, bar in ipairs(A.bars) do
        local f = ab.frames[i] or CreateFrame("Frame", "WolfpackActionBar" .. i, UIParent)
        ab.frames[i] = f
        f:Show()
        local n, step = ns.abCount(i), bar.size + bar.gap
        local g = ns.AB_GROW[bar.grow] or ns.AB_GROW.rightdown
        local corner = (g[2] < 0 and "TOP" or "BOTTOM") .. (g[1] > 0 and "LEFT" or "RIGHT")
        f:SetSize(math.max(1, math.min(n, bar.cols) * step - bar.gap), math.max(1, math.ceil(n / bar.cols) * step - bar.gap))
        f:ClearAllPoints()
        f:SetPoint(bar.point, UIParent, bar.point, bar.x, bar.y)
        ns.abFadeSet(f, bar.mouseover)
        ab.buttons[i] = ab.buttons[i] or {}
        local list = ab.buttons[i]
        for j = 1, math.max(n, #list) do
            local b = list[j]
            if not b and j <= n then
                b = ns.abButton(f, i, j)
                list[j] = b
            end
            if b then
                local slot = bar.first + j - 1
                -- hiding empty ones: the template shows them again while a spell is dragged
                local grid = bar.hideEmpty and 0 or 1
                b:SetAttribute("showgrid", grid)
                b.showgrid = grid
                -- something on the cursor (a spell, an item): every slot shows, to drop it on
                b:SetShown(j <= n and (not bar.hideEmpty or ns.ab.dragging or HasAction(slot)) and true or false)
                if j <= n then
                    b:SetAttribute("action", slot)
                    b.wpSlot = slot
                    b.wpScale = ns.abScale(b, bar.size)
                    b:ClearAllPoints()
                    b:SetPoint(corner, f, corner, g[1] * ((j - 1) % bar.cols) * step / b.wpScale,
                        g[2] * math.floor((j - 1) / bar.cols) * step / b.wpScale)
                    ns.abLook(b, bar, slot)
                end
            end
        end
    end
    for i = #A.bars + 1, #ab.frames do ab.frames[i]:Hide() end
    ns.syncSpecialBars()
    ns.abBinds()
end

-- Stance and pet bars. Blizzard's buttons are moved in (and given back, where they were, when
-- the bar is turned off); Blizzard goes on updating them. The pet bar shows while you have a pet,
-- by the game's own state driver, so that holds in combat too. ponytail: given back, a button
-- keeps this bar's look until /reload.
ns.AB_SPECIAL = {
    stance = { name = "WolfpackStanceBar", containers = { "StanceBar", "StanceBarFrame", "ShapeshiftBarFrame" },
        buttons = { "StanceButton", "ShapeshiftButton" } },
    pet = { name = "WolfpackPetBar", containers = { "PetActionBar", "PetActionBarFrame" }, buttons = { "PetActionButton" },
        driver = "[pet] show; hide" },
}
ns.ab.special = { stance = { saved = {} }, pet = { saved = {} } }
-- per side: its point and the bar's, for start / center / end along it, and which way the gap goes
ns.AB_SIDES = {
    above = { start = { "BOTTOMLEFT", "TOPLEFT" }, center = { "BOTTOM", "TOP" }, ["end"] = { "BOTTOMRIGHT", "TOPRIGHT" }, 0, 1 },
    below = { start = { "TOPLEFT", "BOTTOMLEFT" }, center = { "TOP", "BOTTOM" }, ["end"] = { "TOPRIGHT", "BOTTOMRIGHT" }, 0, -1 },
    left = { start = { "TOPRIGHT", "TOPLEFT" }, center = { "RIGHT", "LEFT" }, ["end"] = { "BOTTOMRIGHT", "BOTTOMLEFT" }, -1, 0 },
    right = { start = { "TOPLEFT", "TOPRIGHT" }, center = { "LEFT", "RIGHT" }, ["end"] = { "BOTTOMLEFT", "BOTTOMRIGHT" }, 1, 0 },
}

function ns.abBlizzButton(key, i)
    for _, prefix in ipairs(ns.AB_SPECIAL[key].buttons) do
        if _G[prefix .. i] then return _G[prefix .. i] end
    end
end

-- what a stance or pet bar hangs on: one of your bars, the other of the two, or nil (the screen)
function ns.abTarget(o)
    local n = tonumber((o.anchorTo or ""):match("^bar:(%d+)$"))
    if n then return db.actionbars.bars[n] and ns.ab.frames[n] end
    local other = ns.ab.special[o.anchorTo or ""]
    return other and other.frame and db.actionbars[o.anchorTo].show and other.frame or nil
end

function ns.syncSpecialBars()
    if InCombatLockdown() or ns.ab.placing then return end
    ns.ab.placing = true -- giving buttons back makes Blizzard lay its bar out, which calls here
    for _, key in ipairs({ "stance", "pet" }) do
        local o, spec, st = db.actionbars[key], ns.AB_SPECIAL[key], ns.ab.special[key]
        if o.show then
            local f = st.frame or CreateFrame("Frame", spec.name, UIParent, "SecureHandlerStateTemplate")
            st.frame = f
            if spec.driver then
                if not st.driven then RegisterStateDriver(f, "visibility", spec.driver) end
                st.driven = true
            else
                f:Show()
            end
            ns.abFadeSet(f, o.mouseover)
            local n, step = math.min(o.rows * o.cols, 10), o.size + o.gap
            local g = ns.AB_GROW[o.grow] or ns.AB_GROW.rightdown
            local corner = (g[2] < 0 and "TOP" or "BOTTOM") .. (g[1] > 0 and "LEFT" or "RIGHT")
            f:SetSize(math.max(1, math.min(n, o.cols) * step - o.gap), math.max(1, math.ceil(n / o.cols) * step - o.gap))
            for i = 1, 10 do
                local b = ns.abBlizzButton(key, i)
                if b then
                    if not st.saved[i] then
                        local pts = {}
                        for p = 1, b:GetNumPoints() do pts[p] = { b:GetPoint(p) } end
                        st.saved[i] = { parent = b:GetParent(), points = pts, scale = b:GetScale() }
                        if not b.wpBlizz then -- once per button: what ours have too
                            local name = b:GetName() or ""
                            b.wpBlizz, b.wpSlot = true, key .. ":" .. i
                            b.wpIcon = rawget(b, "icon") or _G[name .. "Icon"] or b:CreateTexture(nil, "ARTWORK")
                            b.wpKey = rawget(b, "HotKey") or _G[name .. "HotKey"] or b:CreateFontString(nil, "OVERLAY")
                            b.wpEdge = b:CreateTexture(nil, "BACKGROUND", nil, -8)
                            b.wpEdge:SetAllPoints()
                            b.wpEdgeMask, b.wpMask = b:CreateMaskTexture(), b:CreateMaskTexture()
                            b.wpEdgeMask:SetAllPoints(b.wpEdge)
                            b.wpMask:SetAllPoints(b.wpIcon)
                            ns.abHooks(b)
                        end
                    end
                    b:SetParent(i <= n and f or hider)
                    if i <= n then
                        b.wpScale = ns.abScale(b, o.size)
                        b:ClearAllPoints()
                        b:SetPoint(corner, f, corner, g[1] * ((i - 1) % o.cols) * step / b.wpScale,
                            g[2] * math.floor((i - 1) / o.cols) * step / b.wpScale)
                        ns.abLook(b, o, nil, true)
                    end
                end
            end
            -- Blizzard lays its bar out again now and then (a new form), which would take them back
            for _, c in ipairs(spec.containers) do
                local box = _G[c]
                if box and not st.hooked then
                    for _, m in ipairs({ "Layout", "UpdateGridLayout" }) do
                        if type(box[m]) == "function" then
                            hooksecurefunc(box, m, function() pcall(ns.syncSpecialBars) end)
                        end
                    end
                end
            end
            st.hooked = true
        elseif st.frame then -- turned off: the buttons go back where they were
            for i, sv in pairs(st.saved) do
                local b = ns.abBlizzButton(key, i)
                b:SetParent(sv.parent)
                b:SetScale(sv.scale or 1)
                b:ClearAllPoints()
                for _, pt in ipairs(sv.points) do b:SetPoint(unpack(pt)) end
            end
            st.saved = {}
            if st.driven then UnregisterStateDriver(st.frame, "visibility") end
            st.driven = false
            st.frame:Hide()
            for _, c in ipairs(spec.containers) do
                local box = _G[c]
                if box then pcall(function() (box.UpdateGridLayout or box.Layout)(box) end) end
            end
        end
    end
    -- anchored after both exist: either may hang on the other
    for _, key in ipairs({ "stance", "pet" }) do
        local o, f = db.actionbars[key], ns.ab.special[key].frame
        if o.show and f then
            f:ClearAllPoints()
            local to, side = ns.abTarget(o), ns.AB_SIDES[o.side] or ns.AB_SIDES.above
            if to and to ~= f then
                local pts = side[o.align] or side.center
                f:SetPoint(pts[1], to, pts[2], o.x + side[1] * o.gap, o.y + side[2] * o.gap)
            else
                f:SetPoint(o.point, UIParent, o.point, o.x, o.y)
            end
        end
    end
    ns.ab.placing = false
end

-- /wp binds: each of your keys, and what the game really does with it (another addon's binding
-- on the same key would show up here instead of the button)
function ns.BindReport()
    local any = false
    for slot, key in pairs(db.actionbars.binds) do
        any = true
        local ok, action = pcall(GetBindingAction, key, true)
        print(("|cff88ccffWolfpack|r %s -> slot %s: %s"):format(key, slot, ok and tostring(action) or "?"))
    end
    if not any then print("|cff88ccffWolfpack|r no keys bound on your action bars yet") end
end

-- isPriority: over other addons' override bindings on the same key, not only the game's own
function ns.abBinds()
    if InCombatLockdown() then return end
    local owner = ns.ab.owner
    ClearOverrideBindings(owner)
    for i, bar in ipairs(db.actionbars.bars) do
        for j, b in ipairs(ns.ab.buttons[i] or {}) do
            local key = b:IsShown() and db.actionbars.binds[tostring(bar.first + j - 1)]
            if key then SetOverrideBindingClick(owner, true, key, b:GetName(), "LeftButton") end
        end
    end
    for _, kind in ipairs({ "stance", "pet" }) do
        for i = 1, 10 do
            local key, b = db.actionbars.binds[kind .. ":" .. i], ns.abBlizzButton(kind, i)
            if key and b and b:GetName() then SetOverrideBindingClick(owner, true, key, b:GetName(), "LeftButton") end
        end
    end
end

-- Quick keybind mode: hover a button and press a key to bind it there, Escape to unbind; Escape
-- off the buttons (or Done) ends it. A key already on another of these buttons moves here.
ns.AB_MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true } -- META: the Mac's Command key
function ns.abKey(key)
    if ns.AB_MODIFIERS[key] then return end
    local t, binds = ns.ab.target, db.actionbars.binds
    if key == "ESCAPE" and not t then return ns.abBindMode(false) end
    if not t or InCombatLockdown() then return end
    local slot = tostring(t.wpSlot or t:GetAttribute("action"))
    if key == "ESCAPE" then
        binds[slot] = nil
    else
        -- the game's own chord builder where there is one (it knows Command); else the same by hand
        local ok, full = pcall(CreateKeyChordStringUsingMetaKeyState, key)
        if not (ok and type(full) == "string") then
            local meta = IsMetaKeyDown and IsMetaKeyDown()
            full = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
                .. (IsShiftKeyDown() and "SHIFT-" or "") .. (meta and "META-" or "") .. key
        end
        for s, k in pairs(binds) do if k == full then binds[s] = nil end end
        binds[slot] = full
    end
    ns.abBinds()
    for _, list in pairs(ns.ab.buttons) do for _, b in ipairs(list) do ns.abHotkey(b) end end
    if t.wpBlizz and t.wpKey then t.wpKey:SetText(ns.abKeyText(slot)) end
end

function ns.abBindMode(on)
    local ab = ns.ab
    if not ab.binder then
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetFrameStrata("DIALOG")
        f:SetSize(360, 64)
        f:SetPoint("TOP", UIParent, "TOP", 0, -120)
        ns.ui.box(f, ns.ui.C.bg, ns.ui.C.border, 8)
        local text = f:CreateFontString(nil, "OVERLAY")
        text:SetFontObject(ns.ui.TEXT)
        text:SetPoint("TOP", 0, -12)
        text:SetText("Keybind mode: hover a button, press a key,\nmouse button or wheel. Escape on it unbinds.")
        local done = ns.ui.Button(f, "Done", 80)
        done:SetPoint("BOTTOMRIGHT", -10, 8)
        done:SetScript("OnClick", function() ns.abBindMode(false) end)
        f:EnableKeyboard(true)
        f:SetScript("OnKeyDown", function(_, key) ns.abKey(key) end)
        f:Hide()
        ab.binder = f
    end
    if InCombatLockdown() and on then return end -- buttons can't change in combat
    ab.binding, ab.target = on and true or false, nil
    ab.binder:SetShown(on and true or false)
    if InCombatLockdown() then return end
    -- while binding: the wheel lands on the buttons, and a click on one of yours casts nothing
    for _, list in pairs(ab.buttons) do
        for _, b in ipairs(list) do
            b:EnableMouseWheel(on and true or false)
            if on then b:RegisterForClicks() else b:RegisterForClicks("AnyUp", "AnyDown") end
        end
    end
    for _, kind in ipairs({ "stance", "pet" }) do
        for i = 1, 10 do
            local b = ns.abBlizzButton(kind, i)
            if b and b.wpBlizz then b:EnableMouseWheel(on and true or false) end
        end
    end
end

-- Secure unit buttons over your health and power bars, clicking like Blizzard's player frame:
-- left targets you, right opens the menu. Their "unit" attribute is also what makes the game
-- treat you as @mouseover while the cursor is on them. ponytail: not children of the bars (that
-- would lock the bars' layout in combat), so their size and spot follow them out of combat only
-- -- read from where the stack put each bar, and where the group sits. With enemy health beside
-- yours, the health one covers only your half, whether there is a target yet or not.
-- The enemy health bar has one too (unit "target", right-click menu). The game's unit watch shows
-- it only while you have a target, in combat as well; ponytail: its spot is the bar's last one
-- out of combat, which is off only if the stack changes shape mid-fight.
-- Your pet and your target's target have one each too (right-click menu, unit watch). Hung on
-- another bar, theirs hangs on that bar's button (secure on secure, so that is allowed in combat).
ns.clickers = {}
local CLICKERS = { health = { "WolfpackAddonClicker", "player" }, power = { "WolfpackAddonClickerPower", "player" },
    enemyhealth = { "WolfpackAddonClickerTarget", "target" }, pethealth = { "WolfpackAddonClickerPet", "pet" },
    tothealth = { "WolfpackAddonClickerToT", "targettarget" } }
local HUNG_ON = { pethealth = "health", tothealth = "enemyhealth" }
function ns.syncClickers()
    local R = db.regular
    local eh = R.bars.enemyhealth
    local beside = eh.show and eh.beside
    local top = R.grow == "up" and R.y + anchor:GetHeight() or R.y -- the group's top edge
    local player = (R.playerMenu or R.playerTarget or R.playerMouseover) and true or false
    local want = { health = player, power = player, enemyhealth = R.targetMenu, pethealth = R.petMenu,
        tothealth = R.totMenu }
    local function hungWanted(key) return want[key] and R.bars[key].show and R.bars[key].anchor ~= "stack" end
    for _, key in ipairs({ "health", "power", "enemyhealth", "pethealth", "tothealth" }) do
        local b, f, mine = R.bars[key], frames[key], CLICKERS[key][2] == "player"
        local c = ns.clickers[key]
        -- also made for a bar whose pet / target of target hangs on it, to hang that one on
        local need = want[key] or (key == "health" and hungWanted("pethealth"))
            or (key == "enemyhealth" and hungWanted("tothealth"))
        if need and not c then
            c = CreateFrame("Button", CLICKERS[key][1], UIParent, "SecureUnitButtonTemplate")
            c:SetAttribute("unit", CLICKERS[key][2])
            c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            ns.clickers[key] = c
        end
        if c then
            -- left click targets: you (if asked), your pet, your target's target
            local targets = HUNG_ON[key] or (mine and R.playerTarget)
            c:SetAttribute("type1", targets and "target" or nil)
            c:SetAttribute("type2", (not mine or R.playerMenu) and "togglemenu" or nil)
            local host = HUNG_ON[key] and b.anchor ~= "stack" and ns.clickers[HUNG_ON[key]]
            local point, _, _, x, y = (key == "enemyhealth" and beside and frames.health or f):GetPoint(1)
            local placed = host or point ~= nil
            local on = want[key] and db.locked and placed -- unlocked: dragging wins
                and (mine and f:IsShown() or not mine and b.show)
            if mine then
                c:SetShown(on or false)
            elseif on then
                RegisterUnitWatch(c)
            else
                UnregisterUnitWatch(c)
                c:Hide()
            end
            if placed then
                local w, h = f:GetWidth(), b.height
                c:ClearAllPoints()
                if host then
                    c:SetFrameLevel(host:GetFrameLevel() + 1)
                    if b.anchor == "below" and key == "tothealth" then -- the bottom of enemy health's slot
                        w = host:GetWidth()
                        c:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT")
                    elseif b.anchor == "below" then -- your pet: under your health
                        w = host:GetWidth()
                        c:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -R.gap)
                    else
                        w, h = b.width, host:GetHeight()
                        if b.anchor == "left" then
                            c:SetPoint("TOPRIGHT", host, "TOPLEFT", -R.gap, 0)
                        else
                            c:SetPoint("TOPLEFT", host, "TOPRIGHT", R.gap, 0)
                        end
                    end
                elseif beside and key ~= "power" then -- the two halves of your health bar's width
                    local hb = R.bars.health
                    w, h = (hb.width - R.gap) / 2, hb.height
                    -- enemy health beside you also spans a pet below your health
                    if key == "enemyhealth" and ns.petBelow() then h = h + R.bars.pethealth.height + R.gap end
                    local left = R.x + hb.x - hb.width / 2 + (key == "enemyhealth" and w + R.gap or 0)
                    c:SetPoint("TOPLEFT", UIParent, "CENTER", left, top + y)
                else
                    c:SetPoint(point, UIParent, "CENTER", R.x + x, top + y)
                end
                c:SetSize(w, h)
            end
        end
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

local inCombat -- from PLAYER_REGEN_DISABLED / _ENABLED

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
-- While mana refills: a fifth of the ring, turning (Media/Arc20: Ring.tga cut to 72 degrees). A
-- frame of its own: the game hides a cooldown frame by itself once its sweep is done, which took
-- an arc drawn on it along (seen in game). It looks again twice a second whether mana is full.
fsr.spin = CreateFrame("Frame", nil, anchor)
fsr.spin:Hide()
fsr.arc = fsr.spin:CreateTexture(nil, "OVERLAY")
fsr.arc:SetTexture("Interface\\AddOns\\WolfpackAddon\\Media\\Arc20")
fsr.arc:SetAllPoints()
function fsr.turn(self, elapsed)
    fsr.arc:SetRotation(-(GetTime() * 4) % (2 * math.pi)) -- clockwise, ~1.5 s a turn
    self.wait = (self.wait or 0) - (elapsed or 0)
    if self.wait <= 0 then
        self.wait = 0.5
        if not fsr:regenerating() then pcall(fsr.sync, fsr) end
    end
end
fsr.spin:SetScript("OnUpdate", fsr.turn)
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
    self.spin:SetParent(host)
    self.spin:SetFrameLevel(host:GetFrameLevel() + 20)
    self.spin:ClearAllPoints()
    self.spin:SetPoint("CENTER", host, "CENTER", o.x, o.y)
    self.spin:SetSize(o.size, o.size)
    local regen = false
    if self:on() and ns.previewing() then
        self.frame:SetCooldown(GetTime(), 3600) -- a sweep too slow to see: a full ring, to place it
        self.endTime = nil
        self.frame:Show()
    elseif self:on() and (self.endTime or 0) > GetTime() then
        self.frame:Show() -- the window: its sweep is already running
    elseif self:on() and o.regen and self:regenerating() then
        regen = true
        self.arc:SetVertexColor(unpack(o.regenColor))
        self.frame:Hide() -- no sweep: the turning arc instead
    else
        self.frame:Hide()
    end
    self.spin:SetShown(regen)
    self.regenOn = regen
end

-- Spirit regen is running: the window is over and mana isn't full (a secret number can't be
-- told: then not shown).
function fsr:regenerating()
    local ok, v, max = pcall(function() return UnitPower("player", PT.Mana), UnitPowerMax("player", PT.Mana) end)
    return (ok and readable(v) and readable(max) and type(max) == "number" and max > 0 and v < max) and true or false
end

-- In combat the window is the plain five-second rule; out of combat regen takes until the
-- seventh second to come back.
function fsr:start()
    if not self:on() then return end
    local seconds = inCombat and 5 or 7
    self.endTime = GetTime() + seconds
    self.regenOn = nil -- the window's sweep replaces the turning arc
    self.spin:Hide()
    self:sync()
    self.frame:SetCooldown(GetTime(), seconds)
    self.frame:Show()
    C_Timer.After(seconds + 0.05, function() pcall(self.sync, self) end) -- just past it; safe() isn't defined yet
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
    for _, s in ipairs(frames.enemyhealth.resFrame.segs) do s.hl:SetShown(on) end
end

-- IsMouseOver works without EnableMouse, so the highlight never blocks clicks.
local function checkHover() setHover(anchor:IsMouseOver()) end

-- Blizzard's raid and party frames get a see-through overlay while hovered. Kept in a table of
-- our own rather than on the frame, so nothing of Blizzard's secure frame table is written to.
-- Nameplates are set up by the same function; only the named party and raid frames are wanted.
ns.raidHover = setmetatable({}, { __mode = "k" }) -- frame -> overlay texture
pcall(hooksecurefunc, "CompactUnitFrame_SetUpFrame", function(frame)
    local name = frame:GetName() or ""
    if ns.raidHover[frame] or not (name:find("^CompactParty") or name:find("^CompactRaid")) then return end
    local tex = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetAllPoints()
    tex:Hide()
    ns.raidHover[frame] = tex
    frame:HookScript("OnEnter", function()
        if not db.other.raidHover.show then return end
        tex:SetColorTexture(unpack(db.other.raidHover.color))
        tex:Show()
    end)
    frame:HookScript("OnLeave", function() tex:Hide() end)
end)

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
ns.FADE_TIME = 0.2
local faded = {} -- frame -> alpha we set

local hoverTicker = CreateFrame("Frame")
ns.hoverTicker = hoverTicker
-- Touching one of Blizzard's own bars is what taints it, and a tainted bar cannot be given the
-- secret numbers its cooldowns are made of -- so it is touched only when the alpha really
-- moves, never once it has settled at either end.
local function hoverTick(_, elapsed)
    local editing = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local step = math.min(elapsed / ns.FADE_TIME, 1)
    for _, e in ipairs(HOVER_FRAMES) do
        local f = _G[e[3]]
        if f and db.other.hover[e[1]] then
            local want = (editing or f:IsMouseOver()) and 1 or 0
            local was = faded[f] or f:GetAlpha()
            local a = was + math.max(-step, math.min(step, want - was))
            if math.abs(a - was) > 0.001 then
                f:SetAlpha(a)
                faded[f] = a
            else
                faded[f] = was
            end
        elseif f and faded[f] then -- option turned off: back to normal, once
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
    if ns.bags.on() or ns.bags.barOn then return end -- our bags carry the bar
    local bar = BagsBar
    local on = db.other.bagsOnOpen
    if not bar or not (on or bagsSaved) then return end
    if InCombatLockdown() then return end -- reparenting their bar mid-fight is blocked
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
    if InCombatLockdown() then return end -- the cluster is theirs, and off limits in a fight
    mini.minimapShape()
    mini.minimapBorder()
    mini.trayUpdate()
    mini.minimapInfo()
    mini.minimapDayNight()
    mini.minimapOffset()
end

local function Refresh()
    if not moving then place() end -- keeps the pinned edge right after any settings change
    ft.tick() -- takeoff and landing, so a route gets timed whether the bar is shown or not
    local health = frames.health
    local eh, ef = db.regular.bars.enemyhealth, frames.enemyhealth
    health.split = (eh.show and eh.beside and (UnitExists("target") or ns.previewing())) and true or false
    stack(anchor, frames, db.regular, true, swingFrames.regular)
    if health.split and health:IsShown() then
        -- the other half of your health bar's width, and all of its height
        ef:Show()
        local pc = db.regular.bars.pethealth
        local hh = db.regular.bars.health.height + (ns.petBelow() and pc.height + db.regular.gap or 0)
        layoutBar(ef, 1, health.width, { height = ns.totBelow() and math.max(2, hh - ns.totShare()) or hh })
        ns.fill(ef)
        ef:ClearAllPoints()
        ef:SetPoint("TOPLEFT", health, "TOPRIGHT", db.regular.gap, 0)
        ns.layoutRes(ef)
        ns.layoutTag(ef)
        ns.layoutAuras(ef)
        ns.layoutBadges(ef)
    end
    ns.placeToT()
    ns.placePet()
    if not (ns.ammoBeside() and frames.power:IsShown()) and db.regular.bars.ammo.anchor ~= "stack" then
        frames.ammo:Hide()
    end
    for _, h in pairs(questHolders) do styleQuest(h) end
    mover:SetShown(not db.locked)
    moverHint:SetFormattedText(HINT, db.regular.x, db.regular.y)
    syncProtected()
    syncGryphons()
    bf.refresh()
    mg.refresh()
    hn.refresh()
    wl.refresh()
    we.refresh("rogue")
    we.refresh("shaman")
    fsr:sync()
    syncHover()
    syncBags()
    mini.syncMinimap()
    anchor:SetScript("OnUpdate", db.regular.highlight.show and checkHover or nil)
    if not db.regular.highlight.show then setHover(false) end
end

-- One report per session, printed to chat: Lua errors are hidden by default and this client
-- stops delivering them after 100.
-- GetMoneyString is what this client has; GetCoinTextureString is not here at all.
function ns.money(c) -- on the namespace, not a local: this chunk is at Lua's 200-local ceiling
    local ok, text = pcall(GetMoneyString, c)
    return (ok and text) or tostring(math.floor((c or 0) / 10000)) .. "g"
end

local function safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not ns.errored then
        ns.errored = true
        print("|cffff5555Wolfpack Addon error:|r " .. tostring(err))
    end
end

------------------------------------------------------------------------------------------
-- Our own nameplates: on every plate (not your own, not one the game keeps to itself) an enemy
-- health bar from db.plates, and Blizzard's plate made invisible (alpha only, which the game
-- allows any time). Plates are recycled: each keeps its bar, given to whichever unit it shows.
------------------------------------------------------------------------------------------
ns.np = { units = {}, bars = {}, seen = {} } -- unit -> bar; plate -> bar; units with a plate
function ns.np.on() return db and db.plates.bars.enemyhealth.show and true or false end

function ns.np.bar(parent)
    local f = newBar(parent, "enemyhealth", "plates")
    f.resFrame = newBar(f, "enemyhealth", "plates")
    f.resFrame.res = true
    f.resFrame:Hide()
    f.castBar = newBar(f, "targetcast", "plates")
    f.castState = {}
    f.castBar.castState = f.castState
    f.castBar:Hide()
    return f
end

-- the cast bar: while the unit casts (or the bars are being placed), under the health bar, and
-- under its power too when that hangs underneath
function ns.np.layoutCast(f)
    local c, cb, e = db.plates.bars.targetcast, f.castBar, db.plates.bars.enemyhealth
    local on = (c.show and (f.castState.targetCasting == true or ns.previewing())) and true or false
    cb:SetShown(on)
    if not on then return end
    layoutBar(cb, 1)
    ns.fillTargetCast(cb)
    cb:ClearAllPoints()
    local below = (e.resource and e.resPlace == "outside" and e.resPoint == "BOTTOM") and f.resFrame or f
    cb:SetPoint("TOP", below, "BOTTOM", c.x, c.y - db.plates.gap)
end

-- a plate that comes into view mid-cast: what it is casting now. A secret answer means yes.
function ns.np.castNow(f, unit)
    local function busy(fn)
        local ok, n = pcall(fn, unit)
        if not ok then return false end
        local okT, yes = pcall(function() return n ~= nil end)
        return not okT or yes
    end
    f.castState.targetChannelling = busy(UnitChannelInfo)
    f.castState.targetCasting = f.castState.targetChannelling or busy(UnitCastingInfo)
end

function ns.np.layout(f)
    f:Show()
    layoutBar(f, 1)
    ns.fill(f)
    f:ClearAllPoints()
    if f.plate then
        f:SetPoint("CENTER", f.plate, "CENTER", db.plates.x, db.plates.y)
    else -- the preview: left of the options window, where it is not covered
        f:SetPoint("RIGHT", ns.cfg or UIParent, "LEFT", -60, 0)
    end
    ns.layoutTag(f)
    ns.layoutRes(f)
    ns.layoutAuras(f)
    ns.layoutBadges(f)
    ns.np.layoutCast(f)
end

-- Blizzard's own plate: hidden while ours is on it, and hidden again whenever the game shows it.
-- Hidden, not just see-through: its hover and target highlight ignore the plate's alpha, and
-- showed as a white bar over ours (seen in game).
function ns.np.blizz(plate, hide)
    local uf = rawget(plate, "UnitFrame")
    if not uf then return end
    uf.wpHide = hide
    if hide and not uf.wpHooked then
        uf.wpHooked = true
        uf:HookScript("OnShow", function(self) if self.wpHide then self:Hide() end end)
    end
    pcall(hide and uf.Hide or uf.Show, uf)
end

function ns.np.add(unit)
    if not ns.np.on() or UnitIsUnit(unit, "player") then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or plate:IsForbidden() then return end
    local f = ns.np.bars[plate] or ns.np.bar(plate)
    ns.np.bars[plate], f.plate = f, plate
    f.unit, f.resFrame.unit, f.castBar.unit = unit, unit, unit
    ns.np.castNow(f, unit)
    ns.np.units[unit] = f
    ns.np.blizz(plate, true)
    ns.np.layout(f)
    if questHolders[plate] then styleQuest(questHolders[plate]) end
end

function ns.np.remove(unit)
    local f = ns.np.units[unit]
    if not f then return end
    ns.np.units[unit], f.unit = nil, nil
    f:Hide()
    ns.np.blizz(f.plate, false)
    if questHolders[f.plate] then styleQuest(questHolders[f.plate]) end
end

-- After a settings change: every plate again, or every plate back to Blizzard's. The preview
-- (your target, or a stand-in) shows above the screen center while the Plates tab is open.
function ns.np.all()
    for unit in pairs(ns.np.seen) do
        if ns.np.on() then ns.np.add(unit) else ns.np.remove(unit) end
    end
    local p = ns.np.previewBar()
    if ns.np.wantPreview and ns.np.wantPreview() then
        ns.np.layout(p)
        p.quest = p.quest or ns.questHolder(p)
        p.quest.ownBar = p
        styleQuest(p.quest)
    else
        p:Hide()
    end
    ns.np.trailSync()
end
function ns.np.previewBar()
    if not ns.np.preview then
        ns.np.preview = ns.np.bar(UIParent)
        ns.np.preview.unit, ns.np.preview.resFrame.unit = "target", "target"
        ns.np.preview.castBar.unit = "target"
        ns.np.preview.castState, ns.np.preview.castBar.castState = ns, ns -- your target's cast
        ns.np.preview:Hide()
    end
    return ns.np.preview
end

-- The target trail: a stroke `length` long running round the target's plate, along its border's
-- line. Each frame it is cut into pieces along the path (see trailDraw), a dot on each end.
function ns.np.trail()
    local t = ns.np.trailFrame
    if t then return t end
    t = CreateFrame("Frame", nil, UIParent)
    t.lines, t.glows, t.head = {}, {}, 0 -- filled as the path needs them
    t.clock, t.poll, t.state = 0, 0, "idle"
    t.caps = { t:CreateTexture(nil, "ARTWORK", nil, 1), t:CreateTexture(nil, "ARTWORK", nil, 1) }
    for _, d in ipairs(t.caps) do d:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\Dot") end
    t:SetScript("OnUpdate", function(self, elapsed)
        elapsed = elapsed or 0
        self.clock, self.poll = self.clock + elapsed, self.poll - elapsed
        if self.poll <= 0 then self.poll, self.state = 0.2, ns.np.trailState() end -- combat and aggro come and go
        local st = db.plates.trail.states[self.state]
        self.head = (self.head + elapsed / math.max(st.lap, 0.1)) % 1
        safe(ns.np.trailDraw, self)
    end)
    t:Hide()
    ns.np.trailFrame = t
    return t
end

-- The path round a w x h rectangle (from its bottom left), clockwise from its top left corner:
-- four edges (start + direction), each with its length and where along the path it starts.
-- ponytail: square corners only; arcs drawn in dots snapped to pixels too coarsely at plate size
-- (seen in game), so a rounded border is circled square
function ns.np.trailPath(w, h)
    local path = {
        { len = w, x = 0, y = h, dx = 1, dy = 0 },
        { len = h, x = w, y = h, dx = 0, dy = -1 },
        { len = w, x = w, y = 0, dx = -1, dy = 0 },
        { len = h, x = 0, y = 0, dx = 0, dy = 1 },
    }
    local at = 0
    for _, e in ipairs(path) do e.at, at = at, at + e.len end
    path.total = at
    return path
end

-- the stretch of the path distance d (0 to its length) lies on, and how far into it
function ns.np.trailSeg(path, d)
    for _, e in ipairs(path) do
        if e.len > 0 and d < e.at + e.len - 1e-9 then return e, d - e.at end
    end
    for _, e in ipairs(path) do if e.len > 0 then return e, 0 end end -- d at the very end: the start
end
function ns.np.trailAt(path, d)
    local e, u = ns.np.trailSeg(path, d % path.total)
    return e.x + e.dx * u, e.y + e.dy * u
end

-- Each stretch along an edge is a texture, fading along it, a soft glow behind it. At a corner
-- the pieces on either side reach over it by half a stroke and meet.
function ns.np.trailDraw(t)
    local o, f = db.plates.trail, t.bar
    local out = o.offset - (f.edge or 0) / 2 -- the border's middle, plus the offset outward
    local w, h = f.width + 2 * out, db.plates.bars.enemyhealth.height + 2 * out
    local path = ns.np.trailPath(w, h)
    local P = path.total
    local st = o.states[t.state]
    local len, th, r, g, b, a = math.min(o.length, P), o.thickness, unpack(st.color)
    if st.flash then -- pulsing between a quarter and full, flashRate times a second
        a = a * (0.625 + 0.375 * math.cos(2 * math.pi * t.clock * o.flashRate))
    end
    local head = t.head * P
    local tail = head - len
    local function alpha(d) return o.fade and a * (d - tail) / len or a end
    local function color(d, k) return CreateColor(r, g, b, alpha(d) * (k or 1)) end
    local gs = math.max(1, math.min(math.floor(o.glowSize), 20))
    local glowOn = (o.glow and o.glowSize > 0) and true or false
    local used = { lines = 0, glows = 0 }
    local function take(kind)
        used[kind] = used[kind] + 1
        local tex = t[kind][used[kind]]
        if not tex then
            tex = t:CreateTexture(nil, kind == "glows" and "BACKGROUND" or "ARTWORK")
            if kind == "glows" then tex:SetBlendMode("ADD") end
            t[kind][used[kind]] = tex
        end
        tex:ClearAllPoints()
        return tex
    end
    local function place(tex, x, y, pw, ph)
        tex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x - out, y - out)
        tex:SetSize(pw, ph)
    end
    -- the fade runs from c0 to c1 along the direction of travel
    local function grad(tex, dx, dy, c0, c1)
        if dx > 0 then tex:SetGradient("HORIZONTAL", c0, c1)
        elseif dx < 0 then tex:SetGradient("HORIZONTAL", c1, c0)
        elseif dy > 0 then tex:SetGradient("VERTICAL", c0, c1)
        else tex:SetGradient("VERTICAL", c1, c0) end
    end
    local function glow(x, y, pw, ph, dx, dy, d0, d1)
        local gl = take("glows")
        gl:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\Shadow\\s" .. gs .. ".tga")
        pcall(gl.SetTextureSliceMargins, gl, gs, gs, gs, gs)
        place(gl, x - gs, y - gs, pw + 2 * gs, ph + 2 * gs)
        grad(gl, dx, dy, color(d0, o.glowAlpha), color(d1, o.glowAlpha))
        gl:SetShown(glowOn)
    end
    local d = tail
    while d < head - 1e-6 and used.lines < 5 do -- at most five: it can turn two corners
        local seg, u0 = ns.np.trailSeg(path, d % P)
        local e = math.min(head, d + seg.len - u0)
        local u1 = u0 + (e - d)
        local dx, dy = seg.dx, seg.dy
        local x0, y0 = seg.x + dx * u0, seg.y + dy * u0
        local x1, y1 = seg.x + dx * u1, seg.y + dy * u1
        local ext0 = d > tail + 1e-6 and th / 2 or 0 -- a corner behind: joined
        local ext1 = e < head - 1e-6 and th / 2 or 0
        local lx = math.min(x0 - dx * ext0, x1 + dx * ext1) - (dx == 0 and th / 2 or 0)
        local ly = math.min(y0 - dy * ext0, y1 + dy * ext1) - (dy == 0 and th / 2 or 0)
        local lw = dx ~= 0 and math.abs(x1 - x0) + ext0 + ext1 or th
        local lh = dy ~= 0 and math.abs(y1 - y0) + ext0 + ext1 or th
        local line = take("lines")
        line:SetColorTexture(1, 1, 1, 1) -- the texture first: the gradient tints it
        place(line, lx, ly, lw, lh)
        grad(line, dx, dy, color(d), color(e))
        line:Show()
        glow(lx, ly, lw, lh, dx, dy, d, e)
        d = e
    end
    for kind, n in pairs(used) do
        for i = n + 1, #t[kind] do t[kind][i]:Hide() end
    end
    -- round caps: a dot the stroke's width on each end
    for k, cap in ipairs(t.caps) do
        local at = k == 1 and head or tail
        local x, y = ns.np.trailAt(path, at)
        cap:SetShown(o.caps and true or false)
        cap:SetSize(th, th)
        cap:ClearAllPoints()
        cap:SetPoint("CENTER", f, "BOTTOMLEFT", x - out, y - out)
        cap:SetVertexColor(r, g, b, alpha(at))
    end
end

-- What your target is up to: "aggro" (in combat, targeting you), "combat", or "idle". An answer
-- the game keeps secret counts as no.
function ns.np.trailState()
    local function yes(fn)
        local ok, v = pcall(function() return fn() and true or false end)
        return ok and v
    end
    if not yes(function() return UnitAffectingCombat("target") end) then return "idle" end
    return yes(function() return UnitIsUnit("targettarget", "player") end) and "aggro" or "combat"
end

-- on your target's plate (or the preview while the Nameplates page is open), else hidden
function ns.np.trailSync()
    local o, f = db.plates.trail, nil
    if o.show and ns.np.on() then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        local okA, foe = pcall(function() return UnitCanAttack("player", "target") and true or false end)
        f = ok and plate and (not okA or foe) and ns.np.bars[plate] or nil
        if f and not f.unit then f = nil end
        if ns.np.wantPreview and ns.np.wantPreview() then f = ns.np.previewBar() end
    end
    if not (f or ns.np.trailFrame) then return end
    local t = ns.np.trail()
    if not (f and f:IsShown()) then t:Hide() return end
    t:SetParent(f)
    t:SetAllPoints(f)
    t:SetFrameLevel(f:GetFrameLevel() + 6)
    t.bar, t.state = f, ns.np.trailState()
    t:Show()
    ns.np.trailDraw(t)
end

ns.npEv = CreateFrame("Frame")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_AURA", "UNIT_NAME_UPDATE", "UNIT_LEVEL",
    "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "PLAYER_TARGET_CHANGED" }) do
    pcall(ns.npEv.RegisterEvent, ns.npEv, e)
end
ns.npEv:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        ns.np.seen[unit] = true
        safe(ns.np.add, unit)
        return safe(ns.np.trailSync)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        ns.np.seen[unit] = nil
        safe(ns.np.remove, unit)
        return safe(ns.np.trailSync)
    elseif event == "PLAYER_TARGET_CHANGED" then
        return safe(ns.np.trailSync)
    end
    local f = ns.np.units[unit]
    if not f then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        safe(ns.fill, f)
    elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
        if f.resFrame:IsShown() then safe(ns.fill, f.resFrame) end
    elseif event == "UNIT_AURA" then
        safe(ns.layoutAuras, f)
        safe(ns.layoutTag, f) -- eating, drinking
        if questHolders[f.plate] then safe(styleQuest, questHolders[f.plate]) end -- on buffs that came or went
    elseif event:find("^UNIT_SPELLCAST_") then
        ns.castState(f.castState, event) -- DELAYED / CHANNEL_UPDATE: the same cast, new times
        safe(ns.np.layoutCast, f)
        if questHolders[f.plate] then safe(styleQuest, questHolders[f.plate]) end -- on the cast bar
    else
        safe(ns.np.layout, f)
    end
end)

------------------------------------------------------------------------------------------
-- Bags: one window of ours for the backpack and bags, in the action bars' look. Blizzard's bag
-- windows still open and close as always (B, a vendor, the bank), parked out of sight; ours is
-- open while one of them is. Quest items group apart under the bags; ammo, soul, profession
-- and reagent bags get a group each. The buttons are the game's own container item buttons,
-- so using, dragging, splitting and tooltips are the game's.
------------------------------------------------------------------------------------------
ns.bags = { holders = {}, order = { "main", "quest", "reagent", "ammo", "soul", "trade" },
    labels = { quest = "Quest items", reagent = "Reagents", ammo = "Ammunition", soul = "Soul shards",
        trade = "Profession bags" } }
function ns.bags.on() return db and db.bags.show and true or false end
function ns.bags.api(name) return (C_Container and C_Container[name]) or _G[name] end

-- backpack and bags, plus the reagent bag where the game has one (elsewhere bag 5 is the bank's)
function ns.bags.list()
    local out = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do out[#out + 1] = bag end
    local r = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if r then out[#out + 1] = r end
    return out
end

function ns.bags.section(bag)
    if Enum and Enum.BagIndex and bag == Enum.BagIndex.ReagentBag then return "reagent" end
    local ok, _, family = pcall(ns.bags.api("GetContainerNumFreeSlots"), bag)
    family = ok and type(family) == "number" and family or 0
    if family == 0 then return "main" end
    if bit.band(family, 3) ~= 0 then return "ammo" end -- 1 arrows, 2 bullets
    if bit.band(family, 4) ~= 0 then return "soul" end
    return "trade"
end

-- the keyring's bag id, where the game has a keyring and it is ours to show
function ns.bags.keys()
    return db.bags.keyring and KeyRingButton and (KEYRING_CONTAINER or -2) or nil
end

-- Class presets for custom bags: item ids, plus name patterns for the many ranks.
-- ponytail: the patterns are English names; other locales go by the ids alone
ns.bags.presets = {
    ROGUE = { { key = "poisons", name = "Poisons", ids = { 6947, 6949, 6950, 8926, 8927, 8928, 21927, 2892, 2893,
        8984, 8985, 20844, 22053, 22054, 3775, 3776, 5237, 6951, 9186, 10918, 10920, 10921, 10922, 22055, 21835,
        3371, 3372, 8925, 18256, 2928, 2930, 5173, 8923, 8924 }, match = { "Poison$", "Poison [IVX]+$" } },
        { key = "tools", name = "Tools and powders", ids = { 5060, 5140, 5530 } } },
    SHAMAN = { { key = "totems", name = "Totems", ids = { 5175, 5176, 5177, 5178 } },
        { key = "reagents", name = "Reagents", ids = { 17030, 17057, 17058 } } },
    WARLOCK = { { key = "shards", name = "Shards and stones", ids = { 6265, 5565, 16583 },
        match = { "Healthstone$", "Soulstone$", "Spellstone$", "Firestone$" } } },
    MAGE = { { key = "reagents", name = "Reagents", ids = { 17020, 17031, 17032, 17056 } },
        { key = "conjured", name = "Conjured", ids = { 5514, 5513, 8007, 8008, 22044 }, match = { "^Conjured " } } },
    PRIEST = { { key = "reagents", name = "Reagents", ids = { 17028, 17029, 17056 } } },
    PALADIN = { { key = "reagents", name = "Reagents", ids = { 17033, 21177 } } },
    DRUID = { { key = "reagents", name = "Reagents", ids = { 17021, 17026, 22148, 17034, 17035, 17036, 17037,
        17038, 22147 } } },
}
function ns.bags.classPresets() return ns.bags.presets[select(2, UnitClass("player")) or ""] or {} end
function ns.bags.preset(key)
    for _, p in ipairs(ns.bags.classPresets()) do if p.key == key then return p end end
end

function ns.bags.itemName(id)
    local ok, name = pcall((C_Item and C_Item.GetItemInfo) or GetItemInfo, id)
    return ok and name or nil
end

-- does custom bag `c` hold this item: put there, or its preset's and not taken out
function ns.bags.holds(c, id)
    local v = c.items[id]
    if v ~= nil then return v end
    local p = c.preset and ns.bags.preset(c.preset)
    if not p then return false end
    if tContains(p.ids, id) then return true end
    local name = p.match and ns.bags.itemName(id)
    for _, pat in ipairs(name and p.match or {}) do if name:find(pat) then return true end end
    return false
end
function ns.bags.customOf(id)
    for i, c in ipairs(db.bags.custom) do if ns.bags.holds(c, id) then return i end end
end

-- an item dropped on custom bag i goes there (and out of the others); dropped again, it goes back
function ns.bags.drop(i)
    local ok, kind, id = pcall(GetCursorInfo)
    local c = db.bags.custom[i]
    if not (ok and kind == "item" and id and c) then return end
    ClearCursor()
    local here = ns.bags.holds(c, id)
    for _, o in ipairs(db.bags.custom) do
        o.items[id] = nil
        if ns.bags.holds(o, id) then o.items[id] = false end
    end
    if not here then c.items[id] = true end
    ns.bags.layout()
end

function ns.bags.addBag(name, preset, id)
    local c = { name = name, preset = preset, items = {} }
    table.insert(db.bags.custom, c)
    if id then
        for _, o in ipairs(db.bags.custom) do if o ~= c and ns.bags.holds(o, id) then o.items[id] = false end end
        c.items[id] = true
    end
    if ns.bags.frame and ns.bags.frame:IsShown() then ns.bags.layout() end
end

-- the icon: the preset's first item, else the first item put in, else a bag
function ns.bags.icon(c)
    local p, id = c.preset and ns.bags.preset(c.preset), nil
    id = p and p.ids[1]
    if not id then for k, v in pairs(c.items) do if v then id = k break end end end
    local ok, icon = pcall(function() return select(5, GetItemInfoInstant(id)) end)
    return ok and icon or "Interface\\Icons\\INV_Misc_Bag_08"
end

StaticPopupDialogs.WOLFPACKADDON_NEWBAG = {
    text = "Name the new bag:",
    button1 = OKAY or "OK", button2 = CANCEL or "Cancel",
    hasEditBox = true,
    OnAccept = function(self, id)
        local e = self and (self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox()))
        local name = e and strtrim(e:GetText() or "") or ""
        safe(ns.bags.addBag, name ~= "" and name or ("Bag " .. (#db.bags.custom + 1)), nil, id)
    end,
    EditBoxOnEnterPressed = function(e)
        local p = e:GetParent()
        StaticPopupDialogs.WOLFPACKADDON_NEWBAG.OnAccept(p, p.data)
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(e) e:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
StaticPopupDialogs.WOLFPACKADDON_DELBAG = {
    text = "Remove the bag \"%s\"? Its items go back into the bags.",
    button1 = YES, button2 = NO,
    OnAccept = function(_, i)
        table.remove(db.bags.custom, i)
        if ns.bags.frame and ns.bags.frame:IsShown() then safe(ns.bags.layout) end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- the strip left of the window: a button per custom bag (drop items on it), one to make a bag,
-- and your class's presets not yet made, faded
function ns.bags.sideButton(i)
    local s = ns.bags.frame.side
    if s.btns[i] then return s.btns[i] end
    local b = CreateFrame("Button", nil, s)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnReceiveDrag", function(self) if self.wpBag then safe(ns.bags.drop, self.wpBag) end end)
    b:SetScript("OnClick", function(self, button)
        local ok, kind, id = pcall(GetCursorInfo)
        local item = ok and kind == "item" and id or nil
        if self.wpBag then
            if item then safe(ns.bags.drop, self.wpBag)
            elseif button == "RightButton" then
                StaticPopup_Show("WOLFPACKADDON_DELBAG", db.bags.custom[self.wpBag].name, nil, self.wpBag)
            end
        elseif self.wpPreset then
            safe(ns.bags.addBag, self.wpPreset.name, self.wpPreset.key)
        else -- the new bag button; an item held on it goes in the new bag
            if item then ClearCursor() end
            StaticPopup_Show("WOLFPACKADDON_NEWBAG", nil, nil, item)
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.wpBag then
            GameTooltip:SetText(db.bags.custom[self.wpBag].name)
            GameTooltip:AddLine("Drop an item here to keep it in this bag; drop it again to take it out.", 1, 1, 1, true)
            GameTooltip:AddLine("Right-click to remove the bag.", 0.6, 0.6, 0.6, true)
        elseif self.wpPreset then
            GameTooltip:SetText(self.wpPreset.name)
            GameTooltip:AddLine("Class preset: click to add this bag.", 1, 1, 1, true)
        else
            GameTooltip:SetText("New bag")
            GameTooltip:AddLine("Click to make a custom bag, then drop items on its icon.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    s.btns[i] = b
    return b
end

function ns.bags.layoutSide(counts)
    local o, B = db.bags, ns.bags
    local s = B.frame.side
    s:SetShown(o.side)
    if not o.side then return end
    local list, have = {}, {}
    for i, c in ipairs(o.custom) do
        list[#list + 1] = { bag = i, icon = B.icon(c), count = counts[i] or 0 }
        if c.preset then have[c.preset] = true end
    end
    list[#list + 1] = { icon = "Interface\\PaperDollInfoFrame\\Character-Plus" }
    for _, p in ipairs(B.classPresets()) do
        if not have[p.key] then list[#list + 1] = { preset = p, icon = B.icon({ preset = p.key, items = {} }) } end
    end
    local pad, size = 6, math.floor(o.size * 0.9)
    for i, e in ipairs(list) do
        local b = B.sideButton(i)
        b.wpBag, b.wpPreset = e.bag, e.preset
        b:SetSize(size, size)
        b.icon:SetTexture(e.icon)
        b.icon:SetDesaturated(e.preset and true or false)
        b:SetAlpha(e.preset and 0.5 or 1)
        b.count:SetText(e.bag and e.count or "")
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", s, "TOPLEFT", pad, -pad - (i - 1) * (size + o.gap))
        b:Show()
    end
    for i = #list + 1, #s.btns do s.btns[i]:Hide() end
    s:SetSize(size + pad * 2, pad * 2 + #list * (size + o.gap) - o.gap)
    s.bg:SetColorTexture(unpack(o.bg))
end

function ns.bags.isQuest(bag, slot, info)
    local ok, q = pcall(ns.bags.api("GetContainerItemQuestInfo"), bag, slot)
    if ok and type(q) == "table" and (q.isQuestItem or q.questID) then return true end
    local id = info and info.itemID
    local okC, classID = pcall(function() return select(6, GetItemInfoInstant(id)) end)
    return okC and classID == 12 -- Enum.ItemClass.Questitem
end

-- one holder per bag carries the bag's id, as the game's buttons look for it on their parent
function ns.bags.button(bag, slot)
    local h = ns.bags.holders[bag]
    if not h then
        h = CreateFrame("Frame", nil, bag == ns.bags.keys() and ns.bags.frame.keys or ns.bags.frame)
        h:SetID(bag)
        h.buttons = {}
        ns.bags.holders[bag] = h
    end
    if h.buttons[slot] then return h.buttons[slot] end
    local name = ("WolfpackBag%dSlot%d"):format(bag, slot)
    local ok, b = pcall(CreateFrame, "ItemButton", name, h, "ContainerFrameItemButtonTemplate")
    if not ok then b = CreateFrame("Button", name, h, "ContainerFrameItemButtonTemplate") end
    b:SetID(slot)
    if type(rawget(b, "SetBagID")) == "function" or b.SetBagID ~= nil then pcall(b.SetBagID, b, bag) end
    -- the template's own art (new-item and quest glows, slot frame...) is Blizzard's bag code to
    -- switch, which never runs on these: all of it goes but the icon, hover and pressed looks
    local icon = rawget(b, "icon") or _G[name .. "IconTexture"]
    local keep = { [icon or 0] = true, [b:GetHighlightTexture() or 0] = true, [b:GetPushedTexture() or 0] = true }
    for _, r in ipairs({ b:GetRegions() }) do
        if not keep[r] and r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
    end
    b.wpIcon = icon or b:CreateTexture(nil, "ARTWORK")
    b.wpCount = rawget(b, "Count") or _G[name .. "Count"]
    b.wpCd = rawget(b, "Cooldown") or _G[name .. "Cooldown"]
    b.wpEdge = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    b.wpEdge:SetAllPoints()
    b.wpBg = b:CreateTexture(nil, "BACKGROUND", nil, -7) -- an empty slot's dark face
    b.wpBg:SetAllPoints(b.wpIcon)
    b.wpBg:SetColorTexture(1, 1, 1, 0.06)
    b.wpEdgeMask, b.wpMask = b:CreateMaskTexture(), b:CreateMaskTexture()
    b.wpEdgeMask:SetAllPoints(b.wpEdge)
    b.wpMask:SetAllPoints(b.wpIcon)
    b.wpJunk = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.wpJunk:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    b.wpJunk:SetPoint("TOPLEFT", 1, -1)
    h.buttons[slot] = b
    return b
end

-- the action bars' look: a border plate, the icon inset by it, zoomed and rounded the same
function ns.bags.look(b, o, info, quest)
    local sc = b.wpScale or 1
    local t, z = o.borderSize / sc, o.zoom / 100
    local col, q = o.borderColor, info and info.quality
    if quest then col = { 1, 0.82, 0, 1 }
    elseif o.quality and type(q) == "number" and q >= 2 then
        local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        if qc then col = { qc.r, qc.g, qc.b, 1 } end
    end
    b.wpEdge:SetColorTexture(unpack(col))
    b.wpEdge:SetShown(t > 0)
    b.wpIcon:ClearAllPoints()
    b.wpIcon:SetPoint("TOPLEFT", b, "TOPLEFT", t, -t)
    b.wpIcon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -t, t)
    ns.iconCorners(b.wpIcon, b.wpMask, o.radius, { z, 1 - z, z, 1 - z })
    ns.iconCorners(b.wpEdge, b.wpEdgeMask, o.radius, { 0, 1, 0, 1 })
    local nt = b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end -- the game's slot art: the border is ours
    local qb = rawget(b, "IconBorder")
    if qb then qb:SetAlpha(0) end -- and so is the quality color
    b.wpJunk:SetSize(14 / sc, 14 / sc)
    b.wpJunk:SetShown((o.junk and info and q == 0 and not info.hasNoValue) and true or false)
    if b.wpCount then b.wpCount:SetFont(o.font, o.countSize / sc, "OUTLINE") end
end

-- what each slot holds, shown on its button
function ns.bags.fill(b, bag, slot, info)
    local tex = info and info.iconFileID
    if SetItemButtonTexture then SetItemButtonTexture(b, tex) else b.wpIcon:SetTexture(tex) end
    b.wpIcon:SetShown(tex ~= nil)
    local n = info and info.stackCount or 0
    if SetItemButtonCount then SetItemButtonCount(b, n)
    elseif b.wpCount then b.wpCount:SetText(n > 1 and n or "") end
    if SetItemButtonDesaturated then SetItemButtonDesaturated(b, info and info.isLocked) end
    if b.wpCd and CooldownFrame_Set then
        local ok, start, dur, enable = pcall(ns.bags.api("GetContainerItemCooldown"), bag, slot)
        if ok and start then pcall(CooldownFrame_Set, b.wpCd, start, dur, enable) end
    end
end

-- keep sorted: what is shown is ordered (best quality, then kind, then name), the items stay put
function ns.bags.sortKey(b)
    local i = b.wpInfo
    if not i then return { 1, 0, "", 0 } end
    local okC, classID = pcall(function() return select(6, GetItemInfoInstant(i.itemID)) end)
    return { 0, -(i.quality or 0), (okC and classID or 99), i.itemName or i.hyperlink or "", -(i.stackCount or 0) }
end
function ns.bags.sorted(list)
    for _, b in ipairs(list) do b.wpKey = ns.bags.sortKey(b) end
    table.sort(list, function(a, c)
        local x, y = a.wpKey, c.wpKey
        for k = 1, 5 do
            if x[k] ~= y[k] and x[k] ~= nil and y[k] ~= nil then return x[k] < y[k] end
        end
        return (a.wpBag * 100 + a:GetID()) < (c.wpBag * 100 + c:GetID())
    end)
end

-- one bag's slots onto buttons; each button goes to the group `pick` names
function ns.bags.slots(bag, pick)
    local o, B = db.bags, ns.bags
    local ok, n = pcall(B.api("GetContainerNumSlots"), bag)
    n = ok and type(n) == "number" and n or 0
    for slot = 1, n do
        local b = B.button(bag, slot)
        local okI, info = pcall(B.api("GetContainerItemInfo"), bag, slot)
        info = okI and type(info) == "table" and info or nil
        b.wpInfo, b.wpBag = info, bag
        local k, quest = pick(slot, info)
        b.wpScale = ns.abScale(b, o.size)
        B.fill(b, bag, slot, info)
        B.look(b, o, info, quest)
        b:Show()
        k[#k + 1] = b
    end
    local h = B.holders[bag]
    for slot = n + 1, h and #h.buttons or 0 do h.buttons[slot]:Hide() end
end

-- buttons in rows of o.cols on `f`, from y down; returns where the rows end
function ns.bags.grid(f, list, y, pad)
    local o = db.bags
    local step = o.size + o.gap
    for i, b in ipairs(list) do
        local col, row = (i - 1) % o.cols, math.floor((i - 1) / o.cols)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", (pad + col * step) / b.wpScale, (y - row * step) / b.wpScale)
    end
    return y - math.ceil(#list / o.cols) * step + o.gap
end

function ns.bags.layout()
    local o, B = db.bags, ns.bags
    local f = B.frame
    -- the custom bags' groups come right after the quest items
    local order, groups, free = {}, {}, 0
    for _, k in ipairs(B.order) do
        order[#order + 1] = k
        if k == "quest" then for i in ipairs(o.custom) do order[#order + 1] = "c" .. i end end
    end
    for _, k in ipairs(order) do groups[k] = {} end
    for _, bag in ipairs(B.list()) do
        local sec = B.section(bag)
        B.slots(bag, function(slot, info)
            if not info then free = free + 1 end
            local c = sec == "main" and info and info.itemID and B.customOf(info.itemID)
            if c then return groups["c" .. c] end
            local quest = sec == "main" and info and B.isQuest(bag, slot, info) or false
            return groups[quest and "quest" or sec], quest
        end)
    end
    if o.sort then for _, k in ipairs(order) do B.sorted(groups[k]) end end
    local pad, step = 8, o.size + o.gap
    local y, first = -pad, true
    for _, tag in pairs(f.tags) do tag:Hide() end
    for _, k in ipairs(order) do
        local list = groups[k]
        local c = k:match("^c(%d+)$") and o.custom[tonumber(k:sub(2))]
        local tag = (B.labels[k] or c) and f.tags[k]
        if c and not tag then
            tag = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            f.tags[k] = tag
        end
        if c then tag:SetText(c.name) end
        if #list > 0 then
            if not first then y = y - o.sectionGap end
            if tag then
                tag:ClearAllPoints()
                tag:SetPoint("TOPLEFT", f, "TOPLEFT", pad, y)
                tag:Show()
                y = y - 14
            end
            first = false
            y = B.grid(f, list, y, pad)
        end
    end
    f.money:SetText(ns.money(GetMoney()))
    f.free:SetText(free .. " free")
    f:SetSize(pad * 2 + o.cols * step - o.gap, -y + pad + 18)
    f.bg:SetColorTexture(unpack(o.bg))
    f:ClearAllPoints()
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", o.x, o.y)
    f.sort:SetShown(B.api("SortBags") ~= nil)
    local counts = {}
    for i in ipairs(o.custom) do counts[i] = #groups["c" .. i] end
    B.layoutSide(counts)
end

-- the keyring's keys, in a panel of their own above the bag bar
function ns.bags.layoutKeys()
    local o, B = db.bags, ns.bags
    local k, list = B.frame.keys, {}
    B.slots(B.keys(), function() return list end)
    if o.sort then B.sorted(list) end
    local pad = 6
    local y = B.grid(k, list, -pad, pad)
    k:SetSize(pad * 2 + math.max(1, math.min(#list, o.cols)) * (o.size + o.gap) - o.gap, -y + pad)
    k.bg:SetColorTexture(unpack(o.bg))
    k:ClearAllPoints()
    -- above the backpack on the bag bar (or the window's top, the bar being elsewhere)
    local top = B.barOn and (BagsBar or MainMenuBarBackpackButton)
    if top then k:SetPoint("BOTTOMRIGHT", top, "TOPRIGHT", 0, 6)
    else k:SetPoint("BOTTOMRIGHT", B.frame, "TOPRIGHT", 0, 4) end
end

-- The bag bar rides on top of our window: Blizzard's whole bar where there is one, else the
-- backpack and bag slot buttons. Only out of combat; given back where it was when turned off.
function ns.bags.bar(on)
    if InCombatLockdown() then ns.bags.barPending = true return end
    ns.bags.barPending = false
    local B, list = ns.bags, nil
    if BagsBar then list = { BagsBar } else
        list = {}
        for _, n in ipairs({ "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
            "CharacterBag2Slot", "CharacterBag3Slot" }) do
            if _G[n] then list[#list + 1] = _G[n] end
        end
    end
    -- the keyring button at the bar's left end while ours shows the keys, else back home
    if KeyRingButton then list[#list + 1] = KeyRingButton end
    for i, w in ipairs(list) do
        if on and w == KeyRingButton and not B.keys() then on = false end
        if on then
            if not w.wpHome then
                w.wpHome = { parent = w:GetParent() }
                for k = 1, w:GetNumPoints() do w.wpHome[k] = { w:GetPoint(k) } end
            end
            w:SetParent(B.frame)
            w:ClearAllPoints()
            if i == 1 then w:SetPoint("BOTTOMRIGHT", B.frame, "TOPRIGHT", 0, 4)
            else w:SetPoint("RIGHT", list[i - 1], "LEFT", -2, 0) end
        elseif w.wpHome then
            w:SetParent(w.wpHome.parent)
            w:ClearAllPoints()
            for _, pt in ipairs(w.wpHome) do w:SetPoint(unpack(pt)) end
            w.wpHome = nil
        end
    end
end

-- Blizzard's windows for these bags (not the bank's) are parked under `hider` while open: their
-- buttons out of reach, their open / closed state still the game's, and ours follows it.
function ns.bags.blizz()
    local out = { ContainerFrameCombinedBags }
    for i = 1, NUM_CONTAINER_FRAMES or 13 do out[#out + 1] = _G["ContainerFrame" .. i] end
    return out
end
function ns.bags.mine(f)
    if f == ContainerFrameCombinedBags then return true end
    local id = f:GetID()
    return tContains(ns.bags.list(), id)
end

function ns.bags.sync()
    local B, on, open, keys = ns.bags, ns.bags.on(), false, false
    if not B.frame and not on then return end
    B.make()
    local keyBag = B.keys()
    for _, f in ipairs(B.blizz()) do
        if not f.wpBagsHooked then
            f.wpBagsHooked = true
            f:HookScript("OnShow", function() safe(ns.bags.sync) end)
            f:HookScript("OnHide", function() safe(ns.bags.sync) end)
            -- parked under the hidden frame, a window being closed fires no OnHide (it was not
            -- visible to begin with), so the calls themselves are heard too (seen in game)
            for _, m in ipairs({ "Show", "Hide", "SetShown" }) do
                hooksecurefunc(f, m, function() safe(ns.bags.sync) end)
            end
        end
        local key = keyBag and f ~= ContainerFrameCombinedBags and f:GetID() == keyBag
        if on and f:IsShown() and (key or B.mine(f)) then
            if not f.wpHome then f.wpHome = f:GetParent() end
            f:SetParent(hider)
            if key then keys = true else open = true end
        elseif f.wpHome then
            f:SetParent(f.wpHome)
            f.wpHome = nil
        end
    end
    open = open or (on and B.wantPreview and B.wantPreview()) or false
    B.frame:SetShown(open)
    if open then B.layout() end
    local barKeys = on and keyBag ~= nil
    if on ~= (B.barOn or false) or B.barPending or barKeys ~= (B.barKeys or false) then
        B.barOn, B.barKeys = on, barKeys
        B.bar(on)
    end
    B.frame.keys:SetShown(keys)
    if keys then B.layoutKeys() end
end

function ns.bags.make()
    local B = ns.bags
    if B.frame then return end
    local f = CreateFrame("Frame", "WolfpackBags", UIParent)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self) -- kept as an offset from the screen's bottom right
        self:StopMovingOrSizing()
        db.bags.x = math.floor(self:GetRight() - UIParent:GetRight() + 0.5)
        db.bags.y = math.floor(self:GetBottom() + 0.5)
        ns.bags.layout()
    end)
    f:Hide()
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.bg:SetAllPoints()
    f.tags = {}
    for k, text in pairs(B.labels) do
        f.tags[k] = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f.tags[k]:SetText(text)
    end
    f.money = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.money:SetPoint("BOTTOMRIGHT", -8, 6)
    f.free = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.free:SetPoint("BOTTOMLEFT", 8, 6)
    f.sort = ns.ui.Button(f, "Sort", 44, true)
    f.sort:SetHeight(16)
    f.sort:SetPoint("BOTTOM", 0, 3)
    f.sort:SetScript("OnClick", function() pcall(ns.bags.api("SortBags")) end)
    f.side = CreateFrame("Frame", nil, f)
    f.side:SetPoint("TOPRIGHT", f, "TOPLEFT", -4, 0)
    f.side:EnableMouse(true)
    f.side.bg = f.side:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.side.bg:SetAllPoints()
    f.side.btns = {}
    -- the keys' panel is the screen's: the keyring opens without the bags too
    f.keys = CreateFrame("Frame", "WolfpackKeys", UIParent)
    f.keys:SetFrameStrata("HIGH")
    f.keys:EnableMouse(true)
    f.keys:Hide()
    f.keys.bg = f.keys:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.keys.bg:SetAllPoints()
    B.frame = f
end

-- contents change: one pass for many changes at once
ns.bags.ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN",
    "PLAYER_MONEY", "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED" }) do
    pcall(ns.bags.ev.RegisterEvent, ns.bags.ev, e)
end
ns.bags.ev:SetScript("OnEvent", function(_, event)
    local B = ns.bags
    if event == "PLAYER_REGEN_ENABLED" then
        if B.barPending then safe(B.bar, B.barOn) end
        return
    end
    if not (B.frame and (B.frame:IsShown() or B.frame.keys:IsShown())) or B.pending then return end
    B.pending = true
    C_Timer.After(0.05, function()
        B.pending = false
        if B.frame:IsShown() then safe(B.layout) end
        if B.frame.keys:IsShown() then safe(B.layoutKeys) end
    end)
end)

------------------------------------------------------------------------------------------
-- Unit frames: your party or raid in a block of frames, one side of it fixed, the other as long
-- as the group needs. Each frame is the game's secure unit button (left click targets, right
-- click opens the menu) with a health bar, a power bar under it, the name, role and raid marker
-- icons, buffs and debuffs. Which unit sits where, sizes and spots are set out of combat only;
-- in combat the game's unit watch shows and hides them, and bars and auras keep filling.
-- While the options are open, a stand-in group of `dummy` members shows instead.
------------------------------------------------------------------------------------------
ns.uf = { buttons = {}, byUnit = {} }
ns.uf.ROLE_ICON = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
ns.uf.ROLE_COORDS = { TANK = { 0, 19 / 64, 22 / 64, 41 / 64 }, HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 } }
ns.uf.DUMMY_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "PALADIN", "HUNTER", "WARLOCK", "SHAMAN" }
ns.uf.BLIZZ = { "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager",
    "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" }
function ns.uf.on() return db and db.unitframes.show and true or false end
function ns.uf.dummy() return ns.uf.on() and ns.configOpen and true or false end

function ns.uf.role(unit)
    local ok, r = pcall(UnitGroupRolesAssigned, unit)
    return ok and (r == "TANK" or r == "HEALER" or r == "DAMAGER") and r or "DAMAGER"
end

-- who gets a frame, in order: the group by role order (the game's order within a role), then
-- their pets. Each entry: { unit, pet = owner's unit } (stand-ins: { dummy = i, role, class }).
function ns.uf.roster()
    local o, list = db.unitframes, {}
    if ns.uf.dummy() then
        local roles = { "TANK", "HEALER", "HEALER", "DAMAGER", "DAMAGER" }
        for i = 1, o.dummy do
            list[i] = { dummy = i, role = i <= 2 and roles[i] or roles[(i % 3) + 3] or "DAMAGER",
                class = ns.uf.DUMMY_CLASSES[(i - 1) % #ns.uf.DUMMY_CLASSES + 1] }
            if i % 8 == 1 then list[i].role = "TANK" elseif i % 5 == 2 then list[i].role = "HEALER" end
        end
    elseif IsInRaid() then
        for i = 1, GetNumGroupMembers() or 0 do list[#list + 1] = { unit = "raid" .. i } end
    elseif (GetNumGroupMembers() or 0) > 0 then
        list[1] = { unit = "player" }
        for i = 1, 4 do if UnitExists("party" .. i) then list[#list + 1] = { unit = "party" .. i } end end
    end
    local rank = {}
    for i, r in ipairs(o.roles) do rank[r] = i end
    for i, e in ipairs(list) do e.i, e.role = i, e.role or ns.uf.role(e.unit) end
    table.sort(list, function(a, b)
        local x, y = rank[a.role] or 9, rank[b.role] or 9
        if x ~= y then return x < y end
        return a.i < b.i
    end)
    if o.pets then
        local n = #list
        for i = 1, n do
            local e, pet = list[i], nil
            if e.dummy then
                if e.class == "HUNTER" or e.class == "WARLOCK" then pet = { dummy = e.dummy, pet = e, class = e.class } end
            else
                local u = e.unit == "player" and "pet" or e.unit:gsub("^(%a+)(%d+)$", "%1pet%2")
                if UnitExists(u) then pet = { unit = u, pet = e } end
            end
            list[#list + 1] = pet
        end
    end
    return list
end

function ns.uf.button(i)
    local b = ns.uf.buttons[i]
    if b then return b end
    b = CreateFrame("Button", "WolfpackUnitFrame" .. i, ns.uf.frame, "SecureUnitButtonTemplate")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetAttribute("type1", "target")
    b:SetAttribute("type2", "togglemenu")
    b.health = newBar(b, "tothealth", "unitframes")
    b.power = newBar(b, "power", "unitframes")
    b.power.res = true -- read from b.unit, not yours
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.name:SetWordWrap(false) -- too long: cut short with dots
    b.role = b:CreateTexture(nil, "OVERLAY")
    b.role:SetTexture(ns.uf.ROLE_ICON)
    b.marker = b:CreateTexture(nil, "OVERLAY")
    b.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    b.icons = { buffs = {}, debuffs = {} }
    b:Hide()
    ns.uf.buttons[i] = b
    return b
end

-- the frames' spots: lines of `per`, players first, pets in lines of their own after them
function ns.uf.layout()
    local o, U = db.unitframes, ns.uf
    local list = U.roster()
    local wide = o.fixed ~= "height"
    local per = math.max(1, o.per)
    local along = (o.size - (per - 1) * o.gap) / per -- a frame's size along the fixed side
    local players = 0
    for _, e in ipairs(list) do if not e.pet then players = players + 1 end end
    U.count = players
    local dirX = (o.grow == "left") and -1 or 1
    local dirY = (o.grow == "up") and 1 or -1
    local corner = wide and (o.grow == "up" and "BOTTOMLEFT" or "TOPLEFT") or (o.grow == "left" and "TOPRIGHT" or "TOPLEFT")
    local f = U.frame
    f:ClearAllPoints()
    f:SetPoint(corner, UIParent, "CENTER", o.x, o.y)
    wipe(U.byUnit)
    local line, inLine, offset, lineSize, petsStarted = 0, 0, 0, 0, false
    for i, e in ipairs(list) do
        if e.pet and not petsStarted then -- pets start a line of their own
            petsStarted = true
            if inLine > 0 then offset, inLine = offset + lineSize + o.gap, 0 end
        end
        if inLine == per then offset, inLine = offset + lineSize + o.gap, 0 end
        local b = U.button(i)
        local h = e.pet and o.petHeight or o.cross
        local w, ht
        if wide then w, ht = along, h else w, ht = o.cross, e.pet and o.petHeight or along end
        if inLine == 0 then lineSize = wide and ht or w end
        -- along the line: frames of the same size, except pets in a column (their own height)
        local pos = wide and inLine * (along + o.gap) or nil
        if not wide then
            pos = 0
            for k = 1, inLine do pos = pos + ((list[i - k].pet and o.petHeight or along) + o.gap) end
        end
        b:ClearAllPoints()
        if wide then b:SetPoint(corner, f, corner, pos, dirY * offset)
        else b:SetPoint(corner, f, corner, dirX * offset, -pos) end
        b:SetSize(w, ht)
        b.entry, b.unit = e, e.unit
        b.wpW, b.wpH = w, ht
        b:SetAttribute("unit", e.unit)
        if e.unit then
            U.byUnit[e.unit] = b
            -- your own raid frame: the game may tell your changes as "player" only
            local okMe, me = pcall(function() return UnitIsUnit(e.unit, "player") and true or false end)
            if okMe and me then U.byUnit.player = b end
            RegisterUnitWatch(b)
        else
            UnregisterUnitWatch(b)
            b:Show()
        end
        U.style(b)
        inLine = inLine + 1
    end
    for i = #list + 1, #U.buttons do
        local b = U.buttons[i]
        UnregisterUnitWatch(b)
        b:SetAttribute("unit", nil)
        b.entry, b.unit = nil, nil
        b:Hide()
    end
    f:SetSize(wide and o.size or math.max(1, offset + lineSize), wide and math.max(1, offset + lineSize) or o.size)
end

-- a frame's bars, name, icons and auras for its unit (or stand-in)
function ns.uf.style(b)
    local o, e = db.unitframes, b.entry
    local pw = (o.power and not e.pet) and math.min(o.powerHeight, b.wpH - 2) or 0
    b.health.unit, b.power.unit = b.unit or "none", b.unit or "none" -- stand-ins: nobody (full bars)
    local over = { height = b.wpH - pw }
    local cls = e.class or (e.pet and e.pet.unit and select(2, UnitClass(e.pet.unit)))
    if e.dummy or e.pet then -- stand-ins and pets: their (owner's) class color, unless custom
        local c = cls and db.colors.class[cls]
        if c and o.bars.tothealth.colorMode == "class" then over.colorMode, over.color = "custom", c end
    end
    layoutBar(b.health, 1, b.wpW, over)
    b.health:ClearAllPoints()
    b.health:SetPoint("TOPLEFT", b, "TOPLEFT")
    b.power:SetShown(pw > 0)
    if pw > 0 then
        layoutBar(b.power, 1, b.wpW, { height = pw })
        b.power:ClearAllPoints()
        b.power:SetPoint("TOPLEFT", b.health, "BOTTOMLEFT")
    end
    b.name:SetFont(FONTS[1][2], o.fontSize, "OUTLINE")
    b.name:ClearAllPoints()
    b.name:SetPoint("CENTER", b.health, "CENTER")
    b.name:SetWidth(b.wpW - 4)
    local isize = math.max(8, math.min(16, b.wpH - pw - 4))
    b.role:SetSize(isize, isize)
    b.role:ClearAllPoints()
    b.role:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.marker:SetSize(isize, isize)
    b.marker:ClearAllPoints()
    b.marker:SetPoint("TOP", b, "TOP", 0, isize / 2)
    ns.uf.update(b)
end

-- what changes with the unit: fill, name, role, marker, auras
function ns.uf.update(b)
    local o, e = db.unitframes, b.entry
    if not e then return end
    ns.fill(b.health)
    if b.power:IsShown() then ns.fill(b.power) end
    if e.dummy then
        b.health.segs[1]:SetValue(0.35 + ((e.dummy * 37) % 65) / 100) -- a little hurt, each its own
        b.name:SetText(e.pet and "Pet" or (e.class:sub(1, 1) .. e.class:sub(2):lower() .. " " .. e.dummy))
    else
        pcall(b.name.SetText, b.name, UnitName(b.unit) or "")
    end
    local coords = not e.pet and o.roleIcon and ns.uf.ROLE_COORDS[e.role]
    b.role:SetShown(coords and true or false)
    if coords then b.role:SetTexCoord(unpack(coords)) end
    local ok, idx = pcall(GetRaidTargetIndex, b.unit)
    if e.dummy then ok, idx = true, (e.dummy == 1 and not e.pet) and 8 or nil end
    local mark = o.marker and ok and type(idx) == "number" and idx or nil
    b.marker:SetShown(mark ~= nil)
    if mark then
        local col, row = (mark - 1) % 4, math.floor((mark - 1) / 4)
        b.marker:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4)
    end
    ns.uf.auras(b)
end

-- buffs and debuffs: which ones, then a grid of `cols` x `rows` from the spot's corner inward
ns.uf.FILTERS = { buffs = { all = "HELPFUL", mine = "HELPFUL|PLAYER" },
    debuffs = { all = "HARMFUL", dispel = "HARMFUL|RAID" } }
function ns.uf.auras(b)
    local o = db.unitframes
    local big = (ns.uf.count or 0) > o.breakpoint
    for _, k in ipairs({ "buffs", "debuffs" }) do
        local a, icons = o[k], b.icons[k]
        local filter = ns.uf.FILTERS[k][a.mode]
        local max = math.min(a.max, a.cols * a.rows)
        local list = {}
        if filter and not b.entry.pet then
            if b.entry.dummy then list = ns.dummyAuras(k, max)
            else list = ns.auraList(b.unit, filter, max) or {} end
        end
        local spot = big and a.large or a.small
        local gx = spot.point:find("RIGHT") and -1 or 1
        local gy = spot.point:find("TOP") and -1 or 1
        local file = ns.ICON_MASKS[a.radius]
        for i = 1, math.max(#list, #icons) do
            local ic = icons[i]
            if not ic and i <= #list then
                ic = CreateFrame("Frame", nil, b)
                ic.tex = ic:CreateTexture(nil, "ARTWORK")
                ic.tex:SetAllPoints()
                ic.mask = ic:CreateMaskTexture()
                ic.mask:SetAllPoints(ic.tex)
                ic.cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
                ic.cd:SetAllPoints()
                ic.cd:SetReverse(true)
                ic.count = ic:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                ic.count:SetPoint("BOTTOMRIGHT", -1, 1)
                icons[i] = ic
            end
            if ic then
                ic:SetShown(i <= #list)
                if i <= #list then
                    local col, row = (i - 1) % a.cols, math.floor((i - 1) / a.cols)
                    ic:SetSize(a.size, a.size)
                    ic:SetFrameLevel(b:GetFrameLevel() + 8)
                    ic:ClearAllPoints()
                    ic:SetPoint(spot.point, b, spot.point, spot.x + gx * col * (a.size + 1), spot.y + gy * row * (a.size + 1))
                    ns.iconCorners(ic.tex, ic.mask, a.radius, { 0.08, 0.92, 0.08, 0.92 })
                    ic.cd:SetSwipeTexture(file and "Interface\\AddOns\\WolfpackAddon\\Media\\Icon\\" .. file .. ".tga"
                        or "Interface\\Buttons\\WHITE8X8")
                    ic.cd:SetSwipeColor(0, 0, 0, 0.7)
                    ic.cd:SetHideCountdownNumbers(a.hideTimer and true or false)
                    ns.drawAura(ic, b.unit, list[i])
                end
            end
        end
    end
end

-- Blizzard's party and raid frames parked under the hidden frame while ours replace them
function ns.uf.blizz(hide)
    for _, name in ipairs(ns.uf.BLIZZ) do
        local fr = _G[name]
        if fr then
            if hide and not fr.wpUfHome then fr.wpUfHome = fr:GetParent(); fr:SetParent(hider)
            elseif not hide and fr.wpUfHome then fr:SetParent(fr.wpUfHome); fr.wpUfHome = nil end
        end
    end
end

-- after a settings or group change: out of combat only (secure frames); in combat, once it ends
function ns.uf.sync()
    local U = ns.uf
    if not U.frame and not U.on() then return end
    if InCombatLockdown() then U.pending = true return end
    U.pending = false
    if not U.frame then
        U.frame = CreateFrame("Frame", "WolfpackUnitFrames", UIParent)
        U.frame:SetFrameStrata("LOW")
    end
    U.blizz(U.on() and db.unitframes.replace)
    U.frame:SetShown(U.on())
    if U.on() then U.layout() else
        for _, b in ipairs(U.buttons) do UnregisterUnitWatch(b); b:Hide() end
    end
end

ns.uf.ev = CreateFrame("Frame")
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "UNIT_PET", "PLAYER_REGEN_ENABLED",
    "PLAYER_ENTERING_WORLD", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
    "UNIT_DISPLAYPOWER", "UNIT_AURA", "UNIT_NAME_UPDATE", "RAID_TARGET_UPDATE" }) do
    pcall(ns.uf.ev.RegisterEvent, ns.uf.ev, e)
end
ns.uf.ev:SetScript("OnEvent", function(_, event, unit)
    local U = ns.uf
    if not U.on() then return end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "UNIT_PET"
        or event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_REGEN_ENABLED" and U.pending) then
        return safe(U.sync)
    elseif event == "RAID_TARGET_UPDATE" then
        for _, b in ipairs(U.buttons) do if b.entry and not b.entry.dummy then safe(U.update, b) end end
        return
    end
    local b = U.byUnit[unit]
    if not b then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then safe(ns.fill, b.health)
    elseif event == "UNIT_AURA" then safe(U.auras, b)
    elseif event == "UNIT_NAME_UPDATE" then safe(U.update, b)
    elseif b.power:IsShown() then safe(ns.fill, b.power) end
end)

bf = { rows = {} }
ns.bf = bf

------------------------------------------------------------------------------------------
-- Buff check: out of combat, who in the group is missing a buff that somebody here can give.
-- Only out of combat, because that is the only time this client answers aura questions -- and
-- it is the only time the answer is any use, since you buff before the pull.
------------------------------------------------------------------------------------------
-- One entry per buff a class hands out. `names` are all the spellings that satisfy it, so a
-- greater blessing counts as a blessing and Prayer of Fortitude counts as stamina. A paladin
-- can only keep one blessing on someone, so any single one satisfies the row.
bf.checks = {
    { key = "stamina", from = "PRIEST", label = "Stamina", icon = 1243,
        names = { "Power Word: Fortitude", "Prayer of Fortitude" } },
    { key = "spirit", from = "PRIEST", label = "Spirit", icon = 14752,
        names = { "Divine Spirit", "Prayer of Spirit" } },
    { key = "shadow", from = "PRIEST", label = "Shadow Protection", icon = 976,
        names = { "Shadow Protection", "Prayer of Shadow Protection" } },
    { key = "wild", from = "DRUID", label = "Mark of the Wild", icon = 1126,
        names = { "Mark of the Wild", "Gift of the Wild" } },
    { key = "thorns", from = "DRUID", label = "Thorns", icon = 467, names = { "Thorns" }, off = true },
    { key = "intellect", from = "MAGE", label = "Intellect", icon = 1459,
        names = { "Arcane Intellect", "Arcane Brilliance" } },
    { key = "blessing", from = "PALADIN", label = "A blessing", icon = 19740,
        names = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings",
            "Blessing of Salvation", "Blessing of Sanctuary", "Blessing of Light",
            "Greater Blessing of Might", "Greater Blessing of Wisdom", "Greater Blessing of Kings",
            "Greater Blessing of Salvation", "Greater Blessing of Sanctuary",
            "Greater Blessing of Light" } },
    { key = "shout", from = "WARRIOR", label = "Battle Shout", icon = 6673,
        names = { "Battle Shout" }, off = true },
}

-- Classes that should have something on their weapon: a rogue's poison, a shaman's enchant.
bf.weaponClasses = { ROGUE = true, SHAMAN = true }


bf.panel = CreateFrame("Frame", "WolfpackAddonBuffCheck", UIParent)
bf.panel:SetSize(200, 20)
bf.panel:SetMovable(true)
bf.panel:SetClampedToScreen(true)
bf.panel:RegisterForDrag("LeftButton")
bf.panel:SetScript("OnDragStart", function(a) a:StartMoving() end)
bf.panel:SetScript("OnDragStop", function(a)
    a:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    db.buffs.x = math.floor(a:GetCenter() - ux + 0.5)
    db.buffs.y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
    changed()
end)

function bf.icon(id)
    if not id then return 134400 end -- a question mark, for anything the client won't name
    bf.textures = bf.textures or {}
    if bf.textures[id] == nil then
        local ok, tex = pcall(function()
            return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id))
                or GetSpellTexture(id)
        end)
        bf.textures[id] = (ok and tex) or 134400
    end
    return bf.textures[id]
end

-- The units to check, and which classes are here to hand buffs out.
function bf.roster()
    local units, classes = { "player" }, {}
    if IsInRaid() then
        units = {}
        for i = 1, GetNumGroupMembers() or 0 do units[#units + 1] = "raid" .. i end
    else
        for i = 1, (GetNumGroupMembers() or 1) - 1 do units[#units + 1] = "party" .. i end
    end
    for _, u in ipairs(units) do
        if UnitExists(u) then
            local _, token = UnitClass(u)
            if token then classes[token] = true end
        end
    end
    return units, classes
end

-- Does this unit have any of these auras? Out of combat the game answers by name.
function bf.unitHas(unit, names)
    for _, name in ipairs(names) do
        local ok, data = pcall(function()
            local d = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
            if d then return d end
        end)
        if ok and data then return true, data end
    end
    return false
end

-- Minutes left on one of your own buffs, or nil when it cannot be worked out.
function bf.left(data)
    local ok, left = pcall(function()
        local exp = data.expirationTime
        if readable(exp) and exp and exp > 0 then return exp - GetTime() end
    end)
    return ok and left or nil
end

function bf.short(sec)
    if not sec or sec <= 0 then return "" end
    if sec >= 3600 then return math.floor(sec / 3600 + 0.5) .. "h" end
    if sec >= 60 then return math.floor(sec / 60 + 0.5) .. "m" end
    return math.floor(sec) .. "s"
end

-- A name for the list of who is missing something: first name, shortened.
function bf.who(unit)
    local n = UnitName(unit) or "?"
    n = n:match("^[^%s%-]+") or n
    return n:sub(1, 10)
end

function bf.row(i)
    local o = db.buffs
    local r = bf.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, bf.panel)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon:SetPoint("LEFT")
        r.text = r:CreateFontString(nil, "OVERLAY")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
        r.text:SetJustifyH("LEFT")
        bf.rows[i] = r
    end
    r:SetSize(260, o.size)
    r.icon:SetSize(o.size, o.size)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", bf.panel, "TOPLEFT", 0, -(i - 1) * (o.size + 2))
    local flags = o.outline and "OUTLINE" or ""
    if not r.text:SetFont(o.font, o.fontSize, flags) then r.text:SetFont(FONTS[1][2], o.fontSize, flags) end
    r:Show()
    return r
end

-- Builds the list: one row per buff somebody here can give, plus your weapon and your timers.
function bf.check()
    local o, lines = db.buffs, {}
    local units, classes = bf.roster()
    for _, chk in ipairs(bf.checks) do
        if classes[chk.from] and not o.skip[chk.key] and not (chk.off and o.skip[chk.key] ~= false) then
            local missing, mineLeft = {}, nil
            for _, u in ipairs(units) do
                if UnitExists(u) and not UnitIsDeadOrGhost(u) then
                    local has, data = bf.unitHas(u, chk.names)
                    if not has then
                        missing[#missing + 1] = bf.who(u)
                    elseif u == "player" then
                        mineLeft = bf.left(data)
                    end
                end
            end
            local text
            if #missing == 0 then
                text = chk.label .. ": all set" .. (mineLeft and (" (you " .. bf.short(mineLeft) .. ")") or "")
            elseif #missing > 4 then
                text = chk.label .. ": " .. #missing .. " missing"
            else
                text = chk.label .. ": " .. table.concat(missing, ", ")
            end
            lines[#lines + 1] = { icon = chk.icon, text = text, ok = #missing == 0 }
        end
    end
    -- Your weapon: a rogue's poison or a shaman's enchant, with what is left on it.
    if bf.weaponClasses[class or ""] and not o.skip.weapon then
        local ok, hasMain, mainMs, _, _, hasOff, offMs = pcall(GetWeaponEnchantInfo)
        if ok then
            local text = "Weapon: "
            if hasMain then text = text .. "main " .. bf.short((mainMs or 0) / 1000) else text = text .. "main missing" end
            if hasOff then
                text = text .. ", off " .. bf.short((offMs or 0) / 1000)
            elseif OffhandHasWeapon and OffhandHasWeapon() then
                text = text .. ", off missing"
            end
            lines[#lines + 1] = { icon = 135795, text = text, ok = hasMain and true or false }
        end
    end
    return lines
end

function bf.refresh()
    if not db then return end
    local o = db.buffs
    bf.panel:ClearAllPoints()
    bf.panel:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    bf.panel:EnableMouse(not o.locked)
    -- In combat the game answers nothing, so the list would be a guess: it steps aside instead.
    if not o.show or (InCombatLockdown() and not ns.previewing()) then
        bf.panel:Hide()
        return
    end
    bf.panel:Show()
    local lines = bf.check()
    local n = 0
    for _, line in ipairs(lines) do
        if not (line.ok and o.onlyMissing) then
            n = n + 1
            local r = bf.row(n)
            r.icon:SetTexture(bf.icon(line.icon))
            r.icon:SetDesaturated(line.ok and true or false)
            r.text:SetText(line.text)
            if line.ok then
                r.text:SetTextColor(0.5, 0.8, 0.5, 1)
            else
                r.text:SetTextColor(unpack(o.color))
            end
        end
    end
    if n == 0 and ns.previewing() then -- something to grab while placing it
        n = 1
        local r = bf.row(1)
        r.icon:SetTexture(bf.icon(1243))
        r.text:SetText("Buff check: all set")
        r.text:SetTextColor(0.5, 0.8, 0.5, 1)
    end
    for i = n + 1, #bf.rows do bf.rows[i]:Hide() end
    bf.panel:SetSize(260, math.max(n * (o.size + 2), 20))
end

ns.BUFF_CHECKS = bf.checks

local bfEv = CreateFrame("Frame")
ns.bfEv = bfEv
bfEv:SetScript("OnEvent", function() safe(bf.refresh) end)
for _, e in ipairs({ "UNIT_AURA", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "PLAYER_ALIVE", "GROUP_ROSTER_UPDATE", "PLAYER_DEAD",
    "UNIT_INVENTORY_CHANGED" }) do
    pcall(bfEv.RegisterEvent, bfEv, e)
end

------------------------------------------------------------------------------------------
-- Mage: how much conjured food and water is in the bags, always the best rank you carry.
------------------------------------------------------------------------------------------
mg = { entries = {} }
ns.mg = mg

-- Rounded icons use a mask of their own, scaled to the icon: the bars' nine-slice masks are
-- cut for long bars and collapse at icon size, which is what squeezed the art into a corner.
-- The radius is a share of the icon, so 12 and 25 are gentle and 50 is a circle.
ns.ICON_MASKS = { [12] = "i12", [25] = "i25", [50] = "i50" }

function ns.iconCorners(tex, mask, radius, coords)
    local file = ns.ICON_MASKS[radius]
    -- A mask covers the whole texture, not the part SetTexCoord kept, so a rounded icon is
    -- shown whole; a square one keeps the usual trim of its own border.
    tex:SetTexCoord(unpack(coords or (file and { 0, 1, 0, 1 }) or { 0.08, 0.92, 0.08, 0.92 }))
    if file then
        if mask.icon ~= file then
            mask:SetTexture("Interface\\AddOns\\WolfpackAddon\\Media\\Icon\\" .. file .. ".tga",
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask.icon = file
        end
        if not tex.iconMask then
            tex:AddMaskTexture(mask)
            tex.iconMask = true
        end
    elseif tex.iconMask then
        tex:RemoveMaskTexture(mask)
        tex.iconMask = nil
    end
end
-- Item id and the level it starts at, lowest rank first.
mg.ranks = {
    food = { { 5349, 1 }, { 1113, 5 }, { 1114, 15 }, { 1487, 25 }, { 8075, 35 }, { 8076, 45 },
        { 22895, 55 } },
    water = { { 5350, 1 }, { 2288, 5 }, { 2136, 15 }, { 3772, 25 }, { 8077, 35 }, { 8078, 45 },
        { 8079, 55 } },
}

mg.panel = CreateFrame("Frame", "WolfpackAddonMage", UIParent)
mg.panel:SetSize(80, 32)
mg.panel:SetMovable(true)
mg.panel:SetClampedToScreen(true)
mg.panel:RegisterForDrag("LeftButton")
mg.panel:SetScript("OnDragStart", function(a) a:StartMoving() end)
mg.panel:SetScript("OnDragStop", function(a)
    a:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    db.mage.x = math.floor(a:GetCenter() - ux + 0.5)
    db.mage.y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
    changed()
end)

-- The item's own icon, asked for by id so it is right even with empty bags.
function mg.icon(id)
    mg.icons = mg.icons or {}
    if mg.icons[id] == nil then
        local ok, tex = pcall(function()
            return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
                or (GetItemIcon and GetItemIcon(id))
        end)
        mg.icons[id] = (ok and tex) or 134062
    end
    return mg.icons[id]
end

-- How many of each conjured item are in the bags, by item id.
function mg.counts()
    local totals = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id then totals[id] = (totals[id] or 0) + (info.stackCount or 1) end
        end
    end
    return totals
end

-- The best rank you carry, or, carrying none, the rank your level can conjure.
function mg.best(kind, totals)
    local ranks = mg.ranks[kind]
    for i = #ranks, 1, -1 do
        local id = ranks[i][1]
        if (totals[id] or 0) > 0 then return id, totals[id] end
    end
    local level, id = (UnitLevel and UnitLevel("player")) or 1, ranks[1][1]
    for _, rank in ipairs(ranks) do
        if level >= rank[2] then id = rank[1] end
    end
    return id, 0
end

function mg.entry(i)
    local e = mg.entries[i]
    if not e then
        e = CreateFrame("Frame", nil, mg.panel)
        e.icon = e:CreateTexture(nil, "ARTWORK")
        e.icon:SetAllPoints()
        e.mask = e:CreateMaskTexture()
        e.mask:SetAllPoints(e)
        e.text = e:CreateFontString(nil, "OVERLAY")
        mg.entries[i] = e
    end
    return e
end

function mg.refresh()
    if not db then return end -- our events can arrive before the profile is loaded
    local o = db.mage
    mg.panel:ClearAllPoints()
    mg.panel:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    mg.panel:EnableMouse(not o.locked)
    if not o.show or class ~= "MAGE" then
        mg.panel:Hide()
        return
    end
    mg.panel:Show()
    local totals = mg.counts()
    local flags = o.outline and "OUTLINE" or ""
    local order = o.waterFirst and { "water", "food" } or { "food", "water" }
    for i, kind in ipairs(order) do
        local id, count = mg.best(kind, totals)
        local e = mg.entry(i)
        e:SetSize(o.size, o.size)
        e:ClearAllPoints()
        local step = o.size + o.gap
        if o.grow == "down" then
            e:SetPoint("TOPLEFT", mg.panel, "TOPLEFT", 0, -(i - 1) * step)
        else
            e:SetPoint("TOPLEFT", mg.panel, "TOPLEFT", (i - 1) * step, 0)
        end
        e.icon:SetTexture(mg.icon(id))
        e.icon:SetDesaturated(count == 0)
        ns.iconCorners(e.icon, e.mask, o.radius)
        if not e.text:SetFont(o.font, o.fontSize, flags) then
            e.text:SetFont(FONTS[1][2], o.fontSize, flags)
        end
        e.text:ClearAllPoints()
        e.text:SetPoint(o.countAt == "center" and "CENTER" or "BOTTOMRIGHT", e, 
            o.countAt == "center" and "CENTER" or "BOTTOMRIGHT", 0, 0)
        e.text:SetText(count)
        e.text:SetShown(o.showCount)
        if count <= o.low then
            e.text:SetTextColor(unpack(o.lowColor))
        else
            e.text:SetTextColor(unpack(o.color))
        end
        e:Show()
    end
    local step = o.size + o.gap
    mg.panel:SetSize(o.grow == "down" and o.size or (step + o.size),
        o.grow == "down" and (step + o.size) or o.size)
end

local mgEv = CreateFrame("Frame")
ns.mgEv = mgEv
mgEv:SetScript("OnEvent", function() safe(mg.refresh) end)
for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD",
    "PLAYER_LEVEL_UP", "PLAYER_LOGIN" }) do
    pcall(mgEv.RegisterEvent, mgEv, e)
end

------------------------------------------------------------------------------------------
-- Hunter: how much ammunition is left, and how the pet feels about you.
------------------------------------------------------------------------------------------
-- Blizzard's own happiness art: three faces side by side in one texture. Kept on the module
-- rather than as a local, because this file is at Lua's limit of 200 of them.
hn = { entries = {}, happyArt = "Interface\\PetPaperDollFrame\\UI-PetHappiness" }
ns.hn = hn
hn.panel = CreateFrame("Frame", "WolfpackAddonHunter", UIParent)
hn.panel:SetSize(80, 32)
hn.panel:SetMovable(true)
hn.panel:SetClampedToScreen(true)
hn.panel:RegisterForDrag("LeftButton")
hn.panel:SetScript("OnDragStart", function(a) a:StartMoving() end)
hn.panel:SetScript("OnDragStop", function(a)
    a:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    db.hunter.x = math.floor(a:GetCenter() - ux + 0.5)
    db.hunter.y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
    changed()
end)

-- What is in the ammo slot, and how much of it you are carrying in total.
function hn.ammo()
    local slot = 0 -- the ammo slot; GetInventorySlotInfo knows it by name on clients that have it
    pcall(function() slot = GetInventorySlotInfo("AmmoSlot") or slot end)
    local okID, id = pcall(GetInventoryItemID, "player", slot)
    local okCount, count = pcall(GetInventoryItemCount, "player", slot)
    local okIcon, icon = pcall(GetInventoryItemTexture, "player", slot)
    if not okID or type(id) ~= "number" then return nil, 0, nil end
    return id, (okCount and type(count) == "number") and count or 0, okIcon and icon or nil
end

-- How much ammo your quivers and ammo pouches hold: their slots times a stack. Without one, the
-- bar is simply full.
function hn.capacity(id, count)
    local okStack, stack = pcall(function()
        return (C_Item and C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(id))
            or select(8, GetItemInfo(id))
    end)
    stack = (okStack and type(stack) == "number" and stack > 0) and stack or 200
    local slots = 0
    for bag = 1, 4 do
        pcall(function()
            local free, family = (C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots)(bag)
            if type(family) == "number" and bit.band(family, 3) ~= 0 then -- 1: arrows, 2: bullets
                slots = slots + (C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots)(bag)
            end
        end)
    end
    return slots > 0 and slots * stack or math.max(count, 1)
end

-- Happiness has moved around between builds, so every route is tried. This client answers on
-- C_PetInfo.GetPetHappiness; older ones on the bare call, and Blizzard's own indicator frame
-- can be asked directly as a last resort. A failed pcall hands back its error text, and some
-- builds answer with a table, so only a real 1-3 counts.
function hn.happiness()
    for _, get in ipairs({
        function() return C_PetInfo.GetPetHappiness() end,
        function() return PetFrameHappiness:GetHappinessStats() end,
        function() return GetPetHappiness() end,
        function() return UnitPetHappiness("pet") end,
    }) do
        local ok, value = pcall(get)
        if ok and type(value) == "table" then
            value = value.happiness or value.happinessLevel or value.level
        end
        if ok and type(value) == "number" and value >= 1 and value <= 3 then
            return math.floor(value)
        end
    end
end

-- Blizzard's own indicator is already wearing the right face, so it is copied rather than
-- cropped by hand: on this build the art is an atlas, and the old coordinates land on some
-- unrelated corner of the file.
function hn.happyLook()
    local ok, look = pcall(function()
        for _, r in ipairs({ PetFrameHappiness:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "Texture" then
                local atlas = r.GetAtlas and r:GetAtlas()
                if atlas then return { atlas = atlas } end
                local tex = r.GetTexture and r:GetTexture()
                if tex then return { tex = tex, coords = { r:GetTexCoord() } } end
            end
        end
    end)
    return ok and type(look) == "table" and look or nil
end

function hn.entry(i)
    local e = hn.entries[i]
    if not e then
        e = CreateFrame("Frame", nil, hn.panel)
        e.icon = e:CreateTexture(nil, "ARTWORK")
        e.icon:SetAllPoints()
        e.mask = e:CreateMaskTexture()
        e.mask:SetAllPoints(e)
        e.text = e:CreateFontString(nil, "OVERLAY")
        hn.entries[i] = e
    end
    return e
end

-- The happiness dot on the pet bar and the ammo count on the power bar (the old panel is gone).
local HAPPY_KEYS = { "unhappy", "content", "happy" }
function ns.layoutHappy(f)
    local o = db[f.mode].bars.pethealth.happy
    local d = f.happyDot
    if not d then
        d = CreateFrame("Frame", nil, f)
        d.tex = d:CreateTexture(nil, "OVERLAY")
        d.tex:SetAllPoints()
        d.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        d.mask = d:CreateMaskTexture()
        d.mask:SetAllPoints(d.tex)
        ns.iconCorners(d.tex, d.mask, 50, { 0, 1, 0, 1 }) -- a circle
        f.happyDot = d
    end
    local level = (class == "HUNTER" and UnitExists("pet")) and hn.happiness() or (ns.previewing() and 3)
    d:SetShown((o.show and level) and true or false)
    if not d:IsShown() then return end
    d.tex:SetVertexColor(unpack(db.colors.happiness[HAPPY_KEYS[level]]))
    d:SetSize(o.size, o.size)
    d:SetFrameLevel(f:GetFrameLevel() + 8)
    d:ClearAllPoints()
    d:SetPoint("CENTER", f, o.point, o.x, o.y)
end

-- A flashing text while you drink (power bar) or eat (health bar), and while placing the bars.
ns.MEAL_TEXTS = { power = { "drinkText", "drinkHost", "drinking" }, health = { "eatText", "eatHost", "eating" } }
function ns.layoutMealText(f)
    local m = ns.MEAL_TEXTS[f.key]
    local c = db[f.mode].bars[f.key]
    local o = c[m[1]]
    if not f[m[1]] then
        f[m[2]] = CreateFrame("Frame", nil, f)
        f[m[2]]:SetAllPoints(f)
        f[m[1]] = f[m[2]]:CreateFontString(nil, "OVERLAY")
    end
    local t, host = f[m[1]], f[m[2]]
    t:SetShown((o.show and (ns[m[3]]("player") or ns.previewing())) and true or false)
    -- it flashes for as long as it shows
    host:SetScript("OnUpdate", t:IsShown() and function(h) h:SetAlpha(0.55 + 0.45 * math.cos(GetTime() * 6)) end or nil)
    if not t:IsShown() then host:SetAlpha(1) return end
    host:SetFrameLevel(f:GetFrameLevel() + 8)
    local flags = c.outline and "OUTLINE" or ""
    if not t:SetFont(c.font, o.size, flags) then t:SetFont(FONTS[1][2], o.size, flags) end
    t:SetTextColor(unpack(o.color))
    t:SetText(o.text)
    t:ClearAllPoints()
    t:SetPoint(o.point, f, o.point, o.x, o.y)
end

function hn.refresh()
    if not db then return end
    hn.panel:Hide()
    -- ammo coming or going changes the layout; otherwise the bar just fills
    if frames.ammo:IsShown() ~= (BARS.ammo.state() and db.regular.bars.ammo.show) then return changed() end
    for _, set in ipairs({ frames }) do
        if set.pethealth:IsShown() then safe(ns.layoutHappy, set.pethealth) end
        if set.ammo:IsShown() then safe(ns.fill, set.ammo) end
    end
end

local hnEv = CreateFrame("Frame")
ns.hnEv = hnEv
hnEv:SetScript("OnEvent", function() safe(hn.refresh) end)
for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "UNIT_PET",
    "UNIT_HAPPINESS", "PLAYER_LOGIN", "UNIT_INVENTORY_CHANGED" }) do
    pcall(hnEv.RegisterEvent, hnEv, e)
end

------------------------------------------------------------------------------------------
-- Warlock: how many soul shards are in the bags.
------------------------------------------------------------------------------------------
wl = { shard = 6265 } -- the item id of a Soul Shard
ns.wl = wl
wl.panel = CreateFrame("Frame", "WolfpackAddonWarlock", UIParent)
wl.panel:SetSize(32, 32)
wl.panel:SetMovable(true)
wl.panel:SetClampedToScreen(true)
wl.panel:RegisterForDrag("LeftButton")
wl.panel:SetScript("OnDragStart", function(a) a:StartMoving() end)
wl.panel:SetScript("OnDragStop", function(a)
    a:StopMovingOrSizing()
    local ux, uy = UIParent:GetCenter()
    db.warlock.x = math.floor(a:GetCenter() - ux + 0.5)
    db.warlock.y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
    changed()
end)
wl.entries = {}
wl.armors = { { "Demon Armor", 706, 20 }, { "Demon Skin", 696, 4 } } -- best first, and its level

function wl.entry(i)
    local e = wl.entries[i]
    if not e then
        e = CreateFrame("Frame", nil, wl.panel)
        e.icon = e:CreateTexture(nil, "ARTWORK")
        e.icon:SetAllPoints()
        e.mask = e:CreateMaskTexture()
        e.mask:SetAllPoints(e)
        e.text = e:CreateFontString(nil, "OVERLAY")
        wl.entries[i] = e
    end
    return e
end

-- Shards stack one to a slot, so this counts slots as well as stack sizes.
function wl.count()
    local total = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == wl.shard then total = total + (info.stackCount or 1) end
        end
    end
    return total
end

function wl.icons(id)
    wl.tex = wl.tex or {}
    if wl.tex[id] == nil then
        local ok, tex = pcall(function()
            if id == wl.shard then
                return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
                    or (GetItemIcon and GetItemIcon(id))
            end
            return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id))
                or (GetSpellTexture and GetSpellTexture(id))
        end)
        wl.tex[id] = (ok and tex) or 134336
    end
    return wl.tex[id]
end

-- Is that buff on you? Out of combat the game answers. In a fight it says nothing about any
-- aura -- but Blizzard's own buff buttons are still on screen wearing the icon, and reading a
-- texture off their frame is not an aura call, so it is not cut off. Returns true, false, or
-- nil when nobody will say.
function wl.iconOnBuffBar(tex)
    local found = nil
    pcall(function()
        for i = 1, 40 do
            local b = _G["BuffButton" .. i]
            local art = b and (b.icon or _G["BuffButton" .. i .. "Icon"])
            if not art then break end
            found = found or false
            if art:GetTexture() == tex then found = true end
        end
        if found ~= nil or not BuffFrame then return end
        local holder = BuffFrame.AuraContainer or BuffFrame
        for _, child in ipairs({ holder:GetChildren() }) do
            local art = child.icon or child.Icon
            if art then
                found = found or false
                if art:GetTexture() == tex then found = true end
            end
        end
    end)
    return found
end

-- Which armor should be on you, and whether it is. Either one counts while it is up.
--
-- In a fight nothing will say: the aura calls refuse, and Blizzard's buff icons do not compare
-- reliably either. So what is known out of the fight is remembered, and casting armor during
-- one updates that memory. The buff lasts half an hour; no fight outlives the answer.
function wl.armor()
    local combat = InCombatLockdown()
    local answered = false
    for _, sp in ipairs(wl.armors) do
        if not combat then
            local ok, data = pcall(function()
                local d = C_UnitAuras.GetAuraDataBySpellName("player", sp[1], "HELPFUL")
                if d then return d end
            end)
            if ok then answered = true end
            if ok and data then wl.memoUp, wl.memoSp = true, sp return sp, true end
        end
        if wl.iconOnBuffBar(wl.icons(sp[2])) == true then
            wl.memoUp, wl.memoSp = true, sp
            return sp, true
        end
    end
    -- the one you should be wearing is a question of level -- the spellbook on this client
    -- often answers nothing at all, the level always answers
    local lvl, best = UnitLevel("player") or 0, nil
    for _, sp in ipairs(wl.armors) do
        if lvl >= sp[3] and not best then best = sp end
    end
    if combat then
        if wl.memoUp then return wl.memoSp or best, true end
    elseif answered then
        wl.memoUp, wl.memoSp = false, nil -- out here the game is telling the truth
    end
    return best, false
end

-- Casting it in a fight is the one thing we do get told about.
function wl.sawCast(spellID)
    local ok, name = pcall(function()
        if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
        if type(info) == "table" then return info.name end
        if GetSpellInfo then return (GetSpellInfo(spellID)) end
    end)
    if not ok or type(name) ~= "string" then return end
    for _, sp in ipairs(wl.armors) do
        if name == sp[1] then wl.memoUp, wl.memoSp = true, sp end
    end
end

function wl.refresh()
    if not db then return end
    local o = db.warlock
    wl.panel:ClearAllPoints()
    wl.panel:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    wl.panel:EnableMouse(not o.locked)
    if not o.show or class ~= "WARLOCK" then
        wl.panel:Hide()
        return
    end
    wl.panel:Show()
    local flags, n, step = o.outline and "OUTLINE" or "", 0, o.size + o.gap
    local function place(e, icon, text, colored, size, fontSize)
        n = n + 1
        e:SetSize(size, size)
        e:ClearAllPoints()
        if o.grow == "down" then
            e:SetPoint("TOPLEFT", wl.panel, "TOPLEFT", 0, -(n - 1) * step)
        else
            e:SetPoint("TOPLEFT", wl.panel, "TOPLEFT", (n - 1) * step, 0)
        end
        e.icon:SetTexture(icon)
        ns.iconCorners(e.icon, e.mask, o.radius)
        local fs = fontSize or o.fontSize
        if not e.text:SetFont(o.font, fs, flags) then e.text:SetFont(FONTS[1][2], fs, flags) end
        e.text:ClearAllPoints()
        local at = o.countAt == "center" and "CENTER" or "BOTTOMRIGHT"
        e.text:SetPoint(at, e, at, 0, 0)
        e.text:SetText(text or "")
        e.text:SetShown(o.showCount and text ~= nil)
        e.text:SetTextColor(unpack(colored and o.lowColor or o.color))
        e:Show()
    end

    local count = wl.count()
    place(wl.entry(1), wl.icons(wl.shard), count, count <= o.low, o.size, o.fontSize)
    wl.entry(1).icon:SetDesaturated(count == 0)

    wl.lit = nil
    if o.armor then
        local sp, up = wl.armor()
        -- With "only when missing" on, a buff that is up needs no reminder at all.
        if sp and not (up and o.armorOnlyMissing) then
            local e = wl.entry(2)
            place(e, wl.icons(sp[2]), nil, false, o.armorSize or o.size,
                o.armorFontSize or o.fontSize)
            e.icon:SetDesaturated(false)
            e.icon:SetAlpha(1)
            wl.lit = (not up) and e or nil -- missing: it is the one that flashes
        end
    end
    for i = n + 1, #wl.entries do wl.entries[i]:Hide() end
    wl.panel:SetSize(o.grow == "down" and o.size or math.max(n * step - o.gap, o.size),
        o.grow == "down" and math.max(n * step - o.gap, o.size) or o.size)
end

-- The armor icon breathes while the buff is missing, and the duration ticks down on its own.
wl.ticker = CreateFrame("Frame")
wl.ticker.since = 0
wl.ticker:SetScript("OnUpdate", function(self, elapsed)
    if not db or not db.warlock.show or class ~= "WARLOCK" then return end
    if wl.lit and db.warlock.flash then -- all the way down and back, so it is hard to miss
        self.t = (self.t or 0) + elapsed
        wl.lit.icon:SetAlpha(0.1 + 0.9 * math.abs(math.sin(self.t * 2.6)))
    elseif wl.entries[2] then
        wl.entries[2].icon:SetAlpha(1)
    end
    self.since = self.since + elapsed
    if self.since < 1 then return end
    self.since = 0
    safe(wl.refresh)
end)

local wlEv = CreateFrame("Frame")
ns.wlEv = wlEv
wlEv:SetScript("OnEvent", function(_, ev, unit, _, spellID)
    if ev == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then return end
        safe(wl.sawCast, spellID)
    end
    safe(wl.refresh)
end)
for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN",
    "UNIT_AURA", "PLAYER_REGEN_ENABLED", "UNIT_SPELLCAST_SUCCEEDED" }) do
    pcall(wlEv.RegisterEvent, wlEv, e)
end

------------------------------------------------------------------------------------------
-- Weapon enchants: a rogue's poisons, a shaman's imbues. One icon per hand, shown when that
-- weapon has nothing on it, or when what it has is nearly gone. GetWeaponEnchantInfo is
-- inventory, not auras, so it answers in a fight as well as out of one.
------------------------------------------------------------------------------------------
we = { panels = {}, classOf = { rogue = "ROGUE", shaman = "SHAMAN" } }
ns.we = we

function we.panel(key)
    local p = we.panels[key]
    if not p then
        p = { entries = {} }
        p.frame = CreateFrame("Frame", "WolfpackAddon" .. key, UIParent)
        p.frame:SetSize(32, 32)
        p.frame:SetMovable(true)
        p.frame:SetClampedToScreen(true)
        p.frame:RegisterForDrag("LeftButton")
        p.frame:SetScript("OnDragStart", function(a) a:StartMoving() end)
        p.frame:SetScript("OnDragStop", function(a)
            a:StopMovingOrSizing()
            local ux, uy = UIParent:GetCenter()
            db[key].x = math.floor(a:GetCenter() - ux + 0.5)
            db[key].y = math.floor(select(2, a:GetCenter()) - uy + 0.5)
            changed()
        end)
        we.panels[key] = p
    end
    return p
end

function we.entry(p, i)
    local e = p.entries[i]
    if not e then
        e = CreateFrame("Frame", nil, p.frame)
        e.icon = e:CreateTexture(nil, "ARTWORK")
        e.icon:SetAllPoints()
        e.mask = e:CreateMaskTexture()
        e.mask:SetAllPoints(e)
        e.text = e:CreateFontString(nil, "OVERLAY")
        p.entries[i] = e
    end
    return e
end

-- What is on each hand: the weapon's own icon, whether it is enchanted, and the minutes left.
-- In a fight the answer is not to be trusted, and nothing can be done about it anyway, so the
-- last reading from before the fight stands: you went in bare, and the icon keeps saying so.
function we.hands()
    if InCombatLockdown() then return we.cache or {} end
    local ok, hasMain, mainMs, _, _, hasOff, offMs = pcall(GetWeaponEnchantInfo)
    if not ok then return {} end
    local out = {}
    for i, slot in ipairs({ 16, 17 }) do -- main hand, off hand
        local gotIcon, icon = pcall(GetInventoryItemTexture, "player", slot)
        if gotIcon and icon then
            local has = i == 1 and hasMain or hasOff
            local ms = i == 1 and mainMs or offMs
            out[#out + 1] = { icon = icon, has = has and true or false,
                minutes = (type(ms) == "number" and ms > 0) and (ms / 60000) or nil }
        end
    end
    we.cache = out
    return out
end

function we.refresh(key)
    if not db then return end
    local o = db[key]
    local p = we.panel(key)
    p.frame:ClearAllPoints()
    p.frame:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    p.frame:EnableMouse(not o.locked)
    if not o.show or class ~= we.classOf[key] then
        p.frame:Hide()
        return
    end
    p.frame:Show()
    local flags, n, step = o.outline and "OUTLINE" or "", 0, o.size + o.gap
    p.lit = {}
    for _, hand in ipairs(we.hands()) do
        -- Nothing on it: a reminder. Nearly gone, and out of combat where you can do something
        -- about it: the same icon with the minutes left. Otherwise nothing at all.
        local missing = not hand.has
        local low = hand.has and hand.minutes and hand.minutes <= o.warn
            and not InCombatLockdown()
        if missing or low then
            n = n + 1
            local e = we.entry(p, n)
            e:SetSize(o.size, o.size)
            e:ClearAllPoints()
            if o.grow == "down" then
                e:SetPoint("TOPLEFT", p.frame, "TOPLEFT", 0, -(n - 1) * step)
            else
                e:SetPoint("TOPLEFT", p.frame, "TOPLEFT", (n - 1) * step, 0)
            end
            e.icon:SetTexture(hand.icon)
            e.icon:SetAlpha(1)
            ns.iconCorners(e.icon, e.mask, o.radius)
            if not e.text:SetFont(o.font, o.fontSize, flags) then
                e.text:SetFont(FONTS[1][2], o.fontSize, flags)
            end
            e.text:ClearAllPoints()
            local at = o.countAt == "center" and "CENTER" or "BOTTOMRIGHT"
            e.text:SetPoint(at, e, at, 0, 0)
            e.text:SetText(low and (math.floor(hand.minutes) .. "m") or "")
            e.text:SetShown(low and true or false)
            e.text:SetTextColor(unpack(low and o.warnColor or o.color))
            p.lit[n] = missing -- only a bare weapon flashes
            e:Show()
        end
    end
    for i = n + 1, #p.entries do p.entries[i]:Hide() end
    p.frame:SetSize(o.grow == "down" and o.size or math.max(n * step - o.gap, o.size),
        o.grow == "down" and math.max(n * step - o.gap, o.size) or o.size)
end

we.ticker = CreateFrame("Frame")
we.ticker.since = 0
we.ticker:SetScript("OnUpdate", function(self, elapsed)
    if not db then return end
    self.t = (self.t or 0) + elapsed
    local a = 0.1 + 0.9 * math.abs(math.sin(self.t * 2.6))
    for key, p in pairs(we.panels) do
        if db[key] and db[key].flash then
            for i, lit in pairs(p.lit or {}) do
                if lit and p.entries[i] then p.entries[i].icon:SetAlpha(a) end
            end
        end
    end
    self.since = self.since + elapsed
    if self.since < 1 then return end
    self.since = 0
    safe(we.refresh, "rogue")
    safe(we.refresh, "shaman")
end)

ns.weEv = CreateFrame("Frame")
ns.weEv:SetScript("OnEvent", function()
    safe(we.refresh, "rogue")
    safe(we.refresh, "shaman")
end)
for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "BAG_UPDATE" }) do
    pcall(ns.weEv.RegisterEvent, ns.weEv, e)
end

------------------------------------------------------------------------------------------
-- Options window (/cpd)
------------------------------------------------------------------------------------------
-- section = sidebar entry, sub = tab inside Nameplates, mode = which bar layout is being edited
local cfg, selected, mode, section, sub = nil, "health", "regular", "combat", "plates"
-- Classes the addon has settings of its own for: { section key, label, class token }
ns.CLASS_SECTIONS = { { "mage", "Mage", "MAGE" },
    { "rogue", "Rogue", "ROGUE" }, { "shaman", "Shaman", "SHAMAN" },
    { "warlock", "Warlock", "WARLOCK" } }
local refreshers = {}

changed = function()
    safe(Refresh)
    safe(ns.np.all)
    safe(ns.bags.sync)
    safe(ns.uf.sync)
    for _, fn in ipairs(refreshers) do fn() end
end

local function L() return db[mode] end
-- The nameplate has two bars of its own; the bar picked on Combat Display comes back after
ns.PLATE_BARS = { "enemyhealth", "targetcast" }
ns.PLATE_LABELS = { enemyhealth = "Health", targetcast = "Cast bar" }
function ns.platesMode(on, other)
    if on and mode ~= "plates" then ns.barPicked = selected end
    if not on and mode == "plates" then selected = ns.barPicked or selected end
    mode = on and "plates" or other
    if on and not ns.PLATE_LABELS[selected] then selected = "enemyhealth" end
end
local function cur() return L().bars[selected] end
local function onRefresh(fn) refreshers[#refreshers + 1] = fn end

-- A titled card that stacks rows: row(h) gives the y for a widget that tall. The lowest card on
-- any page decides how tall the options window needs to be. Look: UI.lua.
local pageBottom = 0
local function group(parent, x, y, w, title)
    ns.boxesOn = ns.boxesOn or {}
    ns.boxesOn[parent] = (ns.boxesOn[parent] or 0) + 1
    local g = { x = x + 12, cursor = y - 34, w = w }
    g.title = parent:CreateFontString(nil, "OVERLAY", ns.ui.HEADING)
    g.title:SetPoint("TOPLEFT", x + 12, y - 12)
    g.title:SetText(title)
    function g:row(h)
        local at = self.cursor
        self.cursor = at - h
        return at
    end
    function g:close()
        local bottom = self.cursor - 8
        pageBottom = math.min(pageBottom, bottom)
        ns.cards = ns.cards or {}
        ns.cards[parent] = ns.cards[parent] or {}
        table.insert(ns.cards[parent], { x = x, bottom = bottom })
        ns.ui.card(parent, x, y, w, y - bottom)
        return self
    end
    return g
end

local function label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", ns.ui.font(font))
    fs:SetText(text)
    return fs
end

-- ghost: the sidebar's look, no fill until hovered or picked
local function button(parent, text, w, x, y, onClick, ghost)
    local b = ns.ui.Button(parent, text, w, ghost)
    b:SetPoint("TOPLEFT", x, y)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onClick)
    return b
end

local function check(parent, text, x, y, get, set)
    local cb = ns.ui.Check(parent, text)
    cb:SetPoint("TOPLEFT", x, y - 4)
    cb:SetScript("OnClick", function(self) set(self:GetChecked()); changed() end)
    onRefresh(function() cb:SetChecked(get()) end)
    return cb
end

local function num(v) return type(v) == "function" and v() or v end

-- min/max may be functions, for ranges that depend on the open tab.
local function slider(parent, text, x, y, min, max, get, set, step)
    step = step or 1 -- whole numbers unless a caller wants finer
    local s = ns.ui.Slider(parent, 124) -- 124 + 10 + 44 fits a card's inner width
    s:SetPoint("TOPLEFT", x, y - 20)
    s:SetMinMaxValues(num(min), num(max))
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true) -- wheel = +/-1 for exact values
    s.label = label(s, text, "GameFontNormalSmall")
    s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)
    local syncing
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        if not syncing and v ~= get() then set(v); changed() end
    end)
    s:SetScript("OnMouseWheel", function(_, d) s:SetValue(s:GetValue() + d * step) end)

    -- Typed value: Enter or clicking away applies it (clamped to the slider range), Escape cancels.
    local box = ns.ui.Input(s, 44)
    box:SetPoint("LEFT", s, "RIGHT", 10, 0)
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
        -- a dialog's sliders refresh while it is hidden too, against whatever bar is picked;
        -- one that bar has no setting for just rests at its minimum
        local v = tonumber(get()) or num(min)
        syncing = true
        s:SetMinMaxValues(num(min), num(max))
        s:SetValue(v)
        syncing = false
        if not box:HasFocus() then box:SetText(tostring(v)) end
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
    local fillTex = ns.ui.box(b, ns.ui.C.fg, ns.ui.C.ring, 5)
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
    local dd = ns.ui.Dropdown(CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate"))
    dd:SetPoint("TOPLEFT", x, y - 16)
    dd:SetSize(178, 26)
    label(dd, text, "GameFontNormalSmall"):SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 4)
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
-- A profile saved before a bar existed keeps its own order, and merge leaves a list it already
-- has alone -- so without this a new bar would never appear for anybody who had played before.
-- Unknown names are dropped at the same time, which is what a removed bar leaves behind.
function ns.repairOrder(layout, default)
    if type(layout) ~= "table" or type(layout.order) ~= "table" then return end
    local seen, kept = {}, {}
    for _, key in ipairs(layout.order) do
        if BARS[key] and not seen[key] then
            seen[key] = true
            kept[#kept + 1] = key
        end
    end
    for _, key in ipairs(default) do
        if not seen[key] then kept[#kept + 1] = key end
    end
    layout.order = kept
end

useProfile = function(name)
    store.profiles[name] = merge(store.profiles[name] or ns.freshProfile(name), DEFAULTS)
    for _, which in ipairs({ "regular", "plates" }) do
        ns.repairOrder(store.profiles[name][which], DEFAULTS[which].order)
    end
    store.chars[charKey] = name
    db = store.profiles[name]
    if not db.regular.bars.ammo.hunterSet then -- the Hunter page's panel moves onto the bars
        local H, am = db.hunter, db.regular.bars.ammo
        am.show = (H.show and H.ammo) and true or false
        am.font, am.fontSize, am.outline = H.font, H.fontSize, H.outline
        db.regular.bars.pethealth.happy.show = (H.show and H.pet) and true or false
        db.regular.bars.ammo.hunterSet = true
    end
    local AB = db.actionbars
    if not AB.seeded then -- one bar to start with: the first twelve slots, at the bottom
        AB.bars[1] = AB.bars[1] or merge({}, ns.AB_BAR)
        AB.seeded = true
    end
    for _, bar in ipairs(AB.bars) do merge(bar, ns.AB_BAR) end
    local P = db.colors
    if not P.bordersSet then -- a bar that already had a border or rounded corners keeps them as its own
        for _, m in ipairs({ "regular", "plates" }) do
            for _, b in pairs(db[m].bars) do
                if type(b) == "table" and ((b.borderSize or 0) ~= 0 or (b.radius or 0) ~= 0) then b.borderFrom = "own" end
            end
        end
        P.bordersSet = true
    end
    if not P.texturesSet then -- a bar with a texture other than the first keeps it as its own
        for _, m in ipairs({ "regular", "plates" }) do
            for _, b in pairs(db[m].bars) do
                if type(b) == "table" and b.texture and b.texture ~= TEXTURES[1][2] then b.textureFrom = "own" end
            end
        end
        P.texturesSet = true
    end
    if not P.moved then -- colors that lived on single bars move into the palette
        local pc = db.regular.bars.power.powerColors
        for token, c in pairs(type(pc) == "table" and pc or {}) do
            if P.power[token] and type(c) == "table" then P.power[token] = { unpack(c) } end
        end
        local tc = db.regular.bars.targetcast
        for kind, key in pairs({ harm = "harmColor", heal = "healColor", locked = "lockedColor" }) do
            if type(tc[key]) == "table" then P.cast[kind] = { unpack(tc[key]) } end
        end
        for _, m in ipairs({ "regular", "plates" }) do
            local bars = db[m].bars
            bars.power.powerColors = nil
            bars.targetcast.harmColor, bars.targetcast.healColor, bars.targetcast.lockedColor = nil, nil, nil
            for _, b in pairs(bars) do -- a class-colored border is now "same as bar" or your own
                if b.borderMode == "class" then b.borderMode = "bar" end
                if b.resBorderMode == "class" then b.resBorderMode = "bar" end
            end
        end
        P.moved = true
    end
    local ci = db.regular.combatIcon
    if type(ci) == "table" then -- the old in-combat icon becomes your health bar's status icon
        local st = db.regular.bars.health.statusIcon
        st.show, st.style, st.size = ci.show and true or false, ci.style or st.style, ci.size or st.size
        if ci.bar == nil or ci.bar == "health" then -- its spot: x from the middle, or (older) the left edge
            st.point, st.x, st.y = ci.fromCenter and "CENTER" or "LEFT", ci.x or st.x, ci.y or st.y
        end
        db.regular.combatIcon = nil
    end
    for _, m in ipairs({ "regular", "plates" }) do
        for _, key in ipairs({ "health", "power", "enemyhealth", "experience" }) do
            local b = db[m].bars[key]
            if not b.textsSet then -- the one text it had becomes "current", as it looked
                b.texts.current.size, b.texts.current.color = b.fontSize, { unpack(b.textColor) }
                b.textsSet = true
            end
        end
        local tc = db[m].bars.targetcast
        if not tc.autoSet then
            if tc.colorMode == "custom" then tc.colorMode = "auto" end
            tc.autoSet = true
        end
    end
    if db.regular.bars.health.target then
        db.regular.bars.health.target = false
        db.regular.bars.enemyhealth.show, db.regular.bars.enemyhealth.beside = true, true
    end
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
--  * the addon profile: "WPA1:" + base64(deflate(CBOR{ name, profile, combatFont, barStack })),
--    imported here; barStack is the Bar Stack bars this character loads, which have no string of their own
--  * the WoW UI layout: Blizzard's own Edit Mode string, imported in Edit Mode itself, because
--    writing Edit Mode layouts from an addon would get overwritten or taint Edit Mode
------------------------------------------------------------------------------------------
local E = C_EncodingUtil

-- A profile whose name holds a class name belongs to that class, so one string can carry
-- "Alpha Priest", "Alpha Warrior" and the rest, and each character lands on its own.
ns.CLASS_NAMES = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage",
    "Warlock", "Druid" }

local function classOfProfile(name)
    local low, best = name:lower(), nil
    for _, cls in ipairs(ns.CLASS_NAMES) do
        if low:find(cls:lower(), 1, true) then best = cls:upper() end
    end
    return best
end

-- `all` packs every profile you have into the one string, instead of only the one in use.
local function exportString(all)
    local data = { name = store.chars[charKey], profile = db, combatFont = db.other.combatFont,
        barStack = ns.bs and ns.bs.profile and ns.bs.ExportSet() }
    if all then
        data.profiles, data.classes = {}, {}
        for name, prof in pairs(store.profiles) do
            data.profiles[name] = prof
            local token = classOfProfile(name)
            -- the most specific name wins, so "Alpha Priest" beats a plain "Priest"
            if token and #name > #(data.classes[token] or "") then data.classes[token] = name end
        end
    end
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
        elseif k == "bars" and next(def) == nil then -- action bars: a list, each a bar's settings
            out.bars = {}
            for _, b in ipairs(type(v) == "table" and v or {}) do
                if type(b) == "table" and #out.bars < 20 then out.bars[#out.bars + 1] = sanitize(b, ns.AB_BAR) end
            end
        elseif k == "binds" then -- action slot -> key
            out.binds = {}
            for slot, key in pairs(type(v) == "table" and v or {}) do
                local n = tonumber(slot)
                local kind, i = tostring(slot):match("^(%a+):(%d+)$")
                local ok = (n and n >= 1 and n <= ns.AB_POOL) or ((kind == "stance" or kind == "pet") and tonumber(i) <= 10)
                if ok and type(key) == "string" and #key <= 40 then out.binds[n and tostring(n) or slot] = key end
            end
        elseif k == "hover" then -- a map: only known elements, only true
            out.hover = {}
            for _, e in ipairs(HOVER_FRAMES) do
                if type(v) == "table" and v[e[1]] == true then out.hover[e[1]] = true end
            end
        elseif k == "list" then -- buff reminders: { name, id, show }
            out.list = {}
            for _, e in ipairs(type(v) == "table" and v or {}) do
                local name = type(e) == "table" and e.name
                if type(name) == "string" and name ~= "" then
                    local dur = tonumber(e.duration) or 18
                    out.list[#out.list + 1] = { name = name:sub(1, 64), id = tonumber(e.id) or 0,
                        show = e.show == true, duration = math.max(1, math.min(600, dur)) }
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
    local mine = data and type(data.profiles) == "table" and data.profiles[name or ""]
    local prof = merge(data and sanitize(mine or data.profile, DEFAULTS) or {}, DEFAULTS)
    for _, f in ipairs(COMBAT_FONTS) do -- strings from before the font moved into the profile
        if data and data.combatFont == f[2] and f[2] ~= "" then prof.other.combatFont = f[2] end
    end
    return prof
end

-- A fresh account (or this beta, which forgets everything) starts from the bundle baked into
-- the addon: every profile in it, and which class each one belongs to.
seedFromBaked = function()
    if next(store.profiles) then return end -- there is already something here
    local data = decodeExport(DEFAULT_PROFILE)
    if not data or type(data.profiles) ~= "table" then return end
    for pname, prof in pairs(data.profiles) do
        if type(pname) == "string" and pname ~= "" and type(prof) == "table" then
            store.profiles[pname] = sanitize(prof, DEFAULTS)
        end
    end
    if type(data.classes) == "table" then
        for token, pname in pairs(data.classes) do
            if store.profiles[pname] then store.classProfiles[token] = pname end
        end
    end
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
    -- A bundle: every profile in it lands under its own name, replacing one of the same name,
    -- and each class is remembered so its characters start on the right one.
    if type(data.profiles) == "table" then
        local first, count = nil, 0
        for pname, prof in pairs(data.profiles) do
            local clean = type(pname) == "string" and strtrim(pname):sub(1, 32) or ""
            if clean ~= "" and type(prof) == "table" then
                store.profiles[clean] = sanitize(prof, DEFAULTS)
                first, count = first or clean, count + 1
            end
        end
        store.classProfiles = {}
        if type(data.classes) == "table" then
            for token, pname in pairs(data.classes) do
                if type(pname) == "string" and store.profiles[pname] then
                    store.classProfiles[token] = pname
                end
            end
        end
        if count == 0 then return nil, "The string holds no profiles. Copy it again in full." end
        local mine = store.classProfiles[class or ""]
        if not (mine and store.profiles[mine]) then mine = data.name end
        useProfile(store.profiles[mine or ""] and mine or first)
        ns.importBarStack(data)
        return store.chars[charKey], nil, count
    end
    local base = type(data.name) == "string" and strtrim(data.name):sub(1, 32) or ""
    if base == "" then base = "Imported" end
    local name = freeName(base)
    store.profiles[name] = sanitize(data.profile, DEFAULTS)
    for _, f in ipairs(COMBAT_FONTS) do -- older strings carried the font outside the profile
        if data.combatFont == f[2] and f[2] ~= "" then store.profiles[name].other.combatFont = f[2] end
    end
    useProfile(name)
    ns.importBarStack(data)
    return name, type(data.editMode) == "string" and data.editMode or nil
end
-- The Bar Stack bars the string carries join the library and load on this character
function ns.importBarStack(data)
    if type(data.barStack) == "table" and ns.bs and ns.bs.ImportProfile then
        pcall(ns.bs.ImportProfile, data.barStack)
    end
end
ns.exportString, ns.editModeString, ns.importString = exportString, editModeString, importString
ns.seedFromBaked = function() return seedFromBaked() end
ns.useProfile = useProfile

-- Another profile's settings replace the current one's; the name stays. Bar Stack is not part
-- of a profile: its bars are one library, loaded per character.
function ns.copyProfile(from)
    local into = store.chars[charKey]
    if from == into then return end
    wipe(db)
    merge(db, store.profiles[from] or ns.freshProfile(from))
    useProfile(into)
end

StaticPopupDialogs.WOLFPACKADDON_COPY = {
    text = "Copy profile \"%s\" onto \"%s\"?\nIts current settings are replaced.",
    button1 = YES, button2 = NO,
    OnAccept = function(_, from) ns.copyProfile(from) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs.WOLFPACKADDON_RESET = {
    text = "Reset profile \"%s\" to its defaults?\nEvery page but Bar Stack starts over.",
    button1 = YES, button2 = NO,
    OnAccept = function()
        wipe(db)
        merge(db, ns.freshProfile(store.chars[charKey]))
        place()
        changed()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs.WOLFPACKADDON_DELBAR = {
    text = "Delete action bar %s? Its spells stay in their action slots.",
    button1 = YES, button2 = NO,
    OnAccept = function(_, i) table.remove(db.actionbars.bars, i); changed() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs.WOLFPACKADDON_DELETE = {
    text = "Delete Wolfpack Addon profile \"%s\"?\nCharacters on it go back to their class profile.",
    button1 = YES, button2 = NO,
    OnAccept = function(_, name) deleteProfile(name) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local openStops -- the gradient points dialog, defined below


function ns.textArea(parent, y, h) -- on the namespace: this chunk is at Lua's 200-local ceiling
    local area = CreateFrame("Frame", nil, parent)
    area:SetPoint("TOPLEFT", 14, y)
    area:SetPoint("TOPRIGHT", -14, y)
    area:SetHeight(h)
    ns.ui.box(area, ns.ui.C.input, ns.ui.C.border, 6)
    local sf = ns.ui.Scroll(CreateFrame("ScrollFrame", nil, area, "UIPanelScrollFrameTemplate"))
    sf:SetPoint("TOPLEFT", 8, -6)
    sf:SetPoint("BOTTOMRIGHT", -24, 6)
    local box = CreateFrame("EditBox", nil, sf)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)
    box:SetFontObject(ns.ui.SMALL)
    box:SetWidth(470)
    box:SetScript("OnEscapePressed", function() box:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function() box:HighlightText() end) -- click, Ctrl+C
    sf:SetScrollChild(box)
    area.box = box
    return area
end

local function openIO(mode)
    local f = ns.ioFrame
    if not f then
        f = ns.ui.Window("WolfpackAddonIO", 540, 410, "")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f.title = f.TitleText
        f.label1 = label(f, "", "GameFontNormalSmall")
        f.label1:SetPoint("TOPLEFT", 16, -50)
        f.all = ns.ui.Check(f, "All profiles in one string")
        f.all:SetPoint("TOPLEFT", 340, -48)
        f.all:SetScript("OnClick", function(self)
            f.area1.box:SetText(exportString(self:GetChecked()))
            f.area1.box:SetFocus()
        end)
        f.area1 = ns.textArea(f, -68, 104)
        f.label2 = label(f, "2. WoW UI layout (Edit Mode). Import it in Edit Mode: Layout dropdown, Import.",
            "GameFontNormalSmall")
        f.label2:SetPoint("TOPLEFT", 16, -184)
        f.area2 = ns.textArea(f, -202, 104)
        f.note = label(f, "", "GameFontDisableSmall")
        f.note:SetPoint("TOPLEFT", 16, -318)
        f.note:SetWidth(505)
        f.note:SetJustifyH("LEFT")
        f.import = ns.ui.Button(f, "Import", 100)
        f.import:SetPoint("BOTTOMRIGHT", -16, 14)
        f.import:SetScript("OnClick", function()
            local name, extra, count = importString(f.area1.box:GetText())
            if not name then
                f.note:SetText("|cffff5555" .. extra .. "|r")
            else
                f.area1.box:SetText("")
                f.note:SetText((count and ("Imported " .. count .. " profiles; this character is on \""
                        .. tostring(name) .. "\". Others start on the one named after their class.")
                    or ("Imported as profile \"" .. name .. "\" and switched to it."))
                    .. (extra and " This older string also held a WoW UI layout: it's in the box below, "
                        .. "for Edit Mode's Import." or ""))
                f.area2:SetShown(extra ~= nil)
                f.label2:SetShown(extra ~= nil)
                if extra then f.area2.box:SetText(extra) end
            end
        end)
        ns.ioFrame = f
    end
    local export = mode == "export"
    f.title:SetText(export and "Export" or "Import profile")
    f.import:SetShown(not export)
    f.all:SetShown(export)
    f.area2:SetShown(export)
    f.label2:SetShown(export)
    if export then
        f.label1:SetText("1. Addon profile. Import it on the Profiles page.")
        f.area1.box:SetText(exportString(f.all:GetChecked()))
        f.area2.box:SetText(editModeString() or "(The WoW UI layout isn't available right now.)")
        f.note:SetText("Click a box, then Ctrl+C. Keep the profile string somewhere safe: the beta forgets "
            .. "addon settings when the game restarts, and it brings them back. Tick \"All profiles\" to "
            .. "pack every one you have into the same string -- name them after a class, like \"Alpha "
            .. "Priest\", and each character starts on its own.")
        f.area1.box:SetFocus()
    else
        f.label1:SetText("Paste an addon profile string (starts with WPA1:), then click Import.")
        f.area1.box:SetText("")
        f.note:SetText("A single profile becomes a new one. A string with several replaces the profiles "
            .. "of the same name. WoW UI layout strings go into Edit Mode's own Import.")
        f.area1.box:SetFocus()
    end
    f:Show()
end

-- Gradient points dialog: percent + color per point, for the bar picked in the options.
local stopsFrame
function openStops()
    local f = stopsFrame
    if not f then
        f = ns.ui.Window("WolfpackAddonStops", 340, 350, "Gradient points")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f.title = f.TitleText
        label(f, "Percent across the bar, and the color there.", "GameFontDisableSmall")
            :SetPoint("TOPLEFT", 16, -50)
        f.rows = {}
        for i = 1, MAX_STOPS do
            local y = -70 - (i - 1) * 28
            local row = CreateFrame("Frame", nil, f)
            row:SetPoint("TOPLEFT", 16, y)
            row:SetSize(300, 24)
            local box = ns.ui.Input(row, 44)
            box:SetPoint("TOPLEFT", 0, 0)
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
        f.add = button(f, "Add point", 100, 16, -74 - MAX_STOPS * 28, function()
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

function ns.foldColumns(page, COL, TOP)
    local cards, low = ns.cards and ns.cards[page] or {}, TOP
    for _, c in ipairs(cards) do
        if c.x < COL[3] then low = math.min(low, c.bottom) end
    end
    local dx, dy = COL[1] - COL[3], low - 20 - TOP
    local need = -low
    for _, c in ipairs(cards) do
        need = math.max(need, -(c.x < COL[3] and c.bottom or c.bottom + dy))
    end
    page.need = need
    if dy == 0 then return end
    local items = { page:GetChildren() }
    for _, r in ipairs({ page:GetRegions() }) do items[#items + 1] = r end
    for _, r in ipairs(items) do
        local point, rel, relPoint, x, y = r:GetPoint(1)
        if r:GetNumPoints() == 1 and point == "TOPLEFT" and (rel == nil or rel == page) and relPoint == "TOPLEFT"
            and x and x >= COL[3] then
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", page, "TOPLEFT", x + dx, y + dy)
        end
    end
end

-- the windows beside the options: one at a time; clicking its button again closes it
function ns.toggleDialog(d)
    local show = not d:IsShown()
    for _, o in ipairs({ ns.resDialog, ns.tagDialog, ns.auraDialog, ns.textDialog, ns.iconDialog,
        ns.statusDialog, ns.fsrDialog, ns.happyDialog, ns.drinkDialog, ns.eatDialog }) do o:Hide() end
    d:SetShown(show)
end

local function buildConfig()
    cfg = ns.ui.Window("WolfpackAddonConfig", 680, 700, "Wolfpack", 52)
    cfg.TitleText:SetFontObject(ns.ui.TITLE)
    cfg:HookScript("OnShow", function() ns.configOpen = true; changed() end)
    cfg:HookScript("OnHide", function() ns.configOpen = false; changed() end)

    -- Pages to the right of the sidebar, in a scroll area under the title row. A page keeps the
    -- window's coordinates (its cards start 100 down), so it sits 90 above the area's top.
    local scroller = ns.ui.Scroll(CreateFrame("ScrollFrame", nil, cfg, "UIPanelScrollFrameTemplate"))
    scroller:SetPoint("TOPLEFT", 143, -90)
    scroller:SetPoint("BOTTOMRIGHT", -22, 8)
    local content = CreateFrame("Frame", nil, scroller)
    content:SetSize(515, 1)
    scroller:SetScrollChild(content)
    ns.scroller, ns.content = scroller, content
    -- Four columns of boxes; a box's rows are stacked by g:row(height).
    local COL, TOP = { 16, 226, 436, 646 }, -100
    local ROW, SLIDER, DROP, SWATCH, BUTTON = 24, 46, 50, 26, 28

    -- Header: the profile in use (account-wide, holds every page); a click opens its page
    local inUse = button(cfg, "", 240, 150, -14, function() section, mode = "profile", "regular"; changed() end, true)
    onRefresh(function() inUse:SetText("Profile: |cffffffff" .. tostring(store.chars[charKey]) .. "|r") end)

    -- Profiles page: everything about profiles, each job in its own card
    local profilePage = CreateFrame("Frame", nil, content)
    profilePage:SetPoint("TOPLEFT", content, "TOPLEFT", -9, 90)
    profilePage:SetSize(524, 700)
    local function note(g, text, h)
        local n = label(profilePage, text, "GameFontDisableSmall")
        n:SetPoint("TOPLEFT", g.x, g:row(h))
        n:SetWidth(178)
        n:SetJustifyH("LEFT")
    end
    local function profileMenu(g, pick, others) -- others: leave out the profile in use
        local dd = ns.ui.Dropdown(CreateFrame("DropdownButton", nil, profilePage, "WowStyle1DropdownTemplate"))
        dd:SetPoint("TOPLEFT", g.x, g:row(32))
        dd:SetSize(178, 26)
        dd:SetupMenu(function(_, root)
            for _, name in ipairs(profileNames()) do
                if not (others and name == store.chars[charKey]) then
                    root:CreateRadio(name, function() return not others and name == store.chars[charKey] end,
                        function() pick(name) end)
                end
            end
        end)
        onRefresh(function() dd:GenerateMenu() end)
        return dd
    end
    local function danger(b)
        b:SetNormalFontObject(ns.ui.DANGER)
        b:SetHighlightFontObject(ns.ui.DANGER)
        return b
    end

    -- column 1: which profile this character uses, or a new one; column 2: what changes it
    local use = group(profilePage, COL[1], TOP, 202, "Profile")
    profileMenu(use, useProfile)
    note(use, "Holds every page but Bar Stack. Any character can use it.", 34)
    local at = use:row(32)
    local nameBox = ns.ui.Input(profilePage, 122)
    nameBox:SetPoint("TOPLEFT", use.x, at)
    nameBox:SetMaxLetters(32)
    local hint = label(nameBox, "New profile", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 8, 0)
    nameBox:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
    local function create()
        createProfile(nameBox:GetText())
        nameBox:SetText("")
        nameBox:ClearFocus()
    end
    nameBox:SetScript("OnEnterPressed", create)
    nameBox:SetScript("OnEscapePressed", function() nameBox:ClearFocus() end)
    button(profilePage, "Create", 52, use.x + 126, at, create)
    note(use, "Starts as a copy of this one.", 22)
    use:close()

    local share = group(profilePage, COL[1], use.cursor - 20, 202, "Share or back up")
    at = share:row(BUTTON)
    button(profilePage, "Export", 87, share.x, at, function() openIO("export") end)
    button(profilePage, "Import", 87, share.x + 91, at, function() openIO("import") end)
    note(share, "One text string holds the profile. Keep a copy: the beta can forget addon settings.", 34)
    share:close()

    local edit = group(profilePage, COL[2], TOP, 202, "Change this profile")
    ns.copyFromMenu = profileMenu(edit, function(name)
        StaticPopup_Show("WOLFPACKADDON_COPY", name, store.chars[charKey], name)
    end, true)
    ns.copyFromMenu:SetDefaultText("Copy from...")
    danger(button(profilePage, "Reset to defaults", 178, edit.x, edit:row(BUTTON), function()
        StaticPopup_Show("WOLFPACKADDON_RESET", store.chars[charKey])
    end))
    danger(button(profilePage, "Delete profile", 178, edit.x, edit:row(BUTTON), function()
        local name = store.chars[charKey]
        StaticPopup_Show("WOLFPACKADDON_DELETE", name, nil, name)
    end))
    note(edit, "Each one asks first.", 22)
    edit:close()

    -- Sidebar: what dresses the screen, then your classes
    local y = -64
    local function shelf(title)
        label(cfg, title:upper(), "GameFontDisableSmall"):SetPoint("TOPLEFT", 22, y)
        y = y - 18
    end
    local function entry(key, text, m)
        local b = button(cfg, text, 122, 12, y, function()
            section = key
            ns.platesMode(key == "nameplates", m or "regular")
            changed()
        end, true)
        onRefresh(function() if section == key then b:LockHighlight() else b:UnlockHighlight() end end)
        y = y - 28
        return b
    end

    entry("profile", "Profiles")
    entry("colors", "Colors & borders")
    y = y - 12
    shelf("Interface")
    for _, e in ipairs({ { "combat", "Combat Display" }, { "actionbars", "Action bars" }, { "bags", "Bags" },
        { "nameplates", "Nameplates" }, { "unitframes", "Unit frames" },
        { "buffs", "Buff check" }, { "other", "Other" }, { "barstack", "Bar Stack" } }) do
        entry(e[1], e[2], e[3])
    end
    y = y - 12
    shelf("Classes")
    for _, e in ipairs(ns.CLASS_SECTIONS) do
        local b = entry(e[1], e[2])
        if e[3] == class then -- your own class carries a quiet "you"
            label(b, "you", "GameFontDisableSmall"):SetPoint("RIGHT", -10, 0)
        end
    end

    ns.sidebarBottom = y
    local divider = cfg:CreateTexture(nil, "ARTWORK")
    ns.ui.paint(divider, ns.ui.C.border)
    divider:SetPoint("TOPLEFT", 142, -53)
    divider:SetPoint("BOTTOMLEFT", 142, 1)
    divider:SetWidth(1)

    local barsPage = CreateFrame("Frame", nil, content)
    barsPage:SetPoint("TOPLEFT", content, "TOPLEFT", -9, 90)
    barsPage:SetSize(524, 700)
    local questPage = CreateFrame("Frame", nil, content)
    questPage:SetAllPoints(barsPage)
    local trailPage = CreateFrame("Frame", nil, content)
    trailPage:SetAllPoints(barsPage)
    local otherPage = CreateFrame("Frame", nil, content)
    otherPage:SetAllPoints(barsPage)
    local buffPage = CreateFrame("Frame", nil, content)
    buffPage:SetAllPoints(barsPage)
    local magePage = CreateFrame("Frame", nil, content)
    magePage:SetAllPoints(barsPage)
    local lockPage = CreateFrame("Frame", nil, content)
    lockPage:SetAllPoints(barsPage)
    local roguePage = CreateFrame("Frame", nil, content)
    roguePage:SetAllPoints(barsPage)
    local shamanPage = CreateFrame("Frame", nil, content)
    shamanPage:SetAllPoints(barsPage)
    local colorPage = CreateFrame("Frame", nil, content)
    colorPage:SetAllPoints(barsPage)
    local actionPage = CreateFrame("Frame", nil, content)
    actionPage:SetAllPoints(barsPage)
    -- Bar Stack builds its own editor (BarStack/Config.lua) into this page, under the title
    local bsPage = CreateFrame("Frame", nil, content)
    bsPage:SetAllPoints(barsPage)
    bsPage.need = 100 + ns.ui.BS_H
    ns.pages = { combat = barsPage, nameplates = questPage, buffs = buffPage, mage = magePage,
        warlock = lockPage, rogue = roguePage, shaman = shamanPage,
        other = otherPage, profile = profilePage, colors = colorPage, actionbars = actionPage,
        bags = CreateFrame("Frame", nil, content), unitframes = CreateFrame("Frame", nil, content) }
    ns.pages.bags:SetAllPoints(barsPage)
    ns.pages.unitframes:SetAllPoints(barsPage)

    local title = label(cfg, "Combat Display", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 150, -72)
    local tabs = {}
    for i, t in ipairs({ { "plates", "Nameplate" }, { "quest", "Quest mobs" }, { "target", "Target" } }) do
        tabs[i] = button(cfg, t[2], 110, 150 + (i - 1) * 114, -66, function()
            sub = t[1]
            changed()
        end)
        onRefresh(function() if sub == t[1] then tabs[i]:LockHighlight() else tabs[i]:UnlockHighlight() end end)
    end
    onRefresh(function()
        local np = section == "nameplates"
        -- the tab row stands where the title would: the tabs are the heading on those pages
        title:SetShown(not np)
        title:SetText(section == "other" and "Other"
            or section == "profile" and "Profiles"
            or section == "colors" and "Colors and borders"
            or section == "actionbars" and "Action bars"
            or section == "bags" and "Bags"
            or section == "unitframes" and "Unit frames"
            or section == "buffs" and "Buff check"
            or section == "mage" and "Mage: food and water"
            or section == "warlock" and "Warlock: soul shards"
            or section == "rogue" and "Rogue: weapon poisons"
            or section == "shaman" and "Shaman: weapon imbues"
            or section == "barstack" and "Bar Stack"
            or "Combat Display")
        for _, t in ipairs(tabs) do t:SetShown(np) end
        barsPage:SetShown(section == "combat" or (np and sub == "plates"))
        questPage:SetShown(np and sub == "quest")
        trailPage:SetShown(np and sub == "target")
        otherPage:SetShown(section == "other")
        buffPage:SetShown(section == "buffs")
        magePage:SetShown(section == "mage")
        lockPage:SetShown(section == "warlock")
        roguePage:SetShown(section == "rogue")
        shamanPage:SetShown(section == "shaman")
        bsPage:SetShown(section == "barstack")
        profilePage:SetShown(section == "profile")
        colorPage:SetShown(section == "colors")
        actionPage:SetShown(section == "actionbars")
        ns.pages.bags:SetShown(section == "bags")
        ns.pages.unitframes:SetShown(section == "unitframes")
        local page = section == "barstack" and bsPage or ns.pages[section]
        if np and sub == "quest" then page = questPage end
        if np and sub == "target" then page = trailPage end
        if page and page.need then content:SetHeight(math.max(1, page.need - 90 + 16)) end
        if section ~= ns.shownSection then -- a new page starts at its top
            ns.shownSection = section
            scroller:SetVerticalScroll(0)
        end
        if section == "barstack" and ns.bs then safe(ns.bs.ShowConfig, bsPage) end
    end)

    local tabNote = label(barsPage, "", "GameFontDisableSmall")
    onRefresh(function()
        tabNote:ClearAllPoints()
        if section == "nameplates" then tabNote:SetPoint("LEFT", tabs[#tabs], "RIGHT", 14, 0)
        else tabNote:SetPoint("LEFT", title, "RIGHT", 14, -1) end
        tabNote:SetText(mode == "regular" and "Health, power and combo bars on your screen."
            or "Nameplates on: V key.") -- short: three tabs fill the row
    end)

    -- Bars page, column 1: which bars, and where the group sits
    local bars = group(barsPage, COL[1], TOP, 202, "Bars, top to bottom")
    for i = 1, #db.regular.order do
        local y = bars:row(ROW)
        local sel = button(barsPage, "", 100, bars.x, y, function()
            selected = mode == "plates" and ns.PLATE_BARS[i] or L().order[i]
            changed()
        end, true)
        local up = button(barsPage, "Up", 34, bars.x + 104, y, function() move(i, -1) end)
        local down = button(barsPage, "Down", 40, bars.x + 140, y, function() move(i, 1) end)
        up:SetHeight(22)
        down:SetHeight(22)
        sel:SetHeight(22)
        onRefresh(function()
            -- Plates: one bar, enemy health, on every nameplate
            local one = mode == "plates" -- the nameplate's two bars: health, then its cast bar
            sel:SetShown(not one or ns.PLATE_BARS[i] ~= nil)
            up:SetShown(not one)
            down:SetShown(not one)
            local key = one and (ns.PLATE_BARS[i] or "enemyhealth") or L().order[i]
            sel:SetText(one and ns.PLATE_LABELS[key] or BARS[key].label)
            if key == selected then sel:LockHighlight() else sel:UnlockHighlight() end
        end)
    end
    local gapSlider = slider(barsPage, "Gap between bars", bars.x, bars:row(SLIDER), 0, 30,
        function() return L().gap end, function(v) L().gap = v end)
    onRefresh(function() bars.title:SetText(mode == "plates" and "Nameplate" or "Bars, top to bottom") end)
    bars:close()

    local grp = group(barsPage, COL[1], bars.cursor - 20, 202, "Group position")
    local groupNote = label(barsPage, "", "GameFontDisableSmall")
    groupNote:SetPoint("TOPLEFT", grp.x, grp:row(16))
    onRefresh(function()
        groupNote:SetText(mode == "plates" and "the bar's center, from the nameplate's"
            or (L().grow == "up" and "bottom-center" or "top-center")
            .. (mode == "regular" and ", from the screen center" or ", from under the nameplate"))
    end)
    local grow = button(barsPage, "", 186, grp.x, grp:row(BUTTON), function()
        L().grow = L().grow == "up" and "down" or "up"
        place()
        changed()
    end)
    onRefresh(function()
        grow:SetText("Grows: " .. (L().grow == "up" and "Upwards" or "Downwards"))
        grow:SetShown(mode ~= "plates")
    end)
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
    local function selFrame()
        if mode == "plates" then
            local p = ns.np.previewBar()
            return selected == "targetcast" and p.castBar or p
        end
        return frames[selected]
    end
    local size = group(barsPage, COL[2], TOP, 202, "")
    onRefresh(function()
        local shown = selFrame():IsShown()
        if selected == "swing" then -- the timer draws in a row per weapon, never in its own frame
            for _, row in ipairs(swingFrames[mode]) do shown = shown or row:IsShown() end
        end
        size.title:SetText(BARS[selected].label .. (shown and "" or " |cff888888(hidden)|r"))
    end)
    local showCheck = check(barsPage, "Show", size.x, size:row(ROW), function() return cur().show end,
        function(v) cur().show = v end)
    onRefresh(function()
        showCheck.Text:SetText(mode == "plates" and selected == "enemyhealth" and "Replace Blizzard's nameplates" or "Show")
    end)
    ns.np.wantPreview = function() return cfg:IsShown() and section == "nameplates" end
    local widthSlider = slider(barsPage, "Width", size.x, size:row(SLIDER), 10, 600,
        function() return cur().width end, function(v) cur().width = v end)
    local heightSlider = slider(barsPage, "Height", size.x, size:row(SLIDER), 2, 100,
        function() return cur().height end, function(v) cur().height = v end)
    slider(barsPage, "Extra space above", size.x, size:row(SLIDER), 0, 60,
        function() return cur().padTop end, function(v) cur().padTop = v end)
    slider(barsPage, "Extra space below", size.x, size:row(SLIDER), 0, 60,
        function() return cur().padBottom end, function(v) cur().padBottom = v end)
    slider(barsPage, "Offset X", size.x, size:row(SLIDER), -300, 300, function() return cur().x end, function(v) cur().x = v end)
    slider(barsPage, "Offset Y", size.x, size:row(SLIDER), -300, 300, function() return cur().y end, function(v) cur().y = v end)
    size:close()

    local only = group(barsPage, COL[2], size.cursor - 20, 202, "Just for this bar")
    local beside = check(barsPage, "Beside your health", only.x, only:row(ROW),
        function() return cur().beside end, function(v) cur().beside = v end)
    -- target of target and your pet: in the stack, or hung on enemy health / your health
    local SITS = {
        tothealth = { { "In the stack", "stack" }, { "Below enemy health", "below" }, { "Right of enemy health", "right" } },
        pethealth = { { "In the stack", "stack" }, { "Below your health", "below" }, { "Left of your health", "left" },
            { "Right of your health", "right" } },
        ammo = { { "In the stack", "stack" }, { "Left of the power bar", "left" }, { "Right of the power bar", "right" } },
    }
    local sits = dropdown(barsPage, "Sits", only.x, only:row(0), function() return SITS[selected] or {} end,
        function() return cur().anchor end, function(v) cur().anchor = v end, textPreview)
    ns.sitsMenu = sits
    -- target of target: its name at a click (the rest of it is in the Level and name window)
    -- the experience bar: what it tracks, and when it stays away
    local xpSource = dropdown(barsPage, "Shows", only.x, only:row(0), { { "Experience", "xp" },
        { "Watched faction", "rep" }, { "Honor", "honor" }, { "Experience, then faction at the top", "auto" } },
        function() return cur().source end, function(v) cur().source = v end, textPreview)
    ns.xpMenu = xpSource
    local xpCombat = check(barsPage, "Hide in combat", only.x, only:row(0) - DROP,
        function() return cur().hideInCombat end, function(v) cur().hideInCombat = v end)
    local xpTop = check(barsPage, "Hide at the top level", only.x, only:row(0) - DROP - ROW,
        function() return cur().hideAtMax end, function(v) cur().hideAtMax = v end)
    local totName = check(barsPage, "Show name", only.x, only:row(0) - ROW - 2 * BUTTON,
        function() return cur().tagName end, function(v) cur().tagName = v end)
    local resCheck = check(barsPage, "Show its resource", only.x, only:row(0),
        function() return cur().resource end, function(v) cur().resource = v end)
    local resButton = button(barsPage, "Resource settings", 186, only.x, only:row(0) - ROW, function()
        ns.toggleDialog(ns.resDialog)
    end)
    local tagButton = button(barsPage, "Level and name", 186, only.x, only:row(0) - ROW - BUTTON, function()
        ns.toggleDialog(ns.tagDialog)
    end)
    local iconButton = button(barsPage, "PvP flag", 186, only.x, only:row(0) - ROW - 3 * BUTTON,
        function() ns.toggleDialog(ns.iconDialog) end)
    -- your health: under the incoming heals rows
    local statusButton = button(barsPage, "Status and PvP icons", 186, only.x, only:row(0) - ROW - BUTTON,
        function() ns.toggleDialog(ns.statusDialog) end)
    local auraButton = button(barsPage, "Buffs and debuffs", 186, only.x, only:row(0) - ROW - 2 * BUTTON, function()
        ns.toggleDialog(ns.auraDialog)
    end)
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
    local regenButton = button(barsPage, "Mana regen spinner", 186, only.x, only:row(0) - 2 * ROW - 4,
        function() ns.toggleDialog(ns.fsrDialog) end)
    local drinkButton = button(barsPage, "Drinking text", 186, only.x, only:row(0) - 2 * ROW - 4 - BUTTON,
        function() ns.toggleDialog(ns.drinkDialog) end)
    local eatButton = button(barsPage, "Eating text", 186, only.x, only:row(0) - ROW - 3 * BUTTON,
        function() ns.toggleDialog(ns.eatDialog) end)
    local happyButton = button(barsPage, "Happiness dot", 186, only.x, only:row(0) - DROP - 4,
        function() ns.toggleDialog(ns.happyDialog) end)
    local castIcon = check(barsPage, "Show spell icon", only.x, only:row(ROW),
        function() return cur().icon end, function(v) cur().icon = v end)
    local castSide = button(barsPage, "", 186, only.x, only:row(BUTTON), function()
        cur().iconSide = cur().iconSide == "right" and "left" or "right"
        changed()
    end)
    local onlyNote = label(barsPage, "", "GameFontDisableSmall")
    onlyNote:SetPoint("TOPLEFT", only.x, only:row(16))
    onRefresh(function()
        beside:SetShown(selected == "enemyhealth" and mode == "regular")
        resCheck:SetShown(selected == "enemyhealth")
        local resOn = selected == "enemyhealth" and cur().resource or false
        resButton:SetShown(resOn)
        if not (resOn and (section == "combat" or section == "nameplates")) then ns.resDialog:Hide() end
        local ehOn = selected == "enemyhealth" and (section == "combat" or section == "nameplates")
        tagButton:SetShown(selected == "enemyhealth" or selected == "tothealth")
        auraButton:SetShown(selected == "enemyhealth" or selected == "health")
        iconButton:SetShown(selected == "enemyhealth")
        if not ehOn then ns.iconDialog:Hide() end
        if not ((selected == "enemyhealth" or selected == "tothealth") and (section == "combat" or section == "nameplates")) then
            ns.tagDialog:Hide()
        end
        if not (ns.AURA_BARS[selected] and (section == "combat" or section == "nameplates")) then
            ns.auraDialog:Hide()
        end
        statusButton:SetShown(selected == "health")
        if not (selected == "health" and (section == "combat" or section == "nameplates")) then
            ns.statusDialog:Hide()
        end
        -- beside your health it takes half your health bar's width and all of its height
        local fixed = selected == "enemyhealth" and mode == "regular" and cur().beside or false
        -- hung: below takes the host's width, beside it the host's height
        local hungOn = SITS[selected] and mode == "regular" and cur().anchor or "stack"
        sits:SetShown(SITS[selected] ~= nil and mode == "regular")
        totName:SetShown(selected == "tothealth")
        xpCombat:SetShown(selected == "experience")
        xpSource:SetShown(selected == "experience")
        xpTop:SetShown(selected == "experience" and cur().source == "xp")
        widthSlider:SetShown(not fixed and hungOn ~= "below")
        heightSlider:SetShown(not fixed and (hungOn == "stack" or hungOn == "below"))
        healCheck:SetShown(selected == "health")
        healColor:SetShown(selected == "health")
        costCheck:SetShown(selected == "power")
        costColor:SetShown(selected == "power")
        regenButton:SetShown(selected == "power")
        happyButton:SetShown(selected == "pethealth")
        drinkButton:SetShown(selected == "power")
        eatButton:SetShown(selected == "health")
        if not (selected == "power" and (section == "combat" or section == "nameplates")) then ns.drinkDialog:Hide() end
        if not (selected == "health" and (section == "combat" or section == "nameplates")) then ns.eatDialog:Hide() end
        local here = section == "combat" or section == "nameplates"
        if not (selected == "pethealth" and here) then ns.happyDialog:Hide() end
        if not (selected == "power" and (section == "combat" or section == "nameplates")) then ns.fsrDialog:Hide() end
        for _, w in ipairs(swingChecks) do w:SetShown(selected == "swing") end
        for _, row in ipairs(totemRows) do
            for _, w in ipairs(row) do w:SetShown(selected == "totems") end
        end
        castIcon:SetShown(selected == "castbar" or selected == "targetcast")
        castSide:SetShown((selected == "castbar" or selected == "targetcast")
            and cur().icon or false)
        castSide:SetText("Icon side: " .. (cur().iconSide == "right" and "Right" or "Left"))
        local none = not (selected == "castbar" or selected == "swing" or selected == "power"
            or selected == "health" or selected == "targetcast" or selected == "enemyhealth")
        if selected == "range" then
            onlyNote:SetText("Asks your own spells whether they would reach. The whole bar takes "
                .. "the color of where your target stands, and says so: in melee, in the gap "
                .. "nothing covers, in range, or too far.")
        elseif selected == "enemyhealth" then
            onlyNote:SetText("") -- the resource sliders stand where this note would
        elseif selected == "targetcast" then
            onlyNote:SetText("What your target is casting. With Bar color \"By kind of cast\" it takes "
                .. "the color of the kind, from the Colors page: one you cannot stop, a heal, or "
                .. "anything else. Whether it can "
                .. "be stopped the game tells us outright; whether it heals is matched by name, "
                .. "from the list of heals a mob actually casts.")
        elseif selected == "flight" then
            onlyNote:SetText("Shows only while a griffin has you. Nothing in the game will say how "
                .. "long a route takes, so the first time you fly one it is timed and written "
                .. "down; every ride after that counts down. Routes are remembered for the whole "
                .. "account.")
        else
            onlyNote:SetText(selected ~= "totems" and none and "Nothing extra for this one." or "")
        end
    end)
    only:row(28) -- room for the four totem rows, which sit over the other controls
    only:close()

    -- Column 3: colors and border
    local look = group(barsPage, COL[3], TOP, 202, "Colors")
    ns.textureFromMenu = dropdown(barsPage, "Texture from", look.x, look:row(DROP),
        { { "Shared (Colors page)", "shared" }, { "Its own", "own" } }, function() return cur().textureFrom end,
        function(v) cur().textureFrom = v end, textPreview)
    local ownTex = dropdown(barsPage, "Texture", look.x, look:row(DROP), TEXTURES, function() return cur().texture end,
        function(v) cur().texture = v end, texturePreview)
    onRefresh(function() ownTex:SetShown(cur().textureFrom == "own") end)
    -- which palette color the bar wears (the Colors page sets them), or its own
    local MODES = { health = { "health", "class", "custom" }, power = { "power", "class", "custom" },
        druidmana = { "power", "class", "custom" }, pethealth = { "health", "class", "custom" },
        tothealth = { "class", "reaction", "health", "custom" },
        experience = { "experience", "class", "custom" },
        ammo = { "class", "custom" },
        enemyhealth = { "class", "reaction", "health", "custom" }, castbar = { "cast", "class", "custom" },
        targetcast = { "auto", "cast", "class", "custom" } }
    local MODE_NAMES = { health = "Health color", power = "Power color", class = "Class color",
        experience = "Its kind's color",
        reaction = "Hostile / neutral / friendly", cast = "Casting / channeling", custom = "Custom",
        auto = "By kind of cast" }
    dropdown(barsPage, "Bar color", look.x, look:row(DROP), function()
        local list = {}
        for _, m in ipairs(MODES[selected] or { "class", "custom" }) do
            list[#list + 1] = { (m == "class" and (selected == "enemyhealth" or selected == "tothealth"))
                and "Class color (NPCs: hostile...)"
                or MODE_NAMES[m], m }
        end
        return list
    end, function() return cur().colorMode end, function(v) cur().colorMode = v end, textPreview)
    swatch(barsPage, "Custom color", look.x, look:row(SWATCH), function() return cur().color end, {
        get = function() return cur().colorMode end, set = function(v) cur().colorMode = v end,
        effective = function() return barColors(selFrame(), cur()) end,
    })
    swatch(barsPage, "Background color", look.x, look:row(SWATCH), function() return cur().bgColor end)
    look:close()

    local bord = group(barsPage, COL[3], look.cursor - 20, 202, "Border")
    local RADII = { { "None", 0 }, { "2 px", 2 }, { "4 px", 4 },
        { "8 px", 8 }, { "16 px", 16 }, { "32 px", 32 }, { "Pill (50% of height)", "pill" } }
    ns.borderFromMenu = dropdown(barsPage, "Width and corners", bord.x, bord:row(DROP), { { "Shared (Colors page)", "shared" },
        { "Its own", "own" } }, function() return cur().borderFrom end, function(v) cur().borderFrom = v end, textPreview)
    local thick = slider(barsPage, "Thickness", bord.x, bord:row(SLIDER), 0, 10,
        function() return cur().borderSize end, function(v) cur().borderSize = v end)
    dropdown(barsPage, "Color", bord.x, bord:row(DROP), { { "Same as bar (shaded)", "bar" }, { "Custom", "custom" } },
        function() return cur().borderMode end, function(v) cur().borderMode = v end,
        textPreview)
    swatch(barsPage, "Custom border color", bord.x, bord:row(SWATCH), function() return cur().borderColor end, {
        get = function() return cur().borderMode end, set = function(v) cur().borderMode = v end,
        effective = function() return select(4, barColors(selFrame(), cur())) end,
    })
    local corners = dropdown(barsPage, "Corner radius", bord.x, bord:row(DROP), RADII,
        function() return cur().radius end, function(v) cur().radius = v end, textPreview)
    local edgeTex = dropdown(barsPage, "Border texture", bord.x, bord:row(DROP), TEXTURES,
        function() return cur().borderTexture end, function(v) cur().borderTexture = v end, texturePreview)
    ns.ownBorderTexMenu = edgeTex
    onRefresh(function()
        thick:SetShown(cur().borderFrom == "own")
        corners:SetShown(cur().borderFrom == "own")
        edgeTex:SetShown(cur().borderFrom == "own")
    end)
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
    }
    local sizeY = txt:row(SLIDER)
    textWidgets[3] = slider(barsPage, "Size", txt.x, sizeY, 6, 32, function() return cur().fontSize end,
        function(v) cur().fontSize = v end)
    textWidgets[4] = check(barsPage, "Outline", txt.x, txt:row(ROW), function() return cur().outline end,
        function(v) cur().outline = v end)
    textWidgets[5] = swatch(barsPage, "Text color", txt.x, txt:row(SWATCH), function() return cur().textColor end)
    -- health, power and enemy health: their numbers have a window of their own, sizes and colors too
    local numButton = button(barsPage, "Numbers", 186, txt.x, sizeY - 12, function() ns.toggleDialog(ns.textDialog) end)
    local noText = label(barsPage, "", "GameFontDisableSmall")
    noText:SetPoint("TOPLEFT", txt.x, txt:row(16))
    onRefresh(function()
        local many = ns.TEXT_BARS[selected] and true or false
        for i, w in ipairs(textWidgets) do w:SetShown(selected ~= "combo" and not (many and (i == 3 or i == 5))) end
        numButton:SetShown(many)
        if not (many and (section == "combat" or section == "nameplates")) then ns.textDialog:Hide() end
        noText:SetText(selected == "combo" and "Combo points show no text." or "")
    end)
    txt:close()

    -- Quest mobs page
    -- Nameplates, Target tab: the trail running round your target's plate
    do
        local T = function() return db.plates.trail end
        local g = group(trailPage, COL[1], TOP, 202, "Target trail")
        check(trailPage, "Show on your target's plate", g.x, g:row(ROW), function() return T().show end,
            function(v) T().show = v end)
        for _, r in ipairs({ { "length", "Length", 2, 200, 1 }, { "thickness", "Thickness", 1, 12, 1 },
            { "offset", "Offset (out / in)", -10, 10, 1 } }) do
            slider(trailPage, r[2], g.x, g:row(SLIDER), r[3], r[4], function() return T()[r[1]] end,
                function(v) T()[r[1]] = v end, r[5])
        end
        check(trailPage, "Rounded caps", g.x, g:row(ROW), function() return T().caps end, function(v) T().caps = v end)
        check(trailPage, "Fade the tail", g.x, g:row(ROW), function() return T().fade end, function(v) T().fade = v end)
        g:close()
        local gl = group(trailPage, COL[2], TOP, 202, "Glow")
        check(trailPage, "Glow", gl.x, gl:row(ROW), function() return T().glow end, function(v) T().glow = v end)
        slider(trailPage, "Glow size", gl.x, gl:row(SLIDER), 1, 20, function() return T().glowSize end,
            function(v) T().glowSize = v end)
        slider(trailPage, "Glow strength", gl.x, gl:row(SLIDER), 0, 1, function() return T().glowAlpha end,
            function(v) T().glowAlpha = v end, 0.05)
        local n = label(trailPage, "Runs along the health bar's border (its edge without one), on enemies "
            .. "you target. The glow takes the trail's color. While this page is open it shows on the "
            .. "preview plate.", "GameFontDisableSmall")
        n:SetPoint("TOPLEFT", gl.x, gl:row(72))
        n:SetWidth(182)
        n:SetJustifyH("LEFT")
        gl:close()
        -- what the target is up to sets the color, speed and flashing
        local cards = { g, gl }
        for i, e in ipairs({ { "idle", "Targeted (not in combat)" }, { "combat", "In combat" },
            { "aggro", "In combat, targeting you" } }) do
            local S = function() return T().states[e[1]] end
            local col = i == 1 and COL[1] or COL[2]
            local above = i == 1 and g or (i == 2 and gl or cards[4]) -- aggro under combat
            local c = group(trailPage, col, above.cursor - 20, 202, e[2])
            swatch(trailPage, e[2] .. ": color", c.x, c:row(SWATCH), function() return S().color end)
            slider(trailPage, "Seconds per round", c.x, c:row(SLIDER), 0.3, 10, function() return S().lap end,
                function(v) S().lap = v end, 0.1)
            check(trailPage, "Flash", c.x, c:row(ROW), function() return S().flash end, function(v) S().flash = v end)
            if e[1] == "aggro" then
                slider(trailPage, "Flashes per second", c.x, c:row(SLIDER), 0.5, 10, function() return T().flashRate end,
                    function(v) T().flashRate = v end, 0.5)
            end
            c:close()
            cards[#cards + 1] = c
        end
        trailPage.need = math.max(-cards[3].cursor, -cards[5].cursor) + 30
    end

    local qinfo = group(questPage, COL[1], TOP, 202, "Quest mobs")
    local desc = label(questPage, "Marks enemies you still need for a quest.\n\nSword: you need to kill it.\n"
        .. "Bag: it drops an item you need.\nGray: only groupmates still need it.\n\nEach icon hangs on "
        .. "a part of the nameplate (with Plates off: on the whole plate). One that hangs on a part "
        .. "not shown right now goes to the health bar; one on the other icon, while that is not shown, "
        .. "takes its place. Needs enemy nameplates on (V key).", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", qinfo.x, qinfo:row(220))
    desc:SetWidth(182)
    desc:SetJustifyH("LEFT")
    qinfo:close()

    local QUEST_SPOT_LIST = {}
    for _, k in ipairs(ns.QUEST_SPOT_ORDER) do QUEST_SPOT_LIST[#QUEST_SPOT_LIST + 1] = { ns.QUEST_SPOTS[k][1], k } end
    local RADII = { { "None", 0 }, { "2 px", 2 }, { "4 px", 4 }, { "8 px", 8 }, { "Pill (50% of height)", "pill" } }
    for i, kind in ipairs({ { "kill", "Kill it (sword)", "The bag" }, { "loot", "Drops a quest item (bag)", "The sword" } }) do
        local function q() return db.quest[kind[1]] end
        local g = group(questPage, COL[i + 1], TOP, 202, kind[2])
        check(questPage, "Show", g.x, g:row(ROW), function() return q().show end, function(v) q().show = v end)
        dropdown(questPage, "Icon", g.x, g:row(DROP), QUEST_ICONS[kind[1]], function() return q().icon end,
            function(v) q().icon = v end, iconPreview)
        slider(questPage, "Size", g.x, g:row(SLIDER), 8, 64, function() return q().size end, function(v) q().size = v end)
        local anchors = { unpack(ns.QUEST_ANCHORS) }
        anchors[#anchors + 1] = { kind[3], "other" }
        dropdown(questPage, "Anchor to", g.x, g:row(DROP), anchors, function() return q().anchorTo end,
            function(v) q().anchorTo = v end, textPreview)
        dropdown(questPage, "Sits", g.x, g:row(DROP), QUEST_SPOT_LIST, function() return q().spot end,
            function(v) q().spot = v end, textPreview)
        slider(questPage, "X (left / right)", g.x, g:row(SLIDER), -200, 200, function() return q().x end,
            function(v) q().x = v end)
        slider(questPage, "Y (down / up)", g.x, g:row(SLIDER), -200, 200, function() return q().y end,
            function(v) q().y = v end)
        g:close()
        local n = group(questPage, COL[i + 1], g.cursor - 20, 202, "How many are left")
        check(questPage, "Show the number", n.x, n:row(ROW), function() return q().count end,
            function(v) q().count = v end)
        dropdown(questPage, "Font", n.x, n:row(DROP), FONTS, function() return q().font end,
            function(v) q().font = v end, fontPreview)
        slider(questPage, "Font size", n.x, n:row(SLIDER), 6, 32, function() return q().fontSize end,
            function(v) q().fontSize = v end)
        ns.countSpotMenus = ns.countSpotMenus or {}
        ns.countSpotMenus[i] = dropdown(questPage, "Sits on the icon", n.x, n:row(DROP), QUEST_SPOT_LIST,
            function() return q().countSpot end, function(v) q().countSpot = v end, textPreview)
        slider(questPage, "Number X", n.x, n:row(SLIDER), -50, 50, function() return q().countX end,
            function(v) q().countX = v end)
        slider(questPage, "Number Y", n.x, n:row(SLIDER), -50, 50, function() return q().countY end,
            function(v) q().countY = v end)
        swatch(questPage, "Number color", n.x, n:row(SWATCH), function() return q().textColor end)
        swatch(questPage, "Background", n.x, n:row(SWATCH), function() return q().bg end)
        dropdown(questPage, "Background radius", n.x, n:row(DROP), RADII,
            function() return q().radius end, function(v) q().radius = v end, textPreview)
        slider(questPage, "Padding", n.x, n:row(SLIDER), 0, 12, function() return q().pad end,
            function(v) q().pad = v end)
        n:close()
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
    check(otherPage, "Auto-repair", merch.x, merch:row(ROW),
        function() return db.other.autoRepair end, function(v) db.other.autoRepair = v end)
    merch:close()


    -- Other page, column 2: Blizzard's own frames
    local blizz = group(otherPage, COL[2], TOP, 202, "Blizzard frames")
    check(otherPage, "Hide player frame", blizz.x, blizz:row(ROW),
        function() return db.regular.hidePlayerFrame end, function(v) db.regular.hidePlayerFrame = v end)
    check(otherPage, "Hide target frame", blizz.x, blizz:row(ROW),
        function() return db.regular.hideTargetFrame end, function(v) db.regular.hideTargetFrame = v end)
    check(otherPage, "Hide experience bar", blizz.x, blizz:row(ROW),
        function() return db.regular.hideXPBar end, function(v) db.regular.hideXPBar = v end)
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
    blizz:row(6)
    check(otherPage, "Party/raid frame hover highlight", blizz.x, blizz:row(ROW),
        function() return db.other.raidHover.show end, function(v) db.other.raidHover.show = v end)
    swatch(otherPage, "Highlight color", blizz.x, blizz:row(SWATCH), function() return db.other.raidHover.color end)
    slider(otherPage, "Highlight opacity (%)", blizz.x, blizz:row(SLIDER), 0, 100,
        function() return math.floor(db.other.raidHover.color[4] * 100 + 0.5) end,
        function(v) db.other.raidHover.color[4] = v / 100 end)
    blizz:close()

    -- Other page, column 4: what the mouse does over the bars, and the regen spinner
    local mouse = group(otherPage, COL[4], TOP, 202, "Clicking the bars")
    check(otherPage, "Left-click: target yourself", mouse.x, mouse:row(ROW),
        function() return db.regular.playerTarget end, function(v) db.regular.playerTarget = v end)
    check(otherPage, "Right-click: player menu", mouse.x, mouse:row(ROW),
        function() return db.regular.playerMenu end, function(v) db.regular.playerMenu = v end)
    check(otherPage, "Enemy health: right-click menu", mouse.x, mouse:row(ROW),
        function() return db.regular.targetMenu end, function(v) db.regular.targetMenu = v end)
    check(otherPage, "Pet: click target, right menu", mouse.x, mouse:row(ROW),
        function() return db.regular.petMenu end, function(v) db.regular.petMenu = v end)
    check(otherPage, "Target of target: same", mouse.x, mouse:row(ROW),
        function() return db.regular.totMenu end, function(v) db.regular.totMenu = v end)
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
    local hnote = label(otherPage, "They fade in under the cursor, stay clickable and show while "
        .. "Edit Mode is open.\n\nFading one of Blizzard's own bars means touching it, and a "
        .. "touched bar can start complaining that its cooldowns cannot be drawn. If you are "
        .. "seeing that, turn the bars here off and reload.", "GameFontDisableSmall")
    hnote:SetPoint("TOPLEFT", hover.x, hover:row(74))
    hnote:SetWidth(182)
    hnote:SetJustifyH("LEFT")
    hover:close()

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
    -- Mage page: the conjured food and water counter
    ----------------------------------------------------------------------------------
    local M = function() return db.mage end
    local mset = group(magePage, COL[1], TOP, 202, "Food and water")
    check(magePage, "Show it", mset.x, mset:row(ROW), function() return M().show end,
        function(v) M().show = v end)
    local mlk = button(magePage, "", 186, mset.x, mset:row(BUTTON), function()
        M().locked = not M().locked
        changed()
    end)
    onRefresh(function() mlk:SetText(M().locked and "Locked (click to unlock)" or "Unlocked - drag it") end)
    slider(magePage, "X (left / right)", mset.x, mset:row(SLIDER), -1200, 1200,
        function() return M().x end, function(v) M().x = v end)
    slider(magePage, "Y (down / up)", mset.x, mset:row(SLIDER), -800, 800,
        function() return M().y end, function(v) M().y = v end)
    local mNote = label(magePage, "Counts the conjured food and water in your bags and shows only "
        .. "the best rank you carry. With none of it, the icon is the rank your level conjures.",
        "GameFontDisableSmall")
    mNote:SetPoint("TOPLEFT", mset.x, mset:row(46))
    mNote:SetWidth(182)
    mNote:SetJustifyH("LEFT")
    mset:close()

    local mlook = group(magePage, COL[2], TOP, 202, "Icons")
    slider(magePage, "Icon size", mlook.x, mlook:row(SLIDER), 12, 80, function() return M().size end,
        function(v) M().size = v end)
    slider(magePage, "Gap", mlook.x, mlook:row(SLIDER), 0, 30, function() return M().gap end,
        function(v) M().gap = v end)
    dropdown(magePage, "Side by side or stacked", mlook.x, mlook:row(DROP),
        { { "Side by side", "right" }, { "Stacked", "down" } },
        function() return M().grow end, function(v) M().grow = v end, textPreview)
    dropdown(magePage, "Which comes first", mlook.x, mlook:row(DROP),
        { { "Food, then water", false }, { "Water, then food", true } },
        function() return M().waterFirst and true or false end,
        function(v) M().waterFirst = v end, textPreview)
    dropdown(magePage, "Corner radius", mlook.x, mlook:row(DROP), { { "None (square)", 0 },
        { "Slightly rounded", 12 }, { "Rounded", 25 }, { "Circle", 50 } },
        function() return ns.ICON_MASKS[M().radius] and M().radius or 0 end,
        function(v) M().radius = v end, textPreview)
    dropdown(magePage, "Count sits", mlook.x, mlook:row(DROP), { { "In the corner", "corner" },
        { "In the middle", "center" } }, function() return M().countAt end,
        function(v) M().countAt = v end, textPreview)
    check(magePage, "Show the count", mlook.x, mlook:row(ROW), function() return M().showCount end,
        function(v) M().showCount = v end)
    mlook:close()

    local mtext = group(magePage, COL[3], TOP, 202, "The count")
    dropdown(magePage, "Font", mtext.x, mtext:row(DROP), FONTS, function() return M().font end,
        function(v) M().font = v end, fontPreview)
    slider(magePage, "Font size", mtext.x, mtext:row(SLIDER), 6, 30, function() return M().fontSize end,
        function(v) M().fontSize = v end)
    check(magePage, "Outline", mtext.x, mtext:row(ROW), function() return M().outline end,
        function(v) M().outline = v end)
    swatch(magePage, "Color", mtext.x, mtext:row(SWATCH), function() return M().color end)
    swatch(magePage, "Color when low", mtext.x, mtext:row(SWATCH), function() return M().lowColor end)
    slider(magePage, "Low is under", mtext.x, mtext:row(SLIDER), 1, 40, function() return M().low end,
        function(v) M().low = v end)
    mtext:close()

    ----------------------------------------------------------------------------------
    -- Warlock page: the soul shards in your bags
    ----------------------------------------------------------------------------------
    local W = function() return db.warlock end
    local wset = group(lockPage, COL[1], TOP, 202, "Soul shards")
    check(lockPage, "Show it", wset.x, wset:row(ROW), function() return W().show end,
        function(v) W().show = v end)
    local wlk = button(lockPage, "", 186, wset.x, wset:row(BUTTON), function()
        W().locked = not W().locked
        changed()
    end)
    onRefresh(function() wlk:SetText(W().locked and "Locked (click to unlock)" or "Unlocked - drag it") end)
    slider(lockPage, "X (left / right)", wset.x, wset:row(SLIDER), -1200, 1200,
        function() return W().x end, function(v) W().x = v end)
    slider(lockPage, "Y (down / up)", wset.x, wset:row(SLIDER), -800, 800,
        function() return W().y end, function(v) W().y = v end)
    local wNote = label(lockPage, "Counts the soul shards in your bags. Warlocks only.",
        "GameFontDisableSmall")
    wNote:SetPoint("TOPLEFT", wset.x, wset:row(30))
    wNote:SetWidth(182)
    wNote:SetJustifyH("LEFT")
    wset:close()

    local wlook = group(lockPage, COL[2], TOP, 202, "Icon")
    slider(lockPage, "Icon size", wlook.x, wlook:row(SLIDER), 12, 80, function() return W().size end,
        function(v) W().size = v end)
    dropdown(lockPage, "Corner radius", wlook.x, wlook:row(DROP), { { "None (square)", 0 },
        { "Slightly rounded", 12 }, { "Rounded", 25 }, { "Circle", 50 } },
        function() return ns.ICON_MASKS[W().radius] and W().radius or 0 end,
        function(v) W().radius = v end, textPreview)
    dropdown(lockPage, "Count sits", wlook.x, wlook:row(DROP), { { "In the corner", "corner" },
        { "In the middle", "center" } }, function() return W().countAt end,
        function(v) W().countAt = v end, textPreview)
    check(lockPage, "Show the count", wlook.x, wlook:row(ROW), function() return W().showCount end,
        function(v) W().showCount = v end)
    slider(lockPage, "Gap", wlook.x, wlook:row(SLIDER), 0, 30, function() return W().gap end,
        function(v) W().gap = v end)
    dropdown(lockPage, "Side by side or stacked", wlook.x, wlook:row(DROP),
        { { "Side by side", "right" }, { "Stacked", "down" } },
        function() return W().grow end, function(v) W().grow = v end, textPreview)
    wlook:close()

    local warm = group(lockPage, COL[4], TOP, 202, "Demon armor")
    check(lockPage, "Show it", warm.x, warm:row(ROW), function() return W().armor end,
        function(v) W().armor = v end)
    check(lockPage, "Flash when it is gone", warm.x, warm:row(ROW), function() return W().flash end,
        function(v) W().flash = v end)
    check(lockPage, "Hide it while you are armored", warm.x, warm:row(ROW),
        function() return W().armorOnlyMissing end, function(v) W().armorOnlyMissing = v end)
    slider(lockPage, "Icon size", warm.x, warm:row(SLIDER), 12, 80,
        function() return W().armorSize or W().size end, function(v) W().armorSize = v end)
    slider(lockPage, "Font size", warm.x, warm:row(SLIDER), 6, 30,
        function() return W().armorFontSize or W().fontSize end,
        function(v) W().armorFontSize = v end)
    local warmNote = label(lockPage, "The best armor you know -- Demon Armor, or Demon Skin until "
        .. "you have it, and either one counts while it is on you. Missing, the icon flashes; "
        .. "armored, it is out of the way. This works in a fight too: when the aura calls go "
        .. "quiet the icon is looked for on Blizzard's own buff bar instead.",
        "GameFontDisableSmall")
    warmNote:SetPoint("TOPLEFT", warm.x, warm:row(56))
    warmNote:SetWidth(182)
    warmNote:SetJustifyH("LEFT")
    warm:close()

    local wtext = group(lockPage, COL[3], TOP, 202, "The count")
    dropdown(lockPage, "Font", wtext.x, wtext:row(DROP), FONTS, function() return W().font end,
        function(v) W().font = v end, fontPreview)
    slider(lockPage, "Font size", wtext.x, wtext:row(SLIDER), 6, 30, function() return W().fontSize end,
        function(v) W().fontSize = v end)
    check(lockPage, "Outline", wtext.x, wtext:row(ROW), function() return W().outline end,
        function(v) W().outline = v end)
    swatch(lockPage, "Shard color", wtext.x, wtext:row(SWATCH), function() return W().color end)
    swatch(lockPage, "Shard color when low", wtext.x, wtext:row(SWATCH), function() return W().lowColor end)
    slider(lockPage, "Low is under", wtext.x, wtext:row(SLIDER), 1, 32, function() return W().low end,
        function(v) W().low = v end)
    wtext:close()

    ----------------------------------------------------------------------------------
    -- Rogue and Shaman pages: what is on each weapon. The same settings, twice over.
    ----------------------------------------------------------------------------------
    for _, w in ipairs({ { "rogue", roguePage, "poison" }, { "shaman", shamanPage, "imbue" } }) do
        local key, page, what = w[1], w[2], w[3]
        local W = function() return db[key] end
        local wg = group(page, COL[1], TOP, 202, "Weapon " .. what)
        check(page, "Show it", wg.x, wg:row(ROW), function() return W().show end,
            function(v) W().show = v end)
        check(page, "Flash a bare weapon", wg.x, wg:row(ROW), function() return W().flash end,
            function(v) W().flash = v end)
        local wgl = button(page, "", 186, wg.x, wg:row(BUTTON), function()
            W().locked = not W().locked
            changed()
        end)
        onRefresh(function()
            wgl:SetText(W().locked and "Locked (click to unlock)" or "Unlocked - drag it")
        end)
        slider(page, "X (left / right)", wg.x, wg:row(SLIDER), -1200, 1200,
            function() return W().x end, function(v) W().x = v end)
        slider(page, "Y (down / up)", wg.x, wg:row(SLIDER), -800, 800,
            function() return W().y end, function(v) W().y = v end)
        slider(page, "Warn under (minutes)", wg.x, wg:row(SLIDER), 1, 60,
            function() return W().warn end, function(v) W().warn = v end)
        local wgNote = label(page, "One icon per hand, and only when it needs you: nothing on "
            .. "that weapon, or -- out of combat, where you can do something about it -- less "
            .. "than the minutes above left, with the number on the icon.", "GameFontDisableSmall")
        wgNote:SetPoint("TOPLEFT", wg.x, wg:row(56))
        wgNote:SetWidth(182)
        wgNote:SetJustifyH("LEFT")
        wg:close()

        local wgi = group(page, COL[2], TOP, 202, "Icons")
        slider(page, "Icon size", wgi.x, wgi:row(SLIDER), 12, 80, function() return W().size end,
            function(v) W().size = v end)
        slider(page, "Gap", wgi.x, wgi:row(SLIDER), 0, 30, function() return W().gap end,
            function(v) W().gap = v end)
        dropdown(page, "Corner radius", wgi.x, wgi:row(DROP), { { "None (square)", 0 },
            { "Slightly rounded", 12 }, { "Rounded", 25 }, { "Circle", 50 } },
            function() return ns.ICON_MASKS[W().radius] and W().radius or 0 end,
            function(v) W().radius = v end, textPreview)
        dropdown(page, "Side by side or stacked", wgi.x, wgi:row(DROP),
            { { "Side by side", "right" }, { "Stacked", "down" } },
            function() return W().grow end, function(v) W().grow = v end, textPreview)
        dropdown(page, "Minutes sit", wgi.x, wgi:row(DROP), { { "In the corner", "corner" },
            { "In the middle", "center" } }, function() return W().countAt end,
            function(v) W().countAt = v end, textPreview)
        wgi:close()

        local wgt = group(page, COL[3], TOP, 202, "The minutes")
        dropdown(page, "Font", wgt.x, wgt:row(DROP), FONTS, function() return W().font end,
            function(v) W().font = v end, fontPreview)
        slider(page, "Font size", wgt.x, wgt:row(SLIDER), 6, 30, function() return W().fontSize end,
            function(v) W().fontSize = v end)
        check(page, "Outline", wgt.x, wgt:row(ROW), function() return W().outline end,
            function(v) W().outline = v end)
        swatch(page, "Color", wgt.x, wgt:row(SWATCH), function() return W().color end)
        swatch(page, "Running out", wgt.x, wgt:row(SWATCH), function() return W().warnColor end)
        wgt:close()
    end

    ----------------------------------------------------------------------------------
    -- Buffs page: the out-of-combat check of who is missing what
    ----------------------------------------------------------------------------------
    local B = function() return db.buffs end
    local bset = group(buffPage, COL[1], TOP, 202, "Buff check")
    check(buffPage, "Show it", bset.x, bset:row(ROW), function() return B().show end,
        function(v) B().show = v end)
    check(buffPage, "Only what is missing", bset.x, bset:row(ROW), function() return B().onlyMissing end,
        function(v) B().onlyMissing = v end)
    local blk = button(buffPage, "", 186, bset.x, bset:row(BUTTON), function()
        B().locked = not B().locked
        changed()
    end)
    onRefresh(function() blk:SetText(B().locked and "Locked (click to unlock)" or "Unlocked - drag it") end)
    slider(buffPage, "X (left / right)", bset.x, bset:row(SLIDER), -1200, 1200,
        function() return B().x end, function(v) B().x = v end)
    slider(buffPage, "Y (down / up)", bset.x, bset:row(SLIDER), -800, 800,
        function() return B().y end, function(v) B().y = v end)
    local bsetNote = label(buffPage, "Checks everyone in the group against the buffs somebody here "
        .. "can give, and shows who is missing one. Out of combat only: in a fight the game "
        .. "answers nothing, so any list would be a guess.", "GameFontDisableSmall")
    bsetNote:SetPoint("TOPLEFT", bset.x, bset:row(52))
    bsetNote:SetWidth(182)
    bsetNote:SetJustifyH("LEFT")
    bset:close()

    local blook = group(buffPage, COL[2], TOP, 202, "Look")
    slider(buffPage, "Icon size", blook.x, blook:row(SLIDER), 8, 40, function() return B().size end,
        function(v) B().size = v end)
    dropdown(buffPage, "Font", blook.x, blook:row(DROP), FONTS, function() return B().font end,
        function(v) B().font = v end, fontPreview)
    slider(buffPage, "Font size", blook.x, blook:row(SLIDER), 6, 24, function() return B().fontSize end,
        function(v) B().fontSize = v end)
    check(buffPage, "Outline", blook.x, blook:row(ROW), function() return B().outline end,
        function(v) B().outline = v end)
    swatch(buffPage, "Missing color", blook.x, blook:row(SWATCH), function() return B().color end)
    blook:close()

    local bwhat = group(buffPage, COL[3], TOP, 202, "What to check")
    for _, chk in ipairs(ns.BUFF_CHECKS) do
        check(buffPage, chk.label .. " (" .. chk.from:sub(1, 1) .. chk.from:sub(2):lower() .. ")",
            bwhat.x, bwhat:row(ROW), function() return not B().skip[chk.key] end,
            function(v) B().skip[chk.key] = (not v) or nil end)
    end
    check(buffPage, "Weapon (rogue, shaman)", bwhat.x, bwhat:row(ROW),
        function() return not B().skip.weapon end,
        function(v) B().skip.weapon = (not v) or nil end)
    local bwhatNote = label(buffPage, "A row shows only when somebody in the group can actually "
        .. "give that buff. A paladin keeps one blessing per person, so any one of them counts.",
        "GameFontDisableSmall")
    bwhatNote:SetPoint("TOPLEFT", bwhat.x, bwhat:row(46))
    bwhatNote:SetWidth(182)
    bwhatNote:SetJustifyH("LEFT")
    bwhat:close()


    -- Four columns of cards are built; the window holds two. Columns 3 and 4 move under 1 and 2:
    -- anything placed on the page itself right of column 2 shifts left and down, and whatever
    -- hangs off those moves with it.
    ----------------------------------------------------------------------------------
    -- Action bars page: the bar picked here, its layout, its look; keybinds; Blizzard's bars
    ----------------------------------------------------------------------------------
    local abSel = 1
    -- no bar picked (all deleted): the widgets read and write a scratch copy, never the defaults
    local scratch = merge({}, ns.AB_BAR)
    local AB = function()
        if abSel == "stance" or abSel == "pet" then return db.actionbars[abSel] end
        return db.actionbars.bars[abSel] or scratch
    end
    ns.abIsSpecial = function() return abSel == "stance" or abSel == "pet" end
    local special = ns.abIsSpecial
    local abc = group(actionPage, COL[1], TOP, 202, "Bars")
    ns.abMenu = dropdown(actionPage, "Bar", abc.x, abc:row(DROP), function()
        local list = {}
        for i, b in ipairs(db.actionbars.bars) do
            list[i] = { ("Bar %d (slots %d-%d)"):format(i, b.first, b.first + math.max(ns.abCount(i), 1) - 1), i }
        end
        list[#list + 1] = { "Stance bar", "stance" }
        list[#list + 1] = { "Pet bar", "pet" }
        return list
    end, function() return abSel end, function(v) abSel = v end, textPreview)
    local abRow = abc:row(BUTTON)
    button(actionPage, "New bar", 87, abc.x, abRow, function()
        local i = ns.abNew()
        if i then abSel = i end
        changed()
    end)
    button(actionPage, "Delete bar", 87, abc.x + 91, abRow, function()
        if db.actionbars.bars[abSel] then StaticPopup_Show("WOLFPACKADDON_DELBAR", abSel, nil, abSel) end
    end)
    local abUsed = label(actionPage, "", "GameFontDisableSmall")
    abUsed:SetPoint("TOPLEFT", abc.x, abc:row(44))
    abUsed:SetWidth(178)
    abUsed:SetJustifyH("LEFT")
    onRefresh(function()
        if not special() and not db.actionbars.bars[abSel] then abSel = math.max(1, #db.actionbars.bars) end
        local room = not special() and db.actionbars.bars[abSel] and ns.abRoom(abSel)
        abUsed:SetText(("%d of %d action slots in use.%s"):format(ns.abUsed(), ns.AB_POOL,
            room and AB().rows * AB().cols > room and ("\nThis bar has room for " .. room .. " here.") or ""))
    end)
    abc:row(6)
    button(actionPage, "Quick keybind mode", 178, abc.x, abc:row(BUTTON), function()
        cfg:Hide()
        ns.abBindMode(true)
    end)
    check(actionPage, "Hide Blizzard's action bars", abc.x, abc:row(ROW),
        function() return db.regular.hideActionBars end, function(v) db.regular.hideActionBars = v end)
    check(actionPage, "Hide Blizzard's stance bar", abc.x, abc:row(ROW),
        function() return db.regular.hideStanceBar end, function(v) db.regular.hideStanceBar = v end)
    check(actionPage, "Hide Blizzard's pet bar", abc.x, abc:row(ROW),
        function() return db.regular.hidePetBar end, function(v) db.regular.hidePetBar = v end)
    local abNote = label(actionPage, "Bars, keys and hiding change out of combat only: the game allows "
        .. "nothing else. Drag spells onto the buttons as usual.", "GameFontDisableSmall")
    abNote:SetPoint("TOPLEFT", abc.x, abc:row(44))
    abNote:SetWidth(178)
    abNote:SetJustifyH("LEFT")
    abc:close()

    local abl = group(actionPage, COL[1], abc.cursor - 20, 202, "Layout")
    -- stance and pet bars: on or off, and what they hang on
    local w = {} -- this page's widgets, in one local: the builder is at Lua's 200-local ceiling
    w.show = check(actionPage, "Show this bar", abl.x, abl:row(0), function() return AB().show end,
        function(v) AB().show = v end)
    w.to = dropdown(actionPage, "Anchor to", abl.x, abl:row(0) - ROW, function()
        local list = { { "The screen", "screen" } }
        for i in ipairs(db.actionbars.bars) do list[#list + 1] = { "Bar " .. i, "bar:" .. i } end
        list[#list + 1] = abSel == "pet" and { "Stance bar", "stance" } or { "Pet bar", "pet" }
        return list
    end, function() return AB().anchorTo end, function(v) AB().anchorTo = v end, textPreview)
    w.side = dropdown(actionPage, "On its", abl.x, abl:row(0) - ROW - DROP, { { "Top", "above" },
        { "Bottom", "below" }, { "Left", "left" }, { "Right", "right" } }, function() return AB().side end,
        function(v) AB().side = v end, textPreview)
    w.align = dropdown(actionPage, "Aligned", abl.x, abl:row(0) - ROW - 2 * DROP, function()
        local across = AB().side == "left" or AB().side == "right"
        return { { across and "Top" or "Left", "start" }, { "Centered", "center" }, { across and "Bottom" or "Right", "end" } }
    end, function() return AB().align end, function(v) AB().align = v end, textPreview)
    ns.abSpecialMenus = { w.to, w.side, w.align }
    onRefresh(function()
        w.show:SetShown(special())
        w.to:SetShown(special())
        w.side:SetShown(special() and AB().anchorTo ~= "screen")
        w.align:SetShown(special() and AB().anchorTo ~= "screen")
    end)
    abl:row(ROW + 3 * DROP) -- room for the stance / pet controls (empty for your own bars)
    for _, r in ipairs({ { "rows", "Rows", 1, 12 }, { "cols", "Columns", 1, 24 }, { "size", "Button size", 16, 64 },
        { "gap", "Gap", 0, 20 } }) do
        slider(actionPage, r[2], abl.x, abl:row(SLIDER), r[3], r[4], function() return AB()[r[1]] end,
            function(v) AB()[r[1]] = v end)
    end
    dropdown(actionPage, "Grows", abl.x, abl:row(DROP), { { "Right, then down", "rightdown" },
        { "Right, then up", "rightup" }, { "Left, then down", "leftdown" }, { "Left, then up", "leftup" } },
        function() return AB().grow end, function(v) AB().grow = v end, textPreview)
    w.point = dropdown(actionPage, "Anchored to the screen's", abl.x, abl:row(DROP), { { "Center", "CENTER" },
        { "Top (centered)", "TOP" }, { "Bottom (centered)", "BOTTOM" }, { "Left (centered)", "LEFT" },
        { "Right (centered)", "RIGHT" }, { "Top left", "TOPLEFT" }, { "Top right", "TOPRIGHT" },
        { "Bottom left", "BOTTOMLEFT" }, { "Bottom right", "BOTTOMRIGHT" } },
        function() return AB().point end, function(v) AB().point = v end, textPreview)
    onRefresh(function() w.point:SetShown(not special() or AB().anchorTo == "screen") end)
    slider(actionPage, "X", abl.x, abl:row(SLIDER), -1500, 1500, function() return AB().x end, function(v) AB().x = v end)
    slider(actionPage, "Y", abl.x, abl:row(SLIDER), -1000, 1000, function() return AB().y end, function(v) AB().y = v end)
    abl:close()

    local abk = group(actionPage, COL[2], TOP, 202, "Look")
    dropdown(actionPage, "Corner radius", abk.x, abk:row(DROP), { { "None (square)", 0 }, { "Slightly rounded", 12 },
        { "Rounded", 25 }, { "Circle", 50 } }, function() return ns.ICON_MASKS[AB().radius] and AB().radius or 0 end,
        function(v) AB().radius = v end, textPreview)
    slider(actionPage, "Zoom (% cut from each side)", abk.x, abk:row(SLIDER), 0, 30, function() return AB().zoom end,
        function(v) AB().zoom = v end)
    slider(actionPage, "Border width", abk.x, abk:row(SLIDER), 0, 6, function() return AB().borderSize end,
        function(v) AB().borderSize = v end)
    swatch(actionPage, "Action border color", abk.x, abk:row(SWATCH), function() return AB().borderColor end)
    check(actionPage, "Show slot background", abk.x, abk:row(ROW), function() return AB().slotBg ~= false end,
        function(v) AB().slotBg = v end)
    abk:close()

    local abt = group(actionPage, COL[2], abk.cursor - 20, 202, "Text")
    dropdown(actionPage, "Keybind font", abt.x, abt:row(DROP), FONTS, function() return AB().keyFont end,
        function(v) AB().keyFont = v end, fontPreview)
    slider(actionPage, "Keybind size", abt.x, abt:row(SLIDER), 6, 24, function() return AB().keySize end,
        function(v) AB().keySize = v end)
    check(actionPage, "Hide empty buttons", abt.x, abt:row(ROW), function() return AB().hideEmpty end,
        function(v) AB().hideEmpty = v end)
    check(actionPage, "Show only on mouseover", abt.x, abt:row(ROW), function() return AB().mouseover end,
        function(v) AB().mouseover = v end)
    check(actionPage, "Show macro names", abt.x, abt:row(ROW), function() return AB().macroText end,
        function(v) AB().macroText = v end)
    dropdown(actionPage, "Macro name font", abt.x, abt:row(DROP), FONTS, function() return AB().macroFont end,
        function(v) AB().macroFont = v end, fontPreview)
    slider(actionPage, "Macro name size", abt.x, abt:row(SLIDER), 6, 24, function() return AB().macroSize end,
        function(v) AB().macroSize = v end)
    abt:close()

    ----------------------------------------------------------------------------------
    -- Bags page: our bag window, in the action bars' look
    ----------------------------------------------------------------------------------
    do
        local pg, G = ns.pages.bags, function() return db.bags end
        local c1 = group(pg, COL[1], TOP, 202, "Bags")
        check(pg, "Replace Blizzard's bags", c1.x, c1:row(ROW), function() return G().show end,
            function(v) G().show = v end)
        local n = label(pg, "Opens and closes like Blizzard's bags (B, a vendor). Quest items always group apart "
            .. "under the bags; ammo, soul and profession bags get a group each. Drag the window to move it. "
            .. "The strip on its left holds custom bags: drop an item on one to group it there.",
            "GameFontDisableSmall")
        n:SetPoint("TOPLEFT", c1.x, c1:row(96))
        n:SetWidth(178)
        n:SetJustifyH("LEFT")
        check(pg, "Keep sorted", c1.x, c1:row(ROW), function() return G().sort end, function(v) G().sort = v end)
        check(pg, "Quality borders", c1.x, c1:row(ROW), function() return G().quality end,
            function(v) G().quality = v end)
        check(pg, "Mark junk (gray items)", c1.x, c1:row(ROW), function() return G().junk end,
            function(v) G().junk = v end)
        check(pg, "Custom bags sidebar", c1.x, c1:row(ROW), function() return G().side end,
            function(v) G().side = v end)
        if KeyRingButton then -- only clients with a keyring
            check(pg, "Keyring above the bag bar", c1.x, c1:row(ROW), function() return G().keyring end,
                function(v) G().keyring = v end)
        end
        local sortNow = button(pg, "Sort the bags now", 178, c1.x, c1:row(BUTTON), function()
            pcall(ns.bags.api("SortBags"))
        end)
        onRefresh(function() sortNow:SetShown(ns.bags.api("SortBags") ~= nil) end)
        c1:close()

        local c2 = group(pg, COL[1], c1.cursor - 20, 202, "Layout")
        for _, r in ipairs({ { "cols", "Columns", 4, 24 }, { "size", "Slot size", 20, 56 }, { "gap", "Gap", 0, 12 },
            { "sectionGap", "Space between groups", 0, 40 }, { "x", "X (from the right edge)", -1500, 0 },
            { "y", "Y (from the bottom)", 0, 1000 } }) do
            slider(pg, r[2], c2.x, c2:row(SLIDER), r[3], r[4], function() return G()[r[1]] end,
                function(v) G()[r[1]] = v end)
        end
        c2:close()

        local c3 = group(pg, COL[2], TOP, 202, "Look")
        dropdown(pg, "Corner radius", c3.x, c3:row(DROP), { { "None (square)", 0 }, { "Slightly rounded", 12 },
            { "Rounded", 25 }, { "Circle", 50 } }, function() return ns.ICON_MASKS[G().radius] and G().radius or 0 end,
            function(v) G().radius = v end, textPreview)
        slider(pg, "Zoom (% cut from each side)", c3.x, c3:row(SLIDER), 0, 30, function() return G().zoom end,
            function(v) G().zoom = v end)
        slider(pg, "Border width", c3.x, c3:row(SLIDER), 0, 6, function() return G().borderSize end,
            function(v) G().borderSize = v end)
        swatch(pg, "Border color", c3.x, c3:row(SWATCH), function() return G().borderColor end)
        swatch(pg, "Background", c3.x, c3:row(SWATCH), function() return G().bg end)
        dropdown(pg, "Count font", c3.x, c3:row(DROP), FONTS, function() return G().font end,
            function(v) G().font = v end, fontPreview)
        slider(pg, "Count size", c3.x, c3:row(SLIDER), 6, 20, function() return G().countSize end,
            function(v) G().countSize = v end)
        c3:close()
        -- the window stays open while this page is, to see what the settings do
        ns.bags.wantPreview = function() return cfg:IsShown() and section == "bags" end
    end

    ----------------------------------------------------------------------------------
    -- Unit frames page: the block, the frames' look, role order, buffs and debuffs
    ----------------------------------------------------------------------------------
    do
        local pg, U = ns.pages.unitframes, function() return db.unitframes end
        local HB = function() return db.unitframes.bars.tothealth end
        local function note(g, text, h)
            local n = label(pg, text, "GameFontDisableSmall")
            n:SetPoint("TOPLEFT", g.x, g:row(h))
            n:SetWidth(178)
            n:SetJustifyH("LEFT")
        end
        local function sliders(g, get, list)
            for _, r in ipairs(list) do
                slider(pg, r[2], g.x, g:row(SLIDER), r[3], r[4], function() return get()[r[1]] end,
                    function(v) get()[r[1]] = v end, r[5])
            end
        end
        local c1 = group(pg, COL[1], TOP, 202, "Unit frames")
        check(pg, "Show", c1.x, c1:row(ROW), function() return U().show end, function(v) U().show = v end)
        check(pg, "Hide Blizzard's party and raid", c1.x, c1:row(ROW), function() return U().replace end,
            function(v) U().replace = v end)
        dropdown(pg, "Fixed side", c1.x, c1:row(DROP), { { "Width: grows up or down", "width" },
            { "Height: grows left or right", "height" } }, function() return U().fixed end, function(v)
            U().fixed = v
            U().grow = v == "width" and "down" or "right"
        end, textPreview)
        dropdown(pg, "Grows", c1.x, c1:row(DROP), function()
            return U().fixed == "width" and { { "Down", "down" }, { "Up", "up" } } or { { "Right", "right" }, { "Left", "left" } }
        end, function() return U().grow end, function(v) U().grow = v end, textPreview)
        local sizeS = slider(pg, "Fixed width (px)", c1.x, c1:row(SLIDER), 40, 1600, function() return U().size end,
            function(v) U().size = v end)
        local perS = slider(pg, "Frames per row", c1.x, c1:row(SLIDER), 1, 40, function() return U().per end,
            function(v) U().per = v end)
        local crossS = slider(pg, "Frame height", c1.x, c1:row(SLIDER), 8, 200, function() return U().cross end,
            function(v) U().cross = v end)
        onRefresh(function() -- the labels follow the fixed side
            local wide = U().fixed == "width"
            sizeS.label:SetText(wide and "Fixed width (px)" or "Fixed height (px)")
            perS.label:SetText(wide and "Frames per row" or "Frames per column")
            crossS.label:SetText(wide and "Frame height" or "Frame width")
        end)
        sliders(c1, U, { { "gap", "Gap", 0, 20 }, { "x", "X (from the center)", -1500, 1500 },
            { "y", "Y (from the center)", -1000, 1000 } })
        note(c1, "Left click targets, right click opens the menu. While this window is open a "
            .. "stand-in group shows.", 44)
        sliders(c1, U, { { "dummy", "Stand-in group size", 1, 40 } })
        c1:close()

        local c2 = group(pg, COL[2], TOP, 202, "Frames")
        dropdown(pg, "Color", c2.x, c2:row(DROP), { { "Class color", "class" }, { "Custom", "custom" } },
            function() return HB().colorMode end, function(v) HB().colorMode = v end, textPreview)
        swatch(pg, "Custom frame color", c2.x, c2:row(SWATCH), function() return HB().color end, {
            get = function() return HB().colorMode end, set = function(v) HB().colorMode = v end,
            effective = function() local c = HB().color; return c[1], c[2], c[3] end,
        })
        swatch(pg, "Frame background", c2.x, c2:row(SWATCH), function() return HB().bgColor end)
        sliders(c2, U, { { "fontSize", "Name size", 6, 24 } })
        check(pg, "Show resources", c2.x, c2:row(ROW), function() return U().power end, function(v) U().power = v end)
        sliders(c2, U, { { "powerHeight", "Resource height", 1, 20 } })
        check(pg, "Show pets", c2.x, c2:row(ROW), function() return U().pets end, function(v) U().pets = v end)
        sliders(c2, U, { { "petHeight", "Pet frame height", 6, 100 } })
        check(pg, "Role icon", c2.x, c2:row(ROW), function() return U().roleIcon end, function(v) U().roleIcon = v end)
        check(pg, "Raid marker", c2.x, c2:row(ROW), function() return U().marker end, function(v) U().marker = v end)
        note(c2, "Textures, borders, shadows and overlays come from Colors & borders. Pets wear their "
            .. "owner's class color.", 44)
        c2:close()

        -- role order: a row each, moved up or down
        local c3 = group(pg, COL[1], c1.cursor - 20, 202, "Role order")
        local ROLE_NAMES = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }
        for i = 1, 3 do
            local y = c3:row(BUTTON)
            local name = label(pg, "", "GameFontHighlight")
            name:SetPoint("TOPLEFT", c3.x, y - 6)
            onRefresh(function() name:SetText(i .. ". " .. ROLE_NAMES[U().roles[i]]) end)
            for k, d in ipairs({ { "Up", -1 }, { "Down", 1 } }) do
                local b = button(pg, d[1], 50, c3.x + 76 + (k - 1) * 54, y, function()
                    local r, j = U().roles, i + d[2]
                    if r[j] then r[i], r[j] = r[j], r[i]; changed() end
                end)
                onRefresh(function() b:SetEnabled(U().roles[i + d[2]] ~= nil) end)
            end
        end
        c3:close()

        -- buffs and debuffs: which, how many, the grid, and their spot below / above the breakpoint
        local bp = group(pg, COL[2], c2.cursor - 20, 202, "Buffs and debuffs")
        sliders(bp, U, { { "breakpoint", "Small group: up to (members)", 1, 39 } })
        note(bp, "Up to this many in the group, buffs and debuffs sit where \"small group\" says; "
            .. "with more, where \"large group\" says.", 44)
        bp:close()
        local POINTS = { { "Top left", "TOPLEFT" }, { "Top", "TOP" }, { "Top right", "TOPRIGHT" }, { "Left", "LEFT" },
            { "Center", "CENTER" }, { "Right", "RIGHT" }, { "Bottom left", "BOTTOMLEFT" }, { "Bottom", "BOTTOM" },
            { "Bottom right", "BOTTOMRIGHT" } }
        for i, k in ipairs({ { "buffs", "Buffs", { { "All", "all" }, { "Only mine", "mine" }, { "Hide", "hide" } } },
            { "debuffs", "Debuffs", { { "All", "all" }, { "Only ones I can dispel", "dispel" }, { "Hide", "hide" } } } }) do
            local A = function() return U()[k[1]] end
            local g = group(pg, COL[i + 2], TOP, 202, k[2])
            dropdown(pg, "Show", g.x, g:row(DROP), k[3], function() return A().mode end, function(v) A().mode = v end,
                textPreview)
            sliders(g, A, { { "max", "At most", 1, 40 }, { "cols", "Columns", 1, 10 }, { "rows", "Rows", 1, 10 },
                { "size", "Icon size", 6, 40 } })
            dropdown(pg, "Corner radius", g.x, g:row(DROP), { { "None (square)", 0 }, { "Slightly rounded", 12 },
                { "Rounded", 25 }, { "Circle", 50 } }, function() return A().radius end,
                function(v) A().radius = v end, textPreview)
            check(pg, "Hide timer text", g.x, g:row(ROW), function() return A().hideTimer end,
                function(v) A().hideTimer = v end)
            for _, sz in ipairs({ { "small", "Small group" }, { "large", "Large group" } }) do
                local S = function() return A()[sz[1]] end
                dropdown(pg, sz[2] .. ": anchor", g.x, g:row(DROP), POINTS, function() return S().point end,
                    function(v) S().point = v end, textPreview)
                sliders(g, S, { { "x", sz[2] .. ": X", -100, 100 }, { "y", sz[2] .. ": Y", -100, 100 } })
            end
            g:close()
        end
    end

    ----------------------------------------------------------------------------------
    -- Colors page: the palette every bar picks from
    ----------------------------------------------------------------------------------
    local P = function() return db.colors end
    local function swatches(g, list, get)
        for _, e in ipairs(list) do swatch(colorPage, e[2], g.x, g:row(SWATCH), function() return get()[e[1]] end) end
    end
    -- Bars on the left, borders on the right, each with its texture, overlay and shadow; the
    -- palette's colors below them
    local function overlay(g, key, what)
        local O = function() return P()[key] end
        check(colorPage, "Gradient overlay", g.x, g:row(ROW), function() return O().show end, function(v) O().show = v end)
        ns.shineMenus = ns.shineMenus or {}
        ns.shineMenus[#ns.shineMenus + 1] = dropdown(colorPage, "Direction", g.x, g:row(DROP),
            { { "Top to bottom", "down" }, { "Left to right", "right" } }, function() return O().dir end,
            function(v) O().dir = v end, textPreview)
        -- each end: a color of its own, or the bar's (picking a color makes it its own again)
        for _, e in ipairs({ { "from", "From" }, { "to", "To" } }) do
            local m = e[1] .. "Mode"
            dropdown(colorPage, e[2] .. " color", g.x, g:row(DROP), { { "Custom", "custom" }, { "Same as bar", "bar" } },
                function() return O()[m] end, function(v) O()[m] = v end, textPreview)
            swatch(colorPage, what .. " overlay: " .. e[1], g.x, g:row(SWATCH), function() return O()[e[1]] end, {
                get = function() return O()[m] end, set = function(v) O()[m] = v end,
                effective = function() local c = O()[e[1]]; return c[1], c[2], c[3] end,
            })
        end
    end
    local function shadow(g, key, what)
        local O = function() return P()[key] end
        check(colorPage, "Show", g.x, g:row(ROW), function() return O().show end, function(v) O().show = v end)
        if key == "innerShadow" then
            dropdown(colorPage, "Where", g.x, g:row(DROP), { { "On the bar (over the fill)", "bar" },
                { "Between border and bar", "border" } }, function() return O().on end,
                function(v) O().on = v end, textPreview)
        end
        swatch(colorPage, what .. " color", g.x, g:row(SWATCH), function() return O().color end)
        local rows = { { "size", "Size (how far it fades)", key == "innerShadow" and 0 or 1, 20 },
            { "x", "X offset", -10, 10 }, { "y", "Y offset (up)", -10, 10 } }
        if key ~= "innerShadow" then rows[#rows + 1] = { "spread", "Spread (negative: smaller)", -20, 10 } end
        for _, r in ipairs(rows) do
            slider(colorPage, r[2], g.x, g:row(SLIDER), r[3], r[4], function() return O()[r[1]] end,
                function(v) O()[r[1]] = v end)
        end
    end
    local function note(g, text, h)
        local n = label(colorPage, text, "GameFontDisableSmall")
        n:SetPoint("TOPLEFT", g.x, g:row(h))
        n:SetWidth(182)
        n:SetJustifyH("LEFT")
    end

    local bars = group(colorPage, COL[1], TOP, 202, "Bars")
    ns.sharedTextureMenu = dropdown(colorPage, "Texture", bars.x, bars:row(DROP), TEXTURES,
        function() return P().texture end, function(v) P().texture = v end, texturePreview)
    note(bars, "Every bar set to \"Shared\" under Colors takes it.", 30)
    overlay(bars, "barShine", "Bar")
    note(bars, "Laid over the bar's own color or gradient. Opacity is in each color.", 30)
    bars:close()
    local empty = group(colorPage, COL[1], bars.cursor - 20, 202, "Bars: empty bar")
    local E = function() return P().emptyBar end
    check(colorPage, "Show an empty bar underneath", empty.x, empty:row(ROW), function() return E().show end,
        function(v) E().show = v end)
    dropdown(colorPage, "Empty texture", empty.x, empty:row(DROP), TEXTURES,
        function() return E().texture end, function(v) E().texture = v end, texturePreview)
    dropdown(colorPage, "Empty color", empty.x, empty:row(DROP), { { "Same as bar, darker", "bar" },
        { "Custom", "custom" } }, function() return E().mode end,
        function(v) E().mode = v end, textPreview)
    swatch(colorPage, "Custom empty color", empty.x, empty:row(SWATCH), function() return E().color end, {
        get = function() return E().mode end, set = function(v) E().mode = v end,
        effective = function() local c = E().color; return c[1], c[2], c[3] end,
    })
    slider(colorPage, "Darker by (same as bar), %", empty.x, empty:row(SLIDER), 0, 100,
        function() return E().darken end, function(v) E().darken = v end)
    note(empty, "A solid shape the bar's size and corners, under its fill, in place of the "
        .. "see-through background. Opacity is in the custom color, for both.", 44)
    empty:close()
    local inner = group(colorPage, COL[1], empty.cursor - 20, 202, "Bars: inner shadow")
    shadow(inner, "innerShadow", "Shadow")
    note(inner, "Fades in from the edges. Opacity is in the color.", 30)
    inner:close()
    local barDrop = group(colorPage, COL[1], inner.cursor - 20, 202, "Bars: drop shadow")
    shadow(barDrop, "barShadow", "Shadow")
    note(barDrop, "The fill's shadow, over the border and under the bar.", 30)
    barDrop:close()

    local bcard = group(colorPage, COL[2], TOP, 202, "Borders")
    ns.sharedBorderTexMenu = dropdown(colorPage, "Texture", bcard.x, bcard:row(DROP), TEXTURES,
        function() return P().borderTexture end, function(v) P().borderTexture = v end, texturePreview)
    slider(colorPage, "Width", bcard.x, bcard:row(SLIDER), 0, 10,
        function() return P().borderSize end, function(v) P().borderSize = v end)
    ns.sharedRadiusMenu = dropdown(colorPage, "Corner radius", bcard.x, bcard:row(DROP), { { "None", 0 }, { "2 px", 2 }, { "4 px", 4 },
        { "8 px", 8 }, { "16 px", 16 }, { "32 px", 32 }, { "Pill (50% of height)", "pill" } },
        function() return P().radius end, function(v) P().radius = v end, textPreview)
    note(bcard, "Every bar set to \"Shared\" under Border takes these.", 30)
    slider(colorPage, "\"Same as bar\" shade", bcard.x, bcard:row(SLIDER), -100, 100,
        function() return P().borderShade end, function(v) P().borderShade = v end)
    note(bcard, "How a border that follows its bar differs from it: up to 100 "
        .. "lighter (white), down to -100 darker (black), 0 the same.", 44)
    overlay(bcard, "borderShine", "Border")
    bcard:close()
    local drop = group(colorPage, COL[2], bcard.cursor - 20, 202, "Borders: drop shadow")
    shadow(drop, "dropShadow", "Shadow")
    note(drop, "Behind the border, on every bar.", 20)
    drop:close()

    local hcard = group(colorPage, COL[3], TOP, 202, "Colors: health and standing")
    swatch(colorPage, "Health", hcard.x, hcard:row(SWATCH), function() return P().health end)
    swatch(colorPage, "Experience", hcard.x, hcard:row(SWATCH), function() return P().experience end)
    swatch(colorPage, "Honor", hcard.x, hcard:row(SWATCH), function() return P().honor end)
    swatches(hcard, { { "unhappy", "Pet: unhappy" }, { "content", "Pet: content" }, { "happy", "Pet: happy" } },
        function() return P().happiness end)
    swatches(hcard, { { "hostile", "Hostile" }, { "neutral", "Neutral" }, { "friendly", "Friendly" } },
        function() return P().reaction end)
    hcard:close()
    local ccard = group(colorPage, COL[3], hcard.cursor - 20, 202, "Colors: cast bars")
    swatches(ccard, { { "cast", "Casting" }, { "channel", "Channeling" }, { "harm", "Enemy: damage" },
        { "heal", "Enemy: healing" }, { "locked", "Enemy: can't be stopped" } }, function() return P().cast end)
    ccard:close()
    local pcard = group(colorPage, COL[4], TOP, 202, "Colors: power")
    swatches(pcard, ns.POWER_ORDER, function() return P().power end)
    pcard:close()
    local klass = group(colorPage, COL[4], pcard.cursor - 20, 202, "Colors: classes")
    swatches(klass, ns.CLASS_ORDER, function() return P().class end)
    klass:close()

    -- Enemy resource dialog: beside the window, for the enemy health bar picked on the bars page
    local rd = ns.ui.Window(nil, 230, 676, "Enemy resource")
    rd:SetParent(cfg)
    rd:ClearAllPoints()
    rd:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
    rd:Hide()
    ns.resDialog = rd
    local ry = -48
    local function rrow(h) local at = ry; ry = ry - h; return at end
    check(rd, "Hide resource text", 16, rrow(ROW), function() return cur().resHideText end,
        function(v) cur().resHideText = v end)
    check(rd, "Hide when empty", 16, rrow(ROW), function() return cur().resHideEmpty end,
        function(v) cur().resHideEmpty = v end)
    dropdown(rd, "Bar color", 16, rrow(DROP), { { "Power color", "power" }, { "Custom", "custom" } },
        function() return cur().resColorMode end, function(v) cur().resColorMode = v end, textPreview)
    swatch(rd, "Custom resource color", 16, rrow(SWATCH), function() return cur().resColor or { 0.2, 0.4, 1, 1 } end, {
        get = function() return cur().resColorMode end, set = function(v) cur().resColorMode = v end,
        effective = function()
            local f = selFrame()
            return barColors(f.resFrame or f, f.resFrame and ns.resConf(cur()) or cur())
        end,
    })
    -- inside the bar at a point of it, or outside, hung on that edge (BOTTOM: underneath)
    ns.resPlaceMenu = dropdown(rd, "Place", 16, rrow(DROP), { { "Inside the bar", "inside" }, { "Outside, on its edge", "outside" } },
        function() return cur().resPlace end, function(v) cur().resPlace = v end, textPreview)
    ns.resPointMenu = dropdown(rd, "Anchor", 16, rrow(DROP), { { "Bottom", "BOTTOM" }, { "Top", "TOP" }, { "Left", "LEFT" },
        { "Right", "RIGHT" }, { "Center", "CENTER" }, { "Top left", "TOPLEFT" }, { "Top right", "TOPRIGHT" },
        { "Bottom left", "BOTTOMLEFT" }, { "Bottom right", "BOTTOMRIGHT" } },
        function() return cur().resPoint end, function(v) cur().resPoint = v end, textPreview)
    for _, r in ipairs({ { "resHeight", "Height", 1, 40 }, { "resWidth", "Width (% of the bar)", 10, 100 },
        { "resX", "X", -100, 100 }, { "resY", "Y", -50, 50 },
        { "resBorderSize", "Border width", 0, 10 } }) do
        slider(rd, r[2], 16, rrow(SLIDER), r[3], r[4],
            function() return cur()[r[1]] or 0 end, function(v) cur()[r[1]] = v end)
    end
    dropdown(rd, "Border color", 16, rrow(DROP), { { "Same as bar (shaded)", "bar" }, { "Custom", "custom" } },
        function() return cur().resBorderMode end,
        function(v) cur().resBorderMode = v end, textPreview)
    swatch(rd, "Custom resource border", 16, rrow(SWATCH), function() return cur().resBorderColor or { 0, 0, 0, 1 } end, {
        get = function() return cur().resBorderMode end, set = function(v) cur().resBorderMode = v end,
        effective = function()
            local f = selFrame()
            return select(4, barColors(f.resFrame or f, f.resFrame and ns.resConf(cur()) or cur()))
        end,
    })
    dropdown(rd, "Border radius", 16, rrow(DROP), { { "None", 0 }, { "2 px", 2 }, { "4 px", 4 },
        { "8 px", 8 }, { "16 px", 16 }, { "Pill (50% of height)", "pill" } },
        function() return cur().resRadius end, function(v) cur().resRadius = v end, textPreview)

    -- Level and name dialog: same place, for the same bar. The font on top, then a column each.
    local td = ns.ui.Window(nil, 440, 740, "Level and name")
    td:SetParent(cfg)
    td:ClearAllPoints()
    td:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
    td:Hide()
    ns.tagDialog = td
    ry = -48
    local fontRow = rrow(DROP)
    dropdown(td, "Font", 16, fontRow, FONTS, function() return cur().tagFont end,
        function(v) cur().tagFont = v end, fontPreview)
    slider(td, "Size", 230, fontRow, 6, 32, function() return cur().tagSize end, function(v) cur().tagSize = v end)
    check(td, "Outline", 16, rrow(ROW), function() return cur().tagOutline end, function(v) cur().tagOutline = v end)
    local tnote = label(td, "The level takes the game's color: grey gives no experience, red is far "
        .. "above you. \"+\" marks an elite.", "GameFontDisableSmall")
    tnote:SetPoint("TOPLEFT", 16, rrow(34))
    tnote:SetWidth(408)
    tnote:SetJustifyH("LEFT")
    -- the point of the bar the text sits on (the text's own same point), nudged by X / Y
    local SIDES = { { "Left", "LEFT" }, { "Center", "CENTER" }, { "Right", "RIGHT" }, { "Top", "TOP" },
        { "Bottom", "BOTTOM" }, { "Top left", "TOPLEFT" }, { "Top right", "TOPRIGHT" },
        { "Bottom left", "BOTTOMLEFT" }, { "Bottom right", "BOTTOMRIGHT" } }
    local RADII = { { "None", 0 }, { "2 px", 2 }, { "4 px", 4 }, { "8 px", 8 }, { "Pill (50% of height)", "pill" } }
    local top = ry
    for i, w in ipairs({ { "Level", "tag", "tagLevel" }, { "Name", "name", "tagName" } }) do
        local x, p = 16 + (i - 1) * 214, w[2]
        -- another bar picked: the dialog is hidden, its widgets read enemy health's defaults
        local B = function() return cur()[p .. "Bg"] or DEFAULTS.regular.bars.enemyhealth[p .. "Bg"] end
        ry = top
        label(td, w[1], "GameFontNormal"):SetPoint("TOPLEFT", x, rrow(22))
        check(td, "Show " .. w[1]:lower(), x, rrow(ROW), function() return cur()[w[3]] end,
            function(v) cur()[w[3]] = v end)
        if p == "name" then
            swatch(td, "Name color", x, rrow(SWATCH), function() return cur().tagNameColor or { 1, 1, 1, 1 } end)
            local D = function() return cur().drinking or DEFAULTS.regular.bars.enemyhealth.drinking end
            check(td, "\"Drinking!\" instead, flashing", x, rrow(ROW), function() return D().show end,
                function(v) D().show = v end)
            swatch(td, "Drinking color", x, rrow(SWATCH), function() return D().color end)
            local E = function() return cur().eating or DEFAULTS.regular.bars.enemyhealth.eating end
            check(td, "\"Eating!\" instead, flashing", x, rrow(ROW), function() return E().show end,
                function(v) E().show = v end)
            swatch(td, "Eating color", x, rrow(SWATCH), function() return E().color end)
        end
        if p == "tag" then
            dropdown(td, "Sits", x, rrow(DROP), { { "Free, on the bar", "free" }, { "Left of the name", "left" },
                { "Right of the name", "right" }, { "Above the name", "top" }, { "Below the name", "bottom" } },
                function() return cur().tagAttach end, function(v) cur().tagAttach = v end, textPreview)
        end
        local pos = dropdown(td, "Anchor", x, rrow(DROP), SIDES, function() return cur()[p .. "Anchor"] end,
            function(v) cur()[p .. "Anchor"] = v end, textPreview)
        ns.tagAnchorMenus = ns.tagAnchorMenus or {}
        ns.tagAnchorMenus[p] = pos
        if p == "tag" then -- beside the name, the name decides where it is
            onRefresh(function() pos:SetShown(not (cur().tagName and ns.TAG_SIDES[cur().tagAttach or ""])) end)
        end
        slider(td, "X offset", x, rrow(SLIDER), -200, 200, function() return cur()[p .. "X"] end,
            function(v) cur()[p .. "X"] = v end)
        slider(td, "Y offset", x, rrow(SLIDER), -100, 100, function() return cur()[p .. "Y"] end,
            function(v) cur()[p .. "Y"] = v end)
        check(td, "Background", x, rrow(ROW), function() return B().show end, function(v) B().show = v end)
        swatch(td, w[1] .. " background", x, rrow(SWATCH), function() return B().color end)
        slider(td, "Padding", x, rrow(SLIDER), 0, 12, function() return B().pad end, function(v) B().pad = v end)
        dropdown(td, "Corner radius", x, rrow(DROP), RADII, function() return B().radius end,
            function(v) B().radius = v end, textPreview)
    end

    -- Buffs and debuffs dialog: a tab each (where it sits on the left, its size and grid on the
    -- right), the gaps they share underneath
    local ad = ns.ui.Window(nil, 440, 660, "Buffs and debuffs")
    ad:SetParent(cfg)
    ad:ClearAllPoints()
    ad:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
    ad:Hide()
    ns.auraDialog = ad
    local SPOTS = { { "Top, left corner", "topleft" }, { "Top, right corner", "topright" },
        { "Bottom, left corner", "bottomleft" }, { "Bottom, right corner", "bottomright" },
        { "Right side, at the top", "righttop" }, { "Left side, at the top", "lefttop" },
        { "Top, center (grows both ways)", "topcenter" }, { "Bottom, center (grows both ways)", "bottomcenter" } }
    local auraTab, panes = 1, {}
    for i, k in ipairs({ { "buffs", "Buffs" }, { "debuffs", "Debuffs" } }) do
        local tab = button(ad, k[2], 100, 16 + (i - 1) * 104, -44, function() auraTab = i; changed() end)
        local pane = CreateFrame("Frame", nil, ad)
        pane:SetAllPoints(ad)
        panes[i] = pane
        onRefresh(function()
            pane:SetShown(auraTab == i)
            if auraTab == i then tab:LockHighlight() else tab:UnlockHighlight() end
        end)
        -- another bar picked: the dialog is hidden, its widgets read enemy health's defaults
        local A = function() return cur()[k[1]] or DEFAULTS.regular.bars.enemyhealth[k[1]] end
        ry = -80
        check(pane, "Show " .. k[2]:lower(), 16, rrow(ROW), function() return A().show end, function(v) A().show = v end)
        label(pane, "Anchor to", "GameFontNormalSmall"):SetPoint("TOPLEFT", 16, rrow(18) - 4)
        for _, to in ipairs({ { "bar", "The bar" }, { "other", i == 1 and "The debuffs" or "The buffs" },
            { "line", "The center line" } }) do
            check(pane, to[2], 16, rrow(ROW), function() return A().anchorTo == to[1] end,
                function() A().anchorTo = to[1] end) -- a radio: ticking one is the choice
        end
        local edge = dropdown(pane, "On the line", 16, rrow(DROP), { { "Bottom edge (above it)", "bottom" },
            { "Center", "center" }, { "Top edge (below it)", "top" } }, function() return A().lineEdge end,
            function(v) A().lineEdge = v end, textPreview)
        onRefresh(function() edge:SetShown(A().anchorTo == "line") end)
        check(pane, "Hide timer text", 16, rrow(ROW), function() return A().hideTimer end,
            function(v) A().hideTimer = v end)
        dropdown(pane, "Starts at", 16, rrow(DROP), SPOTS, function() return A().spot end,
            function(v) A().spot = v end, textPreview)
        local centered = function() return A().spot == "topcenter" or A().spot == "bottomcenter" end
        local grows = dropdown(pane, "Grows", 16, rrow(DROP), { { "Right", "right" }, { "Left", "left" },
            { "Up", "up" }, { "Down", "down" } }, function() return A().grow end, function(v) A().grow = v end,
            textPreview)
        onRefresh(function() grows:SetShown(not centered()) end) -- centered: out both ways, nothing to pick
        -- then: which way a new row (or column) goes; auto: away from what it hangs on
        dropdown(pane, "Then (new rows / columns)", 16, rrow(DROP), function()
            local across = A().grow == "left" or A().grow == "right" or centered()
            return across and { { "Auto", "auto" }, { "Up", "up" }, { "Down", "down" } }
                or { { "Auto", "auto" }, { "Left", "left" }, { "Right", "right" } }
        end, function() return A().wrap end, function(v) A().wrap = v end, textPreview)
        dropdown(pane, "Corner radius", 16, rrow(DROP), { { "None (square)", 0 }, { "Slightly rounded", 12 },
            { "Rounded", 25 }, { "Circle", 50 } }, function() return ns.ICON_MASKS[A().radius] and A().radius or 0 end,
            function(v) A().radius = v end, textPreview)
        ry = -80
        for _, r in ipairs({ { "x", "X", -200, 200 }, { "y", "Y", -200, 200 }, { "size", "Icon size", 8, 64 },
            { "zoom", "Zoom (% cut from each side)", 0, 30 },
            { "cols", "Columns", 1, 20 }, { "rows", "Rows", 1, 10 }, { "max", "Most icons", 1, 40 } }) do
            slider(pane, r[2], 230, rrow(SLIDER), r[3], r[4], function() return A()[r[1]] end,
                function(v) A()[r[1]] = v end)
        end
    end
    local shared = ry - 10 - 74 -- the placement column is the longer one now: three radios, the line edge
    slider(ad, "Gap between icons", 16, shared, 0, 20, function() return cur().auraGap or 0 end,
        function(v) cur().auraGap = v end)
    slider(ad, "Gap between the groups", 230, shared, 0, 40, function() return cur().auraGroupGap or 0 end,
        function(v) cur().auraGroupGap = v end)
    shared = shared - SLIDER - 6
    slider(ad, "Gap from the center line", 16, shared, 0, 40, function() return cur().auraLineGap or 0 end,
        function(v) cur().auraLineGap = v end)
    local anote = label(ad, "Your health: all your buffs and debuffs. Enemy health: what Blizzard's target "
        .. "frame shows, all buffs and on an enemy your own debuffs. A group anchored to the other sits the "
        .. "group gap away from it. On the center line, a group with the other one empty sits centered.",
        "GameFontDisableSmall")
    anote:SetPoint("TOPLEFT", 16, shared - SLIDER - 4)
    anote:SetWidth(408)
    anote:SetJustifyH("LEFT")

    -- Icon dialogs: enemy health's PvP and drinking icons, your health's status and PvP icons,
    -- a column each
    local POINTS = { { "Top left", "TOPLEFT" }, { "Top", "TOP" }, { "Top right", "TOPRIGHT" }, { "Left", "LEFT" },
        { "Center", "CENTER" }, { "Right", "RIGHT" }, { "Bottom left", "BOTTOMLEFT" }, { "Bottom", "BOTTOM" },
        { "Bottom right", "BOTTOMRIGHT" } }
    for _, spec in ipairs({
        { "iconDialog", "PvP flag", "enemyhealth", { { "pvpIcon", "PvP flag" } },
            "Shows while your target is flagged: an icon in its faction's look (free-for-all has its own), or "
            .. "your own text in the name's font and size. On the name or level it sits outside, on that side." },
        { "statusDialog", "Status and PvP icons", "health", { { "statusIcon", "Status" }, { "pvpIcon", "PvP flag" } },
            "Status: the combat icon in a fight, else the Zzz (or your text) while you are resting, else nothing. "
            .. "PvP: while you are flagged." },
    }) do
        local d = ns.ui.Window(nil, #spec[4] == 1 and 230 or 440, 640, spec[2])
        d:SetParent(cfg)
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
        d:Hide()
        ns[spec[1]] = d
        local lowest = 0
        for i, k in ipairs(spec[4]) do
            local x = 16 + (i - 1) * 214
            -- another bar picked: the dialog is hidden, its widgets read the defaults
            local I = function() return cur()[k[1]] or DEFAULTS.regular.bars[spec[3]][k[1]] end
            ry = -48
            label(d, k[2], "GameFontNormal"):SetPoint("TOPLEFT", x, rrow(22))
            check(d, "Show", x, rrow(ROW), function() return I().show end, function(v) I().show = v end)
            -- a typed-in text: kept on Enter or clicking away, Escape puts it back
            local function textBox(title, field)
                label(d, title, "GameFontNormalSmall"):SetPoint("TOPLEFT", x, rrow(16))
                local tb = ns.ui.Input(d, 178)
                tb:SetPoint("TOPLEFT", x, rrow(30))
                tb:SetMaxLetters(24)
                local function keep()
                    I()[field] = tb:GetText()
                    tb:ClearFocus()
                    changed()
                end
                tb:SetScript("OnEnterPressed", keep)
                tb:HookScript("OnEditFocusLost", keep)
                tb:SetScript("OnEscapePressed", function() tb:SetText(I()[field] or ""); tb:ClearFocus() end)
                onRefresh(function() if not tb:HasFocus() then tb:SetText(I()[field] or "") end end)
                return tb
            end
            if k[1] == "pvpIcon" then
                dropdown(d, "Icon", x, rrow(DROP), { { "Faction emblem", "faction" }, { "Faction banner", "banner" },
                    { "Crossed swords", "swords" }, { "Skull", "skull" }, { "Text", "text" } },
                    function() return I().style end, function(v) I().style = v end, textPreview)
                textBox("Text", "text") -- with the Text look: what it says, and its color
                swatch(d, spec[3] == "health" and "Your PvP text color" or "PvP text color", x, rrow(SWATCH),
                    function() return I().textColor end)
                if spec[3] == "enemyhealth" then
                    dropdown(d, "Anchor to", x, rrow(DROP), { { "The bar", "bar" }, { "The name", "name" },
                        { "The level", "level" } }, function() return I().anchorTo end,
                        function(v) I().anchorTo = v end, textPreview)
                end
            elseif k[1] == "statusIcon" then
                dropdown(d, "Combat icon", x, rrow(DROP), COMBAT_ICONS, function() return I().style end,
                    function(v) I().style = v end, function(button, item)
                        local t = button:AttachTexture()
                        t:SetSize(20, 20)
                        setCombatArt(t, item[2])
                        return beforeName(button, item, t, 20)
                    end)
                check(d, "Show while resting", x, rrow(ROW), function() return I().rested end,
                    function(v) I().rested = v end)
                dropdown(d, "Resting shows", x, rrow(DROP), { { "The Zzz icon", "icon" }, { "Text", "text" } },
                    function() return I().restStyle end, function(v) I().restStyle = v end, textPreview)
                textBox("Resting text", "restText")
                swatch(d, "Resting text color", x, rrow(SWATCH), function() return I().restColor end)
                check(d, "Letters fade in and out in turn", x, rrow(ROW), function() return I().restWave end,
                    function(v) I().restWave = v end)
            end
            dropdown(d, "Point", x, rrow(DROP), POINTS, function() return I().point end,
                function(v) I().point = v end, textPreview)
            slider(d, "X", x, rrow(SLIDER), -200, 200, function() return I().x end, function(v) I().x = v end)
            slider(d, "Y", x, rrow(SLIDER), -100, 100, function() return I().y end, function(v) I().y = v end)
            slider(d, "Size", x, rrow(SLIDER), 8, 64, function() return I().size end, function(v) I().size = v end)
            lowest = math.min(lowest, ry)
        end
        local note = label(d, spec[5], "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", 16, lowest - 4)
        note:SetWidth(408)
        note:SetJustifyH("LEFT")
    end

    -- Hunter dialogs: the pet bar's happiness dot, the power bar's ammo count
    local SPOTS9 = { { "Top left", "TOPLEFT" }, { "Top", "TOP" }, { "Top right", "TOPRIGHT" }, { "Left", "LEFT" },
        { "Center", "CENTER" }, { "Right", "RIGHT" }, { "Bottom left", "BOTTOMLEFT" }, { "Bottom", "BOTTOM" },
        { "Bottom right", "BOTTOMRIGHT" } }
    for _, spec in ipairs({ { "happyDialog", "Happiness dot", "pethealth", "happy", 330 } }) do
        local d = ns.ui.Window(nil, 230, spec[5], spec[2])
        d:SetParent(cfg)
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
        d:Hide()
        ns[spec[1]] = d
        -- another bar picked: hidden, the widgets read the defaults
        local O = function() return cur()[spec[4]] or DEFAULTS.regular.bars[spec[3]][spec[4]] end
        ry = -48
        check(d, "Show", 16, rrow(ROW), function() return O().show end, function(v) O().show = v end)
        dropdown(d, "Point on the bar", 16, rrow(DROP), SPOTS9, function() return O().point end,
            function(v) O().point = v end, textPreview)
        slider(d, "X", 16, rrow(SLIDER), -200, 200, function() return O().x end, function(v) O().x = v end)
        slider(d, "Y", 16, rrow(SLIDER), -100, 100, function() return O().y end, function(v) O().y = v end)
        slider(d, spec[4] == "happy" and "Dot size" or "Size", 16, rrow(SLIDER), spec[4] == "happy" and 2 or 6, 32,
            function() return O().size end, function(v) O().size = v end)
        if spec[4] == "ammo" then
            dropdown(d, "Font", 16, rrow(DROP), FONTS, function() return O().font end, function(v) O().font = v end,
                fontPreview)
            check(d, "Outline", 16, rrow(ROW), function() return O().outline end, function(v) O().outline = v end)
            swatch(d, "Ammo color", 16, rrow(SWATCH), function() return O().color end)
            swatch(d, "Ammo color when low", 16, rrow(SWATCH), function() return O().lowColor end)
            slider(d, "Low is under", 16, rrow(SLIDER), 1, 2000, function() return O().low end,
                function(v) O().low = v end)
        end
        local n = label(d, spec[4] == "happy" and "Hunters: red unhappy, orange content, green happy "
            .. "(the colors are on the Colors page)." or "Hunters: the ammunition in your ammo slot.",
            "GameFontDisableSmall")
        n:SetPoint("TOPLEFT", 16, rrow(40))
        n:SetWidth(198)
        n:SetJustifyH("LEFT")
    end

    -- Drinking text (power bar) and eating text (health bar) dialogs
    for _, spec in ipairs({ { "drinkDialog", "Drinking text", "power", "drinkText", "drinking", "Drink" },
        { "eatDialog", "Eating text", "health", "eatText", "eating", "Food" } }) do
        local d = ns.ui.Window(nil, 230, 470, spec[2])
        d:SetParent(cfg)
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
        d:Hide()
        ns[spec[1]] = d
        local O = function() return cur()[spec[4]] or DEFAULTS.regular.bars[spec[3]][spec[4]] end
        ry = -48
        check(d, "Show while " .. spec[5], 16, rrow(ROW), function() return O().show end, function(v) O().show = v end)
        label(d, "Text", "GameFontNormalSmall"):SetPoint("TOPLEFT", 16, rrow(16))
        local tb = ns.ui.Input(d, 198)
        tb:SetPoint("TOPLEFT", 16, rrow(30))
        tb:SetMaxLetters(24)
        local function keep() O().text = tb:GetText(); tb:ClearFocus(); changed() end
        tb:SetScript("OnEnterPressed", keep)
        tb:HookScript("OnEditFocusLost", keep)
        tb:SetScript("OnEscapePressed", function() tb:SetText(O().text or ""); tb:ClearFocus() end)
        onRefresh(function() if not tb:HasFocus() then tb:SetText(O().text or "") end end)
        dropdown(d, "Point on the bar", 16, rrow(DROP), SPOTS9, function() return O().point end,
            function(v) O().point = v end, textPreview)
        slider(d, "X", 16, rrow(SLIDER), -200, 200, function() return O().x end, function(v) O().x = v end)
        slider(d, "Y", 16, rrow(SLIDER), -100, 100, function() return O().y end, function(v) O().y = v end)
        slider(d, "Size", 16, rrow(SLIDER), 6, 32, function() return O().size end, function(v) O().size = v end)
        swatch(d, spec[2] .. " color", 16, rrow(SWATCH), function() return O().color end)
        local n = label(d, ("Flashes while you have a %s buff. The font is the bar's."):format(spec[6]),
            "GameFontDisableSmall")
        n:SetPoint("TOPLEFT", 16, rrow(30))
        n:SetWidth(198)
        n:SetJustifyH("LEFT")
    end

    -- Mana regen spinner dialog (the setting itself lives with the other page's, db.other.fsr)
    local fd = ns.ui.Window(nil, 230, 560, "Mana regen spinner")
    fd:SetParent(cfg)
    fd:ClearAllPoints()
    fd:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
    fd:Hide()
    ns.fsrDialog = fd
    local FS = function() return db.other.fsr end
    ry = -48
    check(fd, "Show", 16, rrow(ROW), function() return FS().show end, function(v) FS().show = v end)
    dropdown(fd, "Attach to bar", 16, rrow(DROP), function()
        local list = {}
        for _, key in ipairs(db.regular.order) do list[#list + 1] = { BARS[key].label, key } end
        return list
    end, function() return FS().bar end, function(v) FS().bar = v end, textPreview)
    slider(fd, "Size", 16, rrow(SLIDER), 8, 96, function() return FS().size end, function(v) FS().size = v end)
    local spinDir = button(fd, "", 186, 16, rrow(BUTTON), function()
        FS().fill = not FS().fill
        changed()
    end)
    onRefresh(function() spinDir:SetText(FS().fill and "Ring: Fills up" or "Ring: Drains away") end)
    slider(fd, "X (left / right)", 16, rrow(SLIDER), -200, 200, function() return FS().x end, function(v) FS().x = v end)
    slider(fd, "Y (down / up)", 16, rrow(SLIDER), -200, 200, function() return FS().y end, function(v) FS().y = v end)
    swatch(fd, "Spinner color", 16, rrow(SWATCH), function() return FS().color end)
    check(fd, "Show while regenerating", 16, rrow(ROW), function() return FS().regen end,
        function(v) FS().regen = v end)
    swatch(fd, "Regenerating color", 16, rrow(SWATCH), function() return FS().regenColor end)
    local fnote = label(fd, "Runs until Spirit regen is back: 5 s in combat, 7 s out of it. Then, while "
        .. "your mana refills, a fifth of the ring keeps turning in the regenerating color. Mana classes only.",
        "GameFontDisableSmall")
    fnote:SetPoint("TOPLEFT", 16, rrow(60))
    fnote:SetWidth(198)
    fnote:SetJustifyH("LEFT")

    -- Numbers dialog: percent, current and current / max for the bar picked, a row each
    local nd = ns.ui.Window(nil, 440, 520, "Numbers")
    nd:SetParent(cfg)
    nd:ClearAllPoints()
    nd:SetPoint("TOPLEFT", cfg, "TOPRIGHT", 12, 0)
    nd:Hide()
    ns.textDialog = nd
    local NSIDES = { { "Left", "LEFT" }, { "Center", "CENTER" }, { "Right", "RIGHT" } }
    ry = -48
    for _, k in ipairs({ { "percent", "Percent" }, { "current", "Current" }, { "currentmax", "Current / max" } }) do
        -- another bar picked: the dialog is hidden, its widgets read health's defaults
        local T = function() return (cur().texts or DEFAULTS.regular.bars.health.texts)[k[1]] end
        local top = ry
        label(nd, k[2], "GameFontNormal"):SetPoint("TOPLEFT", 16, top)
        check(nd, "Show", 16, top - 22, function() return T().show end, function(v) T().show = v end)
        dropdown(nd, "Position", 16, top - 46, NSIDES, function() return T().anchor end,
            function(v) T().anchor = v end, textPreview)
        slider(nd, "Size", 16, top - 96, 6, 32, function() return T().size end, function(v) T().size = v end)
        slider(nd, "X", 230, top - 22, -200, 200, function() return T().x end, function(v) T().x = v end)
        slider(nd, "Y", 230, top - 68, -50, 50, function() return T().y end, function(v) T().y = v end)
        swatch(nd, k[2] .. " color", 230, top - 118, function() return T().color end)
        ry = top - 152
    end
    local nnote = label(nd, "Font and outline are the bar's, on its Text card. \"Show text\" there turns "
        .. "all three off at once.", "GameFontDisableSmall")
    nnote:SetPoint("TOPLEFT", 16, ry)
    nnote:SetWidth(408)
    nnote:SetJustifyH("LEFT")

    for _, page in pairs(ns.pages) do ns.foldColumns(page, COL, TOP) end
    ns.configHeight = math.max(-(ns.sidebarBottom or 0) + 24, 640)
    cfg:SetHeight(math.min(ns.configHeight, math.floor(UIParent:GetHeight()) - 40))
end

function ns.ToggleConfig()
    if not db then return end
    if not cfg then
        buildConfig() -- a frame is on screen the moment it is made, so there is nothing to flip
        cfg:Show()
    else
        cfg:SetShown(not cfg:IsShown())
    end
    ns.cfg = cfg
    -- the first opening fires no OnShow (a new frame is shown already), so say it here: it is
    -- what puts the dummy buffs, debuffs and every other preview up
    ns.configOpen = cfg:IsShown() and true or false
    if cfg:IsShown() then changed() end
end
-- /bs: the options window, opened on Bar Stack; closes it if that is already what is on screen
function ns.ShowBarStack()
    if cfg and cfg:IsShown() and section == "barstack" then cfg:Hide() return end
    section, mode = "barstack", "regular"
    if cfg and cfg:IsShown() then changed() else ns.ToggleConfig() end
end
WolfpackAddon_Toggle = ns.ToggleConfig -- addon compartment (retail only, Forever has none)

SLASH_WOLFPACKADDON1 = "/wolfpack"
SLASH_WOLFPACKADDON2 = "/wp"
SLASH_WOLFPACKADDON3 = "/cpd" -- the old name still works
-- Watches, from login, whether anything still says "that was a critical hit". The combat log
-- is gone here and registering it is itself blocked, so only ordinary events are tried:
-- UNIT_COMBAT, which vanilla used for exactly this, and the scrolling combat text feed.
-- /cpd crit says what has arrived.
ns.critSeen = { counts = {}, samples = {} }
ns.critEv = CreateFrame("Frame")
ns.critEv:SetScript("OnEvent", function(_, event, ...)
    local seen = ns.critSeen
    seen.counts[event] = (seen.counts[event] or 0) + 1
    local bits = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        bits[#bits + 1] = readable(v) and tostring(v):sub(1, 20) or "<secret>"
    end
    local line = table.concat(bits, " ")
    if line:find("CRIT") then
        seen.samples[event .. " CRIT"] = line
    elseif not seen.samples[event] then
        seen.samples[event] = line
    end
end)
pcall(ns.critEv.RegisterUnitEvent, ns.critEv, "UNIT_COMBAT", "player", "target")
pcall(ns.critEv.RegisterEvent, ns.critEv, "COMBAT_TEXT_UPDATE")

function ns.CritReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    say("what has arrived since login (hit something a few times first):")
    local any = false
    for event, n in pairs(ns.critSeen.counts) do
        any = true
        say(("  %s: %d  %s"):format(event, n, ns.critSeen.samples[event] or ""))
    end
    for key, sample in pairs(ns.critSeen.samples) do
        if key:find("CRIT") then say("  |cff55ff55" .. key .. ":|r " .. sample) end
    end
    if not any then say("  nothing at all: no crit is visible to an addon here") end
end

-- /cpd auras: says which aura calls this client has and whether they answer right now, which
-- is the only way to tell from inside the game why a buff icon is missing. Run it twice: once
-- out of combat and once in combat, with the buff actually on you.
function ns.AuraReport(spellName)
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    local sp = { name = (spellName ~= "" and spellName) or "Renew", id = 0 }
    say(("combat %s, issecretvalue %s, looking for %s -- have it on you when you run this")
        :format(tostring(InCombatLockdown()), tostring(issecretvalue ~= nil), sp.name))

    local function report(label, fn, ...)
        local args = { ... }
        local ok, res = pcall(function() return fn(unpack(args)) end)
        if not ok then
            say(label .. ": refused (" .. tostring(res):match("[^\n]*"):sub(1, 60) .. ")")
        elseif res == nil then
            say(label .. ": answered, nothing")
        else
            local n = 0
            pcall(function() for _ in ipairs(res) do n = n + 1 end end)
            local extra = ""
            pcall(function()
                extra = ", instance " .. (readable(res.auraInstanceID) and "readable" or "secret")
                    .. ", name " .. (readable(res.name) and "readable" or "secret")
            end)
            say(label .. ": ANSWERED" .. (n > 0 and (", " .. n .. " entries") or extra))
        end
    end

    local A = C_UnitAuras
    if A.GetAuraDataBySpellName then
        report("byName(no filter)", A.GetAuraDataBySpellName, "player", sp.name)
        report("byName(HELPFUL)", A.GetAuraDataBySpellName, "player", sp.name, "HELPFUL")
        report("byName(HELPFUL|PLAYER)", A.GetAuraDataBySpellName, "player", sp.name, "HELPFUL|PLAYER")
    else
        say("byName: not on this client")
    end
    if A.GetPlayerAuraBySpellID then
        report("playerAuraBySpellID", A.GetPlayerAuraBySpellID, sp.id or 0)
    else
        say("playerAuraBySpellID: not on this client")
    end
    if AuraUtil and AuraUtil.FindAuraByName then
        report("AuraUtil.FindAuraByName", AuraUtil.FindAuraByName, sp.name, "player", "HELPFUL")
    end
    if UnitBuff then report("UnitBuff(1)", UnitBuff, "player", 1) end
    report("GetUnitAuras HELPFUL", function() return A.GetUnitAuras("player", "HELPFUL|PLAYER", 40) end)
    report("GetUnitAuras HARMFUL|RAID", function() return A.GetUnitAuras("player", "HARMFUL|RAID", 8) end)
    report("GetAuraDataByIndex(1)", A.GetAuraDataByIndex, "player", 1, "HELPFUL|PLAYER")
end

-- /wp armor -- what the warlock icon thinks it sees, for when it shows up at the wrong time.
function ns.ArmorReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    say(InCombatLockdown() and "in combat -- only the buff bar can answer" or "out of combat")
    for _, sp in ipairs(wl.armors) do
        local want = wl.icons(sp[2])
        local ok, data = pcall(function()
            return C_UnitAuras.GetAuraDataBySpellName("player", sp[1], "HELPFUL")
        end)
        local bar = wl.iconOnBuffBar(want)
        say(("%s: icon %s | aura %s | buff bar %s"):format(sp[1], tostring(want),
            ok and (data and "found" or "not on you") or "call refused",
            bar == nil and "no answer" or tostring(bar)))
    end
    say(("remembered: %s%s"):format(tostring(wl.memoUp),
        wl.memoSp and (" (" .. wl.memoSp[1] .. ")") or ""))
    local sp, up = wl.armor()
    say(("level %s -- verdict: %s, buffed = %s"):format(tostring(UnitLevel("player")),
        sp and sp[1] or "none", tostring(up)))
end

-- /wp pet -- which of the happiness routes, if any, this build still answers on.
function ns.PetReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    local function shot(what, fn)
        local ok, v = pcall(fn)
        say(("%s: %s %s"):format(what, ok and type(v) or "error", tostring(v)))
    end
    say(("pet exists = %s, name = %s"):format(tostring(UnitExists("pet")),
        tostring(UnitName("pet"))))
    shot("GetPetHappiness", function() return GetPetHappiness() end)
    shot("UnitPetHappiness", function() return UnitPetHappiness("pet") end)
    shot("PetFrameHappiness", function()
        return PetFrameHappiness and select(2, PetFrameHappiness:GetTexCoord())
    end)
    shot("hn.happiness", hn.happiness)
    local function keys(t, want)
        local out = {}
        if type(t) == "table" then
            for k, v in pairs(t) do
                if type(k) == "string" and (not want or k:lower():find(want)) then
                    out[#out + 1] = k .. (type(v) == "number" and ("=" .. v) or "")
                end
            end
        end
        table.sort(out)
        return #out > 0 and table.concat(out, ", ") or "nothing"
    end
    local f = PetFrameHappiness
    say(("PetFrameHappiness: %s %s"):format(type(f),
        type(f) == "table" and f.GetObjectType and f:GetObjectType() or ""))
    if type(f) == "table" then
        say("  its own keys: " .. keys(f))
        if f.GetRegions then
            for i, r in ipairs({ f:GetRegions() }) do
                local ok, tex = pcall(function() return r.GetTexture and r:GetTexture() end)
                local ok2, a = pcall(function() return r.GetAtlas and r:GetAtlas() end)
                local ok3, c = pcall(function()
                    return r.GetTexCoord and table.concat({ r:GetTexCoord() }, " ")
                end)
                say(("  region %d: %s tex=%s atlas=%s coords=%s"):format(i,
                    r.GetObjectType and r:GetObjectType() or "?", ok and tostring(tex) or "-",
                    ok2 and tostring(a) or "-", ok3 and tostring(c) or "-"))
            end
        end
    end
    say("PetHappinessIndicatorMixin: " .. keys(PetHappinessIndicatorMixin))
    say("PetPaperDollPetHappinessInfo: " .. keys(PetPaperDollPetHappinessInfo))
    local api = {}
    for name, t in pairs(_G) do
        if type(name) == "string" and name:find("^C_") and type(t) == "table" then
            for k in pairs(t) do
                if type(k) == "string" and k:lower():find("happ") then
                    api[#api + 1] = name .. "." .. k
                end
            end
        end
    end
    table.sort(api)
    say("namespaced calls: " .. (#api > 0 and table.concat(api, ", ") or "nothing"))
    local names = { "UI-PetHappiness" }
    for i = 1, 3 do
        names[#names + 1] = "UI-PetHappiness" .. i
        names[#names + 1] = "PetHappiness" .. i
        names[#names + 1] = "UI-HUD-UnitFrame-Player-PetFrame-Happiness" .. i
    end
    local atlases = {}
    for _, n in ipairs(names) do
        local ok, info = pcall(function() return C_Texture.GetAtlasInfo(n) end)
        if ok and type(info) == "table" then
            atlases[#atlases + 1] = ("%s (%sx%s)"):format(n, tostring(info.width),
                tostring(info.height))
        end
    end
    say("atlases that exist: " .. (#atlases > 0 and table.concat(atlases, ", ") or "none"))
    local look = hn.happyLook()
    say("what we would draw: " .. (look and (look.atlas or tostring(look.tex)) or "the old file"))
end

-- /wp flight -- whether the route is being caught, and what is remembered.
function ns.FlightReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    say("on a taxi: " .. tostring(ft.flying()) .. ", timing since: " .. tostring(ft.startedAt))
    say("hooked: " .. (ft.hooked and #ft.hooked > 0 and table.concat(ft.hooked, ", ") or "nothing"))
    say("TakeTaxiNode is a " .. type(TakeTaxiNode) .. ", TaxiNodeName a " .. type(TaxiNodeName)
        .. ", C_TaxiMap a " .. type(C_TaxiMap))
    say("standing at: " .. tostring(ft.here()))
    local nodes = {}
    pcall(function()
        for _, n in ipairs(C_TaxiMap.GetAllTaxiNodes(C_Map.GetBestMapForUnit("player")) or {}) do
            nodes[#nodes + 1] = ("%s[%s/%s]"):format(n.name or "?", tostring(n.slotIndex),
                tostring(n.state))
        end
    end)
    say("flight map: " .. (#nodes > 0 and table.concat(nodes, ", "):sub(1, 260) or "nothing open"))
    say("last route caught: " .. (ft.key() or "none") .. ", known: " .. tostring(ft.known()))
    local n = 0
    for _ in pairs((store and store.flights) or {}) do n = n + 1 end
    say(n .. " routes remembered")
end

-- /wp heal -- which of the incoming-heal calls this build has, and what they say right now.
function ns.HealReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    say("CreateUnitHealPredictionCalculator: " .. type(CreateUnitHealPredictionCalculator)
        .. ", the calculator itself: " .. type(healCalc))
    say("UnitGetDetailedHealPrediction: " .. type(UnitGetDetailedHealPrediction)
        .. ", UnitGetIncomingHeals: " .. type(UnitGetIncomingHeals))
    local ok, heals = pcall(function() return UnitGetIncomingHeals("player") end)
    say(("UnitGetIncomingHeals(player): %s %s"):format(tostring(ok),
        readable(heals) and tostring(heals) or "<secret>"))
    if healCalc and UnitGetDetailedHealPrediction then
        local ok2, got = pcall(function()
            UnitGetDetailedHealPrediction("player", "player", healCalc)
            return healCalc:GetIncomingHeals()
        end)
        say(("the calculator says: %s %s"):format(tostring(ok2),
            readable(got) and tostring(got) or "<secret>"))
    end
    say("the bar is switched on: " .. tostring(db and db.regular.bars.health.heal))
end

function ns.CastReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    local c = db and db.regular.bars.targetcast
    say("the bar is on: " .. tostring(c and c.show) .. ", in the list at: "
        .. tostring((function()
            for i, k in ipairs(db and db.regular.order or {}) do
                if k == "targetcast" then return i end
            end
        end)()))
    say("frame exists: " .. tostring(ns.frames.targetcast ~= nil) .. ", shown: "
        .. tostring(ns.frames.targetcast and ns.frames.targetcast:IsShown()))
    local got = { pcall(UnitCastingInfo, "target") }
    say(("UnitCastingInfo(target): %s %s icon %s cannot-stop %s"):format(tostring(got[1]),
        tostring(got[2]), tostring(got[4]), tostring(got[9])))
    local chan = { pcall(UnitChannelInfo, "target") }
    say(("UnitChannelInfo(target): %s %s"):format(tostring(chan[1]), tostring(chan[2])))
    say("UnitCastingDuration: " .. type(UnitCastingDuration) .. ", for the target: "
        .. tostring(({ pcall(UnitCastingDuration, "target") })[2]))
    say("your own cast right now: " .. tostring(({ pcall(UnitCastingInfo, "player") })[2]))
end

SlashCmdList.WOLFPACKADDON = function(msg)
    msg = (msg or ""):lower()
    if msg:find("aura") then return safe(ns.AuraReport, (msg:gsub("^%s*auras?%s*", ""))) end
    if msg:find("crit") then return safe(ns.CritReport) end
    if msg:find("armor") then return safe(ns.ArmorReport) end
    if msg:find("pet") then return safe(ns.PetReport) end
    if msg:find("flight") then return safe(ns.FlightReport) end
    if msg:find("heal") then return safe(ns.HealReport) end
    if msg:find("cast") then return safe(ns.CastReport) end
    if msg:find("bind") then return safe(ns.BindReport) end
    safe(ns.ToggleConfig)
end

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
    elseif (startItem or 0) == 0 and not (QuestIsFromAreaTrigger and QuestIsFromAreaTrigger()) then
        -- neither call is on Anniversary or Classic Era, which have no such quests anyway
        if QuestGetAutoAccept and QuestGetAutoAccept() then AcknowledgeAutoAcceptQuest() else AcceptQuest() end
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
    -- Newer clients list gossip quests in C_GossipInfo, by quest ID. Anniversary and Classic Era
    -- have the old flat lists instead (6 values per active quest, 7 per available one), picked
    -- by position.
    local G = C_GossipInfo
    if db.other.autoComplete then
        if G and G.GetActiveQuests then
            for _, q in ipairs(G.GetActiveQuests() or {}) do
                if q.isComplete and take("done" .. q.questID, G.SelectActiveQuest, q.questID) then return end
            end
        elseif GetGossipActiveQuests then
            local info = { GetGossipActiveQuests() }
            for i = 1, #info / 6 do
                if info[(i - 1) * 6 + 4] and take("oldDone" .. i, SelectGossipActiveQuest, i) then return end
            end
        end
        for i = 1, GetNumActiveQuests() do
            if select(2, GetActiveTitle(i)) and take("greetDone" .. i, SelectActiveQuest, i) then return end
        end
    end
    if db.other.autoAccept then
        if G and G.GetAvailableQuests then
            for _, q in ipairs(G.GetAvailableQuests() or {}) do
                if take("new" .. q.questID, G.SelectAvailableQuest, q.questID) then return end
            end
        elseif GetGossipAvailableQuests then
            for i = 1, select("#", GetGossipAvailableQuests()) / 7 do
                if take("oldNew" .. i, SelectGossipAvailableQuest, i) then return end
            end
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
                if f:IsShown() then safe(ns.fill, f) end
            end
        end
    end
    if not swingActive() then swingTicker:SetScript("OnUpdate", nil) end
end

-- A swing starts: duration in seconds, swing type 0 main hand, 1 off hand, 2 ranged.
-- Either may arrive secret, and the timer does math on both every frame: a secret one would
-- throw there, over and over, and stop the whole stack from laying out. Such a swing is left
-- untimed instead.
function ns.startSwing(duration, kind)
    if not (readable(duration) and readable(kind) and type(duration) == "number" and duration > 0
        and type(kind) == "number") then return end
    swingState[kind] = { start = GetTime(), duration = duration }
    swingTicker:SetScript("OnUpdate", swingTick)
    swingTick()
end

-- Anniversary and Classic Era have no PLAYER_SWING (Forever does), but their combat log still
-- tells addons when you swing: a hit or a miss starts the next one, as long as your weapon's
-- current speed. Dodges and parries count too; they are swings all the same.
-- Midnight (12.x) keeps the combat log from addons, so only the classic clients read it.
ns.swingLog = not C_SwingTimer and CombatLogGetCurrentEventInfo ~= nil and select(4, GetBuildInfo()) < 100000
function ns.swingFromLog()
    local _, sub, _, source, _, _, _, _, _, _, _, a12, a13, _, _, _, _, _, _, _, a21 = CombatLogGetCurrentEventInfo()
    if source ~= UnitGUID("player") then return end
    local off
    if sub == "SWING_DAMAGE" then off = a21     -- isOffHand, after the damage fields
    elseif sub == "SWING_MISSED" then off = a13 -- missType, isOffHand
    else return end
    local main, offSpeed = UnitAttackSpeed("player")
    if off then ns.startSwing(offSpeed, 1) else ns.startSwing(main, 0) end
end

local petEv = CreateFrame("Frame") -- same handler as ev, for pet unit events

-- Auto-sell junk: gray items that have a sell price, one every 0.2 s while the merchant window
-- is open. Nothing else is ever sold, and closing the window stops it.
local sellTicker
-- Repairs everything at a merchant that can, out of your own money, and says what it cost.
local function autoRepair()
    if not db.other.autoRepair then return end
    if not (CanMerchantRepair and CanMerchantRepair()) then return end
    local ok, cost, canRepair = pcall(GetRepairAllCost)
    if not ok or not canRepair or (cost or 0) <= 0 then return end
    if GetMoney() < cost then
        print("|cffff5555Wolfpack Addon:|r not enough money to repair (" .. ns.money(cost) .. ")")
        return
    end
    RepairAllItems()
    print("|cff33ff99Wolfpack Addon|r repaired for " .. ns.money(cost))
end

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
            if earned > 0 then print("|cff33ff99Wolfpack Addon|r sold junk for " .. ns.money(earned)) end
        end)
    end, #queue + 1)
end

local function stopSelling()
    if sellTicker then
        sellTicker:Cancel()
        sellTicker = nil
    end
end

-- The flight bar is the one bar the game will not animate for us -- there is no duration object
-- for a taxi ride -- so it is redrawn on a ticker, and only while the griffin has you.
ft.ticker = CreateFrame("Frame")
ft.ticker.since = 0
ft.ticker:SetScript("OnUpdate", function(self, elapsed)
    if not db then return end
    self.since = self.since + elapsed
    if self.since < 0.2 then return end
    self.since = 0
    safe(ft.tick)
    if ft.moved then -- takeoff or landing: the bar joins or leaves the stack
        ft.moved = nil
        changed()
    end
    if not (ft.startedAt or ns.previewing()) then return end
    for _, set in ipairs({ frames }) do
        local f = set.flight
        if f and f:IsShown() then safe(ns.fill, f) end
    end
end)

local function fillShown(...)
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if frames[key]:IsShown() then safe(ns.fill, frames[key]) end
    end
end

-- Nothing says when your target's target loses health, so its bar asks five times a second.
ns.totPoll = CreateFrame("Frame")
ns.totPoll.wait = 0
ns.totPoll:SetScript("OnUpdate", function(self, elapsed)
    self.wait = self.wait - (elapsed or 0)
    if self.wait > 0 then return end
    self.wait = 0.2
    for _, set in ipairs({ frames }) do
        if set.tothealth:IsShown() then safe(ns.fill, set.tothealth) end
    end
end)

ev:SetScript("OnEvent", function(_, event, unit, arg2, arg3)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then -- by far the busiest, so asked first
        safe(ns.swingFromLog)
    elseif event == "ADDON_LOADED" then
        if unit == ADDON then applyCombatFont() end
    elseif event == "PLAYER_LOGIN" then
        -- ponytail: settings saved before profiles existed are dropped (the beta never loaded them anyway)
        store = type(WolfpackAddonDB) == "table" and WolfpackAddonDB.profiles and WolfpackAddonDB
            or { profiles = {}, chars = {} }
        WolfpackAddonDB = store
        store.minimapAngle = store.minimapAngle or 220
        store.classProfiles = store.classProfiles or {} -- [class token] = profile name
        -- every profile, not just the one in use: a bar added since it was saved belongs on all
        -- of them, and switching to one later should not be the first time it appears
        for _, prof in pairs(store.profiles) do
            for _, which in ipairs({ "regular", "plates" }) do
                ns.repairOrder(prof[which], DEFAULTS[which].order)
            end
        end
        store.flights = store.flights or {} -- ["Ironforge > Menethil Harbor"] = seconds
        safe(ft.hook)
        seedFromBaked()
        classProfile, class = UnitClass("player")
        playerName = UnitName("player")
        charKey = playerName .. " - " .. GetRealmName()
        for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
            "UNIT_SPELLCAST_SUCCEEDED",
            "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
            listen(e, "player", "target")
        end
        listen("UNIT_HEALTH", "player", "target")
        listen("UNIT_MAXHEALTH", "player", "target")
        listen("UNIT_ABSORB_AMOUNT_CHANGED", "player")
        for _, e in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP" }) do
            listen(e)
        end
        listen("UNIT_HEAL_PREDICTION", "player", "target")
        listen("UNIT_PET", "player") -- pet summoned, dismissed or swapped
        pcall(petEv.RegisterUnitEvent, petEv, "UNIT_HEALTH", "pet")
        pcall(petEv.RegisterUnitEvent, petEv, "UNIT_MAXHEALTH", "pet")
        for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
            listen(e, "player", "target") -- target: the enemy resource bar
        end
        listen("UNIT_QUEST_LOG_CHANGED", "player")
        listen("UNIT_AURA", "target", "player") -- buffs and debuffs on both health bars; drinking
        listen("UNIT_FACTION", "target", "player") -- PvP flags
        listen("UNIT_TARGET", "target") -- your target's target changed: target of target
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
            "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED",
            "QUEST_DETAIL", "QUEST_ACCEPT_CONFIRM", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_GREETING",
            "PLAYER_REGEN_DISABLED", "PLAYER_UPDATE_RESTING", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_FACTION", "HONOR_XP_UPDATE", "ACTIONBAR_SHOWGRID",
            "ACTIONBAR_HIDEGRID", "CURSOR_CHANGED", "ACTIONBAR_SLOT_CHANGED", "PLAYER_SWING", "PLAYER_TOTEM_UPDATE", "MERCHANT_SHOW", "MERCHANT_CLOSED",
            "GOSSIP_CLOSED" }) do
            listen(e)
        end
        if ns.swingLog then listen("COMBAT_LOG_EVENT_UNFILTERED") end -- swings, where no PLAYER_SWING
        inCombat = InCombatLockdown() -- a /reload mid-fight
        ns.inCombat = inCombat
        local mine = store.chars[charKey]
        if not (mine and store.profiles[mine]) then
            mine = store.classProfiles and store.classProfiles[class or ""]
        end
        useProfile(store.profiles[mine or ""] and mine or classProfile)
        placeMini()
    elseif event == "UNIT_AURA" or event == "UNIT_FACTION" or event == "PLAYER_UPDATE_RESTING" then
        for _, set in ipairs({ frames }) do
            if set.enemyhealth:IsShown() and unit == "target" then
                if event == "UNIT_AURA" then
                    safe(ns.layoutAuras, set.enemyhealth)
                    safe(ns.layoutTag, set.enemyhealth) -- drinking
                end
                safe(ns.layoutBadges, set.enemyhealth)
            end
            if set.health:IsShown() and unit ~= "target" then
                if event == "UNIT_AURA" then safe(ns.layoutAuras, set.health) end
                if event == "UNIT_AURA" and set.power:IsShown() then safe(ns.layoutMealText, set.power) end
                if event == "UNIT_AURA" then safe(ns.layoutMealText, set.health) end
                safe(ns.layoutBadges, set.health)
            end
        end
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        -- a spell dropped on a slot lands after the drag has ended: look at empty slots again
        -- then. Many come at once (login, a talent swap): one look for all of them.
        if not ns.ab.slotPending then
            ns.ab.slotPending = true
            C_Timer.After(0.05, function()
                ns.ab.slotPending = false
                safe(ns.syncActionBars)
            end)
        end
    elseif event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" or event == "CURSOR_CHANGED" then
        -- dragging something that can go on an action button: hidden empty slots show for it
        local ok, what = pcall(GetCursorInfo)
        local drag = event == "ACTIONBAR_SHOWGRID" or (event == "CURSOR_CHANGED" and ok and what ~= nil)
        if drag ~= (ns.ab.dragging or false) then
            ns.ab.dragging = drag
            safe(Refresh)
        end
    elseif event == "PLAYER_XP_UPDATE" or event == "HONOR_XP_UPDATE" then
        fillShown("experience")
    elseif event == "UNIT_HEAL_PREDICTION" then
        fillShown("health")
    elseif event == "PLAYER_TARGET_CHANGED" then
        safe(ns.watchTargetCast, event) -- a new target is not mid-cast until it says so
        safe(Refresh)
    elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        if GetTime() - absorb.castAt <= ABSORB_CAST_WINDOW then -- our cast just put a shield up
            local ok, points = pcall(UnitGetTotalAbsorbs, "player")
            absorb.max, absorb.have = ok and points, ok
        end
        fillShown("absorb")
    elseif event == "UNIT_HEALTH" then
        fillShown("health", "pethealth")
        fillShown("absorb") -- max health scales it
        fillShown("enemyhealth")
    elseif event == "UNIT_POWER_FREQUENT" then
        if unit == "target" then -- only the enemy resource bars read your target's power
            for _, set in ipairs({ frames }) do
                if set.enemyhealth.resFrame:IsShown() then safe(ns.fill, set.enemyhealth.resFrame) end
            end
        else
            fillShown("power", "combo", "druidmana")
            if fsr:on() and (fsr.endTime or 0) <= GetTime() then safe(fsr.sync, fsr) end -- refilling, full yet?
        end

    elseif event:find("^UNIT_SPELLCAST_") then
        safe(ns.watchTargetCast, event, unit)
        if unit == "player" then
            safe(fsr.cast, fsr, event, arg2, arg3)
            safe(castCost.track, castCost, event, arg3)
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                absorb.castAt = GetTime()
                -- Auto Shot or a wand's Shoot: the ranged swing, where no PLAYER_SWING says so
                if ns.swingLog and (arg3 == 75 or arg3 == 5019) then
                    local ok, speed = pcall(UnitRangedDamage, "player")
                    if ok then ns.startSwing(speed, 2) end
                end
            end
        end
        safe(Refresh) -- the cast bar joins or leaves the stack
    elseif event == "PLAYER_SWING" then -- unit, arg2 = duration, swing type
        ns.startSwing(unit, arg2)
    elseif event == "PLAYER_TOTEM_UPDATE" then -- hand the new timers over; they run themselves
        fillShown("totems")
    elseif event == "MERCHANT_SHOW" then
        safe(sellJunk)
        safe(autoRepair)
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
        inCombat, ns.inCombat = true, true
        safe(Refresh)
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat, ns.inCombat = false, false
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
