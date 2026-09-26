describe("AsmonFinder AddonController", function()
  local AddonController

  before_each(function()
    AsmonFinder = nil
    dofile("AsmonFinder/Types.lua")
    dofile("AsmonFinder/AddonController.lua")
    AddonController = AsmonFinder.AddonController
  end)

  local function CreateFixture()
    local toggleCount = 0
    local resetCount = 0
    local inspectCount = 0
    local debugEnabled = false
    local chatMessages = {}
    local alerts = {}

    local controller = AddonController.Create({
      settingsPanel = {
        Toggle = function()
          toggleCount = toggleCount + 1
        end,
      },
      resetSettings = function()
        resetCount = resetCount + 1
      end,
      printToChat = function(message)
        chatMessages[#chatMessages + 1] = message
      end,
      showAlert = function(name, source)
        alerts[#alerts + 1] = {
          name = name,
          source = source,
        }
      end,
      inspectUnits = function()
        inspectCount = inspectCount + 1
      end,
      toggleDebug = function()
        debugEnabled = not debugEnabled
        return debugEnabled
      end,
    })

    return {
      controller = controller,
      chatMessages = chatMessages,
      alerts = alerts,
      getToggleCount = function()
        return toggleCount
      end,
      getResetCount = function()
        return resetCount
      end,
      getInspectCount = function()
        return inspectCount
      end,
    }
  end

  it("toggles settings for an empty command", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("")

    assert.are.equal(1, fixture.getToggleCount())
  end)

  it("fires the default test alert", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("test")

    assert.same({
      {
        name = "Asmongold",
        source = "test",
      },
    }, fixture.alerts)
  end)

  it("fires a test alert for a custom full name", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("test Donald Trump")

    assert.same({
      {
        name = "Donald Trump",
        source = "test",
      },
    }, fixture.alerts)
  end)

  it("resets settings and confirms in chat", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("reset")

    assert.are.equal(1, fixture.getResetCount())
    assert.are.equal(
      "[Asmon Finder] Settings reset.",
      fixture.chatMessages[1]
    )
  end)

  it("inspects units exposed by the client", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("inspect")

    assert.are.equal(1, fixture.getInspectCount())
  end)

  it("toggles live debug diagnostics", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("debug")
    fixture.controller.HandleSlashCommand("debug")

    assert.are.equal(
      "[Asmon Finder] Debug ON (watched names only).",
      fixture.chatMessages[1]
    )
    assert.are.equal(
      "[Asmon Finder] Debug OFF (watched names only).",
      fixture.chatMessages[2]
    )
  end)

  it("prints help for unknown commands", function()
    local fixture = CreateFixture()

    fixture.controller.HandleSlashCommand("unknown")

    assert.are.equal("[Asmon Finder] Commands:", fixture.chatMessages[1])
    assert.are.equal(
      "Features: exact-name alerts, last-seen location/coords, and secure targeting.",
      fixture.chatMessages[3]
    )
    assert.is_true(#fixture.chatMessages >= 8)
  end)
end)
