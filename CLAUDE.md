# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

RPG Boss Bar is a World of Warcraft addon (Lua, no build step) that renders boss units (`boss1`–`boss5`), or a single hard/soft enemy target when Track Target is on, as one large decorative segmented bar. It targets Retail Midnight 12.1.0/12.1.5 and WoW Forever 1.60.1 (see `## Interface:` in `RPGBossBar.toc`). `README.md` is the user-facing behavior spec (Track Target priority rules, Maximum Frames ordering, test mode, profiles). Check it before changing behavior.

## Development

- There is no build, lint config, or test suite. You test by copying or symlinking this folder into `World of Warcraft/_retail_/Interface/AddOns/RPGBossBar` and running `/reload` in-game. Folder name must stay `RPGBossBar`, because media paths are hardcoded as `Interface\AddOns\RPGBossBar\...`.
- In-game: `/rpgbb test [1-5]` shows preview bars, `/rpgbb debug` turns on `RPGBB:VPrint` diagnostics, `/rpgbb reset` resets the active profile, and `/rpgbb settings` opens the settings and profile panel. Opening Edit Mode also previews bars.
- For a quick syntax check, run `luac -p file.lua` (system `lua` is available). WoW globals are not checked, so this catches syntax errors only.
- **Load order is the `.toc` file list.** Every new Lua file must be added there, after the files it depends on. `skins/lura.lua` is a WIP skin that is intentionally not in the TOC.
- Release: bump `## Version:` in the TOC (format `<wow-version>-<build>`, e.g. `12.1.5-15`) and add a `CHANGELOG.md` entry. Keep the README "Compatibility" section in sync.

## Architecture

All files share the addon namespace via `local ADDON_NAME, RPGBB = ...` (some files name it `addon`). Global state lives on `RPGBB`.

**Load sequence (TOC order):** libs → `Media.lua` (atlas/spark texture tables, LibSharedMedia font registration) → `database/Defaults.lua` → border/accent/skin registries and their entries → `database/Init.lua` → `Commands.lua` → `BlizzardBossFrames.lua` → `RPGBossBar.lua` (creates `RPGBossBarFrame`) → `Settings.lua` (Edit Mode) → `ProfileSettings.lua` (Blizzard Settings panel). On `ADDON_LOADED`, `RPGBossBar.lua` calls `InitializeDB()`, `InitOrUpdateFrame()`, and `RegisterProfileSettings()`.

**Settings data model:** `database/Defaults.lua` defines `db_defaults`, the complete settings schema. Its `db_validation` lists which paths are anchor points, blend modes, font outlines, accent selections, or may be `string|false`. Profiles are stored in the account-wide `RPGBossBarProfiles.profiles[name]` and wrapped by `LibSimpleDB-1.0` (`RPGBB.db:Get("frame", "border", "size")` / `:Set(...)`), which falls back to defaults. `RPGBossBarProfiles.profileKeys[charKey]` selects each character's profile. `RPGBossBarDB` is the legacy per-character store, read only by `MigrateOldDB`.

**Adding a setting** touches several files: add the default (and any `db_validation` path) in `Defaults.lua`, add a get/set pair plus an LEM widget in `Settings.lua` (setters call `RPGBB:InitOrUpdateFrame()`), and add rendering in `RPGBossBar.lua`. Settings shown in both Edit Mode and the Settings panel go in `RPGBB.sharedSettings` (`Settings.lua`), which `ProfileSettings.lua` wraps with `Settings.RegisterProxySetting` so both UIs stay synchronized.

**Skins** (`skins/*.lua`) are bundled profile presets registered with `RPGBB:RegisterDefaultSkin({ id, name, overrides })`. `skins/Registry.lua` validates `overrides` against the shape and types of `db_defaults`. Unknown keys, wrong types, or invalid enum values cause the skin to be **skipped** with a chat message, not to error. So when you add or rename a default, update existing skins too. Applying a skin deep-merges its overrides into the profile and records the skin id in `profileMeta[name].defaultSkin`. `default_skin_id` is `vigor_dark`.

**Accents** (`accents/*.lua`) are decorative textures in `center`/`left`/`right` slots, registered via `RPGBB:RegisterAccentOption`. Accent kinds are `atlas` or `group`. Side accents declare `native_side` and can be mirrored to the other side. `accents/Registry.lua` handles placement, scaling, rotation, and mirroring. Profiles reference accents by id in `accents.<slot>.selected`.

**Borders** (`borders/Registry.lua`) map `nineslice:<style>` texture keys (e.g. `nineslice:kyrian`) to Blizzard NineSlice atlas layouts. `RPGBossBar.lua` renders them, or LSM borders, around the main frame and power bars.

**Runtime (`RPGBossBar.lua`):** `GetTrackedUnits()` resolves the units to display: the living bosses, capped by `GetMaxBossFrames()`, or `target`/`softenemy` in Track Target mode. `UpdateFrames()` rebuilds layout when the unit set changes (horizontal segments or vertical stacked rows). `RenderHealthChanges` and `RenderPowerChanges` handle per-tick updates driven by `UNIT_HEALTH` and `UNIT_POWER_*` events. Event registration changes with mode (`UpdateTrackingEvents`). Frame layering uses the frame-level constants at the top of the file. Retail 12.x unit values may be "secret" values (`issecretvalue`), so guard arithmetic and comparisons on unit health and power.

**Edit Mode integration** uses a vendored, renamed `LibEditMode` (`LibStub('LibEditMode-RPGBossBar-1.0')`). Don't swap it for the upstream library name. `BlizzardBossFrames.lua` hides `BossTargetFrameContainer` using a state driver and defers changes made in combat until `PLAYER_REGEN_ENABLED`.

## Conventions

- Lua style uses 4-space indentation and `snake_case` for locals and settings keys. Public methods are `RPGBB:PascalCase`, and DB/profile functions are `RPGBB.PascalCase`.
- Atlas names are Blizzard client atlases. Custom art lives in `media/art` (`.tga`) and fonts in `media/fonts`.
