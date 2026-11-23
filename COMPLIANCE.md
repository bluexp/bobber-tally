# BobberTally 规则与代码审查

2026 年 11 月 24 日复核国服《魔兽世界：无限》的 BobberTally v0.11.6（接口 `16001`），对照发布标签、三个公开下载入口及本机客户端的插件文件。2026 年 11 月 11 日的 v0.3.1 审查保留在历史版本中。 [v0.11.6 发布](https://github.com/bluexp/bobber-tally/releases/tag/v0.11.6) · [v0.3.1 审查原文](https://github.com/bluexp/bobber-tally/blob/01fca65/COMPLIANCE.md)

## v0.11.6 复核结论

已核实免费分发、可读源码和手动抛竿收竿。发布包内未发现自动抛竿、自动收竿、模拟输入、客户端二进制修改或自动交易的执行路径。公开条款允许暴雪和国服运营方判断对服务器及玩家的实际影响，并禁用插件功能。本次未查到针对 BobberTally 的公开认定。11 月 23 日的处罚公告未列出所查九款外挂的名称。 [暴雪插件开发政策](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) · [国服插件治理公告](https://wow.blizzard.cn/news/20260924/43790_1314928.html) · [无限环境治理总则](https://wow.blizzard.cn/news/20261104/43836_1318588.html) · [11 月 23 日处罚公告](https://wow.blizzard.cn/news/20261123/43790_1320294.html)

| 审查项 | v0.11.6 的实现与判断 |
| --- | --- |
| 免费与源码可见 | GitHub Releases 和 WFDB 公开提供完整下载，独立站转到 WFDB。同一 ZIP 包含 14 个可读 Lua、1 个 TOC 和 5 个说明或许可文件。自定义的非商业及署名许可允许免费查看源码及非商业使用，无付费解锁、订阅或账号登录门槛。 [GitHub](https://github.com/bluexp/bobber-tally/releases/tag/v0.11.6) · [WFDB 下载](https://wfdb.cc/downloads/#bobber-tally) · [许可](LICENSE) |
| 游戏内广告、捐赠与内容 | 未见商品、付费服务推广、捐赠引导或有害内容。「关于」列有 WFDB 首页、安装、资料库和论坛的文本地址，另列第三方来源与致谢。政策禁止游戏内广告，未就此类站点入口给出具体判断。 [关于面板](addons/WowfFishing/About.lua#L28) · [政策第 4–6 条](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) |
| 抛竿、收竿与换装 | 玩家先录入快捷键。抛竿使用游戏安全动作按钮，钓鱼引导开始后插件只改绑到游戏原生交互，玩家再次输入才可收竿。装备切换由玩家单独按键或点击，战斗中拒绝请求。水花声增强只调整游戏声音设置，计时器用于恢复音量。 [钓鱼绑定与引导](addons/WowfFishing/Fishing.lua#L248) · [换装入口](addons/WowfFishing/Fishing.lua#L384) · [暴雪原生交互键说明](https://news.blizzard.com/en-us/article/23876525/accessibility-updates-in-dragonflight) |
| 首次设置与自动拾取 | 账号首次运行 v0.11.6 时，即使未录入插件键位，也会尝试开启游戏的键鼠交互。成功后记住初始化，之后保留玩家的选择。此项影响整个游戏。「自动拾取」是游戏原生设置，由玩家点击才修改。鱼漂搜索角度和距离也由玩家点击才修改，实际交互距离由客户端判定。 [游戏设置代码](addons/WowfFishing/FishingSettings.lua#L13) |
| 拍卖行与性能 | 打开拍卖行且浏览页可见时默认自动查价，可关闭并手动更新。有本次渔获时查询其物品，无记录时查询鱼类和食谱产物。查价按最多 40 种分批，检查客户端节流，每批最多发起三次，45 秒超时，关闭拍卖行即停止。「我的挂单」也检查客户端节流。未发现后台持续扫描或购买、竞价、挂单调用。客户端节流只能说明请求受限，服务器实际影响由运营方判定。 [查价代码](addons/WowfFishing/CatchList.lua#L507) · [在售查询](addons/WowfFishing/AuctionWatch.lua#L359) |
| 本地统计、邮箱与导出 | 本地统计当前角色的渔获、鱼类挂单和结算数据，邮箱打开后通过游戏接口读取鱼类结算单的必要字段，未保存交易对手身份或邮件正文。插件未发现聊天广播或自动向外部发送记录的路径。`/wowfish export` 生成物品编号、地图、UTC 日期、地区、游戏构建号、鱼饵状态和数量，不含账号、角色名或服务器名。网页预览在浏览器内解析，公开投稿由玩家另行提交，GitHub 会显示发帖账号。 [邮箱结算](addons/WowfFishing/AuctionWatch.lua#L381) · [导出代码](addons/WowfFishing/ObservationExport.lua#L14) · [投稿预览](https://wfdb.cc/fishing/#submit) · [国服 EULA 第 1.C.6、7.C 条](https://legal.battlenet.com.cn/zh-cn/legal/2e90163d-612f-41a5-addd-8a837ac43d02/non-printable) |
| 第三方权利 | FishDex 的 MIT 声明已随包，声音和图标调用客户端现有资源，安装包未附游戏音频或图像。Fishing-OneKey 与 Classic Fishing Companion 分别列为同键操作和声音逻辑的参考。前者的当前公开仓库未见明确源码许可，后者使用 GPLv3。当前对应实现使用共同的游戏接口，未见整段照搬。此项对比只覆盖列出的直接参考功能，第三方表达和数据仍依各自授权判断。 [致谢](addons/WowfFishing/README.md#来源与致谢) · [随包许可](addons/WowfFishing/THIRD_PARTY_LICENSES.txt) · [Fishing-OneKey](https://github.com/DasAoD/Fishing-Onekey) · [Classic Fishing Companion 许可](https://github.com/DigitalPenguin1/ClassicFishingCompanion/blob/main/LICENSE) |

较稳妥的默认设置是让玩家主动开启交互键和水花声增强，并让拍卖价在玩家点击后查询，自动查价作为可选项。说明交互键会修改整个游戏的设置，保留玩家已有的游戏及插件选择。游戏内「关于」可缩减为用法、版本和署名，把站点导航放在下载页或 README。在国服运营方作出具体答复前，对外用「免费第三方插件，玩家按键抛竿和收竿」描述。

此次逐文件核对 GitHub、WFDB、独立站下载包以及工作区和本机已安装文件。20 个文件一致，ZIP 的 SHA-256 为 `f3f8ce1ee5b1869b5d076606885afb5a87ce736a9160c42308c0e19127534fbd`。14 个 Lua 文件通过语法检查。用模拟客户端接口验证首次写入、保留关停选择和被客户端拒绝后重试。本次未进行国服实机输入或拍卖行负载测量。复核范围为插件及其分发包，桌面客户端读取存档的行为须另行评估。

## v0.11.4 安装包许可

2026 年 11 月 18 日，正式安装包加入 `LICENSE`、`NOTICE` 和 `LICENSING.md`，继续保留 FishDex 的 `THIRD_PARTY_LICENSES.txt`。插件原创部分按非商业使用及署名许可 1.0 提供；第三方独立许可与历史发布包保持原样。Lua 仅更新“关于”版本号，钓鱼逻辑沿用 v0.11.3。

## v0.11.2 快捷键直接录入

玩家可直接录入已有游戏绑定的键。插件通过临时覆盖让该键触发玩家所选的动作。换键、清除或停用后，游戏原绑定恢复。插件的两个动作使用同一键时，以最后保存的为准。换装、抛竿和收竿仍由玩家按键触发。

## v0.6.0 统一设置和鼠标侧键

键盘与鼠标侧键使用同一套游戏内绑定接口。玩家明确确认后，插件可暂时覆盖某个已有游戏绑定。清除插件绑定后，原绑定恢复。v0.6.0 的交互键、自动拾取和鱼漂搜索选项均由玩家在设置页逐项修改。向导仅在玩家点击后请求换装，随后等待装备结果并记录方案。 [v0.6.0 代码](https://github.com/bluexp/bobber-tally/tree/v0.6.0/addons/WowfFishing)

## v0.5.7 工具栏和钓鱼面板

鱼钩图标由玩家点击后通过游戏的安全动作按钮抛竿。浮漂交互仍由玩家点击或按键触发。工具栏和合并面板的位置按角色保存在本地游戏设置。 [Fishing.lua](addons/WowfFishing/Fishing.lua) · [CatchList.lua](addons/WowfFishing/CatchList.lua)

## v0.4.0 换装向导

向导读取背包和主手装备以列出鱼竿与武器。玩家点击「装备所选」后，插件调用游戏的装备接口。向导通过游戏装备管理器保存主副手方案，设置完成后由玩家点击屏幕按钮或按换装键触发切换。战斗中会拒绝换装。快捷键、方案引用、按钮坐标和锁定状态保存在本角色的本地设置中。 [Setup.lua](addons/WowfFishing/Setup.lua) · [Fishing.lua](addons/WowfFishing/Fishing.lua)

## 第三方资料与发布范围

2026 年 11 月 17 日制定 [BobberTally 非商业使用及署名许可协议 1.0](LICENSE)，适用于明确附带该协议的原创插件源码及指定配套文档。该协议禁止商用，要求保留作者和来源，属于源码可用许可。它不替代游戏平台条款，不改变 FishDex 等第三方的独立许可，也不追溯改写既有发布 ZIP 或标签。[许可问答](addons/WowfFishing/LICENSING.md) · [署名声明](NOTICE)

FishDex 引用部分随包保留 MIT 授权和版权声明。客户端物品资料与参考钓点逐项标明来源，静态资料包含物品名称、编号、地点与用途等参考字段。公开可读的第三方资料仍受各自的权利与使用条款约束，已核实的 MIT 授权适用于 FishDex 引用部分。游戏截图用于免费玩家项目的功能说明，并保留游戏权属提示。[资料来源与致谢](addons/WowfFishing/README.md) · [FishDex 授权](addons/WowfFishing/THIRD_PARTY_LICENSES.txt) · [暴雪玩家网站法律问答](https://www.blizzard.com/it-it/legal/c1ae32ac-7ff9-4ac3-a03b-fc04b8697010/blizzard-legal-faq)

## English summary

The [BobberTally Noncommercial Attribution License 1.0](LICENSE), prepared on November 17, 2026, covers only expressly accompanied copies of the original add-on and specified supporting files. This custom source-available license prohibits commercial use and requires attribution. It does not replace platform terms, restrict independent third-party licenses, or retroactively change release archives or tags.

The November 24, 2026 review verified the public v0.11.6 ZIP, its readable Lua source and the installed add-on files. Casting and reeling require separate player inputs through the game's secure spell button and Interact action. Version 0.11.6 enables the game's keyboard and mouse interaction on first load per account. Price searches can start automatically when the player opens the Auction House. Splash enhancement adjusts the game's sound settings while fishing. The review recommends opt-in for these three behaviors.

Catch and settlement data stay in the game's local saved variables. Players can copy the export manually and decide whether to submit it. The static review found no unattended fishing, simulated input, automated trading or automatic export transmission. In-game behavior and server load were outside this verification. The publisher and operator retain final authority over add-on use. [WoW UI Add-On Development Policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) · [China Battle.net EULA](https://legal.battlenet.com.cn/zh-cn/legal/2e90163d-612f-41a5-addd-8a837ac43d02/non-printable) · [China add-on enforcement notice](https://wow.blizzard.cn/news/20260924/43790_1314928.html)
