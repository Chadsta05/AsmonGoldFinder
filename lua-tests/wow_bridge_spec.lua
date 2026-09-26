describe("AsmonFinder WowBridge", function()
  local WowBridge
  local Core
  local scripts
  local names
  local suffixes
  local chatMessages

  before_each(function()
    AsmonFinder = nil
    AsmonFinderDB = nil
    scripts = {}
    names = {}
    suffixes = {}
    chatMessages = {}

    _G.DEFAULT_CHAT_FRAME = {
      AddMessage = function(_, message)
        chatMessages[#chatMessages + 1] = message
      end,
    }

    _G.CreateFrame = function()
      return {
        SetScript = function(_, scriptName, handler)
          scripts[scriptName] = handler
        end,
        RegisterEvent = function() end,
      }
    end

    _G.UnitExists = function(unit)
      return names[unit] ~= nil
    end

    _G.UnitName = function(unit)
      return names[unit], suffixes[unit]
    end

    _G.GetTime = function()
      return 1
    end

    _G.SlashCmdList = {}
    _G.CombatLogGetCurrentEventInfo = nil
    _G.C_NamePlate = nil
    _G.GetCVar = nil
    _G.GetUnitName = nil
    _G.UnitFullName = nil
    _G.UnitGUID = nil
    _G.TargetByName = nil
    _G.TargetUnit = nil
    _G.issecretvalue = nil
    _G.InCombatLockdown = function()
      return false
    end

    dofile("AsmonFinder/Types.lua")
    dofile("AsmonFinder/TypeGuards.lua")
    dofile("AsmonFinder/Core.lua")
    dofile("AsmonFinder/WowBridge.lua")
    Core = AsmonFinder.Core
    WowBridge = AsmonFinder.WowBridge
  end)

  it("polls target, focus, and visible nameplate tokens as a fallback", function()
    names.target = "Donald Trump"
    names.focus = "Lil Sister"
    names.nameplate3 = "Joe Biden"

    local dependencies = WowBridge.CreateDependencies()
    local received = {}

    dependencies.registerEvent("PLAYER_TARGET_CHANGED", function(event, payload)
      received[#received + 1] = {
        event = event,
        unit = payload.unit,
      }
    end)

    scripts.OnUpdate(nil, 0.5)

    assert.same({
      {
        event = "PLAYER_TARGET_CHANGED",
      },
      {
        event = "PLAYER_FOCUS_CHANGED",
      },
      {
        event = "NAME_PLATE_UNIT_ADDED",
        unit = "nameplate3",
      },
    }, received)
  end)

  it("ignores secret nameplate names without throwing", function()
    names.nameplate1 = "Edwin VanCleef"
    _G.issecretvalue = function(value)
      return value == "SECRET"
    end
    _G.GetUnitName = function()
      return "SECRET"
    end
    _G.UnitName = function()
      return "SECRET"
    end

    local dependencies = WowBridge.CreateDependencies()
    local received = {}

    dependencies.registerEvent("NAME_PLATE_UNIT_ADDED", function(event, payload)
      received[#received + 1] = {
        event = event,
        unit = payload.unit,
      }
    end)

    scripts.OnEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")

    assert.are.equal("nameplate1", received[1].unit)

    ---@type number
    local typesLogCount = 0
    ---@type number
    local index = 1
    while index <= #chatMessages do
      if string.find(chatMessages[index], "[Asmon Finder Types]", 1, true) then
        typesLogCount = typesLogCount + 1
      end
      index = index + 1
    end

    assert.is_true(typesLogCount >= 1)
    assert.is_truthy(string.find(chatMessages[1], "secret type=string", 1, true))
  end)

  it("detects a watched name from nameplate frames beyond fixed tokens", function()
    names.nameplate47 = "Donald"
    suffixes.nameplate47 = "Trump"
    _G.GetUnitName = function(unit)
      if suffixes[unit] then
        return names[unit] .. " " .. suffixes[unit]
      end
      return names[unit]
    end
    _G.C_NamePlate = {
      GetNamePlates = function()
        return {
          {
            namePlateUnitToken = "nameplate47",
          },
        }
      end,
    }

    local dependencies = WowBridge.CreateDependencies()
    ---@type string[]
    local targetNames = {}
    dependencies.getSettings = function()
      return {
        enabled = true,
        raidWarningEnabled = true,
        soundEnabled = false,
        chatEnabled = false,
        autoTargetEnabled = false,
        alertCooldownMs = 0,
        targetNames = targetNames,
      }
    end

    local finder = Core.CreateAsmonFinder(dependencies)
    finder.Start()
    targetNames[1] = "Donald Trump"
    scripts.OnUpdate(nil, 0.5)

    assert.are.equal("Donald Trump DETECTED", chatMessages[1])
    assert.are.equal("Donald Trump", AsmonFinderDB.lastSeen.name)
    assert.are.equal("nameplate", AsmonFinderDB.lastSeen.source)
  end)

  it("combines Forever first and second UnitName values", function()
    names.nameplate2 = "Red"
    suffixes.nameplate2 = "Myst"

    local dependencies = WowBridge.CreateDependencies()
    dependencies.getSettings = function()
      return {
        enabled = true,
        raidWarningEnabled = true,
        soundEnabled = false,
        chatEnabled = false,
        autoTargetEnabled = false,
        alertCooldownMs = 0,
        targetNames = { "Red Myst" },
      }
    end

    local finder = Core.CreateAsmonFinder(dependencies)
    finder.Start()
    scripts.OnUpdate(nil, 0.5)

    assert.are.equal("Red Myst DETECTED", chatMessages[1])
    assert.are.equal("Red Myst", AsmonFinderDB.lastSeen.name)
  end)

  it("warns when friendly nameplates disable nearby-player scanning", function()
    _G.GetCVar = function(name)
      if name == "nameplateShowFriends" then
        return "0"
      end
      return nil
    end

    local dependencies = WowBridge.CreateDependencies()
    dependencies.registerEvent("PLAYER_LOGIN", function() end)
    scripts.OnEvent(nil, "PLAYER_LOGIN")

    assert.are.equal(
      "[Asmon Finder] Nearby-player scanning needs friendly nameplates. Press Shift+V to enable them.",
      chatMessages[1]
    )
  end)

  it("prints exact names currently exposed by the client", function()
    names.target = "Donald"
    names.mouseover = "Joe Biden"
    suffixes.target = "Trump"
    _G.GetUnitName = function(unit)
      if suffixes[unit] then
        return names[unit] .. " " .. suffixes[unit]
      end
      return names[unit]
    end
    _G.UnitFullName = function(unit)
      return names[unit], suffixes[unit]
    end
    _G.UnitGUID = function(unit)
      return "guid-" .. unit
    end

    local dependencies = WowBridge.CreateDependencies()
    dependencies.inspectUnits()

    assert.are.equal(
      "[Asmon Finder Inspect] target = [Donald Trump]",
      chatMessages[1]
    )
    assert.are.equal(
      "[Asmon Finder Inspect API] target UnitName=[Donald] second=[Trump] GetUnitName=[Donald Trump] UnitFullName=[Donald] second=[Trump] GUID=[guid-target]",
      chatMessages[2]
    )
    assert.are.equal(
      "[Asmon Finder Inspect] mouseover = [Joe Biden]",
      chatMessages[3]
    )
  end)

  it("toggles scanner diagnostics", function()
    local dependencies = WowBridge.CreateDependencies()

    assert.is_true(dependencies.toggleDebug())
    assert.is_false(dependencies.toggleDebug())
  end)

  it("debug logs only watched nameplates", function()
    names.nameplate1 = "Joe Biden"
    names.nameplate2 = "Donald Trump"

    WowBridge.SetIsWatchedName(function(name)
      return name == "Donald Trump"
    end)

    local dependencies = WowBridge.CreateDependencies()
    dependencies.toggleDebug()
    dependencies.registerEvent("NAME_PLATE_UNIT_ADDED", function() end)

    scripts.OnEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    scripts.OnEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate2")

    assert.are.equal(1, #chatMessages)
    assert.are.equal(
      "[Asmon Finder Debug] nameplate2 = [Donald Trump]",
      chatMessages[1]
    )
  end)

  it("uses the legacy destination-name combat-log slot", function()
    local dependencies = WowBridge.CreateDependencies()
    local payload

    dependencies.registerEvent(
      "COMBAT_LOG_EVENT_UNFILTERED",
      function(_, receivedPayload)
        payload = receivedPayload
      end
    )

    scripts.OnEvent(
      nil,
      "COMBAT_LOG_EVENT_UNFILTERED",
      1,
      "SPELL_DAMAGE",
      false,
      "source-guid",
      "Donald Trump",
      0,
      "destination-guid",
      "Joe Biden",
      0
    )

    assert.are.equal("Donald Trump", payload.sourceName)
    assert.are.equal("Joe Biden", payload.destinationName)
  end)

  it("does not call TargetUnit and queues the click button", function()
    local targetedUnit
    local shownName
    _G.TargetUnit = function(unit)
      targetedUnit = unit
    end
    _G.TargetByName = function()
      error("TargetByName should not run")
    end

    AsmonFinder.settingsPanel = {
      ShowSecureTarget = function(name)
        shownName = name
      end,
    }

    local dependencies = WowBridge.CreateDependencies()
    dependencies.requestTarget("Shadow Reaver")

    assert.is_nil(targetedUnit)
    assert.are.equal("Shadow Reaver", shownName)
    assert.are.equal(
      "[Asmon Finder Target] click Target [Shadow Reaver]",
      chatMessages[1]
    )
  end)

  it("skips targeting when that character is already selected", function()
    local shownName
    names.target = "Stad"
    suffixes.target = "Swipe"
    _G.GetUnitName = function(unit)
      if suffixes[unit] then
        return names[unit] .. " " .. suffixes[unit]
      end
      return names[unit]
    end
    _G.TargetUnit = function()
      error("TargetUnit should not run")
    end

    AsmonFinder.settingsPanel = {
      ShowSecureTarget = function(name)
        shownName = name
      end,
    }

    local dependencies = WowBridge.CreateDependencies()
    dependencies.requestTarget("Stad Swipe")

    assert.is_nil(shownName)
    assert.are.equal(
      "[Asmon Finder Target] already targeted [Stad Swipe]",
      chatMessages[1]
    )
  end)
end)
