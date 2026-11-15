local _, addon = ...
local L, theme = addon.L, addon.Theme
local colors = theme.colors
local auction = C_AuctionHouse
local fishByID, fishByName = {}, {}
local store, auctionOpen, mailboxOpen, queryQueued
local recentSales = {}
local selectedDay, renderedToday
local DAY = 86400
local INVOICE_TIME_TOLERANCE = 5

for _, fish in ipairs(addon.FishData.entries) do
    fishByID[fish.id] = fish
    fishByName[fish.name] = fish.id
    local english = addon.EnglishCatalog.items[fish.id]
    if english then fishByName[english] = fish.id end
end

local soldPattern
if ERR_AUCTION_SOLD_S then
    local format = ERR_AUCTION_SOLD_S:gsub("%%1%$s", "%%s")
    local escaped = format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    soldPattern = "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
end

local function FishID(text)
    if type(text) ~= "string" or text == "" then return end
    local id = tonumber(text:match("|Hitem:(%d+)")) or fishByName[text] or C_Item.GetItemInfoInstant(text)
    return fishByID[id] and id or nil
end

local function FishName(id)
    local english = addon.IsEnglish() and addon.EnglishCatalog.items[id]
    return C_Item.GetItemInfo(id) or english or fishByID[id].name
end

local panel = theme.CreatePanel("WowfFishingAuctionWatch")
panel:SetSize(554, 450)
panel:SetPoint("CENTER", UIParent, "CENTER", 252, 30)
panel:SetMovable(true)
local surface = theme.Surface(panel)
local label = theme.Label
addon.SetLocalizedText(label(panel, "GameFontNormal", 16, -4, 392), "我的挂单")

local titleBar = CreateFrame("Frame", nil, panel)
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
    panel.moving = nil
    panel:StopMovingOrSizing()
    panel:SetUserPlaced(false)
    local x, y = panel:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if store and x and y and parentX and parentY then
        store.position = { x = x - parentX, y = y - parentY }
    end
end
titleBar:SetScript("OnDragStop", StopMoving)
panel:SetScript("OnHide", StopMoving)

local contentWidth, scrollHeight = 502, 350
local scroll = CreateFrame("ScrollFrame", nil, surface, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 16, -32)
scroll:SetSize(contentWidth, scrollHeight)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(contentWidth, scrollHeight)
scroll:SetScrollChild(content)

local rowHeight, firstRowTop = 22, 51
local function ColumnLabel(parent, column, y, color)
    local field = label(parent, "GameFontHighlightSmall", column.x, y, column.width, column.align, color)
    field:SetMaxLines(1)
    return field
end

local function CreateSection(title, emptyText, columns)
    local frame = theme.Inset(content, 0, 0, contentWidth, firstRowTop + rowHeight)
    addon.SetLocalizedText(label(frame, "GameFontNormal", 10, -7, 174, nil, colors.gold), title)
    theme.Block(frame, "ARTWORK", 3, -29, contentWidth - 6, 22, colors.control)
    for _, column in ipairs(columns) do
        addon.SetLocalizedText(ColumnLabel(frame, column, -34, colors.muted), column.title)
    end
    local empty = label(frame, "GameFontHighlightSmall", 10, -57, contentWidth - 20, nil, colors.muted)
    addon.SetLocalizedText(empty, emptyText)
    return { frame = frame, columns = columns, empty = empty, rows = {} }
end

local itemColumn = { title = "物品", x = 10, width = 151 }
local listings = CreateSection("在售挂单", "暂无在售挂单", {
    itemColumn,
    { title = "数量", x = 167, width = 44, align = "RIGHT" },
    { title = "挂单笔数", x = 219, width = 75, align = "RIGHT" },
    { title = "一口价", x = 302, width = 106, align = "RIGHT" },
    { title = "最早到期", x = 416, width = 76, align = "RIGHT" },
})
local listedSummary = label(listings.frame, "GameFontHighlightSmall", 192, -9, 300, "RIGHT", colors.gold)
local sold = CreateSection("拍卖行已售", "暂无成交记录", {
    itemColumn,
    { title = "成交确认", x = 176, width = 106, align = "RIGHT" },
    { title = "已售", x = 291, width = 82, align = "RIGHT" },
    { title = "拍卖行应收", x = 381, width = 111, align = "RIGHT" },
})
local daily = CreateSection("每日记录", "当天暂无记录", {
    itemColumn,
    { title = "确认笔数", x = 170, width = 74, align = "RIGHT" },
    { title = "已结算", x = 252, width = 52, align = "RIGHT" },
    { title = "结算所得", x = 312, width = 87, align = "RIGHT" },
    { title = "最近成交额", x = 407, width = 85, align = "RIGHT" },
})
local previousDay = theme.Button(daily.frame, nil, "上个记录日", 104, 20)
previousDay:SetPoint("TOPLEFT", 186, -4)
local dayLabel = label(daily.frame, "GameFontHighlightSmall", 296, -8, 86, "CENTER", colors.text)
local nextDay = theme.Button(daily.frame, nil, "下个记录日", 104, 20)
nextDay:SetPoint("TOPRIGHT", -10, -4)
local dailyTotal = label(daily.frame, "GameFontHighlightSmall", 10, 0, contentWidth - 20, nil, colors.gold)
dailyTotal:ClearAllPoints()
dailyTotal:SetPoint("BOTTOMLEFT", 10, 22)
local dailyNote = label(daily.frame, "GameFontHighlightSmall", 10, 0, contentWidth - 20, nil, colors.muted)
dailyNote:ClearAllPoints()
dailyNote:SetPoint("BOTTOMLEFT", 10, 5)
addon.SetLocalizedText(dailyNote, "成交按确认日记录，所得按邮箱同步日记录。")

local lifetime = label(surface, "GameFontHighlight", 16, -389, contentWidth, nil, colors.gold)
local auctionStatus = label(surface, "GameFontHighlightSmall", 16, -409, contentWidth, nil, colors.muted)
local mailStatus = label(surface, "GameFontHighlightSmall", 16, -426, contentWidth, nil, colors.muted)

local function DayFor(timestamp)
    return date("%Y-%m-%d", timestamp)
end

local function DailyItem(day, itemID)
    store.days[day] = store.days[day] or {}
    local items = store.days[day]
    items[itemID] = items[itemID] or { confirmed = 0, quantity = 0, copper = 0 }
    return items[itemID]
end

local function FormatBuyout(group)
    if not group.minBuyout then return "—" end
    local price = addon.FormatMoney(group.minBuyout)
    if group.minBuyout ~= group.maxBuyout then price = price .. "–" .. addon.FormatMoney(group.maxBuyout) end
    return price
end

local function RenderSection(section, top, items, extraHeight)
    table.sort(items, function(a, b) return a[1] < b[1] end)
    section.frame:ClearAllPoints()
    section.frame:SetPoint("TOPLEFT", 0, -top)
    for index, item in ipairs(items) do
        local row = section.rows[index]
        if not row then
            row = CreateFrame("Frame", nil, section.frame)
            row:SetPoint("TOPLEFT", 0, -firstRowTop - (index - 1) * rowHeight)
            row:SetSize(contentWidth, rowHeight)
            theme.Block(row, "BACKGROUND", 3, 0, contentWidth - 6, rowHeight,
                { 1, 1, 1, index % 2 == 0 and 0.045 or 0.015 })
            row.cells = {}
            for cellIndex, column in ipairs(section.columns) do
                row.cells[cellIndex] = ColumnLabel(row, column, -5, colors.text)
            end
            section.rows[index] = row
        end
        for cellIndex, cell in ipairs(row.cells) do cell:SetText(item[cellIndex]) end
        row:Show()
    end
    for index = #items + 1, #section.rows do section.rows[index]:Hide() end
    section.empty:SetShown(#items == 0)

    local height = firstRowTop + math.max(1, #items) * rowHeight + (extraHeight or 0) + 3
    section.frame:SetHeight(height)
    return top + height + 10
end

local function Render()
    if not store or not panel:IsShown() then return end
    local today = DayFor(GetServerTime())
    renderedToday = today
    local day = selectedDay or today
    local earlier = nil
    local later = day < today and today or nil
    for savedDay in pairs(store.days) do
        if savedDay < day and (not earlier or savedDay > earlier) then earlier = savedDay end
        if savedDay > day and (not later or savedDay < later) then later = savedDay end
    end
    previousDay.day, nextDay.day = earlier, later
    previousDay:SetEnabled(earlier ~= nil)
    nextDay:SetEnabled(later ~= nil)
    dayLabel:SetText(day)

    local groups, listed = {}, 0
    for _, entry in pairs(store.auctions) do
        if entry.active then
            local group = groups[entry.itemID] or { count = 0, quantity = 0 }
            group.count, group.quantity = group.count + 1, group.quantity + entry.quantity
            if entry.buyout then
                group.minBuyout = math.min(group.minBuyout or entry.buyout, entry.buyout)
                group.maxBuyout = math.max(group.maxBuyout or entry.buyout, entry.buyout)
            end
            if entry.expires then group.earliest = math.min(group.earliest or entry.expires, entry.expires) end
            groups[entry.itemID] = group
            listed = listed + entry.quantity
        end
    end

    local activeRows, soldRows, dailyRows = {}, {}, {}
    local received, dayConfirmations, dayQuantity, dayCopper = 0, 0, 0, 0
    local dayItems = store.days[day] or {}
    for id in pairs(fishByID) do
        local active, snapshot, confirmedAt = groups[id], store.soldSnapshot[id], store.confirmations[id]
        local recorded, sales = dayItems[id], store.sales[id]
        local name = (active or snapshot or confirmedAt or recorded) and FishName(id)
        if active then
            activeRows[#activeRows + 1] = { name, active.quantity, active.count, FormatBuyout(active),
                active.earliest and date("%m-%d %H:%M", active.earliest) or "—" }
        end
        if snapshot or confirmedAt then
            local confirmation = confirmedAt and confirmedAt > 0 and date("%m-%d %H:%M", confirmedAt) or L["已确认"]
            local soldAmount = snapshot and (snapshot.unknownQuantity and L["%d 笔"]:format(snapshot.count)
                or L["%d 条"]:format(snapshot.quantity)) or "—"
            local incoming = snapshot and not snapshot.unknownAmount and addon.FormatMoney(snapshot.amount) or "—"
            soldRows[#soldRows + 1] = { name, confirmation, soldAmount, incoming }
        end
        if recorded then
            dailyRows[#dailyRows + 1] = { name, recorded.confirmed, recorded.quantity,
                addon.FormatMoney(recorded.copper), recorded.lastPrice and addon.FormatMoney(recorded.lastPrice) or "—" }
            dayConfirmations = dayConfirmations + recorded.confirmed
            dayQuantity = dayQuantity + recorded.quantity
            dayCopper = dayCopper + recorded.copper
        end
        if sales then received = received + sales.copper end
    end

    local top = RenderSection(listings, 0, activeRows)
    top = RenderSection(sold, top, soldRows)
    local bottom = RenderSection(daily, top, dailyRows, 35)
    dailyTotal:SetText(L["当日合计 · 确认 %d 笔 · 结算 %d 条 · 所得 %s"]:format(dayConfirmations, dayQuantity,
        addon.FormatMoney(dayCopper)))
    content:SetHeight(math.max(scrollHeight, bottom - 10))
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), scroll:GetVerticalScrollRange()))

    listedSummary:SetText(L["在售 %d 条"]:format(listed))
    lifetime:SetText(L["累计结算所得 %s"]:format(addon.FormatMoney(received)))
    local checked = store.auctionUpdatedAt and date("%m-%d %H:%M", store.auctionUpdatedAt)
    auctionStatus:SetText(checked and L[store.auctionPending and "上次核对挂单 %s · 有成交待同步" or "上次核对挂单 %s"]:format(checked)
        or L["打开拍卖行同步在售数量"])
    mailStatus:SetText(store.mailUpdatedAt and L["上次核对邮箱 %s"]:format(date("%m-%d %H:%M", store.mailUpdatedAt))
        or L["打开游戏邮箱同步鱼类结算所得"])
end

local function ChangeDay(button)
    if not button.day then return end
    selectedDay = button.day ~= DayFor(GetServerTime()) and button.day or nil
    Render()
end
previousDay:SetScript("OnClick", ChangeDay)
nextDay:SetScript("OnClick", ChangeDay)

local refreshElapsed = 0
panel:SetScript("OnUpdate", function(_, elapsed)
    refreshElapsed = refreshElapsed + elapsed
    if refreshElapsed < 15 then return end
    refreshElapsed = 0
    if renderedToday ~= DayFor(GetServerTime()) then Render() end
end)

local function Say(message)
    print("|cff63c6ea" .. L["无限钓鱼助手"] .. "|r " .. message)
end

local function RememberConfirmation(itemID)
    -- The listing or mailbox confirms a sale, but does not give its confirmation time.
    store.confirmations[itemID] = store.confirmations[itemID] or 0
end

local function NotifySale(id, itemID)
    if not itemID then return end
    if type(id) ~= "number" or id <= 0 then id = nil end
    local now = GetServerTime()
    if id then
        local entry = store.auctions[id] or { itemID = itemID, time = now }
        if entry.notified then return end
        entry.notified = true
        store.auctions[id] = entry
    end

    -- Pair notifications without an auction ID with the corresponding listing update.
    local notices = recentSales[itemID] or {}
    recentSales[itemID] = notices
    for index = #notices, 1, -1 do
        local previous = notices[index]
        if now - previous.time > 5 then
            table.remove(notices, index)
        elseif previous.hasID ~= (id ~= nil) then
            table.remove(notices, index)
            return
        end
    end
    notices[#notices + 1] = { time = now, hasID = id ~= nil }
    store.confirmations[itemID] = now
    local item = DailyItem(DayFor(now), itemID)
    item.confirmed = item.confirmed + 1
    Say(L["拍卖成交：%s"]:format(FishName(itemID)))
    return true
end

local function RefreshOwnedAuctions()
    if not auctionOpen or not auction.HasFullOwnedAuctionResults() then return end
    local now = GetServerTime()
    local soldSnapshot = {}
    for _, entry in pairs(store.auctions) do entry.active = nil end
    for _, result in ipairs(auction.GetOwnedAuctions()) do
        local id = result.auctionID
        local itemID = result.itemKey and result.itemKey.itemID
        if id and id > 0 and fishByID[itemID] then
            local entry = store.auctions[id]
            if result.status == Enum.AuctionStatus.Active and result.quantity > 0 then
                entry = entry or { itemID = itemID }
                entry.active, entry.quantity, entry.time = true, result.quantity, now
                entry.buyout = result.buyoutAmount and result.buyoutAmount > 0 and result.buyoutAmount or nil
                entry.expires = result.timeLeftSeconds and now + result.timeLeftSeconds or nil
                store.auctions[id] = entry
                local name = C_Item.GetItemInfo(itemID)
                if name then fishByName[name] = itemID end
            elseif result.status == Enum.AuctionStatus.Sold then
                local sold = soldSnapshot[itemID] or { count = 0, quantity = 0, amount = 0 }
                sold.count = sold.count + 1
                if result.quantity and result.quantity > 0 then
                    sold.quantity = sold.quantity + result.quantity
                else
                    sold.unknownQuantity = true
                end
                -- The native My Auctions list shows this amount beside its incoming-funds label.
                if result.buyoutAmount and result.buyoutAmount > 0 then
                    sold.amount = sold.amount + result.buyoutAmount
                else
                    sold.unknownAmount = true
                end
                soldSnapshot[itemID] = sold
                RememberConfirmation(itemID)
                if entry then NotifySale(id, itemID) end
            end
        end
    end
    store.soldSnapshot = soldSnapshot
    store.auctionUpdatedAt = now
    store.auctionPending = nil
    Render()
end

local function SendOwnedQuery()
    if auctionOpen and queryQueued and auction.IsThrottledMessageSystemReady() then
        queryQueued = false
        local sorts = AuctionHouseFrame and AuctionHouseFrame.GetSortsForContext and AuctionHouseSearchContext
            and AuctionHouseFrame:GetSortsForContext(AuctionHouseSearchContext.AllAuctions)
        auction.QueryOwnedAuctions(sorts or { { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false } })
    end
end

local function QueueOwnedQuery()
    if not auctionOpen or queryQueued then return end
    queryQueued = true
    C_Timer.After(0, SendOwnedQuery)
end

local function AddSettlement(total, quantity, copper, bid, expires)
    total.quantity, total.copper = total.quantity + quantity, total.copper + copper
    if not total.lastInvoiceExpiry or expires > total.lastInvoiceExpiry then
        total.lastPrice, total.lastInvoiceExpiry = bid, expires
    end
end

local function RecordSettlements()
    if not mailboxOpen then return end
    local now = GetServerTime()
    local day = DayFor(now)
    local matched, newQuantity, newCopper = {}, 0, 0
    for key, expirations in pairs(store.invoices) do
        for index = #expirations, 1, -1 do
            if expirations[index] + INVOICE_TIME_TOLERANCE < now then table.remove(expirations, index) end
        end
        if #expirations == 0 then store.invoices[key] = nil end
    end
    for slot = 1, GetInboxNumItems() do
        local kind, name, _, bid, _, deposit, fee, _, _, _, count = GetInboxInvoiceInfo(slot)
        local id = (kind == "seller" or kind == "seller_temp_invoice") and FishID(name)
        if id and kind == "seller_temp_invoice" then
            RememberConfirmation(id)
        elseif id and type(bid) == "number" then
            local daysLeft = select(7, GetInboxHeaderInfo(slot))
            if type(daysLeft) == "number" and daysLeft > 0 then
                local quantity, copper = count or 1, bid + (deposit or 0) - (fee or 0)
                local key = table.concat({ id, quantity, bid, deposit or 0, fee or 0 }, ":")
                local expires = now + daysLeft * DAY
                local expirations, used = store.invoices[key] or {}, matched[key] or {}
                store.invoices[key], matched[key] = expirations, used
                -- Inbox slots move after collection. Match invoice details and expiry, once per visible mail.
                local matchingIndex
                local closest = INVOICE_TIME_TOLERANCE
                for index, previous in ipairs(expirations) do
                    local difference = math.abs(previous - expires)
                    if not used[index] and difference <= closest then
                        matchingIndex, closest = index, difference
                    end
                end
                if not matchingIndex then
                    matchingIndex = #expirations + 1
                    expirations[matchingIndex] = expires
                    store.sales[id] = store.sales[id] or { quantity = 0, copper = 0 }
                    AddSettlement(store.sales[id], quantity, copper, bid, expires)
                    AddSettlement(DailyItem(day, id), quantity, copper, bid, expires)
                    newQuantity, newCopper = newQuantity + quantity, newCopper + copper
                end
                used[matchingIndex] = true
            end
        end
    end
    store.mailUpdatedAt = now
    if newQuantity > 0 then
        Say(L["邮箱结算：售出 %d 条鱼，所得 %s。"]:format(newQuantity, addon.FormatMoney(newCopper)))
    end
    Render()
end

function addon.InitializeAuctionWatch(db)
    db.auctionWatch = db.auctionWatch or { auctions = {}, sales = {}, invoices = {} }
    store = db.auctionWatch
    store.confirmations = store.confirmations or {}
    store.soldSnapshot = store.soldSnapshot or {}
    selectedDay = nil
    if not store.days then
        store.days = {}
        -- Older saves kept only the latest dated confirmation per fish and undated settlement totals.
        for itemID, timestamp in pairs(store.confirmations) do
            if timestamp > 0 and fishByID[itemID] then
                DailyItem(DayFor(timestamp), itemID).confirmed = 1
            end
        end
    end
    local position = store.position
    if position then
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
    end
    local cutoff = GetServerTime() - 7 * DAY
    for id, entry in pairs(store.auctions) do
        if entry.notified and fishByID[entry.itemID] then RememberConfirmation(entry.itemID) end
        if not entry.active and entry.time < cutoff then store.auctions[id] = nil end
    end
end

function addon.ToggleAuctionWatch()
    theme.TogglePanel(panel)
end

panel:SetScript("OnShow", function()
    Render()
    QueueOwnedQuery()
end)

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, value, text, auctionID)
    if not store then return end
    if event == "AUCTION_HOUSE_SHOW" then
        auctionOpen = true
        QueueOwnedQuery()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        auctionOpen, queryQueued = false, false
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        RefreshOwnedAuctions()
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        SendOwnedQuery()
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        QueueOwnedQuery()
    elseif event == "AUCTION_CANCELED" or event == "AUCTION_HOUSE_AUCTIONS_EXPIRED" then
        local entry = store.auctions[value]
        if entry then entry.active = nil end
        Render()
        QueueOwnedQuery()
    elseif event == "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION" then
        if value == Enum.AuctionHouseNotification.AuctionSold then
            local entry = auctionID and store.auctions[auctionID]
            local item = soldPattern and text and text:match(soldPattern)
            local itemID = entry and entry.itemID or FishID(item or text)
            if NotifySale(auctionID, itemID) then
                store.auctionPending = true
                Render()
            end
            QueueOwnedQuery()
        end
    elseif event == "AUCTION_HOUSE_SHOW_NOTIFICATION" then
        if value == Enum.AuctionHouseNotification.AuctionSold then QueueOwnedQuery() end
    elseif event == "MAIL_SHOW" then
        mailboxOpen = true
        RecordSettlements()
    elseif event == "MAIL_INBOX_UPDATE" then
        RecordSettlements()
    elseif event == "MAIL_CLOSED" then
        mailboxOpen = false
    end
end)

for _, event in ipairs({
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_CANCELED", "AUCTION_HOUSE_AUCTIONS_EXPIRED",
    "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION", "AUCTION_HOUSE_SHOW_NOTIFICATION",
    "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED",
}) do
    events:RegisterEvent(event)
end
