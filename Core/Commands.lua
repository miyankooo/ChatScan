local _, ns = ...

local UI = LibStub("LibNativeUI-1.0")

-- One line per action: an idle scan starts and its start line covers the rule, a running scan
-- confirms the rule itself. A fresh character gets its joined channels ticked first.
local function confirmOrStart(text)
    if ns.Scanner.scanning then
        UI.Print(ns.TITLE, text)
    else
        ns.SeedChannels()
        ns.Scanner.Start()
    end
end

-- Stores a rule, then starts. A rule already tracked (any case) is not stored twice.
local function addKeyword(raw)
    if not ns.hasTerm(raw) then
        UI.Print(ns.TITLE, ns.NO_TERM)
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
    confirmOrStart("Added rule: " .. raw .. ".")
end

local function clearKeywords()
    local store = ns.Store.Get()
    if #store.keywords == 0 then
        UI.Print(ns.TITLE, "No rules to clear.")
        return
    end
    store.keywords = {}
    ns.Scanner.ReloadKeywords()
    UI.Print(ns.TITLE, "Rules cleared.")
    ns.RefreshPanel()
end

-- A bare /cs toggles the window, a command word runs it, anything else is a rule.
local function handleSlash(msg)
    local raw = ns.trim(msg)
    local command = raw:lower()

    if raw == "" then
        ns.TogglePanel()
    elseif command == "start" then
        if ns.Scanner.scanning then UI.Print(ns.TITLE, "Already scanning.") else ns.Scanner.Start() end
    elseif command == "stop" then
        if ns.Scanner.scanning then ns.Scanner.Stop() else UI.Print(ns.TITLE, "Not scanning.") end
    elseif command == "clear" then
        clearKeywords()
    elseif command == "minimap" then
        ns.ToggleMinimap()
    else
        addKeyword(raw)
    end
end

UI.RegisterSlash("CHATSCAN", { "/chatscan", "/cs" }, handleSlash)
