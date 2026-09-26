# Asmon Finder

**Spot watched players the moment they appear — and know exactly where you were when it happened.**

Asmon Finder is a World of Warcraft addon for **WoW Forever** (and compatible clients) that watches for character names you care about, fires a clear alert, and remembers the last sighting with zone + map coordinates. Built for Forever’s **full character names** (no realms) — names like `Donald Trump` or `Asmongold` match exactly, case-insensitively.

Install the **`AsmonFinder/`** folder into the game. That is the addon.

---

## Features

- **Watch list** — track one or many full character names
- **Detection sources** — target, mouseover, nameplates, combat log
- **Alerts** — raid warning, chat message, and sound (each toggleable)
- **Cooldown** — configurable so you aren’t spammed
- **Last seen** — name, zone/subzone, detection source, map coordinates
- **Secure targeting** — click-to-target via `/targetexact` (no illegal silent targeting)
- **Settings UI** — `/asmon` opens an in-game panel
- **SavedVariables** — settings and last sighting persist between sessions

---

## Install (in-game addon)

### 1. Copy the addon

Copy the **`AsmonFinder`** folder (the one that contains `AsmonFinder.toc`) into your client’s AddOns directory.

**macOS (Battle.net default):**

```text
/Applications/World of Warcraft/<flavor>/Interface/AddOns/AsmonFinder
```

On many Forever / classic-beta installs that path looks like:

```text
/Applications/World of Warcraft/_classic_beta_/World of Warcraft/_classic_beta_/Interface/AddOns/AsmonFinder
```

**Windows (typical):**

```text
C:\Program Files (x86)\World of Warcraft\<flavor>\Interface\AddOns\AsmonFinder
```

Your AddOns folder should look like:

```text
Interface/AddOns/AsmonFinder/
  AsmonFinder.toc
  AsmonFinder.lua
  Types.lua
  Settings.lua
  Core.lua
  AddonController.lua
  SettingsPanel.lua
  WowBridge.lua
  images/
    AsmoPal_UI.tga
```

> Do **not** nest it as `AddOns/AsmonFinder/AsmonFinder/`. The `.toc` must sit directly inside `AddOns/AsmonFinder/`.

### 2. Enable it

1. Fully restart the game (or log to character select)
2. At the character list, click **AddOns**
3. Enable **Asmon Finder**
4. If it shows as out of date, either:
   - Check **Load out of date AddOns**, or
   - Update `## Interface:` in `AsmonFinder.toc` to match your client’s interface version

### 3. Load in and try it

```text
/asmon
/asmon test
```

---

## Slash commands

| Command | Action |
|---------|--------|
| `/asmon` | Open / close the settings panel |
| `/asmon test` | Fire a test alert (`Asmongold` via `test`) |
| `/asmon test <name>` | Fire the real alert pipeline for any full name |
| `/asmon inspect` | Print exact target, mouseover, and nameplate names exposed by the client |
| `/asmon debug` | Toggle live unit/event diagnostics in chat |
| `/asmon reset` | Reset settings to defaults |
| `/asmon help` | List commands |

---

## Settings panel

- Enable / disable the scanner
- Toggle raid warning, sound, and chat alerts
- Alert cooldown (seconds)
- “Prepare target when detected” (queues the secure target button)
- Watched character list — add / remove full names
- Last seen — name, zone, source, coordinates
- **Target** button — secure `/cleartarget` + `/targetexact <Full Name>`

### Name matching (important)

WoW Forever uses **full names**, not `Name-Realm`.

- `Asmongold` matches `asmongold`
- `Donald Trump` matches `donald trump`
- Partial names do **not** match (`Trump` ≠ `Donald Trump`)
- Hyphens/spaces are part of the name — nothing is stripped as a “realm”

---

## How detection works

The addon listens for:

- `PLAYER_TARGET_CHANGED`
- `UPDATE_MOUSEOVER_UNIT`
- `NAME_PLATE_UNIT_ADDED`
- `COMBAT_LOG_EVENT_UNFILTERED`

It also polls the public `target`, `mouseover`, and `nameplate1`–`nameplate40`
unit tokens every 0.5 seconds. This is a compatibility fallback for client
builds that do not reliably emit modern nameplate events. WoW does not expose
an API for enumerating every nearby player, so a player must be visible through
one of those unit tokens or appear in the combat log.

When a watched name is seen, it:

1. Respects enable + cooldown settings  
2. Saves **last seen** (zone, source, time, map `x`/`y`/`mapId`)  
3. Shows configured alerts  
4. Optionally prepares a **secure** click-to-target button  

Silent auto-targeting from insecure addon code is intentionally **not** used. Targeting goes through a player click on a `SecureActionButton` (same idea as RareScanner’s `/targetexact` button).

---

## Addon files

```text
AsmonFinder/          ← install this into Interface/AddOns
├── AsmonFinder.toc
├── AsmonFinder.lua   ← boot + SavedVariables
├── Types.lua         ← LuaLS/LuaCATS type declarations
├── Settings.lua      ← defaults + settings store
├── Core.lua          ← detection / alerts
├── AddonController.lua
├── SettingsPanel.lua ← in-game UI
├── WowBridge.lua     ← WoW API adapter
├── UI_PREVIEW.html   ← standalone browser UI preview
└── images/           ← browser + WoW-compatible artwork
```

Versioned copies such as `AsmonFinder-1.04` are snapshots. WoW only loads a folder named **`AsmonFinder`**.

---

## Lua tests

The addon is tested with [Busted](https://lunarmodules.github.io/busted/).
On macOS:

```bash
brew install lua luarocks
luarocks install busted
busted lua-tests
```

### Open the one-to-one UI preview

Open `AsmonFinder/UI_PREVIEW.html` directly in a browser. It needs no server and
uses the same 430 × 780 layout measurements as the Lua panel. The watch list,
cooldown, test alert, close button, and target label are interactive.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Addon doesn’t appear | Confirm path ends in `Interface/AddOns/AsmonFinder/AsmonFinder.toc` |
| Marked out of date | Enable “Load out of date AddOns” or bump `## Interface:` in the `.toc` |
| `/asmon` does nothing | Addon disabled, or Lua error — check `Logs/` or Escape → Options → AddOns |
| Secure target error on open | Make sure you’re on the latest `SettingsPanel.lua` (secure button must parent to `UIParent`) |
| Names never match | Use the **full** Forever name, including spaces |
| No coordinates | Client didn’t return map position for that moment — zone/source still save |

---

## Short GitHub “About” blurb

Use this in the repo description field:

> WoW Forever addon that detects watched players by full name, alerts you, and saves last-seen zone + map coordinates.

---

## License

Add a license of your choice before publishing if you want others to redistribute it.

---

## Credits

- Secure targeting pattern aligned with how addons like **RareScanner** use `/targetexact` instead of unprotected targeting APIs
