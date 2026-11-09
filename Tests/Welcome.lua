-- Offline check of the first-use onboarding in Core/Store.lua, Core/Commands.lua, UI/Welcome.lua and
-- Bootstrap.lua: the welcome line, its window link, the Keywords tip and the slash commands.
--
-- Run from the ChatScan folder:  lua Tests/Welcome.lua

local here = debug.getinfo(1, "S").source:match("@(.*[/\\])") or "./"
local ROOT = here .. "../"

-- Chat lines go to the stubbed print, test results to the real one.
local realPrint = print

local ns, lines, linkCallbacks, loginHandler, loader, opened, toggled, minimap, secret, tips

local function Color(hex)
    return { WrapTextInColorCode = function(_, text) return "|cff" .. hex .. text .. "|r" end }
end

-- A frame that keeps its OnShow hooks and visibility, enough for the tip's target.
local function Target()
    local target = { hooks = {}, visible = false }
    function target:HookScript(_, fn) self.hooks[#self.hooks + 1] = fn end
    function target:IsVisible() return self.visible end
    function target:Show()
        self.visible = true
        for _, fn in ipairs(self.hooks) do fn(self) end
    end
    function target:Hide() self.visible = false end
    return target
end

-- Fresh client stubs per load, so no case leaks saved settings, callbacks or chat lines into the next.
local function Load(db)
    lines, linkCallbacks, opened, toggled, minimap, secret, tips = {}, {}, 0, 0, nil, false, {}
    ChatScanDB, ChatScanCharDB = db, nil

    print = function(message) lines[#lines + 1] = message end
    C_AddOns = { GetAddOnMetadata = function() return "Chat Scan" end }
    NORMAL_FONT_COLOR = Color("ffd200")
    canaccessvalue = function() return not secret end
    SOUNDKIT = { MAP_PING = 1 }
    LinkTypes = { AddOn = "addon" }
    LinkUtil = {
        FormatLink = function(linkType, text, ...)
            return table.concat({ "|H" .. linkType, ... }, ":") .. "|h" .. text .. "|h"
        end,
    }
    EventRegistry = {
        RegisterCallback = function(_, event, fn, owner)
            if event == "SetItemRef" then linkCallbacks[#linkCallbacks + 1] = { fn = fn, owner = owner } end
        end,
    }
    HelpTip = { width = 225, ButtonStyle = { Close = 1 }, Point = { LeftEdgeCenter = 11 } }
    CreateFrame = function(_, _, _, template)
        local frame = { template = template, shown = false }
        function frame:RegisterEvent() end
        function frame:UnregisterEvent() end
        function frame:SetScript(_, fn) loginHandler, loader = fn, self end
        function frame:SetWidth() end
        function frame:Reset() self.info = nil end
        function frame:Init(_, info) self.info = info end
        function frame:Show() self.shown = true end
        function frame:IsShown() return self.shown end
        function frame:Acknowledge()
            self.shown = false
            self.info.onAcknowledgeCallback()
        end
        if template == "HelpTipTemplate" then tips[#tips + 1] = frame end
        return frame
    end
    SlashCmdList = {}

    ns = {
        Scanner = { Resume = function() end, scanning = false },
        SetupLauncher = function() end,
        SetMinimapShown = function(shown) minimap = shown; ChatScanDB.minimap.hide = not shown end,
        TogglePanel = function() toggled = toggled + 1 end,
        ShowPanel = function() opened = opened + 1 end,
        RefreshPanel = function() end,
    }
    for _, file in ipairs({ "Core/Init.lua", "Core/Store.lua", "Core/Commands.lua", "UI/Welcome.lua", "Bootstrap.lua" }) do
        assert(loadfile(ROOT .. file))("ChatScan", ns)
    end
end

local function Login() loginHandler(loader) end

local function ClickLink(link)
    for _, callback in ipairs(linkCallbacks) do callback.fn(callback.owner, link) end
end

local function Slash(message)
    SlashCmdList.CHATSCAN(message)
    return lines[#lines]
end

local failures, passes = 0, 0
local function Check(name, condition)
    if condition then passes = passes + 1 else
        failures = failures + 1
        realPrint("FAIL " .. name)
    end
end

local PREFIX = "|cffffd200[Chat Scan]|r: "
local LINK = "|cffffd200|Haddon:ChatScan|h[Chat Scan]|h|r"
local WELCOME = PREFIX .. "Forwards chat lines that match your keywords to the chat tabs you pick. Open the " .. LINK
    .. " window or type /cs to add your first keyword."

-- The welcome line.
Load(nil)
Check("first load: prints nothing before login", #lines == 0)
Login()
Check("first login: sets the first-run flag", ns.firstRun == true)
Check("first login: exactly one welcome line", #lines == 1)
Check("first login: the line reads as the shared shape", lines[1] == WELCOME)

ClickLink("addon:ChatScan")
Check("link: a click opens the window", opened == 1)
ClickLink("addon:OtherAddon")
Check("link: another addon's link does nothing", opened == 1)
secret = true
ClickLink("addon:ChatScan")
secret = false
Check("link: a secret link does nothing", opened == 1)

Load({})
Login()
Check("later login: prints nothing", not ns.firstRun and #lines == 0)

-- The Keywords tip.
local column, rows = Target(), {}
ns.AttachKeywordTip(column, rows)
Check("tip: waits for the window", #tips == 0)
column:Show()
Check("tip: shows with the window", #tips == 1 and tips[1].shown and tips[1].info.targetPoint == 11)
tips[1]:Acknowledge()
Check("tip: its close button marks it seen", ChatScanDB.tipSeen == true)
column:Hide()
column:Show()
Check("tip: a seen tip stays away", not tips[1].shown)

Slash("intro")
Check("intro: prints the welcome line again", lines[#lines] == WELCOME)
Check("intro: the tip shows again while the window is open", ChatScanDB.tipSeen == nil and tips[1].shown)
ns.RetireKeywordTip()
Check("tip: adding a rule retires it for good", ChatScanDB.tipSeen == true and not tips[1].shown)

-- Slash commands.
local help = Slash("help")
Check("help: one line naming every command", help:find("^" .. PREFIX:gsub("%p", "%%%0") .. "Type /cs to open the window")
    ~= nil and help:find("/cs intro", 1, true) ~= nil and help:find("/cs minimap", 1, true) ~= nil)
Check("?: the same line", Slash("?") == help)
Slash("")
Check("bare command: toggles the window", toggled == 1)
local before = #lines
Slash("minimap")
Check("minimap: hiding says how to bring it back", minimap == false
    and lines[#lines] == PREFIX .. "Minimap button hidden. Type /cs minimap to show it again.")
Slash("minimap")
Check("minimap: showing prints nothing", minimap == true and #lines == before + 1)

print = realPrint
print(string.format("Welcome check: %d passed, %d failed", passes, failures))
if failures > 0 then os.exit(1) end
