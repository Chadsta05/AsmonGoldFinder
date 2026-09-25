--[[
  AsmonFinder.SettingsPanel

  Controller + in-game settings frame.
  Behavior mirrors asmon-finder/src/SettingsPanel.js
]]

---@type AsmonFinderNamespace
AsmonFinder = AsmonFinder or {}
AsmonFinder.SettingsPanel = AsmonFinder.SettingsPanel or {}

---@type table
local SettingsPanel = AsmonFinder.SettingsPanel
---@type table
local Settings = AsmonFinder.Settings

---Trim user-entered character names and command values.
---@param value? string Input text.
---@return string trimmed Trimmed text.
local function Trim(value)
  if not value then
    return ""
  end

  return (value:match("^%s*(.-)%s*$")) or ""
end

---Maximum floating Target buttons shown at once.
---@type number
local MAX_QUEUED_TARGETS = 3

---Trim a queued target name.
---@param name? string Full character name.
---@return string? trimmed Name or nil when blank.
function SettingsPanel.NormalizeQueuedName(name)
  if not name then
    return nil
  end

  local trimmed = Trim(name)
  if trimmed == "" then
    return nil
  end

  return trimmed
end

---Add a name to the Target-button queue. Oldest is dropped past three.
---A duplicate is moved to the newest slot instead of appearing twice.
---@param queue string[] Current queued names.
---@param name? string Full character name to add.
---@return string[] queue Updated queue.
function SettingsPanel.PushQueuedName(queue, name)
  local trimmed = SettingsPanel.NormalizeQueuedName(name)
  ---@type string[]
  local nextQueue = {}

  if not trimmed then
    for index = 1, #queue do
      nextQueue[index] = queue[index]
    end
    return nextQueue
  end

  local normalized = string.lower(trimmed)

  for index = 1, #queue do
    if string.lower(queue[index]) ~= normalized then
      nextQueue[#nextQueue + 1] = queue[index]
    end
  end

  nextQueue[#nextQueue + 1] = trimmed

  while #nextQueue > MAX_QUEUED_TARGETS do
    table.remove(nextQueue, 1)
  end

  return nextQueue
end

---Remove one name from the Target-button queue.
---@param queue string[] Current queued names.
---@param name? string Full character name to remove.
---@return string[] queue Updated queue.
function SettingsPanel.RemoveQueuedName(queue, name)
  local trimmed = SettingsPanel.NormalizeQueuedName(name)
  ---@type string[]
  local nextQueue = {}

  if not trimmed then
    for index = 1, #queue do
      nextQueue[index] = queue[index]
    end
    return nextQueue
  end

  local normalized = string.lower(trimmed)

  for index = 1, #queue do
    if string.lower(queue[index]) ~= normalized then
      nextQueue[#nextQueue + 1] = queue[index]
    end
  end

  return nextQueue
end

---Apply the dark tabard palette to a standard WoW button.
---@param button any Button frame to style.
local function StyleTabardButton(button)
  ---@type any
  local border = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
  border:SetColorTexture(0.38, 0.55, 0.74, 1)

  ---@type any
  local normal = button:CreateTexture(nil, "BACKGROUND")
  normal:SetColorTexture(0.025, 0.13, 0.32, 0.98)
  button:SetNormalTexture(normal)

  ---@type any
  local pushed = button:CreateTexture(nil, "BACKGROUND")
  pushed:SetColorTexture(0.02, 0.08, 0.22, 1)
  button:SetPushedTexture(pushed)

  ---@type any
  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetColorTexture(0.18, 0.5, 0.9, 0.3)
  button:SetHighlightTexture(highlight)

  ---@type any?
  local fontString = button:GetFontString()
  if fontString then
    fontString:SetTextColor(0.88, 0.95, 1, 1)
  end
end

---Apply an opaque navy fill and steel-blue border to a frame.
---@param target any Frame to style.
local function StyleTabardBox(target)
  ---@type any
  local border = target:CreateTexture(nil, "BACKGROUND", nil, -8)
  border:SetPoint("TOPLEFT", target, "TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 2, -2)
  border:SetColorTexture(0.3, 0.5, 0.72, 1)

  ---@type any
  local fill = target:CreateTexture(nil, "BACKGROUND", nil, -7)
  fill:SetAllPoints(target)
  fill:SetColorTexture(0.002, 0.02, 0.07, 0.96)
end

---Replace the brown InputBoxTemplate artwork with the tabard palette.
---@param editBox any Named edit box to style.
local function StyleTabardInput(editBox)
  StyleTabardBox(editBox)

  ---@type string?
  local name = editBox:GetName()
  if not name then
    return
  end

  ---@type string[]
  local suffixes = { "Left", "Middle", "Mid", "Right" }
  for _, suffix in ipairs(suffixes) do
    ---@type any?
    local region = _G[name .. suffix]
    if region then
      region:SetAlpha(0)
    end
  end
end

---Replace Blizzard's green checkbox art with a silver-blue checkmark.
---@param check any CheckButton frame to style.
local function StyleTabardCheck(check)
  ---@type any?
  local normalTexture = check:GetNormalTexture()
  if normalTexture then
    normalTexture:SetAlpha(0)
  end

  ---@type any?
  local checkedTexture = check:GetCheckedTexture()
  if checkedTexture then
    checkedTexture:SetAlpha(0)
  end

  ---@type any
  local border = check:CreateTexture(nil, "ARTWORK")
  border:SetSize(22, 22)
  border:SetPoint("LEFT", check, "LEFT", 3, 0)
  border:SetColorTexture(0.45, 0.65, 0.84, 1)

  ---@type any
  local fill = check:CreateTexture(nil, "ARTWORK", nil, 1)
  fill:SetSize(18, 18)
  fill:SetPoint("CENTER", border, "CENTER", 0, 0)
  fill:SetColorTexture(0.005, 0.035, 0.11, 1)

  ---@type any
  local mark = check:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  mark:SetPoint("CENTER", border, "CENTER", 0, 1)
  mark:SetText("✓")
  mark:SetTextColor(0.86, 0.96, 1, 1)
  mark:Hide()
  check.AsmonFinderCheckMark = mark
end

---Synchronize a custom checkmark after programmatic setting changes.
---@param check any CheckButton frame with tabard styling.
local function SyncTabardCheck(check)
  if not check.AsmonFinderCheckMark then
    return
  end

  check.AsmonFinderCheckMark:SetShown(check:GetChecked())
end

---Create the settings controller and lazy in-game frame.
---@param dependencies AsmonFinderSettingsPanelDependencies UI adapters.
---@return AsmonFinderSettingsPanelApi panel Settings panel API.
function SettingsPanel.Create(dependencies)
  ---@type boolean
  local visible = false
  ---@type AsmonFinderSettingsPanelApi
  local panel = {}
  ---@type any?
  local frame
  ---@type AsmonFinderSettingsWidgets
  local widgets = {}
  ---@type string[]
  local queuedTargetNames = {}
  ---@type fun()?
  local PositionSecureTarget
  ---@type fun()?
  local SyncTargetButtons

  ---Persist the Target stack's dragged position.
  local function SaveTargetStackPosition()
    if not widgets.targetStack then
      return
    end

    ---@type string?, any, string?, number?, number?
    local point, _, relativePoint, x, y = widgets.targetStack:GetPoint(1)
    if not point then
      return
    end

    AsmonFinderDB = AsmonFinderDB or {}
    AsmonFinderDB.targetStackPosition = {
      point = point,
      relativePoint = relativePoint or point,
      x = x or 0,
      y = y or 0,
    }
  end

  ---Restore the Target stack to its last dragged position.
  local function RestoreTargetStackPosition()
    if not widgets.targetStack then
      return
    end

    widgets.targetStack:ClearAllPoints()
    AsmonFinderDB = AsmonFinderDB or {}
    ---@type AsmonFinderFramePosition?
    local saved = AsmonFinderDB.targetStackPosition

    if saved and saved.point then
      widgets.targetStack:SetPoint(
        saved.point,
        UIParent,
        saved.relativePoint or saved.point,
        saved.x or 0,
        saved.y or 0
      )
      return
    end

    widgets.targetStack:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
  end

  ---Render settings, watched names, and last-seen data into existing widgets.
  local function Refresh()
    if not frame then
      return
    end

    ---@type AsmonFinderSettings
    local settings = dependencies.getSettings()

    widgets.enabled:SetChecked(settings.enabled)
    widgets.raidWarning:SetChecked(settings.raidWarningEnabled)
    widgets.sound:SetChecked(settings.soundEnabled)
    widgets.chat:SetChecked(settings.chatEnabled)
    widgets.autoTarget:SetChecked(settings.autoTargetEnabled)
    SyncTabardCheck(widgets.enabled)
    SyncTabardCheck(widgets.raidWarning)
    SyncTabardCheck(widgets.sound)
    SyncTabardCheck(widgets.chat)
    SyncTabardCheck(widgets.autoTarget)

    local seconds = Settings.MillisecondsToSeconds(settings.alertCooldownMs)
    widgets.cooldown:SetValue(seconds)
    widgets.cooldownLabel:SetText(string.format("%d seconds", seconds))

    -- Rebuild every watched name inside the fixed scrollable viewport.
    for _, child in ipairs(widgets.nameRows) do
      child:Hide()
      child:SetParent(nil)
    end
    widgets.nameRows = {}

    ---@type number
    local totalNames = #settings.targetNames
    widgets.watchedTitle:SetText(
      string.format("WATCHED CHARACTERS (%d)", totalNames)
    )

    local y = 0
    for index = 1, totalNames do
      local name = settings.targetNames[index]
      local row = CreateFrame("Frame", nil, widgets.nameList)
      row:SetSize(280, 22)
      row:SetPoint("TOPLEFT", widgets.nameList, "TOPLEFT", 0, -y)

      local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      label:SetPoint("LEFT", row, "LEFT", 4, 0)
      label:SetText(name)

      local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      remove:SetSize(20, 20)
      remove:SetPoint("RIGHT", row, "RIGHT", 0, 0)
      remove:SetText("X")
      StyleTabardButton(remove)
      remove:SetScript("OnClick", function()
        panel.RemoveTarget(name)
        Refresh()
        AsmonFinder.PersistSettings()
      end)

      widgets.nameRows[#widgets.nameRows + 1] = row
      y = y + 24
    end

    widgets.nameList:SetHeight(math.max(y, 72))

    ---@type AsmonFinderDetection?
    local lastSeen = dependencies.getLastSeen()
    if not lastSeen then
      widgets.lastSeenName:SetText("No sightings yet")
      widgets.lastSeenZone:SetText("")
      widgets.lastSeenSource:SetText("")
      widgets.lastSeenCoords:SetText("")
      widgets.lastSeenZone:Hide()
      widgets.lastSeenSource:Hide()
      widgets.lastSeenCoords:Hide()
      widgets.devTitle:ClearAllPoints()
      widgets.devTitle:SetPoint(
        "TOPLEFT",
        widgets.lastSeenName,
        "BOTTOMLEFT",
        0,
        -18
      )
    else
      widgets.lastSeenName:SetText(lastSeen.name or "")
      widgets.lastSeenZone:SetText(lastSeen.zone or "")
      widgets.lastSeenSource:SetText("Detected via " .. (lastSeen.source or ""))
      widgets.lastSeenZone:Show()
      widgets.lastSeenSource:Show()
      widgets.lastSeenCoords:Show()
      widgets.devTitle:ClearAllPoints()
      widgets.devTitle:SetPoint(
        "TOPLEFT",
        widgets.lastSeenCoords,
        "BOTTOMLEFT",
        0,
        -14
      )

      if lastSeen.x and lastSeen.y then
        local coords = string.format("Coords %.1f, %.1f", lastSeen.x, lastSeen.y)
        if lastSeen.mapId then
          coords = coords .. " (map " .. tostring(lastSeen.mapId) .. ")"
        end
        widgets.lastSeenCoords:SetText(coords)
      else
        widgets.lastSeenCoords:SetText("")
      end
    end
  end

  ---Create the in-game frame and widgets once, then reuse them.
  ---@return any frame Settings frame.
  local function EnsureFrame()
    if frame then
      return frame
    end

    frame = CreateFrame("Frame", "AsmonFinderSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(430, 780)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClipsChildren(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if frame.Bg then
      frame.Bg:SetAlpha(0)
    end
    if frame.InsetBg then
      frame.InsetBg:SetAlpha(0)
    end

    widgets.panelUnderlay = frame:CreateTexture(
      nil,
      "BACKGROUND",
      nil,
      -8
    )
    widgets.panelUnderlay:SetPoint(
      "TOPLEFT",
      frame,
      "TOPLEFT",
      10,
      -28
    )
    widgets.panelUnderlay:SetPoint(
      "BOTTOMRIGHT",
      frame,
      "BOTTOMRIGHT",
      -10,
      10
    )
    widgets.panelUnderlay:SetColorTexture(0.002, 0.012, 0.045, 1)

    widgets.panelBackground = frame:CreateTexture(
      nil,
      "BACKGROUND",
      nil,
      -7
    )
    widgets.panelBackground:SetPoint(
      "TOPLEFT",
      frame,
      "TOPLEFT",
      10,
      -118
    )
    widgets.panelBackground:SetPoint(
      "BOTTOMRIGHT",
      frame,
      "BOTTOMRIGHT",
      -10,
      -80
    )
    widgets.panelBackground:SetTexture(
      "Interface\\AddOns\\AsmonFinder\\images\\TabardPanel.tga"
    )
    widgets.panelBackground:SetTexCoord(0, 1, 0, 1)
    widgets.panelBackground:SetAlpha(0.82)

    frame.TitleText:SetText("Asmon Finder Control Center")
    frame.TitleText:SetTextColor(0.76, 0.88, 1, 1)
    frame.CloseButton:ClearAllPoints()
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    frame.CloseButton:SetSize(22, 22)
    frame.CloseButton:SetText("")
    StyleTabardButton(frame.CloseButton)
    ---@type any
    local closeMark = frame.CloseButton:CreateFontString(
      nil,
      "OVERLAY",
      "GameFontNormalLarge"
    )
    closeMark:SetPoint("CENTER", frame.CloseButton, "CENTER", 0, 1)
    closeMark:SetText("×")
    closeMark:SetTextColor(0.9, 0.97, 1, 1)

    frame:SetScript("OnHide", function()
      visible = false
    end)

    -- Gold-framed hero art. This power-of-two TGA is pre-cropped because WoW
    -- does not reliably render arbitrary PNG dimensions as addon textures.
    local heroBorder = frame:CreateTexture(nil, "BACKGROUND")
    heroBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    heroBorder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -34)
    heroBorder:SetHeight(186)
    heroBorder:SetColorTexture(0.18, 0.43, 0.72, 1)

    widgets.heroArt = frame:CreateTexture(nil, "ARTWORK")
    widgets.heroArt:SetPoint("TOPLEFT", heroBorder, "TOPLEFT", 3, -3)
    widgets.heroArt:SetPoint("BOTTOMRIGHT", heroBorder, "BOTTOMRIGHT", -3, 3)
    widgets.heroArt:SetTexture(
      "Interface\\AddOns\\AsmonFinder\\images\\AsmonTabard_Hero.tga"
    )
    widgets.heroArt:SetTexCoord(0, 1, 0, 1)

    local heroShade = frame:CreateTexture(nil, "OVERLAY")
    heroShade:SetPoint("BOTTOMLEFT", widgets.heroArt, "BOTTOMLEFT", 0, 0)
    heroShade:SetPoint("BOTTOMRIGHT", widgets.heroArt, "BOTTOMRIGHT", 0, 0)
    heroShade:SetHeight(64)
    heroShade:SetColorTexture(0.005, 0.02, 0.075, 0.88)

    widgets.heroTitle = frame:CreateFontString(
      nil,
      "OVERLAY",
      "GameFontNormalHuge"
    )
    widgets.heroTitle:SetPoint(
      "BOTTOM",
      widgets.heroArt,
      "BOTTOM",
      0,
      30
    )
    widgets.heroTitle:SetText("FOR OLYMPUS!")
    widgets.heroTitle:SetTextColor(0.93, 0.97, 1, 1)
    widgets.heroTitle:SetShadowColor(0, 0, 0, 1)
    widgets.heroTitle:SetShadowOffset(2, -2)

    widgets.heroSubtitle = frame:CreateFontString(
      nil,
      "OVERLAY",
      "GameFontHighlightSmall"
    )
    widgets.heroSubtitle:SetPoint(
      "TOP",
      widgets.heroTitle,
      "BOTTOM",
      0,
      -2
    )
    widgets.heroSubtitle:SetText("WATCH THE WORLD. FIND THE LEGEND.")
    widgets.heroSubtitle:SetTextColor(0.63, 0.82, 1, 1)

    widgets.heroBadge = frame:CreateFontString(
      nil,
      "OVERLAY",
      "GameFontNormalSmall"
    )
    widgets.heroBadge:SetPoint(
      "TOPRIGHT",
      widgets.heroArt,
      "TOPRIGHT",
      -10,
      -8
    )
    widgets.heroBadge:SetText("FOREVER EDITION")
    widgets.heroBadge:SetTextColor(0.78, 0.9, 1, 1)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 40, -238)
    content:SetPoint("BOTTOMRIGHT", -40, 12)

    local contentWash = content:CreateTexture(nil, "BACKGROUND")
    contentWash:SetPoint("TOPLEFT", content, "TOPLEFT", -16, 12)
    contentWash:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 16, -2)
    contentWash:SetColorTexture(0.005, 0.025, 0.09, 0.72)

    ---Create one labeled settings checkbox.
    ---@param labelText string Visible checkbox label.
    ---@param offsetX number Horizontal offset from the content left.
    ---@param offsetY number Vertical offset from the content top.
    ---@return any checkButton Created check button.
    local function MakeCheck(labelText, offsetX, offsetY)
      local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
      check:SetPoint("TOPLEFT", content, "TOPLEFT", offsetX, offsetY)
      check.Text:SetText(labelText)
      check.Text:SetTextColor(0.86, 0.93, 1, 1)
      StyleTabardCheck(check)
      return check
    end

    widgets.enabled = MakeCheck("Enable Asmon Finder", 0, 0)
    widgets.enabled.Text:SetTextColor(0.86, 0.93, 1, 1)

    local alerts = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alerts:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -38)
    alerts:SetText("ALERTS")
    alerts:SetTextColor(0.43, 0.72, 1, 1)

    widgets.raidWarning = MakeCheck("Raid warning", 0, -58)
    widgets.sound = MakeCheck("Play sound", 112, -58)
    widgets.chat = MakeCheck("Chat message", 214, -58)

    local cooldownTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cooldownTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -96)
    cooldownTitle:SetText("ALERT COOLDOWN")
    cooldownTitle:SetTextColor(0.43, 0.72, 1, 1)

    widgets.cooldown = CreateFrame("Slider", "AsmonFinderCooldownSlider", content, "OptionsSliderTemplate")
    widgets.cooldown:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -116)
    widgets.cooldown:SetWidth(260)
    widgets.cooldown:SetMinMaxValues(0, 60)
    widgets.cooldown:SetValueStep(1)
    widgets.cooldown:SetObeyStepOnDrag(true)
    ---@type any?
    local cooldownThumb = widgets.cooldown:GetThumbTexture()
    if cooldownThumb then
      cooldownThumb:SetColorTexture(0.18, 0.62, 1, 1)
      cooldownThumb:SetSize(14, 14)
    end
    _G[widgets.cooldown:GetName() .. "Low"]:SetText("0s")
    _G[widgets.cooldown:GetName() .. "High"]:SetText("60s")
    _G[widgets.cooldown:GetName() .. "Text"]:SetText("")

    widgets.cooldownLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    widgets.cooldownLabel:SetPoint("TOP", widgets.cooldown, "BOTTOM", 0, -2)

    local targeting = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targeting:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -166)
    targeting:SetText("TARGETING")
    targeting:SetTextColor(0.43, 0.72, 1, 1)

    widgets.autoTarget = MakeCheck("Prepare target when detected", 0, -184)

    widgets.watchedTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    widgets.watchedTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -222)
    widgets.watchedTitle:SetText("WATCHED CHARACTERS (0)")
    widgets.watchedTitle:SetTextColor(0.43, 0.72, 1, 1)

    widgets.nameScroll = CreateFrame(
      "ScrollFrame",
      "AsmonFinderNameScroll",
      content,
      "UIPanelScrollFrameTemplate"
    )
    widgets.nameScroll:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -242)
    widgets.nameScroll:SetSize(310, 72)
    widgets.nameScroll:EnableMouseWheel(true)
    StyleTabardBox(widgets.nameScroll)
    widgets.nameScroll:SetScript("OnMouseWheel", function(self, delta)
      ---@type number
      local nextOffset = self:GetVerticalScroll() - (delta * 24)
      ---@type number
      local maximumOffset = self:GetVerticalScrollRange()

      if nextOffset < 0 then
        nextOffset = 0
      elseif nextOffset > maximumOffset then
        nextOffset = maximumOffset
      end

      self:SetVerticalScroll(nextOffset)
    end)

    widgets.nameList = CreateFrame("Frame", nil, widgets.nameScroll)
    widgets.nameList:SetSize(280, 72)
    widgets.nameScroll:SetScrollChild(widgets.nameList)
    widgets.nameRows = {}

    widgets.nameInput = CreateFrame("EditBox", "AsmonFinderNameInput", content, "InputBoxTemplate")
    widgets.nameInput:SetSize(200, 24)
    widgets.nameInput:SetPoint("TOPLEFT", widgets.nameScroll, "BOTTOMLEFT", 6, -16)
    widgets.nameInput:SetAutoFocus(false)
    StyleTabardInput(widgets.nameInput)

    widgets.addButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    widgets.addButton:SetSize(70, 24)
    widgets.addButton:SetPoint("LEFT", widgets.nameInput, "RIGHT", 8, 0)
    widgets.addButton:SetText("+ ADD")
    StyleTabardButton(widgets.addButton)

    local lastSeenTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lastSeenTitle:SetPoint("TOPLEFT", widgets.nameInput, "BOTTOMLEFT", -6, -16)
    lastSeenTitle:SetText("LAST SEEN")
    lastSeenTitle:SetTextColor(0.43, 0.72, 1, 1)

    widgets.lastSeenName = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widgets.lastSeenName:SetPoint("TOPLEFT", lastSeenTitle, "BOTTOMLEFT", 0, -6)
    widgets.lastSeenName:SetTextColor(0.86, 0.94, 1, 1)

    widgets.lastSeenZone = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    widgets.lastSeenZone:SetPoint("TOPLEFT", widgets.lastSeenName, "BOTTOMLEFT", 0, -2)

    widgets.lastSeenSource = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    widgets.lastSeenSource:SetPoint("TOPLEFT", widgets.lastSeenZone, "BOTTOMLEFT", 0, -2)

    widgets.lastSeenCoords = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    widgets.lastSeenCoords:SetPoint("TOPLEFT", widgets.lastSeenSource, "BOTTOMLEFT", 0, -2)

    widgets.devTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    widgets.devTitle:SetPoint("TOPLEFT", widgets.lastSeenCoords, "BOTTOMLEFT", 0, -14)
    widgets.devTitle:SetText("DEV TEST")
    widgets.devTitle:SetTextColor(0.35, 0.8, 1, 1)

    widgets.testInput = CreateFrame("EditBox", "AsmonFinderTestNameInput", content, "InputBoxTemplate")
    widgets.testInput:SetSize(180, 24)
    widgets.testInput:SetPoint("TOPLEFT", widgets.devTitle, "BOTTOMLEFT", 6, -8)
    widgets.testInput:SetAutoFocus(false)
    widgets.testInput:SetText("Donald Trump")
    StyleTabardInput(widgets.testInput)

    widgets.testButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    widgets.testButton:SetSize(100, 24)
    widgets.testButton:SetPoint("LEFT", widgets.testInput, "RIGHT", 8, 0)
    widgets.testButton:SetText("TEST ALERT")
    StyleTabardButton(widgets.testButton)

    -- Movable stack. Drag the "Targets" handle; left-click still targets.
    widgets.targetStack = CreateFrame(
      "Frame",
      "AsmonFinderTargetStack",
      UIParent
    )
    widgets.targetStack:SetSize(214, 114)
    widgets.targetStack:SetFrameStrata("DIALOG")
    widgets.targetStack:SetMovable(true)
    widgets.targetStack:SetClampedToScreen(true)
    widgets.targetStack:Hide()

    widgets.targetStackHandle = CreateFrame(
      "Button",
      "AsmonFinderTargetStackHandle",
      widgets.targetStack,
      "UIPanelButtonTemplate"
    )
    widgets.targetStackHandle:SetSize(180, 20)
    widgets.targetStackHandle:SetPoint("TOPLEFT", widgets.targetStack, "TOPLEFT", 0, 0)
    widgets.targetStackHandle:SetText("Targets (drag)")
    StyleTabardButton(widgets.targetStackHandle)
    widgets.targetStackHandle:RegisterForDrag("LeftButton")
    widgets.targetStackHandle:SetScript("OnDragStart", function()
      if InCombatLockdown() then
        return
      end

      widgets.targetStack:StartMoving()
    end)
    widgets.targetStackHandle:SetScript("OnDragStop", function()
      widgets.targetStack:StopMovingOrSizing()
      SaveTargetStackPosition()
    end)

    RestoreTargetStackPosition()

    widgets.secureTargets = {}
    widgets.targetDismisses = {}

    for slotIndex = 1, MAX_QUEUED_TARGETS do
      ---@type any
      local targetButton = CreateFrame(
        "Button",
        "AsmonFinderSecureTargetButton" .. tostring(slotIndex),
        widgets.targetStack,
        "SecureActionButtonTemplate,UIPanelButtonTemplate"
      )
      targetButton:SetSize(180, 24)
      targetButton:RegisterForClicks("AnyUp", "AnyDown")
      targetButton:SetAttribute("type", "macro")
      targetButton:SetText("Target")
      StyleTabardButton(targetButton)
      targetButton:Hide()
      widgets.secureTargets[slotIndex] = targetButton

      ---@type any
      local dismissButton = CreateFrame(
        "Button",
        "AsmonFinderTargetDismissButton" .. tostring(slotIndex),
        widgets.targetStack,
        "UIPanelButtonTemplate"
      )
      dismissButton:SetSize(22, 22)
      dismissButton:SetText("X")
      StyleTabardButton(dismissButton)
      dismissButton:Hide()
      widgets.targetDismisses[slotIndex] = dismissButton

      dismissButton:SetScript("OnClick", function()
        if InCombatLockdown() then
          return
        end

        local queuedName = queuedTargetNames[slotIndex]
        if queuedName then
          queuedTargetNames = SettingsPanel.RemoveQueuedName(
            queuedTargetNames,
            queuedName
          )
        end

        if SyncTargetButtons then
          SyncTargetButtons()
        end

        if PositionSecureTarget then
          PositionSecureTarget()
        end
      end)
    end

    widgets.enabled:SetScript("OnClick", function(self)
      SyncTabardCheck(self)
      panel.UpdateSettings({ enabled = self:GetChecked() })
      AsmonFinder.PersistSettings()
    end)

    widgets.raidWarning:SetScript("OnClick", function(self)
      SyncTabardCheck(self)
      panel.UpdateSettings({ raidWarningEnabled = self:GetChecked() })
      AsmonFinder.PersistSettings()
    end)

    widgets.sound:SetScript("OnClick", function(self)
      SyncTabardCheck(self)
      panel.UpdateSettings({ soundEnabled = self:GetChecked() })
      AsmonFinder.PersistSettings()
    end)

    widgets.chat:SetScript("OnClick", function(self)
      SyncTabardCheck(self)
      panel.UpdateSettings({ chatEnabled = self:GetChecked() })
      AsmonFinder.PersistSettings()
    end)

    widgets.autoTarget:SetScript("OnClick", function(self)
      SyncTabardCheck(self)
      panel.UpdateSettings({ autoTargetEnabled = self:GetChecked() })
      AsmonFinder.PersistSettings()
    end)

    widgets.cooldown:SetScript("OnValueChanged", function(self, value)
      local seconds = math.floor(value + 0.5)
      widgets.cooldownLabel:SetText(string.format("%d seconds", seconds))
      panel.UpdateSettings({
        alertCooldownMs = Settings.SecondsToMilliseconds(seconds),
      })
      AsmonFinder.PersistSettings()
    end)

    widgets.addButton:SetScript("OnClick", function()
      panel.AddTarget(widgets.nameInput:GetText() or "")
      widgets.nameInput:SetText("")
      Refresh()
      AsmonFinder.PersistSettings()
    end)

    widgets.nameInput:SetScript("OnEnterPressed", function(self)
      panel.AddTarget(self:GetText() or "")
      self:SetText("")
      self:ClearFocus()
      Refresh()
      AsmonFinder.PersistSettings()
    end)

    ---Fire the developer test using the current test-name input.
    local function RunDevTest()
      panel.FireTestAlert(widgets.testInput:GetText() or "")
      Refresh()
    end

    widgets.testButton:SetScript("OnClick", RunDevTest)

    widgets.testInput:SetScript("OnEnterPressed", function(self)
      RunDevTest()
      self:ClearFocus()
    end)

    return frame
  end

  ---Place the protected targeting buttons in a vertical stack.
  PositionSecureTarget = function()
    if not widgets.secureTargets or not widgets.targetStack then
      return
    end

    if InCombatLockdown() then
      return
    end

    for slotIndex = 1, MAX_QUEUED_TARGETS do
      ---@type any
      local targetButton = widgets.secureTargets[slotIndex]
      ---@type any
      local dismissButton = widgets.targetDismisses[slotIndex]
      ---@type number
      local offsetY = -24 - ((slotIndex - 1) * 30)

      targetButton:ClearAllPoints()
      targetButton:SetFrameLevel(120)
      targetButton:SetPoint(
        "TOPLEFT",
        widgets.targetStack,
        "TOPLEFT",
        0,
        offsetY
      )

      dismissButton:ClearAllPoints()
      dismissButton:SetPoint("LEFT", targetButton, "RIGHT", 6, 0)
      dismissButton:SetFrameLevel(121)
    end
  end

  ---Hide every Target button when allowed.
  local function HideSecureTarget()
    if InCombatLockdown() then
      return
    end

    if not widgets.secureTargets then
      return
    end

    for slotIndex = 1, MAX_QUEUED_TARGETS do
      widgets.secureTargets[slotIndex]:Hide()
      widgets.targetDismisses[slotIndex]:Hide()
    end

    if widgets.targetStack then
      widgets.targetStack:Hide()
    end
  end

  ---Arm visible Target buttons from the queued names.
  SyncTargetButtons = function()
    if not widgets.secureTargets then
      return
    end

    if InCombatLockdown() then
      return
    end

    for slotIndex = 1, MAX_QUEUED_TARGETS do
      ---@type any
      local targetButton = widgets.secureTargets[slotIndex]
      ---@type any
      local dismissButton = widgets.targetDismisses[slotIndex]
      ---@type string?
      local queuedName = queuedTargetNames[slotIndex]

      if queuedName then
        targetButton:SetAttribute("type", "macro")
        targetButton:SetAttribute(
          "macrotext",
          "/targetexact " .. queuedName
        )
        targetButton:SetText("Target: " .. queuedName)
        targetButton:Enable()
        targetButton:Show()
        dismissButton:Show()
      else
        targetButton:SetAttribute("macrotext", "")
        targetButton:SetText("Target")
        targetButton:Hide()
        dismissButton:Hide()
      end
    end

    if #queuedTargetNames > 0 then
      widgets.targetStack:Show()
      if widgets.targetStackHandle then
        widgets.targetStackHandle:Show()
      end
    else
      widgets.targetStack:Hide()
    end
  end

  ---Open and refresh the settings panel.
  function panel.Open()
    EnsureFrame()
    visible = true
    Refresh()
    frame:Show()
    PositionSecureTarget()
    SyncTargetButtons()
  end

  ---Close the settings panel. A pending target button stays on screen.
  function panel.Close()
    visible = false
    if frame then
      frame:Hide()
    end
    PositionSecureTarget()
  end

  ---Toggle panel visibility.
  function panel.Toggle()
    if visible then
      panel.Close()
      return
    end
    panel.Open()
  end

  ---Determine whether the panel is currently open.
  ---@return boolean visible Whether the panel is open.
  function panel.IsVisible()
    return visible
  end

  ---Apply settings changes through the backing store.
  ---@param changes PartialAsmonFinderSettings Changed fields.
  ---@return AsmonFinderSettings settings Updated settings.
  function panel.UpdateSettings(changes)
    return dependencies.updateSettings(changes)
  end

  ---Add a unique full character name to the watch list.
  ---@param name string Full character name.
  ---@return AsmonFinderSettings settings Updated settings.
  function panel.AddTarget(name)
    local trimmedName = Trim(name)

    if trimmedName == "" then
      return dependencies.getSettings()
    end

    local settings = dependencies.getSettings()
    ---@type string[]
    local targetNames = {}
    for index = 1, #settings.targetNames do
      targetNames[index] = settings.targetNames[index]
    end

    local normalizedName = string.lower(trimmedName)
    local alreadyExists = false

    for index = 1, #targetNames do
      if string.lower(targetNames[index]) == normalizedName then
        alreadyExists = true
        break
      end
    end

    if not alreadyExists then
      targetNames[#targetNames + 1] = trimmedName
    end

    return dependencies.updateSettings({ targetNames = targetNames })
  end

  ---Remove a full character name from the watch list.
  ---@param name string Full character name.
  ---@return AsmonFinderSettings settings Updated settings.
  function panel.RemoveTarget(name)
    local settings = dependencies.getSettings()
    local normalizedName = string.lower(Trim(name))
    ---@type string[]
    local targetNames = {}

    for index = 1, #settings.targetNames do
      local existingName = settings.targetNames[index]
      if string.lower(existingName) ~= normalizedName then
        targetNames[#targetNames + 1] = existingName
      end
    end

    return dependencies.updateSettings({ targetNames = targetNames })
  end

  ---Prepare the last-seen character for secure click-to-target.
  function panel.TargetLastSeen()
    local lastSeen = dependencies.getLastSeen()

    if not lastSeen then
      return
    end

    dependencies.requestTarget(lastSeen.name)
    if SyncTargetButtons then
      SyncTargetButtons()
    end
    if PositionSecureTarget then
      PositionSecureTarget()
    end
  end

  ---Fire the real alert pipeline for a developer-supplied name.
  ---@param name? string Full test character name.
  function panel.FireTestAlert(name)
    local trimmedName = Trim(name or "")

    if trimmedName == "" then
      trimmedName = "Asmongold"
    end

    if dependencies.showAlert then
      dependencies.showAlert(trimmedName, "test")
    end
  end

  ---Create hidden targeting widgets at ADDON_LOADED, not from the scanner.
  function panel.EnsureReady()
    EnsureFrame()
    HideSecureTarget()
  end

  ---Queue a Target button for this name. Keeps at most three, dropping the oldest.
  ---@param name? string Full character name.
  function panel.ShowSecureTarget(name)
    EnsureFrame()

    if InCombatLockdown() then
      return
    end

    queuedTargetNames = SettingsPanel.PushQueuedName(queuedTargetNames, name)
    PositionSecureTarget()
    SyncTargetButtons()
  end

  ---Refresh visible UI and secure-target state.
  function panel.Refresh()
    if visible then
      Refresh()
      PositionSecureTarget()
      if SyncTargetButtons then
        SyncTargetButtons()
      end
    end
  end

  return panel
end
