-- Trinket manager: a button for each trinket slot (13, 14), each with a key (Action bars' quick
-- keybind mode), and one priority list of your trinkets. A slot whose trinket is on cooldown
-- pulls the first ready one of the list; hovering a button opens the list as a flyout, to order it
-- (the arrows) or to pick one by hand for that slot. The game allows no gear changes in combat:
-- what you ask for then happens as combat ends.
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
-- the list, a slot keeping what it wears when that is among them
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
        if not taken[id] and left and left <= T.LOCK then ready[#ready + 1] = id end
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
    b:RegisterForClicks("AnyUp", "AnyDown") -- the template keeps the one the key-down setting wants
    b.wpI, b.wpSlot = i, "trinket:" .. i
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetColorTexture(0, 0, 0, 1)
    b.edge:SetPoint("TOPLEFT", -1, 1)
    b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints()
    b.wpKey = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    b.wpKey:SetPoint("TOPRIGHT", -2, -2)
    b:SetScript("PreClick", function(self) T.press(self) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", s)
        GameTooltip:Show()
        if not (ns.ab and ns.ab.binding) then T.open(self) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if ns.abHooks then ns.abHooks(b) end -- quick keybind mode binds here too
    T.buttons[i] = b
end
if ns.ab then ns.ab.buttons.trinket = T.buttons end

function T.paint()
    for i, b in ipairs(T.buttons) do
        local s = T.SLOTS[i]
        b.icon:SetTexture(GetInventoryItemTexture("player", s) or T.EMPTY)
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
    local O = T.o()
    if not O then return end
    if InCombatLockdown() then T.pending = true return end
    T.pending = false
    local h, size, gap = T.holder, O.size, O.gap
    h:SetShown(O.show and true or false)
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
        if ns.abHotkey then ns.abHotkey(b) end
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
T.holder:SetScript("OnUpdate", T.tick)

------------------------------------------------------------------------------------------
-- The flyout: the list, top first. Click one to wear it in this button's slot; arrows reorder.
------------------------------------------------------------------------------------------
local ROW, W = 26, 250
T.flyout = CreateFrame("Frame", nil, UIParent)
T.flyout:SetFrameStrata("DIALOG")
T.flyout:SetWidth(W)
T.flyout:Hide()
if ns.ui and ns.ui.box then ns.ui.box(T.flyout, ns.ui.C.bg, ns.ui.C.border, 6) end
T.flyout.title = T.flyout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
T.flyout.title:SetPoint("TOPLEFT", 8, -7)
T.flyout.rows = {}
T.flyout:SetScript("OnUpdate", function(self)
    if not (self:IsMouseOver() or (self.owner and self.owner:IsMouseOver())) then self:Hide() end
end)

local function row(k)
    local r = T.flyout.rows[k]
    if r then return r end
    r = CreateFrame("Button", nil, T.flyout)
    r:SetSize(W - 12, ROW - 2)
    r:SetPoint("TOPLEFT", 6, -22 - (k - 1) * ROW)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 1, 1, 0.08)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ROW - 4, ROW - 4)
    r.icon:SetPoint("LEFT", 2, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetWidth(W - 110)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.left = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.left:SetPoint("RIGHT", -44, 0)
    for _, a in ipairs({ { "up", -1, "Interface\\Buttons\\Arrow-Up-Up", -22 }, { "down", 1, "Interface\\Buttons\\Arrow-Down-Up", -2 } }) do
        local b = CreateFrame("Button", nil, r)
        b:SetSize(18, 18)
        b:SetPoint("RIGHT", a[4], 0)
        b:SetNormalTexture(a[3])
        b:SetScript("OnClick", function() T.move(r.id, a[2]); T.fill() end)
        r[a[1]] = b
    end
    r:SetScript("OnClick", function(self) T.pick(T.flyout.owner.wpI, self.id); T.fill() end)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetItemByID, GameTooltip, self.id)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    T.flyout.rows[k] = r
    return r
end

function T.fill()
    local f, list = T.flyout, T.list()
    local worn = { GetInventoryItemID("player", 13), GetInventoryItemID("player", 14) }
    local held = f.owner and T.hold[f.owner.wpI]
    f.title:SetText(("Trinket %d: click one to wear it here%s"):format(f.owner and f.owner.wpI or 1,
        InCombatLockdown() and " (after combat)" or ""))
    local info = api("GetItemInfo")
    for k, id in ipairs(list) do
        local r = row(k)
        r.id = id
        r.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id)) or T.EMPTY)
        local name = info and info(id)
        local tag = worn[1] == id and "|cff66ff66[1]|r " or worn[2] == id and "|cff66ff66[2]|r " or ""
        r.name:SetText(k .. ". " .. tag .. (name or ("Item " .. id)) .. (held and held.id == id and " |cffffd100(picked)|r" or ""))
        local left = T.left(id)
        r.left:SetText(left and left > 0 and ("%d s"):format(math.ceil(left)) or "")
        r.up:SetShown(k > 1)
        r.down:SetShown(k < #list)
        r:Show()
    end
    for k = #list + 1, #f.rows do f.rows[k]:Hide() end
    f:SetHeight(28 + math.max(1, #list) * ROW)
    if #list == 0 then f.title:SetText("No trinkets in your bags") end
end

-- opened beside the button, on the side the Trinket manager page says
T.SIDES = { up = { "BOTTOM", "TOP", 0, 4 }, down = { "TOP", "BOTTOM", 0, -4 }, left = { "RIGHT", "LEFT", -4, 0 },
    right = { "LEFT", "RIGHT", 4, 0 } }
function T.open(b)
    local f, side = T.flyout, T.SIDES[T.o().flyout] or T.SIDES.up
    f.owner = b
    f:ClearAllPoints()
    f:SetPoint(side[1], b, side[2], side[3], side[4])
    T.fill()
    f:Show()
end

-- an import string's list: item IDs only
function T.clean(v)
    local out = {}
    for _, id in ipairs(type(v) == "table" and v or {}) do
        if type(id) == "number" and id > 0 and id == math.floor(id) and #out < 100 then out[#out + 1] = id end
    end
    return out
end
