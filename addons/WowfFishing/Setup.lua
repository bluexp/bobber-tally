local _, addon = ...
local theme = addon.Theme
local colors = theme.colors
local MAIN_HAND, OFF_HAND = 16, 17
local FIRST_SLOT, LAST_SLOT = 1, 19
local EMPTY_LOCATION, IGNORED_LOCATION = 0, 1
local ROW_COUNT = 5
local mainHandTypes = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true }
local db, handlers, step, rod, weapon, page

function addon.IsFishingPole(id)
    if not id or id <= 0 then return false end
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(id)
    return class == 2 and subclass == 20
end

local function CurrentMainHand()
    return GetInventoryItemID("player", MAIN_HAND), GetInventoryItemLink("player", MAIN_HAND)
end

local function SameItem(item, id, link)
    if not item or item.id ~= id then return false end
    local first = item.link and item.link:match("|H(item:[^|]+)|h")
    local second = link and link:match("|H(item:[^|]+)|h")
    return not first or not second or first == second
end

local function Items(wantRod)
    local items = {}
    local function Add(id, link, equipped)
        if not id then return end
        local _, _, _, equipType, icon = C_Item.GetItemInfoInstant(id)
        if wantRod ~= addon.IsFishingPole(id) or (not wantRod and not mainHandTypes[equipType]) then return end
        for _, item in ipairs(items) do
            if SameItem(item, id, link) then return end
        end
        local name = C_Item.GetItemInfo(link or id)
        items[#items + 1] = { id = id, link = link, name = name or ("物品 #%d"):format(id), icon = icon, equipped = equipped }
    end
    local id, link = CurrentMainHand()
    Add(id, link, true)
    if not wantRod then
        Add(GetInventoryItemID("player", OFF_HAND), GetInventoryItemLink("player", OFF_HAND))
    end
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then Add(itemID, C_Container.GetContainerItemLink(bag, slot)) end
        end
    end
    return items
end

local function FindItem(items, selected)
    if not selected then return end
    for _, item in ipairs(items) do
        if SameItem(item, selected.id, selected.link) then return item end
    end
end

local function ItemText(item)
    return item and (item.link or item.name) or "—"
end

local function HandSetID(set)
    if not set then return end
    local api = C_EquipmentSet
    if api.GetEquipmentSetID(set.name) ~= set.id then return end
    local items, ignored = api.GetItemIDs(set.id), api.GetIgnoredSlots(set.id)
    local locations = api.GetItemLocations(set.id)
    if not items or not ignored or not locations or items[MAIN_HAND] ~= set.main
        or math.max(items[OFF_HAND] or 0, 0) ~= set.off then return end
    for slot = FIRST_SLOT, LAST_SLOT do
        local location = locations[slot]
        if slot == MAIN_HAND or slot == OFF_HAND then
            if ignored[slot] or location == IGNORED_LOCATION then return end
            if slot == OFF_HAND and set.off == 0 and location ~= nil and location ~= EMPTY_LOCATION then return end
        elseif (not ignored[slot] and location ~= IGNORED_LOCATION)
            or (location ~= nil and location ~= IGNORED_LOCATION) then
            return
        end
    end
    return set.id
end

function addon.GetSetupEquipment()
    local setup = db.setupEquipment
    if setup then return HandSetID(setup.rod), HandSetID(setup.weapon) end
end

local function ChooseSetName(api, label, snapshot)
    local base = "BobberTally " .. label
    local name, suffix = base, 2
    while true do
        local id = api.GetEquipmentSetID(name)
        if not id then return name end
        snapshot.name, snapshot.id = name, id
        local _, _, _, equipped = api.GetEquipmentSetInfo(id)
        if equipped and HandSetID(snapshot) and not api.GetEquipmentSetAssignedSpec(id) then return name, id end
        name = base .. " " .. suffix
        suffix = suffix + 1
    end
end

local function ApplySaveFlags(api, flags)
    for slot = FIRST_SLOT, LAST_SLOT do
        if flags[slot] then api.IgnoreSlotForSave(slot) else api.UnignoreSlotForSave(slot) end
    end
end

local function SaveHands(label, previous)
    local api = C_EquipmentSet
    local manager = PaperDollFrame and PaperDollFrame.EquipmentManagerPane
    if manager and manager:IsVisible() then
        return nil, "请关闭角色窗口里的装备管理器，然后再保存。"
    end
    if IsInventoryItemLocked and (IsInventoryItemLocked(MAIN_HAND) or IsInventoryItemLocked(OFF_HAND)) then
        return nil, "装备正在切换，请稍等后再保存。"
    end
    local snapshot = {
        main = GetInventoryItemID("player", MAIN_HAND),
        off = GetInventoryItemID("player", OFF_HAND) or 0,
    }
    db.setupPending = db.setupPending or {}
    local pending = db.setupPending
    local name, id = pending[label], nil
    if name then
        id = api.GetEquipmentSetID(name)
        if id and api.GetEquipmentSetAssignedSpec(id) then
            pending[label] = nil
            return nil, "待保存方案已关联专精，请重新保存以创建独立方案。"
        end
    else
        id = HandSetID(previous)
        if id and not api.GetEquipmentSetAssignedSpec(id) then
            name = previous.name
        else
            name, id = ChooseSetName(api, label, snapshot)
            if id then return snapshot end
        end
    end
    if not id and MAX_EQUIPMENT_SETS_PER_PLAYER
        and api.GetNumEquipmentSets() >= MAX_EQUIPMENT_SETS_PER_PLAYER then
        return nil, "装备方案已满，请在装备管理器中腾出一个位置。"
    end

    local original, handsOnly = {}, {}
    for slot = FIRST_SLOT, LAST_SLOT do
        original[slot] = api.IsSlotIgnoredForSave(slot)
        handsOnly[slot] = slot ~= MAIN_HAND and slot ~= OFF_HAND
    end
    snapshot.name = name
    local ran, saved, message = pcall(function()
        if not id then
            pending[label] = name
            ApplySaveFlags(api, handsOnly)
            api.CreateEquipmentSet(name)
            id = api.GetEquipmentSetID(name)
            if not id then return nil, "游戏正在创建方案，请稍等后再试。" end
        end
        -- Creating a set can change the shared ignore flags before it is saved.
        ApplySaveFlags(api, handsOnly)
        api.SaveEquipmentSet(id)
        snapshot.id = id
        if HandSetID(snapshot) then return snapshot end
        return nil, "游戏暂未确认方案内容，请稍等后再试。"
    end)
    ApplySaveFlags(api, original)
    if not ran then error(saved, 0) end
    if saved then
        pending[label] = nil
    end
    return saved, message
end

local function RemovePreviousSet(previous, replacement)
    local id = HandSetID(previous)
    if id and id ~= replacement.id and not C_EquipmentSet.GetEquipmentSetAssignedSpec(id) then
        C_EquipmentSet.DeleteEquipmentSet(id)
    end
end

local wizard = theme.CreatePanel("WowfFishingSetup")
wizard:SetSize(456, 350)
wizard:SetPoint("CENTER", UIParent, "CENTER", 0, 35)
local surface = theme.Surface(wizard)

local Label = theme.Label

Label(wizard, "GameFontHighlight", 16, -4, 360):SetText("无限钓鱼助手 · 配置向导")
local heading = Label(surface, "GameFontNormalLarge", 20, -40, 412, nil, colors.gold)
local description = Label(surface, "GameFontHighlight", 20, -70, 412, nil, colors.muted)
theme.Block(surface, "BORDER", 12, -107, 432, 165, colors.card)
local message = Label(surface, "GameFontHighlightSmall", 20, -277, 412, nil, colors.gold)
local rows = {}
for index = 1, ROW_COUNT do
    local row = CreateFrame("Button", nil, surface)
    row:SetPoint("TOPLEFT", 20, -116 - (index - 1) * 27)
    row:SetSize(412, 26)
    row.active = theme.Fill(row, "BACKGROUND", colors.selected)
    row.mark = theme.Block(row, "BORDER", 0, 0, 2, 26, colors.gold)
    theme.Highlight(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 7, 0)
    row.icon:SetSize(21, 21)
    row.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    row.label = Label(row, "GameFontHighlight", 36, -6, 365)
    row.label:SetMaxLines(1)
    row:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item.link then
            GameTooltip:SetHyperlink(self.item.link)
        else
            GameTooltip:SetItemByID(self.item.id)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
end

local keyLabel = Label(surface, "GameFontHighlight", 20, -184, 210, nil, colors.muted)
keyLabel:SetText("一键换装快捷键")
local keyButton = theme.Button(surface, "WowfFishingSetupKey", "点击录入", 192, 24, true)
keyButton:SetPoint("TOPLEFT", 173, -177)
local selectedKey, keyCapture

local function KeyChord(key)
    if CreateKeyChordStringUsingMetaKeyState then
        return CreateKeyChordStringUsingMetaKeyState(key)
    end
    return (IsAltKeyDown() and "ALT-" or "")
        .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end

local activeCapture
local modifierKeys = { ALT = true, CTRL = true, SHIFT = true, META = true, CMD = true }

function addon.CreateKeyCapture(parent, name, validate, accept, refresh)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetPropagateKeyboardInput(false)
    frame:EnableKeyboard(false)
    local releaseKey, chord

    function frame:IsListening()
        return activeCapture == self
    end

    function frame:StopListening(acceptedKey)
        if not self:IsListening() then return end
        activeCapture, releaseKey, chord = nil, nil, nil
        self:EnableKeyboard(false)
        if acceptedKey then accept(acceptedKey) end
        refresh()
    end

    function frame:ToggleListening()
        if self:IsListening() then
            self:StopListening()
        elseif InCombatLockdown() then
            refresh("请脱离战斗后再录入快捷键。")
        else
            if activeCapture then activeCapture:StopListening() end
            activeCapture = self
            self:EnableKeyboard(true)
            refresh()
        end
    end

    frame:SetScript("OnKeyDown", function(self, key)
        if not self:IsListening() or releaseKey or modifierKeys[key:gsub("^[LR]", "")] then return end
        releaseKey = key
        if key ~= "ESCAPE" then chord = KeyChord(key) end
    end)
    frame:SetScript("OnKeyUp", function(self, key)
        if not self:IsListening() or key ~= releaseKey then return end
        if not chord then
            self:StopListening()
            return
        end
        local acceptedKey, errorMessage = validate(chord)
        if acceptedKey then
            self:StopListening(acceptedKey)
        else
            releaseKey, chord = nil, nil
            refresh(errorMessage)
        end
    end)
    frame:SetScript("OnEvent", function(self) self:StopListening() end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    parent:HookScript("OnHide", function() frame:StopListening() end)
    return frame
end

local summary = Label(surface, "GameFontHighlight", 20, -116, 412, nil, colors.text)

local previousPage = theme.Button(surface, nil, "上页", 41, 22)
previousPage:SetPoint("TOPLEFT", 20, -250)
local nextPage = theme.Button(surface, nil, "下页", 41, 22)
nextPage:SetPoint("LEFT", previousPage, "RIGHT", 52, 0)
local pageLabel = Label(surface, "GameFontHighlightSmall", 63, -255, 48, "CENTER", colors.muted)
local back = theme.Button(surface, nil, "上一步", 77, 25)
back:SetPoint("BOTTOMLEFT", 18, 15)
local equip = theme.Button(surface, nil, "装备所选", 100, 25)
equip:SetPoint("BOTTOMRIGHT", -155, 15)
local nextStep = theme.Button(surface, nil, "下一步", 130, 25, true)
nextStep:SetPoint("BOTTOMRIGHT", -18, 15)

local function Render(notice)
    local capturingKey = keyCapture:IsListening()
    local rodPage, weaponPage = step == 1, step == 2
    local items = step == 3 and {} or Items(rodPage)
    local chosen
    if rodPage then
        rod = FindItem(items, rod) or items[1]
        chosen = rod
    elseif weaponPage then
        weapon = FindItem(items, weapon) or items[1]
        chosen = weapon
    end
    local pageCount = math.max(1, math.ceil(#items / ROW_COUNT))
    page = math.min(page, pageCount)
    for index, row in ipairs(rows) do
        local item = items[(page - 1) * ROW_COUNT + index]
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.icon:SetTexture(item.icon)
            row.active:SetShown(item == chosen)
            row.mark:SetShown(item == chosen)
            row.label:SetTextColor(unpack(item == chosen and colors.gold or colors.text))
            row.label:SetText(ItemText(item) .. (item.equipped and "  |cff9cbaca已装备|r" or ""))
        end
    end
    previousPage:SetShown(pageCount > 1)
    nextPage:SetShown(pageCount > 1)
    previousPage:SetEnabled(page > 1)
    nextPage:SetEnabled(page < pageCount)
    pageLabel:SetText(pageCount > 1 and ("%d / %d"):format(page, pageCount) or "")
    back:SetShown(not rodPage)
    local selected = rod
    if weaponPage then selected = weapon end
    local equipped = SameItem(selected, CurrentMainHand())
    local available = step == 3 and FindItem(Items(true), rod) or chosen
    equip:SetShown(not rodPage and available ~= nil and not equipped)
    equip:SetText(weaponPage and "装备所选武器" or "装备所选鱼竿")
    keyLabel:SetShown(step == 3)
    keyButton:SetShown(step == 3)
    keyButton:SetText(capturingKey and "请按快捷键…" or selectedKey or "点击录入")
    summary:SetShown(step == 3)
    local ready = (rodPage and rod ~= nil) or (not rodPage and equipped)
    nextStep:SetEnabled(ready and (step ~= 3 or (selectedKey ~= nil and not capturingKey)))
    nextStep:SetText(step == 3 and "保存并显示按钮" or "下一步")
    message:SetText(notice or "")
    if rodPage then
        heading:SetText("1 / 3  选择鱼竿")
        description:SetText(rod and "从背包或主手中选择一根鱼竿。"
            or "没有找到鱼竿。请向钓鱼用品商人购买一根，放入背包后会自动刷新。")
    elseif weaponPage then
        heading:SetText("2 / 3  选择换回的武器")
        description:SetText("选择并装备要换回的主手武器。当前副手会一起记录。")
        if not weapon and not notice then message:SetText("请将可装备的主手武器放入背包。") end
    else
        heading:SetText("3 / 3  设置快捷键")
        description:SetText("装备所选鱼竿，点击快捷键按钮后按键，再保存。")
        summary:SetText("鱼竿  " .. ItemText(rod) .. "\n武器  " .. ItemText(weapon))
        if not notice then
            message:SetText(available and (capturingKey and "按下快捷键，或按 Esc 取消录入。"
                or "可录入字母、数字、F1–F12、小键盘和组合键。")
                or "所选鱼竿不在身上，请找回鱼竿或返回重选。")
        end
    end
end

for _, row in ipairs(rows) do
    row:SetScript("OnClick", function(self)
        if step == 1 then rod = self.item else weapon = self.item end
        Render()
    end)
end
previousPage:SetScript("OnClick", function()
    page = page - 1
    Render()
end)
nextPage:SetScript("OnClick", function()
    page = page + 1
    Render()
end)
back:SetScript("OnClick", function()
    keyCapture:StopListening()
    step, page = step - 1, 1
    Render()
end)

equip:SetScript("OnClick", function()
    keyCapture:StopListening()
    if InCombatLockdown() then
        Render("请脱离战斗后再换装。")
        return
    end
    local selected = step == 2 and weapon or rod
    local item = FindItem(Items(step == 3), selected)
    if not item then
        Render("找不到所选物品，请重新选择。")
        return
    end
    local equipItem = C_Item.EquipItemByName or EquipItemByName
    if equipItem then equipItem(item.link or item.id, MAIN_HAND) end
    local waiting = not SameItem(item, CurrentMainHand())
    Render(waiting and "装备完成后可继续。如未生效，请从背包手动装备所选物品。" or nil)
end)

nextStep:SetScript("OnClick", function()
    if InCombatLockdown() then
        Render("请脱离战斗后再继续。")
        return
    end
    if step == 1 then
        if not FindItem(Items(true), rod) then Render(); return end
        step, page = 2, 1
    elseif step == 2 then
        if not SameItem(weapon, CurrentMainHand()) then Render(); return end
        if not C_EquipmentSet.CanUseEquipmentSets() then
            Render("装备管理器暂不可用，请稍后再试。")
            return
        end
        local draft, saveError = SaveHands("武器", db.setupDraft)
        if not draft then
            Render(saveError)
            return
        end
        db.setupDraft = draft
        step, page = 3, 1
    else
        local key, errorMessage = handlers.validateKey(selectedKey or "")
        if not key then
            Render(errorMessage)
            return
        end
        if not SameItem(rod, CurrentMainHand()) then Render(); return end
        if not HandSetID(db.setupDraft) then
            step, page = 2, 1
            Render("武器方案已变更，请重新记录武器。")
            return
        end
        local old = db.setupEquipment
        local rodSet, saveError = SaveHands("鱼竿", old and old.rod)
        if not rodSet then
            Render(saveError)
            return
        end
        db.setupEquipment = { rod = rodSet, weapon = db.setupDraft }
        db.setupDraft = nil
        if old then RemovePreviousSet(old.weapon, db.setupEquipment.weapon) end
        handlers.saveKey(key)
        wizard:Hide()
        handlers.say("配置已保存。点击屏幕按钮或按 " .. key .. " 可切换鱼竿与武器。")
        return
    end
    Render()
end)

wizard:SetScript("OnEvent", function()
    if wizard:IsShown() then Render() end
end)
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
    wizard:RegisterEvent(event)
end

function addon.ShowSetup()
    if wizard:IsShown() then wizard:Raise(); return end
    step, page = 1, 1
    local setup = db.setupEquipment
    rod = setup and { id = setup.rod.main } or nil
    weapon = setup and { id = setup.weapon.main } or nil
    selectedKey = handlers.key()
    theme.ShowPanel(wizard)
    Render()
end

function addon.InitializeSetup(settings, callbacks)
    db, handlers = settings, callbacks
    if not keyCapture then
        keyCapture = addon.CreateKeyCapture(wizard, "WowfFishingSetupKeyCapture", function(chord)
            return handlers.validateKey(chord)
        end, function(key)
            selectedKey = key
        end, Render)
        keyButton:SetScript("OnClick", function() keyCapture:ToggleListening() end)
    end
end
