describe("AsmonFinder Core", function()
  local Core
  local Settings

  before_each(function()
    AsmonFinder = nil
    dofile("AsmonFinder/Types.lua")
    dofile("AsmonFinder/TypeGuards.lua")
    dofile("AsmonFinder/Settings.lua")
    dofile("AsmonFinder/Core.lua")
    Core = AsmonFinder.Core
    Settings = AsmonFinder.Settings
  end)

  local function CreateFixture(options)
    options = options or {}

    local store = Settings.CreateSettingsStore(options.settings)
    local currentTime = options.currentTime or 1000
    local currentUnitName = options.unitName
    local lastSeen = nil
    local warnings = {}
    local chatMessages = {}
    local soundCount = 0
    local requestedTarget = nil
    local registeredEvents = {}

    local finder = Core.CreateAsmonFinder({
      getZoneText = function()
        return "Elwynn Forest"
      end,
      getSubZoneText = function()
        return "Goldshire"
      end,
      getPlayerPosition = function()
        return {
          x = 42.5,
          y = 61.25,
          mapId = "1429",
        }
      end,
      unitExists = function()
        if options.unitExists == nil then
          return true
        end

        return options.unitExists
      end,
      unitName = function()
        return currentUnitName
      end,
      saveLastSeen = function(detection)
        lastSeen = detection
      end,
      getLastSeen = function()
        return lastSeen
      end,
      showRaidWarning = function(message)
        warnings[#warnings + 1] = message
      end,
      printToChat = function(message)
        chatMessages[#chatMessages + 1] = message
      end,
      playRaidWarningSound = function()
        soundCount = soundCount + 1
      end,
      requestTarget = function(name)
        requestedTarget = name
      end,
      registerEvent = function(event)
        registeredEvents[#registeredEvents + 1] = event
      end,
      now = function()
        return currentTime
      end,
      getSettings = store.GetSettings,
    })

    return {
      finder = finder,
      store = store,
      warnings = warnings,
      chatMessages = chatMessages,
      registeredEvents = registeredEvents,
      getSoundCount = function()
        return soundCount
      end,
      getRequestedTarget = function()
        return requestedTarget
      end,
      getLastSeen = function()
        return lastSeen
      end,
      setTime = function(time)
        currentTime = time
      end,
      setUnitName = function(name)
        currentUnitName = name
      end,
    }
  end

  it("normalizes full names without stripping spaces or hyphens", function()
    assert.are.equal("donald trump", Core.NormalizeName("  Donald Trump  "))
    assert.are.equal("jean-luc picard", Core.NormalizeName("Jean-Luc Picard"))
    assert.is_nil(Core.NormalizeName("   "))
  end)

  it("matches exact full names case-insensitively", function()
    local fixture = CreateFixture({
      settings = {
        targetNames = { "Donald Trump" },
      },
    })

    assert.is_true(fixture.finder.IsTarget("donald trump"))
    assert.is_false(fixture.finder.IsTarget("Donald"))
    assert.is_false(fixture.finder.IsTarget("Trump"))
  end)

  it("detects a watched target through the real event path", function()
    local fixture = CreateFixture({
      unitName = "Donald Trump",
      settings = {
        targetNames = { "Donald Trump" },
      },
    })

    fixture.finder.HandleEvent("PLAYER_TARGET_CHANGED")

    assert.same({ "Donald Trump DETECTED" }, fixture.warnings)
    assert.are.equal("target", fixture.getLastSeen().source)
    assert.are.equal(42.5, fixture.getLastSeen().x)
    assert.are.equal("1429", fixture.getLastSeen().mapId)
  end)

  it("detects watched mouseover, nameplate, and combat-log names", function()
    local fixture = CreateFixture({
      unitName = "Donald Trump",
      settings = {
        alertCooldownMs = 0,
        targetNames = { "Donald Trump" },
      },
    })

    fixture.finder.HandleEvent("UPDATE_MOUSEOVER_UNIT")
    fixture.finder.HandleEvent("NAME_PLATE_UNIT_ADDED", {
      unit = "nameplate3",
    })
    fixture.finder.HandleEvent("COMBAT_LOG_EVENT_UNFILTERED", {
      sourceName = "Donald Trump",
      destinationName = "Some Mob",
    })

    assert.are.equal(3, #fixture.warnings)
    assert.are.equal("combat log", fixture.getLastSeen().source)
  end)

  it("does not alert for unrelated or nonexistent units", function()
    local unrelated = CreateFixture({
      unitName = "Joe Biden",
      settings = {
        targetNames = { "Donald Trump" },
      },
    })

    unrelated.finder.HandleEvent("PLAYER_TARGET_CHANGED")
    assert.are.equal(0, #unrelated.warnings)

    local missing = CreateFixture({
      unitExists = false,
      unitName = "Donald Trump",
      settings = {
        targetNames = { "Donald Trump" },
      },
    })

    missing.finder.HandleEvent("PLAYER_TARGET_CHANGED")
    assert.are.equal(0, #missing.warnings)
  end)

  it("honors enabled state and every alert preference", function()
    local disabled = CreateFixture({
      settings = {
        enabled = false,
      },
    })

    disabled.finder.ShowAlert("Asmongold", "test")
    assert.are.equal(0, #disabled.warnings)

    local muted = CreateFixture({
      settings = {
        raidWarningEnabled = false,
        chatEnabled = false,
        soundEnabled = false,
      },
    })

    muted.finder.ShowAlert("Asmongold", "test")

    assert.are.equal(0, #muted.warnings)
    assert.are.equal(0, #muted.chatMessages)
    assert.are.equal(0, muted.getSoundCount())
    assert.is_not_nil(muted.getLastSeen())
  end)

  it("suppresses detections during cooldown and allows them afterward", function()
    local fixture = CreateFixture()

    fixture.finder.ShowAlert("Asmongold", "test")
    fixture.setTime(5000)
    fixture.finder.ShowAlert("Asmongold", "target")

    assert.are.equal(1, #fixture.warnings)

    fixture.setTime(11000)
    fixture.finder.ShowAlert("Asmongold", "target")

    assert.are.equal(2, #fixture.warnings)
  end)

  it("alerts a second watched name during another name's cooldown", function()
    local fixture = CreateFixture({
      settings = {
        autoTargetEnabled = true,
      },
    })

    fixture.finder.ShowAlert("Asmongold", "nameplate")
    fixture.setTime(5000)
    fixture.finder.ShowAlert("Donald Trump", "nameplate")

    assert.are.equal(2, #fixture.warnings)
    assert.are.equal("Donald Trump", fixture.getRequestedTarget())
  end)

  it("requests secure targeting when enabled", function()
    local fixture = CreateFixture({
      settings = {
        autoTargetEnabled = true,
      },
    })

    fixture.finder.ShowAlert("Donald Trump", "test")

    assert.are.equal("Donald Trump", fixture.getRequestedTarget())
  end)

  it("uses dynamically updated watched names", function()
    local fixture = CreateFixture()

    fixture.store.UpdateSettings({
      targetNames = { "Joe Biden" },
    })

    assert.is_true(fixture.finder.IsTarget("Joe Biden"))
    assert.is_false(fixture.finder.IsTarget("Asmongold"))
  end)

  it("registers every required WoW event", function()
    local fixture = CreateFixture()

    fixture.finder.Start()

    assert.same(Core.EVENTS, fixture.registeredEvents)
  end)
end)
