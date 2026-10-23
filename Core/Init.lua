local _, ns = ...

-- Spaced name for everything the player reads: the window title, the chat prefix and the
-- launcher, whose LibDataBroker name it also is.
ns.TITLE = "Chat Scan"

-- The same icon as the toc's IconTexture.
ns.ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"

-- Trade posts repeat every 30 to 90 seconds, so a repeat within 2 minutes is shown once.
ns.DEDUP_TTL = 120
ns.DEDUP_MAX = 100
ns.SOUND_THROTTLE = 3.0

-- The alert plays on the master channel, so it is heard even with sound effects turned off.
ns.SOUND_CHANNEL = "Master"

-- Named alerts for the sound picker, so the player never types a raw sound kit id.
ns.SOUNDS = {
    { name = "Minimap Ping", id = SOUNDKIT.MAP_PING },
    { name = "Whisper", id = SOUNDKIT.TELL_MESSAGE },
    { name = "Raid Warning", id = SOUNDKIT.RAID_WARNING },
    { name = "Ready Check", id = SOUNDKIT.READY_CHECK },
    { name = "Auction Window", id = SOUNDKIT.AUCTION_WINDOW_OPEN },
    { name = "Alarm Clock", id = SOUNDKIT.ALARM_CLOCK_WARNING_1 },
}
ns.DEFAULT_SOUND_ID = SOUNDKIT.MAP_PING

-- The sound id that stands for the None pick.
ns.NO_SOUND = 0

-- Chat that is not a numbered channel, labelled with Blizzard's chat settings strings. One tick
-- covers every event Blizzard prints under that chat, so leader lines count as their group's and
-- the player's own outgoing whispers count as whispers. Own lines are always forwarded, a product
-- rule. Canned emotes (/wave) are text the client writes, so they are left out; /e emotes are
-- typed by the sender and stay in.
ns.CHAT_GROUPS = {
    { title = GUILD, types = {
        { key = "guild", label = GUILD_CHAT, events = { "CHAT_MSG_GUILD" } },
        { key = "officer", label = OFFICER_CHAT, events = { "CHAT_MSG_OFFICER" } },
        { key = "guilddiscord", label = GUILD_DISCORD_CHAT, events = { "CHAT_MSG_GUILD_DISCORD" } },
    } },
    { title = GROUP, types = {
        { key = "party", label = PARTY, events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" } },
        { key = "raid", label = RAID, events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" } },
        { key = "instance", label = INSTANCE_CHAT, events = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" } },
    } },
    { title = "Nearby", types = {
        { key = "say", label = SAY, events = { "CHAT_MSG_SAY" } },
        { key = "yell", label = YELL, events = { "CHAT_MSG_YELL" } },
        { key = "emote", label = EMOTE, events = { "CHAT_MSG_EMOTE" } },
    } },
    { title = "Whispers", types = {
        { key = "whisper", label = WHISPER, events = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM" } },
        { key = "bnwhisper", label = BN_WHISPER, events = { "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" } },
    } },
}

-- ChatFrame2 is always reset and docked as the combat log, so it never receives forwarded lines.
ns.COMBAT_LOG_INDEX = 2

function ns.countLabel(count, one, many)
    return string.format("%d %s", count, count == 1 and one or many)
end

function ns.trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

-- A rule made only of commas and spaces can never match, so it is never stored.
ns.NO_TERM = "A rule needs at least one word."

function ns.hasTerm(row)
    return row:find("[^,%s]") ~= nil
end

-- Zone channels carry a " - Zone" suffix, so it is dropped to keep a scan alive across zone
-- changes. Custom channel names cannot contain spaces, so they are never truncated.
function ns.channelKey(name)
    local key = strlower(name or ""):gsub("%s+%-%s+.*$", "")
    return key
end
