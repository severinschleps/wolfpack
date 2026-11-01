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
local ICON_DEFAULTS = { zoom = 8, border = 1, color = { 0, 0, 0, 1 }, radius = 0 }
BS.RADII = { [0] = true, [12] = true, [25] = true, [50] = true }
local STACK_DEFAULTS = { point = "CENTER", x = 0, y = -180, scale = 1, alpha = 1, showInCombat = true, showOutOfCombat = true }
local BAR_DEFAULTS = {
  name = "New bar", offset = { x = 0, y = 0 }, size = { w = 36, h = 36 }, -- one icon; the bar is n of them
  orientation = "horizontal", visibility = "always", spells = {},
  gap = 0, -- px between icons
  flashAt = 0, -- flash under this % of the aura's time left; 0 = never
}
local ENUMS = { visibility = { always = true, usable = true, aura = true, debuff = true, proc = true, missing = true }, orientation = { horizontal = true, vertical = true } }
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

function BS.NormalizeBar(b)
  fill(b, BAR_DEFAULTS)
  if type(b.id) ~= "string" then b.id = newID("b") end
  for k, ok in pairs(ENUMS) do
    if not ok[b[k]] then b[k] = BAR_DEFAULTS[k] end
  end
  b.style = nil -- bar texture and color: gone with bars
  if b.flashLow == true and b.flashAt == 0 then b.flashAt = 25 end -- the first, on / off version
  b.flashLow = nil
  b.gap, b.flashAt = Clamp(math.floor(b.gap + 0.5), 0, 200), Clamp(math.floor(b.flashAt + 0.5), 0, 100)
  b.offset.x, b.offset.y = Clamp(b.offset.x, -2000, 2000), Clamp(b.offset.y, -2000, 2000)
  local spells = {}
  for _, sp in ipairs(b.spells) do
    if type(sp) == "table" and type(sp.baseSpell) == "number" then
      spells[#spells + 1] = {
        baseSpell = sp.baseSpell,
        name = type(sp.name) == "string" and sp.name or BS.SpellName(sp.baseSpell),
      }
    end
  end
  b.spells = spells
  -- size was once the whole bar; it is one icon now. An older bar's size is cut into its spells,
  -- along the way the icons run, so it looks the same as before.
  if not b.perIcon then
    local n = math.max(1, #spells)
    if b.orientation == "vertical" then b.size.h = b.size.h / n else b.size.w = b.size.w / n end
    b.perIcon = true
  end
  b.size.w, b.size.h = Clamp(math.floor(b.size.w + 0.5), 1, 2000), Clamp(math.floor(b.size.h + 0.5), 1, 2000)
  return b
end

-- A group is one stack on screen: its own position, scale and combat rules, and its own bars.
function BS.NormalizeGroup(g, i)
  fill(g, { name = "Stack " .. (i or 1), stack = STACK_DEFAULTS, bars = {} })
  if type(g.id) ~= "string" then g.id = newID("g") end
  local s = g.stack
  s.point = "CENTER" -- the only anchor we ever write
  s.x, s.y = Clamp(s.x, -4000, 4000), Clamp(s.y, -4000, 4000)
  s.scale, s.alpha = Clamp(s.scale, 0.3, 3), Clamp(s.alpha, 0, 1)
  local bars = {}
  for _, b in ipairs(g.bars) do
    if type(b) == "table" then bars[#bars + 1] = BS.NormalizeBar(b) end
  end
  g.bars = bars
  return g
end

-- Version 1 had one stack and one list of bars; it becomes the first group.
function BS.NormalizeProfile(p)
  if type(p.groups) ~= "table" then
    p.groups = { { stack = type(p.stack) == "table" and p.stack or nil, bars = type(p.bars) == "table" and p.bars or nil } }
  end
  p.stack, p.bars = nil, nil
  p.version = 2
  fill(p, { icons = ICON_DEFAULTS })
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
  if type(db.profiles) ~= "table" then db.profiles = {} end
  BS.db, BarStackDB = db, db
end

function BS.Save()
  BS.db.updated = time()
  BS.profile.updated = BS.db.updated
  BarStackDB = BS.db
  local s = BS.Encode(BS.db)
  if s then writeCVars(s) end
end

local function profileKey()
  local spec = BS.try(GetSpecialization) or 0
  return ("%s-%s:%d"):format(UnitName("player"), GetRealmName(), spec)
end

function BS.LoadProfile()
  local key = profileKey()
  local p = BS.db.profiles[key]
  if type(p) ~= "table" then p = {} end
  BS.profile = BS.NormalizeProfile(p)
  BS.db.profiles[key] = BS.profile
end

function BS.Export() return BS.Encode(BS.profile) end

function BS.Import(s)
  local p = BS.Decode(type(s) == "string" and (s:gsub("%s", "")) or nil)
  if not p or not (type(p.groups) == "table" or type(p.bars) == "table") then return false end
  BS.db.profiles[profileKey()] = p
  BS.LoadProfile()
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
  print(("|cffC79C6EBar Stack|r check: %s client, interface %d"):format(BS.isForever and "Forever" or "Midnight", select(4, GetBuildInfo())))
  line(BS.svFound, "SavedVariables BarStackDB existed at login")
  line(BS.cvFound, "CVar backend returned saved data at login")
  line(C_EncodingUtil ~= nil, "C_EncodingUtil (export string, CVar backend)")
  line(registerCVars(), "custom CVars registered")
  line(BS.try(C_CVar.GetCVar, "cooldownViewerEnabled") == "1", "Cooldown Manager enabled")
  line(issecretvalue ~= nil, "issecretvalue present")
  line(EventRegistry ~= nil, "Edit Mode callbacks (EventRegistry)")
  for _, name in ipairs(BS.ALL_VIEWERS) do
    local total, mapped = BS.ViewerStats(_G[name])
    local hooks = BS.hooks and BS.hooks[name]
    line(mapped > 0, ("%s: %s, %d frames, %d mapped to spells, hooked: %s"):format(name, _G[name] and "found" or "missing",
      total, mapped, hooks and #hooks > 0 and table.concat(hooks, ", ") or "nothing"))
  end
  for _, g in ipairs(BS.profile.groups) do
    local st = BS.stacks and BS.stacks[g.id]
    line(st and st:IsVisible(), ("group %s: %d bars, %s"):format(g.name, #g.bars, not st and "no frame yet"
      or st:IsVisible() and ("visible at %d, %d"):format(st:GetCenter()) or "hidden"))
  end
  -- every spell of every bar, as the last layout pass left it
  if not BS.placed or #BS.placed == 0 then line(false, "no spells on any bar yet") end
  for _, r in ipairs(BS.placed or {}) do
    local it, what = r.frame, ("%s / %s / %s: "):format(r.group, r.bar, r.spell)
    if r.visibility == "usable" then
      local seen = BS.usableSeen[r.barRef and r.barRef.id]
      line(seen ~= nil, what .. "own icon; usable right now: " .. tostring(seen or "not asked yet")
        .. "; swipe: " .. tostring(BS.swipeSeen[r.barRef and r.barRef.id] or "not fed yet"))
    elseif not it then
      line(false, what .. (BS.AURA_MODES[r.visibility]
        and "not in Tracked Buffs -- add it there in the Cooldown Manager"
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
      if r.reminder then
        local ra = r.reminder:GetAlpha()
        line(ours, what .. ("watching %s's frame (%s); reminder icon %s"):format(r.viewer,
          shown == "secret" and "its state is secret" or shown == true and "debuff up" or "debuff missing",
          BS.secret(ra) and "switched by a secret" or ra > 0 and "showing" or "hidden"))
      else
      line(ours and vis == true, what .. ("from %s, %s, %s, %dx%d"):format(r.viewer,
        ours and "in the stack" or "taken back by Blizzard",
        vis == true and "visible" or vis == "secret" and "visibility is secret"
          or shown == true and "shown, but a parent is hidden" or "hidden by Blizzard",
        it:GetWidth(), it:GetHeight()))
      end
      if r.barRef and r.barRef.flashAt > 0 then
        local calls, seen = BS.cdCalls[it], {}
        if type(calls) == "table" then
          for _, m in ipairs(BS.CD_METHODS) do
            if calls[m] then seen[#seen + 1] = m .. " " .. calls[m] end
          end
        end
        line(BS.flashSeen.result == "working", ("      flash at %d%% left: %s; Blizzard's cooldown got %s"):format(
          r.barRef.flashAt, BS.flashSeen.result, type(calls) == "string" and calls
          or #seen > 0 and table.concat(seen, ", ") or "not hooked yet"))
      end
      local w = BS.watch and BS.watch[it]
      if w then -- how Blizzard switches it: decides whether "show while missing" can be built
        print(("      alpha %s; Blizzard called Show %d, Hide %d, SetShown %d%s, SetAlpha %d%s"):format(
          type(alpha) == "number" and ("%.2f"):format(alpha) or tostring(alpha),
          w.Show, w.Hide, w.SetShown, w.SetShownSecret and " (secret)" or "",
          w.SetAlpha, w.SetAlphaSecret and " (secret)" or ""))
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
  elseif event == "SPELL_UPDATE_USABLE" or event == "SPELL_UPDATE_COOLDOWN" then
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
      BS.LoadProfile()
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

