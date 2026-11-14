local _, addon = ...
local L, theme = addon.L, addon.Theme
local colors, Label = theme.colors, theme.Label
local MAIN_HAND, OFF_HAND = 16, 17
local slotLabels = { "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "SHIRTSLOT", "CHESTSLOT", "WAISTSLOT",
    "LEGSSLOT", "FEETSLOT", "WRISTSLOT", "HANDSSLOT", "FINGER0SLOT", "FINGER1SLOT",
    "TRINKET0SLOT", "TRINKET1SLOT", "BACKSLOT", "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT", "TABARDSLOT" }

local function ItemName(id)
    if not id or id <= 0 then return L["空槽"] end
    return C_Item.GetItemInfo(id) or L["物品 #%d"]:format(id)
end

local function ItemRow(parent, y, title)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", 30, y)
    button:SetSize(390, 22)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT")
    icon:SetSize(20, 20)
    addon.SetLocalizedText(Label(button, "GameFontHighlightSmall", 29, -5, 56, nil, colors.muted), title)
    local value = Label(button, "GameFontHighlight", 88, -4, 302)
    value:SetMaxLines(1)
    button:SetScript("OnEnter", function(self)
        if not self.itemID or self.itemID <= 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return function(id, configured)
        button.itemID = id
        local hasItem = id and id > 0
        if hasItem then icon:SetTexture(theme.ItemIcon(id)) end
        icon:SetShown(not not hasItem)
        value:SetText(configured and ItemName(id) or "—")
    end
end

function addon.GetGearSetIssue(set, reason, slot, actual)
    local slotName = slot and (slot == MAIN_HAND and L["主手"] or slot == OFF_HAND and L["副手"]
        or _G[slotLabels[slot]] or L["装备槽 %d"]:format(slot))
    if reason == "missingSet" then return "未找到方案：%s", set.name end
    if reason == "changed" then return "%s与保存时不同，当前方案为：%s", slotName, ItemName(actual) end
    if reason == "ignored" then return "方案忽略了%s", slotName end
    if reason == "notEmpty" then return "%s应为空槽", slotName end
    if reason == "extraSlot" then return "方案会改动%s", slotName end
    if reason == "unconfigured" then return "尚未设置" end
    return "装备管理器暂不可用，请稍后再试。"
end

local function UpdateCard(card, set, id, status, color)
    card.name:SetText(set and set.name or "—")
    card.main(set and set.main, set ~= nil)
    card.off(set and set.off, set ~= nil)
    if id then
        local _, _, _, _, _, _, _, missing = C_EquipmentSet.GetEquipmentSetInfo(id)
        if missing and missing > 0 then
            status, color = L["找不到所需装备，请检查背包。"], colors.gold
        end
    end
    card.status:SetText(status)
    card.status:SetTextColor(unpack(color))
end

function addon.CreateGearStatus(parent, db, gearKey, inspectSet)
    addon.SetLocalizedText(Label(parent, "GameFontNormalLarge", 20, -24, 266, nil, colors.gold), "换装方案")
    local key = Label(parent, "GameFontHighlightSmall", 286, -27, 150, "RIGHT", colors.muted)
    local current = Label(parent, "GameFontHighlightSmall", 20, -48, 416, nil, colors.text)
    current:SetMaxLines(2)
    local cards = {}
    for index, title in ipairs({ "鱼竿", "武器" }) do
        local y = -85 - (index - 1) * 116
        theme.Block(parent, "BORDER", 20, y, 416, 108, colors.card)
        addon.SetLocalizedText(Label(parent, "GameFontHighlight", 30, y - 7, 76, nil, colors.gold), title)
        local name = Label(parent, "GameFontHighlightSmall", 110, y - 9, 310, "RIGHT", colors.muted)
        name:SetMaxLines(1)
        local status = Label(parent, "GameFontHighlightSmall", 30, y - 73, 390)
        status:SetMaxLines(2)
        cards[index] = { name = name, status = status, main = ItemRow(parent, y - 25, "主手"),
            off = ItemRow(parent, y - 48, "副手") }
    end
    theme.Block(parent, "BORDER", 20, -319, 416, 63, colors.card)
    local result = Label(parent, "GameFontHighlightSmall", 30, -328, 273, nil, colors.gold)
    result:SetMaxLines(1)
    local resultTime = Label(parent, "GameFontHighlightSmall", 303, -328, 119, "RIGHT", colors.muted)
    local reason = Label(parent, "GameFontHighlightSmall", 30, -347, 392, nil, colors.text)
    reason:SetMaxLines(2)
    local notice = Label(parent, "GameFontHighlightSmall", 20, -398, 265, nil, colors.muted)
    notice:SetMaxLines(2)
    local edit = theme.Button(parent, nil, "打开换装向导", 144, 26, true)
    edit:SetPoint("BOTTOMRIGHT", -20, 24)
    edit:SetScript("OnClick", function() addon.ShowSetup("setup") end)

    local function ShowSaved(card, set, main, off)
        local id, reason, slot, actual = inspectSet(set)
        if not id then
            local color = reason == "unconfigured" and colors.muted or colors.gold
            local message, a, b = addon.GetGearSetIssue(set, reason, slot, actual)
            UpdateCard(card, set, nil, L[message]:format(a, b), color)
            return
        end
        local equipped = main == set.main and off == set.off
        UpdateCard(card, set, id, equipped and L["当前已装备 · 方案可用"] or L["方案可用"], colors.text)
    end

    local function ShowLegacy(card, name, id, isRod)
        local items = id and C_EquipmentSet.GetItemIDs(id)
        if not items then
            local issue = id and L["装备管理器暂不可用，请稍后再试。"] or L["未找到方案：%s"]:format(name)
            UpdateCard(card, nil, nil, issue, colors.gold)
            return
        end
        local set = { name = name, main = items[MAIN_HAND], off = items[OFF_HAND] }
        if isRod and not addon.IsFishingPole(set.main) then
            UpdateCard(card, set, nil, L["方案 F 的主手不是鱼竿。"], colors.gold)
        else
            UpdateCard(card, set, id, L["装备管理器方案（旧版）"], colors.muted)
        end
    end

    return function(message)
        local main = GetInventoryItemID("player", MAIN_HAND)
        local off = GetInventoryItemID("player", OFF_HAND) or 0
        current:SetText(L["当前装备：%s / %s"]:format(ItemName(main), ItemName(off)))
        key:SetText(L["换装键：%s"]:format(gearKey() or L["尚未设置"]))
        if message ~= nil then notice:SetText(message) end
        local last = db.lastGearSwap
        local pending = addon.GetPendingGearSwap()
        resultTime:SetText(not pending and last and date("%m-%d %H:%M:%S", last.time) or "")
        if pending then
            result:SetText(L["换装中：%s"]:format(pending))
            reason:SetText(L["换装中，等待确认主副手…"])
        elseif last then
            local state = last.success and L["换装成功"] or L["换装失败"]
            result:SetText(L["最近换装：%s · %s"]:format(state, last.target))
            reason:SetText(L[last.message]:format(unpack(last.args or {})))
        else
            result:SetText(L["最近换装：暂无记录"])
            reason:SetText("")
        end
        local setup = db.setupEquipment
        local api = C_EquipmentSet
        if setup then
            ShowSaved(cards[1], setup.rod, main, off)
            ShowSaved(cards[2], setup.weapon, main, off)
        else
            local rodID, weaponID = api.GetEquipmentSetID("F"), api.GetEquipmentSetID("W")
            if db.useM or rodID or weaponID then
                ShowLegacy(cards[1], "F", rodID, true)
                ShowLegacy(cards[2], "W", weaponID, false)
            else
                ShowSaved(cards[1])
                ShowSaved(cards[2])
            end
        end
    end
end
