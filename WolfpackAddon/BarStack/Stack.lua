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

-- An icon's picture can be Blizzard's own Cooldown Manager icon, which keeps its timer and
-- charges. "aura" takes it from Tracked Buffs only, which shows and hides it with the aura -- a
-- debuff on the target and a proc included. "cooldown" takes the cooldown icon, which is always up.
local function sources(look)
  if look == "aura" then return { "BuffIconCooldownViewer" } end
  -- the cooldowns first, but a buff given this look is still found
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

local function find(sp, look, used)
  for _, name in ipairs(sources(look)) do
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
  c.panes, c.gates = {}, {}
  containers[id] = c
  return c
end

-- Conditions. Each icon sits in a pane, and each of its conditions is one frame chained between
-- the bar and that pane. Alpha multiplies down the chain, so the icon shows only while every
-- condition says yes -- an AND that never reads the answers, which in combat are secret.
-- "usable" asks WoW and "target" asks whether you have one (see UpdateUsable); "active" and
-- "missing" follow Blizzard's Tracked Buffs frame for the aura, whose Show / Hide we hook.
BS.watch = setmetatable({}, { __mode = "k" })
BS.gates = {}                                 -- this layout's gates: { gate, cond, bar, icon, frame }
BS.gated = setmetatable({}, { __mode = "k" }) -- Blizzard aura frame -> the gates it drives
local WATCHED = { "Show", "Hide", "SetShown", "SetAlpha" }
local GATE_ALPHA = { usable = { 1, 0 }, target = { 1, 0 }, active = { 1, 0 }, missing = { 0, 1 },
  form = { 1, 0 }, noform = { 0, 1 }, stealth = { 1, 0 }, nostealth = { 0, 1 } }
local hideout

-- alpha `on` while the answer is yes, `off` while it is no; a secret is handed on unread
local function follow(t, yes, on, off)
  if BS.secret(yes) then
    pcall(t.SetAlphaFromBoolean, t, yes, on, off)
  else
    t:SetAlpha(yes and on or off)
  end
end

-- Conditions stay live while the page is open ("Show all bars" shows each bar's box, so there is
-- still something to place): what you see while you build an icon is what it does in play.
local function setGate(q, v)
  local a = GATE_ALPHA[q.cond.kind]
  follow(q.gate, v, a[1], a[2])
end

-- Icon j's pane, under a chain of n condition frames hung from the bar.
local function paneFor(c, j, n)
  c.gates[j] = c.gates[j] or {}
  local chain, parent, level = c.gates[j], c, c:GetFrameLevel() + 1
  for k = 1, n do
    local g = chain[k] or CreateFrame("Frame", nil, parent)
    chain[k] = g
    g:SetParent(parent)
    g:SetFrameLevel(level)
    g:SetAlpha(1)
    g:Show()
    parent = g
  end
  local pane = c.panes[j] or CreateFrame("Frame", nil, parent)
  c.panes[j] = pane
  pane:SetParent(parent)
  pane:SetFrameLevel(level)
  pane:ClearAllPoints()
  pane:SetAllPoints(c)
  pane:Show()
  return pane
end

-- The hooks only listen: they count Blizzard's calls (for /bs check) and pass the answer on.
local function watch(it)
  if BS.watch[it] then return end
  local w = { Show = 0, Hide = 0, SetShown = 0, SetAlpha = 0 }
  BS.watch[it] = w
  for _, m in ipairs(WATCHED) do
    if type(it[m]) == "function" then
      hooksecurefunc(it, m, function(_, arg)
        w[m] = w[m] + 1
        if m == "SetShown" or m == "SetAlpha" then w[m .. "Secret"] = BS.secret(arg) end
        for _, q in ipairs(BS.gated[it] or {}) do
          if m == "Show" then setGate(q, true)
          elseif m == "Hide" then setGate(q, false)
          elseif m == "SetShown" then setGate(q, arg) end
        end
      end)
    end
  end
end

-- Where spell j sits inside its bar: one icon's slot (size is per icon), x/y from the bar's top-left.
local function slot(b, j)
  local horiz, w, h = b.orientation ~= "vertical", b.size.w, b.size.h
  return horiz and (j - 1) * (w + b.gap) or 0, horiz and 0 or -(j - 1) * (h + b.gap), w, h
end

-- The whole bar: one slot per icon, along the way the icons run.
function BS.BarSize(b)
  local n = math.max(1, #b.icons)
  local gaps = (n - 1) * (b.gap or 0)
  if b.orientation == "vertical" then return b.size.w, b.size.h * n + gaps end
  return b.size.w * n + gaps, b.size.h
end

-- A cooldown swipe over one of our own icons. The cooldown is secret in combat, but WoW hands
-- out a duration object that a Cooldown frame plays by itself, so nothing is read -- the same
-- way Wolfpack's cast bar drains. The GCD shows too, as on any action button.
local function swipeFor(pane, r)
  local cd = pane.swipe
  if not cd then
    cd = CreateFrame("Cooldown", nil, pane, "CooldownFrameTemplate")
    pane.swipe = cd
  end
  cd:ClearAllPoints()
  cd:SetAllPoints(r)
  cd:Show()
  return cd
end

-- Returns which route ran, or each route's own error, for /bs check.
BS.swipeSeen = setmetatable({}, { __mode = "k" }) -- icon -> how its swipe was fed
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

-- What an icon of our own shows: the texture typed in (a file ID, a path, or a spell's name),
-- else its spell's picture, else a question mark.
function BS.IconTexture(ic)
  local t = ic.texture
  if t then
    local tex = tonumber(t) or (C_Spell and BS.try(C_Spell.GetSpellTexture, t))
    if tex then return tex end
    if type(t) == "string" and t:find("[/\\]") then return t end
  end
  return ic.spell and C_Spell and BS.try(C_Spell.GetSpellTexture, ic.spell.baseSpell) or 134400
end

BS.borderOf = setmetatable({}, { __mode = "k" }) -- our own icon -> the plate behind it

-- An icon of our own, in its slot, styled like every other icon.
local function ownIcon(pane, b, j, ic)
  local r = pane.own
  if not r then
    r = pane:CreateTexture(nil, "ARTWORK")
    pane.own = r
  end
  local x, y, w, h = slot(b, j)
  local size = math.min(w, h)
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", pane, "TOPLEFT", x, y)
  r:SetSize(size, size)
  r:SetTexture(BS.IconTexture(ic))
  r:Show()
  BS.borderOf[r] = styleIcon(r, pane, "own").border
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
local function place(it, c, b, j, aura)
  borrow(it)
  if aura then watch(it) end -- only counts, for /bs check
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

-- Wolfpack's Combat Display, when the group hangs on one of its edges; or one of its three icon
-- stacks (slot1..slot3) over its middle column
function BS.AnchorFrame(s)
  local n = tonumber(tostring(s.anchor):match("^slot(%d)$"))
  if n then return ns.iconSlot and ns.iconSlot(n) or nil end
  return s.anchor ~= "screen" and WolfpackAddonFrame or nil
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
        local cd = BS.AnchorFrame(s)
        if cd then -- from the edge's middle, in the stack's own units
          -- (an icon stack: from its bottom, the group's bottom on it, like the top edge's)
          local r, top = cd:GetEffectiveScale() / st:GetEffectiveScale(), s.anchor == "top"
          local edge = (top and cd:GetTop() or cd:GetBottom()) * r
          ux, uy, y = cd:GetCenter() * r, edge, s.anchor ~= "bottom" and st:GetBottom() or st:GetTop()
          sc = 1
        end
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
  local used, live, liveStacks = {}, {}, {}
  BS.gates = {}
  BS.placed = {} -- what the last pass did with every icon, for /bs check
  for _, g in ipairs(BS.profile.groups) do
    local st, s, bars = stackFor(g), g.stack, BS.LoadedBars(g)
    liveStacks[st] = #bars > 0 -- a group with nothing loaded on this character stays hidden
    st:ClearAllPoints()
    local cd = BS.AnchorFrame(s)
    if cd and s.anchor:match("^slot") then -- an icon stack: growing up from its bottom
      st:SetPoint("BOTTOM", cd, "BOTTOM", s.x, s.y)
    elseif cd then -- hung on the edge: below the bottom, above the top
      local top = s.anchor == "top"
      st:SetPoint(top and "BOTTOM" or "TOP", cd, top and "TOP" or "BOTTOM", s.x, s.y)
    else
      st:SetPoint(s.point, UIParent, s.point, s.x, s.y)
    end
    st:SetScale(s.scale)
    st:SetAlpha(s.alpha)
    st.edit.label:SetText(g.name)
    local n, sw, sh = #bars, 40, 40
    for i, b in ipairs(bars) do
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
      for j, pane in pairs(c.panes) do
        if pane.own then pane.own:Hide() end
        if pane.swipe then pane.swipe:Hide() end
        for _, k in pairs(styleSets[pane] or {}) do k.border:Hide() end -- styleIcon shows the ones in use
        if j > #b.icons then pane:Hide() end
      end
      for j, ic in ipairs(b.icons) do
        local pane = paneFor(c, j, #ic.conditions)
        for k, cond in ipairs(ic.conditions) do
          BS.gates[#BS.gates + 1] = { gate = c.gates[j][k], cond = cond, bar = b, icon = ic }
        end
        local rec = { group = g.name, bar = b.name, spell = BS.IconName(ic), look = ic.look,
          container = pane, barFrame = c, barRef = b, icon = ic, index = j }
        BS.placed[#BS.placed + 1] = rec
        if ic.look == "custom" then
          -- our own picture: Blizzard's usable look only refreshes inside its own viewer, and a
          -- custom texture has no frame of Blizzard's at all
          rec.reminder = ownIcon(pane, b, j, ic)
          if ic.swipe and ic.spell then rec.swipe = swipeFor(pane, rec.reminder) end
        else
          local it, from = find(ic.spell, ic.look, used)
          rec.frame, rec.viewer = it, from
          if it then
            used[it] = true
            place(it, pane, b, j, ic.look == "aura")
          end
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
  -- An aura condition only watches Blizzard's frame, so it may share one an icon shows: one Rend
  -- in Tracked Buffs serves a "Rend is up" icon and a "Rend is missing" one. A frame nothing
  -- shows is parked out of sight instead.
  BS.gated = setmetatable({}, { __mode = "k" })
  for _, q in ipairs(BS.gates) do
    if q.cond.kind == "active" or q.cond.kind == "missing" then
      local it = find(q.cond, "aura", {})
      q.frame = it or false
      if it then
        if not used[it] then
          used[it] = true
          park(it)
        end
        watch(it)
        BS.gated[it] = BS.gated[it] or {}
        table.insert(BS.gated[it], q)
      end
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

-- Blizzard fills a viewer's icons only while the viewer is shown: hidden by its Visibility in Edit
-- Mode, it has nothing for Bar Stack to read (seen in game: every frame empty, in and out of
-- combat). So it stays shown and goes invisible here instead, and comes back in Edit Mode to be
-- placed. Blizzard's own Opacity setting calls SetAlpha too; the hook puts 0 back.
local faded, fadeHooked = false, {}
function BS.FadeViewers()
  local hide = BS.profile.hideBlizzard and not BS.editing
  if not hide and not faded then return end -- never touched: Blizzard's opacity is its own
  faded = hide
  for _, name in ipairs(BS.ALL_VIEWERS) do
    local v = _G[name]
    if v and type(v.SetAlpha) == "function" then
      if not fadeHooked[v] then
        fadeHooked[v] = true
        hooksecurefunc(v, "SetAlpha", function(self, a) if faded and a ~= 0 then self:SetAlpha(0) end end)
      end
      v:SetAlpha(hide and 0 or 1)
    end
  end
end

function BS.UpdateVisibility()
  BS.FadeViewers()
  local placing = BS.preview or BS.editing
  for _, g in ipairs(BS.profile.groups) do
    local st, s = stacks[g.id], g.stack
    local bars = BS.LoadedBars(g)
    if st then
      st:SetShown(#bars > 0 and (placing or (BS.inCombat and s.showInCombat) or (not BS.inCombat and s.showOutOfCombat)))
    end
    for _, b in ipairs(bars) do
      if containers[b.id] then containers[b.id]:Show() end
    end
  end
  BS.UpdateUsable()
end

-- "usable": WoW's own answer to "can I press this now?" -- enough rage, the target low enough
-- for Execute, a proc like Sudden Death -- the same one the action bar shows.
local function usableOf(id)
  local ok, u = pcall(C_Spell.IsSpellUsable, id)
  if not ok then ok, u = pcall(IsUsableSpell, id) end
  if ok then return u end
end
BS.usableOf = usableOf

-- Stances and forms: the stance bar's slots, each with its spell and whether it is the one you
-- are in. The spell ID is learned while it reads plainly, so a secret one still finds its slot;
-- the "active" answer is handed on unread either way. Not on your stance bar: not in it.
local formSlot = {} -- form spell -> its slot on the stance bar
function BS.FormActive(id)
  for i = 1, (BS.try(GetNumShapeshiftForms) or 0) do
    local ok, _, active, _, sid = pcall(GetShapeshiftFormInfo, i)
    if ok then
      if sid and not BS.secret(sid) then formSlot[sid] = i end
      if formSlot[id] == i then return active end
    end
  end
  return false
end

-- Your stances and forms, for the picker.
function BS.Forms()
  local out = {}
  for i = 1, (BS.try(GetNumShapeshiftForms) or 0) do
    local ok, icon, _, _, sid = pcall(GetShapeshiftFormInfo, i)
    if ok and sid and not BS.secret(sid) then
      out[#out + 1] = { baseSpell = sid, name = BS.SpellName(sid) or ("Form " .. i),
        icon = not BS.secret(icon) and icon or nil }
    end
  end
  return out
end

-- Every condition asked afresh, and every swipe fed. An aura condition whose aura is not in
-- Tracked Buffs cannot be judged and stays out of the way (the window says why).
function BS.UpdateUsable()
  local hasTarget = UnitExists("target") and true or false
  for _, q in ipairs(BS.gates) do
    local kind = q.cond.kind
    if kind == "usable" then
      setGate(q, usableOf(q.cond.baseSpell))
    elseif kind == "target" then
      setGate(q, hasTarget)
    elseif kind == "form" or kind == "noform" then
      setGate(q, BS.FormActive(q.cond.baseSpell))
    elseif kind == "stealth" or kind == "nostealth" then
      local ok, s = pcall(IsStealthed)
      setGate(q, ok and s)
    elseif q.frame then
      local ok, shown = pcall(q.frame.IsShown, q.frame)
      if ok then setGate(q, shown) end
    else
      q.gate:SetAlpha(1)
    end
  end
  for _, r in ipairs(BS.placed or {}) do
    if r.swipe then BS.swipeSeen[r.icon] = feedSwipe(r.swipe, r.icon.spell.baseSpell) end
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
