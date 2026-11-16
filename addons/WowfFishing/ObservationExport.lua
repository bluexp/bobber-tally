local _, addon = ...
local L, theme = addon.L, addon.Theme
local knownFish = {}
for _, fish in ipairs(addon.FishData.entries) do
    knownFish[fish.id] = true
end

local history
local historyLimit, exportLimit = 120, 20
local regionCodes = { [1] = "US", [2] = "KR", [3] = "EU", [4] = "TW", [5] = "CN" }
local _, build = GetBuildInfo()
local clientBuild = tonumber(build) or 0

function addon.InitializeObservationExport(db)
    db.wfdbObservations = db.wfdbObservations or {}
    history = db.wfdbObservations
end

function addon.RecordWFDBObservation(itemID, count, lure)
    if not knownFish[itemID] then return end
    local region = regionCodes[GetCurrentRegion and GetCurrentRegion()] or "UNKNOWN"
    local mapID = C_Map.GetBestMapForUnit("player") or 0
    local day = math.floor(GetServerTime() / 86400)
    local key = ("%d,%d,%d,%s,%d,%s"):format(itemID, mapID, day, region, clientBuild, lure)
    local previous
    for index = #history, 1, -1 do
        if history[index].key == key then
            previous = table.remove(history, index)
            break
        end
    end
    history[#history + 1] = { key = key, count = (previous and previous.count or 0) + count }
    if #history > historyLimit then table.remove(history, 1) end
end

local panel = theme.CreatePanel("WowfFishingObservationExport")
panel:SetSize(540, 200)
panel:SetPoint("CENTER")
panel:SetMovable(true)
local surface = theme.Surface(panel)
addon.SetLocalizedText(theme.Label(panel, "GameFontNormal", 16, -4, 470), "导出 WFDB 钓鱼记录")

local titleBar = CreateFrame("Frame", nil, panel)
titleBar:SetPoint("TOPLEFT", 8, -2)
titleBar:SetPoint("TOPRIGHT", -32, -2)
titleBar:SetHeight(20)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() panel:StartMoving() end)
titleBar:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)

local help = theme.Label(surface, "GameFontHighlight", 20, -44, 500, nil, theme.colors.text)
addon.SetLocalizedText(help, "复制下方记录，再打开 wfdb.cc/fishing/ 预览。")

local edit = CreateFrame("EditBox", nil, surface, "InputBoxTemplate")
edit:SetAutoFocus(false)
edit:SetSize(486, 30)
edit:SetPoint("TOPLEFT", 24, -91)
edit:SetMaxLetters(4096)
edit:SetScript("OnEscapePressed", function() panel:Hide() end)
edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

local status = theme.Label(surface, "GameFontHighlightSmall", 20, -134, 500, nil, theme.colors.muted)
status:SetMaxLines(2)
panel:SetScript("OnHide", function()
    panel:StopMovingOrSizing()
    edit:ClearFocus()
end)

function addon.ShowObservationExport()
    local rows = {}
    for index = #history, math.max(1, #history - exportLimit + 1), -1 do
        local row = history[index]
        rows[#rows + 1] = row.key .. "," .. row.count
    end
    edit:SetText(#rows > 0 and ("WFDB1:" .. table.concat(rows, ";")) or "")
    status:SetText(#rows > 0 and L["已选中 %d 组近期记录，按 Ctrl+C 或 ⌘C 复制。"]:format(#rows)
        or L["暂无可导出的记录。钓到资料库里的条目后会在这里显示。"])
    theme.ShowPanel(panel)
    if #rows > 0 then
        edit:SetFocus()
        edit:HighlightText()
    end
end
