local _, ns = ...

local UI = LibStub("LibNativeUI-1.0")

-- One short line on the scan state, in the colours of the panel's status line.
local function statusLine()
    local Scanner = ns.Scanner
    if not Scanner.scanning then
        return UI.Color.muted:WrapTextInColorCode("Not scanning")
    elseif Scanner.chatLocked then
        return UI.Color.warn:WrapTextInColorCode("Chat locked") .. ", matching paused"
    elseif not Scanner.CanMatch() then
        return UI.Color.warn:WrapTextInColorCode("Nothing to match")
    end
    return UI.Color.good:WrapTextInColorCode("Scanning") .. ", " .. ns.countLabel(Scanner.matchCount, "match", "matches")
end

-- The lines under the launcher's title, written with Blizzard's tooltip line helpers so the colours
-- match every native tooltip. The rules follow the status, so the tooltip says what a scan matches.
local function fillTooltip(tooltip)
    GameTooltip_AddHighlightLine(tooltip, statusLine())

    local keywords = ns.Store.Get().keywords
    GameTooltip_AddBlankLineToTooltip(tooltip)
    if #keywords == 0 then
        GameTooltip_AddDisabledLine(tooltip, "No keywords yet.")
    else
        GameTooltip_AddNormalLine(tooltip, "Keywords")
        for _, keyword in ipairs(keywords) do GameTooltip_AddHighlightLine(tooltip, keyword) end
    end

    GameTooltip_AddBlankLineToTooltip(tooltip)
    GameTooltip_AddInstructionLine(tooltip, "Left-click to toggle the window.")
    GameTooltip_AddInstructionLine(tooltip,
        ns.Scanner.scanning and "Right-click to stop the scan." or "Right-click to start the scan.")
end

local function onClick(button)
    if button == "LeftButton" then
        ns.TogglePanel()
    elseif button == "RightButton" then
        ns.Scanner.Toggle()
    end
end

local launcher

-- The minimap button and the addon menu entry share this click and tooltip. The minimap position
-- lives in the account-wide db table, so every character shares it.
function ns.SetupLauncher()
    launcher = UI.CreateLauncher({
        title = ns.TITLE,
        icon = ns.ICON,
        db = ns.Store.Minimap(),
        onClick = onClick,
        tooltip = fillTooltip,
    })
end

-- /cs minimap flips only the minimap button; the addon menu entry always stays.
function ns.ToggleMinimap()
    local show = ns.Store.Minimap().hide
    launcher.setShown(show)
    UI.Print(ns.TITLE, show and "Minimap button shown." or "Minimap button hidden. Type /cs minimap to show it again.")
end
