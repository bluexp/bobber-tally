local _, addon = ...
local FISHING_SPELL_ID = 7620
local GEAR_BUTTON = "WowfFishingGearButton"
local FLOATING_GEAR_BUTTON = "WowfFishingFloatingGear"
local CAST_BUTTON = "WowfFishingCastButton"
local LOOT_ITEM = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or LOOT_SLOT_ITEM or 1

local events = CreateFrame("Frame")
local bindings = CreateFrame("Frame")
local castButton = CreateFrame("Button", CAST_BUTTON, UIParent, "SecureActionButtonTemplate")
castButton:Hide()
castButton:RegisterForClicks("AnyUp", "AnyDown")
castButton:SetAttribute("type", "spell")

local db, spellName, audioTimer, lootSlots
local swappingUntil = 0
local casts, catches, itemCount = 0, 0, 0
local lastCatch = "—"
local fishing, hasPole, caughtFromWindow = false, false, false

local function Say(message)
    print("|cff63c6ea无限钓鱼助手|r " .. message)
end

local panel = CreateFrame("Frame", "WowfFishingPanel", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(310, 190)
panel:SetPoint("RIGHT", UIParent, "RIGHT", -70, 100)
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOPLEFT", 12, -6)
title:SetText("无限钓鱼助手")

local aboutButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
aboutButton:SetSize(96, 20)
aboutButton:SetPoint("TOPRIGHT", -32, -3)
aboutButton:SetText("说明与致谢")
aboutButton:SetScript("OnClick", addon.ToggleAbout)

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
status:SetPoint("TOPLEFT", 15, -33)

local stats = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
stats:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -9)

local recent = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
recent:SetPoint("TOPLEFT", stats, "BOTTOMLEFT", 0, -8)
recent:SetWidth(194)
recent:SetJustifyH("LEFT")
recent:SetMaxLines(1)

local catchListButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
catchListButton:SetSize(81, 21)
catchListButton:SetPoint("TOPRIGHT", -14, -72)
catchListButton:SetText("查看全部")
catchListButton:SetScript("OnClick", addon.ToggleCatchList)

local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("BOTTOMLEFT", 15, 72)

local gearButton = CreateFrame("Button", GEAR_BUTTON, panel, "UIPanelButtonTemplate")
gearButton:SetSize(135, 24)
gearButton:SetPoint("BOTTOMLEFT", 14, 42)

local audioButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
audioButton:SetSize(135, 24)
audioButton:SetPoint("BOTTOMRIGHT", -14, 42)

local setupButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
setupButton:SetSize(282, 24)
setupButton:SetPoint("BOTTOMLEFT", 14, 12)
setupButton:SetText("配置向导")
setupButton:SetScript("OnClick", addon.ShowSetup)

local function GearKey()
    return db.gearKey or (db.useM and "M") or nil
end

local function RefreshPanel()
    if fishing then
        status:SetText("已抛竿，等待浮漂水花声")
    elseif hasPole then
        status:SetText("鱼竿已装备，可以抛竿")
    else
        status:SetText("普通装备")
    end
    stats:SetText(("本次：抛竿 %d 次，收获 %d 竿 / %d 件"):format(casts, catches, itemCount))
    recent:SetText("最近渔获：" .. lastCatch)
    hint:SetText(db.fishKey and ("抛竿 / 收竿：" .. db.fishKey) or "设置抛竿键：/wowfish bind G")
    gearButton:SetText(hasPole and "恢复原装备" or "装备鱼竿")
    audioButton:SetText(db.enhanceSound and "水花声：增强" or "水花声：原音")
    addon.UpdateFloatingGear(hasPole)
end

local function UpdateBindings()
    if InCombatLockdown() then return end
    ClearOverrideBindings(bindings)
    local key = GearKey()
    if key then
        local button = db.setupEquipment and FLOATING_GEAR_BUTTON or GEAR_BUTTON
        SetOverrideBindingClick(bindings, true, key, button, "LeftButton")
    end
    if db.fishKey and spellName and hasPole then
        if fishing then
            SetOverrideBinding(bindings, true, db.fishKey, "INTERACTTARGET")
        else
            SetOverrideBindingClick(bindings, true, db.fishKey, CAST_BUTTON, "LeftButton")
        end
    end
end

local audioSettings = {
    Sound_EnableSFX = "1",
    Sound_SFXVolume = "1",
    Sound_EnableMusic = "0",
    Sound_EnableAmbience = "0",
    Sound_EnableDialog = "0",
}

local function RestoreAudio()
    if audioTimer then
        audioTimer:Cancel()
        audioTimer = nil
    end
    if not db.audioBeforeFishing then return end
    for name, original in pairs(db.audioBeforeFishing) do
        local current = C_CVar.GetCVar(name)
        if tonumber(current) == tonumber(audioSettings[name]) then
            C_CVar.SetCVar(name, original)
        end
    end
    db.audioBeforeFishing = nil
end

local function EnhanceAudio()
    if audioTimer then
        audioTimer:Cancel()
        audioTimer = nil
    end
    if not db.enhanceSound or db.audioBeforeFishing then return end
    db.audioBeforeFishing = {}
    for name, value in pairs(audioSettings) do
        local original = C_CVar.GetCVar(name)
        if original and tonumber(original) ~= tonumber(value) then
            db.audioBeforeFishing[name] = original
            C_CVar.SetCVar(name, value)
        end
    end
end

local function UpdateChannel(countCast)
    local isFishing = spellName ~= nil and UnitChannelInfo("player") == spellName
    if isFishing == fishing then return end
    fishing = isFishing
    if fishing then
        if countCast then casts = casts + 1 end
        EnhanceAudio()
    elseif db.audioBeforeFishing then
        audioTimer = C_Timer.NewTimer(5, RestoreAudio)
    end
    UpdateBindings()
    RefreshPanel()
end

local function UpdateEquipment()
    local wasEquipped = hasPole
    hasPole = addon.IsFishingPole(GetInventoryItemID("player", 16))
    if db.useM and MultiBar6 and not InCombatLockdown() then
        MultiBar6:SetAlpha(hasPole and 1 or 0)
    end
    if wasEquipped ~= hasPole then
        panel:SetShown(hasPole)
        if not hasPole then RestoreAudio() end
    end
    UpdateBindings()
    RefreshPanel()
end

local function ToggleEquipment()
    if InCombatLockdown() then
        Say("脱离战斗后再切换装备。")
        return
    end
    if GetTime() < swappingUntil then return end
    local api = C_EquipmentSet
    local poleEquipped = addon.IsFishingPole(GetInventoryItemID("player", 16))
    local targetID
    if db.setupEquipment then
        local rodID, weaponID = addon.GetSetupEquipment()
        if not rodID or not weaponID then
            Say("鱼竿或武器方案已变更，请重新运行 /wowfish setup。")
            return
        end
        targetID = poleEquipped and weaponID or rodID
        local _, _, _, _, _, _, _, missing = api.GetEquipmentSetInfo(targetID)
        if missing and missing > 0 then
            Say("找不到所需装备，请检查背包。")
            return
        end
    else
        local backupID = api.GetEquipmentSetID("W")
        if not backupID then
            Say("请在配置向导选择武器，或在装备管理器创建 W。")
            return
        end
        targetID = backupID
        if not poleEquipped then
            targetID = api.GetEquipmentSetID("F")
            local items = targetID and api.GetItemIDs(targetID)
            if not items or not addon.IsFishingPole(items[16]) then
                Say("请在配置向导选择鱼竿，或把鱼竿保存为装备方案 F 的主手武器。")
                return
            end
            api.SaveEquipmentSet(backupID)
        end
    end
    swappingUntil = GetTime() + 1
    if not api.UseEquipmentSet(targetID) then
        swappingUntil = 0
        Say("切换装备失败，请检查背包空间和装备方案。")
        return
    end
    UpdateEquipment()
end

gearButton:SetScript("OnClick", ToggleEquipment)
audioButton:SetScript("OnClick", function()
    db.enhanceSound = not db.enhanceSound
    if not db.enhanceSound then
        RestoreAudio()
    elseif fishing then
        EnhanceAudio()
    end
    RefreshPanel()
end)

local function ReadFishingLoot()
    if not IsFishingLoot or not IsFishingLoot() then return end
    lootSlots = lootSlots or {}
    for slot = 1, GetNumLootItems() do
        if lootSlots[slot] ~= false and GetLootSlotType(slot) == LOOT_ITEM then
            local _, name, quantity = GetLootSlotInfo(slot)
            if name and quantity and quantity > 0 then
                local link = GetLootSlotLink(slot)
                local itemID = link and tonumber(link:match("item:(%d+)"))
                local item = lootSlots[slot] or { name = name, quantity = quantity }
                item.itemID = item.itemID or itemID
                lootSlots[slot] = item
            end
        end
    end
end

local function CountLoot(slot)
    local item = lootSlots and lootSlots[slot]
    if not item then return end
    lootSlots[slot] = false
    if not caughtFromWindow then
        catches = catches + 1
        caughtFromWindow = true
    end
    itemCount = itemCount + item.quantity
    lastCatch = ("%s ×%d"):format(item.name, item.quantity)
    addon.RecordCatch(item.itemID, item.name, item.quantity)
    RefreshPanel()
end

local function NormalizeKey(input)
    local key = input:match("^%s*(.-)%s*$"):upper()
    local remaining = key
    for _, modifier in ipairs({ "ALT", "CTRL", "SHIFT" }) do
        remaining = remaining:gsub("^" .. modifier .. "%-", "")
    end
    if remaining:match("^[A-Z0-9]$") then return key end
    local number = tonumber(remaining:match("^F(%d+)$"))
    if number and number >= 1 and number <= 12 and remaining == "F" .. number then return key end
end

local function ValidateGearKey(input)
    local key = NormalizeKey(input)
    if not key then return nil, "请输入字母、数字或 F1–F12，可带修饰键。" end
    if key == db.fishKey then return nil, key .. " 已用于抛竿和收竿。" end
    local action = GetBindingAction(key, true)
    if key ~= GearKey() and action and action ~= "" then
        return nil, key .. " 已绑定其他操作，请换一个空闲键。"
    end
    return key
end

local function SaveGearKey(key)
    if db.useM and key ~= "M" and MultiBar6 then MultiBar6:SetAlpha(1) end
    db.useM = key == "M"
    db.gearKey = key
    UpdateEquipment()
end

local function HandleCommand(input)
    local command, argument = input:match("^%s*(%S*)%s*(.-)%s*$")
    if command == "" then
        panel:SetShown(not panel:IsShown())
        return
    end
    if command == "loot" then
        addon.ToggleCatchList()
        return
    end
    if command == "fish" then
        addon.ToggleFishCatalog()
        return
    end
    if command == "about" then
        addon.ToggleAbout()
        return
    end
    if command == "setup" then
        addon.ShowSetup()
        return
    end
    if InCombatLockdown() then
        Say("脱离战斗后再修改按键。")
        return
    end
    if command == "bind" then
        local key = NormalizeKey(argument)
        if not key or key == "M" or key == GearKey() then
            Say("请指定空闲的字母、数字或 F1–F12，避开换装键和 M。")
            return
        end
        local action = GetBindingAction(key, true)
        if key ~= db.fishKey and action and action ~= "" then
            Say(key .. " 已绑定其他操作，请选一个空闲按键。")
            return
        end
        db.fishKey = key
        Say(key .. " 用于抛竿和收竿。请在游戏设置中开启「交互键」。")
    elseif command == "unbind" then
        db.fishKey = nil
    elseif command == "m" and (argument == "on" or argument == "off") then
        if argument == "on" then
            SaveGearKey("M")
            Say("M 已用于切换钓鱼装备。")
        elseif GearKey() == "M" then
            SaveGearKey(nil)
            Say("已释放 M。")
        end
        return
    else
        Say("/wowfish setup 打开配置向导；/wowfish loot 查看本次渔获；/wowfish fish 查看鱼类资料；/wowfish bind G 设置抛竿键；/wowfish unbind 释放抛竿键；/wowfish m on/off 管理 M。")
        return
    end
    UpdateEquipment()
end

local function Initialize()
    WowfFishingDB = WowfFishingDB or {}
    db = WowfFishingDB
    addon.InitializeCatchList(db)
    addon.InitializeFishCatalog(db)
    if db.useM == nil then db.useM = false end
    if db.enhanceSound == nil then db.enhanceSound = true end
    addon.InitializeSetup(db, { key = GearKey, validateKey = ValidateGearKey, saveKey = SaveGearKey, toggleGear = ToggleEquipment, say = Say })
    RestoreAudio()
    spellName = C_Spell.GetSpellName(FISHING_SPELL_ID)
    castButton:SetAttribute("spell", spellName)
    SLASH_WOWFFISHING1 = "/wowfish"
    SlashCmdList.WOWFFISHING = HandleCommand
    UpdateEquipment()
    UpdateChannel(false)
end

events:SetScript("OnEvent", function(_, event, unitOrSlot)
    if event == "PLAYER_LOGIN" then
        Initialize()
    elseif not db then
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateEquipment()
        UpdateChannel(false)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        UpdateEquipment()
    elseif event == "EQUIPMENT_SWAP_FINISHED" then
        swappingUntil = 0
        UpdateEquipment()
    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_REGEN_DISABLED" then
        RestoreAudio()
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        ReadFishingLoot()
    elseif event == "LOOT_SLOT_CLEARED" then
        CountLoot(unitOrSlot)
    elseif event == "LOOT_CLOSED" then
        lootSlots, caughtFromWindow = nil, false
    elseif unitOrSlot == "player" then
        UpdateChannel(event == "UNIT_SPELLCAST_CHANNEL_START")
    end
end)

for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SWAP_FINISHED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "LOOT_READY", "LOOT_OPENED",
    "LOOT_SLOT_CLEARED", "LOOT_CLOSED",
}) do
    events:RegisterEvent(event)
end
