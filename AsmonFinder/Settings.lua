--[[
  AsmonFinder.Settings

  Lua translation of asmon-finder/src/Settings.js
  Defaults, merge/SavedVariables helpers, and the settings store.
]]

---@type AsmonFinderNamespace
AsmonFinder = AsmonFinder or {}
AsmonFinder.Settings = AsmonFinder.Settings or {}

---@type table
local Settings = AsmonFinder.Settings

---Default addon configuration. Consumers receive copies so this table cannot
---be mutated through the settings store.
---@type AsmonFinderSettings
local DEFAULT_SETTINGS = {
  enabled = true,
  alertCooldownMs = 10000,
  raidWarningEnabled = true,
  soundEnabled = true,
  chatEnabled = true,
  autoTargetEnabled = true,
  targetNames = {
    "Asmongold",
    "Asmongler",
  },
}

---Create an independent copy of a character-name list.
---@param names? string[] Character names to copy.
---@return string[] names Independent list.
local function CopyTargetNames(names)
  ---@type string[]
  local copy = {}
  if not names then
    return copy
  end

  for index = 1, #names do
    copy[index] = names[index]
  end

  return copy
end

---Create a new independent settings object populated with defaults.
---@return AsmonFinderSettings settings Default settings.
function Settings.CreateDefaultSettings()
  return {
    enabled = DEFAULT_SETTINGS.enabled,
    alertCooldownMs = DEFAULT_SETTINGS.alertCooldownMs,
    raidWarningEnabled = DEFAULT_SETTINGS.raidWarningEnabled,
    soundEnabled = DEFAULT_SETTINGS.soundEnabled,
    chatEnabled = DEFAULT_SETTINGS.chatEnabled,
    autoTargetEnabled = DEFAULT_SETTINGS.autoTargetEnabled,
    targetNames = CopyTargetNames(DEFAULT_SETTINGS.targetNames),
  }
end

---Clone a complete settings object and its target-name list.
---@param settings AsmonFinderSettings Settings to copy.
---@return AsmonFinderSettings settings Independent copy.
function Settings.CloneSettings(settings)
  return {
    enabled = settings.enabled,
    alertCooldownMs = settings.alertCooldownMs,
    raidWarningEnabled = settings.raidWarningEnabled,
    soundEnabled = settings.soundEnabled,
    chatEnabled = settings.chatEnabled,
    autoTargetEnabled = settings.autoTargetEnabled,
    targetNames = CopyTargetNames(settings.targetNames),
  }
end

---Merge saved settings onto current defaults.
---
---Missing fields retain current defaults, allowing older SavedVariables to
---survive settings added by newer addon versions.
---@param saved? PartialAsmonFinderSettings Persisted settings.
---@return AsmonFinderSettings settings Complete merged settings.
function Settings.MergeSettings(saved)
  local merged = Settings.CreateDefaultSettings()

  if not saved then
    return merged
  end

  if saved.enabled ~= nil then
    merged.enabled = saved.enabled
  end

  if saved.alertCooldownMs ~= nil then
    merged.alertCooldownMs = saved.alertCooldownMs
  end

  if saved.raidWarningEnabled ~= nil then
    merged.raidWarningEnabled = saved.raidWarningEnabled
  end

  if saved.soundEnabled ~= nil then
    merged.soundEnabled = saved.soundEnabled
  end

  if saved.chatEnabled ~= nil then
    merged.chatEnabled = saved.chatEnabled
  end

  if saved.autoTargetEnabled ~= nil then
    merged.autoTargetEnabled = saved.autoTargetEnabled
  end

  if saved.targetNames then
    merged.targetNames = CopyTargetNames(saved.targetNames)
  end

  return merged
end

---Convert UI seconds to the milliseconds used by the detector.
---@param seconds number Seconds from the settings slider.
---@return number milliseconds Rounded non-negative milliseconds.
function Settings.SecondsToMilliseconds(seconds)
  local milliseconds = math.floor((seconds * 1000) + 0.5)

  if milliseconds < 0 then
    return 0
  end

  return milliseconds
end

---Convert detector milliseconds to seconds for display.
---@param milliseconds number Milliseconds.
---@return number seconds Seconds.
function Settings.MillisecondsToSeconds(milliseconds)
  return milliseconds / 1000
end

---Create the mutable settings store used by the addon.
---@param initialSettings? PartialAsmonFinderSettings Initial SavedVariables.
---@return AsmonFinderSettingsStore store Settings API.
function Settings.CreateSettingsStore(initialSettings)
  ---@type AsmonFinderSettings
  local settings = Settings.MergeSettings(initialSettings)

  ---@type AsmonFinderSettingsStore
  local store = {}

  ---Get an independent copy of the current settings.
  ---@return AsmonFinderSettings settings Current settings.
  function store.GetSettings()
    return Settings.CloneSettings(settings)
  end

  ---Apply one or more settings changes.
  ---@param changes PartialAsmonFinderSettings Changed fields.
  ---@return AsmonFinderSettings settings Updated settings.
  function store.UpdateSettings(changes)
    local nextSettings = Settings.CloneSettings(settings)

    if changes.enabled ~= nil then
      nextSettings.enabled = changes.enabled
    end

    if changes.alertCooldownMs ~= nil then
      nextSettings.alertCooldownMs = changes.alertCooldownMs
    end

    if changes.raidWarningEnabled ~= nil then
      nextSettings.raidWarningEnabled = changes.raidWarningEnabled
    end

    if changes.soundEnabled ~= nil then
      nextSettings.soundEnabled = changes.soundEnabled
    end

    if changes.chatEnabled ~= nil then
      nextSettings.chatEnabled = changes.chatEnabled
    end

    if changes.autoTargetEnabled ~= nil then
      nextSettings.autoTargetEnabled = changes.autoTargetEnabled
    end

    if changes.targetNames ~= nil then
      nextSettings.targetNames = CopyTargetNames(changes.targetNames)
    end

    settings = Settings.MergeSettings(nextSettings)
    return store.GetSettings()
  end

  ---Restore all addon settings to their defaults.
  ---@return AsmonFinderSettings settings Restored settings.
  function store.ResetSettings()
    settings = Settings.CreateDefaultSettings()
    return store.GetSettings()
  end

  return store
end

Settings.DEFAULT_SETTINGS = DEFAULT_SETTINGS
