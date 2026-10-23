-- Offline check for keyword matching, dedupe, rule validation and the alert sound. It loads the real
-- Core/Init.lua, Core/Store.lua and Core/Scanner.lua against client stubs and feeds chat events through
-- the scanner's own event handler.
--
-- Run from the ChatScan folder:  lua Tests/Scanner.lua

local here = debug.getinfo(1, "S").source:match("@(.*[/\\])") or "./"
local ROOT = here .. "../"

local failures, passes = 0, 0
local function check(label, ok, detail)
    if ok then
        passes = passes + 1
    else
        failures = failures + 1
        print("FAIL " .. label .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
    end
end

strlower = string.lower
strfind = string.find
date = os.date
time = os.time

-- The clock the dedupe window and the sound throttle read.
local clock = 0
function GetTime() return clock end

SOUNDKIT = { MAP_PING = 1, TELL_MESSAGE = 2, RAID_WARNING = 3, READY_CHECK = 4, AUCTION_WINDOW_OPEN = 5,
    ALARM_CLOCK_WARNING_1 = 6 }

local sounds = {}
function PlaySound(id, channel) sounds[#sounds + 1] = { id = id, channel = channel } end

local printed = {}
local UI = {
    Print = function(_, message) printed[#printed + 1] = message end,
    Color = { muted = { WrapTextInColorCode = function(_, text) return text end } },
}
function LibStub() return UI end

-- The event frame keeps its handler, so the test can fire events at it.
local eventFrame
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(_, fn) self.onEvent = fn end
    eventFrame = frame
    return frame
end

C_ChatInfo = { InChatMessagingLockdown = function() return false end }
ChatFrameUtil = { GetTimestampFormat = function() return nil end }
Constants = { ChatFrameConstants = { MaxChatWindows = 10 } }
function GetChatWindowInfo(i) return i == 1 and "General" or "" end
function FCF_IsChatWindowIndexActive(i) return i == 1 end
function RunNextFrame(fn) fn() end

-- Forwarded lines land here; Lines.lua is replaced by the bare text.
local delivered = {}
ChatFrame1 = { AddMessage = function(_, line) delivered[#delivered + 1] = line end, IsShown = function() return true end }
DEFAULT_CHAT_FRAME = ChatFrame1

local ns = {}
local function load(path)
    local chunk, err = loadfile(ROOT .. path)
    if not chunk then error(err) end
    chunk("ChatScan", ns)
end

load("Core/Init.lua")
load("Core/Store.lua")
ns.Lines = { Chat = function(_, msg) return msg, 1, 1, 1, 1 end }
load("Core/Scanner.lua")

ns.Store.Init()
local store = ns.Store.Get()
store.chatTypes.say = true

local function rules(...)
    store.keywords = { ... }
    ns.Scanner.ReloadKeywords()
end

-- Fires CHAT_MSG_SAY and reports whether a line was forwarded.
local function say(text, sender)
    local before = #delivered
    eventFrame.onEvent(eventFrame, "CHAT_MSG_SAY", text, sender or "Player-Realm")
    return #delivered > before
end

-- Each matching case uses a new sender, so dedupe never hides a result.
local senderCount = 0
local function matches(text)
    senderCount = senderCount + 1
    return say(text, "Sender" .. senderCount)
end

rules("lf")
ns.Scanner.Start()
check("start announces sources and rules", printed[#printed] == "Scanning 1 source for 1 rule.", printed[#printed])

-- Word-start matching
check("lf matches LFG", matches("LFG tank for Deadmines"))
check("lf matches LF1M", matches("LF1M heal"))
check("lf matches a lone lf", matches("anyone lf summon?"))
check("lf skips self", not matches("buff self"))
check("lf skips half", not matches("half price"))
check("lf skips golf", not matches("golf anyone"))

rules("lf, tank")
check("comma terms all have to match", matches("LFM tank DM"))
check("one missing term fails the rule", not matches("LFM heal DM"))

rules("lf, tank", "wts")
check("rows are alternatives", matches("WTS Lionheart Helm"))

rules("thunderfury")
check("a term matches inside an item link's name",
    matches("WTS |cffff8000|Hitem:19019::::::::60:::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"))

rules("100g")
check("a number term matches at a word start", matches("selling for 100g each"))
check("a number term skips a longer number", not matches("selling for 1100g each"))

rules("{skull}")
check("a term opening with punctuation matches anywhere", matches("kill{skull}first"))

rules("lf+")
check("pattern characters in a term are literal", matches("lf+ anyone") and not matches("lff anyone"))

-- Dedupe: the same sender and text forward once per 2 minutes
rules("dedupe")
clock = 1000
check("first line forwards", say("dedupe test", "Spammer"))
clock = 1060
check("a repeat after 60 s is hidden", not say("dedupe test", "Spammer"))
check("another sender with the same text forwards", say("dedupe test", "Other"))
clock = 1121
check("a repeat after 121 s forwards again", say("dedupe test", "Spammer"))

clock = 2000
say("dedupe evict", "First")
for i = 1, ns.DEDUP_MAX do say("dedupe evict " .. i, "Filler") end
check("the oldest entry is evicted beyond the cap", say("dedupe evict", "First"))

-- Rule validation
check("a rule of commas and spaces has no term", not ns.hasTerm(", ,") and not ns.hasTerm("   "))
check("a rule with one word has a term", ns.hasTerm(" , wts"))

-- Alert sound: Master channel, throttled, and off with None
rules("ding")
store.soundId = SOUNDKIT.RAID_WARNING
sounds = {}
clock = 3000
say("ding one", "A")
check("the alert plays on the master channel", sounds[1] and sounds[1].id == SOUNDKIT.RAID_WARNING
    and sounds[1].channel == "Master")
clock = 3001
say("ding two", "B")
check("a second alert within 3 s is throttled", #sounds == 1, #sounds)
store.soundId = ns.NO_SOUND
clock = 3010
check("None forwards silently", say("ding three", "C") and #sounds == 1, #sounds)

-- One chat line per action: a start in lockdown and /cs <rule>
local lockdown = true
C_ChatInfo.InChatMessagingLockdown = function() return lockdown end
ns.Scanner.Stop()
printed = {}
ns.Scanner.Start()
check("a start in lockdown prints one line", #printed == 1 and printed[1] == "Chat is locked here, matching paused.",
    table.concat(printed, " | "))
lockdown = false

local slash, seeded = nil, 0
UI.RegisterSlash = function(_, _, handler) slash = handler end
ns.RefreshPanel = function() end
ns.SeedChannels = function() seeded = seeded + 1 end
load("Core/Commands.lua")

ns.Scanner.Stop()
store.keywords = {}
printed = {}
slash("wts gem")
check("/cs <rule> while idle seeds channels and prints only the start line",
    seeded == 1 and #printed == 1 and printed[1] == "Scanning 1 source for 1 rule.", table.concat(printed, " | "))
printed = {}
slash("wtb ore")
check("/cs <rule> while scanning confirms the rule", #printed == 1 and printed[1] == "Added rule: wtb ore.", printed[1])
printed = {}
slash("WTS GEM")
check("a rule in another case is not stored twice", #printed == 1 and printed[1] == "Already tracking: wts gem."
    and #store.keywords == 2, printed[1])

print(string.format("Scanner check: %d passed, %d failed", passes, failures))
if failures > 0 then os.exit(1) end
