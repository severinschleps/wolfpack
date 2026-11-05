-- Trinket manager: a button for each trinket slot (13, 14), each with a key (Action bars' quick
-- keybind mode), and one priority list of your trinkets. A slot whose trinket is on cooldown
-- pulls the first ready one of the list that is in the rotation; hovering a button opens the list
-- as a flyout, with a sidebar to order it (the arrows) and put each in the rotation or not (the
-- toggle; new ones are not), or to pick one by hand for that slot. The game allows no gear changes
-- in combat: what you ask for then happens as combat ends.
local _, ns = ...
local T = {}
ns.trink = T
T.SLOTS = { 13, 14 }
T.LOCK = 30 -- a trinket put on is locked for 30 s: that counts as ready, not as used
T.EMPTY = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket"
T.hold = {}   -- [button] = { id, since }: picked by hand, worn until it is used
T.queued = {} -- [button] = true: asked for in combat, done once it ends

local function api(name) return (C_Container and C_Container[name]) or (C_Item and C_Item[name]) or _G[name] end
local function readable(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end
function T.o()
    local p = ns.profile and ns.profile()
    return p and p.trinkets
end

function T.isTrinket(id)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not (id and fn) then return false end
    local ok, _, _, _, loc = pcall(fn, id)
    return ok and loc == "INVTYPE_TRINKET"
end

-- your trinkets, worn and in the bags: [item ID] = true
function T.owned()
    local out = {}
    for _, s in ipairs(T.SLOTS) do
        local id = GetInventoryItemID("player", s)
        if id then out[id] = true end
    end
    local num, idOf = api("GetContainerNumSlots"), api("GetContainerItemID")
    if num and idOf then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, num(bag) or 0 do
                local id = idOf(bag, slot)
                if id and not out[id] and T.isTrinket(id) then out[id] = true end
            end
        end
    end
    return out
end

-- seconds until it can be used (0: ready), its cooldown's length and start; nil while the game
-- won't say (a secret, in combat)
function T.left(id)
    local fn = api("GetItemCooldown")
    if not fn then return 0, 0, 0 end
    local ok, start, dur = pcall(fn, id)
    if not ok or not readable(start) or not readable(dur) then return nil end
    if (start or 0) <= 0 or (dur or 0) <= 0 then return 0, 0, 0 end
    return math.max(0, start + dur - GetTime()), dur, start
end

-- the list as it stands: the trinkets you have, in your order; new ones join at the end
function T.list()
    local q, owned, out, seen = T.o().queue, T.owned(), {}, {}
    local known = {}
    for _, id in ipairs(q) do known[id] = true end
    local new = {}
    for id in pairs(owned) do if not known[id] then new[#new + 1] = id end end
    table.sort(new)
    for _, id in ipairs(new) do q[#q + 1] = id end
    for _, id in ipairs(q) do
        if owned[id] and not seen[id] then seen[id] = true; out[#out + 1] = id end
    end
    return out
end

-- in the rotation: swapped in by the list. Not: in your bags, worn only when picked by hand
function T.inRot(id)
    for _, x in ipairs(T.o().rotation) do if x == id then return true end end
    return false
end
function T.setRot(id, on)
    local r = T.o().rotation
    for i = #r, 1, -1 do if r[i] == id then table.remove(r, i) end end
    if on then r[#r + 1] = id end
end

-- one place up (d = -1) or down (d = 1); what you don't have any more goes to the end
function T.move(id, d)
    local list = T.list()
    for i, x in ipairs(list) do
        if x == id and list[i + d] then list[i], list[i + d] = list[i + d], list[i]; break end
    end
    local q, mine = T.o().queue, {}
    for _, x in ipairs(list) do mine[x] = true end
    for _, x in ipairs(q) do if not mine[x] then list[#list + 1] = x end end
    T.o().queue = list
end

-- what each slot should wear: one picked by hand, until it is used; else the first ready ones of
-- the list in the rotation, a slot keeping what it wears when that is among them
function T.plan()
    local worn = { GetInventoryItemID("player", 13), GetInventoryItemID("player", 14) }
    local want, taken = {}, {}
    for i = 1, 2 do
        local h = T.hold[i]
        if h then
            local _, dur, start = T.left(h.id)
            if worn[i] == h.id and dur and dur > T.LOCK + 0.5 and start >= h.since then
                T.hold[i] = nil -- used: the list takes over
            else
                want[i], taken[h.id] = h.id, true
            end
        end
    end
    local ready = {}
    for _, id in ipairs(T.list()) do
        local left = T.left(id)
        if not taken[id] and T.inRot(id) and left and left <= T.LOCK then ready[#ready + 1] = id end
    end
    local free, picks = {}, {}
    for i = 1, 2 do if not want[i] then free[#free + 1] = i end end
    for k = 1, math.min(#free, #ready) do picks[ready[k]] = true end
    for _, i in ipairs(free) do
        if worn[i] and picks[worn[i]] then want[i], picks[worn[i]] = worn[i], nil end
    end
    for _, i in ipairs(free) do
        if not want[i] then
            for _, id in ipairs(ready) do
                if picks[id] then want[i], picks[id] = id, nil; break end
            end
            want[i] = want[i] or worn[i] -- nothing ready: it stays
        end
    end
    return want, worn
end

-- put on what the plan says (only: that button's slot), one item at a time
function T.apply(only)
    if InCombatLockdown() or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return end
    if T.busyUntil and GetTime() < T.busyUntil then return end -- the last swap is still moving
    local want, worn = T.plan()
    local equip = api("EquipItemByName")
    for i, s in ipairs(T.SLOTS) do
        if (not only or only == i) and want[i] and want[i] ~= worn[i] and equip then
            pcall(equip, want[i], s)
            T.busyUntil = GetTime() + 1
            return
        end
    end
end

-- picked in the flyout: worn in that button's slot until it is used
function T.pick(i, id)
    T.hold[i] = { id = id, since = GetTime() }
    if InCombatLockdown() then T.queued[i] = true else T.busyUntil = nil; T.apply(i) end
end

-- a press: on cooldown (or, in combat, unknown), the button pulls the next one from the list
function T.press(b)
    local now = GetTime()
    if b.wpLast and now - b.wpLast < 0.3 then return end -- a key's down and up: one press
    b.wpLast = now
    local id = GetInventoryItemID("player", T.SLOTS[b.wpI])
    local left = id and T.left(id)
    if not id or left == nil or left > T.LOCK then
        T.hold[b.wpI] = nil
        if InCombatLockdown() then T.queued[b.wpI] = true else T.busyUntil = nil; T.apply(b.wpI) end
    end
end

-- Dragged off a button: a macro of the game's, "/use 13" (or 14), to drop on an action bar. It
-- fires whatever trinket that slot wears, its icon and cooldown follow it, and a press on it
-- pulls the next one as the button does (the game's UseInventoryItem is watched, below).
T.MACRO = "WP Trinket %d"
function T.macro(i)
    if InCombatLockdown() or not CreateMacro then return end -- bars change out of combat only
    local name, body = T.MACRO:format(i), "#showtooltip\n/use " .. T.SLOTS[i]
    if (GetMacroIndexByName(name) or 0) == 0 then
        -- the account's macros (every character has it); full: this character's
        if not pcall(CreateMacro, name, 134400, body, false) or (GetMacroIndexByName(name) or 0) == 0 then
            pcall(CreateMacro, name, 134400, body, true)
        end
    end
    if (GetMacroIndexByName(name) or 0) > 0 then PickupMacro(name) end
end
-- The key of the action button that macro sits on (the first one found with a key): your bars'
-- key for that action slot, else the game's own binding for the button showing it. nil: the
-- macro is on no bar, or on none with a key. Shown on the trinket button that has no key itself.
T.BLIZZ_BARS = { { 1, "ACTIONBUTTON" }, { 25, "MULTIACTIONBAR3BUTTON" }, { 37, "MULTIACTIONBAR4BUTTON" },
    { 49, "MULTIACTIONBAR2BUTTON" }, { 61, "MULTIACTIONBAR1BUTTON" } } -- first action slot, binding
function T.barKey(i)
    local m = GetMacroIndexByName and GetMacroIndexByName(T.MACRO:format(i)) or 0
    if not (m and m > 0 and GetActionInfo) then return end
    local binds = ns.profile().actionbars.binds
    for slot = 1, 120 do
        local ok, kind, id = pcall(GetActionInfo, slot)
        if ok and kind == "macro" and id == m then
            local key = binds[tostring(slot)]
            for _, b in ipairs(T.BLIZZ_BARS) do
                if not key and GetBindingKey and slot >= b[1] and slot < b[1] + 12 then
                    key = GetBindingKey(b[2] .. (slot - b[1] + 1))
                end
            end
            if key then return key end
        end
    end
end
-- the macro put on a bar or taken off, a key changed (the addon's events): the key text again
function T.keys()
    for _, b in ipairs(T.buttons or {}) do if ns.abHotkey then ns.abHotkey(b) end end
end
if UseInventoryItem then
    hooksecurefunc("UseInventoryItem", function(slot)
        for i, s in ipairs(T.SLOTS) do
            if slot == s and T.buttons[i] then T.press(T.buttons[i]) end
        end
    end)
end

------------------------------------------------------------------------------------------
-- The two buttons. Secure ("/use 13", "/use 14"), so they work in combat; moved out of it only.
------------------------------------------------------------------------------------------
T.holder = CreateFrame("Frame", "WolfpackTrinkets", UIParent)
T.holder:Hide()
T.buttons = {}
for i, s in ipairs(T.SLOTS) do
    local b = CreateFrame("Button", "WolfpackTrinket" .. i, T.holder, "SecureActionButtonTemplate")
    b:SetAttribute("type", "item")
    b:SetAttribute("item", tostring(s))
    -- the mouse: on release only, so pressing to drag it to a bar fires nothing. The template
    -- would otherwise follow the "cast on key down" setting for clicks too.
    b:SetAttribute("useOnKeyDown", false)
    b:RegisterForClicks("AnyUp", "AnyDown")
    -- the key: a hidden twin that does follow that setting, as your action bars' keys do
    local key = CreateFrame("Button", "WolfpackTrinketKey" .. i, UIParent, "SecureActionButtonTemplate")
    key:SetAttribute("type", "item")
    key:SetAttribute("item", tostring(s))
    key:RegisterForClicks("AnyUp", "AnyDown") -- the template keeps the one the key-down setting wants
    key:Hide()
    b.wpKeyButton = key
    b.wpI, b.wpSlot = i, "trinket:" .. i
    -- the parts the action bars' look (ns.abLook) styles: border, icon, their masks, the key
    b.wpEdge = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    b.wpEdge:SetAllPoints()
    b.wpIcon = b:CreateTexture(nil, "ARTWORK")
    b.wpEdgeMask, b.wpMask = b:CreateMaskTexture(), b:CreateMaskTexture()
    b.wpEdgeMask:SetAllPoints(b.wpEdge)
    b.wpMask:SetAllPoints(b.wpIcon)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.wpIcon)
    -- under the mouse: the icon lit and the border in the hover color
    b.wpHover = b:CreateTexture(nil, "OVERLAY")
    b.wpHover:SetAllPoints(b.wpIcon)
    b.wpHover:Hide()
    b.wpKey = b:CreateFontString(nil, "OVERLAY")
    b.wpKey:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    b.wpKey:SetPoint("TOPRIGHT", -2, -2)
    b:SetScript("PreClick", function(self) T.press(self) end)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self) T.macro(self.wpI) end)
    b:SetScript("OnEnter", function(self)
        T.lit(self, true)
        GameTooltip:SetOwner(self, T.TIP[T.o().flyout] or "ANCHOR_BOTTOM")
        GameTooltip:SetInventoryItem("player", s)
        GameTooltip:AddLine("Drag onto an action bar: a macro that uses this slot.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        if not (ns.ab and ns.ab.binding) then T.open(self) end
    end)
    b:SetScript("OnLeave", function(self) T.lit(self, false); GameTooltip:Hide() end)
    if ns.abHooks then ns.abHooks(b) end -- quick keybind mode binds here too
    T.buttons[i] = b
end
if ns.ab then ns.ab.buttons.trinket = T.buttons end

-- hovered (or its list open): lit, its border in the hover color; else as the look says
function T.lit(b, on)
    local O = T.o()
    if not O then return end
    local c = O.hoverColor
    b.wpHover:SetColorTexture(c[1], c[2], c[3], c[4])
    b.wpHover:SetShown(on)
    b.wpEdge:SetColorTexture(unpack(on and { c[1], c[2], c[3], 1 } or O.borderColor))
end

function T.paint()
    for i, b in ipairs(T.buttons) do
        local s = T.SLOTS[i]
        b.wpIcon:SetTexture(GetInventoryItemTexture("player", s) or T.EMPTY)
        local ok, start, dur = pcall(GetInventoryItemCooldown, "player", s)
        if ok and start ~= nil then
            local same = readable(start) and readable(dur) and b.wpStart == start and b.wpDur == dur
            if not same then
                pcall(b.cd.SetCooldown, b.cd, start, dur)
                b.wpStart, b.wpDur = readable(start) and start or nil, readable(dur) and dur or nil
            end
        end
    end
end

function T.sync()
    if not ns.loads("trinkets") or not ns.loads("actionbars") then return end
    local O = T.o()
    if not O then return end
    if InCombatLockdown() then T.pending = true return end
    T.pending = false
    -- corners as your action bars' (the Colors page's Action buttons corners, set before these existed)
    local ab = ns.profile().actionbars.bars[1]
    if ab and ab.radius ~= nil then O.radius = ab.radius end
    local h, size, gap = T.holder, O.size, O.gap
    h:SetShown(O.show and true or false)
    if ns.abFadeSet then ns.abFadeSet(h, O.mouseover) end
    h:ClearAllPoints()
    h:SetPoint(O.point, UIParent, O.point, O.x, O.y)
    h:SetSize(O.vertical and size or 2 * size + gap, O.vertical and 2 * size + gap or size)
    for i, b in ipairs(T.buttons) do
        b:SetSize(size, size)
        b:ClearAllPoints()
        if O.vertical then
            b:SetPoint("TOP", h, "TOP", 0, -(i - 1) * (size + gap))
        else
            b:SetPoint("LEFT", h, "LEFT", (i - 1) * (size + gap), 0)
        end
        if ns.abLook then ns.abLook(b, O, nil, true) end -- the action bars' look; the key text too
        ns.iconCorners(b.wpHover, b.wpMask, O.radius, { 0, 1, 0, 1 })
        T.lit(b, b:IsMouseOver() and h:IsShown())
    end
    if ns.abBinds then ns.abBinds() end
    T.paint()
end

-- 4 times a second: the icons and cooldowns; once a second, out of combat, the swaps.
-- ponytail: a poll instead of item events, which differ per client
function T.tick(_, dt)
    T.t = (T.t or 0) + dt
    if T.t < 0.25 then return end
    T.t = 0
    T.paint()
    if T.flyout:IsShown() then T.fill() end
    if InCombatLockdown() then return end
    if T.pending then T.sync() end
    for i in pairs(T.queued) do T.queued[i] = nil; T.busyUntil = nil; T.apply(i) end
    T.n = (T.n or 0) + 1
    if T.n % 4 ~= 0 then return end
    if T.o().auto then T.apply() else for i in pairs(T.hold) do T.apply(i) end end
end
-- its own clock: the holder's OnUpdate fades it, on mouseover
T.clock = CreateFrame("Frame")
T.clock:SetScript("OnUpdate", function(self, dt) if T.holder:IsShown() then T.tick(self, dt) end end)

------------------------------------------------------------------------------------------
-- The flyout: your trinkets as icons in a line out of the button, the list's first nearest it.
-- Left-click: wear it in this button's slot. Beside each, its sidebar: two arrows that move it
-- along the list (each points the way it goes) and a toggle, in the rotation or not.
-- It touches the button and closes only a moment after the mouse has left both, so the way over
-- to it is safe.
------------------------------------------------------------------------------------------
local PAD, GAP = 4, 4
T.flyout = CreateFrame("Frame", nil, UIParent)
T.flyout:SetFrameStrata("DIALOG")
T.flyout:EnableMouse(true) -- the gaps between icons count as on it
T.flyout:Hide()
if ns.ui and ns.ui.box then ns.ui.box(T.flyout, ns.ui.C.bg, ns.ui.C.border, 6) end
T.flyout.empty = T.flyout:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
T.flyout.empty:SetPoint("CENTER")
T.flyout.empty:SetText("No trinkets")
T.flyout.icons = {}
T.flyout:SetScript("OnUpdate", function(self, dt)
    if self:IsMouseOver() or (self.owner and self.owner:IsMouseOver()) then self.away = 0 return end
    self.away = (self.away or 0) + dt
    if self.away > 0.4 then self:Hide() end
end)
T.flyout:SetScript("OnShow", function(self) self.away = 0 end)
T.flyout:SetScript("OnHide", function(self) if self.owner then T.lit(self.owner, self.owner:IsMouseOver()) end end)

-- where each next icon goes: out of the button, the way the list opens
T.DIRS = { up = { "BOTTOM", 0, 1 }, down = { "TOP", 0, -1 }, left = { "RIGHT", -1, 0 }, right = { "LEFT", 1, 0 } }
-- the button's own tooltip goes the other way, off the list
T.TIP = { up = "ANCHOR_BOTTOM", down = "ANCHOR_TOP", left = "ANCHOR_RIGHT", right = "ANCHOR_LEFT" }

local function tip(self, text, sub)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1)
    if sub then GameTooltip:AddLine(sub, 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

-- an arrow of the sidebar: d = -1 earlier in the list, 1 later
local function arrow(c, d)
    local a = CreateFrame("Button", nil, T.flyout)
    a.tex = a:CreateTexture(nil, "ARTWORK")
    a.tex:SetAllPoints()
    a.tex:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    a:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    a:SetScript("OnClick", function() T.move(c.id, d); T.fill() end)
    a:SetScript("OnEnter", function(self) tip(self, d < 0 and "Higher in the list" or "Lower in the list") end)
    a:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return a
end

local function icon(k)
    local f = T.flyout
    local c = f.icons[k]
    if c then return c end
    c = CreateFrame("Button", nil, f)
    c:RegisterForClicks("LeftButtonUp")
    c.edge = c:CreateTexture(nil, "BACKGROUND")
    c.edge:SetAllPoints()
    c.tex = c:CreateTexture(nil, "ARTWORK")
    c.tex:SetPoint("TOPLEFT", 1, -1)
    c.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    c.mask = c:CreateMaskTexture()
    c.mask:SetAllPoints(c.tex)
    c.cd = CreateFrame("Cooldown", nil, c, "CooldownFrameTemplate")
    c.cd:SetAllPoints(c.tex)
    c.hl = c:CreateTexture(nil, "OVERLAY")
    c.hl:SetAllPoints(c.tex)
    c.hl:Hide()
    c.num = c:CreateFontString(nil, "OVERLAY")
    c.num:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    c.num:SetPoint("BOTTOMLEFT", 2, 2)
    c:SetScript("OnClick", function(self) T.pick(f.owner.wpI, self.id); T.fill() end)
    c:SetScript("OnEnter", function(self)
        self.hl:Show()
        local side = T.o().flyout
        GameTooltip:SetOwner(self, (side == "left" or side == "right") and "ANCHOR_TOP" or "ANCHOR_LEFT")
        pcall(GameTooltip.SetItemByID, GameTooltip, self.id)
        GameTooltip:AddLine(("Click: wear as trinket %d%s"):format(f.owner and f.owner.wpI or 1,
            InCombatLockdown() and " (after combat)" or ""), 0.4, 1, 0.4)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    -- the sidebar
    c.earlier, c.later = arrow(c, -1), arrow(c, 1)
    c.rot = ns.ui and ns.ui.Check and ns.ui.Check(f) or CreateFrame("CheckButton", nil, f)
    c.rot:SetScript("OnClick", function(self) T.setRot(c.id, self:GetChecked() and true or false); T.fill() end)
    c.rot:SetScript("OnEnter", function(self)
        if T.inRot(c.id) then tip(self, "In the rotation", "Swapped in by the list.")
        else tip(self, "Not in the rotation", "Stays in your bags; worn only when you click it.") end
    end)
    c.rot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.icons[k] = c
    return c
end

-- the angle that turns the up arrow to point (x, y)
local function angle(x, y) return x == 0 and (y > 0 and 0 or math.pi) or (x > 0 and -math.pi / 2 or math.pi / 2) end

-- the icons, laid out again: their order, which are worn or picked, their cooldowns; and their sidebars
function T.fill()
    local f, O, list = T.flyout, T.o(), T.list()
    local size, d = O.size, T.DIRS[O.flyout] or T.DIRS.up
    local across = d[3] == 0 -- opens to the left or right
    -- the sidebar's side: right of a list going up or down, below one going left or right
    local px, py = across and 0 or 1, across and -1 or 0
    local o, a = (size + GAP) / 2, math.max(10, math.floor((size - GAP) / 2))
    local worn = { GetInventoryItemID("player", 13), GetInventoryItemID("player", 14) }
    local me = f.owner and f.owner.wpI or 1
    local held = T.hold[me]
    local hc, z = O.hoverColor, O.zoom / 100
    local rank = 0
    for k, id in ipairs(list) do
        local c = icon(k)
        c.id = id
        c:SetSize(size, size)
        c:ClearAllPoints()
        local at = PAD + (k - 1) * (size + GAP)
        c:SetPoint(d[1], f, d[1], d[2] * at - o * px, d[3] * at - o * py)
        c.tex:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
            or (GetItemIcon and GetItemIcon(id)) or T.EMPTY)
        ns.iconCorners(c.tex, c.mask, O.radius, { z, 1 - z, z, 1 - z })
        ns.iconCorners(c.hl, c.mask, O.radius, { 0, 1, 0, 1 })
        c.hl:SetColorTexture(hc[1], hc[2], hc[3], hc[4])
        -- the border says where it is: picked for here (gold), worn here (green), worn in the other slot (blue)
        local edge = (held and held.id == id) and { 1, 0.82, 0, 1 } or worn[me] == id and { 0.3, 1, 0.3, 1 }
            or worn[3 - me] == id and { 0.35, 0.6, 1, 1 } or O.borderColor
        c.edge:SetColorTexture(unpack(edge))
        -- out of the rotation: grey, no number; the rotation numbered in its order
        local on = T.inRot(id)
        if on then rank = rank + 1 end
        c.tex:SetDesaturated(not on)
        c.num:SetText(on and rank or "")
        local _, dur, start = T.left(id)
        if c.wpStart ~= start or c.wpDur ~= dur then
            pcall(c.cd.SetCooldown, c.cd, start or 0, dur or 0)
            c.wpStart, c.wpDur = start, dur
        end
        -- the sidebar beside it: the arrows along the list, nearer the icon; the toggle past them
        local mid = at + size / 2
        for _, x in ipairs({ { c.earlier, -1, k > 1 }, { c.later, 1, k < #list } }) do
            local b, s, can = x[1], x[2], x[3]
            local along, side = mid + s * (a + GAP) / 2, o - (a + GAP) / 2
            b:SetSize(a, a)
            b:ClearAllPoints()
            b:SetPoint("CENTER", f, d[1], d[2] * along + px * side, d[3] * along + py * side)
            b.tex:SetRotation(angle(s * d[2], s * d[3]))
            b:SetEnabled(can)
            b.tex:SetAlpha(can and 1 or 0.25)
            b:Show()
        end
        local side = o + (a + GAP) / 2
        c.rot:SetSize(a, a)
        c.rot:ClearAllPoints()
        c.rot:SetPoint("CENTER", f, d[1], d[2] * mid + px * side, d[3] * mid + py * side)
        c.rot:SetChecked(on)
        c.rot:Show()
        c:Show()
    end
    for k = #list + 1, #f.icons do
        local c = f.icons[k]
        c:Hide(); c.earlier:Hide(); c.later:Hide(); c.rot:Hide()
    end
    f.empty:SetShown(#list == 0)
    local n = math.max(1, #list)
    local long, short = 2 * PAD + n * size + (n - 1) * GAP, 2 * size + GAP + 2 * PAD
    f:SetSize(across and long or short, across and short or long)
end

-- opened beside the button, touching it, on the side the Trinket manager page says; the icons in
-- line with it, the sidebar out to one side
T.SIDES = { up = { "BOTTOM", "TOP" }, down = { "TOP", "BOTTOM" }, left = { "RIGHT", "LEFT" }, right = { "LEFT", "RIGHT" } }
function T.open(b)
    local O = T.o()
    local f, side = T.flyout, T.SIDES[O.flyout] or T.SIDES.up
    local o, across = (O.size + GAP) / 2, (T.DIRS[O.flyout] or T.DIRS.up)[3] == 0
    if f.owner and f.owner ~= b then T.lit(f.owner, false) end
    f.owner = b
    f:ClearAllPoints()
    f:SetPoint(side[1], b, side[2], across and 0 or o, across and -o or 0)
    T.fill()
    f:Show()
    f.away = 0
end

-- an import string's list: item IDs only
function T.clean(v)
    local out = {}
    for _, id in ipairs(type(v) == "table" and v or {}) do
        if type(id) == "number" and id > 0 and id == math.floor(id) and #out < 100 then out[#out + 1] = id end
    end
    return out
end
