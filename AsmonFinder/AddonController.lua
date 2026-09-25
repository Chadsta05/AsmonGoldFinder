--[[
  AsmonFinder.AddonController

  Lua translation of asmon-finder/src/AddonController.js
  Slash-command behavior: /asmon, test [name], reset, help
]]

---@type AsmonFinderNamespace
AsmonFinder = AsmonFinder or {}
AsmonFinder.AddonController = AsmonFinder.AddonController or {}

---@type table
local AddonController = AsmonFinder.AddonController

---Fallback character used by `/asmon test`.
---@type string
local DEFAULT_TEST_NAME = "Asmongold"

---Trim slash-command input.
---@param value? string Command text.
---@return string trimmed Trimmed text.
local function Trim(value)
  if not value then
    return ""
  end

  return (value:match("^%s*(.-)%s*$")) or ""
end

---Create the slash-command controller.
---@param dependencies AsmonFinderControllerDependencies Controller adapters.
---@return AsmonFinderControllerApi controller Slash-command API.
function AddonController.Create(dependencies)
  ---@type AsmonFinderControllerApi
  local controller = {}

  ---Print all supported slash commands to chat.
  local function ShowHelp()
    dependencies.printToChat("[Asmon Finder] Commands:")
    dependencies.printToChat(
      "Open /asmon, add full character names, and leave scanning enabled."
    )
    dependencies.printToChat(
      "Features: exact-name alerts, last-seen location/coords, and secure targeting."
    )
    dependencies.printToChat("/asmon - Open or close settings")
    dependencies.printToChat("/asmon test - Test alert (Asmongold)")
    dependencies.printToChat("/asmon test <name> - Test alert for any full name")
    dependencies.printToChat("/asmon inspect - Print visible unit names")
    dependencies.printToChat("/asmon debug - Toggle debug for watched names only")
    dependencies.printToChat("/asmon reset - Reset settings")
    dependencies.printToChat("/asmon help - Show commands")
  end

  ---Handle `/asmon` command input.
  ---@param input? string Text after `/asmon`.
  function controller.HandleSlashCommand(input)
    local trimmedInput = Trim(input or "")

    if trimmedInput == "" then
      dependencies.settingsPanel.Toggle()
      return
    end

    local lowerInput = string.lower(trimmedInput)

    if lowerInput == "test" then
      dependencies.showAlert(DEFAULT_TEST_NAME, "test")
      return
    end

    if string.sub(lowerInput, 1, 5) == "test " then
      local name = Trim(string.sub(trimmedInput, 6))

      if name == "" then
        name = DEFAULT_TEST_NAME
      end

      dependencies.showAlert(name, "test")
      return
    end

    if lowerInput == "inspect" then
      dependencies.inspectUnits()
      return
    end

    if lowerInput == "debug" then
      local enabled = dependencies.toggleDebug()
      local state = "OFF"

      if enabled then
        state = "ON"
      end

      dependencies.printToChat(
        "[Asmon Finder] Debug " .. state .. " (watched names only)."
      )
      return
    end

    if lowerInput == "reset" then
      dependencies.resetSettings()
      dependencies.printToChat("[Asmon Finder] Settings reset.")
      return
    end

    ShowHelp()
  end

  return controller
end
