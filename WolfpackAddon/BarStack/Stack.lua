local _, ns = ...
ns.bs = ns.bs or {}
local BS = ns.bs

-- The addon owns layout, Blizzard owns state: we re-parent Cooldown Manager item frames
-- into our bars and never branch on a combat value. Blizzard keeps showing/hiding them.

local BASE, STEP = 10, 10 -- bar frame level = BASE + layer * STEP
-- Icons only. Tracked Bars is left alone: no addon may run an aura's timer on a bar of its own
-- (GetAuraDuration and SetTimeFromStart both refuse secrets from addon code, tried in game), and
-- Blizzard's own Tracked Bars frames turned out not to say reliably which spell they show.
BS.ALL_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }

local stacks = {}     -- group id -> stack frame
BS.stacks = stacks
local containers = {} -- bar id -> container frame
local borrowed = {}   -- Blizzard item frame -> the viewer it came from

-- Bars that show only while something is up. Only Blizzard's buff viewers show and hide a
-- frame with its aura -- a debuff you put on the target and a proc buff included -- so these
-- borrow from nowhere else: a cooldown icon would simply always be there.
BS.AURA_MODES = { aura = true, debuff = true, proc = true, missing = true }

-- Which viewers a widget may borrow from, in preference order.
local function sources(visibility)
  if BS.AURA_MODES[visibility] then return { "BuffIconCooldownViewer" } end
  -- "always": the cooldowns first, but a buff put on such a bar is still found
  return { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
end

-- The spell a frame is showing, and whether an answer came back secret on the way. A secret is
-- noted, never looked at; nil means the frame holds no spell at all (Blizzard has cleared it).
local function readSpell(item)
  local secret = false
  local function seen(v)
    if BS.secret(v) then secret = true; return nil end
    return v
  end
  local ok, id = pcall(item.GetSpellID, item)
  if not ok then secret = true end -- could not ask: as unknown as a secret (a cleared frame answers nil)
  id = ok and seen(id) or nil
  if type(id) == "number" then return id end
  local okInfo, info = pcall(function() return seen(item.cooldownInfo) or seen(item:GetCooldownInfo()) end)
  info = okInfo and info or nil
  if type(info) ~= "table" and C_CooldownViewer then
    local okCD, cd = pcall(function() return seen(item.cooldownID) or seen(item:GetCooldownID()) end)
    if okCD and cd then
      local okLook, found = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cd)
      info = okLook and seen(found) or nil
    end
  end
  if type(info) == "table" then
    id = seen(info.spellID)
    if type(id) == "number" then return id end
  end
  return nil, secret
end

-- In combat the answer can come back secret -- right when an aura lands and Blizzard lays its
-- viewer out again, which is when we re-match. Then the last readable answer for the frame
-- stands. But a frame that answers nothing has been cleared by Blizzard, and is forgotten: it
-- must not go on standing for a spell it no longer shows.
local spellOf = setmetatable({}, { __mode = "k" })
function BS.FrameSpell(item)
  local id, secret = readSpell(item)
  if id then
    spellOf[item] = id
  elseif not secret then
    spellOf[item] = nil
  end
  return spellOf[item]
end

-- Active item frames of a viewer, plus the ones we already took from it
-- (re-parented frames no longer show up as its children).
local function items(viewer)
  local list, seen = {}, {}
  local function add(it)
    if it and not seen[it] then seen[it] = true; list[#list + 1] = it end
  end
  -- Blizzard lists only the frames still inside its viewer, so the ones we have moved into a
  -- stack are added back. A frame Blizzard has since cleared is still listed, but answers no
  -- spell (see FrameSpell), so it matches nothing.
  local ok, frames = pcall(viewer.GetItemFrames, viewer)
  if ok and type(frames) == "table" then
    for _, it in ipairs(frames) do add(it) end
  elseif not (viewer.itemFramePool
    and pcall(function() for it in viewer.itemFramePool:EnumerateActive() do add(it) end end)) then
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
  for _, name in ipairs(sources(visibility)) do
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
-- The border plate behind one of our own icons, which must come and go with it.
BS.borderOf = setmetatable({}, { __mode = "k" })
local function mirror(r, shown)
  for _, t in ipairs({ r, BS.borderOf[r] }) do
    if BS.secret(shown) then
      pcall(t.SetAlphaFromBoolean, t, shown, 0, 1)
    else
      t:SetAlpha(shown and 0 or 1)
    end
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

-- Where spell j sits inside its bar: one icon's slot (size is per icon), x/y from the bar's top-left.
local function slot(b, j)
  local horiz, w, h = b.orientation ~= "vertical", b.size.w, b.size.h
  return horiz and (j - 1) * w or 0, horiz and 0 or -(j - 1) * h, w, h
end

-- The whole bar: one slot per spell, along the way the icons run.
function BS.BarSize(b)
  local n = math.max(1, #b.spells)
  if b.orientation == "vertical" then return b.size.w, b.size.h * n end
  return b.size.w * n, b.size.h
end

-- A cooldown swipe over one of our own icons. The cooldown is secret in combat, but WoW hands
-- out a duration object that a Cooldown frame plays by itself, so nothing is read -- the same
-- way Wolfpack's cast bar drains. The GCD shows too, as on any action button.
local function swipeFor(c, j, r)
  c.swipes = c.swipes or {}
  local cd = c.swipes[j]
  if not cd then
    cd = CreateFrame("Cooldown", nil, c, "CooldownFrameTemplate")
    c.swipes[j] = cd
  end
  cd:ClearAllPoints()
  cd:SetAllPoints(r)
  cd:Show()
  return cd
end

-- Returns which route ran, or each route's own error, for /bs check.
BS.swipeSeen = {} -- bar id -> how its first spell's swipe was fed
local function feedSwipe(cd, id)
  local why = {}
  local ok, err = pcall(function() cd:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(id)) end)
  if ok then return "duration object" end
  why[#why + 1] = "duration object: " .. tostring(err)
  ok, err = pcall(function()
    local info = C_Spell.GetSpellCooldown(id)
    cd:SetCooldown(info.startTime, info.duration, info.modRate)
  end)
  if ok then return "start and duration" end
  why[#why + 1] = "start and duration: " .. tostring(err)
  return "none -- " .. table.concat(why, " | ")
end

-- The icon style, on any icon texture -- ours, or the one inside a frame we borrowed. The border
-- is a plate behind the icon, cut to the same shape by its own mask.
local MASKS = { [12] = "i12", [25] = "i25", [50] = "i50" } -- Wolfpack's own Media/Icon art
local MASK_PATH = "Interface\\AddOns\\WolfpackAddon\\Media\\Icon\\"
local maskOn = setmetatable({}, { __mode = "k" }) -- mask -> on its texture
local function setMask(tex, m, file)
  if file then
    m:SetTexture(MASK_PATH .. file .. ".tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not maskOn[m] then tex:AddMaskTexture(m); maskOn[m] = true end
  elseif maskOn[m] then
    tex:RemoveMaskTexture(m)
    maskOn[m] = nil
  end
end

-- `owner` is the frame the icon lives in, so the plate shows and hides with it: our bar for our
-- own icons, Blizzard's frame for a borrowed one. `scale` is that frame's, so the border stays
-- `border` px on screen. The records live here, never as fields on Blizzard's frame.
local styleSets = setmetatable({}, { __mode = "k" }) -- owner frame -> { key -> style }
local function styleIcon(tex, owner, key, scale)
  local st = BS.profile.icons
  local z = st.zoom / 100
  tex:SetTexCoord(z, 1 - z, z, 1 - z)
  styleSets[owner] = styleSets[owner] or {}
  local k = styleSets[owner][key]
  if not k then
    k = { border = owner:CreateTexture(nil, "BACKGROUND", nil, -8) }
    k.borderMask = owner:CreateMaskTexture()
    styleSets[owner][key] = k
  end
  if k.tex ~= tex then -- a new texture in this slot: its mask has to belong to its own frame
    if k.tex and k.iconMask then setMask(k.tex, k.iconMask, nil) end
    k.tex, k.iconMask = tex, (tex:GetParent() or owner):CreateMaskTexture()
  end
  local file, e = MASKS[st.radius], st.border / (scale or 1)
  k.iconMask:SetAllPoints(tex)
  setMask(tex, k.iconMask, file)
  k.border:ClearAllPoints()
  k.border:SetPoint("TOPLEFT", tex, "TOPLEFT", -e, e)
  k.border:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", e, -e)
  k.border:SetColorTexture(st.color[1], st.color[2], st.color[3], st.color[4])
  k.borderMask:SetAllPoints(k.border)
  setMask(k.border, k.borderMask, file)
  k.border:SetShown(e > 0)
  k.border:SetAlpha(1)
  return k
end

-- Blizzard's crop on a borrowed icon, to put back when the frame goes home.
local styled = setmetatable({}, { __mode = "k" }) -- borrowed frame -> { tex, key style, coords }

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
  BS.borderOf[r] = styleIcon(r, c, "own" .. j).border
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

-- An icon, as tall as its slot allows and square, scaled from Blizzard's own size.
local function place(it, c, b, j)
  borrow(it)
  if BS.AURA_MODES[b.visibility] then watch(it) end
  local n = naturalOf(it)
  local x, y, w, h = slot(b, j)
  local s = math.min(w, h) / n.h
  it:SetParent(c)
  it:SetFrameStrata(c:GetFrameStrata())
  it:SetFrameLevel(c:GetFrameLevel() + 1)
  it:SetScale(s)
  it:ClearAllPoints()
  it:SetPoint("TOPLEFT", c, "TOPLEFT", x / s, y / s) -- offsets are in the frame's own scaled units
  it:SetSize(n.w, n.h) -- an icon keeps its own shape; the scale sets its size
  local tex = it.Icon
  if type(tex) == "table" and tex.SetTexCoord then
    if not styled[it] then styled[it] = { tex = tex, coords = { tex:GetTexCoord() } } end
    styled[it].k = styleIcon(tex, it, "plate", s)
  end
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
      local bw, bh = BS.BarSize(b)
      c:SetSize(bw, bh)
      c:SetFrameLevel(BASE + b.layer * STEP)
      c.preview:SetFrameLevel(c:GetFrameLevel() + 5)
      c.preview:SetShown(BS.preview == true)
      sw = math.max(sw, math.abs(b.offset.x) * 2 + bw)
      sh = math.max(sh, math.abs(b.offset.y) * 2 + bh)
      for _, r in pairs(c.reminders or {}) do r:Hide() end
      for _, cd in pairs(c.swipes or {}) do cd:Hide() end
      for _, k in pairs(styleSets[c] or {}) do k.border:Hide() end -- styleIcon shows the ones in use
      for j, sp in ipairs(b.spells) do
        -- a usable bar draws its own icon and borrows nothing (see below)
        local it, from
        if b.visibility ~= "usable" then it, from = find(sp, b.visibility, used) end
        local rec = { group = g.name, bar = b.name, spell = sp.name or tostring(sp.baseSpell),
          visibility = b.visibility, frame = it, viewer = from, container = c, barFrame = c, barRef = b, index = j }
        BS.placed[#BS.placed + 1] = rec
        if b.visibility == "missing" then
          rec.reminder = reminder(c, b, j)
          missing[#missing + 1] = { rec = rec, sp = sp } -- matched after every other bar has its frame
        elseif b.visibility == "usable" then
          -- Blizzard refreshes its icon's usable look only while the frame sits in its own viewer, so
          -- a borrowed one froze in its "not usable" look. This bar only shows while the spell can
          -- be pressed, so our own plain icon is always the right look.
          rec.reminder = reminder(c, b, j)
          rec.swipe = swipeFor(c, j, rec.reminder)
        elseif it then
          used[it] = true
          place(it, c, b, j)
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
  -- Tracked Buffs serves both a "debuff is active" bar and a "debuff is missing" one. A frame no
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
      local sty = styled[it]
      if sty then -- Blizzard's own crop back, our mask off; the border stays with our bar
        if #sty.coords == 8 then pcall(sty.tex.SetTexCoord, sty.tex, unpack(sty.coords)) end
        if sty.k and sty.k.iconMask then setMask(sty.tex, sty.k.iconMask, nil) end
        if sty.k then sty.k.border:Hide() end -- our plate leaves Blizzard's frame with us
        styled[it] = nil
      end
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
  BS.UpdateUsable()
end

-- "Only while usable": WoW's own answer to "can I press this now?" -- enough rage, the target low
-- enough for Execute, a proc like Sudden Death -- the same one the action bar shows. A readable
-- answer sets the bar's opacity; a secret one is handed to SetAlphaFromBoolean unread. The bar's
-- first spell decides (ponytail: per-spell slots if a bar ever needs several usable spells).
BS.usableSeen = {} -- bar id -> what the last ask returned, for /bs check
local function usableOf(id)
  local ok, u = pcall(C_Spell.IsSpellUsable, id)
  if not ok then ok, u = pcall(IsUsableSpell, id) end
  if ok then return u end
end

function BS.UpdateUsable()
  local placing = BS.preview or BS.editing
  for _, g in ipairs(BS.profile.groups) do
    for _, b in ipairs(g.bars) do
      local c, sp = containers[b.id], b.spells[1]
      if c and b.visibility == "usable" then
        for j, cd in pairs(c.swipes or {}) do
          if b.spells[j] then
            local how = feedSwipe(cd, b.spells[j].baseSpell)
            if j == 1 then BS.swipeSeen[b.id] = how end
          end
        end
        if placing or not sp then
          c:SetAlpha(1)
        else
          local u = usableOf(sp.baseSpell)
          if BS.secret(u) then
            BS.usableSeen[b.id] = "secret"
            if not pcall(c.SetAlphaFromBoolean, c, u, 1, 0) then c:SetAlpha(1) end
          else
            BS.usableSeen[b.id] = tostring(u)
            c:SetAlpha(u and 1 or 0)
          end
        end
      elseif c then
        c:SetAlpha(1) -- a bar switched away from "usable" must not stay invisible
      end
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

-- /bs frames: every frame of every viewer, and what each way of asking "which spell are you?"
-- answers right now -- a value, "secret", "nil" or "error". Asking reads nothing secret: a secret
-- is only reported as such.
function BS.Frames()
  local function d(fn)
    local ok, v = pcall(fn)
    if not ok then return "error" end
    if BS.secret(v) then return "secret" end
    return tostring(v)
  end
  for _, name in ipairs(BS.ALL_VIEWERS) do
    local v = _G[name]
    if not v then
      print("|cffC79C6EBar Stack|r " .. name .. ": missing")
    else
      local ok, frames = pcall(v.GetItemFrames, v)
      print(("|cffC79C6EBar Stack|r %s: list from %s"):format(name, ok and type(frames) == "table" and "GetItemFrames"
        or v.itemFramePool and "itemFramePool" or "its children"))
      for i, it in ipairs(items(v)) do
        local function info() return it.cooldownInfo or it:GetCooldownInfo() end
        print(("  %d %s | GetSpellID %s | cooldownID %s / GetCooldownID %s | info.spellID %s, override %s"
          .. " | by cooldownID %s | ours %s"):format(i,
          d(function() return it:IsShown() and "shown" or "hidden" end),
          d(function() return it:GetSpellID() end),
          d(function() return it.cooldownID end), d(function() return it:GetCooldownID() end),
          d(function() return info().spellID end), d(function() return info().overrideSpellID end),
          d(function()
            return C_CooldownViewer.GetCooldownViewerCooldownInfo(it.cooldownID or it:GetCooldownID()).spellID
          end),
          tostring(BS.FrameSpell(it))))
      end
    end
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
-- `buffsOnly`: just Tracked Buffs, which is all an aura or debuff bar can use.
function BS.AvailableSpells(buffsOnly)
  local seen, out = {}, {}
  for _, name in ipairs(buffsOnly and { "BuffIconCooldownViewer" } or BS.ALL_VIEWERS) do
    local v = _G[name]
    if v then
      for _, it in ipairs(items(v)) do
        local id = BS.FrameSpell(it)
        local spell = id and BS.SpellName(id)
        if spell and not seen[spell] then
          seen[spell] = true
          out[#out + 1] = { baseSpell = id, name = spell, icon = C_Spell and BS.try(C_Spell.GetSpellTexture, id),
            viewer = name }
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end
