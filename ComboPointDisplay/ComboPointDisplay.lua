-- ComboPointDisplay: stacked health / power / combo point / druid mana bars for WoW: Forever.
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

local function barDefaults(height, r, g, b, text)
    return {
        enabled = true, width = 220, height = height, texture = TEXTURES[1][2],
        color = { r, g, b, 1 }, gradient = false, color2 = { r * 0.4, g * 0.4, b * 0.4, 1 },
        vertical = false, text = text,
    }
end

local DEFAULTS = {
    locked = true, gap = 2, x = 0, y = -120,
    order = { "health", "power", "combo", "druidmana" },
    bars = {
        health = barDefaults(18, 0.2, 0.8, 0.2, true),
        power = barDefaults(14, 1, 0.85, 0.1, true),
        combo = barDefaults(12, 1, 0.3, 0.1, false),
        druidmana = barDefaults(6, 0.2, 0.45, 1, false),
    },
}
DEFAULTS.bars.power.powerColor = true
DEFAULTS.bars.combo.nameplate = false

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

-- state() -> shown, segment count. value() -> current, max (both possibly secret).
local BARS = {
    health = {
        label = "Health",
        state = function() return true, 1 end,
        value = function() return UnitHealth("player"), UnitHealthMax("player") end,
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
    anchor:SetPoint("TOP", UIParent, "CENTER", db.x, db.y)
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
    db.x, db.y = coords()
    place()
    changed()
end)
mover:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.ToggleConfig() end
end)

for key in pairs(BARS) do
    frames[key] = CreateFrame("Frame", nil, anchor)
    frames[key].key, frames[key].segs = key, {}
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

local function layoutBar(f, n)
    local c = db.bars[f.key]
    local r, g, b = unpack(c.color)
    if f.key == "power" and c.powerColor then
        local pc = PowerBarColor and PowerBarColor[select(2, UnitPowerType("player"))]
        if pc then r, g, b = pc.r, pc.g, pc.b end
    end
    f:SetSize(c.width, c.height)
    local w = (c.width - (n - 1) * PIP_GAP) / n
    for i = 1, math.max(n, #f.segs) do
        local s = f.segs[i]
        if i > n then
            s:Hide()
        else
            if not s then
                s = CreateFrame("StatusBar", nil, f)
                local bg = s:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0, 0, 0, 0.5)
                f.segs[i] = s
            end
            s:SetSize(w, c.height)
            s:SetPoint("LEFT", f, "LEFT", (i - 1) * (w + PIP_GAP), 0)
            s:SetMinMaxValues(i - 1, i) -- pip range; single bars get their real max in fill()
            paint(s, c, r, g, b)
            s:Show()
        end
    end
    if not f.text then
        f.text = f.segs[1]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.text:SetPoint("CENTER", f)
    end
    f.text:SetShown(c.text and n == 1)
    f.n = n
end

local function setText(fs, v) fs:SetText(AbbreviateNumbers(v)) end

local function fill(f)
    local v, max = BARS[f.key].value()
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

local function Refresh()
    local prev, w, h = nil, 20, 0
    for _, key in ipairs(db.order) do
        local f, c = frames[key], db.bars[key]
        local shown, n = BARS[key].state()
        local plate = key == "combo" and c.nameplate and targetPlate()
        shown = (shown and c.enabled and (plate or not c.nameplate)) and true or false
        f:SetParent(plate or anchor)
        f:SetShown(shown)
        if shown then
            layoutBar(f, n)
            fill(f)
            f:ClearAllPoints()
            if plate then
                -- ponytail: fixed spot under the nameplate; add x/y offsets if it collides with a plate addon
                f:SetPoint("TOP", plate, "BOTTOM", 0, -2)
            else
                if prev then f:SetPoint("TOP", prev, "BOTTOM", 0, -db.gap) else f:SetPoint("TOP") end
                h = h + c.height + (prev and db.gap or 0)
                w = math.max(w, c.width)
                prev = f
            end
        end
    end
    anchor:SetSize(w, math.max(h, 10))
    mover:SetShown(not db.locked)
    moverHint:SetFormattedText(HINT, db.x, db.y)
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
local cfg, selected = nil, "health"
local refreshers = {}

changed = function()
    safe(Refresh)
    for _, fn in ipairs(refreshers) do fn() end
end

local function cur() return db.bars[selected] end
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

local function slider(parent, text, x, y, min, max, get, set)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetSize(150, 16)
    s:SetPoint("TOPLEFT", x, y - 16)
    s:SetBackdrop(SLIDER_BACKDROP)
    s:SetOrientation("HORIZONTAL")
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:GetThumbTexture():SetSize(32, 32)
    s:SetMinMaxValues(min, max)
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
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(40, 20)
    box:SetPoint("LEFT", s, "RIGHT", 12, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(5) -- not SetNumeric: X/Y need a minus sign; tonumber() rejects the rest
    local function apply()
        local v = tonumber(box:GetText())
        if v then
            set(math.max(min, math.min(max, math.floor(v))))
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

local function texIndex()
    for i, t in ipairs(TEXTURES) do
        if t[2] == cur().texture then return i end
    end
    return 1
end

local function move(i, d)
    local o, j = db.order, i + d
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
    cfg:SetSize(460, 540)
    cfg:SetPoint("CENTER")
    cfg:SetFrameStrata("DIALOG")
    cfg:SetMovable(true)
    cfg:EnableMouse(true)
    cfg:RegisterForDrag("LeftButton")
    cfg:SetScript("OnDragStart", cfg.StartMoving)
    cfg:SetScript("OnDragStop", cfg.StopMovingOrSizing)
    tinsert(UISpecialFrames, cfg:GetName()) -- Escape closes it
    label(cfg, "ComboPointDisplay"):SetPoint("TOP", 0, -5)

    -- Left column: profile
    label(cfg, "Profile (account-wide)", "GameFontNormal"):SetPoint("TOPLEFT", 16, -34)
    local dd = CreateFrame("DropdownButton", nil, cfg, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", 16, -52)
    dd:SetWidth(196)
    dd:SetupMenu(function(_, root)
        for _, name in ipairs(profileNames()) do
            root:CreateRadio(name, function() return name == store.chars[charKey] end, function() useProfile(name) end)
        end
    end)
    onRefresh(function() dd:GenerateMenu() end)
    label(cfg, "New profile (copies current):", "GameFontNormalSmall"):SetPoint("TOPLEFT", 16, -82)
    local nameBox = CreateFrame("EditBox", nil, cfg, "InputBoxTemplate")
    nameBox:SetSize(124, 20)
    nameBox:SetPoint("TOPLEFT", 22, -96)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(32)
    local function create()
        createProfile(nameBox:GetText())
        nameBox:SetText("")
        nameBox:ClearFocus()
    end
    nameBox:SetScript("OnEnterPressed", create)
    nameBox:SetScript("OnEscapePressed", function() nameBox:ClearFocus() end)
    button(cfg, "Create", 60, 152, -95, create)
    button(cfg, "Delete", 96, 16, -124, function()
        local name = store.chars[charKey]
        StaticPopup_Show("COMBOPOINTDISPLAY_DELETE", name, nil, name)
    end)
    button(cfg, "Reset profile", 96, 116, -124, function()
        wipe(db)
        merge(db, DEFAULTS)
        place()
        changed()
    end)

    -- Left column: order, gap
    label(cfg, "Bars, top to bottom", "GameFontNormal"):SetPoint("TOPLEFT", 16, -162)
    for i = 1, #db.order do
        local y = -182 - (i - 1) * 26
        local sel = button(cfg, "", 110, 16, y, function() selected = db.order[i]; changed() end)
        button(cfg, "Up", 36, 128, y, function() move(i, -1) end)
        button(cfg, "Down", 46, 166, y, function() move(i, 1) end)
        onRefresh(function()
            local key = db.order[i]
            sel:SetText(BARS[key].label)
            if key == selected then sel:LockHighlight() else sel:UnlockHighlight() end
        end)
    end
    slider(cfg, "Gap between bars", 16, -294, 0, 30, function() return db.gap end, function(v) db.gap = v end)

    -- Left column: position (top-center of the bars, from the screen center)
    label(cfg, "Position", "GameFontNormal"):SetPoint("TOPLEFT", 16, -340)
    local xr, yr = math.floor(UIParent:GetWidth() / 2), math.floor(UIParent:GetHeight() / 2)
    slider(cfg, "X (left / right)", 16, -360, -xr, xr, function() return db.x end, function(v) db.x = v; place() end)
    slider(cfg, "Y (down / up)", 16, -402, -yr, yr, function() return db.y end, function(v) db.y = v; place() end)
    local lock = button(cfg, "", 96, 16, -448, function() db.locked = not db.locked; changed() end)
    onRefresh(function() lock:SetText(db.locked and "Unlock" or "Lock") end)
    local help = label(cfg, "Texture button: left-click next, right-click previous.\nMouse wheel on a slider changes it by 1.",
        "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", 16, -486)
    help:SetJustifyH("LEFT")

    -- Right column: selected bar
    local X = 236
    local header = label(cfg, "", "GameFontNormal")
    header:SetPoint("TOPLEFT", X, -34)
    onRefresh(function()
        local hidden = frames[selected]:IsShown() and "" or " |cff888888(hidden now)|r"
        header:SetText(BARS[selected].label .. hidden)
    end)
    check(cfg, "Enabled", X, -52, function() return cur().enabled end, function(v) cur().enabled = v end)
    slider(cfg, "Width", X, -84, 10, 600, function() return cur().width end, function(v) cur().width = v end)
    slider(cfg, "Height", X, -126, 2, 100, function() return cur().height end, function(v) cur().height = v end)
    local tex = button(cfg, "", 200, X, -172, function(_, btn)
        local d = btn == "RightButton" and -1 or 1
        cur().texture = TEXTURES[(texIndex() - 1 + d) % #TEXTURES + 1][2]
        changed()
    end)
    onRefresh(function() tex:SetText("Texture: " .. TEXTURES[texIndex()][1]) end)
    swatch(cfg, "Bar color", X, -202, function() return cur().color end)

    -- Bar-specific options share the row under the color swatch
    local powerColor = check(cfg, "Use power type color", X, -226,
        function() return cur().powerColor end, function(v) cur().powerColor = v end)
    local plate = check(cfg, "Show on target nameplate", X, -226,
        function() return cur().nameplate end, function(v) cur().nameplate = v end)
    local text = check(cfg, "Show text", X, -250, function() return cur().text end, function(v) cur().text = v end)
    onRefresh(function()
        powerColor:SetShown(selected == "power")
        plate:SetShown(selected == "combo")
        text:SetShown(selected ~= "combo")
    end)

    check(cfg, "Gradient", X, -280, function() return cur().gradient end, function(v) cur().gradient = v end)
    local c2 = swatch(cfg, "Gradient end color", X, -306, function() return cur().color2 end)
    local dir = button(cfg, "", 200, X, -334, function() cur().vertical = not cur().vertical; changed() end)
    onRefresh(function()
        c2:SetShown(cur().gradient)
        dir:SetShown(cur().gradient)
        dir:SetText("Direction: " .. (cur().vertical and "Vertical" or "Horizontal"))
    end)
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
local function listen(event, unit)
    if unit then pcall(ev.RegisterUnitEvent, ev, event, unit) else pcall(ev.RegisterEvent, ev, event) end
end

local function fillShown(...)
    for i = 1, select("#", ...) do
        local f = frames[select(i, ...)]
        if f:IsShown() then safe(fill, f) end
    end
end

ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- ponytail: settings saved before profiles existed are dropped (the beta never loaded them anyway)
        store = type(ComboPointDisplayDB) == "table" and ComboPointDisplayDB.profiles and ComboPointDisplayDB
            or { profiles = {}, chars = {} }
        ComboPointDisplayDB = store
        store.minimapAngle = store.minimapAngle or 220
        classProfile, class = UnitClass("player")
        charKey = UnitName("player") .. " - " .. GetRealmName()
        for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
            listen(e, "player")
        end
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
            "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
            listen(e)
        end
        local mine = store.chars[charKey]
        useProfile(store.profiles[mine or ""] and mine or classProfile)
        placeMini()
    elseif event == "UNIT_HEALTH" then
        fillShown("health")
    elseif event == "UNIT_POWER_FREQUENT" then
        fillShown("power", "combo", "druidmana")
    else -- form, max, target or nameplate changes: re-layout (target change moves the nameplate bar)
        safe(Refresh)
    end
end)
listen("PLAYER_LOGIN")
