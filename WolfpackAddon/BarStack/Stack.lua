local _, ns = ...
ns.bs = ns.bs or {}
local BS = ns.bs

-- The addon owns layout, Blizzard owns state: we re-parent Cooldown Manager item frames
-- into our bars and never branch on a combat value. Blizzard keeps showing/hiding them.

local BASE, STEP = 10, 10 -- bar frame level = BASE + layer * STEP
BS.TEXTURES = { flat = "Interface\\Buttons\\WHITE8x8", blizzard = "Interface\\TargetingFrame\\UI-StatusBar" }
BS.ALL_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local stacks = {}     -- group id -> stack frame
BS.stacks = stacks
local containers = {} -- bar id -> container frame
local borrowed = {}   -- Blizzard item frame -> the viewer it came from

-- Bars that show only while something is up. Only Blizzard's buff viewers show and hide a
-- frame with its aura -- a debuff you put on the target and a proc buff included -- so these
-- borrow from nowhere else: a cooldown icon would simply always be there.
BS.AURA_MODES = { aura = true, debuff = true, proc = true, missing = true }

-- Which viewers a widget may borrow from, in preference order.
local function sources(visibility, display)
  local icon, bar = "BuffIconCooldownViewer", "BuffBarCooldownViewer"
  if BS.AURA_MODES[visibility] then
    if display == "bar" then return { bar, icon } end
    return { icon, bar }
  end
  -- "always": the cooldowns first, but a buff put on such a bar is still found
  return { "EssentialCooldownViewer", "UtilityCooldownViewer", icon, bar }
end

local function readSpell(item)
  local id = BS.try(item.GetSpellID, item)
  if type(id) == "number" then return id end
  local info = item.cooldownInfo or BS.try(item.GetCooldownInfo, item)
  if type(info) ~= "table" and C_CooldownViewer then
    local cd = item.cooldownID or BS.try(item.GetCooldownID, item)
    info = cd and BS.try(C_CooldownViewer.GetCooldownViewerCooldownInfo, cd)
  end
  id = type(info) == "table" and info.spellID
  if not BS.secret(id) and type(id) == "number" then return id end
end

-- In combat the answer can come back secret -- right when an aura lands and Blizzard lays its
-- viewer out again, which is when we re-match. The last readable answer for the frame stands,
-- so a debuff bar does not hand its frame back the moment the debuff goes up.
local spellOf = setmetatable({}, { __mode = "k" })
function BS.FrameSpell(item)
  local id = readSpell(item)
  if id then spellOf[item] = id end
  return spellOf[item]
end

-- Active item frames of a viewer, plus the ones we already took from it
-- (re-parented frames no longer show up as its children).
local function items(viewer)
  local list, seen = {}, {}
  local function add(it)
    if it and not seen[it] then seen[it] = true; list[#list + 1] = it end
  end
  local ok, frames = pcall(viewer.GetItemFrames, viewer)
  if ok and type(frames) == "table" then
    for _, it in ipairs(frames) do add(it) end
  elseif viewer.itemFramePool then
    pcall(function() for it in viewer.itemFramePool:EnumerateActive() do add(it) end end)
  else
    for _, it in ipairs({ viewer:GetChildren() }) do add(it) end
  end
  for it, origin in pairs(borrowed) do
    if origin == viewer then add(it) end
  end
  return list
end

-- Ranks share a name (Forever lists each rank as its own row), so match by ID or name.
function BS.Matches(item, sp)
  local id = BS.FrameSpell(item)
  return id ~= nil and (id == sp.baseSpell or BS.SpellName(id) == sp.name)
end

local function find(sp, visibility, used)
  for _, name in ipairs(sources(visibility, sp.display)) do
    local v = _G[name]
    if v then
      for _, it in ipairs(items(v)) do
        if not used[it] and BS.Matches(it, sp) then return it, name end
      end
    end
  end
end
BS.Find = find

local function container(id)
  if containers[id] then return containers[id] end
  local c = CreateFrame("Frame", nil, UIParent) -- moved onto its group's stack by Layout
  c.preview = CreateFrame("Frame", nil, c)
  c.preview:SetAllPoints()
  local bg = c.preview:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.35) -- no name drawn on the bar: the config list says which is which
  containers[id] = c
  return c
end

-- "Only while debuff is missing": Blizzard's debuff frame is parked out of sight, and an icon
-- of our own takes its slot, switched the opposite way every time Blizzard switches its frame.
-- Show/Hide say plainly which way; a secret SetShown argument is handed on to
-- SetAlphaFromBoolean without being looked at. The hooks only listen and count (for /bs check).
BS.watch = setmetatable({}, { __mode = "k" })
BS.mirror = setmetatable({}, { __mode = "k" }) -- Blizzard debuff frame -> our reminder icons
local WATCHED = { "Show", "Hide", "SetShown", "SetAlpha" }
local hideout

-- reminder visible (1) while Blizzard's frame is hidden, invisible (0) while it is shown
local function mirror(r, shown)
  if BS.secret(shown) then
    pcall(r.SetAlphaFromBoolean, r, shown, 0, 1)
  else
    r:SetAlpha(shown and 0 or 1)
  end
end

local function watch(it)
  if BS.watch[it] then return end
  local w = { Show = 0, Hide = 0, SetShown = 0, SetAlpha = 0 }
  BS.watch[it] = w
  for _, m in ipairs(WATCHED) do
    if type(it[m]) == "function" then
      hooksecurefunc(it, m, function(_, arg)
        w[m] = w[m] + 1
        if m == "SetShown" or m == "SetAlpha" then w[m .. "Secret"] = BS.secret(arg) end
        for _, r in ipairs(BS.mirror[it] or {}) do
          if m == "Show" then mirror(r, true)
          elseif m == "Hide" then mirror(r, false)
          elseif m == "SetShown" then mirror(r, arg) end
        end
      end)
    end
  end
end

-- Where spell j sits inside its bar: the whole slot, x/y from the bar's top-left.
local function slot(b, j)
  local horiz = b.orientation ~= "vertical"
  local w = horiz and b.size.w / #b.spells or b.size.w
  local h = horiz and b.size.h or b.size.h / #b.spells
  return horiz and (j - 1) * w or 0, horiz and 0 or -(j - 1) * h, w, h
end

local function reminder(c, b, j)
  c.reminders = c.reminders or {}
  local r = c.reminders[j]
  if not r then
    r = c:CreateTexture(nil, "ARTWORK")
    c.reminders[j] = r
  end
  local x, y, w, h = slot(b, j)
  local size = math.min(w, h)
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", c, "TOPLEFT", x, y)
  r:SetSize(size, size)
  r:SetTexture((C_Spell and BS.try(C_Spell.GetSpellTexture, b.spells[j].baseSpell)) or 134400)
  r:SetAlpha(1) -- missing until Blizzard's frame says otherwise
  r:Show()
  return r
end

-- Blizzard sizes its frames by scale (the viewers' icon size setting), and the art inside keeps
-- the frame's own size, so SetSize alone leaves the icon the size Blizzard drew it. The size and
-- scale a frame had when we first took it are its natural ones: we scale from those, and put
-- them back when the frame goes home.
local natural = setmetatable({}, { __mode = "k" })
local function naturalOf(it)
  local n = natural[it]
  if not n then
    local w, h, s = BS.try(it.GetWidth, it), BS.try(it.GetHeight, it), BS.try(it.GetScale, it)
    n = { w = type(w) == "number" and w >= 1 and w or 36, h = type(h) == "number" and h >= 1 and h or 36,
      scale = type(s) == "number" and s > 0 and s or 1 }
    natural[it] = n
  end
  return n
end

local function borrow(it)
  if not borrowed[it] then
    naturalOf(it)
    borrowed[it] = it:GetParent()
  end
end

-- Out of sight but still Blizzard's to show and hide: a hidden parent keeps it from drawing,
-- while its own shown flag goes on changing, which is what the hooks follow.
local function park(it)
  borrow(it)
  if not hideout then
    hideout = CreateFrame("Frame", nil, UIParent)
    hideout:Hide()
  end
  it:SetParent(hideout)
end

-- "Bar" for a spell: Blizzard's icon on the left, and a timer bar of ours beside it. The bar is
-- the icon's own child, so it comes and goes with the icon -- nothing has to be read for that.
-- Its timer is whatever Blizzard hands the icon's cooldown swipe, caught on the way in: a
-- duration object goes straight to SetTimerDuration; a start and duration are wrapped in one
-- first. Neither is looked at. /bs check says which route ran.
local TIMER_REMAINING = 1 -- Enum.StatusBarTimerDirection
BS.timerBars = setmetatable({}, { __mode = "k" })
local function hookTimer(it, bar)
  local cd = it.Cooldown
  if type(cd) ~= "table" then bar.route = "the icon has no cooldown swipe"; return end
  local function run(dur, route)
    if pcall(bar.SetTimerDuration, bar, dur, 0, TIMER_REMAINING) then bar.route = route
    else bar.failed = route end
  end
  -- Every cooldown call Blizzard makes on the swipe, by name, for /bs check: which one starts
  -- the countdown on the icon is what the bar has to catch. Counting reads nothing.
  bar.calls = {}
  local mt = getmetatable(cd)
  local methods = mt and type(mt.__index) == "table" and mt.__index or {}
  for name, fn in pairs(methods) do
    if type(fn) == "function" and (name:find("Cooldown") or name:find("Duration") or name == "Clear") then
      pcall(hooksecurefunc, cd, name, function() bar.calls[name] = (bar.calls[name] or 0) + 1 end)
    end
  end
  if type(cd.SetCooldownFromDurationObject) == "function" then
    hooksecurefunc(cd, "SetCooldownFromDurationObject", function(_, dur) run(dur, "duration object") end)
  end
  if type(cd.SetCooldown) == "function" then
    hooksecurefunc(cd, "SetCooldown", function(_, start, duration)
      local ok, dur = pcall(function()
        local d = C_DurationUtil.CreateDuration()
        d:SetTimeFromStart(start, duration)
        return d
      end)
      if ok then run(dur, "start and duration") end
    end)
  end
  if type(cd.Clear) == "function" then
    hooksecurefunc(cd, "Clear", function() bar:SetMinMaxValues(0, 1); bar:SetValue(0) end)
  end
end

local function timerBar(it, b, sp, width, height, s)
  local bar = BS.timerBars[it]
  if not bar then
    bar = CreateFrame("StatusBar", nil, it)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.5)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("LEFT", 4, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1) -- full until a timer arrives
    BS.timerBars[it] = bar
    hookTimer(it, bar)
  end
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", it, "TOPRIGHT", 0, 0)
  bar:SetSize(math.max(1, width) / s, height / s) -- the icon's child, so in its scaled units
  bar:SetStatusBarTexture(BS.TEXTURES[b.style.texture])
  bar:SetStatusBarColor(BS.Hex(b.style.color))
  bar.text:SetText(sp.name or "")
  bar:Show()
end

local function place(it, c, b, j, viewer)
  borrow(it)
  if BS.AURA_MODES[b.visibility] then watch(it) end
  local sp, n = b.spells[j], naturalOf(it)
  local x, y, w, h = slot(b, j)
  local asBar = sp.display == "bar"
  local height = asBar and h or math.min(w, h)
  local s = height / n.h
  it:SetParent(c)
  it:SetFrameStrata(c:GetFrameStrata())
  it:SetFrameLevel(c:GetFrameLevel() + 1)
  it:SetScale(s)
  it:ClearAllPoints()
  it:SetPoint("TOPLEFT", c, "TOPLEFT", x / s, y / s) -- offsets are in the frame's own scaled units
  if viewer == "BuffBarCooldownViewer" then
    -- Blizzard's own bar (Tracked Bars): as tall as the slot, as wide as the slot
    it:SetSize(w / s, n.h)
    local bar = it.Bar
    if bar and bar.SetStatusBarColor then
      -- ponytail: re-styled on each layout pass only; if Blizzard recolors bars between passes, hook the item's refresh
      pcall(bar.SetStatusBarTexture, bar, BS.TEXTURES[b.style.texture])
      pcall(bar.SetStatusBarColor, bar, BS.Hex(b.style.color))
    end
  else
    it:SetSize(n.w, n.h) -- an icon keeps its own shape; the scale makes it `height` tall
    if asBar then
      timerBar(it, b, sp, w - n.w * s, height, s)
    elseif BS.timerBars[it] then
      BS.timerBars[it]:Hide()
    end
  end
end

function BS.Hex(s)
  local r, g, b = tostring(s):match("^#?(%x%x)(%x%x)(%x%x)$")
  if not r then return 1, 1, 1 end
  return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

local hooked = {}
BS.hooks = {} -- viewer name -> the methods we managed to hook, for /bs check
local function hookViewers()
  for _, name in ipairs(BS.ALL_VIEWERS) do
    local v = _G[name]
    if v and not hooked[v] then
      hooked[v] = true
      local got = {}
      -- Blizzard re-lays out its viewers (settings change, auras appearing); take our frames back right after.
      for _, method in ipairs({ "RefreshLayout", "Layout" }) do
        if type(v[method]) == "function" then
          hooksecurefunc(v, method, function() BS.Reapply() end)
          got[#got + 1] = method
        end
      end
      BS.hooks[name] = got
    end
  end
end

-- One frame per group, made the first time the group is laid out.
local function stackFor(g)
  if stacks[g.id] then return stacks[g.id] end
  local st = CreateFrame("Frame", nil, UIParent)
  st:SetFrameStrata("MEDIUM")
  st:SetMovable(true)
  st:SetClampedToScreen(true)

  -- Edit Mode overlay: outline + the group's name, drag to move. Nothing else is editable there.
  local edit = CreateFrame("Frame", nil, st)
  edit:SetAllPoints()
  edit:SetFrameLevel(8000)
  edit:EnableMouse(true)
  edit:RegisterForDrag("LeftButton")
  edit:SetScript("OnDragStart", function() st:StartMoving() end)
  edit:SetScript("OnDragStop", function()
    st:StopMovingOrSizing()
    for _, g2 in ipairs(BS.profile.groups) do
      if stacks[g2.id] == st then
        local s, sc = g2.stack, st:GetScale()
        local x, y = st:GetCenter()
        local ux, uy = UIParent:GetCenter()
        s.point = "CENTER"
        s.x, s.y = math.floor(x - ux / sc + 0.5), math.floor(y - uy / sc + 0.5)
      end
    end
    BS.Changed()
  end)
  local t = edit:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(0.25, 0.55, 1, 0.35)
  edit.label = edit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  edit.label:SetPoint("CENTER")
  edit:SetShown(BS.editing == true)
  st.edit = edit
  stacks[g.id] = st
  return st
end

function BS.Layout()
  if not BS.ready then return end
  hookViewers()
  local used, live, liveStacks, missing = {}, {}, {}, {}
  BS.placed = {} -- what the last pass did with every spell, for /bs check
  for _, g in ipairs(BS.profile.groups) do
    local st, s = stackFor(g), g.stack
    liveStacks[st] = true
    st:ClearAllPoints()
    st:SetPoint(s.point, UIParent, s.point, s.x, s.y)
    st:SetScale(s.scale)
    st:SetAlpha(s.alpha)
    st.edit.label:SetText(g.name)
    local n, sw, sh = #g.bars, 40, 40
    for i, b in ipairs(g.bars) do
      b.layer = n - i + 1 -- top of the list = top layer
      local c = container(b.id)
      live[c] = true
      c:SetParent(st)
      c:ClearAllPoints()
      c:SetPoint("CENTER", st, "CENTER", b.offset.x, b.offset.y)
      c:SetSize(b.size.w, b.size.h)
      c:SetFrameLevel(BASE + b.layer * STEP)
      c.preview:SetFrameLevel(c:GetFrameLevel() + 5)
      c.preview:SetShown(BS.preview == true)
      sw = math.max(sw, math.abs(b.offset.x) * 2 + b.size.w)
      sh = math.max(sh, math.abs(b.offset.y) * 2 + b.size.h)
      for _, r in pairs(c.reminders or {}) do r:Hide() end
      for j, sp in ipairs(b.spells) do
        local it, from = find(sp, b.visibility, used)
        local rec = { group = g.name, bar = b.name, spell = sp.name or tostring(sp.baseSpell),
          visibility = b.visibility, frame = it, viewer = from, container = c, barFrame = c, barRef = b, index = j }
        BS.placed[#BS.placed + 1] = rec
        if b.visibility == "missing" then
          rec.reminder = reminder(c, b, j)
          missing[#missing + 1] = { rec = rec, sp = sp } -- matched after every other bar has its frame
        elseif it then
          used[it] = true
          place(it, c, b, j, from)
        end
      end
    end
    st:SetSize(sw, sh)
  end
  for _, c in pairs(containers) do
    if not live[c] then c:Hide() end
  end
  for _, st in pairs(stacks) do
    if not liveStacks[st] then st:Hide() end -- a deleted group
  end
  -- A "missing" bar only watches the frame, so it may share one another bar shows: one Rend in
  -- Tracked Bars serves both a "debuff is active" bar and a "debuff is missing" one. A frame no
  -- other bar shows is parked out of sight instead.
  BS.mirror = setmetatable({}, { __mode = "k" })
  for _, m in ipairs(missing) do
    local it, from = find(m.sp, "missing", {})
    m.rec.frame, m.rec.viewer = it, from
    if it then
      if not used[it] then
        used[it] = true
        park(it)
      end
      m.rec.container = it:GetParent()
      watch(it)
      BS.mirror[it] = BS.mirror[it] or {}
      table.insert(BS.mirror[it], m.rec.reminder)
      local ok, shown = pcall(it.IsShown, it)
      if ok then mirror(m.rec.reminder, shown) end
    end
  end
  -- ponytail: returned frames sit unanchored until Blizzard's next layout pass; we never call its layout ourselves (taint)
  for it, origin in pairs(borrowed) do
    if not used[it] then
      borrowed[it] = nil
      if BS.timerBars[it] then BS.timerBars[it]:Hide() end
      local n = natural[it]
      if n then -- home the way it came: Blizzard's size and scale
        it:SetScale(n.scale)
        it:SetSize(n.w, n.h)
        natural[it] = nil
      end
      it:SetParent(origin)
    end
  end
  BS.UpdateVisibility()
end

local busy
function BS.Reapply()
  if busy or not BS.profile then return end
  busy = true
  local ok, err = pcall(BS.Layout)
  busy = false
  if not ok then geterrorhandler()(err) end
end

-- Debuff bars, either way round, are about your target: with no target there is nothing to say.
-- UnitExists is not secret, so this is decided here, in combat too.
BS.TARGET_MODES = { debuff = true, missing = true }

function BS.UpdateVisibility()
  local placing = BS.preview or BS.editing
  local hasTarget = UnitExists("target") and true or false
  for _, g in ipairs(BS.profile.groups) do
    local st, s = stacks[g.id], g.stack
    if st then
      st:SetShown(placing or (BS.inCombat and s.showInCombat) or (not BS.inCombat and s.showOutOfCombat))
    end
    for _, b in ipairs(g.bars) do
      local c = containers[b.id]
      if c then c:SetShown(placing or hasTarget or not BS.TARGET_MODES[b.visibility]) end
    end
  end
end

function BS.SetEditing(on)
  BS.editing = on
  for _, st in pairs(stacks) do st.edit:SetShown(on) end
  BS.UpdateVisibility()
end

function BS.Init()
  BS.ready = true
  if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Enter", function() BS.SetEditing(true) end, BS)
    EventRegistry:RegisterCallback("EditMode.Exit", function() BS.SetEditing(false) end, BS)
  end
end

function BS.ViewerStats(v)
  if not v then return 0, 0 end
  local list, mapped = items(v), 0
  for _, it in ipairs(list) do
    if BS.FrameSpell(it) then mapped = mapped + 1 end
  end
  return #list, mapped
end

-- Spells currently in the Cooldown Manager, ranks grouped into one entry by name.
-- `buffsOnly`: just Tracked Buffs and Tracked Bars, which is all an aura or debuff bar can use.
function BS.AvailableSpells(buffsOnly)
  local seen, out = {}, {}
  for _, name in ipairs(buffsOnly and { "BuffIconCooldownViewer", "BuffBarCooldownViewer" } or BS.ALL_VIEWERS) do
    local v = _G[name]
    if v then
      for _, it in ipairs(items(v)) do
        local id = BS.FrameSpell(it)
        local spell = id and BS.SpellName(id)
        if spell and not seen[spell] then
          seen[spell] = true
          out[#out + 1] = { baseSpell = id, name = spell, icon = C_Spell and BS.try(C_Spell.GetSpellTexture, id) }
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end
