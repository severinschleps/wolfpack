local _, ns = ...
ns.bs = ns.bs or {}
local BS = ns.bs

-- The addon owns layout, Blizzard owns state: we re-parent Cooldown Manager item frames
-- into our bars and never branch on a combat value. Blizzard keeps showing/hiding them.

local BASE, STEP = 10, 10 -- bar frame level = BASE + layer * STEP
BS.TEXTURES = { flat = "Interface\\Buttons\\WHITE8x8", blizzard = "Interface\\TargetingFrame\\UI-StatusBar" }
BS.ALL_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local stack
local containers = {} -- bar id -> container frame
local borrowed = {}   -- Blizzard item frame -> the viewer it came from

-- Which viewers a widget may borrow from, in preference order. The preferred ones come
-- first; every other viewer follows, because the picker offers spells from all four and a
-- buff put on an "always" bar must still be found rather than leave the bar empty.
local function sources(visibility, display)
  local buffs = display == "bar" and "BuffBarCooldownViewer" or "BuffIconCooldownViewer"
  local list
  if visibility == "aura" then list = { buffs }
  -- proc not tracked as an aura: fall back to the cooldown frame with Blizzard's proc glow
  elseif visibility == "proc" then list = { buffs, "EssentialCooldownViewer", "UtilityCooldownViewer" }
  else list = { "EssentialCooldownViewer", "UtilityCooldownViewer" } end
  for _, name in ipairs(BS.ALL_VIEWERS) do
    if not tContains(list, name) then list[#list + 1] = name end
  end
  return list
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
  local c = CreateFrame("Frame", nil, stack)
  c.preview = CreateFrame("Frame", nil, c)
  c.preview:SetAllPoints()
  local bg = c.preview:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.35) -- no name drawn on the bar: the config list says which is which
  containers[id] = c
  return c
end

local function place(it, c, b, j)
  if not borrowed[it] then borrowed[it] = it:GetParent() end
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

function BS.Layout()
  if not stack then return end
  hookViewers()
  local p, used, live = BS.profile, {}, {}
  BS.placed = {} -- what the last pass did with every spell, for /bs check
  local s = p.stack
  stack:ClearAllPoints()
  stack:SetPoint(s.point, UIParent, s.point, s.x, s.y)
  stack:SetScale(s.scale)
  stack:SetAlpha(s.alpha)
  local n, sw, sh = #p.bars, 40, 40
  for i, b in ipairs(p.bars) do
    b.layer = n - i + 1 -- top of the list = top layer
    local c = container(b.id)
    live[c] = true
    c:ClearAllPoints()
    c:SetPoint("CENTER", stack, "CENTER", b.offset.x, b.offset.y)
    c:SetSize(b.size.w, b.size.h)
    c:SetFrameLevel(BASE + b.layer * STEP)
    c.preview:SetFrameLevel(c:GetFrameLevel() + 5)
    c.preview:SetShown(BS.preview == true)
    c:Show()
    sw = math.max(sw, math.abs(b.offset.x) * 2 + b.size.w)
    sh = math.max(sh, math.abs(b.offset.y) * 2 + b.size.h)
    for j, sp in ipairs(b.spells) do
      local it, from = find(sp, b.visibility, used)
      BS.placed[#BS.placed + 1] = { bar = b.name, spell = sp.name or tostring(sp.baseSpell), frame = it, viewer = from, container = c }
      if it then
        used[it] = true
        place(it, c, b, j)
      end
    end
  end
  stack:SetSize(sw, sh)
  for _, c in pairs(containers) do
    if not live[c] then c:Hide() end
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
  if not stack then return end
  local s = BS.profile.stack
  stack:SetShown(BS.preview or BS.editing or (BS.inCombat and s.showInCombat) or (not BS.inCombat and s.showOutOfCombat))
end

local function savePosition()
  stack:StopMovingOrSizing()
  local s, sc = BS.profile.stack, stack:GetScale()
  local x, y = stack:GetCenter()
  local ux, uy = UIParent:GetCenter()
  s.point = "CENTER"
  s.x, s.y = math.floor(x - ux / sc + 0.5), math.floor(y - uy / sc + 0.5)
  BS.Changed()
end

function BS.SetEditing(on)
  BS.editing = on
  stack.edit:SetShown(on)
  BS.UpdateVisibility()
end

function BS.Init()
  stack = CreateFrame("Frame", "BarStackFrame", UIParent)
  stack:SetFrameStrata("MEDIUM")
  stack:SetMovable(true)
  stack:SetClampedToScreen(true)

  -- Edit Mode overlay: outline + label, drag to move. Nothing else is editable there.
  local edit = CreateFrame("Frame", nil, stack)
  edit:SetAllPoints()
  edit:SetFrameLevel(8000)
  edit:EnableMouse(true)
  edit:RegisterForDrag("LeftButton")
  edit:SetScript("OnDragStart", function() stack:StartMoving() end)
  edit:SetScript("OnDragStop", savePosition)
  local t = edit:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(0.25, 0.55, 1, 0.35)
  local label = edit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("CENTER")
  label:SetText("Bar Stack")
  edit:Hide()
  stack.edit = edit

  if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Enter", function() BS.SetEditing(true) end, stack)
    EventRegistry:RegisterCallback("EditMode.Exit", function() BS.SetEditing(false) end, stack)
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
