local _, ns = ...

local HELP = "Type /cs to open the window, /cs and a rule to add it and start scanning, /cs start, /cs stop "
    .. "or /cs clear for the scan and its rules, /cs intro to see the welcome line and the tip again, "
    .. "/cs minimap to show or hide the minimap button, or /cs help for this list."

-- One line per action: an idle scan starts and its start line covers the rule, a running scan
-- confirms the rule itself. A fresh character gets its joined channels ticked first.
local function confirmOrStart(text)
    if ns.Scanner.scanning then
        ns.Print(text)
    else
        ns.SeedChannels()
        ns.Scanner.Start()
    end
end

-- Stores a rule, then starts. A rule already tracked (any case) is not stored twice.
local function addKeyword(raw)
    if not ns.hasTerm(raw) then
        ns.Print(ns.NO_TERM)
        return
    end
    local keywords = ns.Store.Get().keywords
    local lower = raw:lower()
    for _, existing in ipairs(keywords) do
        if existing:lower() == lower then
            confirmOrStart("Already tracking: " .. existing .. ".")
            return
        end
    end
    keywords[#keywords + 1] = raw
    ns.Scanner.ReloadKeywords()
    ns.RefreshPanel()
    ns.RetireKeywordTip()
    confirmOrStart("Added rule: " .. raw .. ".")
end

local function clearKeywords()
    local store = ns.Store.Get()
    if #store.keywords == 0 then
        ns.Print("No rules to clear.")
        return
    end
    store.keywords = {}
    ns.Scanner.ReloadKeywords()
    ns.Print("Rules cleared.")
    ns.RefreshPanel()
end

-- One long command and one short alias. The bare command opens the window; help, intro and minimap
-- are the shared words, start, stop and clear run the scan, and any other text is a rule, so
-- /cs wts thunderfury adds it.
SLASH_CHATSCAN1, SLASH_CHATSCAN2 = "/chatscan", "/cs"
SlashCmdList.CHATSCAN = function(message)
    local raw = ns.trim(message)
    local command = raw:lower()

    if raw == "" then
        ns.TogglePanel()
    elseif command == "help" or command == "?" then
        ns.Print(HELP)
    elseif command == "intro" then
        ns.ReplayIntro()
    elseif command == "start" then
        if ns.Scanner.scanning then ns.Print("Already scanning.") else ns.Scanner.Start() end
    elseif command == "stop" then
        if ns.Scanner.scanning then ns.Scanner.Stop() else ns.Print("Not scanning.") end
    elseif command == "clear" then
        clearKeywords()
    elseif command == "minimap" then
        -- Only the minimap button hides; the addon menu entry stays as the way back. Hiding prints
        -- the way back, showing prints nothing, since the button is the feedback.
        local show = ns.Store.Minimap().hide
        ns.SetMinimapShown(show)
        if not show then ns.Print("Minimap button hidden. Type /cs minimap to show it again.") end
    else
        addKeyword(raw)
    end
end
