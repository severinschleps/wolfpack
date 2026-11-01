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
BS.AURA_MODES = { aura = true, debuff = true, proc = true }

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

function BS.FrameSpell(item)
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

-- How Blizzard shows and hides a buff frame, counted per call. Show/Hide (or SetShown with a
-- readable argument) would let a bar do the opposite -- show an icon while a debuff is missing;
-- a secret alpha would not. /bs check reports it. Hooks only listen, they change nothing.
BS.watch = setmetatable({}, { __mode = "k" })
local WATCHED = { "Show", "Hide", "SetShown", "SetAlpha" }
local function watch(it)
  if BS.watch[it] then return end
  local w = { Show = 0, Hide = 0, SetShown = 0, SetAlpha = 0 }
  BS.watch[it] = w
  for _, m in ipairs(WATCHED) do
    if type(it[m]) == "function" then
      hooksecurefunc(it, m, function(_, arg)
        w[m] = w[m] + 1
        if m == "SetShown" or m == "SetAlpha" then w[m .. "Secret"] = BS.secret(arg) end
      end)
    end
  end
end

local function place(it, c, b, j)
  if not borrowed[it] then borrowed[it] = it:GetParent() end
  if BS.AURA_MODES[b.visibility] then watch(it) end
  local sp, horiz = b.spells[j], b.orientation ~= "vertical"
  local w = horiz and b.size.w / #b.spells or b.size.w
  local h = horiz and b.size.h or b.size.h / #b.spells
  local x, y = horiz and (j - 1) * w or 0, horiz and 0 or -(j - 1) * h
  if sp.display ~= "bar" or b.visibility == "always" then w = math.min(w, h); h = w end
  it:SetParent(c)
  it:SetFrameStrata(c:GetFrameStrata())
  it:SetFrameLevel(c:GetFrameLevel() + 1)
  it:ClearAllPoints()
  it:SetPoint("TOPLEFT", c, "TOPLEFT", x, y)
  it:SetSize(w, h)
  local bar = it.Bar
  if bar and bar.SetStatusBarColor then
    -- ponytail: re-styled on each layout pass only; if Blizzard recolors bars between passes, hook the item's refresh
    pcall(bar.SetStatusBarTexture, bar, BS.TEXTURES[b.style.texture])
    pcall(bar.SetStatusBarColor, bar, BS.Hex(b.style.color))
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
  local used, live, liveStacks = {}, {}, {}
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
      c:Show()
      sw = math.max(sw, math.abs(b.offset.x) * 2 + b.size.w)
      sh = math.max(sh, math.abs(b.offset.y) * 2 + b.size.h)
      for j, sp in ipairs(b.spells) do
        local it, from = find(sp, b.visibility, used)
        BS.placed[#BS.placed + 1] = { group = g.name, bar = b.name, spell = sp.name or tostring(sp.baseSpell),
          visibility = b.visibility, frame = it, viewer = from, container = c }
        if it then
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
  -- ponytail: returned frames sit unanchored until Blizzard's next layout pass; we never call its layout ourselves (taint)
  for it, origin in pairs(borrowed) do
    if not used[it] then
      borrowed[it] = nil
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

function BS.UpdateVisibility()
  for _, g in ipairs(BS.profile.groups) do
    local st, s = stacks[g.id], g.stack
    if st then
      st:SetShown(BS.preview or BS.editing or (BS.inCombat and s.showInCombat) or (not BS.inCombat and s.showOutOfCombat))
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
function BS.AvailableSpells()
  local seen, out = {}, {}
  for _, name in ipairs(BS.ALL_VIEWERS) do
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
