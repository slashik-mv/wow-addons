# SlashikFlying

Standalone Retail Skyriding HUD with switchable themes, inspired by the supplied EllesmereUI screenshot. No libraries or EllesmereUI dependency. Interface version follows SlashikRaidBreakTime (120100).

The compact display appears while mounted with Skyriding available, including while standing on the ground. It hides on dismount and in steady-flight mode. Purple segments show Second Wind charges; blue-gray segments show vigor (Skyward Ascent charges), including recharge progress. The lower bar shows flight speed relative to base running speed. The right icon shows Whirling Surge and its cooldown. This is a status display; cast abilities using your existing action buttons/keybinds.

## Themes

- **Compact** (`compact`, default): the original purple Second Wind bars, blue-gray vigor bars, and flat speed display.
- **Blizzard** (`blizzard`): native Blizzard Skyriding vigor artwork, textured status bars, and traditional gold-tinted borders. Uses built-in game textures; no additional addon is required. If vigor atlases are unavailable, framed bars are used instead.

Use `/sf theme blizzard` or `/sf theme compact` to switch immediately, without reloading. Use `/sf test` to compare themes off-mount. `/sf theme` lists the current selection and available IDs.

The selected `themeId` is saved in `SlashikFlyingDB.settings.themeId`. Appearance settings are stored under `SlashikFlyingDB.settings.themes[themeId]`, including width, textures, colors, fonts, spacing, and layout. Each theme remembers its own bar width: Compact defaults to 240 and Blizzard to 200, keeping the smaller vigor circles close together. Use `/sf width <120-600>` to resize the active theme. Position, overall scale, enablement, and combat visibility are shared. Existing settings migrate to Compact automatically, preserving width and position.

Developers can register additional theme IDs in `Themes.lua`; missing fields in saved themes receive defaults. Unknown selected IDs fall back to Compact. Both themes reuse the same frames and flight-data logic, with no additional background polling.

## Commands

- `/sf` or `/slashikflying`: help.
- `/sf unlock`: show a draggable preview; `/sf lock`: return to automatic visibility.
- `/sf test`: toggle an off-mount preview (not saved across reloads).
- `/sf theme compact` or `/sf theme blizzard`: select a visual theme.
- `/sf width 240`: active theme's bar width, 120–600.
- `/sf scale 1`: overall scale, 0.5–3.
- `/sf enabled on` or `off`: enable/disable the display.
- `/sf combat on` or `off`: hide in combat (default off).
- `/sf settings`: current settings.
- `/sf settings default`: reset settings and position.

Settings and position are account-wide. The default position is centered, 100 UI units below the screen center. Blizzard's UI remains available. If EllesmereUI's Skyriding HUD is enabled, disable that module to avoid duplicate displays.

## Installation and in-game verification

Copy this folder to `_retail_/Interface/AddOns/SlashikFlying`, then restart the game or reload if already discovered. Enable Slashik Flying in the addon list.

1. Mount a Skyriding mount: verify the HUD appears on the ground and updates in flight.
2. Spend vigor, Second Wind, and Whirling Surge; verify recharge fills and cooldown.
3. Dismount, use a ground-only mount, and switch to steady flight: verify it hides.
4. Use `/sf unlock`, drag, `/sf lock`, and `/reload`: verify position persists.
5. Test width, scale, enable/disable, combat visibility, and reset.
6. Test reload while flying and entering/leaving instances.
7. Switch themes while mounted and in preview mode. Verify native vigor artwork and cooldown framing, separate widths, shared position/scale, and persistence after `/reload`.

Restricted spell values are displayed as unavailable/empty rather than used in unsafe arithmetic. Actual client rendering and mount behavior require the in-game checks above.

API reference: Blizzard's generated spell API documentation, mirrored at https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua .
