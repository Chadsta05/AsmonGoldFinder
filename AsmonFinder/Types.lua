--[[
  AsmonFinder type declarations

  LuaLS / LuaCATS annotations — the Lua equivalent of the JSDoc typedefs
  used by the JavaScript reference implementation. This file contains no
  runtime behavior and must load before the other addon modules.
]]

---@class AsmonFinderSettings
---@field enabled boolean Whether detection is enabled.
---@field alertCooldownMs number Minimum milliseconds between alerts.
---@field raidWarningEnabled boolean Whether raid-warning text is shown.
---@field soundEnabled boolean Whether the raid-warning sound is played.
---@field chatEnabled boolean Whether detection details print to chat.
---@field autoTargetEnabled boolean Whether detection prepares a secure target.
---@field targetNames string[] Exact full character names to watch.

---@class PartialAsmonFinderSettings
---@field enabled? boolean
---@field alertCooldownMs? number
---@field raidWarningEnabled? boolean
---@field soundEnabled? boolean
---@field chatEnabled? boolean
---@field autoTargetEnabled? boolean
---@field targetNames? string[]

---@class AsmonFinderSettingsStore
---@field GetSettings fun(): AsmonFinderSettings
---@field UpdateSettings fun(changes: PartialAsmonFinderSettings): AsmonFinderSettings
---@field ResetSettings fun(): AsmonFinderSettings

---@class AsmonFinderMapPosition
---@field x number Player map X as a percentage from 0 through 100.
---@field y number Player map Y as a percentage from 0 through 100.
---@field mapId? string Client map identifier when available.

---@class AsmonFinderDetection
---@field name string Full detected character name.
---@field zone string Zone and optional subzone at detection time.
---@field source string Detection mechanism.
---@field time number Detection timestamp in milliseconds.
---@field x? number Player map X at detection time.
---@field y? number Player map Y at detection time.
---@field mapId? string Client map identifier at detection time.

---@class AsmonFinderEventPayload
---@field unit? string WoW unit token.
---@field sourceName? string Combat-log source character.
---@field destinationName? string Combat-log destination character.

---@alias AsmonFinderEventHandler fun(event: string, payload?: AsmonFinderEventPayload)

---@class AsmonFinderDependencies
---@field getZoneText fun(): string?
---@field getSubZoneText fun(): string?
---@field getPlayerPosition fun(): AsmonFinderMapPosition?
---@field unitExists fun(unit: string): boolean
---@field unitName fun(unit: string): string?
---@field saveLastSeen fun(detection: AsmonFinderDetection)
---@field getLastSeen fun(): AsmonFinderDetection?
---@field showRaidWarning fun(message: string)
---@field printToChat fun(message: string)
---@field playRaidWarningSound fun()
---@field requestTarget fun(name: string)
---@field registerEvent fun(event: string, handler: AsmonFinderEventHandler)
---@field now fun(): number
---@field getSettings fun(): AsmonFinderSettings

---@class AsmonFinderApi
---@field Start fun()
---@field HandleEvent AsmonFinderEventHandler
---@field CheckUnit fun(unit: string, source: string)
---@field CheckCombatLog fun(event: AsmonFinderEventPayload)
---@field ShowAlert fun(name: string, source: string)
---@field GetLocation fun(): string
---@field IsTarget fun(name?: string): boolean

---@class AsmonFinderSettingsPanelDependencies
---@field getSettings fun(): AsmonFinderSettings
---@field updateSettings fun(changes: PartialAsmonFinderSettings): AsmonFinderSettings
---@field getLastSeen fun(): AsmonFinderDetection?
---@field requestTarget fun(name: string)
---@field showAlert fun(name: string, source: string)

---@class AsmonFinderSettingsWidgets
---@field panelUnderlay any
---@field panelBackground any
---@field heroArt any
---@field heroTitle any
---@field heroSubtitle any
---@field heroBadge any
---@field enabled any
---@field raidWarning any
---@field sound any
---@field chat any
---@field autoTarget any
---@field cooldown any
---@field cooldownLabel any
---@field watchedTitle any
---@field nameScroll any
---@field nameList any
---@field nameRows any[]
---@field nameInput any
---@field addButton any
---@field lastSeenName any
---@field lastSeenZone any
---@field lastSeenSource any
---@field lastSeenCoords any
---@field devTitle any
---@field testInput any
---@field testButton any
---@field targetStack any
---@field targetStackHandle any
---@field secureTargets any[]
---@field targetDismisses any[]

---@class AsmonFinderSettingsPanelApi
---@field Open fun()
---@field Close fun()
---@field Toggle fun()
---@field IsVisible fun(): boolean
---@field UpdateSettings fun(changes: PartialAsmonFinderSettings): AsmonFinderSettings
---@field AddTarget fun(name: string): AsmonFinderSettings
---@field RemoveTarget fun(name: string): AsmonFinderSettings
---@field TargetLastSeen fun()
---@field FireTestAlert fun(name?: string)
---@field ShowSecureTarget fun(name?: string)
---@field EnsureReady fun()
---@field Refresh fun()

---@class AsmonFinderControllerDependencies
---@field settingsPanel AsmonFinderSettingsPanelApi
---@field resetSettings fun()
---@field printToChat fun(message: string)
---@field showAlert fun(name: string, source: string)
---@field toggleDebug fun(): boolean
---@field inspectUnits fun()

---@class AsmonFinderControllerApi
---@field HandleSlashCommand fun(input?: string)

---@class AsmonFinderBootDependencies
---@field getZoneText fun(): string?
---@field getSubZoneText fun(): string?
---@field getPlayerPosition fun(): AsmonFinderMapPosition?
---@field unitExists fun(unit: string): boolean
---@field unitName fun(unit: string): string?
---@field saveLastSeen fun(detection: AsmonFinderDetection)
---@field getLastSeen fun(): AsmonFinderDetection?
---@field showRaidWarning fun(message: string)
---@field printToChat fun(message: string)
---@field playRaidWarningSound fun()
---@field requestTarget fun(name: string)
---@field registerEvent fun(event: string, handler: AsmonFinderEventHandler)
---@field now fun(): number
---@field registerSlashCommand fun(handler: fun(input?: string))
---@field toggleDebug fun(): boolean
---@field inspectUnits fun()
---@field savedSettings? PartialAsmonFinderSettings

---@class AsmonFinderWowBridgeApi
---@field CreateDependencies fun(): AsmonFinderBootDependencies
---@field SetIsWatchedName fun(checker: fun(name: string): boolean)
---@field GetPendingTargetName fun(): string?
---@field MarkWorldSettled fun()

---@class AsmonFinderSavedVariables
---@field settings? AsmonFinderSettings
---@field lastSeen? AsmonFinderDetection
---@field targetStackPosition? AsmonFinderFramePosition

---@class AsmonFinderFramePosition
---@field point string Anchor point on the stack.
---@field relativePoint string Anchor point on UIParent.
---@field x number X offset.
---@field y number Y offset.

---@class AsmonFinderNamespace
---@field Settings table
---@field Core table
---@field AddonController table
---@field SettingsPanel table
---@field WowBridge table
---@field settingsStore? AsmonFinderSettingsStore
---@field finder? AsmonFinderApi
---@field settingsPanel? AsmonFinderSettingsPanelApi
---@field controller? AsmonFinderControllerApi
---@field PersistSettings? fun()
