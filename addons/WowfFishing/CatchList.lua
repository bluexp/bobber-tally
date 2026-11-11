local _, addon = ...
local theme = addon.Theme
local colors = theme.colors
local catches, catchesByName, catchesByID = {}, {}, {}
local rows = {}
local visibleRows, rowHeight = 7, 33
local firstRow = 1
local auction = C_AuctionHouse
local auctionOpen = false
local settings, quotes, scan, auctionMessage

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
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return handle
end

local panel = theme.CreatePanel("WowfFishingCatchList")
local detailOffset = 82
local footerExtra = 28
local panelHeight = 366 + detailOffset + footerExtra
panel:SetSize(508, panelHeight)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 35)
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

Label(panel, "GameFontHighlight", 16, -4, 240):SetText("无限钓鱼助手 · 本次渔获")

local status = Label(surface, "GameFontHighlight", 16, -34, 205, nil, colors.gold)
local stats = Label(surface, "GameFontHighlight", 224, -34, 268, "RIGHT", colors.text)
local recent = Label(surface, "GameFontHighlightSmall", 16, -56, 250, nil, colors.muted)
local hint = Label(surface, "GameFontHighlightSmall", 269, -56, 223, "RIGHT", colors.muted)
local setupButton = theme.Button(surface, nil, "配置向导", 92, 25)
setupButton:SetPoint("TOPLEFT", 14, -75)
setupButton:SetScript("OnClick", function() addon.ShowSetup() end)
local audioButton = theme.Button(surface, nil, "", 112, 25)
audioButton:SetPoint("LEFT", setupButton, "RIGHT", 6, 0)
local catalogButton = theme.Button(surface, nil, "鱼类资料", 90, 25, true)
catalogButton:SetPoint("LEFT", audioButton, "RIGHT", 8, 0)
catalogButton:SetScript("OnClick", function() addon.ToggleFishCatalog() end)
local fishKeyButton = theme.Button(surface, "WowfFishingCatchKey", "", 156, 25)
fishKeyButton:SetPoint("LEFT", catalogButton, "RIGHT", 8, 0)
local fishKeyCapture

local function RefreshFishKey(notice)
    local listening = fishKeyCapture:IsListening()
    fishKeyButton:SetText(listening and "请按快捷键…" or "设置抛竿 / 收竿键")
    if notice then
        hint:SetText(notice)
    elseif listening then
        hint:SetText("按下快捷键，或按 Esc 取消")
    else
        hint:SetText(settings.fishKey and ("抛竿 / 收竿  " .. settings.fishKey) or "抛竿 / 收竿键未设置")
    end
end

function addon.UpdateCatchSummary(state, castCount, catchCount, itemCount, lastCatch)
    status:SetText(state)
    stats:SetText(("抛竿 %d 次 · 收获 %d 竿 / %d 件"):format(castCount, catchCount, itemCount))
    recent:SetText("最近渔获 " .. lastCatch)
    if not fishKeyCapture:IsListening() then RefreshFishKey() end
    audioButton:SetText(settings.enhanceSound and "水花声：增强" or "水花声：原音")
end

theme.Block(surface, "BORDER", 14, -111, 480, 294, colors.card)
Label(surface, "GameFontHighlightSmall", 24, -37 - detailOffset, 172, nil, colors.gold):SetText("物品")
Label(surface, "GameFontHighlightSmall", 208, -37 - detailOffset, 48, "RIGHT", colors.gold):SetText("数量")
Label(surface, "GameFontHighlightSmall", 268, -37 - detailOffset, 132, nil, colors.gold):SetText("拍卖行最低单价")
Label(surface, "GameFontHighlightSmall", 405, -37 - detailOffset, 89, nil, colors.gold):SetText("卖给 NPC")

local list = CreateFrame("Frame", nil, surface)
list:SetPoint("TOPLEFT", 14, -54 - detailOffset)
list:SetSize(480, visibleRows * rowHeight)
list:EnableMouseWheel(true)

for i = 1, visibleRows do
    local row = CreateFrame("Frame", nil, list)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
    row:SetSize(480, rowHeight)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.045 or 0.015)
    row.hover = theme.Fill(row, "ARTWORK", colors.hover)
    row.hover:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.icon:SetPoint("LEFT", 10, 0)
    row.icon:SetSize(21, 21)
    row.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    row.name = Label(row, "GameFontHighlight", 39, -8, 147, nil, colors.text)
    row.quantity = Label(row, "GameFontHighlight", 194, -8, 48, "RIGHT")
    row.auction = Label(row, "GameFontHighlight", 254, -3, 132)
    row.quoteTime = Label(row, "GameFontHighlightSmall", 254, -18, 132, nil, colors.muted)
    row.vendor = Label(row, "GameFontHighlight", 391, -8, 88)
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

local empty = Label(list, "GameFontHighlight", 0, -107, 480, "CENTER", colors.muted)
empty:SetText("本次还没有钓到物品")

theme.Block(surface, "ARTWORK", 24, -286 - detailOffset, 460, 1, colors.divider)
Label(surface, "GameFontHighlight", 24, -295 - detailOffset, 180, nil, colors.gold):SetText("本次合计")
local totalQuantity = Label(surface, "GameFontHighlight", 208, -295 - detailOffset, 48, "RIGHT")
local auctionTotal = Label(surface, "GameFontHighlight", 268, -295 - detailOffset, 132)
local auctionCoverage = Label(surface, "GameFontHighlightSmall", 268, -310 - detailOffset, 132, nil, colors.muted)
local vendorTotal = Label(surface, "GameFontHighlight", 405, -295 - detailOffset, 89)
local vendorCoverage = Label(surface, "GameFontHighlightSmall", 405, -310 - detailOffset, 89, nil, colors.muted)

local function FooterButton(text, width, x, y, primary)
    local button = theme.Button(surface, nil, text, width, 24, primary)
    button:SetPoint("BOTTOMLEFT", x, y)
    return button
end

local refresh = FooterButton("更新拍卖价", 108, 14, 12 + footerExtra, true)
local previous = FooterButton("上页", 40, 344, 12 + footerExtra)
local following = FooterButton("下页", 40, 454, 12 + footerExtra)
local footerTextY = 31 + footerExtra - panelHeight
local page = Label(surface, "GameFontHighlightSmall", 387, footerTextY, 64, "CENTER", colors.muted)
local message = Label(surface, "GameFontHighlightSmall", 130, footerTextY, 209, nil, colors.muted)
local aboutButton = FooterButton("关于", 64, 430, 10)
aboutButton:SetScript("OnClick", function() addon.ToggleAbout() end)

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
            row.icon:SetTexture(theme.ItemIcon(item.itemID))
            row.name:SetText(item.name)
            row.quantity:SetText(item.quantity)
            row.auction:SetText(quote and Money(quote.copper) or "未报价")
            row.quoteTime:SetText(quote and date("%m-%d %H:%M", quote.time) or "")
            row.vendor:SetText(vendor and (vendor > 0 and Money(vendor) or "不可出售") or "—")
        end
    end
    RefreshTotals()
    previous:SetShown(total > visibleRows)
    following:SetShown(total > visibleRows)
    previous:SetEnabled(firstRow > 1)
    following:SetEnabled(lastRow < total)
    page:SetText(total > 0 and ("%d–%d / %d"):format(firstRow, lastRow, total) or "")
    refresh:SetEnabled(auctionOpen and not scan)
    local queryHint = next(catchesByID) and "查询当前挂单" or "查询资料库鱼类和成品"
    message:SetText(auctionMessage or (auctionOpen and queryHint or "打开拍卖行后可更新"))
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

function addon.InitializeCatchList(db, toggleAudio, validateFishKey, saveFishKey)
    settings = db
    db.auctionQuotes = db.auctionQuotes or {}
    quotes = db.auctionQuotes
    audioButton:SetScript("OnClick", toggleAudio)
    if not fishKeyCapture then
        fishKeyCapture = addon.CreateKeyCapture(panel, "WowfFishingCatchKeyCapture", validateFishKey, saveFishKey, RefreshFishKey)
        fishKeyButton:SetScript("OnClick", function() fishKeyCapture:ToggleListening() end)
    end
    local position = db.catchPanelPosition
    if position then
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
    end
end

function addon.IsCatchListShown()
    return panel:IsShown()
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
        for _, fish in ipairs(addon.FishData.entries) do
            ids[#ids + 1] = fish.id
        end
        for _, recipe in ipairs(addon.CookingData.entries) do
            ids[#ids + 1] = recipe.itemID
        end
    end
    scan = { ids = ids, offset = 1, found = 0 }
    scan.timeout = C_Timer.NewTimer(45, function() FinishScan("查询超时，可重新更新") end)
    auctionMessage = ("正在查询 %d 种物品…"):format(#ids)
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
