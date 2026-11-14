local _, addon = ...
local L = addon.L
local theme = addon.Theme
local colors = theme.colors
local MAIN_HAND, OFF_HAND = 16, 17
local FIRST_SLOT, LAST_SLOT = 1, 19
local EMPTY_LOCATION, IGNORED_LOCATION, MISSING_LOCATION = 0, 1, -1
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
        items[#items + 1] = { id = id, link = link, name = name or (L["物品 #%d"]):format(id), icon = icon, equipped = equipped }
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
    if not set then return nil, "unconfigured" end
    local api = C_EquipmentSet
    -- Resolve the current ID by name, then verify the set before using it.
    local id = api.GetEquipmentSetID(set.name)
    if not id then
        if not api.CanUseEquipmentSets() then return nil, "unavailable" end
        return nil, "missingSet"
    end
    local items, ignored = api.GetItemIDs(id), api.GetIgnoredSlots(id)
    local locations = api.GetItemLocations(id)
    if not items or not ignored or not locations then return nil, "unavailable" end
    local off = math.max(items[OFF_HAND] or 0, 0)
    if items[MAIN_HAND] ~= set.main then return nil, "changed", MAIN_HAND, items[MAIN_HAND] end
    if off ~= set.off then return nil, "changed", OFF_HAND, off end
    for slot = FIRST_SLOT, LAST_SLOT do
        local location = locations[slot]
        if slot == MAIN_HAND or slot == OFF_HAND then
            if ignored[slot] or location == IGNORED_LOCATION then return nil, "ignored", slot end
            -- An unavailable empty off hand is valid only if the set explicitly includes that slot.
            if slot == OFF_HAND and off == 0 and location ~= nil and location ~= EMPTY_LOCATION
                and not (location == MISSING_LOCATION and ignored[slot] == false) then return nil, "notEmpty", slot end
        elseif location ~= IGNORED_LOCATION and not (ignored[slot] and (location == nil
            or (location == MISSING_LOCATION and (items[slot] or 0) <= 0))) then
            return nil, "extraSlot", slot
        end
    end
    return id
end

function addon.GetSetupEquipment()
    local setup = db.setupEquipment
    if not setup then return end
    local rodID, reason, slot, actual = HandSetID(setup.rod)
    if not rodID then return nil, nil, setup.rod, reason, slot, actual end
    local weaponID
    weaponID, reason, slot, actual = HandSetID(setup.weapon)
    return rodID, weaponID, not weaponID and setup.weapon or nil, reason, slot, actual
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

local function EquipmentSaveError()
    local api = C_EquipmentSet
    local manager = PaperDollFrame and PaperDollFrame.EquipmentManagerPane
    if manager and manager:IsVisible() then
        return L["请关闭角色窗口里的装备管理器，然后再保存。"]
    end
    if not api.CanUseEquipmentSets() then
        return L["装备管理器暂不可用，请稍后再试。"]
    end
end

local function HandsLocked()
    return IsInventoryItemLocked and (IsInventoryItemLocked(MAIN_HAND) or IsInventoryItemLocked(OFF_HAND))
end

local function SaveHands(label, previous, attempt)
    local api = C_EquipmentSet
    local snapshot = {
        main = GetInventoryItemID("player", MAIN_HAND),
        off = GetInventoryItemID("player", OFF_HAND) or 0,
    }
    db.setupPending = db.setupPending or {}
    local pending = db.setupPending
    if attempt.hands and (attempt.hands.main ~= snapshot.main or attempt.hands.off ~= snapshot.off) then
        return nil, L["装备已变化，请确认主副手后重试。"]
    end
    attempt.hands = snapshot
    if attempt.saved then
        if not HandSetID(attempt.saved) then return nil, nil, true end
        pending[label] = nil
        return attempt.saved
    end

    local name, id = pending[label], nil
    if name then
        id = api.GetEquipmentSetID(name)
        if not id and attempt.creating then return nil, nil, true end
        if id and api.GetEquipmentSetAssignedSpec(id) then
            pending[label] = nil
            return nil, L["待保存方案已关联专精，请重新保存以创建独立方案。"]
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
        return nil, L["装备方案已满，请在装备管理器中腾出一个位置。"]
    end

    local original, handsOnly = {}, {}
    for slot = FIRST_SLOT, LAST_SLOT do
        original[slot] = api.IsSlotIgnoredForSave(slot)
        handsOnly[slot] = slot ~= MAIN_HAND and slot ~= OFF_HAND
    end
    snapshot.name = name
    local ran, saved, retry = pcall(function()
        if not id then
            pending[label] = name
            attempt.creating = true
            ApplySaveFlags(api, handsOnly)
            api.CreateEquipmentSet(name)
            id = api.GetEquipmentSetID(name)
            if not id then return nil, true end
        end
        -- Creating a set can change the shared ignore flags before it is saved.
        ApplySaveFlags(api, handsOnly)
        api.SaveEquipmentSet(id)
        snapshot.id = id
        attempt.saved = snapshot
        if HandSetID(snapshot) then return snapshot end
        return nil, true
    end)
    ApplySaveFlags(api, original)
    if not ran then error(saved, 0) end
    if saved then
        pending[label] = nil
    end
    return saved, nil, retry
end

local function RemovePreviousSet(previous, replacement)
    local id = HandSetID(previous)
    if id and id == previous.id and id ~= replacement.id and not C_EquipmentSet.GetEquipmentSetAssignedSpec(id) then
        C_EquipmentSet.DeleteEquipmentSet(id)
    end
end

local wizard = theme.CreatePanel("WowfFishingSetup")
wizard:SetSize(456, 430)
wizard:SetPoint("CENTER", UIParent, "CENTER", 314, 35)
wizard:SetMovable(true)
local titleDrag = CreateFrame("Frame", nil, wizard)
titleDrag:SetPoint("TOPLEFT", 6, 0)
titleDrag:SetSize(416, 21)
titleDrag:EnableMouse(true)
titleDrag:RegisterForDrag("LeftButton")
titleDrag:SetScript("OnDragStart", function() wizard:StartMoving() end)
titleDrag:SetScript("OnDragStop", function() wizard:StopMovingOrSizing() end)
wizard:HookScript("OnHide", wizard.StopMovingOrSizing)
local background = theme.Surface(wizard)
local function Page()
    local frame = CreateFrame("Frame", nil, background)
    frame:SetPoint("TOPLEFT", background, "TOPLEFT", 0, -44)
    frame:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT")
    frame:Hide()
    return frame
end
local surface, fishingPage, gearPage = Page(), Page(), Page()
local tabMarks = {}
for index, tab in ipairs({ { "fishing", "钓鱼操作" }, { "gear", "换装方案" }, { "setup", "换装向导" } }) do
    local tabID = tab[1]
    local button = theme.Button(background, nil, tab[2], 134, 24)
    button:SetPoint("TOPLEFT", 20 + (index - 1) * 141, -32)
    button:SetScript("OnClick", function() addon.ShowSetup(tabID) end)
    tabMarks[tabID] = theme.Block(button, "ARTWORK", 0, -22, 134, 2, colors.gold)
end
local currentTab, fishingSettings, gearStatus

local Label = theme.Label

addon.SetLocalizedText(Label(wizard, "GameFontHighlight", 16, -4, 360), "无限钓鱼助手 · 钓鱼设置")
local progress = {}
for i, title in ipairs({ "1  鱼竿", "2  武器", "3  完成" }) do
    local x = 20 + (i - 1) * 140
    progress[i] = {
        fill = theme.Block(surface, "BORDER", x, -36, 132, 24, colors.card),
        label = Label(surface, "GameFontHighlightSmall", x, -42, 132, "CENTER", colors.muted),
        title = title,
    }
end
local heading = Label(surface, "GameFontNormalLarge", 20, -72, 416, nil, colors.gold)
local description = Label(surface, "GameFontHighlight", 20, -96, 416, nil, colors.muted)
theme.Block(surface, "BORDER", 12, -138, 432, 148, colors.card)
local message = Label(surface, "GameFontHighlightSmall", 20, -315, 416, nil, colors.gold)
local itemList = CreateFrame("Frame", nil, surface)
itemList:SetPoint("TOPLEFT", 20, -144)
itemList:SetSize(416, 136)
itemList:EnableMouseWheel(true)
local rows = {}
for index = 1, ROW_COUNT do
    local row = CreateFrame("Button", nil, itemList)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 27)
    row:SetSize(416, 26)
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

local keyLabel = Label(surface, "GameFontHighlight", 28, -246, 190, nil, colors.muted)
addon.SetLocalizedText(keyLabel, "一键换装快捷键")
local keyButton = theme.Button(surface, "WowfFishingSetupKey", "", 144, 26)
keyButton:SetPoint("TOPLEFT", 192, -240)
local useKey = theme.Button(surface, nil, "使用此键", 86, 26, true)
useKey:SetPoint("LEFT", keyButton, "RIGHT", 6, 0)
local selectedKey, selectedOverride, keyCapture

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
    local releaseKey, chord, conflict

    function frame:IsListening()
        return activeCapture == self
    end

    function frame:StopListening(acceptedKey, override)
        if not self:IsListening() then return end
        activeCapture, releaseKey, chord, conflict = nil, nil, nil, nil
        self:EnableKeyboard(false)
        if acceptedKey then accept(acceptedKey, override) end
        refresh()
    end

    local function Accept(input, override)
        local acceptedKey, errorMessage, canOverride = validate(input, override)
        if acceptedKey then
            frame:StopListening(acceptedKey, override)
        else
            conflict = canOverride and input or nil
            refresh(conflict and L["%s 已被游戏占用。使用此键会暂时覆盖原操作。"]:format(input) or errorMessage)
        end
    end

    function frame:HasConflict()
        return conflict ~= nil
    end

    function frame:UseConflictingKey()
        if self:IsListening() and conflict and not releaseKey and not InCombatLockdown() then
            Accept(conflict, true)
        end
    end

    function frame:AttachButton(button)
        button:RegisterForClicks("AnyUp")
        button:SetScript("OnClick", function(_, mouseButton)
            if mouseButton == "Button4" or mouseButton == "Button5" then
                if self:IsListening() and not releaseKey and not InCombatLockdown() then
                    Accept(KeyChord(mouseButton:upper()))
                end
            elseif not mouseButton or mouseButton == "LeftButton" then
                self:ToggleListening()
            end
        end)
    end

    function frame:ToggleListening()
        if self:IsListening() then
            self:StopListening()
        elseif InCombatLockdown() then
            refresh(L["请脱离战斗后再录入快捷键。"])
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
        local input = chord
        releaseKey, chord = nil, nil
        Accept(input)
    end)
    frame:SetScript("OnEvent", function(self) self:StopListening() end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    parent:HookScript("OnHide", function() frame:StopListening() end)
    return frame
end

local summary = {}
for i, title in ipairs({ "鱼竿", "武器" }) do
    local y = -152 - (i - 1) * 39
    local icon = surface:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("TOPLEFT", 28, y)
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    local label = Label(surface, "GameFontHighlightSmall", 64, y - 7, 74, nil, colors.muted)
    addon.SetLocalizedText(label, title)
    local value = Label(surface, "GameFontHighlight", 140, y - 6, 280)
    value:SetMaxLines(1)
    summary[i] = { icon = icon, label = label, value = value }
end

local previousPage = theme.Button(surface, nil, "上页", 41, 22)
previousPage:SetPoint("TOPLEFT", 20, -291)
local nextPage = theme.Button(surface, nil, "下页", 41, 22)
nextPage:SetPoint("LEFT", previousPage, "RIGHT", 52, 0)
local pageLabel = Label(surface, "GameFontHighlightSmall", 63, -296, 48, "CENTER", colors.muted)
local back = theme.Button(surface, nil, "上一步", 92, 28)
back:SetPoint("BOTTOMLEFT", 18, 15)
local nextStep = theme.Button(surface, nil, "", 172, 28, true)
nextStep:SetPoint("BOTTOMRIGHT", -18, 15)
local pending, lastNotice

local function Render(notice)
    lastNotice = notice
    local capturingKey = keyCapture:IsListening()
    local rodPage, weaponPage = step == 1, step == 2
    local finishPage, combat = step == 3, InCombatLockdown()
    for i, entry in ipairs(progress) do
        entry.fill:SetColorTexture(unpack(step == i and colors.selected or colors.card))
        entry.label:SetTextColor(unpack(step == i and colors.gold or colors.muted))
        entry.label:SetText(L[entry.title])
    end
    local items = finishPage and {} or Items(rodPage)
    local chosen
    if rodPage then
        rod = FindItem(items, rod) or items[1]
        chosen = rod
    elseif weaponPage then
        weapon = FindItem(items, weapon) or items[1]
        chosen = weapon
    end
    local pageCount = math.max(1, math.ceil(#items / ROW_COUNT))
    if not page then
        for index, item in ipairs(items) do
            if item == chosen then page = math.ceil(index / ROW_COUNT); break end
        end
    end
    page = math.min(page or 1, pageCount)
    itemList:SetShown(not finishPage)
    for index, row in ipairs(rows) do
        local item = items[(page - 1) * ROW_COUNT + index]
        row.item = item
        row:SetShown(item ~= nil)
        row:SetEnabled(not pending)
        if item then
            row.icon:SetTexture(item.icon)
            row.active:SetShown(item == chosen)
            row.mark:SetShown(item == chosen)
            row.label:SetTextColor(unpack(item == chosen and colors.gold or colors.text))
            row.label:SetText(ItemText(item) .. (item.equipped and L["  |cff9cbaca已装备|r"] or ""))
        end
    end
    previousPage:SetShown(pageCount > 1)
    nextPage:SetShown(pageCount > 1)
    previousPage:SetEnabled(not pending and page > 1)
    nextPage:SetEnabled(not pending and page < pageCount)
    pageLabel:SetText(pageCount > 1 and ("%d / %d"):format(page, pageCount) or "")
    back:SetShown(not rodPage)
    local selected = rod
    if weaponPage then selected = weapon end
    local equipped = SameItem(selected, CurrentMainHand())
    local available = finishPage and FindItem(Items(true), rod) or chosen
    local validKey = finishPage and selectedKey and handlers.validateKey(selectedKey, selectedOverride)
    keyLabel:SetShown(finishPage)
    keyButton:SetShown(finishPage)
    keyButton:SetEnabled(not pending and not combat)
    keyButton:SetText(capturingKey and L["请按快捷键…"] or selectedKey or L["点击录入"])
    useKey:SetShown(finishPage and keyCapture:HasConflict())
    for i, entry in ipairs(summary) do
        local item = i == 1 and rod or weapon
        entry.icon:SetShown(finishPage)
        entry.label:SetShown(finishPage)
        entry.value:SetShown(finishPage)
        if finishPage then
            entry.icon:SetTexture(item and item.icon)
            entry.value:SetText(ItemText(item))
        end
    end
    nextStep:SetEnabled(available ~= nil and not pending and not combat and not capturingKey)
    local action = rodPage and "下一步"
        or (weaponPage and (equipped and "记录武器并继续" or "装备武器并继续"))
        or (not validKey and "录入换装键")
        or (equipped and "保存换装方案" or "装备鱼竿并保存")
    nextStep:SetText(L[pending and pending.action or action])
    local hint
    if rodPage then
        heading:SetText(L["选择鱼竿"])
        description:SetText(L["从背包或主手中选择一根鱼竿。"])
        if not rod then hint = L["没有找到鱼竿。请向钓鱼用品商人购买一根，放入背包后会自动刷新。"] end
    elseif weaponPage then
        heading:SetText(L["选择换回的武器"])
        description:SetText(L["选择要换回的主手武器。装备后会一并记录当时的副手。"])
        if not weapon then hint = L["请将可装备的主手武器放入背包。"] end
    else
        heading:SetText(L["确认换装方案"])
        description:SetText(L["确认鱼竿和武器，录好换装键后即可保存。"])
        hint = not available and L["所选鱼竿不在身上，请找回鱼竿或返回重选。"]
            or (capturingKey and L["按键盘键，或在录入按钮上按鼠标侧键。Esc 取消。"])
            or (not validKey and L["支持键盘、小键盘、鼠标侧键和组合键。"])
    end
    message:SetText(notice or (combat and L["请脱离战斗后再继续。"]) or hint or "")
end

for _, row in ipairs(rows) do
    row:SetScript("OnClick", function(self)
        if not self.item or pending then return end
        if step == 1 then rod = self.item else weapon = self.item end
        Render()
    end)
end
local function TurnPage(direction)
    if pending then return end
    page = math.max(1, page + direction)
    Render()
end
previousPage:SetScript("OnClick", function() TurnPage(-1) end)
nextPage:SetScript("OnClick", function() TurnPage(1) end)
itemList:SetScript("OnMouseWheel", function(_, delta)
    TurnPage(delta > 0 and -1 or 1)
end)
back:SetScript("OnClick", function()
    pending = nil
    keyCapture:StopListening()
    step, page = step - 1, nil
    Render()
end)

local function Finish(notice)
    pending = nil
    Render(notice)
end

local function CheckWeaponDraft()
    if weapon and db.setupDraft and db.setupDraft.main == weapon.id and HandSetID(db.setupDraft) then
        return true
    end
    step, page = 2, nil
    Finish(L["武器方案已变更，请重新记录武器。"])
end

local function Advance(attempt)
    if pending ~= attempt then return end
    if InCombatLockdown() then Finish(L["请脱离战斗后再继续。"]); return end
    local saveError = EquipmentSaveError()
    if saveError then Finish(saveError); return end
    if step == 3 and not CheckWeaponDraft() then return end

    local function Wait(action, notice, timeoutNotice)
        if GetTime() >= attempt.deadline then
            Finish(timeoutNotice)
            return
        end
        if attempt.action ~= action or lastNotice ~= notice then
            attempt.action = action
            Render(notice)
        end
        C_Timer.After(0.12, function() Advance(attempt) end)
    end

    if not SameItem(attempt.item, CurrentMainHand()) then
        if attempt.hands then Finish(L["装备已变化，请确认主副手后重试。"]); return end
        Wait("正在装备…", L["等待游戏完成装备切换。"], L["未能装备所选物品，请从背包手动装备后重试。"])
        return
    elseif HandsLocked() then
        Wait("正在装备…", L["等待游戏完成装备切换。"], L["装备正在切换，请稍等后再保存。"])
        return
    end

    local key
    if step == 3 then
        key, saveError = handlers.validateKey(selectedKey or "", selectedOverride)
        if not key then Finish(saveError); return end
    end
    local old = db.setupEquipment
    local set, errorMessage, retry
    if step == 2 then
        set, errorMessage, retry = SaveHands("武器", db.setupDraft, attempt)
    else
        set, errorMessage, retry = SaveHands("鱼竿", old and old.rod, attempt)
    end
    if retry then
        Wait("正在保存…", L["等待游戏确认装备方案。"], L["游戏暂未确认方案内容，请稍等后再试。"])
        return
    end
    if not set then Finish(errorMessage); return end
    if step == 2 then
        db.setupDraft = set
        step, page = 3, nil
        Finish()
        return
    end

    pending = nil
    db.setupEquipment = { rod = set, weapon = db.setupDraft }
    db.setupDraft = nil
    if old then RemovePreviousSet(old.weapon, db.setupEquipment.weapon) end
    handlers.saveKey(key)
    step = nil
    addon.ShowSetup("gear", L["换装方案已保存。"])
    handlers.say(L["配置已保存。点击屏幕按钮或按 "] .. key .. L[" 可切换鱼竿与武器。"])
end

nextStep:SetScript("OnClick", function()
    if pending or keyCapture:IsListening() or InCombatLockdown() then return end
    if step == 1 then
        if not FindItem(Items(true), rod) then Render(); return end
        step, page = 2, nil
        Render()
        return
    end
    if step == 3 and not CheckWeaponDraft() then return end
    if step == 3 and not (selectedKey and handlers.validateKey(selectedKey, selectedOverride)) then
        keyCapture:ToggleListening()
        return
    end
    local saveError = EquipmentSaveError()
    if saveError then Render(saveError); return end
    local selected = step == 2 and weapon or rod
    local item = FindItem(Items(step == 3), selected)
    if not item then Render(L["找不到所选物品，请重新选择。"]); return end

    local attempt = { item = item, deadline = GetTime() + 3 }
    pending = attempt
    if SameItem(item, CurrentMainHand()) then
        Advance(attempt)
    else
        local equipItem = C_Item.EquipItemByName or EquipItemByName
        if not equipItem then Finish(L["未能装备所选物品，请从背包手动装备后重试。"]); return end
        attempt.action = "正在装备…"
        Render(L["等待游戏完成装备切换。"])
        if not pcall(equipItem, item.link or item.id, MAIN_HAND) then
            Finish(L["未能装备所选物品，请从背包手动装备后重试。"])
            return
        end
        C_Timer.After(0.12, function() Advance(attempt) end)
    end
end)

local function CancelPending()
    pending, lastNotice = nil, nil
end
surface:HookScript("OnHide", CancelPending)
wizard:HookScript("OnHide", CancelPending)
wizard:SetScript("OnEvent", function(_, event)
    if not wizard:IsShown() then return end
    if currentTab == "gear" then gearStatus(); return end
    if currentTab ~= "setup" then return end
    if event == "PLAYER_REGEN_DISABLED" then CancelPending() end
    if not pending then Render(lastNotice) end
end)
for _, event in ipairs({
    "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "EQUIPMENT_SETS_CHANGED",
    "EQUIPMENT_SWAP_FINISHED", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}) do
    wizard:RegisterEvent(event)
end

function addon.ShowSetup(tab, notice)
    tab = tab or "setup"
    if not wizard:IsShown() then step = nil end
    currentTab = tab
    wizard:SetHeight(tab == "gear" and 485 or 430)
    for id, mark in pairs(tabMarks) do mark:SetShown(tab == id) end
    gearPage:SetShown(tab == "gear")
    fishingPage:SetShown(tab == "fishing")
    if tab == "setup" then
        if not step then
            step, page = 1, nil
            local setup = db.setupEquipment
            rod = setup and setup.rod and { id = setup.rod.main } or nil
            weapon = setup and setup.weapon and { id = setup.weapon.main } or nil
            selectedKey, selectedOverride = handlers.key(), nil
        end
        surface:Show()
        Render(lastNotice)
    else
        CancelPending()
        keyCapture:StopListening()
        surface:Hide()
        if tab == "gear" then gearStatus(notice or "") else fishingSettings(notice) end
    end
    theme.ShowPanel(wizard)
end

function addon.InitializeSetup(settings, callbacks)
    db, handlers = settings, callbacks
    if not keyCapture then
        keyCapture = addon.CreateKeyCapture(surface, "WowfFishingSetupKeyCapture", function(chord, override)
            return handlers.validateKey(chord, override)
        end, function(key, override)
            selectedKey, selectedOverride = key, override
        end, Render)
        keyCapture:AttachButton(keyButton)
        useKey:SetScript("OnClick", function() keyCapture:UseConflictingKey() end)
        fishingSettings = addon.CreateFishingSettings(fishingPage, settings, handlers)
        gearStatus = addon.CreateGearStatus(gearPage, settings, handlers.key, HandSetID)
    end
end

function addon.RefreshGearStatus()
    if wizard:IsShown() and currentTab == "gear" then gearStatus() end
end

function addon.ToggleFishingSettings()
    if wizard:IsShown() then wizard:Hide() else addon.ShowSetup("fishing") end
end
