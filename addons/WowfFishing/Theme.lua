local _, addon = ...
local theme = {}
addon.Theme = theme

local colors = {
    surface = { 0.055, 0.071, 0.088, 1 },
    card = { 0.082, 0.103, 0.124, 1 },
    control = { 0.115, 0.142, 0.168, 1 },
    selected = { 0.19, 0.16, 0.12, 1 },
    gold = { 0.94, 0.75, 0.44, 1 },
    text = { 0.94, 0.93, 0.89, 1 },
    muted = { 0.61, 0.73, 0.81, 1 },
    disabled = { 0.53, 0.58, 0.63, 1 },
    divider = { 0.68, 0.76, 0.84, 0.2 },
    hover = { 0.75, 0.86, 0.95, 0.11 },
}
theme.colors = colors
theme.goldText = "|cffe9c483"

function theme.CreatePanel(name)
    local panel = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    panel:Hide()
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    -- Keep the window and its child controls together when it is raised.
    panel:SetToplevel(true)
    local backing = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    backing:SetAllPoints()
    backing:SetColorTexture(unpack(colors.surface))
    return panel
end

function theme.ShowPanel(panel)
    if panel:IsShown() then
        panel:Raise()
    else
        panel:Show()
    end
end

function theme.TogglePanel(panel)
    if panel:IsShown() then
        panel:Hide()
    else
        theme.ShowPanel(panel)
    end
end

function theme.Fill(frame, layer, color)
    local texture = frame:CreateTexture(nil, layer)
    texture:SetAllPoints()
    texture:SetColorTexture(unpack(color))
    return texture
end

function theme.Surface(panel)
    local surface = CreateFrame("Frame", nil, panel)
    surface:SetAllPoints()
    local background = theme.Fill(surface, "BACKGROUND", colors.surface)
    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", 5, -22)
    background:SetPoint("BOTTOMRIGHT", -5, 6)
    return surface
end

function theme.Block(frame, layer, x, y, width, height, color)
    local texture = frame:CreateTexture(nil, layer)
    texture:SetPoint("TOPLEFT", x, y)
    texture:SetSize(width, height)
    texture:SetColorTexture(unpack(color))
    return texture
end

function theme.Label(parent, font, x, y, width, alignment, color)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH(alignment or "LEFT")
    label:SetJustifyV("TOP")
    if color then label:SetTextColor(unpack(color)) end
    return label
end

function theme.Highlight(button)
    button:SetHighlightTexture(theme.Fill(button, "HIGHLIGHT", colors.hover))
end

function theme.Button(parent, name, text, width, height, primary)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(width, height)
    local fill = theme.Fill(button, "BACKGROUND", primary and colors.selected or colors.control)
    theme.Highlight(button)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 4, 0)
    label:SetPoint("RIGHT", -4, 0)
    label:SetJustifyH("CENTER")
    label:SetMaxLines(1)
    button:SetFontString(label)
    if text ~= "" then addon.SetLocalizedText(button, text) end
    local function RefreshStyle(self)
        local enabled = self:IsEnabled()
        local color = enabled and (primary and colors.gold or colors.text) or colors.disabled
        label:SetTextColor(unpack(color))
        fill:SetColorTexture(unpack(enabled and (primary and colors.selected or colors.control) or colors.card))
    end
    button:SetScript("OnEnable", RefreshStyle)
    button:SetScript("OnDisable", RefreshStyle)
    RefreshStyle(button)
    return button
end

function theme.ItemIcon(itemID)
    return (itemID and select(5, C_Item.GetItemInfoInstant(itemID))) or 134400
end
