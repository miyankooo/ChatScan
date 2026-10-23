# Chat Scan

Watches the chat you pick for your keywords and forwards every matching line to the chat tabs you choose, with an optional sound.

## Features

- Keyword rules: each row is one rule, and commas inside a row require every word
- Keywords match at the start of a word and ignore case, so `lf` finds LFG and LF1M but not "self"
- Scans any channel you are in, such as General, Trade and LookingForGroup, custom channels and community channels
- Scans guild, officer and Guild Discord chat, party, raid and instance chat, say, yell, emotes and whispers
- Forwarded lines look like the game's own, with the channel tag, the chat colour and a clickable sender
- Lines carry your chat timestamp, or a grey time when chat timestamps are off
- A repeated line from the same sender is shown once every 2 minutes
- An optional alert sound, at most once every 3 seconds
- Zone channels such as General and Trade stay ticked when you change zones
- A minimap button and an Addon Compartment entry. Left-click opens the window, right-click starts or stops the scan, and the tooltip lists your keywords
- Settings are saved per character, and an active scan resumes after login or `/reload`

## Installation

1. Install it with the CurseForge app under WoW Forever, or copy the `ChatScan` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
2. Restart the game or type `/reload`.
3. Enable Chat Scan in the AddOns list.

## Usage

1. Type `/cs`, or click the minimap button or the Addon Compartment entry. The first time, the channels you have joined are ticked for you.
2. Under Keywords, type a rule such as `wts thunderfury` or `lf, tank` and press Enter. The scan starts.
3. Under Channels and Chat Types, tick the chat to watch.
4. Under Output Tabs, tick the chat tabs that receive matches. With none ticked, matches go to your main chat tab.
5. Under Sound, pick an alert or None.
6. Press Stop to pause the scan and Start to resume it.

| Rule | Matches |
| --- | --- |
| `wts thunderfury` | lines containing `wts thunderfury` |
| `lf, tank` | lines containing both `lf` and `tank` |
| `lf, tank` and `lf, heal` as two rows | `lf` with `tank`, or `lf` with `heal` |

## Commands

| Command | Does |
| --- | --- |
| `/cs` | Opens or closes the window |
| `/cs <rule>` | Adds a rule, such as `/cs lf, tank`, and starts scanning |
| `/cs start` | Starts scanning with your saved settings |
| `/cs stop` | Stops scanning |
| `/cs clear` | Removes every rule |
| `/cs minimap` | Hides or shows the minimap button |

`/chatscan` works as well.

## Requirements

WoW Forever 1.60.x (Interface `16001`). No other addons needed.

## Restrictions

The game can hide chat text from addons in some places, such as dungeons, raids and battlegrounds. Chat Scan then pauses matching, says so once in chat and shows "Chat locked" in the window and the minimap tooltip. It picks up again when the text is readable.

Battle.net communities are not scanned, because the game hands their text to addons in a protected form.

Your own lines are forwarded too, including the whispers you send.

Built-in emotes such as `/wave`, voice chat, NPC chat and system messages are not scanned.

## Development

Run the offline checks from the `ChatScan` folder:

```sh
lua Tests/Scanner.lua
lua Tests/LibNativeUI.lua
```

## License

MIT. See [LICENSE](LICENSE).
