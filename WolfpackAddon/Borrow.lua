local _, ns = ...

-- Forever (and Midnight) keep aura data from addons in combat: asking for a buff or debuff is
-- refused while you fight ("Auras cannot be accessed when secret"), so the target's rows would
-- freeze. Blizzard's own target frame still gets them, so on such a client its buttons are
-- borrowed: each time Blizzard lays its target's auras out, the Combat Display's rows take those
-- very buttons (the way Bar Stack borrows the Cooldown Manager's icons). They are only moved
-- and sized, never read: picture, stacks, timer and border stay Blizzard's.
-- ponytail: Only mine and the lists can't apply to them (nothing about them may be read), and
-- your own rows still ask the game, so they hold still in a fight.
local B = { away = CreateFrame("Frame") }
B.away:Hide() -- past a row's most icons: out of sight
ns.borrow = B

local TEMPLATES = { buffs = "TargetBuffFrameTemplate", debuffs = "TargetDebuffFrameTemplate" }

function B.on()
    return issecretvalue ~= nil and TargetFrame ~= nil and TargetFrame.auraPools ~= nil
end

-- Blizzard's target buttons of one kind that it is showing, oldest aura first where that can be
-- told (an instance ID kept secret can't be compared: then as the pool hands them out)
function B.buttons(kind)
    local out = {}
    pcall(function()
        for b in TargetFrame.auraPools:EnumerateActiveByTemplate(TEMPLATES[kind]) do
            if b:IsShown() then out[#out + 1] = b end
        end
    end)
    pcall(table.sort, out, function(a, b) return (a.auraInstanceID or 0) < (b.auraInstanceID or 0) end)
    return out
end

-- The first `n` into `box`, each placed by place(button, i, n); any it held before and no
-- longer gets go back out of sight. Returns how many it holds.
function B.place(list, box, n, place)
    local now = {}
    for i = 1, n do
        local b = list[i]
        now[b] = true
        b:SetParent(box)
        place(b, i, n)
    end
    for b in pairs(box.borrowed or {}) do
        if not now[b] then b:SetParent(B.away) end
    end
    box.borrowed = now
    return n
end

-- One in the look of our own icons (the group's settings o): no border, the picture trimmed by
-- its zoom and cut to its corners, the swipe in the same shape, its timer text as set, the
-- stack count where ours has it. Only looks change; Blizzard keeps filling them.
local function part(b, a, c) -- a child Blizzard's template may name either way, or not have
    local v = rawget(b, a) or rawget(b, c)
    return type(v) == "table" and v or nil
end
function B.skin(b, o)
    local icon, cd, border, count = part(b, "Icon", "icon"), part(b, "Cooldown", "cooldown"), part(b, "Border", "border"),
        part(b, "Count", "count")
    if icon then
        b.wpMask = b.wpMask or b:CreateMaskTexture()
        b.wpMask:SetAllPoints(icon)
        local z = (o.zoom or 8) / 100
        ns.iconCorners(icon, b.wpMask, o.radius, { z, 1 - z, z, 1 - z })
    end
    if border then border:SetAlpha(0) end
    if cd then
        local file = ns.ICON_MASKS[o.radius]
        cd:SetSwipeTexture(file and "Interface\\AddOns\\WolfpackAddon\\Media\\Icon\\" .. file .. ".tga"
            or "Interface\\Buttons\\WHITE8X8")
        cd:SetSwipeColor(0, 0, 0, 0.7)
        cd:SetHideCountdownNumbers(o.hideTimer and true or false)
    end
    if count then
        count:SetFontObject("NumberFontNormalSmall")
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", -1, 1)
    end
end

-- after Blizzard has laid them out: into the rows again
local function after()
    local f = ns.frames and ns.frames.enemyhealth
    if f and f:IsShown() and B.on() then pcall(ns.layoutAuras, f) end
end
if TargetFrame and TargetFrame.UpdateAuras then hooksecurefunc(TargetFrame, "UpdateAuras", after) end
