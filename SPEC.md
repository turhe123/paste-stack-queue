# PasteStackQueue — specification

**Tagline:** Copy many things in a row, then paste them back one by one in order with a single hotkey.

**Category:** Clipboard

**Inspired by (paid):** Copy 'Em ($14.99 one-time)

**Frameworks:** SwiftUI, AppKit, Carbon, ApplicationServices, CoreGraphics

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does and evidence of demand. Copy 'Em is a long-standing Mac clipboard manager that costs 14.99 dollars and is routinely named in best-of clipboard roundups. One of its most loved features is multi-item copy and paste, where you collect several clips and then paste them in sequence. People who fill forms, move spreadsheet values, or assemble documents from many sources value this a lot. Our clean-room version, PasteStackQueue, isolates just that workflow into a tiny tool.

Feature set. A queue mode can be switched on and off by a global hotkey. While it is on, each copy action in any app appends the new item to an ordered queue instead of replacing a history. A second global hotkey, the sequential paste key, takes the first item in the queue, places it on the pasteboard, pastes it into the frontmost app, and removes it from the queue. The mode can be set to first in first out or last in first out. Optional behaviors: join mode, where the whole queue is pasted at once separated by a chosen delimiter such as a newline, comma, or tab, and auto-advance, where after pasting a Tab key press is sent so values fill successive form fields. The queue can be reordered by dragging, items can be deleted, and the entire queue can be cleared with one command.

UI spec. The app is a MenuBarExtra whose icon shows a small badge with the queue count while queue mode is on, and a hollow icon when off. The menu contains a Queue Mode toggle, the list of queued items showing the first 40 characters with the next item marked by an arrow, Paste All Joined, Clear Queue, Settings, and Quit. A compact floating HUD near the top of the screen appears for two seconds after each copy and paste to show Added 3 or Pasted, 2 left. Empty state in the menu: Queue is empty. Settings fields: toggle hotkey recorder, paste next hotkey recorder, order picker with FIFO and LIFO, join delimiter picker, auto-advance with Tab toggle, HUD toggle, and Launch at login.

Technical approach. Poll NSPasteboard.general.changeCount at 0.3 second intervals only while queue mode is enabled, appending strings and file URLs and ignoring concealed types. Register two Carbon hotkeys. For pasting, write the next item to the pasteboard, record the resulting changeCount so the poller skips it, then post Command plus V through CGEvent, which needs Accessibility permission. Request it with AXIsProcessTrustedWithOptions at first use of paste and explain why in a sheet. When pasting is done and the queue becomes empty, optionally restore the pasteboard contents saved at the moment queue mode started. Store the queue in memory and also mirror it to a small JSON file in Application Support so a crash does not lose it. Show the HUD using a nonactivating NSPanel with a SwiftUI view and a fade animation. Launch at login uses SMAppService.mainApp.

Edge cases and error handling. If the queue is empty when the paste key is pressed, play the system beep and show the HUD message Queue is empty. Cap the queue at 200 items and 1 megabyte per item. If Accessibility is not granted, the paste key places the item on the pasteboard and shows a HUD asking the user to press Command V. Handle images by supporting them in the queue as TIFF data but excluding them from joined paste. Turning queue mode off asks whether to keep or discard remaining items. Avoid capturing the app's own pasteboard writes, and handle the hotkey being unavailable with an inline settings warning.
