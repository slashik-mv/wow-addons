# SlashikCombatUtils

Retail combat trackers with independent module switches. Version 1.9 targets
interface 120105. Releases use two-part versions (1.6, 1.7, and so on). This metadata target does not establish in-game compatibility testing.

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
The settings window lists registered modules in its left sidebar. Register a
right-hand settings page with `addon:RegisterModuleSettings(key, builder)` before
the window is first opened; the builder receives its page frame. Pages are built
once and reused when selected. Selecting a module does not enable it.

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

## Module settings layout

The left sidebar lists modules with separate enable/disable checkboxes. Select a
module name to display its settings on the right. Disabled modules remain
selectable, with their controls dimmed until enabled. Switching pages ends the
previous module's preview; closing the window ends all previews. The window keeps
the Blizzard-style background, movable frame and Escape-to-close behavior.

## Check Consumables

Available to every class; disabled by default. Open `/scu`, enable **Check Consumables**
with its sidebar checkbox, select its name,
and tick the consumables you accept in each category. No items are selected by
default. Categories without selections are skipped; any selected item meeting its minimum in bags
satisfies its category. Banks do not count, and this checks stock, not active buffs.

- **Flasks:** Thalassian Resistance, Blood Knights, Magisters, Shattered Sun.
- **Health Potions:** Silvermoon Health Potion.
- **Battle Potions:** Light's Potential, Potion of Recklessness.
- **Enchanting:** Thalassian Phoenix Oil, Smuggler's Enchanted Edge.
- **Food:** Royal Roast, Impossibly Royal Roast.

The catalog uses item IDs 241321, 241324, 241322, 241326, 241304, 241308, 241288,
243734, 243738, 242275 and 255847.
A compact, movable, dismissible window names missing categories and their selected
items. Its height adjusts to the missing list, including wrapped text.
Checks run after login/zone changes, bag updates, selection changes, and enabling
the module. Ready checks, combat ending, and key completion/reset do not trigger checks.
**Check now** also runs a check. Combat immediately hides the reminder; checks and
reminders stay paused throughout an active Mythic+ run, including between pulls
and after reloading inside a key.

Dismissing a reminder silences that same missing list until the next zone
change, selection change, or stock change. Disable the module with its sidebar
checkbox to stop its events and timers while keeping selections.

Run `lua Tests/run.lua` for bag selection and suppression checks. In game,
verify selection persistence after reload, purchasing/using selected items,
dismissing the window, entering combat, and starting/completing/resetting a key.

Known quality variants also count under the same selection: Magisters 241323,
Light's Potential 241309, and Thalassian Phoenix Oil 243733.

Every flask, potion and Enchanting selection accepts both crafting qualities
(small and big diamond) under the same checkbox. Food remains individually selectable.

Each item has a **Minimum** quantity (default 1, whole numbers 1–9999).
Press Enter or leave the field to save. Counts from both crafting qualities add
together. A category is satisfied when any selected item meets its own minimum;
different selected items do not combine their counts. The reminder lists the
required minimum beside each acceptable item.

Use the up/down arrows beside module names to reorder the sidebar. The order is
saved across reloads; moving a module does not enable it or change the selected page.

Consumable names in settings and the missing-items window are clickable item links. Hover for the item tooltip; left-click
to fill the open Blizzard Auction House Buy search field, then start the search.
Outside the Buy view, clicking opens the item tooltip. Modified clicks retain normal
WoW item-link behavior. Custom Auction House addons may handle links differently.

Left-click the Slashik Combat Utils minimap icon to open settings. Left-drag it
around the minimap to reposition it; its position is saved across reloads.
