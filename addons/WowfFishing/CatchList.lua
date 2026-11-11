local _, addon = ...
local catches, catchesByName, catchesByID = {}, {}, {}
local rows = {}
local visibleRows, rowHeight = 7, 33
local firstRow = 1
local auction = C_AuctionHouse
local auctionOpen = false
local quotes, scan, auctionMessage

local panel = CreateFrame("Frame", "WowfFishingCatchList", UIParent, "BasicFrameTemplateWithInset")
local panelHeight = 366
panel:SetSize(508, panelHeight)
panel:SetPoint("RIGHT", UIParent, "RIGHT", -55, 20)
panel:SetClampedToScreen(true)
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()

local function Label(parent, font, x, y, width, alignment)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH(alignment or "LEFT")
    label:SetMaxLines(1)
    return label
end

local title = Label(panel, "GameFontHighlight", 12, -6, 250)
title:SetText("本次渔获")
local catalogButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
catalogButton:SetSize(90, 20)
catalogButton:SetPoint("TOPRIGHT", -31, -3)
catalogButton:SetText("鱼类资料")
catalogButton:SetScript("OnClick", function() addon.ToggleFishCatalog() end)
Label(panel, "GameFontNormalSmall", 16, -37, 180):SetText("物品")
Label(panel, "GameFontNormalSmall", 208, -37, 48, "RIGHT"):SetText("数量")
Label(panel, "GameFontNormalSmall", 268, -37, 132):SetText("拍卖行最低单价")
Label(panel, "GameFontNormalSmall", 405, -37, 90):SetText("卖给 NPC")

local list = CreateFrame("Frame", nil, panel)
list:SetPoint("TOPLEFT", 14, -54)
list:SetSize(480, visibleRows * rowHeight)
list:EnableMouseWheel(true)

for i = 1, visibleRows do
    local row = CreateFrame("Frame", nil, list)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
    row:SetSize(480, rowHeight)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.045 or 0.015)
    row.name = Label(row, "GameFontHighlight", 2, -8, 184)
    row.quantity = Label(row, "GameFontHighlight", 194, -8, 48, "RIGHT")
    row.auction = Label(row, "GameFontHighlight", 254, -3, 132)
    row.quoteTime = Label(row, "GameFontDisableSmall", 254, -18, 132)
    row.vendor = Label(row, "GameFontHighlight", 391, -8, 88)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.item.itemID then
            GameTooltip:SetItemByID(self.item.itemID)
        else
            GameTooltip:SetText(self.item.name)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = row
end

local empty = Label(list, "GameFontDisable", 0, -85, 480, "CENTER")
empty:SetText("本次还没有钓到物品")

local divider = panel:CreateTexture(nil, "ARTWORK")
divider:SetPoint("TOPLEFT", 15, -286)
divider:SetSize(478, 1)
divider:SetColorTexture(1, 1, 1, 0.18)
Label(panel, "GameFontNormal", 16, -295, 180):SetText("本次合计")
local totalQuantity = Label(panel, "GameFontHighlight", 208, -295, 48, "RIGHT")
local auctionTotal = Label(panel, "GameFontHighlight", 268, -295, 132)
local auctionCoverage = Label(panel, "GameFontDisableSmall", 268, -310, 132)
local vendorTotal = Label(panel, "GameFontHighlight", 405, -295, 90)
local vendorCoverage = Label(panel, "GameFontDisableSmall", 405, -310, 90)

local function FooterButton(text, width, x)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("BOTTOMLEFT", x, 12)
    button:SetText(text)
    return button
end

local refresh = FooterButton("更新拍卖价", 108, 14)
local previous = FooterButton("‹", 25, 370)
local following = FooterButton("›", 25, 471)
local page = Label(panel, "GameFontDisableSmall", 399, 31 - panelHeight, 68, "CENTER")
local message = Label(panel, "GameFontDisableSmall", 128, 31 - panelHeight, 235)

local function Money(copper)
    if copper == 0 then return "0铜" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local remainder = copper % 100
    local text = {}
    if gold > 0 then text[#text + 1] = gold .. "金" end
    if silver > 0 then text[#text + 1] = silver .. "银" end
    if remainder > 0 then text[#text + 1] = remainder .. "铜" end
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
    auctionCoverage:SetText(auctionCount < quantity and ("%d 件未报价"):format(quantity - auctionCount) or "")
    vendorTotal:SetText(vendorCount > 0 and Money(vendorCopper) or "—")
    vendorCoverage:SetText(vendorCount < quantity and ("%d 件未知"):format(quantity - vendorCount) or "")
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
            row.name:SetText(item.name)
            row.quantity:SetText(item.quantity)
            row.auction:SetText(quote and Money(quote.copper) or "未报价")
            row.quoteTime:SetText(quote and date("%m-%d %H:%M", quote.time) or "")
            row.vendor:SetText(vendor and (vendor > 0 and Money(vendor) or "不可出售") or "—")
        end
    end
    RefreshTotals()
    previous:SetEnabled(firstRow > 1)
    following:SetEnabled(lastRow < total)
    page:SetText(total > 0 and ("%d–%d / %d"):format(firstRow, lastRow, total) or "")
    refresh:SetEnabled(auctionOpen and not scan and total > 0)
    message:SetText(auctionMessage or (auctionOpen and "查询当前挂单" or "打开拍卖行后可更新"))
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
    addon.RecordFishObservation(itemID, quantity)
    if panel:IsShown() then Refresh() end
end

function addon.InitializeCatchList(db)
    db.auctionQuotes = db.auctionQuotes or {}
    quotes = db.auctionQuotes
end

function addon.ToggleCatchList()
    panel:SetShown(not panel:IsShown())
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

refresh:SetScript("OnClick", function()
    if not auctionOpen or scan then return end
    local ids, seen = {}, {}
    for _, item in ipairs(catches) do
        if item.itemID and not seen[item.itemID] then
            ids[#ids + 1] = item.itemID
            seen[item.itemID] = true
        end
    end
    if #ids == 0 then
        auctionMessage = "渔获没有可查询的物品编号"
        Refresh()
        return
    end
    scan = { ids = ids, offset = 1, found = 0 }
    scan.timeout = C_Timer.NewTimer(45, function() FinishScan("查询超时，可重新更新") end)
    auctionMessage = "正在查询拍卖行…"
    Refresh()
    SendQuery()
end)

local function ReceiveQuotes()
    if not scan or not scan.waiting then return end
    local prices = {}
    for _, result in ipairs(auction.GetBrowseResults()) do
        local itemID = result.itemKey.itemID
        if not scan.pending[itemID] then
            FinishScan("拍卖行搜索已切换，请重新更新")
            return
        end
        if result.totalQuantity > 0 and result.minPrice > 0 then
            prices[itemID] = math.min(prices[itemID] or result.minPrice, result.minPrice)
        end
    end
    for itemID, copper in pairs(prices) do
        quotes[itemID] = { copper = copper, time = GetServerTime() }
        scan.pending[itemID] = nil
        scan.found = scan.found + 1
    end
    scan.waiting = false
    -- Forever can return empty rows for a targeted search before prices arrive on a retry.
    if not next(scan.pending) or scan.attempt >= 3 then
        scan.pending = nil
        if scan.offset > #scan.ids then
            FinishScan(("已更新 %d 种，%d 种未查到"):format(scan.found, #scan.ids - scan.found))
            return
        end
    end
    Refresh()
    -- Let the current browse event finish before sending another request.
    C_Timer.After(0, SendQuery)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, itemID, success)
    if event == "AUCTION_HOUSE_SHOW" then
        auctionOpen, auctionMessage = true, nil
        Refresh()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        auctionOpen, auctionMessage = false, nil
        if scan then FinishScan("已关闭拍卖行，查询停止") else Refresh() end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        ReceiveQuotes()
    elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        if scan then FinishScan("查询失败，可重新更新") end
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
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_FAILURE", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "ITEM_DATA_LOAD_RESULT",
}) do
    events:RegisterEvent(event)
end
