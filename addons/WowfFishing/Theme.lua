local _, addon = ...
local theme = {}
addon.Theme = theme

local colors = {
    card = { 0.07, 0.055, 0.04, 0.9 },
    control = { 0.21, 0.15, 0.09, 0.9 },
    selected = { 0.34, 0.23, 0.08, 0.9 },
    gold = { 1, 0.82, 0, 1 },
    text = { 0.98, 0.96, 0.9, 1 },
    muted = { 0.8, 0.76, 0.66, 1 },
    divider = { 0.69, 0.52, 0.28, 0.55 },
    hover = { 1, 0.82, 0, 0.13 },
}
theme.colors = colors
theme.goldText = "|cffffd100"

function theme.CreatePanel(name)
    local panel = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    panel:Hide()
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    -- Keep the window and its child controls together when it is raised.
    panel:SetToplevel(true)
    return panel
end

function theme.ShowPanel(panel)
    panel:Show()
    panel:Raise()
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
    return surface
end

function theme.Inset(parent, x, y, width, height)
    local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", x, y)
    inset:SetSize(width, height)
    return inset
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
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetNormalFontObject(primary and "GameFontNormal" or "GameFontNormalSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
    local label = button:GetFontString()
    label:ClearAllPoints()
    label:SetPoint("LEFT", 6, 0)
    label:SetPoint("RIGHT", -6, 0)
    label:SetMaxLines(1)
    if text ~= "" then addon.SetLocalizedText(button, text) end
    return button
end

function theme.ItemIcon(itemID)
    return (itemID and select(5, C_Item.GetItemInfoInstant(itemID))) or 134400
end
