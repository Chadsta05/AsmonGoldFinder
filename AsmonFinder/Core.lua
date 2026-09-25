--[[
  AsmonFinder.Core

  Lua translation of asmon-finder/src/AsmonFinder.js
  Detection / alert logic. WoW APIs arrive through dependencies.
]]

---@type AsmonFinderNamespace
AsmonFinder = AsmonFinder or {}
AsmonFinder.Core = AsmonFinder.Core or {}

---@type table
local Core = AsmonFinder.Core

---WoW events monitored by the detector.
---@type string[]
local EVENTS = {
  "PLAYER_LOGIN",
  "PLAYER_TARGET_CHANGED",
  "PLAYER_FOCUS_CHANGED",
  "UPDATE_MOUSEOVER_UNIT",
  "NAME_PLATE_UNIT_ADDED",
  "COMBAT_LOG_EVENT_UNFILTERED",
}

---Trim outer whitespace and reject empty strings.
---@param value? string Input value.
---@return string? trimmed Trimmed value, or nil when empty.
local function Trim(value)
  if not value then
    return nil
  end

  local trimmed = value:match("^%s*(.-)%s*$")

  if not trimmed or trimmed == "" then
    return nil
  end

  return trimmed
end

---Normalize a full Forever character name for exact comparison.
---
---Spaces and hyphens remain part of the name; only outer whitespace and case
---are normalized. No retail-style realm suffix processing is performed.
---@param name? string Full character name.
---@return string? normalized Normalized full name.
function Core.NormalizeName(name)
  local trimmed = Trim(name)

  if not trimmed then
    return nil
  end

  return string.lower(trimmed)
end

---Create the detection service.
---@param dependencies AsmonFinderDependencies WoW API adapters and stores.
---@return AsmonFinderApi finder Detection API.
function Core.CreateAsmonFinder(dependencies)
  ---@type table<string, number>
  local lastAlertTimes = {}

  ---@type AsmonFinderApi
  local finder = {}

  ---Determine whether an exact full character name is watched.
  ---@param name? string Character name returned by the client.
  ---@return boolean watched Whether the name is currently watched.
  function finder.IsTarget(name)
    local normalizedName = Core.NormalizeName(name)

    if not normalizedName then
      return false
    end

    local settings = dependencies.getSettings()

    for index = 1, #settings.targetNames do
      local normalizedTarget = Core.NormalizeName(settings.targetNames[index])

      if normalizedTarget == normalizedName then
        return true
      end
    end

    return false
  end

  ---Get the current zone and optional subzone for display.
  ---@return string location Human-readable location.
  function finder.GetLocation()
    local zoneText = dependencies.getZoneText()
    local zone = "Unknown Zone"

    if zoneText and zoneText ~= "" then
      zone = zoneText
    end

    local subZoneText = dependencies.getSubZoneText()
    local subZone = ""

    if subZoneText and subZoneText ~= "" then
      subZone = subZoneText
    end

    if subZone ~= "" then
      return zone .. " - " .. subZone
    end

    return zone
  end

  ---Determine whether the configured alert cooldown has elapsed for this name.
  ---@param name string Detected full character name.
  ---@param currentTime number Current timestamp in milliseconds.
  ---@return boolean allowed Whether another alert may fire.
  local function CanAlert(name, currentTime)
    local settings = dependencies.getSettings()
    local normalizedName = Core.NormalizeName(name)

    if not normalizedName then
      return false
    end

    local lastTime = lastAlertTimes[normalizedName]
    if not lastTime then
      return true
    end

    local elapsed = currentTime - lastTime
    return elapsed >= settings.alertCooldownMs
  end

  ---Create a persisted sighting record.
  ---@param name string Detected full character name.
  ---@param source string Detection mechanism.
  ---@param timestamp number Detection timestamp in milliseconds.
  ---@return AsmonFinderDetection detection Sighting record.
  local function CreateDetection(name, source, timestamp)
    local position = dependencies.getPlayerPosition()
    local x = nil
    local y = nil
    local mapId = nil

    if position then
      x = position.x
      y = position.y
      mapId = position.mapId
    end

    return {
      name = name,
      zone = finder.GetLocation(),
      source = source,
      time = timestamp,
      x = x,
      y = y,
      mapId = mapId,
    }
  end

  ---Run all enabled alert behaviors for a detection.
  ---@param name string Detected full character name.
  ---@param source string Detection mechanism.
  function finder.ShowAlert(name, source)
    local settings = dependencies.getSettings()

    if not settings.enabled then
      return
    end

    local currentTime = dependencies.now()

    if not CanAlert(name, currentTime) then
      return
    end

    local normalizedName = Core.NormalizeName(name)
    if normalizedName then
      lastAlertTimes[normalizedName] = currentTime
    end

    local detection = CreateDetection(name, source, currentTime)
    dependencies.saveLastSeen(detection)

    if settings.raidWarningEnabled then
      dependencies.showRaidWarning(detection.name .. " DETECTED")
    end

    if settings.chatEnabled then
      dependencies.printToChat(
        "[Asmon Finder] " .. detection.name
          .. " detected via " .. detection.source
          .. " in " .. detection.zone
      )
    end

    if settings.soundEnabled then
      dependencies.playRaidWarningSound()
    end

    if settings.autoTargetEnabled then
      dependencies.requestTarget(detection.name)
    end
  end

  ---Inspect a WoW unit token and alert if its exact name is watched.
  ---@param unit string WoW unit token.
  ---@param source string Detection mechanism.
  function finder.CheckUnit(unit, source)
    if not dependencies.unitExists(unit) then
      return
    end

    local name = dependencies.unitName(unit)

    if not name then
      return
    end

    if not finder.IsTarget(name) then
      return
    end

    finder.ShowAlert(name, source)
  end

  ---Inspect source and destination names from a combat-log event.
  ---@param event AsmonFinderEventPayload Combat-log payload.
  function finder.CheckCombatLog(event)
    if finder.IsTarget(event.sourceName) then
      if event.sourceName then
        finder.ShowAlert(event.sourceName, "combat log")
      end
      return
    end

    if finder.IsTarget(event.destinationName) then
      if event.destinationName then
        finder.ShowAlert(event.destinationName, "combat log")
      end
    end
  end

  ---Dispatch one registered WoW event into the detector.
  ---@param event string WoW event name.
  ---@param payload? AsmonFinderEventPayload Event data.
  function finder.HandleEvent(event, payload)
    payload = payload or {}

    local settings = dependencies.getSettings()

    if event ~= "PLAYER_LOGIN" and not settings.enabled then
      return
    end

    if event == "PLAYER_LOGIN" then
      dependencies.printToChat("[Asmon Finder] loaded.")
      dependencies.printToChat(
        "[Asmon Finder] Watching "
          .. tostring(#settings.targetNames)
          .. " character names."
      )
      return
    end

    if event == "PLAYER_TARGET_CHANGED" then
      finder.CheckUnit("target", "target")
      return
    end

    if event == "PLAYER_FOCUS_CHANGED" then
      finder.CheckUnit("focus", "focus")
      return
    end

    if event == "UPDATE_MOUSEOVER_UNIT" then
      finder.CheckUnit("mouseover", "mouseover")
      return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
      if payload.unit then
        finder.CheckUnit(payload.unit, "nameplate")
      end
      return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      finder.CheckCombatLog(payload)
    end
  end

  ---Register every event required by the detector.
  function finder.Start()
    for index = 1, #EVENTS do
      dependencies.registerEvent(EVENTS[index], finder.HandleEvent)
    end
  end

  return finder
end

Core.EVENTS = EVENTS
