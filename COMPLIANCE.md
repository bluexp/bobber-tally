# BobberTally 规则与代码审查

2026 年 11 月 11 日审查了《魔兽世界：无限》国服规则、v0.3.1 的 Lua 源码及下载包。v0.4.0 换装向导的实现见下节。 [v0.3.1 审查原文](https://github.com/bluexp/bobber-tally/blob/01fca65/COMPLIANCE.md)

## v0.4.0 换装向导

向导读取背包和主手装备以列出鱼竿与武器。玩家点击「装备所选」后，插件调用游戏的装备接口。向导通过游戏装备管理器保存主副手方案，设置完成后由玩家点击屏幕按钮或按换装键触发切换。战斗中会拒绝换装。快捷键、方案引用、按钮坐标和锁定状态保存在本角色的本地设置中。 [Setup.lua](addons/WowfFishing/Setup.lua) · [Fishing.lua](addons/WowfFishing/Fishing.lua)

## 审查结论

按当前公开规则及源码，BobberTally 具备免费、源码可查、由玩家按键操作的游戏内界面插件特征。代码审查未发现无人值守钓鱼、外部输入模拟、客户端修改或交易自动化的执行路径。暴雪和国服运营方保留解释规则、认定违规和禁用插件功能的权利。公开规则可以支持对实现方式的判断，官方对具体插件的认定须以运营方答复为准。[国服插件治理公告](https://wow.blizzard.cn/news/20260924/43790_1314928.html) · [无限环境治理总则](https://wow.blizzard.cn/news/20261104/43836_1318588.html) · [暴雪插件开发政策](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642)

| 项目 | 实现证据 | 审查判断 |
| --- | --- | --- |
| 抛竿与收竿 | `UpdateBindings` 在引导状态改变后重新绑定同一按键。抛竿通过游戏的安全按钮施法，收竿使用游戏内 `INTERACTTARGET`。每次都需要玩家重新按键。 | 引导事件只更新绑定与界面。施法和交互由独立的玩家输入触发。 |
| 装备和音量 | `ToggleEquipment` 由按钮或 M 键触发，战斗中退出，使用游戏装备管理器切换方案。音效增强调整游戏音量选项，计时器用于恢复音量。 | 换装与显示依赖现有游戏功能，声音提示来自游戏原有水花音效。 |
| 渔获与估价 | 插件在 `LOOT_SLOT_CLEARED` 后统计渔获。拍卖查询从拍卖行开启时的「更新拍卖价」点击开始，受客户端节流限制。报价读取挂单结果。 | 渔获记录与挂单查询属于信息展示。估价使用游戏内货币，购买、挂单、竞价和销售由玩家在游戏中另行操作。 |
| 数据与隐私 | `WowfFishingDB` 按角色在本地保存按键、音量恢复值、物品报价和渔获地区统计。下载包包含 Lua、TOC、说明和第三方授权文件。 | 数据保留在本地游戏保存变量。主页和下载包采用独立项目名称，公开版本的 M 键设置由玩家启用。 |
| 分发 | GitHub 可直接阅读未混淆 Lua，下载包免费，游戏内说明列出来源和致谢。 | 符合源码可查、免费、无广告及游戏内捐赠引导的发布要求。 |

实施依据见 [Fishing.lua](addons/WowfFishing/Fishing.lua)、[CatchList.lua](addons/WowfFishing/CatchList.lua)、[FishCatalog.lua](addons/WowfFishing/FishCatalog.lua) 和 [WowfFishing.toc](addons/WowfFishing/WowfFishing.toc)。对机器人、未授权程序、数据探测和扰乱运营的条款见[国服战网最终用户许可协议](https://legal.battlenet.com.cn/zh-cn/legal/simple/2e90163d-612f-41a5-addd-8a837ac43d02/non-printable)。

## 第三方资料与发布范围

FishDex 引用部分随包保留 MIT 授权和版权声明。客户端物品资料与参考钓点逐项标明来源，静态资料包含物品名称、编号、地点与用途等参考字段。公开可读的第三方资料仍受各自的权利与使用条款约束，已核实的 MIT 授权适用于 FishDex 引用部分。游戏截图用于免费玩家项目的功能说明，并保留游戏权属提示。[资料来源与致谢](addons/WowfFishing/README.md) · [FishDex 授权](addons/WowfFishing/THIRD_PARTY_LICENSES.txt) · [暴雪玩家网站法律问答](https://www.blizzard.com/it-it/legal/c1ae32ac-7ff9-4ac3-a03b-fc04b8697010/blizzard-legal-faq)

## English summary

BobberTally is distributed free of charge with readable Lua source. Casting and reeling require separate player inputs through the game’s secure spell button and Interact action. The add-on records completed loot events and refreshes auction listings after a player requests a lookup at the Auction House. Character settings and observations are stored locally in the game’s saved variables. This review describes the source and the published rules. The publisher and operator retain final authority over add-on use. [WoW UI Add-On Development Policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642) · [China Battle.net EULA](https://legal.battlenet.com.cn/zh-cn/legal/simple/2e90163d-612f-41a5-addd-8a837ac43d02/non-printable)
