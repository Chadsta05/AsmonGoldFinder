--[[
  AsmonFinder boot

  Lua translation of asmon-finder/src/index.js
  Wires Settings store, Core finder, SettingsPanel, slash commands,
  and SavedVariables persistence.
]]

---@type AsmonFinderNamespace
AsmonFinder = AsmonFinder or {}

---@type table
local Settings = AsmonFinder.Settings
---@type table
local Core = AsmonFinder.Core
---@type table
local AddonController = AsmonFinder.AddonController
---@type table
local SettingsPanel = AsmonFinder.SettingsPanel
---@type table
local WowBridge = AsmonFinder.WowBridge
---@type (fun(message: string))?
local printToChat

---Persist the current settings into the account-wide SavedVariables table.
function AsmonFinder.PersistSettings()
  if not AsmonFinder.settingsStore then
    return
  end

  AsmonFinderDB = AsmonFinderDB or {}
  AsmonFinderDB.settings = AsmonFinder.settingsStore.GetSettings()
end

---Wire stores, detector, settings panel, slash commands, and WoW adapters.
local function Boot()
  ---@type AsmonFinderSavedVariables
  AsmonFinderDB = AsmonFinderDB or {}

  ---@type AsmonFinderBootDependencies
  local dependencies = WowBridge.CreateDependencies()
  dependencies.savedSettings = AsmonFinderDB.settings
  printToChat = dependencies.printToChat

  ---@type AsmonFinderSettingsStore
  local settingsStore = Settings.CreateSettingsStore(dependencies.savedSettings)

  -- Keep SavedVariables in sync whenever settings change.
  ---@type fun(changes: PartialAsmonFinderSettings): AsmonFinderSettings
  local originalUpdate = settingsStore.UpdateSettings

  ---Apply settings and immediately persist the new state.
  ---@param changes PartialAsmonFinderSettings Changed fields.
  ---@return AsmonFinderSettings settings Updated settings.
  function settingsStore.UpdateSettings(changes)
    local nextSettings = originalUpdate(changes)
    AsmonFinderDB.settings = nextSettings
    return nextSettings
  end

  ---@type fun(): AsmonFinderSettings
  local originalReset = settingsStore.ResetSettings

  ---Reset settings and immediately persist the defaults.
  ---@return AsmonFinderSettings settings Default settings.
  function settingsStore.ResetSettings()
    local nextSettings = originalReset()
    AsmonFinderDB.settings = nextSettings
    return nextSettings
  end

  ---@type AsmonFinderApi
  local finder = Core.CreateAsmonFinder({
    getZoneText = dependencies.getZoneText,
    getSubZoneText = dependencies.getSubZoneText,
    getPlayerPosition = dependencies.getPlayerPosition,
    unitExists = dependencies.unitExists,
    unitName = dependencies.unitName,
    saveLastSeen = dependencies.saveLastSeen,
    getLastSeen = dependencies.getLastSeen,
    showRaidWarning = dependencies.showRaidWarning,
    printToChat = dependencies.printToChat,
    playRaidWarningSound = dependencies.playRaidWarningSound,
    requestTarget = dependencies.requestTarget,
    registerEvent = dependencies.registerEvent,
    now = dependencies.now,
    getSettings = settingsStore.GetSettings,
  })

  WowBridge.SetIsWatchedName(finder.IsTarget)

  ---@type AsmonFinderSettingsPanelApi
  local settingsPanel = SettingsPanel.Create({
    getSettings = settingsStore.GetSettings,
    updateSettings = settingsStore.UpdateSettings,
    getLastSeen = dependencies.getLastSeen,
    requestTarget = dependencies.requestTarget,
    showAlert = finder.ShowAlert,
  })

  ---@type AsmonFinderControllerApi
  local controller = AddonController.Create({
    settingsPanel = settingsPanel,
    resetSettings = function()
      settingsStore.ResetSettings()
      settingsPanel.Refresh()
    end,
    printToChat = dependencies.printToChat,
    showAlert = finder.ShowAlert,
    toggleDebug = dependencies.toggleDebug,
    inspectUnits = dependencies.inspectUnits,
  })

  AsmonFinder.settingsStore = settingsStore
  AsmonFinder.finder = finder
  AsmonFinder.settingsPanel = settingsPanel
  AsmonFinder.controller = controller

  settingsPanel.EnsureReady()
  dependencies.registerSlashCommand(controller.HandleSlashCommand)
  finder.Start()
end

---@type any
local bootFrame = CreateFrame("Frame", "AsmonFinderBootFrame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:RegisterEvent("PLAYER_LOGIN")
bootFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

---Boot once this addon's files and SavedVariables have loaded.
---@param self any Event frame.
---@param event string WoW event name.
---@param addonName? string Loaded addon name.
bootFrame:SetScript("OnEvent", function(self, event, addonName)
  if event == "PLAYER_ENTERING_WORLD" then
    local function MarkSettled()
      if AsmonFinder.WowBridge and AsmonFinder.WowBridge.MarkWorldSettled then
        AsmonFinder.WowBridge.MarkWorldSettled()
      end
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(3, MarkSettled)
    else
      MarkSettled()
    end

    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    return
  end

  if event == "PLAYER_LOGIN" then
    if printToChat then
      printToChat(
        "[Asmon Finder] Ready! Type /asmon help to learn how to use the addon and review its features."
      )
    end
    self:UnregisterEvent("PLAYER_LOGIN")
    return
  end

  if event ~= "ADDON_LOADED" then
    return
  end

  if addonName ~= "AsmonFinder" then
    return
  end

  AsmonFinderDB = AsmonFinderDB or {}
  Boot()

  -- PLAYER_LOGIN may already have fired by the time we finish booting
  -- on some clients; invoke the login handler directly after Start().
  if AsmonFinder.finder then
    AsmonFinder.finder.HandleEvent("PLAYER_LOGIN")
  end

  self:UnregisterEvent("ADDON_LOADED")
end)
