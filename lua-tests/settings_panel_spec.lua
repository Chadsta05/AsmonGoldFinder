describe("AsmonFinder SettingsPanel controller", function()
  local Settings
  local SettingsPanel

  before_each(function()
    AsmonFinder = nil
    dofile("AsmonFinder/Types.lua")
    dofile("AsmonFinder/Settings.lua")
    dofile("AsmonFinder/SettingsPanel.lua")
    Settings = AsmonFinder.Settings
    SettingsPanel = AsmonFinder.SettingsPanel
  end)

  local function CreateFixture(lastSeen)
    local store = Settings.CreateSettingsStore()
    local requestedTarget = nil
    local testAlerts = {}

    local panel = SettingsPanel.Create({
      getSettings = store.GetSettings,
      updateSettings = store.UpdateSettings,
      getLastSeen = function()
        return lastSeen
      end,
      requestTarget = function(name)
        requestedTarget = name
      end,
      showAlert = function(name, source)
        testAlerts[#testAlerts + 1] = {
          name = name,
          source = source,
        }
      end,
    })

    return {
      panel = panel,
      store = store,
      testAlerts = testAlerts,
      getRequestedTarget = function()
        return requestedTarget
      end,
    }
  end

  it("adds full names and rejects case-insensitive duplicates", function()
    local fixture = CreateFixture()

    fixture.panel.AddTarget("Donald Trump")
    fixture.panel.AddTarget("donald trump")

    assert.same({
      "Asmongold",
      "Asmongler",
      "Donald Trump",
    }, fixture.store.GetSettings().targetNames)
  end)

  it("ignores blank names", function()
    local fixture = CreateFixture()

    fixture.panel.AddTarget("   ")

    assert.same({
      "Asmongold",
      "Asmongler",
    }, fixture.store.GetSettings().targetNames)
  end)

  it("removes watched names case-insensitively", function()
    local fixture = CreateFixture()

    fixture.panel.RemoveTarget("ASMONGOLD")

    assert.same({ "Asmongler" }, fixture.store.GetSettings().targetNames)
  end)

  it("requests targeting for the last sighting", function()
    local fixture = CreateFixture({
      name = "Donald Trump",
      zone = "Elwynn Forest",
      source = "target",
      time = 1000,
    })

    fixture.panel.TargetLastSeen()

    assert.are.equal("Donald Trump", fixture.getRequestedTarget())
  end)

  it("does nothing when no last sighting exists", function()
    local fixture = CreateFixture(nil)

    fixture.panel.TargetLastSeen()

    assert.is_nil(fixture.getRequestedTarget())
  end)

  it("fires developer tests for custom and fallback names", function()
    local fixture = CreateFixture()

    fixture.panel.FireTestAlert("Joe Biden")
    fixture.panel.FireTestAlert("   ")

    assert.same({
      {
        name = "Joe Biden",
        source = "test",
      },
      {
        name = "Asmongold",
        source = "test",
      },
    }, fixture.testAlerts)
  end)

  it("keeps three Target buttons and drops the oldest", function()
    local queue = { "One" }

    queue = SettingsPanel.PushQueuedName(queue, "Two")
    queue = SettingsPanel.PushQueuedName(queue, "Three")
    queue = SettingsPanel.PushQueuedName(queue, "Four")

    assert.same({ "Two", "Three", "Four" }, queue)
  end)

  it("moves a duplicate Target name to the newest slot", function()
    local queue = { "One", "Two" }

    queue = SettingsPanel.PushQueuedName(queue, "One")

    assert.same({ "Two", "One" }, queue)
  end)
end)
