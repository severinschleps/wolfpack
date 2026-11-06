-- Bar Stack, part of Wolfpack: its own table on the addon's namespace, so its names
-- (ToggleConfig, Save, profile...) never meet Wolfpack's.
local _, ns = ...
ns.bs = ns.bs or {}
local BS = ns.bs

BS.isForever = select(4, GetBuildInfo()) < 100000
BS.inCombat = false

function BS.secret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- pcall wrapper for every Blizzard read; errors and secret values both come back as nil ("unknown")
function BS.try(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, v = pcall(fn, ...)
  if ok and not BS.secret(v) then return v end
end

function BS.SpellName(id) return C_Spell and BS.try(C_Spell.GetSpellName, id) end

function BS.Clamp(v, lo, hi)
  if type(v) ~= "number" or v ~= v then return lo end
  return math.min(hi, math.max(lo, v))
end

------------------------------------------------------------------------
-- Profile schema
------------------------------------------------------------------------

-- How every icon looks: zoom crops the art's edges (percent per side), a border plate of `border`
-- px sits behind it, and `radius` rounds both (0 square, 12 / 25 small and medium, 50 a circle).
local ICON_DEFAULTS = { zoom = 8, border = 2, color = { 0, 0, 0, 1 }, radius = 12 }
BS.RADII = { [0] = true, [12] = true, [25] = true, [50] = true }
-- anchor: "screen" (x / y from its center), or "top" / "bottom": on that edge of Wolfpack's Combat
-- Display, x / y from the edge's middle, so it moves along as the display grows or shrinks; or
-- "slot1".."slot3": one of its icon stacks over the middle column, growing up from its bottom.
-- size: one icon, for every bar of the group that has no size of its own. class: the class file
-- name ("WARLOCK") the group shows on; nil for every class.
local STACK_DEFAULTS = { point = "CENTER", anchor = "screen", x = 0, y = -180, scale = 1, alpha = 1,
  showInCombat = true, showOutOfCombat = true, size = { w = 36, h = 36 } }
local BAR_DEFAULTS = {
  name = "New bar", offset = { x = 0, y = 0 }, -- size: one icon (the bar is n of them); nil = the group's
  orientation = "horizontal", icons = {},
  gap = 8, -- px between icons
}
local ENUMS = { orientation = { horizontal = true, vertical = true } }
BS.ANCHORS = { screen = true, top = true, bottom = true, slot1 = true, slot2 = true, slot3 = true }
-- An icon: what it looks like, and when it shows.
--   look   "custom": a picture of our own -- `texture` (file ID, path or spell name), else the
--          spell's picture; `swipe` plays the spell's cooldown over it.
--          "cooldown" / "aura": Blizzard's Cooldown Manager icon for `spell`, timer and all.
--   conditions: every one must hold. usable / active / missing name a spell; target does not.
BS.LOOKS = { custom = true, cooldown = true, aura = true }
BS.COND_KINDS = { usable = true, active = true, missing = true, target = true,
  form = true, noform = true, stealth = true, nostealth = true }
BS.NO_SPELL = { target = true, stealth = true, nostealth = true } -- conditions about you, not a spell
local Clamp = BS.Clamp

-- copy defaults into t wherever a field is missing or has the wrong type
local function fill(t, defaults)
  for k, v in pairs(defaults) do
    if type(t[k]) ~= type(v) then
      t[k] = type(v) == "table" and CopyTable(v) or v
    elseif type(v) == "table" then
      fill(t[k], v)
    end
  end
  return t
end

local function newID(prefix) return ("%s%d-%d"):format(prefix, time(), math.random(1e6)) end

local function spellRef(sp)
  if type(sp) == "table" and type(sp.baseSpell) == "number" then
    return { baseSpell = sp.baseSpell, name = type(sp.name) == "string" and sp.name or BS.SpellName(sp.baseSpell) }
  end
end

function BS.NormalizeIcon(ic)
  if type(ic) ~= "table" then return end
  local out = { spell = spellRef(ic.spell), look = BS.LOOKS[ic.look] and ic.look or "custom", swipe = ic.swipe == true,
    texture = (type(ic.texture) == "number" or type(ic.texture) == "string" and ic.texture ~= "") and ic.texture or nil,
    conditions = {} }
  if not out.spell then out.look = "custom" end -- Blizzard's icon needs a spell to look for
  for _, q in ipairs(type(ic.conditions) == "table" and ic.conditions or {}) do
    local kind = type(q) == "table" and q.kind
    if BS.NO_SPELL[kind] then
      out.conditions[#out.conditions + 1] = { kind = kind }
    elseif BS.COND_KINDS[kind] and spellRef(q) then
      local ref = spellRef(q)
      ref.kind = kind
      out.conditions[#out.conditions + 1] = ref
    end
  end
  return out
end

-- Bars before icons had one Show setting and a list of spells; each spell becomes an icon that
-- shows the same way it did.
local FROM_SHOW = {
  always = { look = "cooldown" },
  usable = { look = "custom", swipe = true, conds = { "usable" } },
  aura = { look = "aura" }, proc = { look = "aura" },
  debuff = { look = "aura", conds = { "target" } },
  missing = { look = "custom", conds = { "target", "missing" } },
  auramissing = { look = "custom", conds = { "missing" } },
}
local function iconsFrom(b)
  local how, icons = FROM_SHOW[b.visibility] or FROM_SHOW.always, {}
  for _, sp in ipairs(type(b.spells) == "table" and b.spells or {}) do
    if type(sp) == "table" then
      local conds = {}
      for _, kind in ipairs(how.conds or {}) do
        conds[#conds + 1] = { kind = kind, baseSpell = sp.baseSpell, name = sp.name }
      end
      for _, q in ipairs(type(b.conditions) == "table" and b.conditions or {}) do conds[#conds + 1] = q end
      icons[#icons + 1] = { look = how.look, spell = sp, swipe = how.swipe, conditions = conds }
    end
  end
  return icons
end

function BS.NormalizeBar(b)
  if type(b.icons) ~= "table" then b.icons = iconsFrom(b) end
  b.visibility, b.spells, b.conditions = nil, nil, nil
  fill(b, BAR_DEFAULTS)
  if type(b.id) ~= "string" then b.id = newID("b") end
  for k, ok in pairs(ENUMS) do
    if not ok[b[k]] then b[k] = BAR_DEFAULTS[k] end
  end
  b.style = nil -- bar texture and color: gone with bars
  b.flash, b.flashLow, b.flashAt = nil, nil, nil -- the flash near the end: gone, see docs/barstack.md
  b.gap = Clamp(math.floor(b.gap + 0.5), 0, 200)
  b.offset.x, b.offset.y = Clamp(b.offset.x, -2000, 2000), Clamp(b.offset.y, -2000, 2000)
  local icons = {}
  for _, ic in ipairs(b.icons) do icons[#icons + 1] = BS.NormalizeIcon(ic) end
  b.icons = icons
  if type(b.size) ~= "table" then b.size = nil end
  -- size was once the whole bar; it is one icon now. An older bar's size is cut into its icons,
  -- along the way the icons run, so it looks the same as before.
  if b.size and not b.perIcon then
    local n = math.max(1, #icons)
    if b.orientation == "vertical" then b.size.h = b.size.h / n else b.size.w = b.size.w / n end
  end
  b.perIcon = true
  if b.size then b.size.w, b.size.h = Clamp(math.floor((tonumber(b.size.w) or 1) + 0.5), 1, 2000),
    Clamp(math.floor((tonumber(b.size.h) or 1) + 0.5), 1, 2000) end
  return b
end

-- One icon of the bar: its own size, else its group's.
function BS.IconSize(b)
  local g = not b.size and BS.profile and BS.GroupOf(b)
  local s = b.size or g and g.stack.size or STACK_DEFAULTS.size
  return s.w, s.h
end

-- What the window and /bs check call an icon.
function BS.IconName(ic)
  if ic.look == "custom" and ic.texture then return "Texture " .. tostring(ic.texture) end
  return ic.spell and (ic.spell.name or ("Spell " .. ic.spell.baseSpell)) or "No picture yet"
end

-- A group is one stack on screen: its own position, scale and combat rules, and its own bars.
function BS.NormalizeGroup(g, i)
  local hadSize = type(g.stack) == "table" and type(g.stack.size) == "table"
  fill(g, { name = "Stack " .. (i or 1), stack = STACK_DEFAULTS, bars = {} })
  if type(g.id) ~= "string" then g.id = newID("g") end
  local s = g.stack
  s.point = "CENTER" -- the only anchor we ever write
  if not BS.ANCHORS[s.anchor] then s.anchor = "screen" end
  s.x, s.y = Clamp(s.x, -4000, 4000), Clamp(s.y, -4000, 4000)
  s.scale, s.alpha = Clamp(s.scale, 0.3, 3), Clamp(s.alpha, 0, 1)
  s.size.w, s.size.h = Clamp(math.floor(s.size.w + 0.5), 1, 2000), Clamp(math.floor(s.size.h + 0.5), 1, 2000)
  if type(s.class) ~= "string" or not s.class:match("^%u+$") then s.class = nil end
  local bars = {}
  for _, b in ipairs(g.bars) do
    if type(b) == "table" then bars[#bars + 1] = BS.NormalizeBar(b) end
  end
  g.bars = bars
  -- a group from before it had an icon size takes its first bar's, and the bars that size follow it
  if not hadSize then
    local first = bars[1] and bars[1].size
    if first then s.size.w, s.size.h = first.w, first.h end
    for _, b in ipairs(bars) do
      if b.size and b.size.w == s.size.w and b.size.h == s.size.h then b.size = nil end
    end
  end
  return g
end

-- Version 1 had one stack and one list of bars; it becomes the first group.
function BS.NormalizeProfile(p)
  if type(p.groups) ~= "table" then
    p.groups = { { stack = type(p.stack) == "table" and p.stack or nil, bars = type(p.bars) == "table" and p.bars or nil } }
  end
  p.stack, p.bars = nil, nil
  p.version = 2
  -- hideBlizzard: Blizzard's viewers kept shown but invisible (see BS.FadeViewers)
  fill(p, { icons = ICON_DEFAULTS, hideBlizzard = true })
  local ic = p.icons
  ic.zoom, ic.border = Clamp(ic.zoom, 0, 30), Clamp(ic.border, 0, 8)
  if not BS.RADII[ic.radius] then ic.radius = 0 end
  for i = 1, 4 do ic.color[i] = Clamp(ic.color[i], 0, 1) end
  if type(p.updated) ~= "number" then p.updated = 0 end
  local groups = {}
  for _, g in ipairs(p.groups) do
    if type(g) == "table" then groups[#groups + 1] = BS.NormalizeGroup(g, #groups + 1) end
  end
  if #groups == 0 then groups[1] = BS.NormalizeGroup({}, 1) end
  p.groups = groups
  return p
end

function BS.NewBar(group, index)
  local b = BS.NormalizeBar({})
  table.insert(group.bars, index or 1, b)
  BS.SetLoaded(b, true)
  return b
end

function BS.NewGroup()
  local groups = BS.profile.groups
  local g = BS.NormalizeGroup({}, #groups + 1)
  groups[#groups + 1] = g
  return g
end

-- Only an empty group goes, and never the last one: deleting a group never deletes bars.
function BS.DeleteGroup(g)
  local groups = BS.profile.groups
  local i = tIndexOf(groups, g)
  if not i or #groups < 2 or #g.bars > 0 then return false end
  table.remove(groups, i)
  return true
end

function BS.GroupOf(bar)
  for _, g in ipairs(BS.profile.groups) do
    if tContains(g.bars, bar) then return g end
  end
end

-- One step up (-1, towards the top layer) or down (+1) in its stack. False at either end.
-- Icon i of a bar one place left / up (d = -1) or right / down (d = 1), not past either end.
function BS.MoveIcon(bar, i, d)
  local icons, j = bar.icons, i + d
  if not (icons[i] and icons[j]) then return false end
  icons[i], icons[j] = icons[j], icons[i]
  return true
end

function BS.MoveBar(bar, d)
  local g = BS.GroupOf(bar)
  local bars = g and g.bars
  local i = bars and tIndexOf(bars, bar)
  local j = i and i + d
  if not (j and bars[j]) then return false end
  bars[i], bars[j] = bars[j], bars[i]
  return true
end

------------------------------------------------------------------------
-- Storage: every save writes all backends, load takes the newest `updated`.
-- 1. SavedVariables BarStackDB  2. account CVar chunks  3. export string (manual, Config window)
-- ponytail: Edit Mode layout store backend skipped until we know which keys are safe to write on Forever.
------------------------------------------------------------------------

function BS.Encode(t)
  return BS.try(function()
    local E = C_EncodingUtil
    return E.EncodeBase64(E.CompressString(E.SerializeCBOR(t)))
  end)
end

function BS.Decode(s)
  if type(s) ~= "string" or s == "" then return end
  local t = BS.try(function()
    local E = C_EncodingUtil
    return E.DeserializeCBOR(E.DecompressString(E.DecodeBase64(s)))
  end)
  return type(t) == "table" and t or nil
end

local CVAR, CVAR_COUNT, CHUNK = "barStackData", 40, 250
local cvarsOK

local function registerCVars()
  if cvarsOK == nil then
    cvarsOK = pcall(function()
      for i = 1, CVAR_COUNT do C_CVar.RegisterCVar(CVAR .. i, "") end
    end)
  end
  return cvarsOK
end
BS.RegisterCVars = registerCVars

local function writeCVars(s)
  -- ponytail: profiles over 10KB skip this backend; SavedVariables and the export string still cover them
  if not registerCVars() or #s > CHUNK * CVAR_COUNT then return end
  for i = 1, CVAR_COUNT do
    pcall(C_CVar.SetCVar, CVAR .. i, s:sub((i - 1) * CHUNK + 1, i * CHUNK))
  end
end

local function readCVars()
  if not registerCVars() then return end
  local parts = {}
  for i = 1, CVAR_COUNT do
    local v = BS.try(C_CVar.GetCVar, CVAR .. i)
    if type(v) ~= "string" or v == "" then break end
    parts[i] = v
  end
  return BS.Decode(table.concat(parts))
end

function BS.LoadDB()
  local sv = type(BarStackDB) == "table" and BarStackDB or nil
  local cv = readCVars()
  BS.svFound, BS.cvFound = sv ~= nil, cv ~= nil
  local db = sv
  if cv and (not sv or (tonumber(cv.updated) or 0) > (tonumber(sv.updated) or 0)) then db = cv end
  db = db or {}
  BS.db, BarStackDB = db, db
end

function BS.Save()
  BS.db.updated = time()
  BS.profile.updated = BS.db.updated
  BarStackDB = BS.db
  local s = BS.Encode(BS.db)
  if s then writeCVars(s) end
end

-- One library of groups, bars and icons for the whole account, apart from Wolfpack's profiles.
-- Each character picks the bars it loads (BS.db.loads[char][bar id]); a new bar loads on the
-- character that made it, and on no other until ticked there.
function BS.Me() return ("%s-%s"):format(UnitName("player"), GetRealmName()) end

local function loads(char)
  local all = BS.db.loads
  all[char] = type(all[char]) == "table" and all[char] or {}
  return all[char]
end

function BS.Loaded(b) return loads(BS.Me())[b.id] == true end
function BS.SetLoaded(b, on) loads(BS.Me())[b.id] = on or nil end
function BS.LoadedBars(g)
  local out = {}
  if g.stack.class and g.stack.class ~= select(2, UnitClass("player")) then return out end -- another class's
  for _, b in ipairs(g.bars) do
    if BS.Loaded(b) then out[#out + 1] = b end
  end
  return out
end

-- Pour `set` into the library: a group or bar already there (same id) is not added twice, a
-- group with no bars is left out, and every bar of the set loads on `chars`.
function BS.Merge(lib, set, chars)
  local have = {}
  for _, g in ipairs(lib.groups) do
    have[g.id] = g
    for _, b in ipairs(g.bars) do have[b.id] = b end
  end
  for _, g in ipairs(set.groups) do
    if #g.bars > 0 then
      local into = have[g.id]
      if not into then
        into = CopyTable(g)
        into.bars = {}
        lib.groups[#lib.groups + 1], have[g.id] = into, into
      end
      for _, b in ipairs(g.bars) do
        if not have[b.id] then
          into.bars[#into.bars + 1], have[b.id] = b, b
        end
        for _, c in ipairs(chars) do loads(c)[b.id] = true end
      end
    end
  end
end

-- Who used an old set: "Name-Realm:spec" was one character's, "wp:Profile:spec" belonged to
-- every character on that Wolfpack profile.
local function ownersOf(key)
  local prof = key:match("^wp:(.*):%d+$")
  if not prof then return { key:match("^(.-):%d+$") } end
  local chars, who = type(WolfpackAddonDB) == "table" and WolfpackAddonDB.chars, {}
  for c, p in pairs(type(chars) == "table" and chars or {}) do
    if p == prof then who[#who + 1] = (c:gsub(" %- ", "-")) end
  end
  return who
end

function BS.LoadProfile()
  local db = BS.db
  if type(db.loads) ~= "table" then db.loads = {} end
  if type(db.library) ~= "table" then
    -- before the library: one set per character (or Wolfpack profile) and spec. All of them
    -- move in once, newest first; the newest one's icon style and Blizzard setting come along.
    local lib, keys = { groups = {} }, {}
    for k, p in pairs(type(db.profiles) == "table" and db.profiles or {}) do
      if type(p) == "table" then keys[#keys + 1] = k end
    end
    table.sort(keys, function(x, y)
      return (tonumber(db.profiles[x].updated) or 0) > (tonumber(db.profiles[y].updated) or 0)
    end)
    for i, k in ipairs(keys) do
      local p = BS.NormalizeProfile(db.profiles[k])
      if i == 1 then lib.icons, lib.hideBlizzard = p.icons, p.hideBlizzard end
      BS.Merge(lib, p, ownersOf(k))
    end
    db.library, db.profiles = lib, nil
  end
  BS.profile = BS.NormalizeProfile(db.library)
end

-- Wolfpack's profile string carries the bars this character loads; importing adds them to the
-- library and loads them here. Nothing already in the library is replaced.
function BS.ExportSet()
  local set = CopyTable(BS.profile)
  for _, g in ipairs(set.groups) do
    for i = #g.bars, 1, -1 do
      if not BS.Loaded(g.bars[i]) then table.remove(g.bars, i) end
    end
  end
  return set
end

function BS.ImportProfile(p)
  if type(p) ~= "table" or not (type(p.groups) == "table" or type(p.bars) == "table") then return false end
  BS.Merge(BS.profile, BS.NormalizeProfile(CopyTable(p)), { BS.Me() })
  BS.Save()
  BS.Apply()
  return true
end

------------------------------------------------------------------------
-- Apply: layout changes wait for combat to end
------------------------------------------------------------------------

function BS.Apply()
  if InCombatLockdown() then BS.pending = true return end
  BS.pending = false
  BS.Layout()
end

function BS.Changed()
  BS.Save()
  BS.Apply()
end

function BS.Check()
  local function line(ok, text) print((ok and "|cff40ff40OK|r  " or "|cffff4040--|r  ") .. text) end
  -- in combat Blizzard's frames name their spell only in secrets, so "0 mapped" means little there
  print(("|cffC79C6EBar Stack|r check: %s client, interface %d, %s"):format(BS.isForever and "Forever" or "Midnight",
    select(4, GetBuildInfo()), InCombatLockdown() and "|cffff4040in combat|r" or "out of combat"))
  line(BS.svFound, "SavedVariables BarStackDB existed at login")
  line(BS.cvFound, "CVar backend returned saved data at login")
  line(C_EncodingUtil ~= nil, "C_EncodingUtil (export string, CVar backend)")
  line(registerCVars(), "custom CVars registered")
  line(BS.try(C_CVar.GetCVar, "cooldownViewerEnabled") == "1", "Cooldown Manager enabled")
  line(issecretvalue ~= nil, "issecretvalue present")
  line(EventRegistry ~= nil, "Edit Mode callbacks (EventRegistry)")
  -- Blizzard's own answer: can the Cooldown Manager run here, and which spells has it been given
  -- for this spec. Frames with no spell while this list has some: the viewer itself is not laying
  -- them out (hidden, or something else took it over).
  local CV = C_CooldownViewer
  local okAvail, avail, why = pcall(function() return CV.IsCooldownViewerAvailable() end)
  line(okAvail and avail == true, "Cooldown Manager available: " .. (not okAvail and "cannot ask"
    or tostring(avail) .. (why and why ~= "" and (" -- " .. tostring(why)) or "")))
  local CAT = { EssentialCooldownViewer = "Essential", UtilityCooldownViewer = "Utility", BuffIconCooldownViewer = "TrackedBuff" }
  for i, name in ipairs(BS.ALL_VIEWERS) do
    local v = _G[name]
    local total, mapped = BS.ViewerStats(v)
    local hooks = BS.hooks and BS.hooks[name]
    local cat = Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory[CAT[name]] or ({ 0, 1, 2 })[i] -- Essential, Utility, TrackedBuff
    local okSet, set = pcall(function() return CV.GetCooldownViewerCategorySet(cat) end)
    local given = okSet and type(set) == "table" and #set or okSet and "none" or "cannot ask"
    local hidden = v and BS.try(v.IsShown, v) == false
    line(mapped > 0, ("%s: %s%s, %d frames, %d mapped to spells, Blizzard gave it %s spells, hooked: %s"):format(name,
      v and "found" or "missing", v and (hidden and ", |cffff4040hidden|r" or ", shown") or "", total, mapped,
      tostring(given), hooks and #hooks > 0 and table.concat(hooks, ", ") or "nothing"))
    if hidden then
      print("      Hidden by its Visibility in Edit Mode, it fills no icons, so Bar Stack reads nothing. Set it"
        .. " to Always: Bar Stack's \"Hide Blizzard's Cooldown Manager\" keeps it out of sight and working.")
    end
  end
  for _, g in ipairs(BS.profile.groups) do
    local st = BS.stacks and BS.stacks[g.id]
    line(st and st:IsVisible(), ("group %s: %d bars, %s"):format(g.name, #g.bars, not st and "no frame yet"
      or st:IsVisible() and ("visible at %d, %d"):format(st:GetCenter()) or "hidden"))
  end
  -- every icon, and every condition, as the last layout pass left them
  if not BS.placed or #BS.placed == 0 then line(false, "no icons on any bar yet") end
  for _, r in ipairs(BS.placed or {}) do
    local it, what = r.frame, ("%s / %s / %s: "):format(r.group, r.bar, r.spell)
    if r.look == "custom" then
      line(true, what .. "own picture" .. (r.swipe and "; swipe: " .. tostring(BS.swipeSeen[r.icon] or "not fed yet") or ""))
    elseif not it then
      line(false, what .. (r.look == "aura"
        and "not in Tracked Buffs (Tracked Bars is not read) -- move it there in the Cooldown Manager"
        or "no Cooldown Manager frame has this spell"))
    else
      -- a frame Blizzard drives with a secret may answer in secrets too: report, never test them
      local function look(m)
        local ok, v = pcall(it[m], it)
        if not ok then return "error" end
        return BS.secret(v) and "secret" or v
      end
      local ours = it:GetParent() == r.container
      local vis, shown, alpha = look("IsVisible"), look("IsShown"), look("GetAlpha")
      line(ours and vis == true, what .. ("from %s, %s, %s, %dx%d"):format(r.viewer,
        ours and "in the stack" or "taken back by Blizzard",
        vis == true and "visible" or vis == "secret" and "visibility is secret"
          or shown == true and "shown, but a parent is hidden" or "hidden by Blizzard",
        it:GetWidth(), it:GetHeight()))
      local w = BS.watch and BS.watch[it]
      if w then -- how Blizzard switches it
        print(("      alpha %s; Blizzard called Show %d, Hide %d, SetShown %d%s, SetAlpha %d%s"):format(
          type(alpha) == "number" and ("%.2f"):format(alpha) or tostring(alpha),
          w.Show, w.Hide, w.SetShown, w.SetShownSecret and " (secret)" or "",
          w.SetAlpha, w.SetAlphaSecret and " (secret)" or ""))
      end
    end
    for _, q in ipairs(BS.gates or {}) do
      if q.icon == r.icon then
        local a = q.gate:GetAlpha()
        line(q.frame ~= false, ("      if %s %s -- %s, now %s"):format(q.cond.kind, q.cond.name or "",
          (q.cond.kind ~= "active" and q.cond.kind ~= "missing") and "asks WoW"
            or q.frame and "watching its Tracked Buffs frame"
            or "not in Tracked Buffs (Tracked Bars is not read) -- move it there in the Cooldown Manager",
          BS.secret(a) and "switched by a secret" or a > 0 and "yes" or "no"))
      end
    end
  end
end

local function cdmPrompt()
  if BS.db.cdmPrompted or BS.try(C_CVar.GetCVar, "cooldownViewerEnabled") ~= "0" then return end
  BS.db.cdmPrompted = true
  StaticPopupDialogs.BARSTACK_CDM = {
    text = "Bar Stack builds its bars from Blizzard's Cooldown Manager, which is turned off.\n\nEnable it in Options > Gameplay Enhancements.",
    button1 = OKAY, timeout = 0, whileDead = true, hideOnEscape = true,
  }
  StaticPopup_Show("BARSTACK_CDM")
end

------------------------------------------------------------------------
-- Events and slash command (Wolfpack's sidebar has a button for the window too)
------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
pcall(ev.RegisterEvent, ev, "SPELL_UPDATE_USABLE") -- rage, target health and procs change what is usable
pcall(ev.RegisterEvent, ev, "SPELL_UPDATE_COOLDOWN") -- feeds the swipe on a usable bar's icons
pcall(ev.RegisterEvent, ev, "UPDATE_SHAPESHIFT_FORM") -- stance and form conditions
pcall(ev.RegisterEvent, ev, "UPDATE_STEALTH")
ev:SetScript("OnEvent", function(_, event, arg)
  if event == "PLAYER_LOGIN" then
    BS.LoadDB()
    BS.LoadProfile()
    BS.Init()
    BS.Apply()
    cdmPrompt()
  elseif event == "ADDON_LOADED" then
    if arg == "Blizzard_CooldownViewer" and BS.profile then BS.Apply() end
  elseif event == "PLAYER_TARGET_CHANGED" then
    if BS.profile then BS.UpdateVisibility() end
  elseif event == "SPELL_UPDATE_USABLE" or event == "SPELL_UPDATE_COOLDOWN" or event == "UPDATE_SHAPESHIFT_FORM"
    or event == "UPDATE_STEALTH" then
    if BS.profile then BS.UpdateUsable() end
  elseif event == "PLAYER_REGEN_DISABLED" then
    BS.inCombat = true
    BS.UpdateVisibility()
  elseif event == "PLAYER_REGEN_ENABLED" then
    BS.inCombat = false
    if BS.pending then BS.Apply() else BS.UpdateVisibility() end
    if BS.RefreshConfig then BS.RefreshConfig() end
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    if arg == "player" and BS.profile then
      BS.Apply()
      if BS.RefreshConfig then BS.RefreshConfig() end
    end
  end
end)

SLASH_BARSTACK1, SLASH_BARSTACK2 = "/bs", "/barstack"
SlashCmdList.BARSTACK = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "check" then BS.Check() elseif msg == "frames" then BS.Frames() else BS.ToggleConfig() end
end

