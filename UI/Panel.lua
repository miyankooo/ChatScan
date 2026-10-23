local _, ns = ...

local UI = LibStub("LibNativeUI-1.0")
local Scanner = ns.Scanner
local Store = ns.Store

-- Two equal wells side by side, one gap apart, inside the template's own inset margins. A well
-- leaves 288px of content beside its scroll gutter: room for the 12px helper lines and for two chat
-- type blocks of 144px. The outer width carries Blizzard's 4/-6 inset offsets, so it is 674.
local COLUMN_W = 328
local PANEL_W = PANEL_INSET_LEFT_OFFSET + 2 * COLUMN_W + UI.Space.gap - PANEL_INSET_RIGHT_OFFSET

-- A fixed height: the right well fits up to three output tabs without scrolling, and longer lists
-- scroll inside their well instead of growing the window. The window has no attic, because the status
-- sits in the button bar.
local PANEL_H = 548

-- WowStyle1Dropdown art reaches 9px below the button (Blizzard_Menu/Mainline/MenuTemplates.xml:10).
local DROPDOWN_ART_BELOW = 9

-- Each well's scroll area sits one padding in from its top, left and bottom and leaves the scroll
-- bar's gutter free on the right, so the bar stays inside the inset.
local CONTENT_W = COLUMN_W - UI.Space.padding - UI.ScrollGutter()

-- Two chat type blocks share a row of the Chat Types section.
local BLOCK_W = CONTENT_W / 2

local panel

-- A checkbox list with a pool, so channel joins and tab changes never leak frames.
local function createCheckList(container, emptyText)
    local list = { active = {}, pool = {} }

    -- The empty note fills the first row, so an empty list keeps the height of one entry.
    local empty = UI.CreateText(container, "muted")
    empty:SetPoint("TOPLEFT")
    empty:SetPoint("TOPRIGHT")
    empty:SetHeight(UI.Size.row)
    empty:SetText(emptyText)

    -- Renders entries top-down and returns the height used.
    function list:Render(entries, isChecked, onClick)
        for _, checkbox in ipairs(self.active) do
            checkbox:Hide()
            self.pool[#self.pool + 1] = checkbox
        end
        wipe(self.active)
        empty:SetShown(#entries == 0)

        for i, entry in ipairs(entries) do
            local checkbox = table.remove(self.pool) or UI.CreateCheckbox(container)
            checkbox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * UI.Size.row)
            checkbox:SetLabel(entry.name)
            checkbox:SetChecked(isChecked(entry))
            checkbox:SetScript("OnClick", function(self) onClick(entry, self:GetChecked()) end)
            checkbox:Show()
            self.active[i] = checkbox
        end
        return math.max(#entries, 1) * UI.Size.row
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
            top = top + rowH + UI.Space.section
            rowH = 0
        end
        local x = column * BLOCK_W

        local title = UI.CreateText(content, "body")
        title:SetHeight(UI.Size.heading)
        title:SetPoint("TOPLEFT", x, -top)
        title:SetText(group.title)
        local ticksTop = top + UI.Size.heading + UI.Space.gap

        for j, chatType in ipairs(group.types) do
            local checkbox = UI.CreateCheckbox(content, chatType.label)
            checkbox:SetPoint("TOPLEFT", x, -(ticksTop + (j - 1) * UI.Size.row))
            checkbox:SetScript("OnClick", function(self) onClick(chatType.key, self:GetChecked()) end)
            checks[chatType.key] = checkbox
        end
        rowH = math.max(rowH, ticksTop - top + #group.types * UI.Size.row)
    end
    return checks, top + rowH
end

-- A library section whose body holds the section's own content, below an optional muted helper
-- line. The helper's two anchors give it the width it needs to measure its wrap.
local function createSection(column, title, helperText)
    local section = UI.CreateSection(column, title)
    section.content = CreateFrame("Frame", nil, section.body)

    local helper
    if helperText then
        helper = UI.CreateText(section.body, "muted")
        helper:SetPoint("TOPLEFT")
        helper:SetPoint("TOPRIGHT")
        helper:SetText(helperText)
    end

    -- The helper's wrapped height is snapped, so the content starts on the grid and a long helper
    -- line never overlaps it.
    function section:Layout(contentHeight)
        local offset = helper and UI.Snap(helper:GetStringHeight()) + UI.Space.gap or 0
        self.content:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -offset)
        self.content:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, -offset)
        self.content:SetHeight(contentHeight)
        self:SetBodyHeight(offset + contentHeight)
    end

    return section
end

-- One scroll area per well, placed like QuestieGuide's list. ScrollFrameTemplate brings
-- MinimalScrollBar and its wheel handler; the ticks, boxes and buttons inside never take the wheel,
-- so it scrolls over the content too. The bar hides while everything fits.
local function createWellScroll(well)
    local scroll = UI.CreateScroll(well)
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    scroll:SetPoint("TOPLEFT", UI.Space.padding, -UI.Space.padding)
    scroll:SetPoint("BOTTOMRIGHT", -UI.ScrollGutter(), UI.Space.padding)
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
            UI.StackBelow(section, sections[i - 1])
        end
    end
end

-- Sizes the scroll child to its laid-out sections, and pulls the offset back into range when a
-- list got shorter.
local function fitScroll(scroll, sections)
    local height = (#sections - 1) * UI.Space.section
    for _, section in ipairs(sections) do
        height = height + section:GetHeight()
    end
    scroll.content:SetHeight(height)
    scroll:UpdateScrollChildRect()
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))
end

-- Keyword rows mirror the slash command: one row is an OR group, commas inside it are AND terms.
-- The trailing row is always empty and ready for the next rule.
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
        UI.Print(ns.TITLE, ns.NO_TERM)
        return
    end
    local lower = typed:lower()
    for _, other in ipairs(KeywordRows.active) do
        if other ~= row and other.saved and other.saved:lower() == lower then
            UI.Print(ns.TITLE, "Already tracking: " .. other.saved .. ".")
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

    -- The caret moves on to the fresh trailing row, so rules can be typed one after another.
    if isNew then KeywordRows.active[#KeywordRows.active].editBox:SetFocus() end
    if not Scanner.scanning then Scanner.Start() end
end

-- An empty row shows no button, a typed row shows Add, a saved and unchanged row shows remove.
local function createKeywordRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(UI.Size.row)

    local editBox = UI.CreateEditBox(row)
    editBox:SetMaxLetters(256)
    row.editBox = editBox

    local addBtn = UI.CreateButton(row, ADD)
    addBtn:SetPoint("RIGHT")

    local removeBtn = UI.CreateRemoveButton(row)
    removeBtn:SetPoint("RIGHT")

    function row:UpdateState()
        local typed = ns.trim(editBox:GetText())
        local isSaved = self.saved ~= nil and typed == self.saved
        local isTyped = typed ~= "" and not isSaved
        addBtn:SetShown(isTyped)
        removeBtn:SetShown(isSaved)

        -- The box sits in by the template's left cap, so its visible border lines up with the column.
        editBox:ClearAllPoints()
        editBox:SetPoint("LEFT", UI.Native.inputArt, 0)
        if isSaved then
            editBox:SetPoint("RIGHT", removeBtn, "LEFT", -UI.Space.gap, 0)
        elseif isTyped then
            editBox:SetPoint("RIGHT", addBtn, "LEFT", -UI.Space.gap, 0)
        else
            editBox:SetPoint("RIGHT")
        end
    end

    editBox:SetScript("OnTextChanged", function(_, userInput)
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

    local pitch = UI.Size.row + UI.Space.gap
    for i, row in ipairs(KeywordRows.active) do
        local y = -(i - 1) * pitch
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    end
    return #KeywordRows.active * pitch - UI.Space.gap
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

-- The template's Inset becomes the left well and a second inset the right one, one gap apart and
-- both on Blizzard's own inset offsets.
local function createColumns(frame)
    local left = frame.Inset
    left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", PANEL_INSET_LEFT_OFFSET + COLUMN_W, PANEL_INSET_BOTTOM_BUTTON_OFFSET)

    local right = UI.CreateInset(frame)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", UI.Space.gap, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_BUTTON_OFFSET)
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

-- One sound picker. Its art hangs past both sides, so it is indented by that much.
local function createSoundDropdown(content)
    local dropdown = UI.CreateDropdown(content)
    dropdown:SetPoint("TOPLEFT", UI.Native.dropdownArt, 0)
    dropdown:SetupMenu(function(_, root)
        addSoundRadio(root, NONE, ns.NO_SOUND)
        for _, sound in ipairs(ns.SOUNDS) do addSoundRadio(root, sound.name, sound.id) end
    end)
    return dropdown
end

-- The live status sits in an inset that fills the button bar left of the start button, so the state
-- reads next to the control that changes it. The inset takes the bar's own corner offset and the
-- button's height.
local function createStatus(frame, startBtn)
    local box = UI.CreateInset(frame)
    box:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PANEL_INSET_LEFT_OFFSET, PANEL_INSET_BOTTOM_OFFSET)
    box:SetPoint("TOPRIGHT", startBtn, "TOPLEFT", -UI.Space.gap, 0)

    local status = UI.CreateText(box, "body")
    status:SetPoint("LEFT", UI.Space.gap, 0)
    status:SetPoint("RIGHT", -UI.Space.gap, 0)
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
    local frame = UI.CreateWindow({
        name = "ChatScanFrame", title = ns.TITLE, icon = ns.ICON,
        width = PANEL_W, height = PANEL_H, position = Store.Window(), attic = false,
    })
    local left, right = createColumns(frame)
    local leftScroll, rightScroll = createWellScroll(left), createWellScroll(right)

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

    local channelList = createCheckList(channelsSection.content, "Not in any channel.")
    local outputList = createCheckList(outputsSection.content, "No chat tabs open.")
    local chatChecks, chatTypesH = createChatTypeGrid(chatTypesSection.content, function(key, checked)
        Store.Get().chatTypes[key] = checked or nil
        frame:RefreshStatus()
    end)
    local soundDropdown = createSoundDropdown(soundSection.content)

    -- The dropdown keeps the template's own height in a grid slot that also holds its art below.
    local soundH = UI.Snap(UI.Native.dropdownHeight + DROPDOWN_ART_BELOW)

    -- The primary action takes the button bar's bottom-right corner, the status the rest of the bar.
    local startBtn = UI.AddBarButton(frame, START, Scanner.Toggle)
    local status = createStatus(frame, startBtn)

    -- The button label and the status line show whether a scan runs.
    function frame:RefreshStatus()
        local count = ns.countLabel(Scanner.matchCount, "match", "matches")
        if Scanner.scanning then
            startBtn:SetText("Stop")
            -- A running scan can be unable to match while the client withholds chat text, or once
            -- every keyword or source is gone.
            if Scanner.chatLocked then
                status:SetText(UI.Color.warn:WrapTextInColorCode("Chat locked") .. ", matching paused")
            elseif not Scanner.CanMatch() then
                status:SetText(UI.Color.warn:WrapTextInColorCode("Nothing to match") .. ", add a keyword and tick a channel or chat type")
            else
                status:SetText(UI.Color.good:WrapTextInColorCode("Scanning") .. ", " .. count)
            end
        else
            startBtn:SetText(START)
            if Scanner.matchCount > 0 then
                status:SetText(UI.Color.muted:WrapTextInColorCode("Stopped") .. ", " .. count .. " this session")
            elseif #Store.Get().keywords == 0 then
                status:SetText(UI.Color.muted:WrapTextInColorCode("Not scanning") .. ", add a keyword to start")
            else
                status:SetText(UI.Color.muted:WrapTextInColorCode("Not scanning"))
            end
        end
    end

    local channelsH, keywordsH, outputsH = UI.Size.row, UI.Size.row, UI.Size.row

    -- The window keeps its height; each well's scroll child follows its re-rendered lists.
    function frame:LayoutWells()
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
        self:LayoutWells()
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
        self:LayoutWells()
    end

    function frame:RefreshKeywords()
        keywordsH = layoutKeywordRows(keywordsSection.content)
        self:LayoutWells()
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
        -- layout, so the wells are measured once more a frame later, as QuestieGuide does.
        RunNextFrame(function()
            if self:IsShown() then self:LayoutWells() end
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

    -- The keyword rows and ns.RefreshPanel reach the panel outside the toggle.
    panel = frame
    return frame
end

-- One toggle for /cs, the minimap button and the addon menu; the panel is built on first use.
ns.TogglePanel = UI.CreateToggle(buildPanel)

-- Called after slash commands change keywords, so an open panel mirrors the store.
function ns.RefreshPanel()
    if panel and panel:IsShown() then panel:PopulateKeywords() end
end
