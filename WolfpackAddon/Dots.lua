-- DoT damage still to come, on your health and your target's: a darker stretch over the end of
-- the health fill, the number beside it, and a skull while the DoTs will finish the unit off.
--
-- The approach is DoesItDie's, by Joe Greive (MIT, see Dots-LICENSE.txt,
-- https://github.com/swirllyman/DoesItDie): the tooltip's numbers until a tick lands, ticks
-- learned as they land, Agony's uneven ticks, and on Forever, where the combat log is closed,
-- your casts and the hits on your target in its place. The skull is its trick too: a StatusBar
-- does the "damage >= health" sum, so health the game keeps secret can still go in.
local _, ns = ...

local build = select(4, GetBuildInfo())
-- Midnight and Forever (1.6, on Midnight's client) keep the log from addons: just asking for it
-- there is a blocked action
function ns.logAllowed(b) return b < 16000 or (b >= 20000 and b < 120000) end
ns.dotLog = CombatLogGetCurrentEventInfo ~= nil and ns.logAllowed(build)
ns.dotCasts = not ns.dotLog and build >= 16000 and build < 20000 -- Forever: casts and hits instead
ns.dotsOn = ns.dotLog or ns.dotCasts

local function isSecret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- Tick gaps other than 3 s that tooltips don't state. A measured gap wins over these.
local EVERY = { ["Insect Swarm"] = 2, ["Curse of Agony"] = 2, ["Bane of Agony"] = 2, ["Fireball"] = 2,
    ["Holy Fire"] = 2, ["Rip"] = 2, ["Rupture"] = 2 }
-- Uneven DoTs: each tick is the average one times its factor (stretched over the tick count)
local AGONY = { 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1.5, 1.5, 1.5, 1.5 }
local SHAPES = { ["Curse of Agony"] = AGONY, ["Bane of Agony"] = AGONY }
local SCHOOLS = { Physical = 1, Holy = 2, Fire = 4, Nature = 8, Frost = 16, Shadow = 32, Arcane = 64 }
local SCHOOL_OF = { ["Siphon Life"] = 32, ["Corruption"] = 32 } -- tooltips that name none
-- read like DoTs, but aren't one on the target: ground effects, channels, delayed damage (Forever)
local NOT_DOTS = {}
for _, n in ipairs({ "Rain of Fire", "Hellfire", "Blizzard", "Flamestrike", "Consecration", "Hurricane",
    "Volley", "Drain Life", "Drain Soul", "Drain Mana", "Health Funnel", "Mind Flay", "Arcane Missiles",
    "Starshards", "Explosive Trap", "Immolation Trap", "Wyvern Sting" }) do NOT_DOTS[n] = true end

local function factor(shape, k, ticks)
    if not shape then return 1 end
    local i = math.ceil(math.min(math.max(k, 1), ticks) / ticks * #shape)
    return shape[math.max(1, math.min(i, #shape))]
end

-- the last n of a DoT's ticks, at avg a tick on average
local function lastTicks(avg, n, ticks, shape)
    if not shape then return avg * n end
    local sum = 0
    for k = ticks - n + 1, ticks do sum = sum + avg * factor(shape, k, ticks) end
    return sum
end

local function schoolIn(words)
    local s = 1
    for w in words:gmatch("%a+") do s = SCHOOLS[w] or s end
    return s
end

-- A DoT's tooltip: its total damage, school, duration and tick gap (when it says), or nil.
-- English only. Finishers (Rip, Rupture) list theirs per combo point. The numbers leave out
-- spell and attack power, so a guess from them runs low: no early skull.
function ns.readDot(desc, points)
    if type(desc) ~= "string" or isSecret(desc) or desc:find("^Heals") or desc:find("[Cc]oats a weapon") then
        return
    end
    if desc:find("Finishing move") then
        local by, top = {}, 0
        for p, amount, secs in desc:gmatch("(%d+) points?%s*:%s*(%d+) damage over (%d+%.?%d*) sec") do
            p = tonumber(p)
            by[p], top = { tonumber(amount), tonumber(secs) }, math.max(top, p)
        end
        local e = top > 0 and (by[math.max(1, math.min(points or 1, top))] or by[top])
        if e then return e[1], 1, e[2] end
        return
    end
    local total, school, secs
    for amount, words, s in desc:gmatch("(%d+)%s*([%a ]-)%s*damage over (%d+%.?%d*) sec") do
        total, school, secs = tonumber(amount), schoolIn(words), tonumber(s) -- the last one: Immolate's DoT part
    end
    if total and secs > 0 then return total, school, secs end
    -- "... damage every 3 sec. Lasts 30 sec.", or Siphon Life's "Transfers 15 health ... every 3 sec"
    local amount, words, every = desc:match("(%d+)%s*([%a ]-)%s*damage every (%d+%.?%d*) sec")
    if not amount then
        amount, every = desc:match("(%d+) health.-every (%d+%.?%d*) sec")
        words = ""
    end
    local lasts = tonumber(desc:match("[Ll]asts (%d+%.?%d*) sec") or "")
    every = tonumber(every or "")
    if amount and every and lasts and every > 0 and lasts > 0 then
        return tonumber(amount) * math.floor(lasts / every + 0.5), schoolIn(words), lasts, every
    end
end

local function describe(id)
    if not id or isSecret(id) then return end
    local get = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    local ok, desc = pcall(get or function() end, id)
    if ok then return desc end
end

-- learned tick sizes by spell ID (by ID x points for finishers), kept across sessions
local function learned()
    if type(WolfpackAddonDB) ~= "table" then return {} end
    WolfpackAddonDB.dotTicks = WolfpackAddonDB.dotTicks or {}
    return WolfpackAddonDB.dotTicks
end

local function refresh(key, keyOf)
    for _, f in ipairs({ ns.frames.health, ns.frames.enemyhealth }) do
        if f.dot and f.dot:IsShown() and keyOf(f.unit or "player") == key then ns.fill(f) end
    end
end

------------------------------------------------------------------------------------------
-- Classic: the combat log. Each DoT's last tick (a crit only until a plain one lands) times the
-- ticks its debuff has left, the gap between ticks measured as they land. Keyed by spell name:
-- Classic Era's log gives no spell IDs.
------------------------------------------------------------------------------------------
ns.dots = {} -- [target GUID] = { [spell name] = { [caster GUID] = { amount, every, at } } }

function ns.dotFromLog()
    local _, sub, _, source, _, _, _, dest, _, _, _, _, spell, _, amount, _, _, _, _, _, crit =
        CombatLogGetCurrentEventInfo()
    if sub == "UNIT_DIED" then ns.dots[dest] = nil return end
    local missed = sub == "SPELL_PERIODIC_MISSED" -- still a tick, for the timing
    if sub ~= "SPELL_PERIODIC_DAMAGE" and not missed then return end
    local on = ns.dots[dest] or {}
    ns.dots[dest] = on
    on[spell] = on[spell] or {}
    local d, now = on[spell][source], GetTime()
    if not d then
        if missed then return end
        d = { amount = amount, every = EVERY[spell] or 3, at = now } -- until a second tick says
        on[spell][source] = d
    else
        local gap = math.floor((now - d.at) * 2 + 0.5) / 2 -- to the half second: lag
        if gap >= 1 and gap <= 5 then d.every = gap end -- outside that: a new application
        d.at = now
        if not (missed or crit) then d.amount = amount end
    end
    refresh(dest, UnitGUID)
end

local function leftFromLog(unit)
    local on = ns.dots[UnitGUID(unit) or ""] or {}
    local now, sum = GetTime(), 0
    for _, a in ipairs(ns.auraList(unit, "HARMFUL", 40) or {}) do
        local by, ends = on[a.name], a.expirationTime or 0
        -- ponytail: a caster the game won't name takes any tick of that DoT's; two such alike DoTs
        -- count one's ticks twice. Per-caster matching needs the caster's GUID on the aura.
        local d = by and (a.sourceUnit and by[UnitGUID(a.sourceUnit) or ""] or select(2, next(by)))
        local total, school, secs, said
        if not d then total, school, secs, said = ns.readDot(describe(a.spellId)) end
        if ends > now and (d or total) then
            local every = d and d.every or said or EVERY[a.name] or 3
            local dur = (a.duration or 0) > 0 and a.duration or secs or (ends - now)
            local ticks = math.max(1, math.floor(dur / every + 0.5))
            local n = math.min(math.max(math.ceil((ends - now) / every - 0.1), 0), ticks)
            local shape = SHAPES[a.name]
            -- the tick that just landed, as an average one; none yet: the tooltip's share
            local avg = d and d.amount / factor(shape, ticks - n, ticks) or total / ticks
            sum = sum + lastTicks(avg, n, ticks, shape)
        end
    end
    return sum
end

------------------------------------------------------------------------------------------
-- Forever: no log and no auras in a fight. Your DoT casts start one (from the tooltip, on the mob
-- you had targeted when you sent it); hits on your target of its school, on its beat and of a
-- likely size, are its ticks. A DoT that never ticks (resisted, immune) goes after two missed
-- beats. Only your own DoTs, and only ticks on your target are seen.
------------------------------------------------------------------------------------------
local casts = {} -- [mob key] = { [spell name] = dot }
local sentTo = {} -- [cast GUID] = mob key when sent
local WINDOW, ANCHORED = 0.45, 0.25 -- seconds either side of the beat: before / after a first tick

-- the mob's GUID, or "target" where the game keeps it secret (then only the target is followed)
local function keyOf(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and guid and not isSecret(guid) then return guid end
    if unit == "target" then return "target" end
end

local function avgTick(d)
    if d.normals > 0 then return d.sum / d.normals end
    return learned()[d.tickKey] or d.total / d.ticks
end

function ns.dotSent(castGUID)
    sentTo[castGUID] = keyOf("target")
    local ok, p = pcall(UnitPower, "player", 4) -- combo points: spent by the time it succeeds
    ns.dotPoints = ok and not isSecret(p) and p or nil
end

function ns.dotCast(castGUID, id)
    local key = sentTo[castGUID] or keyOf("target")
    sentTo[castGUID] = nil
    local name = id and not isSecret(id) and ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id))
        or (GetSpellInfo and GetSpellInfo(id)))
    if not key or not name or isSecret(name) or NOT_DOTS[name] then return end
    local desc = describe(id)
    local finisher = type(desc) == "string" and desc:find("Finishing move")
    local total, school, secs, every = ns.readDot(desc, ns.dotPoints)
    if not total then return end
    every = every or EVERY[name] or 3
    local now = GetTime()
    casts[key] = casts[key] or {}
    casts[key][name] = { id = id, total = total, school = SCHOOL_OF[name] or school, every = every,
        ticks = math.max(1, math.floor(secs / every + 0.5)), shape = SHAPES[name],
        tickKey = finisher and (id .. "x" .. (ns.dotPoints or 1)) or id,
        at = now, ends = now + secs, nextAt = now + every, sum = 0, normals = 0, seen = 0, missed = 0 }
    refresh(key, keyOf)
end

local function likely(d, amount, crit, k)
    local known = d.normals > 0 and d.sum / d.normals or learned()[d.tickKey]
    if not known then return true end
    known = known * factor(d.shape, k, d.ticks)
    if crit then return amount >= known * 1.3 - 1 and amount <= known * 2.3 + 1 end
    return math.abs(amount - known) <= math.max(1, known * (d.normals > 0 and 0.25 or 0.3))
end

-- UNIT_COMBAT on the target: action, flag, amount, school
function ns.dotHit(unit, action, flag, amount, school)
    if isSecret(action) or isSecret(amount) or isSecret(school) or type(amount) ~= "number" then return end
    if action ~= "WOUND" and action ~= "ABSORB" then return end -- a shield ate it: still on the beat
    local key = keyOf(unit)
    local now, crit, best, bestOff, bestSlot = GetTime(), not isSecret(flag) and flag == "CRITICAL"
    for _, d in pairs(key and casts[key] or {}) do
        local from = d.firstAt or d.at
        local slot = math.max(1, math.floor((now - from) / d.every + 0.5))
        local off = math.abs(now - (from + slot * d.every))
        local k = math.max(1, math.floor((now - d.at) / d.every + 0.5))
        if d.school == school and off <= (d.firstAt and ANCHORED or WINDOW)
            and (not d.firstAt or slot > d.lastSlot) and (amount == 0 or likely(d, amount, crit, k))
            and (not bestOff or off < bestOff) then
            best, bestOff, bestSlot = d, off, slot
        end
    end
    if not best then return end
    local d = best
    local k = math.max(1, math.floor((now - d.at) / d.every + 0.5))
    d.seen, d.missed = d.seen + 1, 0
    if not crit and amount > 0 then
        d.sum, d.normals = d.sum + amount / factor(d.shape, k, d.ticks), d.normals + 1
        learned()[d.tickKey] = math.floor(d.sum / d.normals * 10 + 0.5) / 10
    end
    if d.firstAt then d.lastSlot = bestSlot else d.firstAt, d.lastSlot = now, 0 end
    -- ticks land a little after their time: the end follows them, or the last one is cut off
    d.nextAt, d.ends = now + d.every, now + (d.ticks - k) * d.every
    refresh(key, keyOf)
end

local function leftFromCasts(unit)
    local key = keyOf(unit)
    local on, now, sum = key and casts[key], GetTime(), 0
    for name, d in pairs(on or {}) do
        while d.nextAt < now - WINDOW and d.nextAt <= d.ends do -- beats gone by
            d.nextAt = d.nextAt + d.every
            if d.seen == 0 and key == keyOf("target") then d.missed = d.missed + 1 end -- one we'd have seen
        end
        if now > d.ends + WINDOW or (d.seen == 0 and d.missed >= 2) then
            on[name] = nil
        elseif d.nextAt <= d.ends + d.every / 2 then
            sum = sum + lastTicks(avgTick(d), math.floor((d.ends - d.nextAt) / d.every + 0.5) + 1, d.ticks, d.shape)
        end
    end
    return sum
end

function ns.dotLeft(unit)
    if not UnitExists(unit) then return 0 end
    return math.floor((ns.dotLog and leftFromLog(unit) or leftFromCasts(unit)) + 0.5)
end

if ns.dotCasts then
    local ev = CreateFrame("Frame")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:RegisterUnitEvent("UNIT_COMBAT", "target")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:SetScript("OnEvent", function(_, event, ...)
        local ok, err = pcall(function(...)
            if event == "UNIT_SPELLCAST_SENT" then ns.dotSent(select(4, ...)) -- unit, target, castGUID, id
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then ns.dotCast(select(2, ...), select(3, ...))
            elseif event == "UNIT_COMBAT" then ns.dotHit(...)
            else casts.target = nil end -- "target" stood for a mob we can no longer tell apart
        end, ...)
        if not ok and not ns.errored then
            ns.errored = true
            print("|cffff5555Wolfpack Addon error:|r " .. tostring(err))
        end
    end)
end

------------------------------------------------------------------------------------------
-- The look: the stretch grows left from the end of the health fill (so it needs no number to be
-- placed), the number sits just left of it, and the skull just left of the number.
------------------------------------------------------------------------------------------
function ns.layoutDots(f, c)
    local seg = f.segs[1]
    local h = math.max(seg:GetHeight(), 8)
    if not f.dot then
        f.dot = CreateFrame("StatusBar", nil, f.clip)
        f.dot.text = f.dot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        -- The skull rides the end of a very long bar's fill, max = health, value = DoT damage, in
        -- a box the size of the skull: it only comes into the box once the fill is full.
        local box = CreateFrame("Frame", nil, f.dot)
        box:SetClipsChildren(true)
        local bar = CreateFrame("StatusBar", nil, box)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetStatusBarColor(0, 0, 0, 0)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        local skull = bar:CreateTexture(nil, "OVERLAY")
        skull:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        skull:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
        f.dot.kill, f.dot.killBar, f.dot.skull = box, bar, skull
    end
    local d, col = f.dot, c.dotsColor
    d:SetFrameLevel(seg:GetFrameLevel() + 2) -- over the heals, should both meet
    d:SetStatusBarTexture((c.dotsTexture or "bar") == "bar" and c.texture or c.dotsTexture)
    d:SetStatusBarColor(col[1], col[2], col[3], col[4]) -- after the texture: a new one resets it
    d.darker = c.dotsColorFrom ~= "custom" -- else the bar's color, darker, at every fill: it changes
    d:SetSize(seg:GetWidth(), seg:GetHeight())
    d:ClearAllPoints()
    d:SetReverseFill(true)
    d:SetPoint("RIGHT", seg:GetStatusBarTexture(), "RIGHT", 0, 0)
    d.text:ClearAllPoints()
    d.text:SetPoint("RIGHT", d:GetStatusBarTexture(), "LEFT", -2, 0)
    local flags = c.outline and "OUTLINE" or ""
    if not d.text:SetFont(c.font, c.fontSize, flags) then d.text:SetFontObject(GameFontHighlightSmall) end
    d.text:SetTextColor(unpack(c.textColor))
    d.text:SetShown(not c.dotsHideText)
    local s = math.min(h, 16)
    d.kill:SetSize(s, s)
    d.kill:ClearAllPoints()
    -- no number: the skull sits right by the stretch
    d.kill:SetPoint("RIGHT", c.dotsHideText and d:GetStatusBarTexture() or d.text, "LEFT", -1, 0)
    d.killBar:SetSize(10000, s)
    d.killBar:ClearAllPoints()
    d.killBar:SetPoint("LEFT", d.kill, "RIGHT", -10000, 0)
    d.skull:SetSize(s, s)
    d:Show()
end

-- An enemy player's health reads as a percent on Classic: the number shows, not the stretch or
-- the skull. Health may be secret (Forever): it only ever goes into the bars.
function ns.fillDots(f, max)
    local unit = f.unit or "player"
    local left = ns.dotLeft(unit)
    local percent = not isSecret(max) and max == 100 and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
    f.dot:SetMinMaxValues(0, max)
    f.dot:SetValue(percent and 0 or left)
    if f.dot.darker then
        local rgb = f.segs[1].rgb or { 0.5, 0.5, 0.5 }
        f.dot:SetStatusBarColor(rgb[1] * 0.5, rgb[2] * 0.5, rgb[3] * 0.5, 1)
    end
    f.dot.text:SetText(left > 0 and AbbreviateNumbers(left) or "")
    local ok, hp = pcall(UnitHealth, unit)
    f.dot.killBar:SetMinMaxValues(0, ok and hp or 1)
    f.dot.killBar:SetValue((left > 0 and not percent) and left or 0)
end
