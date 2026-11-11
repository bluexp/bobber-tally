local _, addon = ...

local panel = CreateFrame("Frame", "WowfFishingAbout", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(560, 444)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOPLEFT", 12, -6)
title:SetText("无限钓鱼助手 · 说明与致谢")

local scroll = CreateFrame("ScrollFrame", nil, panel)
scroll:SetPoint("TOPLEFT", 17, -36)
scroll:SetSize(525, 385)
scroll:EnableMouseWheel(true)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(515, 385)
scroll:SetScrollChild(content)
local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetPoint("TOPLEFT", 0, 0)
text:SetWidth(515)
text:SetJustifyH("LEFT")
text:SetSpacing(3)
text:SetText(table.concat({
    "|cffffd100无限钓鱼助手 0.4.1|r",
    "为《魔兽世界：无限》制作的钓鱼辅助插件。",
    "",
    "|cffffd100使用方法|r",
    "/wowfish setup 打开配置向导，选择鱼竿、武器和换装快捷键。",
    "完成后拖动屏幕上的换装按钮，再点「固定」保存位置。",
    "已有 F、W 方案的角色可继续使用原有 M 键换装。",
    "/wowfish 打开主面板。/wowfish bind G 设置空闲的抛竿键。",
    "在游戏设置开启交互键后，听见浮漂水花声再按同一键收竿。",
    "/wowfish loot 查看本次渔获、两种单价和总价。",
    "打开拍卖行后点更新拍卖价，报价旁会显示查询时间。",
    "总价按单价乘数量计算，缺少报价的数量会另行标明。",
    "/wowfish fish 打开鱼类资料库，支持名称、地点和类别搜索。",
    "本次渔获在登录或重载时清零，鱼类累计记录和拍卖报价会保存。",
    "",
    "|cffffd100资料说明|r",
    "收录 88 条鱼类资料，物品名称和编号依据客户端 1.60.1.70862 核对。",
    "钓点包括经典旧世参考和玩家报告，资料页逐项标明来源。本角色在无限服的钓获会累计记录地点与数量。",
    "",
    "|cffffd100参考资料与感谢|r",
    "感谢 Blizzard Entertainment 提供界面和插件 API，感谢 Gethe 维护界面源码镜像。",
    "github.com/Gethe/wow-ui-source/tree/forever",
    "感谢 DasAoD 的 Fishing-OneKey，抛竿与交互键的实现参考了其公开源码。",
    "github.com/DasAoD/Fishing-Onekey",
    "感谢 DigitalPenguin1 的 Classic Fishing Companion，为钓鱼事件识别与水花声增强提供参考。",
    "github.com/DigitalPenguin1/ClassicFishingCompanion",
    "感谢 xIGBClutchIx / ForeverPlusPlus 分享无限服 API 与拍卖行实测记录。",
    "github.com/xIGBClutchIx/ForeverPlusPlus",
    "感谢 renaud 的 FishDex 开放鱼类目录，相关数据依照 MIT 授权引用。",
    "github.com/Renaud-Sto/FishDex",
    "感谢 timemir / Pagle 对无限服鱼类资料范围和数据缺口的公开研究。",
    "github.com/timemir/pagle-addon",
    "感谢 Wago.tools 提供客户端数据导出，感谢无限图鉴与 WOWF.IO 整理中文物品及鱼类资料。",
    "wago.tools · wuxianwow.com · wowf.io",
    "完整来源链接和第三方授权见插件目录中的 README.md 与 THIRD_PARTY_LICENSES.txt。",
}, "\n"))

panel:SetScript("OnShow", function()
    content:SetHeight(math.max(385, text:GetStringHeight() + 12))
end)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local offset = self:GetVerticalScroll() - delta * 40
    self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
end)

function addon.ToggleAbout()
    panel:SetShown(not panel:IsShown())
end
