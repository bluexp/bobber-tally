local _, addon = ...
local L = addon.L
local theme = addon.Theme
local colors = theme.colors
local catches, catchesByName, catchesByID = {}, {}, {}
local rows = {}
local visibleRows, rowHeight = 6, 32
local firstRow = 1
local auction = C_AuctionHouse
local auctionOpen = false
local settings, quotes, scan, auctionMessage
local auctionRefresh, auctionStatus

function addon.CreateDragHandle(parent, name, tooltip)
    local handle = CreateFrame("Button", name, parent)
    handle:SetSize(26, 26)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    theme.Fill(handle, "BACKGROUND", colors.control)
    theme.Highlight(handle)
    local function DrawMark(x, y, width, height)
        local mark = handle:CreateTexture(nil, "ARTWORK")
        mark:SetPoint("CENTER", handle, "CENTER", x, y)
        mark:SetSize(width, height)
        mark:SetColorTexture(unpack(colors.gold))
    end
    DrawMark(0, 0, 16, 2)
    DrawMark(0, 0, 2, 16)
    for step = 0, 3 do
        local distance = 10 - step
        local span = 2 + step * 2
        DrawMark(0, distance, span, 1)
        DrawMark(0, -distance, span, 1)
        DrawMark(distance, 0, 1, span)
        DrawMark(-distance, 0, 1, span)
    end
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[tooltip])
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return handle
end

local panel = theme.CreatePanel("WowfFishingCatchList")
local panelWidth, panelHeight, margin = 624, 570, 16
local contentWidth = panelWidth - margin * 2
local tableTop, headerHeight = 214, 28
local totalsTop = tableTop + headerHeight + visibleRows * rowHeight
panel:SetSize(panelWidth, panelHeight)
panel:SetPoint("CENTER", UIParent, "CENTER", -238, 35)
panel:SetMovable(true)
local surface = theme.Surface(panel)

local titleBar = CreateFrame("Frame", "WowfFishingCatchListTitleBar", panel)
titleBar:SetPoint("TOPLEFT", 8, -2)
titleBar:SetPoint("TOPRIGHT", -32, -2)
titleBar:SetHeight(20)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function()
    panel.moving = true
    panel:StartMoving()
end)

local function StopMoving()
    if not panel.moving then return end
    panel:StopMovingOrSizing()
    panel.moving = nil
    panel:SetUserPlaced(false)
    local x, y = panel:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not x or not parentX then return end
    settings.catchPanelPosition = { x = x - parentX, y = y - parentY }
end

titleBar:SetScript("OnDragStop", StopMoving)
panel:SetScript("OnHide", StopMoving)

local function Label(parent, font, x, y, width, alignment, color)
    local label = theme.Label(parent, font, x, y, width, alignment, color)
    label:SetMaxLines(1)
    return label
end

addon.SetLocalizedText(Label(panel, "GameFontHighlight", 16, -4, 390), "无限钓鱼助手 · 渔获统计")

local status = Label(surface, "GameFontHighlight", 16, -37, 343, nil, colors.gold)
local hint = Label(surface, "GameFontHighlightSmall", 355, -38, 253, "RIGHT", colors.muted)
theme.Block(surface, "ARTWORK", 16, -58, contentWidth, 1, colors.divider)

local function SummaryCard(index, title)
    local gap = 8
    local width = (contentWidth - 3 * gap) / 4
    local x = margin + (index - 1) * (width + gap)
    theme.Block(surface, "BORDER", x, -70, width, 59, colors.card)
    addon.SetLocalizedText(Label(surface, "GameFontHighlightSmall", x + 12, -80, width - 24, nil, colors.muted), title)
    return Label(surface, "GameFontNormalLarge", x + 12, -100, width - 24, nil, colors.text)
end

local castCount = SummaryCard(1, "抛竿次数")
local successfulCasts = SummaryCard(2, "有收获的竿数")
local itemCount = SummaryCard(3, "渔获件数")
local activity = SummaryCard(4, "钓鱼用时")

theme.Block(surface, "BORDER", 16, -139, contentWidth, 60, colors.card)
local recent = Label(surface, "GameFontHighlightSmall", 28, -150, 355, nil, colors.text)
local lure = Label(surface, "GameFontHighlightSmall", 383, -150, 213, "RIGHT", colors.muted)
local goalButton = theme.Button(surface, nil, "鱼类目标", 88, 23)
goalButton:SetPoint("TOPLEFT", 28, -169)
local goalProgress = Label(surface, "GameFontHighlightSmall", 126, -176, 318, nil, colors.text)
local goalTrack = theme.Block(surface, "ARTWORK", 457, -179, 139, 6, colors.control)
local goalFill = surface:CreateTexture(nil, "OVERLAY")
goalFill:SetPoint("TOPLEFT", goalTrack, "TOPLEFT")
goalFill:SetHeight(6)
goalFill:SetColorTexture(unpack(colors.gold))
goalFill:Hide()
goalTrack:Hide()

function addon.UpdateLureStatus(seconds)
    lure:SetText(not seconds and "" or seconds == 0 and L["鱼饵已到期。"]
        or L["鱼饵剩余 %s"]:format(("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)))
    lure:SetTextColor(unpack(seconds and seconds <= 30 and colors.gold or colors.muted))
end

function addon.UpdateCatchSummary(state, session)
    status:SetText(state)
    castCount:SetText(session.casts)
    successfulCasts:SetText(session.catches)
    itemCount:SetText(session.count)
    recent:SetText(L["最近渔获 "] .. (session.lastCatch or "—"))
    hint:SetText(settings.fishKey and (L["抛竿 / 收竿  "] .. settings.fishKey) or L["抛竿 / 收竿键未设置"])
end

local columns = {
    { title = "物品", x = 14, width = 231 },
    { title = "数量", x = 250, width = 55, align = "RIGHT" },
    { title = "拍卖行最低单价", x = 324, width = 133 },
    { title = "卖给 NPC", x = 470, width = 108 },
}
local function TableLabel(parent, column, y, font, color)
    return Label(parent, font, column.x, y, column.width, column.align, color)
end

local tableFrame = CreateFrame("Frame", nil, surface)
tableFrame:SetPoint("TOPLEFT", margin, -tableTop)
tableFrame:SetSize(contentWidth, totalsTop - tableTop + 64)
theme.Fill(tableFrame, "BACKGROUND", colors.card)
theme.Block(tableFrame, "BORDER", 0, 0, contentWidth, headerHeight, colors.control)
for _, column in ipairs(columns) do
    addon.SetLocalizedText(TableLabel(tableFrame, column, -8, "GameFontHighlightSmall", colors.gold), column.title)
end

local list = CreateFrame("Frame", nil, tableFrame)
list:SetPoint("TOPLEFT", 0, -headerHeight)
list:SetSize(contentWidth, visibleRows * rowHeight)
list:EnableMouseWheel(true)

for i = 1, visibleRows do
    local row = CreateFrame("Frame", nil, list)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
    row:SetSize(contentWidth, rowHeight)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.045 or 0.015)
    row.hover = theme.Fill(row, "ARTWORK", colors.hover)
    row.hover:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.icon:SetPoint("LEFT", 14, 0)
    row.icon:SetSize(21, 21)
    row.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    row.name = Label(row, "GameFontHighlight", 44, -9, 201, nil, colors.text)
    row.quantity = TableLabel(row, columns[2], -9, "GameFontHighlight", colors.text)
    row.auction = TableLabel(row, columns[3], -3, "GameFontHighlight", colors.text)
    row.quoteTime = TableLabel(row, columns[3], -17, "GameFontHighlightSmall", colors.muted)
    row.vendor = TableLabel(row, columns[4], -9, "GameFontHighlight", colors.text)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.item then return end
        self.hover:Show()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.item.itemID then
            GameTooltip:SetItemByID(self.item.itemID)
        else
            GameTooltip:SetText(self.item.name)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    rows[i] = row
end

local empty = Label(list, "GameFontHighlight", 0, -88, contentWidth, "CENTER", colors.muted)
addon.SetLocalizedText(empty, "本次还没有钓到物品")

local totals = CreateFrame("Frame", nil, tableFrame)
totals:SetPoint("TOPLEFT", 0, -(totalsTop - tableTop))
totals:SetSize(contentWidth, 64)
theme.Fill(totals, "BACKGROUND", colors.control)
theme.Block(totals, "ARTWORK", 0, 0, contentWidth, 1, colors.divider)
addon.SetLocalizedText(TableLabel(totals, columns[1], -10, "GameFontHighlight", colors.gold), "本次合计")
local catchRate = TableLabel(totals, columns[1], -31, "GameFontHighlightSmall", colors.muted)
local totalQuantity = TableLabel(totals, columns[2], -10, "GameFontHighlight", colors.text)
local auctionTotal = TableLabel(totals, columns[3], -10, "GameFontHighlight", colors.text)
local auctionCoverage = TableLabel(totals, columns[3], -28, "GameFontHighlightSmall", colors.muted)
local auctionRate = TableLabel(totals, columns[3], -44, "GameFontHighlightSmall", colors.muted)
local vendorTotal = TableLabel(totals, columns[4], -10, "GameFontHighlight", colors.text)
local vendorCoverage = TableLabel(totals, columns[4], -28, "GameFontHighlightSmall", colors.muted)
local vendorRate = TableLabel(totals, columns[4], -44, "GameFontHighlightSmall", colors.muted)

local function FooterButton(text, width, x, primary)
    local button = theme.Button(surface, nil, text, width, 24, primary)
    button:SetPoint("TOPLEFT", x, -510)
    return button
end

local refresh = FooterButton("更新拍卖价", 110, 16, true)
local catalogButton = FooterButton("鱼类资料", 99, 134)
catalogButton:SetScript("OnClick", function() addon.ToggleFishCatalog() end)
local aboutButton = FooterButton("关于", 52, 241)
aboutButton:SetScript("OnClick", function() addon.ToggleAbout() end)
local endButton = FooterButton("结束本次", 86, 301)
local previous = FooterButton("上页", 44, 435)
local following = FooterButton("下页", 44, 564)
local page = Label(surface, "GameFontHighlightSmall", 480, -517, 83, "CENTER", colors.muted)
local message = Label(surface, "GameFontHighlightSmall", 16, -542, contentWidth, nil, colors.muted)

local function Money(copper)
    if copper == 0 then return "0" .. L["铜"] end
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local remainder = copper % 100
    local text = {}
    if gold > 0 then text[#text + 1] = gold .. L["金"] end
    if silver > 0 then text[#text + 1] = silver .. L["银"] end
    if remainder > 0 then text[#text + 1] = remainder .. L["铜"] end
    return table.concat(text, " ")
end
addon.FormatMoney = Money

local function RefreshTotals()
    local quantity, auctionCount, vendorCount = 0, 0, 0
    local auctionCopper, vendorCopper = 0, 0
    for _, item in ipairs(catches) do
        quantity = quantity + item.quantity
        local quote = item.itemID and quotes[item.itemID]
        if quote then
            auctionCount = auctionCount + item.quantity
            auctionCopper = auctionCopper + quote.copper * item.quantity
        end
        if item.vendorPrice ~= nil then
            vendorCount = vendorCount + item.quantity
            vendorCopper = vendorCopper + item.vendorPrice * item.quantity
        end
    end
    totalQuantity:SetText(quantity)
    auctionTotal:SetText(auctionCount > 0 and Money(auctionCopper) or "—")
    auctionCoverage:SetText(auctionCount < quantity and (L["%d 件未报价"]):format(quantity - auctionCount) or "")
    vendorTotal:SetText(vendorCount > 0 and Money(vendorCopper) or "—")
    vendorCoverage:SetText(vendorCount < quantity and (L["%d 件未知"]):format(quantity - vendorCount) or "")
    local seconds = addon.GetFishingSeconds()
    local minutes = math.floor(seconds / 60)
    local elapsed = ("%d:%02d"):format(minutes, math.floor(seconds) % 60)
    activity:SetText(elapsed)
    catchRate:SetText(seconds >= 60
        and L["%d 竿/小时"]:format(math.floor(settings.fishingSession.catches * 3600 / seconds + 0.5))
        or L["满 1 分钟后显示每小时统计"])
    auctionRate:SetText(seconds >= 60 and auctionCount > 0 and L["%s/小时"]:format(Money(math.floor(auctionCopper * 3600 / seconds))) or "")
    vendorRate:SetText(seconds >= 60 and vendorCount > 0 and L["%s/小时"]:format(Money(math.floor(vendorCopper * 3600 / seconds))) or "")
    local goal = settings.fishingSession.goal
    goalTrack:SetShown(goal ~= nil)
    goalFill:SetShown(goal ~= nil and goal.count > 0)
    if goal then
        goalFill:SetWidth(math.max(1, goalTrack:GetWidth() * math.min(1, goal.count / goal.target)))
        goalProgress:SetText(L["目标：%s %d / %d%s"]:format(C_Item.GetItemInfo(goal.id) or goal.name, goal.count,
            goal.target, goal.count >= goal.target and L[" · 已达成"] or ""))
    else
        goalProgress:SetText(L["在鱼类资料中设置目标"])
    end
end

local function RefreshAuctionControls()
    local enabled = auctionOpen and not scan
    local text
    if scan then
        text = L["查询进度 %d / %d · 已查到 %d 种"]:format(scan.checked, #scan.ids, scan.found)
    elseif auctionMessage then
        text = auctionMessage
    elseif auctionOpen then
        text = next(catchesByID) and L["查询本次渔获的挂单"] or L["查询资料库鱼类和成品"]
    else
        text = L["打开拍卖行后可更新"]
    end
    refresh:SetEnabled(enabled)
    message:SetText(text)
    if auctionRefresh then
        auctionRefresh:SetEnabled(enabled)
        auctionStatus:SetText(text)
    end
end

local function Refresh()
    local total = #catches
    firstRow = math.max(1, math.min(firstRow, math.max(1, total - visibleRows + 1)))
    local lastRow = math.min(firstRow + visibleRows - 1, total)
    empty:SetShown(total == 0)
    for i, row in ipairs(rows) do
        local item = catches[firstRow + i - 1]
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            local quote = item.itemID and quotes[item.itemID]
            local vendor = item.vendorPrice
            row.icon:SetTexture(theme.ItemIcon(item.itemID))
            row.name:SetText(item.name)
            row.quantity:SetText(item.quantity)
            row.auction:SetText(quote and Money(quote.copper) or L["未报价"])
            row.quoteTime:SetText(quote and date("%m-%d %H:%M", quote.time) or "")
            row.vendor:SetText(vendor and (vendor > 0 and Money(vendor) or L["不可出售"]) or "—")
        end
    end
    RefreshTotals()
    previous:SetShown(total > visibleRows)
    following:SetShown(total > visibleRows)
    previous:SetEnabled(firstRow > 1)
    following:SetEnabled(lastRow < total)
    page:SetText(total > 0 and ("%d–%d / %d"):format(firstRow, lastRow, total) or "")
    RefreshAuctionControls()
    addon.RefreshFishCatalog()
end

local function Scroll(delta)
    firstRow = firstRow + delta
    Refresh()
end

list:SetScript("OnMouseWheel", function(_, delta) Scroll(-delta * 3) end)
previous:SetScript("OnClick", function() Scroll(-visibleRows) end)
following:SetScript("OnClick", function() Scroll(visibleRows) end)
panel:SetScript("OnShow", Refresh)
local elapsedSinceRefresh = 0
panel:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceRefresh = elapsedSinceRefresh + elapsed
    if elapsedSinceRefresh < 1 then return end
    elapsedSinceRefresh = 0
    RefreshTotals()
end)

goalButton:SetScript("OnClick", function()
    local goal = settings.fishingSession.goal
    if goal then addon.ToggleFishCatalog(goal.id) else addon.ToggleFishCatalog() end
end)

StaticPopupDialogs["WOWFFISHING_END_SESSION"] = {
    text = "", button1 = "", button2 = "", timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function()
        if not addon.EndFishingSession() then
            print(L["请先结束当前抛竿并关闭拾取窗口。"])
        end
    end,
}
endButton:SetScript("OnClick", function()
    local dialog = StaticPopupDialogs["WOWFFISHING_END_SESSION"]
    dialog.text, dialog.button1, dialog.button2 = L["结束本次并清空本次渔获和目标进度？"], L["结束本次"], CANCEL
    StaticPopup_Show("WOWFFISHING_END_SESSION")
end)

local function LoadVendorPrice(item)
    if not item.itemID or item.vendorPrice ~= nil then return end
    item.vendorPrice = select(11, C_Item.GetItemInfo(item.itemID))
    if item.vendorPrice == nil and not item.requestedData then
        item.requestedData = true
        C_Item.RequestLoadItemDataByID(item.itemID)
    end
end

function addon.RecordCatch(itemID, name, quantity)
    local item = itemID and catchesByID[itemID]
    local named = catchesByName[name]
    if not item and named and (not itemID or not named.itemID) then
        item = named
    end
    if not item then
        item = { name = name, quantity = 0 }
        catchesByName[name] = named or item
        catches[#catches + 1] = item
    end
    if itemID then
        item.itemID = itemID
        catchesByID[itemID] = item
    end
    item.quantity = item.quantity + quantity
    LoadVendorPrice(item)
    local saved = settings.fishingSession.items
    local key = item.itemID or item.name
    if item.itemID then saved[item.name] = nil end
    saved[key] = { name = item.name, quantity = item.quantity }
    local goal = settings.fishingSession.goal
    if goal and itemID == goal.id then goal.count = goal.count + quantity end
    addon.RecordFishObservation(itemID, quantity)
    if panel:IsShown() then Refresh() else RefreshAuctionControls() end
end

function addon.InitializeCatchList(db)
    settings = db
    db.auctionQuotes = db.auctionQuotes or {}
    quotes = db.auctionQuotes
    catches, catchesByID, catchesByName = {}, {}, {}
    for key, entry in pairs(db.fishingSession.items) do
        local item = { name = entry.name, itemID = type(key) == "number" and key or nil, quantity = entry.quantity }
        if item.itemID then catchesByID[item.itemID] = item end
        catchesByName[item.name] = item
        catches[#catches + 1] = item
        LoadVendorPrice(item)
    end
    table.sort(catches, function(a, b) return a.name < b.name end)
    local position = db.catchPanelPosition
    if position then
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
    end
end

function addon.ClearSessionCatches()
    catches, catchesByID, catchesByName = {}, {}, {}
    firstRow = 1
    local session = settings.fishingSession
    session.items = {}
    if session.goal then session.goal.count = 0 end
    if panel:IsShown() then Refresh() else RefreshAuctionControls() end
end

function addon.SetFishingGoal(id, name, target)
    local session = settings.fishingSession
    local previous = session.goal
    session.goal = id and { id = id, name = name, target = target,
        count = previous and previous.id == id and previous.count or 0 } or nil
    if panel:IsShown() then RefreshTotals() end
end

function addon.ToggleCatchList()
    theme.TogglePanel(panel)
end

local function FinishScan(text)
    scan.timeout:Cancel()
    scan = nil
    auctionMessage = text
    Refresh()
end

local function SendQuery()
    if not scan or scan.waiting or not auction.IsThrottledMessageSystemReady() then return end
    if not scan.pending then
        scan.pending = {}
        scan.attempt = 0
        for i = scan.offset, math.min(scan.offset + 39, #scan.ids) do
            scan.pending[scan.ids[i]] = true
        end
        scan.offset = scan.offset + 40
    end
    local keys = {}
    for itemID in pairs(scan.pending) do
        keys[#keys + 1] = auction.MakeItemKey(itemID)
    end
    scan.attempt = scan.attempt + 1
    scan.waiting = true
    auction.SearchForItemKeys(keys, { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } })
end

local function StartScan()
    if not auctionOpen or scan then return end
    local ids, seen = {}, {}
    local function AddItem(itemID)
        if itemID and not seen[itemID] then
            ids[#ids + 1] = itemID
            seen[itemID] = true
        end
    end
    for _, item in ipairs(catches) do
        AddItem(item.itemID)
    end
    if #ids == 0 then
        for _, fish in ipairs(addon.FishData.entries) do
            AddItem(fish.id)
        end
        for _, recipe in ipairs(addon.CookingData.entries) do
            AddItem(recipe.itemID)
        end
    end
    scan = { ids = ids, offset = 1, checked = 0, found = 0 }
    scan.timeout = C_Timer.NewTimer(45, function() FinishScan(L["查询超时，可重新更新"]) end)
    RefreshAuctionControls()
    SendQuery()
end

refresh:SetScript("OnClick", StartScan)

local function AttachAuctionControls()
    local house = AuctionHouseFrame
    local browse = house and house.BrowseResultsFrame
    if not browse or auctionRefresh then return end

    -- The browse footer sits below the results and to the right of the money display.
    local footer = CreateFrame("Frame", nil, browse)
    footer:SetPoint("BOTTOMLEFT", house, "BOTTOMLEFT", 178, 5)
    footer:SetPoint("BOTTOMRIGHT", house, "BOTTOMRIGHT", -12, 5)
    footer:SetHeight(20)
    auctionRefresh = theme.Button(footer, nil, "更新拍卖价", 114, 20, true)
    auctionRefresh:SetPoint("LEFT")
    auctionRefresh:SetScript("OnClick", StartScan)
    auctionStatus = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    auctionStatus:SetPoint("LEFT", auctionRefresh, "RIGHT", 10, 0)
    auctionStatus:SetPoint("RIGHT", -4, 0)
    auctionStatus:SetJustifyH("LEFT")
    auctionStatus:SetMaxLines(1)
    auctionStatus:SetTextColor(unpack(colors.muted))

    local function CancelForBrowseChange()
        if scan then FinishScan(L["拍卖行搜索已切换，请重新更新"]) end
    end
    house:RegisterCallback(AuctionHouseFrameMixin.Event.BrowseSearchStarted, CancelForBrowseChange, footer)
    browse:HookScript("OnHide", function()
        if house:IsVisible() then CancelForBrowseChange() end
    end)
    RefreshAuctionControls()
end

local function ReceiveQuotes()
    if not scan or not scan.waiting then return end
    local prices = {}
    for _, result in ipairs(auction.GetBrowseResults()) do
        local itemID = result.itemKey.itemID
        if not scan.pending[itemID] then
            FinishScan(L["拍卖行搜索已切换，请重新更新"])
            return
        end
        if result.totalQuantity > 0 and result.minPrice > 0 then
            prices[itemID] = math.min(prices[itemID] or result.minPrice, result.minPrice)
        end
    end
    for itemID, copper in pairs(prices) do
        quotes[itemID] = { copper = copper, time = GetServerTime() }
        scan.pending[itemID] = nil
        scan.checked = scan.checked + 1
        scan.found = scan.found + 1
    end
    scan.waiting = false
    -- Forever can return empty rows for a targeted search before prices arrive on a retry.
    if not next(scan.pending) or scan.attempt >= 3 then
        scan.checked = math.min(scan.offset - 1, #scan.ids)
        scan.pending = nil
        if scan.offset > #scan.ids then
            FinishScan((L["已更新 %d 种，%d 种未查到"]):format(scan.found, #scan.ids - scan.found))
            return
        end
    end
    Refresh()
    -- Let the current browse event finish before sending another request.
    C_Timer.After(0, SendQuery)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, itemID, success)
    if event == "ADDON_LOADED" then
        if itemID == "Blizzard_AuctionHouseUI" then AttachAuctionControls() end
    elseif event == "AUCTION_HOUSE_SHOW" then
        auctionOpen, auctionMessage = true, nil
        AttachAuctionControls()
        Refresh()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        auctionOpen, auctionMessage = false, nil
        if scan then FinishScan(L["已关闭拍卖行，查询停止"]) else Refresh() end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        ReceiveQuotes()
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        if scan then FinishScan(L["查询失败，可重新更新"]) end
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        SendQuery()
    elseif success then
        local updated = false
        for _, item in ipairs(catches) do
            if item.itemID == itemID and item.vendorPrice == nil then
                LoadVendorPrice(item)
                updated = updated or item.vendorPrice ~= nil
            end
        end
        if updated and panel:IsShown() then Refresh() end
    end
end)

for _, event in ipairs({
    "ADDON_LOADED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_FAILURE", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "ITEM_DATA_LOAD_RESULT",
}) do
    events:RegisterEvent(event)
end
AttachAuctionControls()
