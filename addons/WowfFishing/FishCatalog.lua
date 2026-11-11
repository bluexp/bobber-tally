local _, addon = ...
local data = addon.FishData
local byID = {}
for _, fish in ipairs(data.entries) do byID[fish.id] = fish end

local observations, quotes
local filtered = data.entries
local firstRow, visibleRows = 1, 11
local selected
local rows = {}

local panel = CreateFrame("Frame", "WowfFishingCatalog", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(668, 424)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()

local function Label(font, x, y, width)
    local label = panel:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    return label
end

Label("GameFontHighlight", 12, -6, 450):SetText("鱼类资料库")
Label("GameFontDisableSmall", 16, -37, 235):SetText("按鱼名、地点、类别或物品编号搜索")
local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
search:SetSize(225, 24)
search:SetPoint("TOPLEFT", 22, -54)
search:SetAutoFocus(false)
search:SetMaxLetters(60)
search:SetScript("OnEscapePressed", search.ClearFocus)

local count = Label("GameFontDisableSmall", 16, -390, 235)
local source = Label("GameFontDisableSmall", 277, -390, 374)
source:SetText("客户端 " .. data.build .. " · 钓点含经典参考")

local list = CreateFrame("Frame", nil, panel)
list:SetPoint("TOPLEFT", 15, -87)
list:SetSize(240, visibleRows * 26)
list:EnableMouseWheel(true)

local details = CreateFrame("ScrollFrame", nil, panel)
details:SetPoint("TOPLEFT", 277, -41)
details:SetSize(373, 338)
details:EnableMouseWheel(true)
local content = CreateFrame("Frame", nil, details)
content:SetSize(365, 338)
details:SetScrollChild(content)
local description = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
description:SetPoint("TOPLEFT", 0, 0)
description:SetWidth(365)
description:SetJustifyH("LEFT")
description:SetSpacing(3)

details:SetScript("OnMouseWheel", function(self, delta)
    local offset = self:GetVerticalScroll() - delta * 34
    self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
end)

local function ZoneNames(ids)
    local names = {}
    for _, id in ipairs(ids) do names[#names + 1] = C_Map.GetAreaInfo(id) or data.zones[id] or tostring(id) end
    return table.concat(names, "、")
end

local function RenderDetails()
    if not selected then
        description:SetText("没有匹配的鱼类")
        content:SetHeight(338)
        return
    end
    local fish = selected
    local liveName = C_Item.GetItemInfo(fish.id)
    local vendorPrice = select(11, C_Item.GetItemInfo(fish.id)) or fish.vendorPrice
    local quote = quotes[fish.id]
    local observed = observations[fish.id]
    local text = {
        "|cffffd100" .. (liveName or fish.name) .. "|r",
        ("%s · 物品 %d"):format(fish.category, fish.id),
        "",
        "卖给 NPC 的单价  " .. (vendorPrice and (vendorPrice > 0 and addon.FormatMoney(vendorPrice) or "不可出售") or "待查询"),
        "拍卖行单价  " .. (quote and addon.FormatMoney(quote.copper) or "未报价"),
    }
    if quote then text[#text + 1] = "报价时间  " .. date("%m-%d %H:%M", quote.time) end
    if fish.recipes and #fish.recipes > 0 then
        text[#text + 1] = ""
        text[#text + 1] = "|cffffd100用途|r"
        text[#text + 1] = table.concat(fish.recipes, "、")
    end
    text[#text + 1] = ""
    text[#text + 1] = "|cffffd100参考钓点|r"
    text[#text + 1] = #fish.zones > 0 and ZoneNames(fish.zones) or "待确认"
    text[#text + 1] = fish.zoneSource
    if fish.note then
        text[#text + 1] = ""
        text[#text + 1] = fish.note
    end
    text[#text + 1] = ""
    text[#text + 1] = "|cffffd100本角色在无限服的记录|r"
    text[#text + 1] = ("资料库启用后累计钓获 %d 件"):format(observed and observed.quantity or 0)
    local zones = {}
    for zone, quantity in pairs(observed and observed.zones or {}) do
        zones[#zones + 1] = ("%s ×%d"):format(zone, quantity)
    end
    table.sort(zones)
    if #zones > 0 then text[#text + 1] = table.concat(zones, "\n") end
    description:SetText(table.concat(text, "\n"))
    content:SetHeight(math.max(338, description:GetStringHeight() + 10))
end

local function RenderList()
    firstRow = math.max(1, math.min(firstRow, math.max(1, #filtered - visibleRows + 1)))
    for i, row in ipairs(rows) do
        row.fish = filtered[firstRow + i - 1]
        row:SetShown(row.fish ~= nil)
        if row.fish then
            row:SetText(row.fish.name)
            if row.fish == selected then row:LockHighlight() else row:UnlockHighlight() end
        end
    end
    count:SetText(("%d / %d 条资料 · 滚轮翻页"):format(#filtered, #data.entries))
end

for i = 1, visibleRows do
    local row = CreateFrame("Button", nil, list, "UIPanelButtonTemplate")
    row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
    row:SetSize(240, 24)
    row:SetNormalFontObject("GameFontHighlightSmall")
    row:SetScript("OnClick", function(self)
        selected = self.fish
        details:SetVerticalScroll(0)
        C_Item.RequestLoadItemDataByID(selected.id)
        RenderDetails()
        RenderList()
    end)
    rows[i] = row
end

list:SetScript("OnMouseWheel", function(_, delta)
    firstRow = firstRow - delta * 3
    RenderList()
end)

search:SetScript("OnTextChanged", function(self)
    local query = self:GetText():lower()
    filtered = {}
    for _, fish in ipairs(data.entries) do
        local searchText = table.concat({fish.name, fish.category, fish.id, ZoneNames(fish.zones)}, " "):lower()
        if searchText:find(query, 1, true) then filtered[#filtered + 1] = fish end
    end
    firstRow = 1
    selected = filtered[1]
    details:SetVerticalScroll(0)
    RenderList()
    RenderDetails()
end)

function addon.InitializeFishCatalog(db)
    db.fishObservations = db.fishObservations or {}
    observations, quotes = db.fishObservations, db.auctionQuotes
    selected = data.entries[1]
    for _, fish in ipairs(data.entries) do
        local name = C_Item.GetItemInfo(fish.id)
        if name then fish.name = name else C_Item.RequestLoadItemDataByID(fish.id) end
    end
end

function addon.RefreshFishCatalog()
    if panel:IsShown() then RenderDetails() end
end

function addon.RecordFishObservation(itemID, quantity)
    if not itemID then return end
    local observed = observations[itemID]
    if not observed then
        observed = { quantity = 0, zones = {} }
        observations[itemID] = observed
    end
    observed.quantity = observed.quantity + quantity
    local zone = GetRealZoneText()
    if zone and zone ~= "" then observed.zones[zone] = (observed.zones[zone] or 0) + quantity end
    addon.RefreshFishCatalog()
end

function addon.ToggleFishCatalog(itemID)
    if itemID and byID[itemID] then
        search:SetText("")
        selected = byID[itemID]
        panel:Show()
    else
        panel:SetShown(not panel:IsShown())
    end
end

panel:SetScript("OnShow", function()
    RenderList()
    RenderDetails()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:SetScript("OnEvent", function(_, _, itemID, success)
    local fish = success and byID[itemID]
    if not fish then return end
    fish.name = C_Item.GetItemInfo(itemID) or fish.name
    if panel:IsShown() then
        RenderList()
        RenderDetails()
    end
end)
