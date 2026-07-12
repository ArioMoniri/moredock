# Release Notes

## 0.4.3

- 🧰 **Built-in crash collector.** MoreDock now keeps crash reports itself: an uncaught exception is written to a persistent file before the process dies, and on the next launch both that record and the newest system crash report (`.ips`, which also captures Swift traps) are surfaced in the **Logs** window and summarized. A new **Crash Reports** row in Settings ▸ Diagnostics shows how many are saved, with **Copy Crash Report** (full report to the clipboard), **Show** (reveal in Finder) and **Clear**. So after any crash you can just reopen MoreDock and paste the report — no digging through Console.app.

## 0.4.2

- 🛡️ **Hardens Clicked Display so a failed move can't take MoreDock down.** The window move now runs entirely on the main thread, fires once per launch instead of on every poll tick, de-duplicates overlapping requests from a single click, and bounds each Accessibility call with a timeout so an unresponsive target app can't hang MoreDock.
- 🧾 **Adds a crash logger.** If MoreDock ever does hit an uncaught exception, its name, reason and stack are written to the system log (Console.app) and the crash report — so an otherwise unreproducible crash leaves a precise trail.

## 0.4.1

- 👁️ **Docks stay visible again.** Leftover per-display auto-hide from earlier builds was making customized docks hide themselves; a one-time reset clears it, and turning on **Customize** now starts a dock visible (auto-hide off) instead of inheriting stale auto-hide. You can still turn auto-hide back on per dock.
- 🧪 **Startup now logs the loaded settings** (Open apps on, customized displays, etc.) so the Logs window shows whether your settings survived the last quit — making any persistence issue diagnosable at a glance.
- 💾 Settings also flush to disk when MoreDock resigns active (e.g. just before a Sparkle update swaps the app), in addition to on every change and on quit.

## 0.4.0

- 🧭 **New "Top" dock location.** Each dock can now sit on the top edge of its display (below the menu bar), alongside Bottom, Left and Right.
- 🧹 **Simpler settings — the global "Appearance" section is gone.** Every dock now mirrors your macOS Dock by default; to make one dock different (edge, size, opacity, auto-hide, reveal delay, glass, running indicators), turn on its **Customize**. Edit the real macOS Dock under **macOS Dock**. No more overlapping "defaults for all docks" panel.
- 💾 **Settings now persist reliably across launches.** Changes are flushed to disk immediately and again on quit, so a setting changed right before quitting (including **Open apps on → Clicked Display**) is no longer lost — which also fixes Clicked Display appearing to "do nothing" after a relaunch.
- 🩹 **Auto-hide no longer freezes while you use Settings.** The reveal timer now runs during UI interaction, so docks don't get stuck hidden until you trigger the native Dock.
- 🪟 Per-dock **Glass material** toggle added to Customize.

## 0.3.9

- 🧭 **Fixes a junction dock appearing on the wrong screen.** When two displays are stacked and a dock's hide edge borders the neighbouring screen, the dock no longer slides across the seam onto the other display — it now fades in place on its own screen's edge, so a bottom dock stays on the upper screen's lower edge instead of crawling onto the lower screen.
- 🔗 **The global "Avoid display junctions" toggle now works for every dock.** Previously it only affected displays you had explicitly customized; a display that follows the global settings now honours the global toggle too.
- 🖱️ A hidden auto-hide dock that fades in place lets clicks pass through to whatever is beneath it while it's invisible.

## 0.3.8

- 🪟 **Clicking a running app with no open windows now opens a new one**, just like the native Dock — MoreDock sends the app a reopen event instead of only raising existing windows, so a windowless-but-running app (Finder, Safari, etc.) responds to a click.
- ⏱️ **Per-dock reveal delay.** Auto-hide now has a "Reveal delay" slider — set it to `0s` for an instant reveal or dial it up for a slower, native-Dock-style appearance. Available both globally (Appearance) and per display (Customize).
- 🩹 **Auto-hide no longer flickers.** The reveal now hit-tests the dock's on-screen rectangle and keeps the dock open through a short grace period, so a pointer skimming the edge no longer makes the dock rapidly show and hide.
- 🧭 **Clearer Settings.** The Appearance section now states up front that it holds the defaults for every dock, and that a display set to "Customize" uses its own values instead — so the relationship between global Appearance and per-dock customization is obvious.

## 0.3.7

- 🩹 **Fixes extra docks being invisible.** Earlier builds mirrored the macOS Dock's auto-hide setting into MoreDock, which left the stored auto-hide value stuck **on** for many installs — so every extra dock was parked off-screen at zero opacity and only flickered into view at the exact screen edge. A one-time migration now forces auto-hide back **off** (both globally and per display), so the docks show up. Auto-hide can still be turned back on explicitly from Settings.

## 0.3.6

- 🧪 Adds a **Log Dock Diagnostics** menu-bar item (⌘D) that dumps a full snapshot — settings, screens, which macOS Dock display is excluded, and every panel's real window frame, mapped screen, visibility, active-space, alpha, level, and content size — so an invisible dock can be pinpointed.
- 🩹 Adds a subtle solid backing behind the glass so a dock stays visible even if the blur material renders clear on some displays.
- 📋 Per-panel logging now reports the panel's actual window frame and whether macOS mapped it to a screen.

## 0.3.5

- 🩹 Snaps each dock panel into place on first appearance instead of animating it up from a zero-size rect, so a dock can't get stuck invisible.
- 🔎 Logs each panel's live state (revealed, auto-hide, app count, frame, on-screen, alpha) so an invisible dock can be diagnosed precisely from the Logs window.

## 0.3.4

- 👁️ Extra docks stay **visible by default** and no longer inherit the macOS Dock's auto-hide. Auto-hide is now an explicit MoreDock toggle (off by default), so a hidden system Dock no longer makes every extra dock disappear, and turning auto-hide off reliably shows the docks. Only the reveal timing is still borrowed from macOS.
- 🧹 The **macOS Dock** editor (which duplicated the Appearance controls) is now a collapsed "Edit the real macOS Dock…" disclosure, so Settings isn't repetitive at a glance.

## 0.3.3

- 🧲 Fixes docks that intermittently disappeared: the macOS Dock display is now detected with a confident-only check and the last known result is held while the Dock is auto-hidden, instead of flickering between the detected display and a fallback.
- 📐 A dock whose **bottom** edge sits on a display junction now relocates to a free side edge (like left/right docks already did), instead of staying stuck on the seam.

## 0.3.2

- 🚫 Fixes a duplicate dock appearing on the main display (over the real macOS Dock) after editing an appearance control. "Hide on Dock display" no longer depends on "Follow native Dock", so the display that owns the macOS Dock is always excluded (detected using the real Dock orientation). This also stabilises docks that would intermittently disappear.
- 🧭 The Settings "Hide on Dock display" toggle is always editable, and the main display correctly shows the "stays hidden" note whenever the macOS Dock is there.
- 🔎 Logs which display is being hidden as the macOS Dock display, to diagnose show/hide issues.

## 0.3.1

- 🎯 Fixes Clicked Display placing the window on the wrong screen / a display junction instead of centered on the clicked display. The AppKit→Accessibility coordinate conversion now references the primary display's top edge rather than the union of all displays, which had offset the window by the height of any monitor sitting above the primary.

## 0.3.0

- 📌 Each dock can now have its **own independent app list**. Pin or remove apps by dragging an app onto a dock, using **Add App…** in Settings, or right-clicking a dock icon; adding asks whether to apply to this dock or all docks, and a per-display **Reset** returns the dock to mirroring the macOS Dock.
- 🖼️ README: documents custom app lists, and clarifies that the Settings **Edge** control reflects the real macOS Dock orientation (the earlier "always Bottom" was the pre-0.2.4 display bug, now fixed).

## 0.2.5

- ⚡ Fixes auto-hide lag and delayed panels: the expensive native-Dock reads (window list + preferences) are now cached and refreshed about once a second instead of on every 0.12s tick, so the mouse-edge reveal stays responsive.
- 🧯 Adds an Accessibility **Reset** button (Settings ▸ Diagnostics) that runs `tccutil reset Accessibility` for MoreDock, clearing a stale/duplicate permission entry that can stop the grant from ever turning on.
- 📝 Documents the stale-permission fix and duplicate-copy cleanup in the README.

## 0.2.4

- 🧭 The Appearance controls now show the **actual** macOS Dock values (edge, icon size, magnification, auto-hide) while Follow native Dock is on, so the Edge/Auto-hide finally match reality; editing snapshots those values and switches to your own settings.
- 🟢 Adds a **Running indicators** setting that mirrors the macOS Dock's "show indicators for open applications" and can be overridden per display; the dots turn off by default when the system Dock has them off.
- 🖥️ The per-display list no longer shows a redundant "Customize" for the display that hosts the macOS Dock — it says the dock stays hidden there instead.
- 🧭 The per-display Location picker only offers edges the dock will actually stay on (a junction-shared edge is hidden while Avoid junctions is on).
- 🪟 Hides the window title so "MoreDock Settings" no longer overlaps the top of the content.
- 🔎 Logs how many windows a Clicked-Display move actually moved (or that none were movable), to diagnose "granted but nothing happens".

## 0.2.3

- 🧭 Fixes the Settings/graphic mismatch: the per-display Location now reflects the **resolved** edge, and the Display Layout map and the Per-Display list always agree.
- 🧹 Simplifies Settings: one **Customize** toggle per display (seeded from the current location), merges the Appearance and Liquid Glass controls, groups Updates/Accessibility/Logs under **Diagnostics**, and labels the **macOS Dock** section as editing the real system Dock.
- 🖱️ Left-clicking the menu-bar icon now opens Settings (right-click shows the menu); Settings also opens on first launch and when the app is reopened.
- 🔁 Adds a **Relaunch** button and clearer guidance for the "granted but still asks" case — macOS only applies an Accessibility grant to a freshly started process.
- 🔎 Logs the app's code-signature type and continuously logs Accessibility trust changes, so it's obvious whether a grant ever registers and whether the build is properly signed.

## 0.2.2

- 📦 Gives the DMG installer a proper drag-to-Applications layout with a background, app icon placement, and Applications shortcut.
- ⬇️ Points the README download button directly at the latest DMG asset instead of the generic releases page.
- 🖼️ Refreshes the README Settings screenshot from the current local app UI.

## 0.2.1

- 🔏 Code-signs the app in `build_app.sh` (ad-hoc for local builds, Developer ID in the release): unsigned apps cannot retain an Accessibility grant, which was the real cause of the endless re-prompt on local `.build` runs.
- 🔐 Detects and explains the "granted but still asks" Accessibility cases — translocated/temporary copies *and* local dev builds — in the Settings note and the logs (move to /Applications for a permanent grant; quit and reopen after granting a dev build).
- 📐 Makes the Settings "Display Layout" preview show each dock's **resolved** edge (after junction avoidance and native orientation), so the map matches where docks actually appear; also logs each display's frame and resolved edge for diagnosis.

## 0.2.0

- 📄 Adds the Apache License 2.0 (© Ariorad Moniri) plus a NOTICE file.
- 🧬 Extra docks now mirror the native Dock: Finder first, pinned apps in Dock order, then running (unpinned) apps, a separator, pinned folders/stacks (Downloads, etc.), and Trash last.
- 🟢 Adds running-indicator dots under open apps and a native-style rounded-rectangle dock shape.
- 🪵 Adds an in-app Log/Diagnostics reader (menu bar ▸ Show Logs, or Settings ▸ Logs) that records dock refreshes, panel activity, and Accessibility events, with Copy All for bug reports.
- 🗺️ Adds an animated Display Layout map in Settings that shows every screen's position and the glowing dock edge for each one.
- 🎛️ Every appearance control is now always editable: changing a locked control detaches it from "Follow native Dock" (globally) or from global placement/appearance (per display) so the change actually applies instead of being greyed out.
- 🖥️ Per-Display Docks now list **every** display (including the main one), not just external ones, each with its own show/hide, location, size, opacity, auto-hide, magnification, and junction settings.
- 🔐 Clicked Display no longer prompts for Accessibility on every click: it asks once (throttled), remembers the pending move, and applies it automatically as soon as access is granted — no second click needed.
- ⚙️ Settings gains a live Accessibility status row with a Grant… button that opens System Settings directly.
- 🖥️ Fixes the duplicate dock that could overlap the real macOS Dock on the main display by flipping Quartz→Cocoa coordinates when locating the native Dock and excluding **all** displays that host it.
- 🧊 Insets extra docks a few points off shared display seams so their glass no longer bleeds onto the neighbouring monitor.
- ✨ Gives the Settings window a richer liquid-glass backdrop.

## 0.1.9

This release expands the per-display controls and fixes a likely Clicked Display coordinate issue.

- 🖥️ Adds separate external-display controls for location, icon size, opacity, auto-hide, magnification, and junction behavior.
- 🪟 Converts Clicked Display window placement from AppKit coordinates to Accessibility coordinates before moving windows.
- 🧊 Moves Settings to lighter liquid-glass materials.
- 📏 Keeps the vertical Dock fit fix from 0.1.8.

## 0.1.8

This release adds the missing per-display placement controls and fixes more of the Dock behavior issues.

- 🖥️ Adds a Displays section where each screen can be enabled/disabled and assigned a custom MoreDock edge.
- 📏 Fixes vertical Dock fitting by including icon button padding in the fit calculation.
- 🪟 Improves Clicked Display mode with stronger app activation and longer window-move retries.
- 🧭 Keeps per-display junction avoidance configurable for each screen.

## 0.1.7

This release fixes the focus-dependent display behavior.

- 🖱️ Uses `CGMainDisplayID()` instead of `NSScreen.main` for native Dock display fallback.
- 🖥️ Prevents focus changes on another display from causing the wrong MoreDock panel to hide.
- 📌 Raises revealed extra docks above focused app windows with status-bar window level.
- 🎛️ Keeps the native macOS Dock settings controls added in 0.1.6.

## 0.1.6

This release focuses on the unresolved native-Dock matching and settings issues.

- 🎛️ Adds editable macOS Dock settings for location, size, zoom, magnification, and auto-hide.
- 🖥️ Strengthens native Dock display exclusion, especially when the real Dock is auto-hidden.
- 🧭 Adds display-junction avoidance so side docks do not sit on borders shared with another display by default.
- 📁 Re-syncs Dock persistent apps/folders after `com.apple.dock` preference synchronization.
- 🔐 Stops repeated Accessibility prompts during clicked-display moves and adds a Settings permission button.

## 0.1.5

This release restores the previous app icon and moves the detective concept into README/docs only.

- 🎨 Restores the previous MoreDock app icon.
- 🕵️ Adds a detective Rive-ready README element and docs canvas.
- 🧊 Keeps the app branding focused on the Dock itself.

## 0.1.4

This release fixes several Dock behavior issues and cleans up the project presentation.

- 📁 Mirrors persistent Dock apps plus folders/stacks such as Downloads.
- 📏 Dynamically fits all Dock items on each display edge without scrolling.
- ✨ Makes hidden auto-hide panels fully invisible to avoid display-junction bleed.
- 🔐 Reduces repeated Accessibility prompts during clicked-display window movement.
- 🖼️ Simplifies the README around the Settings screenshot only.
- 🕵️ Refreshes the app icon with a simple detective-inspired Dock mark.

## 0.1.3

This release tightens the settings experience and makes updater access visible from the app itself.

- 🧊 Reworks Settings into a compact native macOS glass panel.
- 🎛️ Groups Dock, behavior, appearance, and Liquid Glass controls into clearer sections.
- 🔄 Adds a Settings-window update check backed by Sparkle.
- 🖼️ Refreshes README screenshots from the real app views.

## 0.1.2

This release replaces the app icon with a simpler Dock-focused symbol.

- 🎨 Uses a single minimal Dock pill element.
- 🧊 Removes monitor/display structures from the icon.
- 📦 Keeps the same signed, notarized, Sparkle-enabled release flow.

## 0.1.1

MoreDock now tracks the native Dock more closely and avoids drawing over the display that already owns the macOS Dock.

- 🖥️ Hides MoreDock on the native Dock screen by default.
- 📐 Reads Dock settings with `CFPreferences`, matching `defaults read com.apple.dock`.
- 🧊 Uses a Dock-like pill shape derived from native Dock tile size.
- 🪟 Improves clicked-display window placement with retries, unminimize, center, and raise.
- ✨ Removes panel shadows to avoid bleed at display junctions.
- 🎛️ Adds a clearer setting for hiding where the native Dock lives.
- 🖼️ Replaces README generated catalogue art with real app screenshots.
- 🔄 Keeps Sparkle updater packaging and signed appcast support.

## 0.1.0

Initial public release.

- 🧊 Native macOS menu-bar app with no Dock icon.
- 🖥️ Dock-style launcher panels on multiple displays.
- 🎛️ Settings window for Dock behavior and display activation.
- 🔐 Developer ID signing and notarized release workflow.
- 🔄 Sparkle updater support.
