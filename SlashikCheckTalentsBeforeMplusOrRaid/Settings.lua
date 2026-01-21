local ADDON_NAME = ...
local MyAddon = _G.MyAddon or {}
_G.MyAddon = MyAddon

MyAddon.Settings = MyAddon.Settings or {}
local S = MyAddon.Settings

local DB_NAME = "SlashikCheckTalentsBeforeMplusOrRaidDB"

local DEFAULTS = {
  enabledM = true,
  enabledRaid = true,
}

local function CopyDefaults(src, dst)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

local function GetDB()
  return _G[DB_NAME]
end

local function SetDB(db)
  _G[DB_NAME] = db
end

function S:InitDB()
  SetDB(CopyDefaults(DEFAULTS, GetDB() or {}))
end

function S:Get(key)
  local db = GetDB()
  return db and db[key]
end

function S:Set(key, value)
  local db = GetDB()
  if not db then return end
  db[key] = value
end

local function RegisterSettingsUI()
  if not Settings then return end

  local category = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)
  Settings.RegisterAddOnCategory(category)

  local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
  if not CreateCheckbox then
    print("API Problem -> CreateCheckbox or CreateCheckBox do not exist!")
    return
  end

  local function AddCheckbox(varName, label, tooltip)
    local setting = Settings.RegisterAddOnSetting(
      category,
      varName,                 -- internal setting name
      varName,                 -- key in SavedVariables table
      GetDB(),                 -- SavedVariables table (must exist already)
      Settings.VarType.Boolean,
      label,
      DEFAULTS[varName]
    )
    CreateCheckbox(category, setting, tooltip)
  end

  -- Settings
  AddCheckbox("enabledM", "Enable for M+", "Turns the warning on/off for M+")
  AddCheckbox("enabledRaid", "Enable for Raid", "Turns the warning on/off for Raid")
end

-- Init when addon loads
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
  if name ~= ADDON_NAME then return end
  S:InitDB()
  RegisterSettingsUI()
end)