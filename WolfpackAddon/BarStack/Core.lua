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

local STACK_DEFAULTS = { point = "CENTER", x = 0, y = -180, scale = 1, alpha = 1, showInCombat = true, showOutOfCombat = true }
local BAR_DEFAULTS = {
  name = "New bar", offset = { x = 0, y = 0 }, size = { w = 240, h = 24 },
  orientation = "horizontal", visibility = "always", spells = {},
  style = { texture = "flat", color = "#C79C6E" },
}
local ENUMS = { visibility = { always = true, aura = true, proc = true }, orientation = { horizontal = true, vertical = true } }
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

function BS.NormalizeBar(b)
  fill(b, BAR_DEFAULTS)
  if type(b.id) ~= "string" then b.id = ("b%d-%d"):format(time(), math.random(1e6)) end
  for k, ok in pairs(ENUMS) do
    if not ok[b[k]] then b[k] = BAR_DEFAULTS[k] end
  end
  if not BS.TEXTURES[b.style.texture] then b.style.texture = "flat" end
  b.offset.x, b.offset.y = Clamp(b.offset.x, -2000, 2000), Clamp(b.offset.y, -2000, 2000)
  b.size.w, b.size.h = Clamp(b.size.w, 1, 2000), Clamp(b.size.h, 1, 2000)
  local spells = {}
  for _, sp in ipairs(b.spells) do
    if type(sp) == "table" and type(sp.baseSpell) == "number" then
      spells[#spells + 1] = {
        baseSpell = sp.baseSpell,
        name = type(sp.name) == "string" and sp.name or BS.SpellName(sp.baseSpell),
        display = sp.display == "bar" and "bar" or "icon",
      }
    end
  end
  b.spells = spells
  return b
end

function BS.NormalizeProfile(p)
  fill(p, { version = 1, updated = 0, stack = STACK_DEFAULTS, bars = {} })
  local s = p.stack
  s.point = "CENTER" -- the only anchor we ever write
  s.x, s.y = Clamp(s.x, -4000, 4000), Clamp(s.y, -4000, 4000)
  s.scale, s.alpha = Clamp(s.scale, 0.3, 3), Clamp(s.alpha, 0, 1)
  local bars = {}
  for _, b in ipairs(p.bars) do
    if type(b) == "table" then bars[#bars + 1] = BS.NormalizeBar(b) end
  end
  p.bars = bars
  return p
end

-- One step up (-1, towards the top layer) or down (+1) in the stack. False at either end.
function BS.MoveBar(bar, d)
  local bars = BS.profile.bars
  local i = tIndexOf(bars, bar)
  local j = i and i + d
  if not (j and bars[j]) then return false end
  bars[i], bars[j] = bars[j], bars[i]
  return true
end

function BS.NewBar(index)
  local b = BS.NormalizeBar({})
  table.insert(BS.profile.bars, index or 1, b)
  return b
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
  if not p or p.version ~= 1 or type(p.bars) ~= "table" then return false end
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
  local stack = BarStackFrame
  line(stack and stack:IsVisible(), ("stack frame %s"):format(not stack and "missing"
    or stack:IsVisible() and ("visible at %d, %d"):format(stack:GetCenter()) or "hidden"))
  -- every spell of every bar, as the last layout pass left it
  if not BS.placed or #BS.placed == 0 then line(false, "no spells on any bar yet") end
  for _, r in ipairs(BS.placed or {}) do
    local it, what = r.frame, ("%s / %s: "):format(r.bar, r.spell)
    if not it then
      line(false, what .. "no Cooldown Manager frame has this spell")
    else
      local ours = it:GetParent() == r.container
      line(ours and it:IsVisible(), what .. ("from %s, %s, %s, %dx%d"):format(r.viewer,
        ours and "in the stack" or "taken back by Blizzard",
        it:IsVisible() and "visible" or it:IsShown() and "shown, but a parent is hidden" or "hidden by Blizzard",
        it:GetWidth(), it:GetHeight()))
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
ev:SetScript("OnEvent", function(_, event, arg)
  if event == "PLAYER_LOGIN" then
    BS.LoadDB()
    BS.LoadProfile()
    BS.Init()
    BS.Apply()
    cdmPrompt()
  elseif event == "ADDON_LOADED" then
    if arg == "Blizzard_CooldownViewer" and BS.profile then BS.Apply() end
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
  if strtrim(msg or ""):lower() == "check" then BS.Check() else BS.ToggleConfig() end
end

