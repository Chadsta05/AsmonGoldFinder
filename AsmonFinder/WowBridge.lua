--[[
  AsmonFinder.WowBridge

  WoW client adapter: events, chat, sound, raid warning,
  map position, SavedVariables, secure target queue.
]]

---@type AsmonFinderNamespace
AsmonFinder = AsmonFinder or {}
AsmonFinder.WowBridge = AsmonFinder.WowBridge or {}

---@type table
local WowBridge = AsmonFinder.WowBridge

---@type any?
local eventFrame
---@type AsmonFinderEventHandler?
local eventHandler
---@type string?
local pendingTargetName

---Seconds between fallback scans of visible unit tokens.
---@type number
local SCAN_INTERVAL_SECONDS = 0.5

---Highest nameplate unit token checked by the fallback scanner.
---@type number
local MAX_NAMEPLATES = 40

---@type number
local scanElapsed = 0

---@type boolean
local debugEnabled = false

---@type table<string, string>
local lastDebugNames = {}

---@type (fun(name: string): boolean)?
local isWatchedName

---Print an addon message to the default chat frame.
---@param message string Chat message.
local function PrintToChat(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(message, 1.0, 0.82, 0.0)
  else
    print(message)
  end
end

---Display raid-warning text, falling back to chat when unavailable.
---@param message string Warning message.
local function ShowRaidWarning(message)
  if RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    return
  end

  PrintToChat(message)
end

---Play the client raid-warning sound when supported.
local function PlayRaidWarningSound()
  if PlaySound then
    -- SOUNDKIT may not exist on every build; fall back to string id.
    if SOUNDKIT and SOUNDKIT.RAID_WARNING then
      PlaySound(SOUNDKIT.RAID_WARNING)
    else
      PlaySound("RaidWarning")
    end
  end
end

---Read the current zone from the WoW client.
---@return string? zone Zone name.
local function GetZoneTextSafe()
  if GetZoneText then
    local zone = GetZoneText()
    if zone and zone ~= "" then
      return zone
    end
  end
  return nil
end

---Read the current subzone from the WoW client.
---@return string? subZone Subzone name.
local function GetSubZoneTextSafe()
  if GetSubZoneText then
    local subZone = GetSubZoneText()
    if subZone and subZone ~= "" then
      return subZone
    end
  end
  return nil
end

---Read the player's map position using modern or legacy map APIs.
---@return AsmonFinderMapPosition? position Percentage coordinates and map id.
local function GetPlayerPositionSafe()
  ---@type number?, number?
  local x, y

  if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
    local mapId = C_Map.GetBestMapForUnit("player")
    if mapId then
      local position = C_Map.GetPlayerMapPosition(mapId, "player")
      if position then
        x, y = position:GetXY()
        if x and y then
          return {
            x = math.floor(x * 10000 + 0.5) / 100,
            y = math.floor(y * 10000 + 0.5) / 100,
            mapId = tostring(mapId),
          }
        end
      end
    end
  end

  if GetPlayerMapPosition then
    x, y = GetPlayerMapPosition("player")
    if x and y and (x > 0 or y > 0) then
      ---@type string?
      local mapId = nil
      if GetCurrentMapAreaID then
        mapId = tostring(GetCurrentMapAreaID())
      end
      return {
        x = math.floor(x * 10000 + 0.5) / 100,
        y = math.floor(y * 10000 + 0.5) / 100,
        mapId = mapId,
      }
    end
  end

  return nil
end

---Read an exact full character name from a WoW unit token.
---@param unit string WoW unit token.
---@return string? name Full character name.
local function UnitNameSafe(unit)
  if GetUnitName then
    ---@type string?
    local displayedName = GetUnitName(unit, true)
    if displayedName and displayedName ~= "" then
      return displayedName
    end
  end

  ---@type string?, string?
  local firstName, secondName = UnitName(unit)
  if not firstName or firstName == "" then
    return nil
  end

  if secondName and secondName ~= "" then
    return firstName .. " " .. secondName
  end

  if UnitFullName then
    ---@type string?, string?
    local fullFirstName, fullSecondName = UnitFullName(unit)
    if fullFirstName and fullFirstName ~= "" then
      if fullSecondName and fullSecondName ~= "" then
        return fullFirstName .. " " .. fullSecondName
      end
      return fullFirstName
    end
  end

  return firstName
end

---Whether debug should mention this exact character name.
---@param name string Full character name.
---@return boolean watched Name is on the watch list.
local function IsWatchedDebugName(name)
  if not isWatchedName then
    return false
  end

  return isWatchedName(name)
end

---Print one watched unit only when its name changes.
---@param unit string WoW unit token.
---@param name string Full character name.
local function DebugObservedUnit(unit, name)
  if not debugEnabled then
    return
  end

  if not IsWatchedDebugName(name) then
    return
  end

  if lastDebugNames[unit] == name then
    return
  end

  lastDebugNames[unit] = name
  PrintToChat(
    "[Asmon Finder Debug] "
      .. unit
      .. " = ["
      .. name
      .. "]"
  )
end

---Inspect one visible token and forward it through the normal unit path.
---@param unit string WoW unit token.
---@param event string Synthetic detector event.
local function ScanUnitToken(unit, event)
  if not eventHandler then
    return
  end

  if not UnitExists(unit) then
    lastDebugNames[unit] = nil
    return
  end

  local name = UnitNameSafe(unit)

  if name then
    DebugObservedUnit(unit, name)
  end

  if event == "NAME_PLATE_UNIT_ADDED" then
    eventHandler(event, {
      unit = unit,
    })
    return
  end

  eventHandler(event, {})
end

---Scan nameplate tokens returned by the modern nameplate API.
local function ScanNamePlateFrames()
  if not C_NamePlate or not C_NamePlate.GetNamePlates then
    return
  end

  ---@type any[]
  local namePlates = C_NamePlate.GetNamePlates()
  if type(namePlates) ~= "table" then
    return
  end

  for _, namePlate in ipairs(namePlates) do
    ---@type string?
    local unit = namePlate.namePlateUnitToken
      or namePlate.unitToken
      or namePlate.unit

    if type(unit) == "string" then
      ScanUnitToken(unit, "NAME_PLATE_UNIT_ADDED")
    end
  end
end

---Poll every public player-bearing unit token as an event fallback.
---
---Some Classic/Forever client builds do not reliably emit modern nameplate
---events. Polling only public unit tokens keeps detection working without
---attempting to enumerate players the client has not exposed.
local function ScanVisibleUnits()
  ScanUnitToken("target", "PLAYER_TARGET_CHANGED")
  ScanUnitToken("mouseover", "UPDATE_MOUSEOVER_UNIT")
  ScanUnitToken("focus", "PLAYER_FOCUS_CHANGED")

  for index = 1, MAX_NAMEPLATES do
    ScanUnitToken("nameplate" .. tostring(index), "NAME_PLATE_UNIT_ADDED")
  end

  ScanNamePlateFrames()

  for index = 1, 4 do
    ScanUnitToken("party" .. tostring(index), "NAME_PLATE_UNIT_ADDED")
  end

  for index = 1, 40 do
    ScanUnitToken("raid" .. tostring(index), "NAME_PLATE_UNIT_ADDED")
  end
end

---Drive the fallback scanner from the shared event frame.
---@param _ any Event frame.
---@param elapsed number Seconds since the previous frame update.
local function OnUpdate(_, elapsed)
  scanElapsed = scanElapsed + elapsed

  if scanElapsed < SCAN_INTERVAL_SECONDS then
    return
  end

  scanElapsed = 0
  ScanVisibleUnits()
end

---Read the client monotonic time in milliseconds.
---@return number milliseconds Current client time.
local function NowMs()
  if GetTime then
    return GetTime() * 1000
  end
  return time() * 1000
end

---Persist the latest detection in SavedVariables.
---@param detection AsmonFinderDetection Sighting record.
local function SaveLastSeen(detection)
  AsmonFinderDB = AsmonFinderDB or {}
  AsmonFinderDB.lastSeen = detection
end

---Read the persisted latest detection.
---@return AsmonFinderDetection? detection Last sighting.
local function GetLastSeen()
  if not AsmonFinderDB then
    return nil
  end
  return AsmonFinderDB.lastSeen
end

---Compare two full Forever names case-insensitively.
---@param left? string First name.
---@param right? string Second name.
---@return boolean matches Whether both names are the same character.
local function NamesMatch(left, right)
  if not left or not right then
    return false
  end

  return string.lower(left) == string.lower(right)
end

---Print a targeting diagnostic that is always useful during field tests.
---@param message string Diagnostic text.
local function PrintTargetLog(message)
  PrintToChat("[Asmon Finder Target] " .. message)
end

---Print scanner diagnostics only while `/asmon debug` is enabled.
---@param message string Diagnostic text.
local function DebugPrint(message)
  if not debugEnabled then
    return
  end

  PrintToChat("[Asmon Finder Debug] " .. message)
end

---@type boolean
local worldSettled = C_Timer == nil

---Show the click Target button once login has settled.
local function ApplyQueuedTargetButton()
  if not worldSettled then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    return
  end

  if not pendingTargetName then
    return
  end

  if AsmonFinder.settingsPanel and AsmonFinder.settingsPanel.ShowSecureTarget then
    AsmonFinder.settingsPanel.ShowSecureTarget(pendingTargetName)
  end
end

---Allow the Target button after the login lockout window.
function WowBridge.MarkWorldSettled()
  worldSettled = true
  ApplyQueuedTargetButton()
end

---Queue a click-only target. Never call TargetUnit/TargetByName from addon code.
---@param name string Full character name.
local function RequestTarget(name)
  if not name or name == "" then
    return
  end

  pendingTargetName = name:match("^%s*(.-)%s*$")

  if NamesMatch(UnitNameSafe("target"), pendingTargetName) then
    PrintTargetLog("already targeted [" .. pendingTargetName .. "]")
    return
  end

  DebugPrint("queue Target [" .. pendingTargetName .. "]")
  ApplyQueuedTargetButton()

  if worldSettled then
    PrintTargetLog(
      "click Target [" .. pendingTargetName .. "]"
    )
    return
  end

  PrintTargetLog("queued [" .. pendingTargetName .. "]")
end

---Convert modern or legacy combat-log arguments into detector data.
---@param ... unknown Raw combat-log event arguments.
---@return AsmonFinderEventPayload payload Normalized source/destination names.
local function BuildCombatLogPayload(...)
  ---@type unknown[]
  local args = { ... }

  -- Modern API
  if CombatLogGetCurrentEventInfo then
    local
      _,
      _,
      _,
      _,
      sourceName,
      _,
      _,
      _,
      destinationName
      = CombatLogGetCurrentEventInfo()

    return {
      sourceName = sourceName,
      destinationName = destinationName,
    }
  end

  -- Older CLEU arg layouts vary; try common source/dest name slots.
  local sourceName = args[5] or args[4]
  local destinationName = args[8] or args[9] or args[7]

  if type(sourceName) ~= "string" then
    sourceName = nil
  end

  if type(destinationName) ~= "string" then
    destinationName = nil
  end

  return {
    sourceName = sourceName,
    destinationName = destinationName,
  }
end

---Forward one frame event into the registered detection handler.
---@param _ any Event frame.
---@param event string WoW event name.
---@param ... unknown Raw event arguments.
local function OnEvent(_, event, ...)
  if not eventHandler then
    return
  end

  ---@type AsmonFinderEventPayload
  local payload = {}

  if event == "NAME_PLATE_UNIT_ADDED" then
    local unit = ...
    if type(unit) == "string" then
      payload.unit = unit

      local name = UnitNameSafe(unit)
      if name then
        DebugObservedUnit(unit, name)
      end
    end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    payload = BuildCombatLogPayload(...)

    if debugEnabled then
      if payload.sourceName and IsWatchedDebugName(payload.sourceName) then
        PrintToChat(
          "[Asmon Finder Debug] combat source = ["
            .. payload.sourceName
            .. "]"
        )
      end

      if payload.destinationName and IsWatchedDebugName(payload.destinationName) then
        PrintToChat(
          "[Asmon Finder Debug] combat destination = ["
            .. payload.destinationName
            .. "]"
        )
      end
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    local name = UnitNameSafe("target")
    if name then
      DebugObservedUnit("target", name)
    end
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    local name = UnitNameSafe("mouseover")
    if name then
      DebugObservedUnit("mouseover", name)
    end
  elseif event == "PLAYER_FOCUS_CHANGED" then
    local name = UnitNameSafe("focus")
    if name then
      DebugObservedUnit("focus", name)
    end
  elseif event == "PLAYER_LOGIN" then
    if GetCVar and GetCVar("nameplateShowFriends") == "0" then
      PrintToChat(
        "[Asmon Finder] Nearby-player scanning needs friendly nameplates. Press Shift+V to enable them."
      )
    end
  end

  eventHandler(event, payload)
end

---Register an event on the shared frame.
---@param event string WoW event name.
---@param handler AsmonFinderEventHandler Detector event handler.
local function RegisterEvent(event, handler)
  eventHandler = handler

  if not eventFrame then
    eventFrame = CreateFrame("Frame", "AsmonFinderEventFrame")
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:SetScript("OnUpdate", OnUpdate)
  end

  eventFrame:RegisterEvent(event)
end

---Register the `/asmon` slash command.
---@param handler fun(input?: string) Slash-command handler.
local function RegisterSlashCommand(handler)
  SLASH_ASMONFINDER1 = "/asmon"
  SlashCmdList["ASMONFINDER"] = function(msg)
    handler(msg)
  end
end

---Limit debug chat to watched character names.
---@param checker fun(name: string): boolean Watch-list matcher.
function WowBridge.SetIsWatchedName(checker)
  isWatchedName = checker
end

---Toggle live scanner diagnostics for watched names only.
---@return boolean enabled New debug state.
local function ToggleDebug()
  debugEnabled = not debugEnabled
  lastDebugNames = {}
  return debugEnabled
end

---Print every target, mouseover, or nameplate currently exposed by the client.
local function InspectUnits()
  local found = 0

  ---Format an optional API value for labeled inspect output.
  ---@param value unknown Raw API return value.
  ---@return string formatted Printable value.
  local function FormatInspectValue(value)
    if value == nil or value == "" then
      return "<nil>"
    end

    return tostring(value)
  end

  local function PrintUnit(unit)
    if not UnitExists(unit) then
      return
    end

    local name = UnitNameSafe(unit)

    if not name then
      return
    end

    found = found + 1
    PrintToChat(
      "[Asmon Finder Inspect] "
        .. unit
        .. " = ["
        .. name
        .. "]"
    )

    ---@type string?, string?
    local unitNameFirst, unitNameSecond = UnitName(unit)
    ---@type string?
    local displayedName
    if GetUnitName then
      displayedName = GetUnitName(unit, true)
    end

    ---@type string?, string?
    local fullNameFirst, fullNameSecond
    if UnitFullName then
      fullNameFirst, fullNameSecond = UnitFullName(unit)
    end

    ---@type string?
    local guid
    if UnitGUID then
      guid = UnitGUID(unit)
    end

    PrintToChat(
      "[Asmon Finder Inspect API] "
        .. unit
        .. " UnitName=["
        .. FormatInspectValue(unitNameFirst)
        .. "] second=["
        .. FormatInspectValue(unitNameSecond)
        .. "] GetUnitName=["
        .. FormatInspectValue(displayedName)
        .. "] UnitFullName=["
        .. FormatInspectValue(fullNameFirst)
        .. "] second=["
        .. FormatInspectValue(fullNameSecond)
        .. "] GUID=["
        .. FormatInspectValue(guid)
        .. "]"
    )
  end

  PrintUnit("target")
  PrintUnit("mouseover")
  PrintUnit("focus")

  for index = 1, MAX_NAMEPLATES do
    PrintUnit("nameplate" .. tostring(index))
  end

  if C_NamePlate and C_NamePlate.GetNamePlates then
    ---@type any[]
    local namePlates = C_NamePlate.GetNamePlates()
    if type(namePlates) == "table" then
      for _, namePlate in ipairs(namePlates) do
        ---@type string?
        local unit = namePlate.namePlateUnitToken
          or namePlate.unitToken
          or namePlate.unit
        if type(unit) == "string" then
          PrintUnit(unit)
        end
      end
    end
  end

  if found == 0 then
    PrintToChat(
      "[Asmon Finder Inspect] No target, mouseover, or nameplate units are currently exposed."
    )
  end
end

---Build the complete WoW adapter used during addon boot.
---@return AsmonFinderBootDependencies dependencies WoW API adapters.
function WowBridge.CreateDependencies()
  return {
    getZoneText = GetZoneTextSafe,
    getSubZoneText = GetSubZoneTextSafe,
    getPlayerPosition = GetPlayerPositionSafe,
    unitExists = function(unit)
      return UnitExists(unit)
    end,
    unitName = UnitNameSafe,
    saveLastSeen = function(detection)
      SaveLastSeen(detection)
      if AsmonFinder.settingsPanel and AsmonFinder.settingsPanel.Refresh then
        AsmonFinder.settingsPanel.Refresh()
      end
    end,
    getLastSeen = GetLastSeen,
    showRaidWarning = ShowRaidWarning,
    printToChat = PrintToChat,
    playRaidWarningSound = PlayRaidWarningSound,
    requestTarget = RequestTarget,
    registerEvent = RegisterEvent,
    now = NowMs,
    registerSlashCommand = RegisterSlashCommand,
    toggleDebug = ToggleDebug,
    inspectUnits = InspectUnits,
    savedSettings = nil,
  }
end

---Read the character currently queued for secure targeting.
---@return string? name Full character name.
function WowBridge.GetPendingTargetName()
  return pendingTargetName
end
