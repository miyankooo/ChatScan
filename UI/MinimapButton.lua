local _, ns = ...

-- One launcher for the minimap button and the Addon Compartment: LibDBIcon draws the button and adds the
-- compartment entry through AddonCompartmentFrame, so both share the click and the tooltip. Such an addon has no
-- AddonCompartmentFunc toc keys. LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0 load first.
local function CreateLauncher(icon, db, onClick, fillTooltip)
    local LDBIcon = LibStub("LibDBIcon-1.0")
    if not LDBIcon:IsRegistered(ns.title) then
        local object = LibStub("LibDataBroker-1.1"):NewDataObject(ns.title, {
            type = "launcher",
            text = ns.title,
            icon = icon,
            OnClick = function(_, button) onClick(button) end,
            OnTooltipShow = function(tooltip)
                GameTooltip_SetTitle(tooltip, ns.title)
                fillTooltip(tooltip)
            end,
        })
        LDBIcon:Register(ns.title, object, db)
        LDBIcon:AddButtonToCompartment(ns.title)
    end
    -- Shows or hides only the minimap button and remembers it in db.hide; the addon menu entry stays.
    return function(shown)
        db.hide = not shown
        if shown then LDBIcon:Show(ns.title) else LDBIcon:Hide(ns.title) end
    end
end

-- The scan state in one word, coloured as the window's status box colours it.
local function statusText()
    local Scanner = ns.Scanner
    if not Scanner.scanning then
        return GRAY_FONT_COLOR:WrapTextInColorCode("Not scanning")
    elseif Scanner.chatLocked then
        return WARNING_FONT_COLOR:WrapTextInColorCode("Chat locked")
    elseif not Scanner.CanMatch() then
        return WARNING_FONT_COLOR:WrapTextInColorCode("Nothing to match")
    end
    return GREEN_FONT_COLOR:WrapTextInColorCode("Scanning")
end

-- The current state as white double rows, then one green instruction line per click, as every launcher in
-- the set reads.
local function fillTooltip(tooltip)
    GameTooltip_AddColoredDoubleLine(tooltip, "Status", statusText(), HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddColoredDoubleLine(tooltip, "Rules", tostring(#ns.Store.Get().keywords),
        HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddColoredDoubleLine(tooltip, "Matches", tostring(ns.Scanner.matchCount),
        HIGHLIGHT_FONT_COLOR, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddBlankLineToTooltip(tooltip)
    GameTooltip_AddInstructionLine(tooltip, "Click to toggle the window.")
    GameTooltip_AddInstructionLine(tooltip,
        ns.Scanner.scanning and "Right-click to stop the scan." or "Right-click to start the scan.")
end

local function onClick(button)
    if button == "RightButton" then
        ns.Scanner.Toggle()
    else
        ns.TogglePanel()
    end
end

-- The minimap position lives in the account-wide table, so every character shares it.
function ns.SetupLauncher()
    ns.SetMinimapShown = CreateLauncher(ns.ICON, ns.Store.Minimap(), onClick, fillTooltip)
end
