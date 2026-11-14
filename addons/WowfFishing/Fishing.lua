local _, addon = ...
local L = addon.L
local theme = addon.Theme
local colors = theme.colors
local FISHING_SPELL_ID = 7620
local GEAR_BUTTON = "WowfFishingFloatingGear"
local CAST_BUTTON = "WowfFishingCastButton"
local ICON_SIZE, CAST_OFFSET = 42, 7
local TOOLBAR_WIDTH = 232
local LOOT_ITEM = Enum and Enum.LootSlotType and Enum.LootSlotType.Item or LOOT_SLOT_ITEM or 1

local events = CreateFrame("Frame")
local bindings = CreateFrame("Frame")
local toolbar = CreateFrame("Frame", "WowfFishingToolbar", UIParent)
toolbar:SetSize(TOOLBAR_WIDTH, 54)
toolbar:SetClampedToScreen(true)
toolbar:SetMovable(true)
theme.Fill(toolbar, "BACKGROUND", colors.control)
theme.Block(toolbar, "BORDER", 1, -1, TOOLBAR_WIDTH - 2, 52, colors.surface)
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

local function ToolbarControl(button)
    local background = ToolbarIcon(button)
    background:SetDrawLayer("BORDER")
    background:SetColorTexture(unpack(colors.selected))
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
ToolbarControl(panelButton)
for index, height in ipairs({ 8, 13, 20 }) do
    theme.Block(panelButton, "ARTWORK", 10 + (index - 1) * 8, -31 + height, 5, height, colors.gold)
end

local settingsButton = CreateFrame("Button", "WowfFishingSettingsToggle", toolbar)
settingsButton:SetPoint("LEFT", panelButton, "RIGHT", 6, 0)
ToolbarControl(settingsButton)
local settingsIcon = settingsButton:CreateTexture(nil, "ARTWORK")
-- Crop the white uitools-icon-settings glyph from the client's 1024 × 256 texture.
if settingsIcon:SetTexture(5400310) then
    settingsIcon:SetTexCoord(555 / 1024, 575 / 1024, 61 / 256, 81 / 256)
    settingsIcon:SetPoint("CENTER", settingsButton, "CENTER")
    settingsIcon:SetSize(22, 22)
    settingsIcon:SetVertexColor(unpack(colors.gold))
else
    settingsIcon:Hide()
    local cogRows = {
        "....###....",
        ".##.###.##.",
        ".#########.",
        "..###.###..",
        "####...####",
        "###.....###",
        "####...####",
        "..###.###..",
        ".#########.",
        ".##.###.##.",
        "....###....",
    }
    for row, pixels in ipairs(cogRows) do
        for column, teeth in pixels:gmatch("()(#+)") do
            theme.Block(settingsButton, "ARTWORK", 10 + (column - 1) * 2, -10 - (row - 1) * 2,
                #teeth * 2, 2, colors.gold)
        end
    end
end

local dragHandle = addon.CreateDragHandle(toolbar, "WowfFishingToolbarGrip", "按住左键拖动工具栏")
dragHandle:SetPoint("LEFT", settingsButton, "RIGHT", 6, 0)

panelButton:SetScript("OnClick", addon.ToggleCatchList)
settingsButton:SetScript("OnClick", function() addon.ToggleFishingSettings() end)
local function ToolbarTooltip(button, title)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[title])
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
ToolbarTooltip(panelButton, "渔获统计")
ToolbarTooltip(settingsButton, "钓鱼设置")

local db, spellName, audioTimer, lootSlots
local pendingSwap, session, castStarted
local MAIN_HAND, OFF_HAND = 16, 17
local lureTicker, lureWasActive, lureWarned
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
    addon.UpdateCatchSummary(state, session)
end

local function RefreshLure()
    local weaponSlot = Enum and Enum.WeaponSlot and Enum.WeaponSlot.MainHand
    if not hasPole or not C_Item.GetWeaponEnchantInfo or weaponSlot == nil then
        addon.UpdateLureStatus()
        return
    end
    local enchants = C_Item.GetWeaponEnchantInfo(weaponSlot)
    if type(enchants) ~= "table" then addon.UpdateLureStatus(); return end
    local remaining
    local temporary = Enum.ItemEnchantType and Enum.ItemEnchantType.Temporary
    for _, enchant in pairs(enchants) do
        if enchant.hasEnchant and (not temporary or enchant.enchantType == temporary)
            and type(enchant.timeLeft) == "number" and enchant.timeLeft > 0 then
            remaining = math.max(remaining or 0, math.ceil(enchant.timeLeft / 1000))
        end
    end
    if remaining then
        if not lureWasActive or remaining > 30 then lureWarned = false end
        if remaining <= 30 and not lureWarned then
            lureWarned = true
            Say(L["鱼饵将在 %d 秒内到期。"]:format(remaining))
        end
        lureWasActive = true
        addon.UpdateLureStatus(remaining)
    elseif lureWasActive then
        lureWasActive = false
        addon.UpdateLureStatus(0)
        Say(L["鱼饵已到期。"])
    end
end

function addon.GetFishingSeconds()
    return session.seconds + (castStarted and math.max(0, GetTime() - castStarted) or 0)
end

local function SaveFishingTime()
    session.seconds = addon.GetFishingSeconds()
    castStarted = nil
end

function addon.EndFishingSession()
    if fishing or lootSlots then return false end
    session.casts, session.catches, session.count, session.seconds, session.lastCatch = 0, 0, 0, 0, nil
    addon.ClearSessionCatches()
    RefreshSummary()
    return true
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
        if countCast then session.casts = session.casts + 1 end
        castStarted = GetTime()
        EnhanceAudio()
    else
        SaveFishingTime()
        if db.audioBeforeFishing then audioTimer = C_Timer.NewTimer(5, RestoreAudio) end
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
    if hasPole and not lureTicker then
        RefreshLure()
        lureTicker = C_Timer.NewTicker(1, RefreshLure)
    elseif not hasPole and lureTicker then
        lureTicker:Cancel()
        lureTicker, lureWasActive, lureWarned = nil, nil, nil
        addon.UpdateLureStatus()
    end
    UpdateBindings()
    RefreshSummary()
end

local function FinishSwap(target, success, message, ...)
    pendingSwap = nil
    db.lastGearSwap = { target = target, success = success, message = message, args = { ... }, time = GetServerTime() }
    addon.RefreshGearStatus()
    if not success then Say(L[message]:format(...)) end
end

local function CheckSwap(attempt, timedOut)
    if pendingSwap ~= attempt then return end
    local mainMatches = (GetInventoryItemID("player", MAIN_HAND) or 0) == attempt.main
    local offMatches = (GetInventoryItemID("player", OFF_HAND) or 0) == attempt.off
    if mainMatches and offMatches then
        FinishSwap(attempt.name, true, "主副手已确认。")
    elseif attempt.rejected or timedOut then
        local slot = not mainMatches and not offMatches and L["主手和副手"]
            or (not mainMatches and L["主手"] or L["副手"])
        local reason = attempt.rejected and "游戏报告换装失败：%s未达到目标。"
            or "等待换装超时：%s未达到目标。"
        FinishSwap(attempt.name, false, reason, slot)
    end
end

local function ToggleEquipment()
    if pendingSwap then return end
    local api = C_EquipmentSet
    local currentMain = GetInventoryItemID("player", MAIN_HAND) or 0
    local currentOff = GetInventoryItemID("player", OFF_HAND) or 0
    local poleEquipped = addon.IsFishingPole(currentMain)
    local setup = db.setupEquipment
    local target = setup and setup[poleEquipped and "weapon" or "rod"]
    local name = target and target.name or (poleEquipped and "W" or "F")
    local function Fail(message, ...)
        FinishSwap(name, false, message, ...)
    end
    if InCombatLockdown() then return Fail("脱离战斗后再切换装备。") end
    local targetID, main, off, backupID
    if db.setupEquipment then
        local rodID, weaponID, badSet, reason, slot, actual = addon.GetSetupEquipment()
        if not rodID or not weaponID then
            name = badSet and badSet.name or name
            local message, a, b = addon.GetGearSetIssue(badSet, reason, slot, actual)
            return Fail(message, a, b)
        end
        targetID = poleEquipped and weaponID or rodID
        main, off = target.main, target.off
    else
        backupID = api.GetEquipmentSetID("W")
        if not backupID then
            name = "W"
            return Fail("请在配置向导选择武器，或在装备管理器创建 W。")
        end
        targetID = poleEquipped and backupID or api.GetEquipmentSetID("F")
        if not targetID then
            return Fail("请在配置向导选择鱼竿，或把鱼竿保存为装备方案 F 的主手武器。")
        end
        local items, ignored, locations = api.GetItemIDs(targetID), api.GetIgnoredSlots(targetID), api.GetItemLocations(targetID)
        if not items or not ignored or not locations then return Fail("装备管理器暂不可用，请稍后再试。") end
        if not poleEquipped and not addon.IsFishingPole(items[MAIN_HAND]) then
            return Fail("方案 F 的主手不是鱼竿。")
        end
        main = (ignored[MAIN_HAND] or locations[MAIN_HAND] == 1) and currentMain or math.max(0, items[MAIN_HAND] or 0)
        off = (ignored[OFF_HAND] or locations[OFF_HAND] == 1) and currentOff or math.max(0, items[OFF_HAND] or 0)
    end
    local _, _, _, _, _, _, _, missing = api.GetEquipmentSetInfo(targetID)
    if missing and missing > 0 then return Fail("找不到所需装备，请检查背包。") end
    if (api.EquipmentSetContainsLockedItems and api.EquipmentSetContainsLockedItems(targetID))
        or (IsInventoryItemLocked and (IsInventoryItemLocked(MAIN_HAND) or IsInventoryItemLocked(OFF_HAND))) then
        return Fail("装备正在切换或已锁定，请稍后重试。")
    end
    if backupID and not poleEquipped then api.SaveEquipmentSet(backupID) end
    local attempt = { id = targetID, name = name, main = main, off = off }
    pendingSwap = attempt
    addon.RefreshGearStatus()
    local accepted = api.UseEquipmentSet(targetID)
    if pendingSwap ~= attempt then return end
    if not accepted then return Fail("游戏未接受换装请求，请检查背包空间后重试。") end
    CheckSwap(attempt)
    if pendingSwap == attempt then C_Timer.After(4, function() CheckSwap(attempt, true) end) end
    UpdateEquipment()
end

function addon.GetPendingGearSwap()
    return pendingSwap and pendingSwap.name
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
        session.catches = session.catches + 1
        caughtFromWindow = true
    end
    session.count = session.count + item.quantity
    session.lastCatch = ("%s ×%d"):format(item.name, item.quantity)
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
    if remaining == "BUTTON4" or remaining == "BUTTON5" then return key end
    local number = tonumber(remaining:match("^F(%d+)$"))
    if number and number >= 1 and number <= 12 and remaining == "F" .. number then return key end
end

local function ValidateGearKey(input, override)
    local key = NormalizeKey(input)
    if not key then return nil, L["支持键盘、小键盘、鼠标侧键和组合键。"] end
    if key == db.fishKey then return nil, key .. L[" 已用于抛竿和收竿。"] end
    local action = GetBindingAction(key, true)
    if not override and key ~= GearKey() and action and action ~= "" then
        return nil, key .. L[" 已绑定其他操作，请换一个空闲键。"], true
    end
    return key
end

local function SaveGearKey(key)
    if db.useM and key ~= "M" and MultiBar6 then MultiBar6:SetAlpha(1) end
    db.useM = key == "M"
    db.gearKey = key
    UpdateEquipment()
    addon.RefreshGearStatus()
    if addon.RefreshFishingSettings then addon.RefreshFishingSettings() end
end

local function ValidateFishKey(input, override)
    local key = NormalizeKey(input)
    if not key then return nil, L["支持键盘、小键盘、鼠标侧键和组合键。"] end
    if key == GearKey() then return nil, L["这个按键已用于换装，请换一个。"] end
    local action = GetBindingAction(key, true)
    if not override and key ~= db.fishKey and action and action ~= "" then
        return nil, L["按键已被占用，请换一个。"], true
    end
    return key
end

local function SaveFishKey(key)
    db.fishKey = key
    UpdateBindings()
    RefreshSummary()
    if addon.RefreshFishingSettings then addon.RefreshFishingSettings() end
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
    if command == "settings" then
        addon.ShowSetup("fishing")
        return
    end
    if command == "gear" then
        addon.ShowSetup("gear")
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
            local key, errorMessage = ValidateGearKey("M", true)
            if not key then Say(errorMessage); return end
            SaveGearKey(key)
            Say(L["M 已用于切换钓鱼装备。"])
        elseif GearKey() == "M" then
            SaveGearKey(nil)
            Say(L["已释放 M。"])
        end
        return
    else
        Say(L["/wowfish settings 打开设置；/wowfish setup 打开换装向导；/wowfish bind G 设置抛竿键；/wowfish unbind 清除抛竿键。"])
        Say(L["/wowfish gear 查看换装方案。"])
        Say(L["/wowfish loot 查看本次渔获；/wowfish fish 查看鱼类资料；/wowfish m on/off 管理 M。"])
        Say(L["语言设置命令为 /wowfish lang zh、/wowfish lang en 或 /wowfish lang auto。"])
        return
    end
end

local function Initialize()
    WowfFishingDB = WowfFishingDB or {}
    db = WowfFishingDB
    db.fishingSession = db.fishingSession or { casts = 0, catches = 0, count = 0, seconds = 0, items = {} }
    session = db.fishingSession
    addon.InitializeLocale(db.language)
    addon.InitializeCatchList(db)
    addon.InitializeFishCatalog(db)
    if db.useM == nil then db.useM = false end
    if db.enhanceSound == nil then db.enhanceSound = true end
    addon.InitializeSetup(db, {
        key = GearKey, validateKey = ValidateGearKey, saveKey = SaveGearKey, say = Say,
        validateFishKey = ValidateFishKey, saveFishKey = SaveFishKey, toggleAudio = ToggleAudio,
    })
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

events:SetScript("OnEvent", function(_, event, unitOrSlot, setID)
    if event == "PLAYER_LOGIN" then
        Initialize()
    elseif not db then
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateEquipment()
        UpdateChannel(false)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_ENABLED" then StopMovingToolbar() end
        if pendingSwap and event == "PLAYER_EQUIPMENT_CHANGED" then CheckSwap(pendingSwap) end
        UpdateEquipment()
    elseif event == "EQUIPMENT_SWAP_FINISHED" then
        if pendingSwap and (setID == pendingSwap.id or (setID == nil and unitOrSlot == true)) then
            pendingSwap.rejected = unitOrSlot == false
            CheckSwap(pendingSwap)
        end
        UpdateEquipment()
    elseif event == "PLAYER_LOGOUT" or event == "PLAYER_REGEN_DISABLED" then
        if event == "PLAYER_LOGOUT" then
            SaveFishingTime()
            if pendingSwap then
                FinishSwap(pendingSwap.name, false, "退出游戏前未确认换装结果。")
            end
        end
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
