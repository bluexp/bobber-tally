local _, addon = ...
local L = addon.L
local theme = addon.Theme
local colors = theme.colors
local data, cooking = addon.FishData, addon.CookingData
local english = addon.EnglishCatalog
local fishByID, recipesByFish, items = {}, {}, {}

for _, fish in ipairs(data.entries) do
    fishByID[fish.id] = fish
    items[fish.id] = fish.name
end
for itemID, name in pairs(cooking.materialNames) do
    items[itemID] = name
end
for _, recipe in ipairs(cooking.entries) do
    items[recipe.itemID] = recipe.itemName
    for _, material in ipairs(recipe.materials) do
        local fishID = material[1]
        if fishByID[fishID] then
            recipesByFish[fishID] = recipesByFish[fishID] or {}
            table.insert(recipesByFish[fishID], recipe)
        end
    end
end

local observations, quotes
local mode, filtered, selected = "fish", data.entries, data.entries[1]
local firstRow, visibleRows, rowHeight = 1, 11, 29
local rows, tabs = {}, {}

local panel = theme.CreatePanel("WowfFishingCatalog")
panel:SetSize(760, 490)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
panel:SetMovable(true)

local Label, Fill = theme.Label, theme.Fill

local function Region(parent, x, y, width, height)
    local region = CreateFrame("Frame", nil, parent)
    region:SetPoint("TOPLEFT", x, y)
    region:SetSize(width, height)
    return region
end

local surface = Region(panel, 5, -22, 750, 462)
Fill(surface, "BACKGROUND", colors.surface)

local titleBar = CreateFrame("Frame", nil, panel)
titleBar:SetPoint("TOPLEFT", 7, 0)
titleBar:SetPoint("TOPRIGHT", -29, 0)
titleBar:SetHeight(21)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() panel:StartMoving() end)
titleBar:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
panel:SetScript("OnHide", function() panel:StopMovingOrSizing() end)
addon.SetLocalizedText(Label(panel, "GameFontHighlight", 16, -4, 400), "无限钓鱼助手 · 资料库")

local function Button(parent, x, y, width, height, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, height)
    theme.Highlight(button)
    button.label = Label(button, "GameFontHighlightSmall", 0, -(height - 12) / 2, width)
    button.label:SetJustifyH("CENTER")
    addon.SetLocalizedText(button.label, text)
    return button
end

tabs.fish = Button(surface, 13, -17, 88, 31, "鱼类")
tabs.cooking = Button(surface, 106, -17, 88, 31, "烹饪")
for _, tab in pairs(tabs) do
    tab.active = Fill(tab, "BACKGROUND", colors.selected)
    tab.line = tab:CreateTexture(nil, "ARTWORK")
    tab.line:SetPoint("BOTTOMLEFT")
    tab.line:SetPoint("BOTTOMRIGHT")
    tab.line:SetHeight(2)
    tab.line:SetColorTexture(unpack(colors.gold))
end

local search = CreateFrame("EditBox", "WowfFishingCatalogSearch", surface, "InputBoxTemplate")
search:SetSize(258, 28)
search:SetPoint("TOPRIGHT", -16, -18)
search:SetAutoFocus(false)
search:SetMaxLetters(60)
search:SetScript("OnEscapePressed", search.ClearFocus)
search:SetScript("OnEnterPressed", search.ClearFocus)
local searchHint = Label(search, "GameFontDisableSmall", 5, -8, 244)

local list = Region(surface, 13, -59, 251, 360)
Fill(list, "BACKGROUND", colors.card)
list:EnableMouseWheel(true)
local count = Label(list, "GameFontDisableSmall", 11, -338, 229)

local detail = Region(surface, 276, -59, 461, 360)
Fill(detail, "BACKGROUND", colors.card)
theme.Block(detail, "ARTWORK", 15, -76, 431, 1, colors.divider)

local iconButton = CreateFrame("Button", nil, detail)
iconButton:SetPoint("TOPLEFT", 15, -15)
iconButton:SetSize(48, 48)
local largeIcon = Fill(iconButton, "ARTWORK", colors.control)
largeIcon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
local nameLabel = Label(detail, "GameFontNormalLarge", 76, -17, 367)
nameLabel:SetMaxLines(1)
nameLabel:SetTextColor(0.98, 0.94, 0.83)
local subtitle = Label(detail, "GameFontHighlightSmall", 76, -46, 241)
subtitle:SetTextColor(unpack(colors.muted))
local related = theme.Button(detail, nil, "查看烹饪配方", 130, 25, true)
related:SetPoint("TOPLEFT", 316, -40)

local details = CreateFrame("ScrollFrame", nil, detail)
details:SetPoint("TOPLEFT", 15, -88)
details:SetSize(431, 256)
details:EnableMouseWheel(true)
local content = CreateFrame("Frame", nil, details)
content:SetSize(428, 256)
details:SetScrollChild(content)
local description = Label(content, "GameFontHighlight", 0, 0, 421)
description:SetSpacing(4)
details:SetScript("OnMouseWheel", function(self, delta)
    local offset = self:GetVerticalScroll() - delta * 34
    self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
end)

local source = Label(surface, "GameFontDisableSmall", 276, -431, 461)

local function ItemName(itemID)
    local fallback = (addon.IsEnglish() and english.items[itemID]) or items[itemID]
    if addon.PreferClientNames() then
        return C_Item.GetItemInfo(itemID) or fallback or (L["物品 %d"]):format(itemID)
    end
    return fallback or C_Item.GetItemInfo(itemID) or (L["物品 %d"]):format(itemID)
end

local function RecipeName(recipe)
    return (addon.PreferClientNames() and C_Spell.GetSpellName(recipe.spellID)) or ItemName(recipe.itemID)
end

local ItemIcon = theme.ItemIcon

local function AttachItemTooltip(button)
    button:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
AttachItemTooltip(iconButton)

local function ZoneName(areaID)
    local fallback = (addon.IsEnglish() and english.zones[areaID]) or data.zones[areaID]
    if addon.PreferClientNames() then
        return C_Map.GetAreaInfo(areaID) or fallback or tostring(areaID)
    end
    return fallback or C_Map.GetAreaInfo(areaID) or tostring(areaID)
end

local function ZoneNames(ids)
    local names = {}
    for _, id in ipairs(ids) do names[#names + 1] = ZoneName(id) end
    return table.concat(names, L["、"])
end

local function PriceLines(itemID, fallbackVendor)
    local vendor = select(11, C_Item.GetItemInfo(itemID)) or fallbackVendor
    local quote = quotes[itemID]
    local lines = {
        L["NPC 出售  "] .. (vendor and (vendor > 0 and addon.FormatMoney(vendor) or L["不可出售"]) or L["待查询"]),
        L["拍卖行单价  "] .. (quote and addon.FormatMoney(quote.copper) or L["未报价"]),
    }
    if quote then lines[#lines + 1] = L["报价时间  "] .. date("%m-%d %H:%M", quote.time) end
    return table.concat(lines, "\n")
end

local function FishDetails(fish)
    local text = {
        L["|cffe9c483价格|r"],
        PriceLines(fish.id, fish.vendorPrice),
    }
    local recipes = recipesByFish[fish.id]
    if recipes then
        local names = {}
        for _, recipe in ipairs(recipes) do names[#names + 1] = RecipeName(recipe) end
        text[#text + 1] = L["\n|cffe9c483烹饪配方|r"]
        text[#text + 1] = table.concat(names, L["、"])
    end
    if fish.uses then
        text[#text + 1] = L["\n|cffe9c483其他用途|r"]
        local uses = {}
        for _, key in ipairs(fish.uses) do uses[#uses + 1] = L[key] end
        text[#text + 1] = table.concat(uses, L["、"])
    end
    return table.concat(text, "\n")
end

local function FishNotes(fish)
    local text = { L[fish.zoneSource] }
    if fish.note then text[#text + 1] = L[fish.note] end
    local observed = observations[fish.id]
    text[#text + 1] = L["\n|cffe9c483本角色钓获|r"]
    text[#text + 1] = (L["累计 %d 件"]):format(observed and observed.quantity or 0)
    local zones = {}
    for zone, quantity in pairs(observed and observed.zones or {}) do
        zones[#zones + 1] = ("%s ×%d"):format(zone, quantity)
    end
    table.sort(zones)
    if #zones > 0 then text[#text + 1] = table.concat(zones, L["、"]) end
    return table.concat(text, "\n")
end

local locationsTitle = Label(content, "GameFontHighlight", 0, 0, 421, nil, colors.gold)
local locationNotes = Label(content, "GameFontHighlightSmall", 0, 0, 421, nil, colors.muted)
locationNotes:SetSpacing(4)
local locationMeasure = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
local locationButtons = {}

local function OpenLocation(button)
    if not button.mapID then return end
    OpenWorldMap(button.mapID)
    if WorldMapFrame and WorldMapFrame:IsShown() then
        GameTooltip:Hide()
        panel:Hide()
    end
end

local function RenderLocations(fish)
    local zoneCount = fish and #fish.zones or 0
    for index = zoneCount + 1, #locationButtons do locationButtons[index]:Hide() end
    locationsTitle:SetShown(fish ~= nil)
    locationNotes:SetShown(fish ~= nil)
    local height = description:GetStringHeight()
    if not fish then return height end

    local x, y = 0, height + 14
    locationsTitle:SetPoint("TOPLEFT", 0, -y)
    locationsTitle:SetText(L["参考钓点"])
    y = y + locationsTitle:GetStringHeight() + 6
    for index, areaID in ipairs(fish.zones) do
        local button = locationButtons[index]
        if not button then
            button = theme.Button(content, nil, "", 60, 23)
            button:SetScript("OnClick", OpenLocation)
            button:SetScript("OnEnter", function(self)
                if not self.mapID then return end
                local map = C_Map.GetMapInfo(self.mapID)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["打开地图 · "] .. (map and map.name or self:GetText()))
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            locationButtons[index] = button
        end
        local name = ZoneName(areaID)
        locationMeasure:SetText(name)
        local width = math.max(48, math.ceil(locationMeasure:GetStringWidth()) + 20)
        if x + width > 421 then
            x, y = 0, y + 28
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", x, -y)
        button:SetWidth(width)
        button:SetText(name)
        local mapID = data.zoneMaps[areaID]
        button.mapID = mapID and C_Map.GetMapInfo(mapID) and mapID or nil
        button:SetEnabled(button.mapID ~= nil)
        button:Show()
        x = x + width + 5
    end
    if zoneCount > 0 then y = y + 30 end
    locationNotes:SetPoint("TOPLEFT", 0, -y)
    local notes = FishNotes(fish)
    locationNotes:SetText(zoneCount > 0 and notes or (L["待确认\n"] .. notes))
    return y + locationNotes:GetStringHeight()
end

local function CookingDetails(recipe)
    local materials = {}
    for _, material in ipairs(recipe.materials) do
        local itemID, quantity = unpack(material)
        materials[#materials + 1] = ("|T%d:16:16|t  %s ×%d"):format(ItemIcon(itemID), ItemName(itemID), quantity)
    end
    return table.concat({
        L["|cffe9c483技能与材料|r"],
        (L["烹饪 %d 变黄  ·  %d 变绿  ·  %d 变灰"]):format(recipe.yellow, math.floor((recipe.yellow + recipe.grey) / 2), recipe.grey),
        table.concat(materials, "\n"),
        "",
        L["|cffe9c483成品|r"],
        ("%s ×%d"):format(ItemName(recipe.itemID), recipe.quantity),
        PriceLines(recipe.itemID),
    }, "\n")
end

local function EntryName(entry)
    if entry.id then return ItemName(entry.id) end
    return RecipeName(entry)
end

local function RenderDetails()
    iconButton:SetShown(selected ~= nil)
    related:SetShown(selected ~= nil and recipesByFish[selected.id] ~= nil)
    if not selected then
        nameLabel:SetText(L["没有匹配的条目"])
        subtitle:SetText("")
        description:SetText("")
        RenderLocations(nil)
        content:SetHeight(256)
        return
    end
    local itemID = selected.id or selected.itemID
    iconButton.itemID = itemID
    largeIcon:SetTexture(ItemIcon(itemID))
    nameLabel:SetText(EntryName(selected))
    if selected.id then
        subtitle:SetText((L["%s  ·  物品 %d"]):format(L[selected.category], itemID))
        description:SetText(FishDetails(selected))
    else
        subtitle:SetText((L["烹饪配方  ·  成品 %d"]):format(itemID))
        description:SetText(CookingDetails(selected))
    end
    content:SetHeight(math.max(256, RenderLocations(selected.id and selected) + 10))
end

local function RenderList()
    firstRow = math.max(1, math.min(firstRow, #filtered - visibleRows + 1))
    for i, row in ipairs(rows) do
        local entry = filtered[firstRow + i - 1]
        row.entry = entry
        row.itemID = entry and (entry.id or entry.itemID)
        row:SetShown(entry ~= nil)
        if entry then
            row.icon:SetTexture(ItemIcon(row.itemID))
            row.label:SetText(EntryName(entry))
            row.active:SetShown(entry == selected)
            row.mark:SetShown(entry == selected)
            row.label:SetTextColor(unpack(entry == selected and colors.gold or colors.text))
        end
    end
    local total = mode == "fish" and #data.entries or #cooking.entries
    count:SetText((L["%d / %d 条"]):format(#filtered, total))
end

for i = 1, visibleRows do
    local row = CreateFrame("Button", nil, list)
    row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * rowHeight)
    row:SetSize(239, 27)
    row.active = Fill(row, "BACKGROUND", colors.selected)
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetPoint("TOPLEFT")
    row.mark:SetPoint("BOTTOMLEFT")
    row.mark:SetWidth(2)
    row.mark:SetColorTexture(unpack(colors.gold))
    theme.Highlight(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(21, 21)
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    row.label = Label(row, "GameFontHighlightSmall", 37, -7, 194)
    row.label:SetMaxLines(1)
    AttachItemTooltip(row)
    row:SetScript("OnClick", function(self)
        selected = self.entry
        details:SetVerticalScroll(0)
        RenderList()
        RenderDetails()
    end)
    rows[i] = row
end

list:SetScript("OnMouseWheel", function(_, delta)
    firstRow = firstRow - delta * 3
    RenderList()
end)

local function Matches(entry, query, numeric)
    if query == "" then return true end
    if entry.id then
        if numeric then return entry.id == numeric end
        return table.concat({ItemName(entry.id), L[entry.category], ZoneNames(entry.zones)}, " "):lower():find(query, 1, true)
    end
    if numeric and (entry.itemID == numeric or entry.spellID == numeric) then return true end
    if not numeric and (EntryName(entry) .. " " .. ItemName(entry.itemID)):lower():find(query, 1, true) then return true end
    for _, material in ipairs(entry.materials) do
        local itemID = material[1]
        if itemID == numeric or (not numeric and ItemName(itemID):lower():find(query, 1, true)) then return true end
    end
    return false
end

local function Filter(query, preferred)
    filtered = {}
    local entries = mode == "fish" and data.entries or cooking.entries
    query = query:match("^%s*(.-)%s*$"):lower()
    local numeric = tonumber(query)
    local selectedIndex
    for _, entry in ipairs(entries) do
        if Matches(entry, query, numeric) then
            filtered[#filtered + 1] = entry
            if entry == preferred then selectedIndex = #filtered end
        end
    end
    selected = filtered[selectedIndex or 1]
    firstRow = selectedIndex or 1
    details:SetVerticalScroll(0)
    RenderList()
    RenderDetails()
end

search:SetScript("OnTextChanged", function(self)
    local query = self:GetText()
    searchHint:SetShown(query == "")
    Filter(query)
end)

local function SelectMode(value, query, preferred)
    mode = value
    for key, tab in pairs(tabs) do
        local active = key == mode
        tab.active:SetShown(active)
        tab.line:SetShown(active)
        tab.label:SetTextColor(active and 0.94 or 0.66, active and 0.75 or 0.74, active and 0.44 or 0.8)
    end
    searchHint:SetText(mode == "fish" and L["搜索鱼名、地点、类别或物品编号"] or L["搜索配方、材料、成品或编号"])
    source:SetText(L["客户端 "] .. data.build .. (mode == "fish" and L["  ·  钓点含经典参考"] or L["  ·  悬停成品图标查看游戏说明"]))
    search:ClearFocus()
    query = query or ""
    if search:GetText() ~= query then search:SetText(query) end
    searchHint:SetShown(query == "")
    Filter(query, preferred)
end

tabs.fish:SetScript("OnClick", function() SelectMode("fish") end)
tabs.cooking:SetScript("OnClick", function() SelectMode("cooking") end)
related:SetScript("OnClick", function() SelectMode("cooking", tostring(selected.id)) end)

function addon.InitializeFishCatalog(db)
    db.fishObservations = db.fishObservations or {}
    observations, quotes = db.fishObservations, db.auctionQuotes
    for itemID in pairs(items) do
        if not C_Item.GetItemInfo(itemID) then C_Item.RequestLoadItemDataByID(itemID) end
    end
    SelectMode("fish")
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
    if itemID and fishByID[itemID] then
        SelectMode("fish", "", fishByID[itemID])
        theme.ShowPanel(panel)
    else
        theme.TogglePanel(panel)
    end
end

panel:SetScript("OnShow", function()
    RenderList()
    RenderDetails()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:SetScript("OnEvent", function(_, _, itemID, success)
    if not success or not items[itemID] or not panel:IsShown() then return end
    if search:GetText() ~= "" then
        Filter(search:GetText(), selected)
    else
        RenderList()
        RenderDetails()
    end
end)
