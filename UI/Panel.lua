local _, ns = ...

local Scanner = ns.Scanner
local Store = ns.Store

-- Spacing roles and component sizes, all on the 4 px grid.
local GAP = 8
local PADDING = 16
local SECTION = 24
local ROW = 24
local HEADING = 16

-- The right margin a scroll frame leaves for its bar: SCROLL_FRAME_SCROLL_BAR_OFFSET_LEFT 6, the
-- MinimalScrollBar 8 and a gap of 8, rounded up to the grid.
local SCROLL_GUTTER = 24

-- InputBoxTemplate draws its left cap 5 px outside the box (InputBoxTemplates.xml:49).
local INPUT_ART = 5

-- WowStyle1DropdownTemplate: 25 tall, its art 8 px past each side and 9 px below the button
-- (Blizzard_Menu/Mainline/MenuTemplates.xml:4-10).
local DROPDOWN_ART = 8
local DROPDOWN_HEIGHT = 25
local DROPDOWN_ART_BELOW = 9

-- Two equal columns side by side, one gap apart, inside the template's own inset margins. A column
-- leaves 288px of content beside its scroll gutter: room for the 12px helper lines and for two chat
-- type blocks of 144px. The outer width carries Blizzard's 4/-6 inset offsets, so it is 674.
local COLUMN_W = 328
local PANEL_W = PANEL_INSET_LEFT_OFFSET + 2 * COLUMN_W + GAP - PANEL_INSET_RIGHT_OFFSET

-- A fixed height: the right column fits up to three output tabs without scrolling, and longer lists
-- scroll inside their column instead of growing the window. The window has no attic, because the
-- status sits in the button bar.
local PANEL_H = 548

-- Each column's scroll area sits one padding in from its top, left and bottom and leaves the scroll
-- bar's gutter free on the right, so the bar stays inside the inset.
local CONTENT_W = COLUMN_W - PADDING - SCROLL_GUTTER

-- Two chat type blocks share a row of the Chat Types section.
local BLOCK_W = CONTENT_W / 2

local panel

-- Rounds a length derived from text up to the 4 px grid.
local function Snap(length)
    return math.ceil(length / 4) * 4
end

-- Text in a font role: GameFontNormal (heading, gold), GameFontHighlight (body, white), GameFontDisable
-- (muted, grey).
local function CreateText(parent, fontObject, layer)
    local text = parent:CreateFontString(nil, layer or "ARTWORK")
    text:SetFontObject(fontObject or GameFontHighlight)
    text:SetJustifyH("LEFT")
    return text
end

-- A GameTooltip owned by the hovered frame, filled with Blizzard's GameTooltip_* line helpers. Hooked, so a
-- template's own OnEnter and OnLeave stay, as on UIPanelButtonTemplate, InputBoxInstructionsTemplate and a
-- dropdown.
local function HookTooltip(frame, fill, anchor)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        fill(GameTooltip, self)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

-- A title and one normal help line, the shape of every control tooltip in the set.
local function SimpleTooltip(title, text)
    return function(tooltip)
        GameTooltip_SetTitle(tooltip, title)
        GameTooltip_AddNormalLine(tooltip, text)
    end
end

-- A content button one row (24) tall. Without a width it fits its label the way UIPanelButtonTemplate's FitToText
-- does (text plus 40, SecureUIPanelTemplates.xml:42), at least 64, rounded up to 8 so neighbours share widths.
local function CreateButton(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(label)
    width = width or math.max(64, math.ceil((button:GetTextWidth() + 40) / 8) * 8)
    button:SetSize(width, 24)
    return button
end

-- The label joins the hit rect, so a click on it toggles the box. Pooled checkboxes take a new label
-- on every render, so the hit rect follows it.
local function SetCheckboxLabel(checkbox, label)
    checkbox.Text:SetText(label)
    checkbox:SetHitRectInsets(0, -(4 + checkbox.Text:GetStringWidth()), 0, 0)
end

-- CheckboxWithLabelTemplate: the minimal art Blizzard's Settings use, at the 24 px AddonList gives it
-- (Blizzard_AddOnList/AddonList.xml:73-74).
local function CreateCheckbox(parent, label)
    local checkbox = CreateFrame("CheckButton", nil, parent, "CheckboxWithLabelTemplate")
    checkbox:SetSize(24, 24)
    checkbox.Text:SetFontObject(GameFontHighlight)
    checkbox.Text:ClearAllPoints()
    checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    SetCheckboxLabel(checkbox, label or "")
    return checkbox
end

-- InputBoxInstructionsTemplate: an edit box plus Blizzard's grey hint, so an empty field says what it takes.
-- The hint moves to the muted font where typed text starts, keeping the template's grey.
local function CreateHintBox(parent, hint, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxInstructionsTemplate")
    box:SetSize(width or 160, 20)
    box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlight)
    local r, g, b = box.Instructions:GetTextColor()
    box.Instructions:SetFontObject(GameFontDisable)
    box.Instructions:SetTextColor(r, g, b)
    box.Instructions:ClearAllPoints()
    box.Instructions:SetAllPoints()
    box.Instructions:SetText(hint)
    return box
end

-- Blizzard's menu dropdown, filled with SetupMenu. Its frame sits on the column edge and its art hangs 8 px past each
-- side, as the Group Finder lines it up under an edit box (LFGList.xml:1794-1795).
local function CreateDropdown(parent, width, name)
    local dropdown = CreateFrame("DropdownButton", name, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width or 160)
    return dropdown
end

-- The close button Blizzard uses for one row of a list, sized to the row.
local function CreateRemoveButton(parent)
    local button = CreateFrame("Button", nil, parent, "UIPanelCloseButtonNoScripts")
    button:SetSize(24, 24)
    return button
end

-- An inset's border on the stone without its marble tile, as the Auction House category list
-- (Blizzard_AuctionHouseCategoriesList.xml:60). For the status box in the button bar.
local function CreateInset(parent)
    local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    inset.Bg:Hide()
    return inset
end

-- The gold Settings divider stood on end, to split the brown panel into columns. SetClampedTextureRotation turns it
-- a quarter and swaps its size (Blizzard_SharedXMLBase/TextureUtil.lua). The caller anchors its top and bottom.
local function CreateVerticalDivider(parent)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    SetClampedTextureRotation(divider, 90)
    return divider
end

-- A window section, the way Blizzard's Settings panel heads one: a gold heading, its divider a tight step under it
-- (Blizzard_SettingsList.xml, AddonList.xml), the body a tight step under that. The caller sets the height to
-- SECTION_BODY_TOP plus the body's height.
local SECTION_DIVIDER_TOP = 16
local SECTION_BODY_TOP = 24
local function CreateSection(parent, title)
    local section = CreateFrame("Frame", nil, parent)
    local heading = CreateText(section, GameFontNormal)
    heading:SetPoint("TOPLEFT")
    heading:SetPoint("TOPRIGHT")
    heading:SetText(title)
    local divider = section:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOPLEFT", 0, -SECTION_DIVIDER_TOP)
    divider:SetPoint("TOPRIGHT", 0, -SECTION_DIVIDER_TOP)
    section.body = CreateFrame("Frame", nil, section)
    section.body:SetPoint("TOPLEFT", 0, -SECTION_BODY_TOP)
    section.body:SetPoint("BOTTOMRIGHT")
    return section
end

-- A ScrollFrameTemplate with its scroll child. Leave the 24 px gutter free on its right for the bar.
local function CreateScroll(parent, name)
    local scroll = CreateFrame("ScrollFrame", name, parent, "ScrollFrameTemplate")
    scroll.content = CreateFrame("Frame", nil, scroll)
    scroll.content:SetSize(1, 1)
    scroll:SetScrollChild(scroll.content)
    return scroll
end

-- The collections panel's ornaments, which a tool window leaves out.
local BACKGROUND_CORNERS = { "BGCornerTopLeft", "BGCornerTopRight", "BGCornerBottomLeft", "BGCornerBottomRight" }

-- Restores a saved position, or centres the frame.
local function RestorePosition(frame, position)
    frame:ClearAllPoints()
    if position and position.point then
        frame:SetPoint(position.point, UIParent, position.relPoint or position.point, position.x or 0, position.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

-- Windows and dialogs: toplevel, clamped, dragged with the left button, closed by Escape through UISpecialFrames,
-- never UIPanelWindows, so they never drive Blizzard's panel layout.
local function MakeMovable(frame, name, strata, position)
    frame:SetFrameStrata(strata)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if position then
            local point, _, relPoint, x, y = self:GetPoint(1)
            position.point, position.relPoint, position.x, position.y = point, relPoint, x, y
        end
    end)
    RestorePosition(frame, position)
    frame:Hide()
    tinsert(UISpecialFrames, name)
end

-- A tool window on ButtonFrameTemplate: portrait, title, close button, inset, attic and button bar come from the
-- template. The wardrobe's brown panel (CollectionsBackgroundTemplate, Mainline/SharedCollectionTemplates.xml) takes
-- the inset's place without its corner ornaments; Inset stays the content parent and draws nothing.
local function CreateWindow(name, title, icon, width, height, position)
    local frame = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
    frame:SetSize(width, height)
    frame.Inset.Bg:Hide()
    frame.Inset.NineSlice:Hide()
    local background = CreateFrame("Frame", nil, frame, "CollectionsBackgroundTemplate")
    background:ClearAllPoints()
    background:SetAllPoints(frame.Inset)
    for _, corner in ipairs(BACKGROUND_CORNERS) do background[corner]:Hide() end
    frame.Background = background
    frame:SetTitle(title)
    frame:SetPortraitToAsset(icon)

    -- The close button goes through HideUIPanel, which refuses insecure callers in combat. UIPanelCloseButton_OnClick
    -- asks onCloseCallback first, so the window hides itself instead.
    frame.onCloseCallback = function()
        frame:Hide()
        return false
    end

    MakeMovable(frame, name, "HIGH", position)
    return frame
end

-- A MagicButtonTemplate bar button, 128 wide: the first takes the bottom-right corner, later ones chain leftwards.
-- MagicButton_OnLoad runs after the anchor so Blizzard applies its corner and neighbour spacing.
local function AddBarButton(window, label, onClick, width)
    local button = CreateFrame("Button", nil, window, "MagicButtonTemplate")
    button:SetWidth(width or 128)
    window.barButtons = window.barButtons or {}
    local previous = window.barButtons[#window.barButtons]
    if previous then
        button:SetPoint("RIGHT", previous, "LEFT")
    else
        button:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT")
    end
    MagicButton_OnLoad(button)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    window.barButtons[#window.barButtons + 1] = button
    return button
end

-- A checkbox list with a pool, so channel joins and tab changes never leak frames. Each checkbox
-- explains itself with the entry's name and the list's help line.
local function createCheckList(container, emptyText, helpText)
    local list = { active = {}, pool = {} }

    -- The empty state fills the first row in muted text, so an empty list keeps the height of one
    -- entry and says what fills it.
    local empty = CreateText(container, GameFontDisable)
    empty:SetPoint("TOPLEFT")
    empty:SetPoint("TOPRIGHT")
    empty:SetHeight(ROW)
    empty:SetJustifyH("CENTER")
    empty:SetText(emptyText)

    local function fillTooltip(tooltip, checkbox)
        GameTooltip_SetTitle(tooltip, checkbox.Text:GetText())
        GameTooltip_AddNormalLine(tooltip, helpText)
    end

    local function acquire()
        local checkbox = table.remove(list.pool)
        if not checkbox then
            checkbox = CreateCheckbox(container)
            HookTooltip(checkbox, fillTooltip)
        end
        return checkbox
    end

    -- Renders entries top-down and returns the height used.
    function list:Render(entries, isChecked, onClick)
        for _, checkbox in ipairs(self.active) do
            checkbox:Hide()
            self.pool[#self.pool + 1] = checkbox
        end
        wipe(self.active)
        empty:SetShown(#entries == 0)

        for i, entry in ipairs(entries) do
            local checkbox = acquire()
            checkbox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * ROW)
            SetCheckboxLabel(checkbox, entry.name)
            checkbox:SetChecked(isChecked(entry))
            checkbox:SetScript("OnClick", function(self) onClick(entry, self:GetChecked()) end)
            checkbox:Show()
            self.active[i] = checkbox
        end
        return math.max(#entries, 1) * ROW
    end

    return list
end

-- Community channels are named Community:<clubId>:<streamId>, which Blizzard's chat shows as the
-- community and stream name; every other channel name passes through unchanged. Battle.net
-- community text arrives as protected K-strings matching cannot read, so those channels get no
-- entry. The club type is secret in chat lockdown and missing before the club loads, so a community
-- channel stays out of the list until it can be told apart, as its streams do.
local function channelEntry(name)
    local entry = { name = name, key = ns.channelKey(name) }
    local clubId = ChatFrameUtil.GetCommunityAndStreamFromChannel(name)
    if not clubId then return entry end
    local club = not C_ChatInfo.InChatMessagingLockdown() and C_Club.GetClubInfo(clubId)
    if not club or club.clubType == Enum.ClubType.BattleNet then return nil end
    entry.name = ChatFrameUtil.ResolveChannelName(name)
    return entry
end

-- Every channel the player is in, community channels included. The key stays the raw channel name,
-- so a renamed community keeps its tick.
local function channelEntries()
    local list = { GetChannelList() }
    local entries, seen = {}, {}
    for i = 1, #list, 3 do
        local entry = channelEntry(list[i + 1])
        if entry and not seen[entry.key] then
            seen[entry.key] = true
            entries[#entries + 1] = entry
        end
    end
    return entries
end

-- Subscribed community streams that are in no chat tab, so they reach the scan only as community
-- messages; a stream in a chat tab is a chat channel and arrives through channelEntries. Guild
-- streams are Guild and Officer chat under Chat Types, and Battle.net communities are skipped as in
-- channelEntry. The key is the stream's channel name, so a stream keeps its tick when it moves into
-- or out of a chat tab. Callers skip this in chat lockdown, where club and stream data are secret;
-- before the clubs load the C_Club calls return nothing.
local function streamEntries()
    local entries = {}
    for _, club in ipairs(C_Club.GetSubscribedClubs() or {}) do
        if club.clubType ~= Enum.ClubType.Guild and club.clubType ~= Enum.ClubType.BattleNet then
            for _, stream in ipairs(C_Club.GetStreams(club.clubId) or {}) do
                local clubId, streamId = club.clubId, stream.streamId
                local localID = ChatFrameUtil.GetCommunitiesChannelLocalID(clubId, streamId)
                if C_Club.IsSubscribedToStream(clubId, streamId) and not (localID and localID ~= 0) then
                    entries[#entries + 1] = {
                        name = ChatFrameUtil.GetCommunityAndStreamName(clubId, streamId),
                        key = ns.channelKey(ChatFrameUtil.GetCommunitiesChannelName(clubId, streamId)),
                    }
                end
            end
        end
    end
    return entries
end

-- The chat type ticks, one titled block per CHAT_GROUPS group, two blocks side by side. A block has
-- a white heading line one gap above its ticks, and block rows sit one section break apart, so each
-- title reads as part of its own group. Returns the checkboxes by key and the height used.
local function createChatTypeGrid(content, onClick)
    local checks, top, rowH = {}, 0, 0
    for i, group in ipairs(ns.CHAT_GROUPS) do
        local column = (i - 1) % 2
        if column == 0 and i > 1 then
            top = top + rowH + SECTION
            rowH = 0
        end
        local x = column * BLOCK_W

        local title = CreateText(content, GameFontHighlight)
        title:SetHeight(HEADING)
        title:SetPoint("TOPLEFT", x, -top)
        title:SetText(group.title)
        local ticksTop = top + HEADING + GAP

        for j, chatType in ipairs(group.types) do
            local checkbox = CreateCheckbox(content, chatType.label)
            checkbox:SetPoint("TOPLEFT", x, -(ticksTop + (j - 1) * ROW))
            checkbox:SetScript("OnClick", function(self) onClick(chatType.key, self:GetChecked()) end)
            HookTooltip(checkbox, SimpleTooltip(chatType.label, "Scan this chat for your keywords."))
            checks[chatType.key] = checkbox
        end
        rowH = math.max(rowH, ticksTop - top + #group.types * ROW)
    end
    return checks, top + rowH
end

-- A window section whose body holds the section's own content, below an optional muted helper
-- line. The helper's two anchors give it the width it needs to measure its wrap.
local function createSection(column, title, helperText)
    local section = CreateSection(column, title)
    section.content = CreateFrame("Frame", nil, section.body)

    local helper
    if helperText then
        helper = CreateText(section.body, GameFontDisable)
        helper:SetPoint("TOPLEFT")
        helper:SetPoint("TOPRIGHT")
        helper:SetText(helperText)
    end

    -- The helper's wrapped height is snapped, so the content starts on the grid and a long helper
    -- line never overlaps it.
    function section:Layout(contentHeight)
        local offset = helper and Snap(helper:GetStringHeight()) + GAP or 0
        self.content:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -offset)
        self.content:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, -offset)
        self.content:SetHeight(contentHeight)
        self:SetHeight(SECTION_BODY_TOP + offset + contentHeight)
    end

    return section
end

-- One scroll area per column, placed like QuestieGuide's list. ScrollFrameTemplate brings
-- MinimalScrollBar and its wheel handler; the ticks, boxes and buttons inside never take the wheel,
-- so it scrolls over the content too. The bar hides while everything fits.
local function createColumnScroll(column)
    local scroll = CreateScroll(column)
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    scroll:SetPoint("TOPLEFT", PADDING, -PADDING)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLL_GUTTER, PADDING)
    scroll.content:SetWidth(CONTENT_W)
    return scroll
end

-- Chains sections down a scroll child from its top, one section break apart.
local function stackSections(sections)
    for i, section in ipairs(sections) do
        if i == 1 then
            section:SetPoint("TOPLEFT")
            section:SetPoint("TOPRIGHT")
        else
            section:SetPoint("TOPLEFT", sections[i - 1], "BOTTOMLEFT", 0, -SECTION)
            section:SetPoint("TOPRIGHT", sections[i - 1], "BOTTOMRIGHT", 0, -SECTION)
        end
    end
end

-- Sizes the scroll child to its laid-out sections, and pulls the offset back into range when a
-- list got shorter.
local function fitScroll(scroll, sections)
    local height = (#sections - 1) * SECTION
    for _, section in ipairs(sections) do
        height = height + section:GetHeight()
    end
    scroll.content:SetHeight(height)
    scroll:UpdateScrollChildRect()
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
end

-- Keyword rows mirror the slash command: one row is an OR group, commas inside it are AND terms.
-- The trailing row is always empty and ready for the next rule; its hint doubles as the empty state.
local KeywordRows = { active = {}, pool = {} }

local function persistKeywords()
    local keywords = {}
    for _, row in ipairs(KeywordRows.active) do
        if row.saved then keywords[#keywords + 1] = row.saved end
    end
    Store.Get().keywords = keywords
    Scanner.ReloadKeywords()
end

local function deleteRow(row)
    tDeleteItem(KeywordRows.active, row)
    row.saved = nil
    row:Hide()
    KeywordRows.pool[#KeywordRows.pool + 1] = row
    persistKeywords()
    panel:RefreshKeywords()
end

-- The same rules as /cs <keyword>: a rule needs a word, a rule saved in any case is not stored
-- twice, and adding one starts the scan. A refused rule keeps its text so it can be fixed.
local function commitRow(row)
    local typed = ns.trim(row.editBox:GetText())

    -- Enter on an empty row hands the keyboard back, and on a cleared rule removes it.
    if typed == "" then
        if row.saved then deleteRow(row) else row.editBox:ClearFocus() end
        return
    end
    if not ns.hasTerm(typed) then
        ns.Print(ns.NO_TERM)
        return
    end
    local lower = typed:lower()
    for _, other in ipairs(KeywordRows.active) do
        if other ~= row and other.saved and other.saved:lower() == lower then
            ns.Print("Already tracking: " .. other.saved .. ".")
            return
        end
    end
    local isNew = row.saved == nil
    row.saved = typed
    row.editBox:SetText(typed)
    row.editBox:ClearFocus()
    row:UpdateState()
    persistKeywords()
    panel:RefreshKeywords()
    ns.RetireKeywordTip()

    -- The caret moves on to the fresh trailing row, so rules can be typed one after another.
    if isNew then KeywordRows.active[#KeywordRows.active].editBox:SetFocus() end
    if not Scanner.scanning then Scanner.Start() end
end

local RULE_TOOLTIP = SimpleTooltip("Rule", "Each word matches the start of a word and ignores case, so lf finds LFG. "
    .. "Commas need every word, so lf, tank needs both.")

-- An empty row shows no button, a typed row shows Add, a saved and unchanged row shows remove.
local function createKeywordRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW)

    local editBox = CreateHintBox(row, "Type a rule, such as wts thunderfury")
    editBox:SetMaxLetters(256)
    HookTooltip(editBox, RULE_TOOLTIP)
    row.editBox = editBox

    local addBtn = CreateButton(row, ADD)
    addBtn:SetPoint("RIGHT")
    HookTooltip(addBtn, SimpleTooltip(ADD, "Adds this rule and starts the scan."))

    local removeBtn = CreateRemoveButton(row)
    removeBtn:SetPoint("RIGHT")
    HookTooltip(removeBtn, SimpleTooltip(REMOVE, "Removes this rule."))

    function row:UpdateState()
        local typed = ns.trim(editBox:GetText())
        local isSaved = self.saved ~= nil and typed == self.saved
        local isTyped = typed ~= "" and not isSaved
        addBtn:SetShown(isTyped)
        removeBtn:SetShown(isSaved)

        -- The box sits in by the template's left cap, so its visible border lines up with the column.
        editBox:ClearAllPoints()
        editBox:SetPoint("LEFT", INPUT_ART, 0)
        if isSaved then
            editBox:SetPoint("RIGHT", removeBtn, "LEFT", -GAP, 0)
        elseif isTyped then
            editBox:SetPoint("RIGHT", addBtn, "LEFT", -GAP, 0)
        else
            editBox:SetPoint("RIGHT")
        end
    end

    -- InputBoxInstructionsTemplate shows its hint from its own OnTextChanged, so this one is hooked.
    editBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then row:UpdateState() end
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(row.saved or "")
        self:ClearFocus()
        row:UpdateState()
    end)
    editBox:SetScript("OnEnterPressed", function() commitRow(row) end)
    addBtn:SetScript("OnClick", function() commitRow(row) end)
    removeBtn:SetScript("OnClick", function() deleteRow(row) end)

    return row
end

local function addKeywordRow(parent, keyword)
    local row = table.remove(KeywordRows.pool) or createKeywordRow(parent)
    row.saved = keyword
    row.editBox:SetText(keyword or "")
    row.editBox:SetCursorPosition(0)
    row:UpdateState()
    row:Show()
    KeywordRows.active[#KeywordRows.active + 1] = row
end

-- Keeps one empty row at the end, lays rows out top-down one gap apart and returns the height used.
local function layoutKeywordRows(parent)
    local last = KeywordRows.active[#KeywordRows.active]
    if not last or last.saved then addKeywordRow(parent, nil) end

    local pitch = ROW + GAP
    for i, row in ipairs(KeywordRows.active) do
        local y = -(i - 1) * pitch
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    end
    return #KeywordRows.active * pitch - GAP
end

local function populateKeywordRows(parent)
    for i = #KeywordRows.active, 1, -1 do
        local row = KeywordRows.active[i]
        row:Hide()
        KeywordRows.pool[#KeywordRows.pool + 1] = row
        KeywordRows.active[i] = nil
    end
    for _, keyword in ipairs(Store.Get().keywords) do
        addKeywordRow(parent, keyword)
    end
end

-- The template's Inset becomes the left column and a plain frame the right one, one gap apart on
-- Blizzard's own inset offsets. The window's brown panel spans both, and the gold divider stood on end
-- splits them in the middle of the gap, as high as the padded content.
local function createColumns(frame)
    local left = frame.Inset
    left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", PANEL_INSET_LEFT_OFFSET + COLUMN_W, PANEL_INSET_BOTTOM_BUTTON_OFFSET)

    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", GAP, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_BUTTON_OFFSET)

    local background = frame.Background
    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", left)
    background:SetPoint("BOTTOMRIGHT", right)
    local divider = CreateVerticalDivider(background)
    divider:SetPoint("TOP", left, "TOPRIGHT", GAP / 2, -PADDING)
    divider:SetPoint("BOTTOM", left, "BOTTOMRIGHT", GAP / 2, PADDING)
    return left, right
end

-- A pick previews its sound, so no Test button is needed. None turns the alert off.
local function addSoundRadio(root, name, id)
    root:CreateRadio(name,
        function() return Store.Get().soundId == id end,
        function()
            Store.Get().soundId = id
            if id ~= ns.NO_SOUND then PlaySound(id, ns.SOUND_CHANNEL) end
        end)
end

-- One sound picker. Its frame sits on the column edge and its art hangs past both sides, so it is
-- indented by that much to stay inside the column.
local function createSoundDropdown(content)
    local dropdown = CreateDropdown(content)
    dropdown:SetPoint("TOPLEFT", DROPDOWN_ART, 0)
    dropdown:SetupMenu(function(_, root)
        addSoundRadio(root, NONE, ns.NO_SOUND)
        for _, sound in ipairs(ns.SOUNDS) do addSoundRadio(root, sound.name, sound.id) end
    end)
    HookTooltip(dropdown, SimpleTooltip(SOUND,
        "Plays when a line is forwarded, at most once every 3 seconds, even with sound effects off. Pick None for silence."))
    return dropdown
end

-- The live status sits in an inset that fills the button bar left of the start button, so the state
-- reads next to the control that changes it. The inset takes the bar's own corner offset and the
-- button's height.
local function createStatus(frame, startBtn)
    local box = CreateInset(frame)
    box:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_BOTTOM_OFFSET)
    box:SetPoint("TOPRIGHT", startBtn, "TOPLEFT", -GAP, 0)

    local status = CreateText(box, GameFontHighlight)
    status:SetPoint("LEFT", GAP, 0)
    status:SetPoint("RIGHT", -GAP, 0)
    status:SetWordWrap(false)
    return status
end

-- On first use a fresh character has nothing ticked, so the channels joined right now are ticked.
-- Channels can still be joining at login and community channels stay hidden in chat lockdown, so
-- the seed waits until there is a channel and lockdown is over. /cs <rule> calls it too.
function ns.SeedChannels()
    local store = Store.Get()
    if store.channelsSeeded or C_ChatInfo.InChatMessagingLockdown() then return end
    local entries = channelEntries()
    if #entries == 0 then return end
    store.channelsSeeded = true
    if next(store.inputChannels) then return end
    for _, entry in ipairs(entries) do store.inputChannels[entry.key] = true end
end

-- Events that change the channel or output tab lists while the window is open.
local LIST_EVENTS = {
    "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL_NOTICE", "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS",
    "CLUB_ADDED", "CLUB_REMOVED", "CLUB_UPDATED", "CLUB_STREAMS_LOADED", "CLUB_STREAM_ADDED",
    "CLUB_STREAM_REMOVED", "CLUB_STREAM_UPDATED", "CLUB_STREAM_SUBSCRIBED", "CLUB_STREAM_UNSUBSCRIBED",
}

local function buildPanel()
    local frame = CreateWindow("ChatScanFrame", ns.title, ns.ICON, PANEL_W, PANEL_H, Store.Window())
    ButtonFrameTemplate_HideAttic(frame)
    local left, right = createColumns(frame)
    local leftScroll, rightScroll = createColumnScroll(left), createColumnScroll(right)

    local keywordsSection = createSection(leftScroll.content, "Keywords",
        "One rule per row. Commas require every word.")
    local channelsSection = createSection(leftScroll.content, CHANNELS)
    local chatTypesSection = createSection(rightScroll.content, "Chat Types")
    local outputsSection = createSection(rightScroll.content, "Output Tabs",
        "None picked: your main chat tab.")
    local soundSection = createSection(rightScroll.content, SOUND)
    local leftSections = { keywordsSection, channelsSection }
    local rightSections = { chatTypesSection, outputsSection, soundSection }
    stackSections(leftSections)
    stackSections(rightSections)

    local channelList = createCheckList(channelsSection.content, "Not in any channel. Type /join and a name to join one.",
        "Scan this channel for your keywords.")
    local outputList = createCheckList(outputsSection.content, "No chat tabs open.",
        "Matches show in this chat tab.")
    local chatChecks, chatTypesH = createChatTypeGrid(chatTypesSection.content, function(key, checked)
        Store.Get().chatTypes[key] = checked or nil
        frame:RefreshStatus()
    end)
    local soundDropdown = createSoundDropdown(soundSection.content)

    -- The dropdown keeps the template's own height in a grid slot that also holds its art below.
    local soundH = Snap(DROPDOWN_HEIGHT + DROPDOWN_ART_BELOW)

    -- The primary action takes the button bar's bottom-right corner, the status the rest of the bar.
    local startBtn = AddBarButton(frame, START, Scanner.Toggle)
    HookTooltip(startBtn, function(tooltip)
        GameTooltip_SetTitle(tooltip, Scanner.scanning and "Stop" or START)
        GameTooltip_AddNormalLine(tooltip, Scanner.scanning and "Stops forwarding matches until you start again."
            or "Scans the ticked channels and chat types for your rules. The scan resumes after login.")
    end)
    local status = createStatus(frame, startBtn)

    -- The button label and the status line show whether a scan runs.
    function frame:RefreshStatus()
        local count = ns.countLabel(Scanner.matchCount, "match", "matches")
        if Scanner.scanning then
            startBtn:SetText("Stop")
            -- A running scan can be unable to match while the client withholds chat text, or once
            -- every keyword or source is gone.
            if Scanner.chatLocked then
                status:SetText(WARNING_FONT_COLOR:WrapTextInColorCode("Chat locked") .. ", matching paused")
            elseif not Scanner.CanMatch() then
                status:SetText(WARNING_FONT_COLOR:WrapTextInColorCode("Nothing to match") .. ", add a keyword and tick a channel or chat type")
            else
                status:SetText(GREEN_FONT_COLOR:WrapTextInColorCode("Scanning") .. ", " .. count)
            end
        else
            startBtn:SetText(START)
            if Scanner.matchCount > 0 then
                status:SetText(GRAY_FONT_COLOR:WrapTextInColorCode("Stopped") .. ", " .. count .. " this session")
            elseif #Store.Get().keywords == 0 then
                status:SetText(GRAY_FONT_COLOR:WrapTextInColorCode("Not scanning") .. ", add a keyword to start")
            else
                status:SetText(GRAY_FONT_COLOR:WrapTextInColorCode("Not scanning"))
            end
        end
    end

    local channelsH, keywordsH, outputsH = ROW, ROW, ROW

    -- The window keeps its height; each column's scroll child follows its re-rendered lists.
    function frame:LayoutColumns()
        keywordsSection:Layout(keywordsH)
        channelsSection:Layout(channelsH)
        chatTypesSection:Layout(chatTypesH)
        outputsSection:Layout(outputsH)
        soundSection:Layout(soundH)
        fitScroll(leftScroll, leftSections)
        fitScroll(rightScroll, rightSections)
    end

    -- Joined channels, then community streams outside every chat tab, in one list. Both share the
    -- channel-name key, so a stream keeps its tick when it joins or leaves a chat tab. Stream data
    -- is secret in chat lockdown, so streams drop out of the list until it ends.
    function frame:RefreshChannels()
        local channels = Store.Get().inputChannels
        local function isChecked(entry) return channels[entry.key] end
        local function onClick(entry, checked)
            channels[entry.key] = checked or nil
            self:RefreshStatus()
        end
        ns.SeedChannels()
        local entries = channelEntries()
        if not C_ChatInfo.InChatMessagingLockdown() then
            for _, entry in ipairs(streamEntries()) do entries[#entries + 1] = entry end
        end
        channelsH = channelList:Render(entries, isChecked, onClick)
        self:LayoutColumns()
    end

    function frame:RefreshChatTypes()
        local chatTypes = Store.Get().chatTypes
        for key, checkbox in pairs(chatChecks) do checkbox:SetChecked(chatTypes[key]) end
    end

    function frame:RefreshOutputs()
        local outputs = Store.Get().outputs
        outputsH = outputList:Render(Scanner.OutputWindows(),
            function(entry) return outputs[entry.key] end,
            function(entry, checked) outputs[entry.key] = checked or nil end)
        self:LayoutColumns()
    end

    function frame:RefreshKeywords()
        keywordsH = layoutKeywordRows(keywordsSection.content)
        self:LayoutColumns()
    end

    function frame:PopulateKeywords()
        populateKeywordRows(keywordsSection.content)
        self:RefreshKeywords()
    end

    -- The channel and output tab lists stay live while the window is open.
    frame:SetScript("OnShow", function(self)
        soundDropdown:GenerateMenu()
        self:RefreshChannels()
        self:RefreshChatTypes()
        self:RefreshOutputs()
        self:PopulateKeywords()
        self:RefreshStatus()
        FrameUtil.RegisterFrameForEvents(self, LIST_EVENTS)

        -- The helper lines wrap to widths the scroll child's sections only have after their first
        -- layout, so the columns are measured once more a frame later, as QuestieGuide does.
        RunNextFrame(function()
            if self:IsShown() then self:LayoutColumns() end
        end)
    end)
    frame:SetScript("OnHide", function(self)
        self:UnregisterAllEvents()
    end)
    frame:SetScript("OnEvent", function(self)
        self:RefreshChannels()
        self:RefreshOutputs()
    end)

    Scanner.OnChanged(function()
        if frame:IsShown() then frame:RefreshStatus() end
    end)

    -- The tip hangs off the left column, outside the scroll frame that would clip it, and points at
    -- the Keywords rows from the window's left edge.
    ns.AttachKeywordTip(left, keywordsSection.content)

    -- The keyword rows and ns.RefreshPanel reach the panel outside the toggle.
    panel = frame
    return frame
end

-- One window for /cs, the minimap button, the addon menu and the welcome link, built on first use.
function ns.TogglePanel()
    panel = panel or buildPanel()
    panel:SetShown(not panel:IsShown())
end

function ns.ShowPanel()
    panel = panel or buildPanel()
    panel:Show()
end

-- Called after slash commands change keywords, so an open panel mirrors the store.
function ns.RefreshPanel()
    if panel and panel:IsShown() then panel:PopulateKeywords() end
end
