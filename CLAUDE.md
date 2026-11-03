# ChatScan

Features, commands and restrictions are in `README.md`.

## Target

- WoW Forever 1.60.x only, `## Interface: 16001`. No client branches, no `WOW_PROJECT_*`, no compat layer.
- `main` holds the Forever version. `1.15.x-backup` keeps the Classic version and stays untouched.
- Verify every API against Gethe `wow-ui-source` and Ketho `BlizzardInterfaceResources`, branch `forever`.

## Setup

- Link the repo folder into `World of Warcraft/_forever_/Interface/AddOns/` with `ln -s`. Edit and commit here, never in the install.

## Rules

- Chat payload fields 1, 2, 5, 12, 13 and 18 are secret during chat lockdown. Filter by tick first, then check `C_ChatInfo.InChatMessagingLockdown()`. Only then read the text. Guild Discord goes through the same gate.
- `Core/Lines.lua` builds every forwarded line like Blizzard's `MessageFormatter` in `Mainline/ChatFrameOverrides.lua`, so tags, colours and links match Blizzard's own lines.
- The player's own lines, sent whispers included, are always forwarded. This is a product rule, not a test aid.
- Keywords match at a word start (`%f[%w]` plus the escaped term). A term that opens with punctuation or a non-ASCII byte matches anywhere.
- A line `C_ChatInfo.IsChatLineCensored(lineID)` marks as censored is never forwarded, so ChatScan never shows text Blizzard's chat hides.
- Battle.net communities are not offered and K-string club text is skipped: their text is not readable plain text.
- The alert plays on the `Master` channel. `soundId` 0 means None.
- Left out on purpose: `CHAT_MSG_TEXT_EMOTE`, `CHAT_MSG_AFK`, `CHAT_MSG_DND`, voice channels, NPC and system chat.
- The UI is built from LibNativeUI-1.0: `UI.Font` roles, `UI.Space`, `UI.Native` and the 4 px grid. No `N * UI.GRID` sizes, no literal `|cff` codes.
- The window has a fixed 674x548 size (674 carries Blizzard's 4/-6 inset offsets), no attic. Each well scrolls. The status sits in an inset that fills the button bar left of Start. Keep the minimap button, hideable with `/cs minimap`: left-click toggles the window, right-click starts or stops the scan through `Scanner.Toggle`. The tooltip lists the keywords. No options page.
- Title Case for headings and buttons, sentence case ending in a period for helper lines and chat. Use Blizzard global strings where one exists (`ADD`, `CHANNELS`, `GUILD`, `GROUP`, `SOUND`, `NONE`, `START`). "Stop" stays literal because no `STOP` global exists.
- One chat line per action. No chat at login: a resumed scan stays quiet.
- First use (window open or `/cs <rule>`) ticks the joined channels once through `ns.SeedChannels`, never in chat lockdown.
- The Sound slot holds the dropdown's art below the button (`DROPDOWN_ART_BELOW`), so the scroll frame never clips it.
- The toc version stays 1.0.0 until the first CurseForge release.
- Licence: MIT (LICENSE).

## Libraries

- `Libs/` holds tracked, unedited upstream copies. No `.pkgmeta` externals.
- ChatScan holds the reference copy of LibNativeUI-1.0. Every other addon carries a byte-identical copy. Change it only by raising `MINOR` and copying it to all of them. `shasum */Libs/LibNativeUI-1.0/LibNativeUI-1.0.lua` must print one hash.

## Learnings

- LibDBIcon draws Classic button sizes on Forever, because `WOW_PROJECT_ID` is 18 (`WOW_PROJECT_CAMELOT`) and not mainline.
- The BigWigs packager maps `## Interface: 16???` to game type `forever`, so the Forever-only toc packages as is.
- The release checkout needs `fetch-depth: 0`. Without the full history the packager finds no previous tag and the changelog comes out empty.

## Checks

- Run `luac -p` on every Lua file after a change.
- Run `lua Tests/Scanner.lua` (matching, dedupe, sound) and `lua Tests/LibNativeUI.lua` from the repo folder.
- Turn on `/console scriptErrors 1` before testing in game.

## Release

1. Move the `## Unreleased` entries in `CHANGELOG.md` under the version, push `main` and tag `vX.Y.Z`.
2. `.github/workflows/release.yml` packages it with the BigWigsMods packager.
3. Without `CF_API_TOKEN` and a toc `X-Curse-Project-ID` the packager skips the CurseForge upload and only publishes the GitHub release.
4. Check that the zip holds all five libraries.
