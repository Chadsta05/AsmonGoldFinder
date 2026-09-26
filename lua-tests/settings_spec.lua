describe("AsmonFinder Settings", function()
  local Settings

  before_each(function()
    AsmonFinder = nil
    dofile("AsmonFinder/Types.lua")
    dofile("AsmonFinder/Settings.lua")
    Settings = AsmonFinder.Settings
  end)

  it("creates complete default settings", function()
    local settings = Settings.CreateDefaultSettings()

    assert.is_true(settings.enabled)
    assert.are.equal(10000, settings.alertCooldownMs)
    assert.is_true(settings.raidWarningEnabled)
    assert.is_true(settings.soundEnabled)
    assert.is_true(settings.chatEnabled)
    assert.is_true(settings.autoTargetEnabled)
    assert.same({ "Asmongold", "Asmongler" }, settings.targetNames)
  end)

  it("returns independent target-name arrays", function()
    local first = Settings.CreateDefaultSettings()
    local second = Settings.CreateDefaultSettings()

    first.targetNames[#first.targetNames + 1] = "Donald Trump"

    assert.same({ "Asmongold", "Asmongler" }, second.targetNames)
  end)

  it("merges an old save with current defaults", function()
    local merged = Settings.MergeSettings({
      enabled = false,
      soundEnabled = false,
    })

    assert.is_false(merged.enabled)
    assert.is_false(merged.soundEnabled)
    assert.is_true(merged.chatEnabled)
    assert.is_true(merged.raidWarningEnabled)
    assert.same({ "Asmongold", "Asmongler" }, merged.targetNames)
  end)

  it("copies target names supplied by SavedVariables", function()
    local savedNames = { "Donald Trump", "Joe Biden" }
    local merged = Settings.MergeSettings({
      targetNames = savedNames,
    })

    savedNames[1] = "Changed"

    assert.same({ "Donald Trump", "Joe Biden" }, merged.targetNames)
  end)

  it("converts seconds to non-negative milliseconds", function()
    assert.are.equal(15000, Settings.SecondsToMilliseconds(15))
    assert.are.equal(0, Settings.SecondsToMilliseconds(-1))
  end)

  it("converts milliseconds to seconds", function()
    assert.are.equal(12, Settings.MillisecondsToSeconds(12000))
  end)

  it("updates and resets the settings store", function()
    local store = Settings.CreateSettingsStore()

    local updated = store.UpdateSettings({
      enabled = false,
      targetNames = { "Donald Trump" },
    })

    assert.is_false(updated.enabled)
    assert.same({ "Donald Trump" }, updated.targetNames)

    local reset = store.ResetSettings()

    assert.is_true(reset.enabled)
    assert.same({ "Asmongold", "Asmongler" }, reset.targetNames)
  end)
end)
