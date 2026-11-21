local _, addon = ...
local L = addon.L
local theme = addon.Theme
local colors = theme.colors
local interact = Enum.SoftTargetEnableFlags or {}
local INTERACT_CVAR = "softTargetInteract"

local function SetNumericCVar(name, value)
    local ok, applied = pcall(C_CVar.SetCVar, name, tostring(value))
    return ok and applied and tonumber(C_CVar.GetCVar(name)) == value
end

function addon.InitializeInteractKey()
    if WowfFishingAccountDB.interactKeyInitialized or interact.Any == nil or InCombatLockdown() then return end
    local current = tonumber(C_CVar.GetCVar(INTERACT_CVAR))
    if current ~= nil and (current == interact.Any or SetNumericCVar(INTERACT_CVAR, interact.Any)) then
        WowfFishingAccountDB.interactKeyInitialized = true
    end
end

function addon.CreateFishingSettings(page, db, handlers)
    local settings = {
        { label = "抛竿 / 收竿键", get = function() return db.fishKey end,
            save = handlers.saveFishKey },
        { label = "一键换装快捷键", get = handlers.key, save = handlers.saveKey },
        { label = "水花声增强", get = function() return db.enhanceSound end, toggle = handlers.toggleAudio },
        { label = "交互键", name = INTERACT_CVAR, on = interact.Any, off = interact.Gamepad },
        { label = "自动拾取", name = "autoLootDefault", on = 1, off = 0 },
        { label = "打开拍卖行自动查价", get = function() return db.autoRefreshAuctionPrices end,
            toggle = addon.ToggleAuctionAutoRefresh },
        { label = "鱼漂搜索角度", name = "SoftTargetInteractArc", preset = 2 },
        { label = "鱼漂搜索距离（码）", name = "SoftTargetInteractRange", preset = 30 },
    }
    local Label = theme.Label
    addon.SetLocalizedText(Label(page, "GameFontNormalLarge", 20, -30, 416, nil, colors.gold), "快捷键与钓鱼操作")
    theme.Block(page, "BORDER", 12, -56, 432, 278, colors.card)
    addon.SetLocalizedText(Label(page, "GameFontHighlightSmall", 20, -343, 416, nil, colors.muted),
        "交互键和自动拾取也适用于游戏中的其他操作。")
    addon.SetLocalizedText(Label(page, "GameFontHighlightSmall", 20, -364, 416, nil, colors.muted),
        "搜索距离用于选中鱼漂，实际收竿距离由游戏判定。")
    local message = Label(page, "GameFontHighlightSmall", 20, -390, 416, nil, colors.gold)
    local lastNotice

    local function Refresh(notice)
        lastNotice = notice
        local combat = InCombatLockdown()
        local listening
        for _, setting in ipairs(settings) do
            if setting.capture then
                local capturing = setting.capture:IsListening()
                listening = listening or capturing
                local key = setting.get()
                setting.action:SetText(capturing and L["请按快捷键…"] or key or L["点击录入"])
                setting.action:SetEnabled(not combat)
                setting.extra:SetEnabled(not combat and key ~= nil and not capturing)
            elseif setting.toggle then
                local enabled = setting.get()
                setting.value:SetText(enabled and L["已开启"] or L["已关闭"])
                setting.action:SetText(enabled and L["关闭"] or L["开启"])
            else
                local value = tonumber(C_CVar.GetCVar(setting.name))
                local available = value ~= nil and (setting.preset ~= nil or (setting.on ~= nil and setting.off ~= nil))
                if setting.preset then
                    setting.value:SetText(available and tostring(value) or L["不可用"])
                    setting.action:SetText(L["设为 %d"]:format(setting.preset))
                    setting.action:SetEnabled(available and value ~= setting.preset)
                    local default = available and tonumber(C_CVar.GetCVarDefault(setting.name))
                    setting.extra:SetEnabled(default and value ~= default or false)
                else
                    local enabled = value == setting.on
                    setting.value:SetText(available and (enabled and L["已开启"] or L["已关闭"]) or L["不可用"])
                    setting.action:SetText(enabled and L["关闭"] or L["开启"])
                    setting.action:SetEnabled(available)
                end
            end
        end
        message:SetText(notice or (listening and L["按键盘键，或在录入按钮上按中键、侧键或滚动滚轮。Esc 取消。"])
            or L["可直接使用游戏已绑定的键；清除插件绑定后，原操作恢复。"])
    end

    local function Apply(setting, value)
        if SetNumericCVar(setting.name, value) then
            if setting.name == INTERACT_CVAR then WowfFishingAccountDB.interactKeyInitialized = true end
            Refresh(L["设置已应用。"])
        else
            Refresh(L["客户端未应用这项设置。"])
        end
    end

    for index, setting in ipairs(settings) do
        local y = -63 - (index - 1) * 34
        addon.SetLocalizedText(Label(page, "GameFontHighlight", 24, y - 5, 172), setting.label)
        setting.action = theme.Button(page, nil, "", setting.save and 144 or 80, 25, true)
        setting.action:SetPoint("TOPLEFT", setting.save and 196 or 260, y)
        if setting.save or setting.preset then
            setting.extra = theme.Button(page, nil, setting.preset and "恢复默认" or "清除", 86, 25)
            setting.extra:SetPoint("TOPLEFT", 346, y)
        end
        if setting.save then
            setting.capture = addon.CreateKeyCapture(page, nil, handlers.validateKey, setting.save, Refresh)
            setting.capture:AttachButton(setting.action)
            setting.extra:SetScript("OnClick", function()
                if not InCombatLockdown() and not setting.capture:IsListening() then
                    setting.save(nil)
                    Refresh(L["快捷键已清除。"])
                end
            end)
        else
            setting.value = Label(page, "GameFontHighlightSmall", 196, y - 6, 62, nil, colors.muted)
            setting.action:SetScript("OnClick", function()
                if setting.toggle then
                    setting.toggle()
                    Refresh()
                else
                    local current = tonumber(C_CVar.GetCVar(setting.name))
                    local value = setting.preset or (current == setting.on and setting.off or setting.on)
                    if current ~= nil and value ~= nil then Apply(setting, value) end
                end
            end)
            if setting.preset then
                setting.extra:SetScript("OnClick", function()
                    local default = tonumber(C_CVar.GetCVarDefault(setting.name))
                    if default then Apply(setting, default) else Refresh() end
                end)
            end
        end
    end

    for _, event in ipairs({ "CVAR_UPDATE", "UPDATE_BINDINGS", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        page:RegisterEvent(event)
    end
    page:SetScript("OnEvent", function()
        if page:IsVisible() then Refresh(lastNotice) end
    end)
    function addon.RefreshFishingSettings()
        if page:IsVisible() then Refresh(lastNotice) end
    end
    return Refresh
end
