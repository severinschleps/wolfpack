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
local DEFAULT_PROFILE = "WPA1:7V1bbCPVGbb3glarLS0QqU4eVstDK6QWHlqoQlUwXnvsOLshwZuIbRUVJvbYGa0zY2bGZLNtJVq2UqtSeIC2wEMRt11YtRQKUhcqVcsiBKgXtldAWqAXiQrBA0KeBxxV23POXDx3jycz8Yzz+yEaJxPPOec7/3/O+fz9//94qdqkRZERTxanFm6cpyrFqTYnMULp5lylUp6tlG6mBYHlyfuDs/kD+H2Trx6hKrOlBYqq8I02U5jJlajCDN1gqEJloVygCkKbrRXnKmXq0HxxTmAZUZqu8itLtFTkOelwqYyfUKerzGKuVpvlxMWb+Wa9RVePoLc8t4hvEhfz5B8W5xhhheYYTpqhhSOMcGWFabSbtHCVJNULHL3CaA0qtQS+zjaZJyleWmaEU9QyfzsjPEytsFWBlw8uszWmJKy1lnlOlKfptsRXmBbNCvKUyDSb023uiBxFEw/iJ6HbWk1GYuTSCsuxK3TryaJ4W5sWmE5BEui1TnGJF2qM0MmtpXJHU6SpBXrtRraxLHUO4jv2N9ljx2ih1imxXJ3fTwudokDX2La4K18XhZMFcZlflXNHM58voBFoylSVb/LC8TR6oY8siOwx5jP5JVqgWvwqI0wv0Q1xlpttMZwyELlqlWlJcklQmv3LQkPgVws1fhXd06TXGGGGb4sMHk25vIwa1cQNe0R5aO9Rn1ydokg3fqg8prjM0E1pudxiJOWKwsPLl2t4bqDhoilxleUapSotSqhtRYmXmBWxSC+JvLCUb9Ctnbm1yU/weCiNmKeFBiPJs3h05shv0BisMBpq5SrPnSADmPkpJUprTYaiJTSzSe8ze5XW4kFQ21VAl+KT6lNPj5f4ttRkOaZTrrECU5VYnqME3M9pBZsZvsYUq21R4lfULq9n//Nl8rJfpCmxyUvi8fS27TtKS408uT+VSn0ymVI/7hBqVKrcomv7eQl9ZGoa/wO5Tzx+PL2e/av2ic8/gF8Ppo+j/13P/qNOXuvZ17Rf65fo7+l0r1Hk9g//gF9/TJck5qjUFpjDn+vNamU4EQBkFBcXylcekmipLaLJpc6t1AGlrXrz0wX8OZ0iavY830qVyTgYBkadEatsTVrOnFcm81QdGQru7e4CvqoodlOslL9x0/wtt1w1P19EeOBx3j3VwI9FRtRB8PEt8XuP+BjofIsXU70b/3T6pg++v/e0/YLcmKmVcQfyunGok+03QcBXx9Zw8Z4CTtoDcduIBkTGMHMIJrI3Jp0IMHHvvwWTN3Zf13r0jd2Giz9jRG760BkTzR/0TFIeAJUfZDI3pFLb17PvvPMuHt/udWfOnDUh0s3uXThswGTbFIs8xyHscptMXSrgdx0dlokeLPvbaLzxOjBVnqcmD08aMNCcsQne9ex9Y2P7cBuy5dd+v5596d57H7pw4YJiRDJCwoaVBqKC1nj6i5pf7yE2RhA7fI2v1Skn3M4b1yIV1cwVVljv1NBCjf1a6o7vmiHsZj/7s/vRH/BIEsiK+u3d7PgDD65nX73//jOoo86A9hx+IDtT3dt69rzqzIZhX/58HkJsQAO7yMPA7B23GNZzx/5Vemrs2+vZVzTDektdFZxx0BfiQDjoK9J72hqk/sZiXV9a+LrRuiwm8eabbyIbuNDNNv77vv4u7cfcNBvbLGh2eUDjPhYWiH6nLUOqy9N/4wyRsnHy2IwUqrwoaXsutMC//fY7eJanLRjkU9uMGBj3GTaA/Yy92ay6WerlV9DiqQKij+inFc9Wxm3U+6TvWfp7OwWgjTg4BXHNzU24IpjqXv/RRx9bDAoN57lz595F85EYkrtDUzeQpyc25M7e1y60rZwZwgMLFRcIixLxXx0TKN3r70BuW/npa/HCfdCMUnMbZM+oehsNXXe3ZOuAZe6/eMklaPXb1s1+6sd36++0EbVOBnxMIdbsZpWWNbGA2y/3jBlNHIfVTXcNFjMjB4/TE6iPXIOp+Yevmx277yfqj70/f8hjJTICZgYq2/roY/IDt8Mytu/bxvYDZ7/yN+L6v2O4+PvZexavkF9Sx9fPFNBnrwp1Zp82XCoSZKBtSOX5er1jtdkVmuXkPg714h4uPdysyJAjYoD1yenINEL7hD2ursyp45bJ8pY2mfTV6DFl5+Ds3qbVMz/DteU5fNgm5ENe2ZXLCOoG84y+Ndd7sMfAORQxHcPUZOXovW96lUZDWmQFtHRNNfnVvNZwvWH6vgWd+neU8Ujl+TYnyaqtb2BFyB0dT9fy6KE7S1X8kTmpWOUFjtERJFyHMrlya9emXyytKmzSU3oXtTsNHfTuheVJtv7gNn0TP+x53LDt+mhtoJs6DJlxZdCvLmNqDCEpMSdya5ejuebEzVgZGe3sZeBsiKs0czPAnETDnGindG5A57ATmJPImZMwMdk85mSg9VNtRMoLBQeuRB4QCDtt4mItPiiSDKeAFM65zjgGbkuoCkBqy1IdQQ1ix6gxHcmGw8s/DZfd6PS4xcsffsTTBELmNRBoNk5jtwJCX05D3VaZvdNdBkbDAQoTW+FuH2n9FNh/h6+eAvvs8DUCI9DWzR+B4Y6Uu6GEQVc4rRnqKcIHvZC5Sz8C4wd2nPgFX5RtP25Ed2j6+f05L8ACExZelII7XGl38uLiu+9Rf+DvBDaBwPDnPa1cRsqByuh4URmaAwUmI9p1x916wicyMJuwradl0M7Z1FK7Xhd/4UFhoCHGZ0LllI/O7Tu1Xea16S8UxCNs644DPNdcm2FFEY1px3SAd+i6JsG4lLqtzYjS4+pMO8I2m4/pIgpCD+D99EQqfeFlcv9YSUTnfvSEbYUmz0su976u3FtcJqqdX3szMwV6ZYWXLfyMNgUCczNOfT6awuRG5lULGWKgW/Jol4b2+JPPTqnCHfGkpjV6AtiLWLEXLj5AcRRoOmvOQPMZwF5E76W9MJEjxATYi+DshXnp1PcoLmA47T6BvQhkEBt1UsBexAoOYC8GYi+0w62VrtC/4XXiNvp5J4QXQhHYizDZC5ev3HVxBN4IW4mKvouHQmUAe5Eg9sKFr9DngYm46DcTFEqjt4UYcfYiynVniOxFGKyFa+9UPsDEauisxcYUH50IWAVfWo7JH0E8C/AaQXgN2eorzgfxFRDPEimvETomEM8SejyLRfNo2qhsVOg25qz4BVLEjzVZPZwBHIhe2azolUihiW/0ioEhueqpX1kjVy499Uz/yBW86wkStkJOfnPn/uIauqIPeXCmJLBO2cCmeESuREenRBjN4h4akZRYlr6MR3/KxroA+udsjOubOhEhnsVPPEs/Os0cygI8yubtHOITz6IxFwnWT0QpK4FcKgb0B8ilomTAAR1LvPie6IgYJ72hRVnYd9G3f7lp88EjyPdER8SYMJE3C5PE6lhCoE6sQ2NBwFt7bZeSEsTsB1o7jTtSlE34VEqIzmmHf0MYER1LdPTJcNaMBB9Jwj8qhAjBRQNAEFNBRK9PoYVfeIU+dayiFjzk5EyuHLXty4nt4B0d47B1REfRsWL9Akn6xGLh45afMCxnTix2cr3wmVy73s8tINE7+M2F11YdoDGp4132bUC/3ZhVxxJfQsF4frdQAb0Dv5EMIlwAnqWEKDBSAeFzE3Hjp9YmnyUElIGQslBVCn+F+hlXHY6dDLRrcQzcIRAuMSdcLJlnfe/cdgPhEjnhEiEmSRbYKFiEnH7VBwsT8Ftqt/RlY+bEi1e47A7cFETA3wzM31gzyUVxTB09yc2mcjmBIdoFZE5YZE5gDPZsApsTsvrCgb0Jlv3Ti7OR7aqW+JM2WyJRr6/krX2z63pyLh5C27DyAm+IxNm0fNiWzg+YTtquPoxwy+ab28FKHrv80DHzt1Vg4x2wYoxRUVyIEsFiDoPROYuE5ZfFOWMNHIi20DlwITtJLlpXsU5PpaNJcdzFOj2VjunejcWIESLL2T04p7tRYspIjJhWgwlqL0HtJYhVg9pLWyRWDWovxYdKg9pLoxe9BrWXYkulQe0lqL0EtZeipXQi4liskwFqL8UgVg1qL8V1nxCfWLWkcWNQewmivhLCnEDtpfgyJ1B7KR7Zi6H20pC3MFB7aSTggOzFUHtpFAOJoPYSZC+G2kvxXXeg9hLUXrLlDqrwjTbjnqeGWJJZUwKMBdRb2oKMBdRbSh5jAfWWhmQQUG8J6i1tXcYC6i0lhLGAekvAWCS83lL3uhvOnPXchYW01gyeur5nNAlhKcJgJxxrKfVlJ4iy4+n+cUSOxMJg3AFRWhBpht7PfnWhiIbDGLu1L7xwFQeCQd+PQbjKqFEYUFopARQGlFZShzzG4SpDK60E4SpQbCmB4SojX2zJ5vlM9Eg3e+s//93NfvWF36Y2M1ylm/3W+v+QU9t+5/FBai6ZIIpB0aUhhqy8dNllyrpAnKf6DsJVbEloNqm0kv/9hVe4Sjd7zakTSQ9YSVRxJZKAQT1+oon7wsQE3vqZQFnPvn7q5K3IuvxtEmK0/GTGYxOhsvFqSl9RR29PuIqI8TTlUxNxbfppu1bkUbP+w0Eh4nQHJEMxgD1AMpTiFJk9UD0pCZQOqFISQOmAKgVUKfoaCqoUUKWMAhygSgFVCqhSQJXiCBeoUqB6dUTrDihUtpRCBRKqbiU6AxQqCaAzQKGif5MEChVQqIBCBRQq8VeoxKV4x0AJVUGdAglVQaECChUgUMJcjuKTUhUEKyBYCUGwMiewCAAQrMSL4dGdVQSpLEGwEmxdiTK9KAhWIPFr4iiZKJ0UCFZiBQcIVqJI/GrIN6DX7HIFQsUQBCth0ip9E78SQiOapBAgWImPYEVnVlzzl5okK7oDhcSv0a47QxSsjHrJmuEltAWBC9AfIdEf5+21TkHgMmT64/zgbh4ELlAxeKsLXPz6PEe4QOASfcXgiKABgUvEFYONX/maaZag7s1MxYDAJYkCFyOzE8huoWJwYHnLQGyLyWqBbol2MRolecvwK9REWLgH9C7B9C6FGbrhUTQI1C7DoHsgPUv86B5Iz5I8tQukZxmSQUB6FkjPsnXVLpCeJSFqF0jPAmoXSM8S33Vn66ZnGWGdDahdgP6AdC4jSn9AOhf9i8TYql0gnUti2BRI5xIDtQukc4mj2gXSuYDaJVHpXEDtAslcYr5PALULqF1GWu3yfw=="
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

-- Holding a secret value is fine; testing one throws. This client can say which is which, so
-- ask before comparing anything that came out of an aura.
local function readable(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return true
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
        autoRepair = false,
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
DEFAULTS.training = { hideKnown = true, fromMyLevel = true, showCost = true }

DEFAULTS.dungeons = { pick = 0, blueOnly = false, showChance = true, quests = true }

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
local changed, placeMini, useProfile, bf, mg, hn, wl, we, tr, lt, mc, seedFromBaked -- below

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
            f.segWidth = iw
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
ns.FADE_TIME = 0.2
local faded = {} -- frame -> alpha we set

local hoverTicker = CreateFrame("Frame")
ns.hoverTicker = hoverTicker
local function hoverTick(_, elapsed)
    local editing = EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
    local step = math.min(elapsed / ns.FADE_TIME, 1)
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

function hn.refresh()
    if not db then return end
    local o = db.hunter
    hn.panel:ClearAllPoints()
    hn.panel:SetPoint("CENTER", UIParent, "CENTER", o.x, o.y)
    hn.panel:EnableMouse(not o.locked)
    if not o.show or class ~= "HUNTER" then
        hn.panel:Hide()
        return
    end
    hn.panel:Show()
    local flags = o.outline and "OUTLINE" or ""
    local step, n = o.size + o.gap, 0
    local id, count, tex = hn.ammo()
    local happy = hn.happiness()
    for _, what in ipairs({ "ammo", "pet" }) do
        local show, icon, text, coords, atlas = false, nil, nil, nil, nil
        if what == "ammo" and o.ammo and id then
            show, icon, text = true, tex or 132382, o.showCount and count or nil
        elseif what == "pet" and o.pet and happy and UnitExists("pet") then
            show = true
            local look = hn.happyLook()
            if look and look.atlas then
                atlas = look.atlas
            elseif look and look.tex then
                icon, coords = look.tex, look.coords
            else -- the old file, cut into three faces side by side
                icon = hn.happyArt
                coords = { (happy - 1) * 0.1875, happy * 0.1875, 0, 0.359375 }
            end
        end
        if show then
            n = n + 1
            local e = hn.entry(n)
            e:SetSize(o.size, o.size)
            e:ClearAllPoints()
            if o.grow == "down" then
                e:SetPoint("TOPLEFT", hn.panel, "TOPLEFT", 0, -(n - 1) * step)
            else
                e:SetPoint("TOPLEFT", hn.panel, "TOPLEFT", (n - 1) * step, 0)
            end
            e.icon:SetTexture(icon)
            ns.iconCorners(e.icon, e.mask, o.radius, coords)
            if atlas then e.icon:SetAtlas(atlas) end -- an atlas brings its own coordinates
            if not e.text:SetFont(o.font, o.fontSize, flags) then
                e.text:SetFont(FONTS[1][2], o.fontSize, flags)
            end
            e.text:ClearAllPoints()
            local at = o.countAt == "center" and "CENTER" or "BOTTOMRIGHT"
            e.text:SetPoint(at, e, at, 0, 0)
            e.text:SetText(text or "")
            e.text:SetShown(text ~= nil)
            if text and count <= o.low then
                e.text:SetTextColor(unpack(o.lowColor))
            else
                e.text:SetTextColor(unpack(o.color))
            end
            e:Show()
        end
    end
    for i = n + 1, #hn.entries do hn.entries[i]:Hide() end
    hn.panel:SetSize(o.grow == "down" and o.size or math.max(n * step - o.gap, o.size),
        o.grow == "down" and math.max(n * step - o.gap, o.size) or o.size)
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
-- Training: what the class trainer still has for you, level by level. The spell tables live
-- in Data/Training.lua and come from What's Training? (MIT); everything here reads them back.

tr = {}
ns.tr = tr

function tr.known(id)
    local ok, yes = pcall(function()
        if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
        if IsSpellKnown then return IsSpellKnown(id) end
        return IsPlayerSpell and IsPlayerSpell(id)
    end)
    return ok and yes == true
end

-- Name and icon, whichever way this build hands them over.
function tr.spellInfo(id)
    tr.cache = tr.cache or {}
    local hit = tr.cache[id]
    if hit then return hit[1], hit[2] end
    local ok, name, icon = pcall(function()
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        if type(info) == "table" then return info.name, info.iconID end
        if GetSpellInfo then return (GetSpellInfo(id)), select(3, GetSpellInfo(id)) end
    end)
    if not ok or type(name) ~= "string" then name, icon = "Spell " .. id, nil end
    if type(icon) ~= "number" and type(icon) ~= "string" then
        local ok2, tex = pcall(function() return C_Spell.GetSpellTexture(id) end)
        icon = (ok2 and tex) or 134400
    end
    tr.cache[id] = { name, icon }
    return name, icon
end

function tr.forMe(sp)
    if sp.faction and sp.faction ~= UnitFactionGroup("player") then return false end
    if sp.race and sp.race ~= select(3, UnitRace("player")) then return false end
    return true
end

-- A spell you have the level for is only really trainable once the rank below it is yours.
function tr.trainable(sp)
    for _, id in ipairs(sp.requiredIds or {}) do
        if not tr.known(id) then return false end
    end
    return true
end

-- One flat list to draw: a header for each level, then that level's spells.
--
-- A level you have passed is skipped only when there is nothing left to learn there. Walk
-- past a trainer for ten levels and those spells are exactly the ones you want to see.
function tr.list()
    local out, data = {}, ns.training and ns.training[class]
    if not data or not db then return out end
    local o, lvl = db.training, UnitLevel("player") or 1
    local levels = {}
    for L in pairs(data) do levels[#levels + 1] = L end
    table.sort(levels)
    for _, L in ipairs(levels) do
        local spells, missed = {}, false
        for _, sp in ipairs(data[L]) do
            local known = tr.known(sp.id)
            if not known and L <= lvl then missed = true end
            if tr.forMe(sp) and not (o.hideKnown and known) then
                spells[#spells + 1] = { spell = sp, level = L, reached = L <= lvl, known = known,
                    trainable = L <= lvl and not known and tr.trainable(sp) }
            end
        end
        if #spells > 0 and (missed or not (o.fromMyLevel and L < lvl)) then
            out[#out + 1] = { level = L, reached = L <= lvl, missed = missed and L < lvl }
            for _, row in ipairs(spells) do out[#out + 1] = row end
        end
    end
    return out
end

------------------------------------------------------------------------------------------
-- Macros. Keep as many as you like here -- they live in the saved variables, account-wide, one
-- shelf per class, and switching profile does not touch them. The game itself has room for
-- only 120 macros plus 18 on the character, so one is written into a real slot at the moment
-- you ask for it: dragging it onto a bar, or pressing the button.

mc = {}
ns.mc = mc
mc.DEFAULT_ICON = 134400 -- the question mark, by file id: a bare name draws nothing

-- What to hand SetTexture. An icon can arrive as a file id, as a file id written down as text,
-- or as a bare name like INV_Misc_QuestionMark, and only the first of those draws by itself.
function mc.texture(icon)
    if type(icon) == "number" then return icon end
    if type(icon) ~= "string" or icon == "" then return mc.DEFAULT_ICON end
    local id = tonumber(icon)
    if id then return id end
    if icon:find("\\") or icon:find("/") then return icon end
    return "Interface\\Icons\\" .. icon
end

-- The icon to draw for a macro: the one chosen by hand, then the one the game would give it
-- itself, and a question mark when neither says anything.
function mc.iconOf(entry)
    if not entry then return mc.DEFAULT_ICON end
    return mc.texture(entry.icon or mc.guessIcon(entry.body) or mc.DEFAULT_ICON)
end

-- What a shelf is called on screen.
function mc.shelfName(key)
    for _, e in ipairs(ns.MACRO_SHELVES) do if e[1] == key then return e[2] end end
    return "General"
end

function mc.shelf(classToken)
    local key = classToken or "GENERAL"
    store.macros = store.macros or {}
    store.macros[key] = store.macros[key] or {}
    return store.macros[key]
end

-- The icon the game itself would put on this macro: what its #showtooltip names, else the first
-- thing it casts or uses. This is the fallback whenever no icon has been chosen by hand.
function mc.guessIcon(body)
    local function texture(text)
        if not text then return nil end
        text = text:gsub("^%s*reset=%S+%s*", "")   -- a castsequence's reset clause
        text = text:gsub("%[[^%]]*%]", "")         -- any [conditional]
        text = text:match("^[^;,]+") or text       -- first of a sequence or a fallback list
        text = text:gsub("!", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" or text:lower() == "null" or text:lower():find("^item:") then return nil end
        local ok, tex = pcall(function()
            return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(text)
        end)
        return (ok and tex) or nil
    end
    for line in (body or ""):gmatch("[^\r\n]+") do
        local shown = line:match("^%s*#show%a*%s+(.+)$")
        if shown then
            local tex = texture(shown)
            if tex then return tex end
        end
    end
    for line in (body or ""):gmatch("[^\r\n]+") do
        local verb, rest = line:match("^%s*/(%a+)%s+(.+)$")
        if rest and (verb == "cast" or verb == "use" or verb == "castsequence") then
            local tex = texture(rest)
            if tex then return tex end
        end
    end
    return nil
end

-- Every icon the game will put on a macro. Which call gives them has moved between builds, so
-- each is tried in turn; failing all of them, the icons of the spells you know still make a
-- usable list. Gathered once and kept.
function mc.icons()
    if mc.iconCache then return mc.iconCache end
    local out = {}
    pcall(function()
        local n = C_MacroFrame and C_MacroFrame.GetNumMacroIcons and C_MacroFrame.GetNumMacroIcons()
        for i = 1, (n or 0) do
            out[#out + 1] = C_MacroFrame.GetMacroIconInfo(i)
        end
    end)
    if #out == 0 then
        pcall(function()
            local n = GetNumMacroIcons and GetNumMacroIcons()
            for i = 1, (n or 0) do out[#out + 1] = GetMacroIconInfo(i) end
        end)
    end
    if #out == 0 then
        pcall(function()
            local t = {}
            GetMacroIcons(t)
            for _, v in ipairs(t) do out[#out + 1] = v end
        end)
    end
    if #out == 0 then -- nothing on offer: the spells you know are better than one question mark
        pcall(function()
            for i = 1, 400 do
                local name = C_SpellBook and C_SpellBook.GetSpellBookItemName
                    and C_SpellBook.GetSpellBookItemName(i, 0)
                if not name then break end
                local tex = C_Spell.GetSpellTexture(name)
                if tex then out[#out + 1] = tex end
            end
        end)
    end
    if #out == 0 then out[1] = mc.DEFAULT_ICON end
    mc.iconCache = out
    return out
end

-- What an icon is called, where the game says so at all -- fileIDs are just numbers.
function mc.iconName(icon)
    if type(icon) ~= "string" then return nil end
    return icon:match("([^\\/]+)$")
end

-- The ones matching what you typed. No text, no filtering: it is the whole list.
function mc.iconsLike(text)
    local all = mc.icons()
    if not text or text == "" then return all end
    local want, out = text:lower(), {}
    for _, icon in ipairs(all) do
        local name = mc.iconName(icon)
        if name and name:lower():find(want, 1, true) then out[#out + 1] = icon end
    end
    return out
end

-- Hand one to the game. It remembers which slot it was given and keeps it across edits, so
-- editing never doubles up. A name the game already has -- one of yours from before, or another
-- macro on this shelf -- is left alone: this one takes a numbered name beside it rather than
-- writing over somebody else's work. Blizzard's own rule: nothing about macros in combat.
function mc.toGame(entry)
    if not entry then return nil, "nothing to save" end
    if InCombatLockdown() then return nil, "not while you are fighting" end
    local want = (entry.name or "Macro"):sub(1, 16)
    local icon = mc.iconOf(entry)
    local body = entry.body or ""
    local function slotOf(name)
        local at = select(2, pcall(GetMacroIndexByName, name))
        return type(at) == "number" and at > 0 and at or nil
    end
    local mine = entry.slot and slotOf(entry.slot)
    if mine then
        local taken = want ~= entry.slot and slotOf(want)
        if not taken and pcall(EditMacro, mine, want, icon, body) then
            entry.slot = want
            return mine
        end
        if pcall(EditMacro, mine, entry.slot, icon, body) then return mine end
    end
    local name, n = want, 1
    while slotOf(name) and n < 20 do
        n = n + 1
        name = want:sub(1, 13) .. " " .. n
    end
    -- the shared list first, then this character's own eighteen when that one is full
    for _, perCharacter in ipairs({ false, true }) do
        local ok, made = pcall(CreateMacro, name, icon, body, perCharacter)
        if ok and type(made) == "number" then
            entry.slot, entry.perChar = name, perCharacter
            return made
        end
    end
    local shared, mine = 0, 0
    pcall(function() shared, mine = GetNumMacros() end)
    return nil, ("no room left -- %d of the 120 shared slots and %d of this character's 18 are "
        .. "taken. Delete one in the game's macro list and try again."):format(shared or 0, mine or 0)
end

-- Open the game's own macro window. Dragging out of that one is Blizzard's code doing the
-- picking up, which is the one route that cannot upset anything.
function mc.openGameList()
    if InCombatLockdown() then return false end
    local ok = pcall(function()
        if not MacroFrame then UIParentLoadAddOn("Blizzard_MacroUI") end
        if MacroFrame and MacroFrame:IsShown() then HideUIPanel(MacroFrame)
        elseif MacroFrame then ShowUIPanel(MacroFrame) end
    end)
    return ok
end

-- Put it on the cursor so it can be dropped on an action bar.
function mc.pickUp(entry)
    local index, why = mc.toGame(entry)
    if not index then return false, why end
    local ok = pcall(PickupMacro, index)
    return ok, ok and nil or "the game would not pick it up"
end

------------------------------------------------------------------------------------------
-- Dungeons: who drops what, and which quests the place has. The tables live in Data/Loot.lua,
-- read off Wowhead's Forever section by tools/fetch_loot.py -- an addon cannot fetch anything
-- itself, so the data is shipped with it.

lt = {}
ns.lt = lt
lt.quality = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 },
    { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }

-- The tables are a separate addon, so that they can be switched off in the addon list. If it
-- is not loaded the panel simply says so.
function lt.all()
    return WolfpackAddonLootData or {}
end

-- The one whose level range you are in, so the page opens somewhere useful.
function lt.forMyLevel()
    local lvl, best = UnitLevel("player") or 1, 1
    for i, d in ipairs(lt.all()) do
        if lvl >= (d.lo or 0) and lvl <= (d.hi or 0) then return i end
        if (d.hi or 0) <= lvl then best = i end
    end
    return best
end

-- Where you stand with one quest. Every call is wrapped: a secret value raises rather than
-- answers, and an unknown quest is better left unclaimed than guessed at.
function lt.questState(qu)
    local id, min, side = qu[1], qu[4], qu[5]
    local ok, done = pcall(function()
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            return C_QuestLog.IsQuestFlaggedCompleted(id)
        end
        return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(id)
    end)
    if ok and done == true then return "done" end
    local inLog = select(2, pcall(function()
        if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
            return C_QuestLog.GetLogIndexForQuestID(id)
        end
    end))
    if type(inLog) == "number" then return "log" end
    if side == 1 or side == 2 then
        if side ~= (UnitFactionGroup("player") == "Alliance" and 1 or 2) then return "faction" end
    end
    if (UnitLevel("player") or 1) < (min or 0) then return "low" end
    return "open"
end

-- Wowhead names the zone, the game numbers it, so the map tree is walked once and indexed by
-- name. Zone maps win over continents and instance floors that happen to share a name.
function lt.mapByName(name)
    if not name then return nil end
    if not lt.maps then
        lt.maps = {}
        pcall(function()
            local queue, seen = { 946, 947, 12, 13, 1414, 1415 }, {}
            while #queue > 0 do
                local id = table.remove(queue)
                if not seen[id] then
                    seen[id] = true
                    local info = C_Map.GetMapInfo(id)
                    if info and info.name and (not lt.maps[info.name] or info.mapType == 3) then
                        lt.maps[info.name] = id
                    end
                    for _, child in ipairs(C_Map.GetMapChildrenInfo(id) or {}) do
                        if child.mapID then queue[#queue + 1] = child.mapID end
                    end
                end
            end
        end)
    end
    return lt.maps[name]
end

-- Open the map where the quest is handed out, and drop the waypoint pin on the spot.
function lt.showOnMap(qu)
    local zone, x, y = qu[7], qu[8], qu[9]
    if not zone or not x or x == 0 or InCombatLockdown() then return false end
    local mapID = lt.mapByName(zone)
    if not mapID then return false end
    pcall(function()
        if C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end
    end)
    pcall(function()
        if not WorldMapFrame:IsShown() then ToggleWorldMap() end
        WorldMapFrame:SetMapID(mapID)
    end)
    return true
end

lt.questLook = {
    done = { "done", 0.5, 0.5, 0.5 },
    log = { "in your log", 1, 0.82, 0 },
    open = { "pick it up", 0.2, 1, 0.2 },
    low = { "too low", 0.8, 0.4, 0.4 },
    faction = { "other side", 0.6, 0.6, 0.6 },
}

-- One flat list for the chosen dungeon: a boss, then its items, then the quests.
function lt.rows(dungeon)
    local out, o = {}, db and db.dungeons or {}
    if not dungeon then return out end
    for _, b in ipairs(dungeon.bosses or {}) do
        local items = {}
        for _, it in ipairs(b.items or {}) do
            if not (o.blueOnly and it[3] < 3) then items[#items + 1] = it end
        end
        if #items > 0 then
            out[#out + 1] = { boss = b.name }
            for _, it in ipairs(items) do out[#out + 1] = { item = it } end
        end
    end
    if o.quests and #(dungeon.quests or {}) > 0 then
        out[#out + 1] = { boss = "Quests for this place" }
        for _, qu in ipairs(dungeon.quests) do out[#out + 1] = { quest = qu } end
    end
    return out
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
local cfg, selected, mode, section, sub = nil, "health", "regular", "combat", "bars"
-- Classes the addon has settings of its own for: { section key, label, class token }
ns.CLASS_SECTIONS = { { "hunter", "Hunter", "HUNTER" }, { "mage", "Mage", "MAGE" },
    { "rogue", "Rogue", "ROGUE" }, { "shaman", "Shaman", "SHAMAN" },
    { "warlock", "Warlock", "WARLOCK" } }
-- Macro shelves: one per class, plus the ones that suit anybody.
ns.MACRO_SHELVES = { { "GENERAL", "General" }, { "DRUID", "Druid" }, { "HUNTER", "Hunter" },
    { "MAGE", "Mage" }, { "PALADIN", "Paladin" }, { "PRIEST", "Priest" },
    { "ROGUE", "Rogue" }, { "SHAMAN", "Shaman" }, { "WARLOCK", "Warlock" },
    { "WARRIOR", "Warrior" } }
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
    ns.boxesOn = ns.boxesOn or {}
    ns.boxesOn[parent] = (ns.boxesOn[parent] or 0) + 1
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

ns.SLIDER_BACKDROP = {
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
    s:SetBackdrop(ns.SLIDER_BACKDROP)
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
    local data = { name = store.chars[charKey], profile = db, combatFont = db.other.combatFont }
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
    return name, type(data.editMode) == "string" and data.editMode or nil
end
ns.exportString, ns.editModeString, ns.importString = exportString, editModeString, importString
ns.seedFromBaked = function() return seedFromBaked() end
ns.useProfile = useProfile

StaticPopupDialogs.WOLFPACKADDON_DELETE = {
    text = "Delete Wolfpack Addon profile \"%s\"?",
    button1 = YES, button2 = NO,
    OnAccept = function(_, name) deleteProfile(name) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local openStops -- the gradient points dialog, defined below

local ioFrame

function ns.textArea(parent, y, h) -- on the namespace: this chunk is at Lua's 200-local ceiling
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
        f.all = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        f.all:SetSize(24, 24)
        f.all:SetPoint("TOPLEFT", 300, -26)
        label(f.all, "All profiles in one string"):SetPoint("LEFT", f.all, "RIGHT", 2, 1)
        f.all:SetScript("OnClick", function(self)
            f.area1.box:SetText(exportString(self:GetChecked()))
            f.area1.box:SetFocus()
        end)
        f.area1 = ns.textArea(f, -50, 110)
        f.label2 = label(f, "2. WoW UI layout (Edit Mode). Import it in Edit Mode: Layout dropdown, Import.",
            "GameFontNormal")
        f.label2:SetPoint("TOPLEFT", 16, -172)
        f.area2 = ns.textArea(f, -190, 110)
        f.note = label(f, "", "GameFontHighlightSmall")
        f.note:SetPoint("TOPLEFT", 16, -312)
        f.note:SetWidth(505)
        f.note:SetJustifyH("LEFT")
        f.import = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.import:SetSize(100, 22)
        f.import:SetPoint("BOTTOMRIGHT", -16, 14)
        f.import:SetText("Import")
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
        ioFrame = f
    end
    local export = mode == "export"
    f.title:SetText(export and "Export" or "Import profile")
    f.import:SetShown(not export)
    f.all:SetShown(export)
    f.area2:SetShown(export)
    f.label2:SetShown(export)
    if export then
        f.label1:SetText("1. Addon profile. Import it here with Import (profile row).")
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

    -- Sidebar: everything that is about the screen first, then a class shelf of its own.
    local SIDEBAR = { { "combat", "Combat Display", "regular" }, { "nameplates", "Nameplates", "nameplate" },
        { "buffs", "Buffs", "regular" }, { "training", "Training", "regular" },
        { "dungeons", "Dungeons", "regular" }, { "other", "Other", "regular" } }
    local y = -104
    for _, e in ipairs(SIDEBAR) do
        local b = button(cfg, e[2], 118, 12, y, function()
            section, mode = e[1], e[3]
            changed()
        end)
        onRefresh(function() if section == e[1] then b:LockHighlight() else b:UnlockHighlight() end end)
        y = y - 26
    end
    y = y - 14
    local shelfLine = cfg:CreateTexture(nil, "ARTWORK")
    shelfLine:SetColorTexture(1, 1, 1, 0.15)
    shelfLine:SetPoint("TOPLEFT", 12, y + 8)
    shelfLine:SetSize(118, 1)
    local shelf = label(cfg, "Classes", "GameFontDisableSmall")
    shelf:SetPoint("TOPLEFT", 14, y)
    y = y - 16
    for _, e in ipairs(ns.CLASS_SECTIONS) do
        local b = button(cfg, e[2], 118, 12, y, function()
            section, mode = e[1], "regular"
            changed()
        end)
        onRefresh(function()
            if section == e[1] then b:LockHighlight() else b:UnlockHighlight() end
            local on = e[3] == class -- your own class reads brighter than the rest
            b:GetFontString():SetTextColor(on and 1 or 0.65, on and 0.82 or 0.65, on and 0 or 0.65)
        end)
        y = y - 26
    end

    y = y - 14
    local macroLine = cfg:CreateTexture(nil, "ARTWORK")
    macroLine:SetColorTexture(1, 1, 1, 0.15)
    macroLine:SetPoint("TOPLEFT", 12, y + 8)
    macroLine:SetSize(118, 1)
    local macroHead = label(cfg, "Macros", "GameFontDisableSmall")
    macroHead:SetPoint("TOPLEFT", 14, y)
    y = y - 16
    for _, e in ipairs(ns.MACRO_SHELVES) do
        local b = button(cfg, e[2], 108, 22, y, function()
            section, mode, ns.macroClass = "macros", "regular", e[1]
            ns.macro.picked = 1
            changed()
        end)
        onRefresh(function()
            local on = section == "macros" and ns.macroClass == e[1]
            if on then b:LockHighlight() else b:UnlockHighlight() end
            local mine = e[1] == class or e[1] == "GENERAL"
            b:GetFontString():SetTextColor(mine and 1 or 0.65, mine and 0.82 or 0.65,
                mine and 0 or 0.65)
        end)
        y = y - 24
    end
    ns.sidebarBottom = y
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
    local buffPage = CreateFrame("Frame", nil, cfg)
    buffPage:SetAllPoints(barsPage)
    local magePage = CreateFrame("Frame", nil, cfg)
    magePage:SetAllPoints(barsPage)
    local hunterPage = CreateFrame("Frame", nil, cfg)
    hunterPage:SetAllPoints(barsPage)
    local lockPage = CreateFrame("Frame", nil, cfg)
    lockPage:SetAllPoints(barsPage)
    local roguePage = CreateFrame("Frame", nil, cfg)
    roguePage:SetAllPoints(barsPage)
    local shamanPage = CreateFrame("Frame", nil, cfg)
    shamanPage:SetAllPoints(barsPage)
    local trainPage = CreateFrame("Frame", nil, cfg)
    trainPage:SetAllPoints(barsPage)
    local dungPage = CreateFrame("Frame", nil, cfg)
    dungPage:SetAllPoints(barsPage)
    ns.pages = { combat = barsPage, nameplates = questPage, buffs = buffPage, mage = magePage,
        hunter = hunterPage, warlock = lockPage, rogue = roguePage, shaman = shamanPage,
        training = trainPage, dungeons = dungPage, other = otherPage }

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
            or section == "buffs" and "Buff check"
            or section == "mage" and "Mage: food and water"
            or section == "hunter" and "Hunter: ammo and pet"
            or section == "warlock" and "Warlock: soul shards"
            or section == "rogue" and "Rogue: weapon poisons"
            or section == "shaman" and "Shaman: weapon imbues"
            or section == "training" and "What your trainer still has"
            or section == "dungeons" and "Dungeons: loot and quests"
            or section == "macros" and ("Macros: " .. mc.shelfName(ns.macroClass))
            or "Combat Display")
        for _, t in ipairs(tabs) do t:SetShown(np) end
        ns.macroPage:SetShown(section == "macros")
        barsPage:SetShown(section == "combat" or (np and sub == "bars"))
        questPage:SetShown(np and sub == "quest")
        otherPage:SetShown(section == "other")
        buffPage:SetShown(section == "buffs")
        magePage:SetShown(section == "mage")
        hunterPage:SetShown(section == "hunter")
        lockPage:SetShown(section == "warlock")
        roguePage:SetShown(section == "rogue")
        shamanPage:SetShown(section == "shaman")
        trainPage:SetShown(section == "training")
        dungPage:SetShown(section == "dungeons")
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
        if selected == "range" then
            onlyNote:SetText("Asks your own spells whether they would reach. The whole bar takes "
                .. "the color of where your target stands, and says so: in melee, in the gap "
                .. "nothing covers, in range, or too far.")
        else
            onlyNote:SetText(selected ~= "totems" and none and "Nothing extra for this one." or "")
        end
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
    check(otherPage, "Auto-repair", merch.x, merch:row(ROW),
        function() return db.other.autoRepair end, function(v) db.other.autoRepair = v end)
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
    -- Hunter page: ammunition and the pet's mood
    ----------------------------------------------------------------------------------
    local H = function() return db.hunter end
    local hset = group(hunterPage, COL[1], TOP, 202, "Ammo and pet")
    check(hunterPage, "Show it", hset.x, hset:row(ROW), function() return H().show end,
        function(v) H().show = v end)
    check(hunterPage, "Ammunition", hset.x, hset:row(ROW), function() return H().ammo end,
        function(v) H().ammo = v end)
    local petTick = check(hunterPage, "Pet happiness", hset.x, hset:row(ROW),
        function() return H().pet end, function(v) H().pet = v end)
    local petNote = label(hunterPage, "", "GameFontDisableSmall")
    petNote:SetPoint("TOPLEFT", hset.x + 24, hset:row(14))
    onRefresh(function()
        local has = GetPetHappiness ~= nil or UnitPetHappiness ~= nil or PetFrameHappiness ~= nil
        petTick:SetEnabled(has)
        petNote:SetText(has and "" or "|cffff8888no happiness in this client|r")
    end)
    local hlk = button(hunterPage, "", 186, hset.x, hset:row(BUTTON), function()
        H().locked = not H().locked
        changed()
    end)
    onRefresh(function() hlk:SetText(H().locked and "Locked (click to unlock)" or "Unlocked - drag it") end)
    slider(hunterPage, "X (left / right)", hset.x, hset:row(SLIDER), -1200, 1200,
        function() return H().x end, function(v) H().x = v end)
    slider(hunterPage, "Y (down / up)", hset.x, hset:row(SLIDER), -800, 800,
        function() return H().y end, function(v) H().y = v end)
    local hNote = label(hunterPage, "The ammo in your ammo slot, with how many you carry, and the "
        .. "face your pet is pulling -- if this client still has pet happiness at all. Hunters "
        .. "only.", "GameFontDisableSmall")
    hNote:SetPoint("TOPLEFT", hset.x, hset:row(40))
    hNote:SetWidth(182)
    hNote:SetJustifyH("LEFT")
    hset:close()

    local hlook = group(hunterPage, COL[2], TOP, 202, "Icons")
    slider(hunterPage, "Icon size", hlook.x, hlook:row(SLIDER), 12, 80, function() return H().size end,
        function(v) H().size = v end)
    slider(hunterPage, "Gap", hlook.x, hlook:row(SLIDER), 0, 30, function() return H().gap end,
        function(v) H().gap = v end)
    dropdown(hunterPage, "Corner radius", hlook.x, hlook:row(DROP), { { "None (square)", 0 },
        { "Slightly rounded", 12 }, { "Rounded", 25 }, { "Circle", 50 } },
        function() return ns.ICON_MASKS[H().radius] and H().radius or 0 end,
        function(v) H().radius = v end, textPreview)
    dropdown(hunterPage, "Side by side or stacked", hlook.x, hlook:row(DROP),
        { { "Side by side", "right" }, { "Stacked", "down" } },
        function() return H().grow end, function(v) H().grow = v end, textPreview)
    dropdown(hunterPage, "Count sits", hlook.x, hlook:row(DROP), { { "In the corner", "corner" },
        { "In the middle", "center" } }, function() return H().countAt end,
        function(v) H().countAt = v end, textPreview)
    check(hunterPage, "Show the count", hlook.x, hlook:row(ROW), function() return H().showCount end,
        function(v) H().showCount = v end)
    hlook:close()

    local htext = group(hunterPage, COL[3], TOP, 202, "The count")
    dropdown(hunterPage, "Font", htext.x, htext:row(DROP), FONTS, function() return H().font end,
        function(v) H().font = v end, fontPreview)
    slider(hunterPage, "Font size", htext.x, htext:row(SLIDER), 6, 30, function() return H().fontSize end,
        function(v) H().fontSize = v end)
    check(hunterPage, "Outline", htext.x, htext:row(ROW), function() return H().outline end,
        function(v) H().outline = v end)
    swatch(hunterPage, "Color", htext.x, htext:row(SWATCH), function() return H().color end)
    swatch(hunterPage, "Color when low", htext.x, htext:row(SWATCH), function() return H().lowColor end)
    slider(hunterPage, "Low is under", htext.x, htext:row(SLIDER), 1, 2000,
        function() return H().low end, function(v) H().low = v end)
    htext:close()

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
    -- Training page: every spell your trainer has for you, level by level. Read only --
    -- the list is the point, the three boxes only decide how much of it you see.
    ----------------------------------------------------------------------------------
    local T = function() return db.training end
    local tset = group(trainPage, COL[1], TOP, 202, "What to list")
    check(trainPage, "Hide what you already know", tset.x, tset:row(ROW),
        function() return T().hideKnown end, function(v) T().hideKnown = v end)
    check(trainPage, "Hide levels you are done with", tset.x, tset:row(ROW),
        function() return T().fromMyLevel end, function(v) T().fromMyLevel = v end)
    check(trainPage, "Show what it costs", tset.x, tset:row(ROW),
        function() return T().showCost end, function(v) T().showCost = v end)
    local tsetNote = label(trainPage, "Green is trainable right now, white needs the rank below "
        .. "it first, grey is still ahead of you. A level you walked past keeps its place in "
        .. "the list while anything there is unlearned. Spell list from What's Training? (MIT "
        .. "licence); pet abilities are not in it.", "GameFontDisableSmall")
    tsetNote:SetPoint("TOPLEFT", tset.x, tset:row(84))
    tsetNote:SetWidth(182)
    tsetNote:SetJustifyH("LEFT")
    tset:close()

    local trList = CreateFrame("Frame", nil, trainPage)
    trList:SetPoint("TOPLEFT", COL[2], TOP - 4)
    trList:SetSize(600, 560)
    local trBg = trList:CreateTexture(nil, "BACKGROUND")
    trBg:SetAllPoints()
    trBg:SetColorTexture(0, 0, 0, 0.35)
    local trScroll = CreateFrame("ScrollFrame", nil, trList, "UIPanelScrollFrameTemplate")
    trScroll:SetPoint("TOPLEFT", 6, -6)
    trScroll:SetPoint("BOTTOMRIGHT", -28, 6)
    local trChild = CreateFrame("Frame", nil, trScroll)
    trChild:SetSize(560, 10)
    trScroll:SetScrollChild(trChild)
    local trRows = {}
    local function trRow(i)
        local r = trRows[i]
        if not r then
            r = CreateFrame("Frame", nil, trChild)
            r:SetSize(556, 20)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(16, 16)
            r.icon:SetPoint("LEFT", 4, 0)
            r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
            r.name:SetJustifyH("LEFT")
            r.right = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            r.right:SetPoint("RIGHT", -8, 0)
            r.right:SetJustifyH("RIGHT")
            r:EnableMouse(true)
            r:SetScript("OnEnter", function(self)
                if not self.spellID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
                if not ok then
                    GameTooltip:SetText(self.name:GetText() or "")
                    GameTooltip:AddLine("Spell " .. self.spellID, 0.6, 0.6, 0.6)
                end
                if self.note then GameTooltip:AddLine(self.note, 0.2, 1, 0.2, true) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            trRows[i] = r
        end
        return r
    end
    local trEmpty = trChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    trEmpty:SetPoint("TOPLEFT", 8, -8)
    ns.trainRows = trRows
    onRefresh(function()
        if section ~= "training" then return end
        local list = tr.list()
        trEmpty:SetShown(#list == 0)
        trEmpty:SetText(ns.training and ns.training[class]
            and "Nothing left -- your trainer has taught you everything on this list."
            or "No spell list for this class.")
        for i, e in ipairs(list) do
            local r = trRow(i)
            r:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
            r.spellID, r.note = nil, nil
            if e.spell then
                r.spellID = e.spell.id
                r.note = e.known and "You know this one."
                    or e.trainable and ("Your trainer has it now, for " .. ns.money(e.spell.cost))
                    or e.reached and "You need the rank below this one first."
                    or ("Comes at level " .. e.level .. ".")
                local name, icon = tr.spellInfo(e.spell.id)
                r.icon:SetTexture(icon)
                r.icon:SetShown(true)
                r.name:SetText(name)
                if e.known then
                    r.name:SetTextColor(0.5, 0.5, 0.5)
                    r.right:SetText("known")
                    r.right:SetTextColor(0.5, 0.5, 0.5)
                elseif e.trainable then
                    r.name:SetTextColor(0.2, 1, 0.2)
                    r.right:SetText(T().showCost and ns.money(e.spell.cost) or "train it")
                    r.right:SetTextColor(0.2, 1, 0.2)
                elseif e.reached then -- level is there, the rank below it is not
                    r.name:SetTextColor(1, 1, 1)
                    r.right:SetText(T().showCost and ns.money(e.spell.cost) or "needs the rank below")
                    r.right:SetTextColor(0.8, 0.8, 0.8)
                else
                    r.name:SetTextColor(0.65, 0.65, 0.65)
                    r.right:SetText(T().showCost and ns.money(e.spell.cost) or "")
                    r.right:SetTextColor(0.45, 0.45, 0.45)
                end
            else -- a level header
                r.icon:SetShown(false)
                r.name:SetText("Level " .. e.level)
                r.name:SetTextColor(e.reached and 1 or 0.7, e.reached and 0.82 or 0.6, 0)
                r.right:SetText(e.missed and "still to learn" or e.reached and "" or "not yet")
                r.right:SetTextColor(0.45, 0.45, 0.45)
            end
            r:Show()
        end
        for i = #list + 1, #trRows do trRows[i]:Hide() end
        trChild:SetHeight(math.max(#list * 20, 10))
    end)

    ----------------------------------------------------------------------------------
    -- Macros: a shelf per class, as long as you like. The roster of icons on top, whichever
    -- one you clicked underneath it. Nothing reaches the game until you drag it out or press
    -- the button, because the game only has 120 slots and this shelf has none.
    ----------------------------------------------------------------------------------
    local M = { rows = {} }
    ns.macro = M
    M.page = CreateFrame("Frame", nil, cfg)
    M.page:SetAllPoints(barsPage)
    ns.macroPage = M.page
    M.picked = 1
    M.COLS, M.CELL = 15, 48

    ns.macroClass = ns.macroClass or "GENERAL"
    local function shelf() return mc.shelf(ns.macroClass) end
    local function current() return shelf()[M.picked] end

    label(M.page, "Your macros", "GameFontNormal"):SetPoint("TOPLEFT", COL[1] + 6, TOP)
    M.list = CreateFrame("ScrollFrame", nil, M.page, "UIPanelScrollFrameTemplate")
    M.list:SetPoint("TOPLEFT", COL[1] + 8, TOP - 22)
    M.list:SetSize(M.COLS * M.CELL + 4, 200)
    M.listChild = CreateFrame("Frame", nil, M.list)
    M.listChild:SetSize(M.COLS * M.CELL, 10)
    M.list:SetScrollChild(M.listChild)

    function M.row(i)
        local r = M.rows[i]
        if not r then
            r = CreateFrame("Button", nil, M.listChild)
            r:SetSize(42, 42)
            r:SetPoint("TOPLEFT", ((i - 1) % M.COLS) * M.CELL,
                -math.floor((i - 1) / M.COLS) * M.CELL)
            r.tex = r:CreateTexture(nil, "ARTWORK")
            r.tex:SetAllPoints()
            r.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            r.sel = r:CreateTexture(nil, "OVERLAY")
            r.sel:SetPoint("TOPLEFT", -2, 2)
            r.sel:SetPoint("BOTTOMRIGHT", 2, -2)
            r.sel:SetColorTexture(1, 0.82, 0, 0.9)
            r.sel:SetDrawLayer("BACKGROUND")
            r:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            r:SetScript("OnClick", function()
                M.picked = i
                M.picker:Hide()
                changed()
            end)
            r:RegisterForDrag("LeftButton")
            -- drag it straight onto an action bar: the game gets a real macro at that moment
            r:SetScript("OnDragStart", function()
                local ok, why = mc.pickUp(shelf()[i])
                if not ok then print("|cff88ccffWolfpack:|r " .. (why or "no")) end
            end)
            r:SetScript("OnEnter", function(self)
                local e = shelf()[i]
                if not e then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(e.name or "Macro")
                for line in (e.body or ""):gmatch("[^\r\n]+") do
                    GameTooltip:AddLine(line, 0.8, 0.8, 0.8)
                end
                GameTooltip:AddLine("Click to change it, drag it onto an action bar", 0.2, 1, 0.2)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            M.rows[i] = r
        end
        return r
    end

    M.empty = label(M.page, "", "GameFontDisableSmall")
    M.empty:SetPoint("TOPLEFT", COL[1] + 12, TOP - 30)
    M.empty:SetWidth(400)
    M.empty:SetJustifyH("LEFT")

    button(M.page, "New macro", 120, COL[1] + 8, TOP - 230, function()
        local list = shelf()
        list[#list + 1] = { name = "New macro", body = "/cast " }
        M.picked = #list
        changed()
    end)
    button(M.page, "Delete this one", 130, COL[1] + 134, TOP - 230, function()
        local list = shelf()
        table.remove(list, M.picked)
        M.picked = math.max(1, math.min(M.picked, #list))
        changed()
    end)
    M.count = label(M.page, "", "GameFontDisableSmall")
    M.count:SetPoint("TOPLEFT", COL[1] + 276, TOP - 224)

    ----------------------------------------------------------------------------------
    -- Underneath: the one you clicked
    ----------------------------------------------------------------------------------
    M.EDIT = TOP - 268
    label(M.page, "Name", "GameFontNormal"):SetPoint("TOPLEFT", COL[1] + 6, M.EDIT)
    M.name = CreateFrame("EditBox", nil, M.page, "InputBoxTemplate")
    M.name:SetPoint("TOPLEFT", COL[1] + 60, M.EDIT + 4)
    M.name:SetSize(260, 22)
    M.name:SetAutoFocus(false)
    M.name:SetMaxLetters(16) -- the game's own limit on a macro name
    M.name:SetScript("OnEnterPressed", function(self)
        local e = current()
        if e then e.name = self:GetText() end
        self:ClearFocus()
        changed()
    end)
    M.name:SetScript("OnEscapePressed", function(self) self:ClearFocus() changed() end)

    -- the icon sits beside the name and opens the picker
    M.iconBtn = CreateFrame("Button", nil, M.page)
    M.iconBtn:SetPoint("TOPLEFT", COL[1] + 332, M.EDIT + 6)
    M.iconBtn:SetSize(28, 28)
    M.iconBtn.tex = M.iconBtn:CreateTexture(nil, "ARTWORK")
    M.iconBtn.tex:SetAllPoints()
    M.iconBtn.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    M.iconBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    M.iconBtn:SetScript("OnClick", function()
        M.picker:SetShown(not M.picker:IsShown())
        changed()
    end)
    M.iconBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Pick an icon")
        GameTooltip:AddLine("Leave it alone and it takes the icon of the first spell it casts.",
            0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    M.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    label(M.page, "What it does", "GameFontNormal"):SetPoint("TOPLEFT", COL[1] + 6, M.EDIT - 30)
    M.bodyBox = CreateFrame("Frame", nil, M.page)
    M.bodyBox:SetPoint("TOPLEFT", COL[1] + 8, M.EDIT - 50)
    M.bodyBox:SetSize(560, 160)
    local mbg = M.bodyBox:CreateTexture(nil, "BACKGROUND")
    mbg:SetAllPoints()
    mbg:SetColorTexture(0, 0, 0, 0.5)
    M.bodyScroll = CreateFrame("ScrollFrame", nil, M.bodyBox, "UIPanelScrollFrameTemplate")
    M.bodyScroll:SetPoint("TOPLEFT", 6, -6)
    M.bodyScroll:SetPoint("BOTTOMRIGHT", -28, 6)
    M.body = CreateFrame("EditBox", nil, M.bodyScroll)
    M.body:SetMultiLine(true)
    M.body:SetAutoFocus(false)
    M.body:SetMaxLetters(255) -- the game's own limit on a macro body
    M.body:SetFontObject(ChatFontNormal)
    M.body:SetWidth(520)
    M.body:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    M.body:SetScript("OnTextChanged", function(self)
        local e = current()
        if e and self:HasFocus() then e.body = self:GetText() end
    end)
    M.bodyScroll:SetScrollChild(M.body)

    button(M.page, "Put it on my cursor", 160, COL[1] + 8, M.EDIT - 218, function()
        local ok, why = mc.pickUp(current())
        print("|cff88ccffWolfpack:|r " .. (ok and "there it is -- click an action bar slot"
            or (why or "no")))
    end)
    button(M.page, "Save it into the game", 170, COL[1] + 174, M.EDIT - 218, function()
        local index, why = mc.toGame(current())
        print("|cff88ccffWolfpack:|r " .. (index and "saved in the game's macro list"
            or (why or "no")))
    end)
    button(M.page, "Open the game's list", 160, COL[1] + 350, M.EDIT - 218, function()
        mc.toGame(current())
        if not mc.openGameList() then print("|cff88ccffWolfpack:|r not while you are fighting") end
    end)
    local mNote = label(M.page, "Keep as many here as you like -- they are saved with the addon, "
        .. "one shelf per class, and changing profile does not touch them. The game itself only "
        .. "has 120 macro slots, so a macro is written into one at the moment you drag it out or "
        .. "press a button above. Editing one afterwards changes the slot it already has; a name "
        .. "the game is using already is left alone and this one takes a number beside it.\n\n"
        .. "If the game starts complaining about action bar cooldowns after you drag one out, "
        .. "save it in and drag it off the game's own list instead -- that way Blizzard's code "
        .. "does the picking up, and a /reload clears what has already been upset.",
        "GameFontDisableSmall")
    mNote:SetPoint("TOPLEFT", COL[1] + 8, M.EDIT - 250)
    mNote:SetWidth(700)
    mNote:SetJustifyH("LEFT")

    ----------------------------------------------------------------------------------
    -- The icon picker: a page of them at a time, with a box to narrow the list down.
    ----------------------------------------------------------------------------------
    M.picker = CreateFrame("Frame", nil, M.page)
    M.picker:SetPoint("TOPLEFT", COL[1] + 380, M.EDIT + 20)
    M.picker:SetSize(356, 280)
    M.picker:SetFrameLevel(M.page:GetFrameLevel() + 10)
    M.picker:EnableMouse(true)
    M.picker:Hide()
    M.picker.bg = M.picker:CreateTexture(nil, "BACKGROUND")
    M.picker.bg:SetAllPoints()
    M.picker.bg:SetColorTexture(0.05, 0.05, 0.07, 0.97)
    M.page.pickerPage, M.picker.buttons = 1, {}

    M.search = CreateFrame("EditBox", nil, M.picker, "InputBoxTemplate")
    M.search:SetPoint("TOPLEFT", 14, -12)
    M.search:SetSize(200, 22)
    M.search:SetAutoFocus(false)
    M.search:SetScript("OnTextChanged", function()
        M.page.pickerPage = 1
        changed()
    end)
    M.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    label(M.picker, "Search", "GameFontDisableSmall"):SetPoint("BOTTOMLEFT", M.search, "TOPLEFT", -6, 2)

    M.pickerCount = label(M.picker, "", "GameFontDisableSmall")
    M.pickerCount:SetPoint("TOPRIGHT", -14, -18)

    for i = 1, 48 do -- eight across, six down
        local b = CreateFrame("Button", nil, M.picker)
        b:SetSize(34, 34)
        b:SetPoint("TOPLEFT", 14 + ((i - 1) % 8) * 42, -44 - math.floor((i - 1) / 8) * 38)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnClick", function(self)
            local e = current()
            if e and self.icon then e.icon = self.icon end
            M.picker:Hide()
            changed()
        end)
        b:SetScript("OnEnter", function(self)
            if not mc.iconName(self.icon) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(mc.iconName(self.icon))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        M.picker.buttons[i] = b
    end

    button(M.picker, "Back", 70, 14, -272, function()
        M.page.pickerPage = math.max(1, M.page.pickerPage - 1)
        changed()
    end)
    button(M.picker, "More", 70, 90, -272, function()
        M.page.pickerPage = M.page.pickerPage + 1
        changed()
    end)
    button(M.picker, "Back to the spell's icon", 160, 180, -272, function()
        local e = current()
        if e then e.icon = nil end
        M.picker:Hide()
        changed()
    end)

    onRefresh(function()
        if not M.picker:IsShown() then return end
        local found = mc.iconsLike(M.search:GetText())
        local pages = math.max(1, math.ceil(#found / 48))
        M.page.pickerPage = math.max(1, math.min(M.page.pickerPage, pages))
        local first = (M.page.pickerPage - 1) * 48
        for i, b in ipairs(M.picker.buttons) do
            local icon = found[first + i]
            b.icon = icon
            b.tex:SetTexture(mc.texture(icon))
            b:SetShown(icon ~= nil)
        end
        M.pickerCount:SetText(("%d icons, page %d of %d"):format(#found, M.page.pickerPage, pages))
    end)

    onRefresh(function()
        if not M.page:IsShown() then return end
        local list = shelf()
        M.picked = math.max(1, math.min(M.picked, math.max(#list, 1)))
        for i, e in ipairs(list) do
            local r = M.row(i)
            r.tex:SetTexture(mc.iconOf(e))
            r.sel:SetShown(i == M.picked)
            r:Show()
        end
        for i = #list + 1, #M.rows do M.rows[i]:Hide() end
        M.listChild:SetHeight(math.max(math.ceil(#list / M.COLS) * M.CELL, 10))
        M.empty:SetShown(#list == 0)
        M.empty:SetText("Nothing here yet. Press New macro.")
        M.count:SetText(#list == 0 and "" or (#list .. (#list == 1 and " macro" or " macros")))
        local e = current()
        M.name:SetShown(e ~= nil)
        M.bodyBox:SetShown(e ~= nil)
        M.iconBtn:SetShown(e ~= nil)
        if e then
            if not M.name:HasFocus() then M.name:SetText(e.name or "") end
            if not M.body:HasFocus() then M.body:SetText(e.body or "") end
            M.iconBtn.tex:SetTexture(mc.iconOf(e))
        else
            M.picker:Hide()
        end
    end)

    ----------------------------------------------------------------------------------
    -- Dungeons page: pick a place on the left, read its loot and its quests on the right.
    ----------------------------------------------------------------------------------
    local D = { rows = {}, picks = {} }
    ns.dung = D
    local DG = function() return db.dungeons end
    local dset = group(dungPage, COL[1], TOP, 202, "The list")
    check(dungPage, "Blue and better only", dset.x, dset:row(ROW),
        function() return DG().blueOnly end, function(v) DG().blueOnly = v end)
    check(dungPage, "Show drop chance", dset.x, dset:row(ROW),
        function() return DG().showChance end, function(v) DG().showChance = v end)
    check(dungPage, "List the quests too", dset.x, dset:row(ROW),
        function() return DG().quests end, function(v) DG().quests = v end)
    dset:close()

    D.left = CreateFrame("ScrollFrame", nil, dungPage, "UIPanelScrollFrameTemplate")
    D.left:SetPoint("TOPLEFT", COL[1] + 8, TOP - 116)
    D.left:SetSize(176, 430)
    D.leftChild = CreateFrame("Frame", nil, D.left)
    D.leftChild:SetSize(176, 10)
    D.left:SetScrollChild(D.leftChild)

    D.right = CreateFrame("Frame", nil, dungPage)
    D.right:SetPoint("TOPLEFT", COL[2], TOP - 4)
    D.right:SetSize(620, 560)
    local dbg = D.right:CreateTexture(nil, "BACKGROUND")
    dbg:SetAllPoints()
    dbg:SetColorTexture(0, 0, 0, 0.35)
    D.scroll = CreateFrame("ScrollFrame", nil, D.right, "UIPanelScrollFrameTemplate")
    D.scroll:SetPoint("TOPLEFT", 6, -6)
    D.scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    D.child = CreateFrame("Frame", nil, D.scroll)
    D.child:SetSize(580, 10)
    D.scroll:SetScrollChild(D.child)
    D.empty = D.child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    D.empty:SetPoint("TOPLEFT", 8, -8)
    D.empty:SetText("The dungeon tables are not loaded.\n\nThey live in their own addon --"
        .. " \"Wolfpack Addon - Dungeon Loot\" -- so that you can switch them off. Tick it in"
        .. " the addon list and reload.")
    D.empty:SetJustifyH("LEFT")

    function D.row(i)
        local r = D.rows[i]
        if not r then
            r = CreateFrame("Button", nil, D.child)
            r:SetSize(576, 18)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(15, 15)
            r.icon:SetPoint("LEFT", 4, 0)
            r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
            r.name:SetJustifyH("LEFT")
            r.right = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            r.right:SetPoint("RIGHT", -8, 0)
            r:SetScript("OnEnter", function(self)
                if not self.itemID and not self.quest then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.itemID then
                    local ok = pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
                    if not ok then GameTooltip:SetText(self.name:GetText() or "") end
                else
                    GameTooltip:SetText(self.quest[2])
                    if self.quest[6] then
                        GameTooltip:AddLine("From " .. self.quest[6], 1, 1, 1)
                        GameTooltip:AddLine(("%s  %.1f, %.1f"):format(self.quest[7] or "?",
                            self.quest[8] or 0, self.quest[9] or 0), 0.7, 0.7, 0.7)
                        GameTooltip:AddLine("Click to put it on the map", 0.2, 1, 0.2)
                    else
                        GameTooltip:AddLine("Nobody hands this one out -- it starts on an item "
                            .. "or inside the place.", 0.7, 0.7, 0.7, true)
                    end
                end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r:SetScript("OnClick", function(self)
                if not self.quest then return end
                if not lt.showOnMap(self.quest) then
                    print("|cff88ccffWolfpack:|r " .. (InCombatLockdown()
                        and "not while you are fighting"
                        or "no map spot for that one"))
                end
            end)
            D.rows[i] = r
        end
        return r
    end

    function D.pick(i)
        local b = D.picks[i]
        if not b then
            b = button(dungPage, "", 170, 0, 0, function()
                DG().pick = i
                changed()
            end)
            b:SetParent(D.leftChild)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
            D.picks[i] = b
        end
        return b
    end

    onRefresh(function()
        if section ~= "dungeons" then return end
        local all = lt.all()
        if DG().pick == 0 or not all[DG().pick] then DG().pick = lt.forMyLevel() end
        for i, d in ipairs(all) do
            local b = D.pick(i)
            b:SetText(d.name)
            if i == DG().pick then b:LockHighlight() else b:UnlockHighlight() end
            b:Show()
        end
        for i = #all + 1, #D.picks do D.picks[i]:Hide() end
        D.leftChild:SetHeight(math.max(#all * 22, 10))

        local here = all[DG().pick]
        local list = lt.rows(here)
        D.empty:SetShown(#all == 0)
        for i, e in ipairs(list) do
            local r = D.row(i)
            r:SetPoint("TOPLEFT", 0, -(i - 1) * 18)
            r.itemID, r.quest = nil, nil
            if e.item then
                local id, name, quality, need, pct, change = e.item[1], e.item[2], e.item[3],
                    e.item[4], e.item[5], e.item[6]
                r.itemID = id
                local ok, tex = pcall(function() return C_Item.GetItemIconByID(id) end)
                r.icon:SetTexture((ok and tex) or 134400)
                r.icon:Show()
                r.name:SetText(name .. (type(change) == "string"
                    and ("  |cff8888ff" .. change .. "|r") or ""))
                local col = lt.quality[quality] or lt.quality[1]
                r.name:SetTextColor(col[1], col[2], col[3])
                local note = type(need) == "number" and need > 0 and ("needs " .. need) or ""
                if DG().showChance and type(pct) == "number" and pct > 0 then
                    note = (note ~= "" and note .. "  " or "") .. pct .. "%"
                end
                r.right:SetText(note)
            elseif e.quest then
                r.quest = e.quest
                r.icon:Hide()
                local how = lt.questLook[lt.questState(e.quest)] or lt.questLook.open
                r.name:SetText(e.quest[2])
                r.name:SetTextColor(how[2], how[3], how[4])
                local why = how[1]
                if why == "too low" then why = "needs level " .. (e.quest[4] or 0) end
                r.right:SetText(why)
                r.right:SetTextColor(how[2], how[3], how[4])
            else
                r.icon:Hide()
                r.name:SetText(e.boss)
                r.name:SetTextColor(0.6, 0.85, 1)
                r.right:SetText("")
                r.right:SetTextColor(0.5, 0.5, 0.5)
            end
            r:Show()
        end
        for i = #list + 1, #D.rows do D.rows[i]:Hide() end
        D.child:SetHeight(math.max(#list * 18, 10))
    end)

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

    -- the sidebar now runs past most pages, so it counts towards the height too
    ns.configHeight = math.max(-pageBottom, -(ns.sidebarBottom or 0)) + 24
    local height = math.min(ns.configHeight, math.floor(UIParent:GetHeight()) - 40)
    cfg:SetHeight(height)
    barsPage:SetHeight(height)
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
    if cfg:IsShown() then changed() end
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

-- /wp loot -- does this client carry its own Encounter Journal? If it does, dungeon bosses and
-- their loot come from the game itself and no loot tables need shipping with the addon.
function ns.LootReport()
    local function say(t) print("|cff88ccffWolfpack:|r " .. t) end
    say("C_EncounterJournal: " .. type(C_EncounterJournal))
    say("EJ_GetInstanceByIndex: " .. type(EJ_GetInstanceByIndex)
        .. ", EJ_GetEncounterInfoByIndex: " .. type(EJ_GetEncounterInfoByIndex)
        .. ", EJ_GetNumLoot: " .. type(EJ_GetNumLoot))
    local keys = {}
    if type(C_EncounterJournal) == "table" then
        for k in pairs(C_EncounterJournal) do keys[#keys + 1] = k end
        table.sort(keys)
    end
    say("C_EncounterJournal has: " .. (#keys > 0 and table.concat(keys, ", ") or "nothing"))
    -- nothing is listed until a tier is picked, so every tier is walked
    local tiers = 0
    pcall(function() tiers = EJ_GetNumTiers() or 0 end)
    say("tiers: " .. tostring(tiers))
    for t = 1, tiers do
        local tname = select(1, pcall(function() return (EJ_GetTierInfo(t)) end)) and
            select(2, pcall(function() return (EJ_GetTierInfo(t)) end)) or "?"
        pcall(EJ_SelectTier, t)
        local names, raids = {}, {}
        pcall(function()
            for i = 1, 40 do
                local id, name = EJ_GetInstanceByIndex(i, false)
                if not id then break end
                names[#names + 1] = name or ("#" .. id)
            end
            for i = 1, 40 do
                local id, name = EJ_GetInstanceByIndex(i, true)
                if not id then break end
                raids[#raids + 1] = name or ("#" .. id)
            end
        end)
        say(("tier %d (%s): %d dungeons, %d raids%s"):format(t, tostring(tname), #names, #raids,
            #names > 0 and (" -- " .. table.concat(names, ", ")) or ""))
    end
    pcall(function()
        local id
        for t = 1, tiers do
            EJ_SelectTier(t)
            id = select(1, EJ_GetInstanceByIndex(1, false))
            if id then break end
        end
        if not id then return end
        EJ_SelectInstance(id)
        local bosses = {}
        for i = 1, 20 do
            local name = EJ_GetEncounterInfoByIndex(i, id)
            if not name then break end
            bosses[#bosses + 1] = name
        end
        say("  first one's bosses: " .. (#bosses > 0 and table.concat(bosses, ", ") or "none"))
        local ok, n = pcall(EJ_GetNumLoot)
        say("  loot rows there: " .. (ok and tostring(n) or "no answer"))
    end)
    say("AtlasLoot loaded: " .. tostring(C_AddOns and C_AddOns.IsAddOnLoaded
        and select(1, C_AddOns.IsAddOnLoaded("AtlasLoot")) or "unknown"))
end

SlashCmdList.WOLFPACKADDON = function(msg)
    msg = (msg or ""):lower()
    if msg:find("aura") then return safe(ns.AuraReport, (msg:gsub("^%s*auras?%s*", ""))) end
    if msg:find("crit") then return safe(ns.CritReport) end
    if msg:find("armor") then return safe(ns.ArmorReport) end
    if msg:find("pet") then return safe(ns.PetReport) end
    if msg:find("loot") then return safe(ns.LootReport) end
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
        store.classProfiles = store.classProfiles or {} -- [class token] = profile name
        store.macros = store.macros or {} -- [class token] = { { name, body, icon }, ... }
        -- The baked macros are added to whatever is already on a shelf, not instead of it, and
        -- each is only ever offered once: delete one and it stays deleted, while any that arrive
        -- in a later version of the addon turn up beside what you have.
        store.macrosBaked = store.macrosBaked or {}
        for key, rows in pairs(ns.bakedMacros or {}) do
            local shelf = store.macros[key] or {}
            store.macros[key] = shelf
            local have = {}
            for _, m in ipairs(shelf) do have[m.name] = true end
            for _, m in ipairs(rows) do
                local tag = key .. "|" .. m.name
                if not store.macrosBaked[tag] and not have[m.name] then
                    shelf[#shelf + 1] = { name = m.name, body = m.body, icon = m.icon }
                end
                store.macrosBaked[tag] = true
            end
        end
        seedFromBaked()
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
        for _, e in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP" }) do
            listen(e)
        end
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
        if not (mine and store.profiles[mine]) then
            mine = store.classProfiles and store.classProfiles[class or ""]
        end
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
