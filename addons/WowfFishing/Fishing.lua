local _, addon = ...
local L = addon.L
local theme = addon.Theme
local colors = theme.colors
local FISHING_SPELL_ID = 7620
local GEAR_BUTTON = "WowfFishingFloatingGear"
local CAST_BUTTON = "WowfFishingCastButton"
local ICON_SIZE, CAST_OFFSET = 42, 7
local LOOT_ITEM = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or LOOT_SLOT_ITEM or 1

local events = CreateFrame("Frame")
local bindings = CreateFrame("Frame")
local toolbar = CreateFrame("Frame", "WowfFishingToolbar", UIParent)
toolbar:SetSize(184, 54)
toolbar:SetClampedToScreen(true)
toolbar:SetMovable(true)
theme.Fill(toolbar, "BACKGROUND", colors.control)
theme.Block(toolbar, "BORDER", 1, -1, 182, 52, colors.surface)
toolbar:Hide()

local function ToolbarIcon(button)
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button:EnableMouse(true)
    theme.Fill(button, "BACKGROUND", colors.control)
    theme.Highlight(button)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    return icon
end

local castButton = CreateFrame("Button", CAST_BUTTON, toolbar, "SecureActionButtonTemplate")
castButton:SetPoint("LEFT", CAST_OFFSET, 0)
castButton:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
local castIcon = ToolbarIcon(castButton)
local gearButton = CreateFrame("Button", GEAR_BUTTON, toolbar)
gearButton:SetPoint("LEFT", castButton, "RIGHT", 6, 0)
local gearIcon = ToolbarIcon(gearButton)
local panelButton = CreateFrame("Button", "WowfFishingPanelToggle", toolbar)
panelButton:SetPoint("LEFT", gearButton, "RIGHT", 6, 0)
ToolbarIcon(panelButton):SetColorTexture(unpack(colors.selected))
for y = -6, 6, 6 do
    local bar = panelButton:CreateTexture(nil, "ARTWORK", nil, 1)
    bar:SetPoint("CENTER", panelButton, "CENTER", 0, y)
    bar:SetSize(20, 2)
    bar:SetColorTexture(unpack(colors.gold))
end

local dragHandle = addon.CreateDragHandle(toolbar, "WowfFishingToolbarGrip", "按住左键拖动工具栏")
dragHandle:SetPoint("LEFT", panelButton, "RIGHT", 6, 0)

panelButton:SetScript("OnClick", addon.ToggleCatchList)
panelButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(addon.IsCatchListShown() and L["收起钓鱼面板"] or L["打开钓鱼面板"])
    GameTooltip:Show()
end)
panelButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local db, spellName, audioTimer, lootSlots
local swappingUntil = 0
local casts, catches, itemCount = 0, 0, 0
local lastCatch = "—"
local fishing, hasPole, caughtFromWindow = false, false, false

local function PositionToolbar()
    local position = db.castButtonPosition
    toolbar:ClearAllPoints()
    if position then
        toolbar:SetPoint("LEFT", UIParent, "CENTER", position.x - CAST_OFFSET - ICON_SIZE / 2, position.y)
    elseif db.floatPosition then
        toolbar:SetPoint("CENTER", UIParent, "CENTER", db.floatPosition.x, db.floatPosition.y)
    else
        toolbar:SetPoint("RIGHT", UIParent, "RIGHT", -390, 100)
    end
end

local function StopMovingToolbar()
    if not toolbar.moving or InCombatLockdown() then return end
    toolbar:StopMovingOrSizing()
    toolbar.moving = nil
    local x, y = castButton:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not x or not parentX then return end
    db.castButtonPosition = { x = x - parentX, y = y - parentY }
    PositionToolbar()
end

dragHandle:SetScript("OnDragStart", function()
    if InCombatLockdown() then return end
    toolbar.moving = true
    toolbar:StartMoving()
end)
dragHandle:SetScript("OnDragStop", StopMovingToolbar)
toolbar:SetScript("OnHide", StopMovingToolbar)
castButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(fishing and L["正在钓鱼"] or (hasPole and L["点击抛竿"] or L["请先装备鱼竿"]))
    if fishing then
        GameTooltip:AddLine(L["听到水花声后，右键点击浮漂。"], 1, 1, 1)
    end
    if db.fishKey then
        GameTooltip:AddLine(L["抛竿与收竿快捷键  "] .. db.fishKey, 1, 1, 1)
    end
    GameTooltip:Show()
end)
castButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function UpdateCastButton()
    if InCombatLockdown() then return end
    local canCast = hasPole and spellName ~= nil and not fishing
    castButton:SetAttribute("type", canCast and "spell" or nil)
    castIcon:SetDesaturated(not canCast)
end

local function Say(message)
    print("|cff63c6ea" .. L["无限钓鱼助手"] .. "|r " .. message)
end

local function GearKey()
    return db.gearKey or (db.useM and "M") or nil
end

gearButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(hasPole and L["恢复武器"] or L["装备鱼竿"])
    local key = GearKey()
    if key then GameTooltip:AddLine(L["换装快捷键  "] .. key, 1, 1, 1) end
    GameTooltip:Show()
end)
gearButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function RefreshSummary()
    local state = L["普通装备"]
    if fishing then
        state = L["已抛竿，等待浮漂水花声"]
    elseif hasPole then
        state = L["鱼竿已装备，可以抛竿"]
    end
    addon.UpdateCatchSummary(state, casts, catches, itemCount, lastCatch)
end

local function UpdateBindings()
    if InCombatLockdown() then return end
    UpdateCastButton()
    ClearOverrideBindings(bindings)
    local key = GearKey()
    if key then
        SetOverrideBindingClick(bindings, true, key, GEAR_BUTTON, "LeftButton")
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
    RefreshSummary()
end

local function UpdateEquipment()
    local wasEquipped = hasPole
    hasPole = addon.IsFishingPole(GetInventoryItemID("player", 16))
    local setup = db.setupEquipment
    local target = setup and (hasPole and setup.weapon or setup.rod)
    local icon = target and select(5, C_Item.GetItemInfoInstant(target.main))
    gearIcon:SetTexture(icon or (hasPole and "Interface\\Icons\\INV_Sword_04" or "Interface\\Icons\\INV_Fishingpole_02"))
    if db.useM and MultiBar6 and not InCombatLockdown() then
        MultiBar6:SetAlpha(hasPole and 1 or 0)
    end
    if wasEquipped and not hasPole then RestoreAudio() end
    UpdateBindings()
    RefreshSummary()
end

local function ToggleEquipment()
    if InCombatLockdown() then
        Say(L["脱离战斗后再切换装备。"])
        return
    end
    if GetTime() < swappingUntil then return end
    local api = C_EquipmentSet
    local poleEquipped = addon.IsFishingPole(GetInventoryItemID("player", 16))
    local targetID
    if db.setupEquipment then
        local rodID, weaponID = addon.GetSetupEquipment()
        if not rodID or not weaponID then
            Say(L["鱼竿或武器方案已变更，请重新运行 /wowfish setup。"])
            return
        end
        targetID = poleEquipped and weaponID or rodID
        local _, _, _, _, _, _, _, missing = api.GetEquipmentSetInfo(targetID)
        if missing and missing > 0 then
            Say(L["找不到所需装备，请检查背包。"])
            return
        end
    else
        local backupID = api.GetEquipmentSetID("W")
        if not backupID then
            Say(L["请在配置向导选择武器，或在装备管理器创建 W。"])
            return
        end
        targetID = backupID
        if not poleEquipped then
            targetID = api.GetEquipmentSetID("F")
            local items = targetID and api.GetItemIDs(targetID)
            if not items or not addon.IsFishingPole(items[16]) then
                Say(L["请在配置向导选择鱼竿，或把鱼竿保存为装备方案 F 的主手武器。"])
                return
            end
            api.SaveEquipmentSet(backupID)
        end
    end
    swappingUntil = GetTime() + 1
    if not api.UseEquipmentSet(targetID) then
        swappingUntil = 0
        Say(L["切换装备失败，请检查背包空间和装备方案。"])
        return
    end
    UpdateEquipment()
end

gearButton:SetScript("OnClick", ToggleEquipment)
local function ToggleAudio()
    db.enhanceSound = not db.enhanceSound
    if not db.enhanceSound then
        RestoreAudio()
    elseif fishing then
        EnhanceAudio()
    end
    RefreshSummary()
end

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
    RefreshSummary()
end

local numpadOperators = {
    NUMPADDECIMAL = true,
    NUMPADDIVIDE = true,
    NUMPADEQUALS = true,
    NUMPADMINUS = true,
    NUMPADMULTIPLY = true,
    NUMPADPLUS = true,
}

local function NormalizeKey(input)
    local key = input:match("^%s*(.-)%s*$"):upper()
    local remaining = key
    for _, modifier in ipairs({ "ALT", "CTRL", "SHIFT" }) do
        remaining = remaining:gsub("^" .. modifier .. "%-", "")
    end
    if remaining:match("^[A-Z0-9]$") then return key end
    if remaining:match("^NUMPAD[0-9]$") or numpadOperators[remaining] then return key end
    local number = tonumber(remaining:match("^F(%d+)$"))
    if number and number >= 1 and number <= 12 and remaining == "F" .. number then return key end
end

local function ValidateGearKey(input)
    local key = NormalizeKey(input)
    if not key then return nil, L["请按字母、数字、F1–F12 或小键盘键，可带修饰键。"] end
    if key == db.fishKey then return nil, key .. L[" 已用于抛竿和收竿。"] end
    local action = GetBindingAction(key, true)
    if key ~= GearKey() and action and action ~= "" then
        return nil, key .. L[" 已绑定其他操作，请换一个空闲键。"]
    end
    return key
end

local function SaveGearKey(key)
    if db.useM and key ~= "M" and MultiBar6 then MultiBar6:SetAlpha(1) end
    db.useM = key == "M"
    db.gearKey = key
    UpdateEquipment()
end

local function ValidateFishKey(input)
    local key = NormalizeKey(input)
    if not key then return nil, L["请按字母、数字、F1–F12 或小键盘键，可带修饰键。"] end
    if key == "M" or key == GearKey() then return nil, L["请选择 M 和换装键以外的空闲键。"] end
    local action = GetBindingAction(key, true)
    if key ~= db.fishKey and action and action ~= "" then
        return nil, L["按键已被占用，请换一个。"]
    end
    return key
end

local function SaveFishKey(key)
    db.fishKey = key
    UpdateBindings()
    RefreshSummary()
    if key then Say(key .. L[" 用于抛竿和收竿。请在游戏设置中开启「交互键」。"]) end
end

local function HandleCommand(input)
    local command, argument = input:match("^%s*(%S*)%s*(.-)%s*$")
    if command == "" or command == "loot" then
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
    if command == "lang" then
        argument = argument:lower()
        if argument == "zh" or argument == "en" or argument == "auto" then
            db.language = argument ~= "auto" and argument or nil
            Say(L["语言已保存。输入 /reload 应用。"])
        else
            Say(L["语言设置命令为 /wowfish lang zh、/wowfish lang en 或 /wowfish lang auto。"])
        end
        return
    end
    if InCombatLockdown() then
        Say(L["脱离战斗后再修改按键。"])
        return
    end
    if command == "bind" then
        local key, errorMessage = ValidateFishKey(argument)
        if not key then
            Say(errorMessage)
            return
        end
        SaveFishKey(key)
    elseif command == "unbind" then
        SaveFishKey(nil)
    elseif command == "m" and (argument == "on" or argument == "off") then
        if argument == "on" then
            SaveGearKey("M")
            Say(L["M 已用于切换钓鱼装备。"])
        elseif GearKey() == "M" then
            SaveGearKey(nil)
            Say(L["已释放 M。"])
        end
        return
    else
        Say(L["/wowfish setup 打开配置向导；/wowfish loot 查看本次渔获；/wowfish fish 查看鱼类资料；/wowfish bind G 设置抛竿键；/wowfish unbind 释放抛竿键；/wowfish m on/off 管理 M。"])
        Say(L["语言设置命令为 /wowfish lang zh、/wowfish lang en 或 /wowfish lang auto。"])
        return
    end
end

local function Initialize()
    WowfFishingDB = WowfFishingDB or {}
    db = WowfFishingDB
    addon.InitializeLocale(db.language)
    addon.InitializeCatchList(db, ToggleAudio, ValidateFishKey, SaveFishKey)
    addon.InitializeFishCatalog(db)
    if db.useM == nil then db.useM = false end
    if db.enhanceSound == nil then db.enhanceSound = true end
    addon.InitializeSetup(db, { key = GearKey, validateKey = ValidateGearKey, saveKey = SaveGearKey, say = Say })
    RestoreAudio()
    spellName = C_Spell.GetSpellName(FISHING_SPELL_ID)
    castButton:SetAttribute("spell", spellName)
    castIcon:SetTexture((C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(FISHING_SPELL_ID))
        or "Interface\\Icons\\Trade_Fishing")
    toolbar:Show()
    PositionToolbar()
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
        if event == "PLAYER_REGEN_ENABLED" then StopMovingToolbar() end
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
