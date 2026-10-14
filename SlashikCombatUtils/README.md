# SlashikCombatUtils

Retail combat trackers with independent module switches. Version 1.0.4 targets
interface 120105. This metadata target does not establish in-game compatibility testing.

## Bone Shield

For living Blood Death Knights (specialization 250), tracks the player Bone Shield
buff (195181). Two tapered arcs surround a central stack number; remaining whole
seconds appear to the left. Green is **5 or more**, dark yellow is **1–4**, red is
**0**. Only the red arcs bounce; the numbers stay still.

By default the tracker appears both in and out of combat, below screen center.
It is anchored to the screen, not the moving 3D character. Use the draggable
preview to place it above or below your character like your old WeakAura.

## Settings and installation

Place this folder as `Interface/AddOns/SlashikCombatUtils` in Retail, then restart
the client or reload if it already recognizes the addon. Open **/scu** or
**/slashikcombatutils**, or use Settings > AddOns > Slashik Combat Utils.

The movable, Escape-closeable Blizzard-style window follows SlashikRaidBreakTime's
BasicFrameTemplateWithInset / UICheckButtonTemplate / UIPanelButtonTemplate pattern.
The module switch stops all event handlers, polling, previews and animation while
preserving preferences. Changes are blocked during combat. Options include combat
only visibility, timer, red bounce, 50–300% size and saved position.

Use **Green / Move**, **Yellow**, and **Red / Bounce** to inspect the three states
while in Blood specialization. Drag the outlined preview to save its position. Closing settings,
entering combat, leaving Blood specialization or disabling the module ends the preview.

## Midnight restrictions

The tracker uses ordinary aura values when readable. If the stack count is secret,
it passes the value directly to FontString:SetText without inspecting it. For
restricted spell queries it obtains display text with GetAuraApplicationDisplayCount
from a current Bone Shield entry in Blizzard's Buff Icon / Buff Bar Cooldown Viewer,
or an aura instance identified before combat. If the instance API rejects the query,
it mirrors Blizzard's current stack FontString, with an aura-cache fallback for
single stacks (which Blizzard normally leaves unlabeled). Viewer entries are matched by public
spell metadata and checked afresh to avoid displaying a recycled frame's other buff.

For buffs first applied during combat, enable Blizzard's Cooldown Manager and add
Bone Shield to its tracked buffs. Without an identifiable aura source the tracker
still shows ?. Secret counts use neutral gray lines with no threshold colors or
bounce. During combat the timer mirrors Blizzard's buff-icon countdown or buff-bar duration
text directly, including secret text. Enable countdown text on the Blizzard source.
If no countdown text is supplied, the timer is blank rather than a guessed value.
The addon's Show remaining seconds option also controls the mirrored timer.

Actual display and aura access still require an in-game check. The mocked tests
verify unchanged forwarding of opaque counts, combat-applied viewer instances,
removed instances, recycled frames and no secret comparisons or arithmetic.

API references:
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua

## Code layout

All helpers use the addon's private namespace to avoid collisions with the other
Slashik addons' global helpers. Saved settings live in SlashikCombatUtilsDB.

- SettingsHelper.lua: defaults, validation, shared messages.
- ModuleSettingsHelper.lua: registry and independent enable/disable lifecycle.
- TrackerFrameHelper.lua: textured arc graphics, animation, position and preview.
- Modules/BoneShield.lua: specialization, events, aura state and rendering.
- AddonSettingsFrameHelper.lua: settings window and Retail settings entry.
- SlashikCombatUtils.lua: startup and slash commands.

New trackers register a unique key with `addon:RegisterModule(key, module)` and
implement `Enable` and `Disable`. Add their file to the TOC before settings/startup.
The settings window enumerates registered master switches; adjust its layout and
add a module-specific section when introducing the next tracker.

## Verification

Run `lua Tests/run.lua` from this folder (Lua 5.1+). Tests use mocked WoW APIs;
they cannot verify the game renderer, taint or actual aura visibility.

In-game checks still required:
1. Preview all three states, drag, resize, close with Escape and reopen.
2. On Blood DK, acquire Bone Shield and cross 4/5 stacks; consume all stacks.
3. Verify timer refresh, expiration and red-only bounce during combat.
4. Track Bone Shield in Blizzard Cooldown Manager; enter combat without the buff,
   acquire it, and check the live count on neutral gray lines when restricted.
5. Switch specialization, die/resurrect, toggle combat-only, and disable/re-enable.
6. Reload and confirm settings, position and size persist alongside RaidBreakTime.

Use `/scu debug` to print the current Bone Shield display source. This reports
the selected stack and timer sources, never the contents of secret values.

## Death and Decay companion timer

The right-hand number shows the remaining player buff duration (188290), with its
own checkbox in the Blood DK/Bone Shield settings. Add Death and Decay to
Blizzard's tracked buffs and enable its countdown for combat mirroring. This is
the player buff timer, not the spell cooldown or an estimated ground duration.
Absent or unavailable buff timers leave the right side blank. Preview shows 8.
The helper lives in Modules/DeathAndDecay.lua and follows the Blood-only module
switch, positioning and visibility settings. `/scu debug` reports its source.
