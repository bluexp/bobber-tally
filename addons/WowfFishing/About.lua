local _, addon = ...
local L = addon.L
local theme = addon.Theme
local colors = theme.colors

local panel = theme.CreatePanel("WowfFishingAbout")
panel:SetSize(560, 444)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

local surface = theme.Surface(panel)
addon.SetLocalizedText(theme.Label(panel, "GameFontHighlight", 16, -4, 500), "无限钓鱼助手 · 关于")
theme.Block(surface, "BORDER", 14, -35, 532, 392, colors.card)

local scroll = CreateFrame("ScrollFrame", nil, surface)
scroll:SetPoint("TOPLEFT", 27, -48)
scroll:SetSize(505, 366)
scroll:EnableMouseWheel(true)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(505, 366)
scroll:SetScrollChild(content)
local text = theme.Label(content, "GameFontHighlight", 0, 0, 498, nil, colors.text)
text:SetSpacing(4)
panel:SetScript("OnShow", function()
    text:SetText(table.concat({
        theme.goldText .. L["无限钓鱼助手"] .. " 0.5.15|r",
        L["为《魔兽世界：无限》制作的钓鱼辅助插件。"],
        "",
        theme.goldText .. L["使用方法|r"],
        L["/wowfish setup 打开配置向导。点击快捷键按钮后直接按键，按 Esc 取消录入。"],
        L["换装键和抛竿 / 收竿键都支持小键盘。"],
        L["点击工具栏上的装备图标换装，点击三条横杠图标打开或关闭主面板。"],
        L["已有 F、W 方案的角色可继续使用原有 M 键换装。"],
        L["装备鱼竿后，左键点击鱼钩图标抛竿。按住工具栏最右侧的四向箭头可移动整组。"],
        L["点「设置抛竿 / 收竿键」并按下空闲键。开启游戏交互键后，按一次抛竿，听见水花声再按同一键收竿。"],
        L["/wowfish 或 /wowfish loot 打开钓鱼面板，查看抛竿统计、渔获详情、两种单价和总价。"],
        L["按住钓鱼面板的标题栏可单独移动窗口。"],
        L["打开拍卖行后点更新拍卖价。本次无渔获时会查询资料库的鱼类和烹饪成品。"],
        L["总价按单价乘数量计算，缺少报价的数量会另行标明。"],
        L["/wowfish fish 打开资料库，在「鱼类」和「烹饪」之间切换。悬停图标可查看物品说明，点击参考钓点可打开地图。"],
        L["本次渔获在登录或重载时清零，鱼类累计记录和拍卖报价会保存。"],
        L["使用 /wowfish lang zh 或 /wowfish lang en 切换语言，输入 /reload 应用。"],
        "",
        theme.goldText .. L["资料说明|r"],
        L["收录 88 条鱼类资料和 24 条以这些鱼为材料的烹饪配方，依据客户端 1.60.1.70862 核对。"],
        L["钓点包括经典旧世参考和玩家报告，资料页逐项标明来源。本角色在无限服的钓获会累计记录地点与数量。"],
        "",
        theme.goldText .. L["参考资料与感谢|r"],
        L["感谢 Blizzard Entertainment 提供界面和插件 API，感谢 Gethe 维护界面源码镜像。"],
        "github.com/Gethe/wow-ui-source/tree/forever",
        L["感谢 DasAoD 的 Fishing-OneKey，抛竿与交互键的实现参考了其公开源码。"],
        "github.com/DasAoD/Fishing-Onekey",
        L["感谢 DigitalPenguin1 的 Classic Fishing Companion，为钓鱼事件识别与水花声增强提供参考。"],
        "github.com/DigitalPenguin1/ClassicFishingCompanion",
        L["感谢 xIGBClutchIx / ForeverPlusPlus 分享无限服 API 与拍卖行实测记录。"],
        "github.com/xIGBClutchIx/ForeverPlusPlus",
        L["感谢 renaud 的 FishDex 开放鱼类目录，相关数据依照 MIT 授权引用。"],
        "github.com/Renaud-Sto/FishDex",
        L["感谢 timemir / Pagle 对无限服鱼类资料范围和数据缺口的公开研究。"],
        "github.com/timemir/pagle-addon",
        L["感谢 Wago.tools 提供客户端数据导出，感谢无限图鉴与 WOWF.IO 整理中文物品及鱼类资料。"],
        "wago.tools · wuxianwow.com · wowf.io",
        L["完整来源链接和第三方授权见插件目录中的 README.md 与 THIRD_PARTY_LICENSES.txt。"],
    }, "\n"))
    content:SetHeight(math.max(366, text:GetStringHeight() + 12))
end)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local offset = self:GetVerticalScroll() - delta * 40
    self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
end)

function addon.ToggleAbout()
    theme.TogglePanel(panel)
end
