# Chat Scan

## Unreleased

- Keywords match at the start of a word, so "lf" finds "LFG" and "LF1M" but no longer "self" or "half".
- A repeated line from the same sender is shown once every 2 minutes instead of every 10 seconds.
- Community streams are listed under Channels, and Battle.net communities are no longer offered.
- Keywords come first in the window, and the helper text is down to two short lines.
- Sound is one dropdown with a None option, and the alert plays on the master channel.
- Adding a rule in the window starts the scan, the caret moves to the next row and a duplicate rule is reported.
- A rule made only of commas and spaces is refused.
- Output Tabs updates when a chat tab opens, closes or is renamed.
- Forwarded lines use your chat timestamp setting when it is on.
- The first time you open the window or add a rule with `/cs`, the channels you have joined are ticked.
- The window remembers its position and is shorter.
- `/cs minimap` hides or shows the minimap button.
- Clicking a checkbox label toggles it.
- Shorter chat messages and no chat line when a scan resumes at login.
