# ChatScan

Features, commands and restrictions are in `README.md`.

## Target

- `main` holds the Forever version. `1.15.x-backup` keeps the Classic version.

## Rules

- Chat payload fields 1, 2, 5, 12, 13 and 18 are secret during chat lockdown. Filter by tick first, then check `C_ChatInfo.InChatMessagingLockdown()`. Only then read the text. Guild Discord goes through the same gate.
- `Core/Lines.lua` builds every forwarded line like Blizzard's `MessageFormatter` in `Mainline/ChatFrameOverrides.lua`, so tags, colours and links match Blizzard's own lines.
- The player's own lines, sent whispers included, are always forwarded. This is a product rule, not a test aid.
- Keywords match at a word start (`%f[%w]` plus the escaped term). A term that opens with punctuation or a non-ASCII byte matches anywhere.
- A line `C_ChatInfo.IsChatLineCensored(lineID)` marks as censored is never forwarded, so ChatScan never shows text Blizzard's chat hides.
- Battle.net communities are not offered and K-string club text is skipped: their text is not readable plain text.
- The alert plays on the `Master` channel. `soundId` 0 means None.
- Left out on purpose: `CHAT_MSG_TEXT_EMOTE`, `CHAT_MSG_AFK`, `CHAT_MSG_DND`, voice channels, NPC and system chat.
- The UI is built from LibNativeUI-1.0: `UI.Font` roles, `UI.Space`, `UI.Native` and the 4 px grid. No `N * UI.GRID` sizes.
- The window has a fixed 674x548 size (674 carries Blizzard's 4/-6 inset offsets), no attic. Each well scrolls. The status sits in an inset that fills the button bar left of Start. Keep the minimap button, hideable with `/cs minimap`: left-click toggles the window, right-click starts or stops the scan through `Scanner.Toggle`. The tooltip lists the keywords. No options page.
- Helper lines are sentences ending with a period. Use Blizzard global strings where one exists (`ADD`, `CHANNELS`, `GUILD`, `GROUP`, `SOUND`, `NONE`, `START`). "Stop" stays literal because no `STOP` global exists.
- No chat at login: a resumed scan stays quiet.
- First use (window open or `/cs <rule>`) ticks the joined channels once through `ns.SeedChannels`, never in chat lockdown.
- The Sound slot holds the dropdown's art below the button (`DROPDOWN_ART_BELOW`), so the scroll frame never clips it.

## Learnings

- LibDBIcon draws Classic button sizes on Forever, because `WOW_PROJECT_ID` is 18 (`WOW_PROJECT_CAMELOT`) and not mainline.
- The BigWigs packager maps `## Interface: 16???` to game type `forever`, so the Forever-only toc packages as is.
- The release checkout needs `fetch-depth: 0`. Without the full history the packager finds no previous tag and the changelog comes out empty.

## Checks

- Run `lua Tests/Scanner.lua` (matching, dedupe, sound) and `lua Tests/LibNativeUI.lua` from the repo folder.

## Release

- Check that the zip holds all five libraries.
