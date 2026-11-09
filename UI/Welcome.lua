local addonName, ns = ...

-- The first load on an account says what Chat Scan does and where to start, with a link to the window. One
-- help tip at Keywords shows the first step until the player closes it or adds a rule.

-- Blizzard reserves the addon link type for addons and hands every click on one to all of them through one
-- EventRegistry event (Shared/ItemRefHandlersShared.lua). Gold is the colour of Blizzard's own action links in chat.
local LINK = LinkTypes.AddOn .. ":" .. addonName

local function SurfaceLink(label)
    return NORMAL_FONT_COLOR:WrapTextInColorCode(LinkUtil.FormatLink(LinkTypes.AddOn, "[" .. label .. "]", addonName))
end

function ns.PrintWelcome()
    ns.Print("Forwards chat lines that match your keywords to the chat tabs you pick. Open the "
        .. SurfaceLink(ns.title) .. " window or type /cs to add your first keyword.")
end

-- The help tip is an own HelpTipTemplate frame, never HelpTip:Show, which takes a frame from Blizzard's shared
-- pool and taints the help tips Blizzard shows later. It points from the window's left, where it covers no
-- content.
local tip, tipTarget, tipRegion
local tipInfo = {
    text = "Type a keyword here and press Enter to start scanning.",
    buttonStyle = HelpTip.ButtonStyle.Close,
    targetPoint = HelpTip.Point.LeftEdgeCenter,
    onAcknowledgeCallback = function() ns.Store.Account().tipSeen = true end,
}

-- Reset comes before every Init: only Blizzard's pool resets a tip, and Init leaves acknowledged set
-- (Blizzard_SharedXML/HelpTip.lua), so a tip closed once and brought back by /cs intro would count as seen
-- when it merely hides with the window. Close hands a hidden tip to HelpTip:Release, which ignores a frame its
-- pool does not own, so the own frame stays out of the pool.
local function ShowTip()
    if not tipTarget or ns.Store.Account().tipSeen or (tip and tip:IsShown()) then return end
    if not tip then
        tip = CreateFrame("Frame", nil, tipTarget, "HelpTipTemplate")
        tip.width = HelpTip.width
        tip:SetWidth(tip.width)
    end
    tip:Reset()
    tip:Init(tipTarget, tipInfo, tipRegion)
    tip:Show()
end

-- The window calls this once it is built: the tip hangs off target and points at relativeRegion, the
-- Keywords rows.
function ns.AttachKeywordTip(target, relativeRegion)
    tipTarget, tipRegion = target, relativeRegion
    target:HookScript("OnShow", ShowTip)
    if target:IsVisible() then ShowTip() end
end

-- The player added a rule: the tip goes for good, shown or not.
function ns.RetireKeywordTip()
    if tip and tip.info then tip:Acknowledge() else ns.Store.Account().tipSeen = true end
end

-- /cs intro: the welcome line now, and the tip again, at once if the window is open, else the next time it opens.
function ns.ReplayIntro()
    ns.Store.Account().tipSeen = nil
    ns.PrintWelcome()
    if tipTarget and tipTarget:IsVisible() then ShowTip() end
end

-- Another addon's link may come from a line kept from restricted content, so it is checked before the comparison.
EventRegistry:RegisterCallback("SetItemRef", function(_, link)
    if ns.CanAccess(link) and link == LINK then ns.ShowPanel() end
end, ns)
