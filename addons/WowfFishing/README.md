# 无限钓鱼助手

为《魔兽世界：无限》制作的钓鱼辅助插件，当前源码版本 0.11.6，客户端接口版本 16001。

插件界面支持简体中文和英文，默认跟随客户端。可用 `/wowfish lang zh`、`/wowfish lang en` 或 `/wowfish lang auto` 为当前角色选择语言，再输入 `/reload` 生效。游戏原生物品提示及装备链接沿用客户端语言。

v0.11.5 改用非文本键盘监听来录入小键盘，并扩展方向键、符号键、鼠标中键、扩展键和滚轮的支持。原有快捷键、渔获记录和角色设置可继续使用。安装包包含非商业使用及署名许可 1.0、署名声明、许可问答及 FishDex 的 MIT 原文。

## 许可与署名 / License and attribution

原创插件代码及配套文档采用 [BobberTally 非商业使用及署名许可协议 1.0](LICENSE)。**禁止商用；非商业个人使用须保留出处，允许按协议学习、修改和免费分享。**个人本地使用保留 `LICENSE`、`NOTICE`、`THIRD_PARTY_LICENSES.txt` 和原署名即可，无需公开发布使用声明。公开分发注明 `BobberTally · 原作者 bluexp · https://github.com/bluexp/bobber-tally`；修改版标明非官方版本、修改者、日期与改动，并附完整可读源码。完整义务以协议为准。

这是自定义的源码可用许可，不是 OSI 开源许可。FishDex 引用数据仍按 MIT 授权，其他第三方内容按原权利处理。新协议只覆盖明确随附它的副本，不改写旧发布 ZIP 和标签。[署名声明](NOTICE) · [许可问答](LICENSING.md)

Original code and accompanying documentation use the [BobberTally Noncommercial Attribution License 1.0](LICENSE), a custom source-available license. **Commercial use is prohibited; noncommercial use requires attribution.** For private use, keep the license, notice, third-party licenses, and existing credits; no public announcement is needed. Public copies must identify BobberTally, original author bluexp, and the repository URL. Unofficial modifications must identify their author, date, and changes and include complete readable source. The full terms control. FishDex data retains MIT permissions; existing release archives and tags are preserved. See [NOTICE](NOTICE) and the [licensing FAQ](LICENSING.md).

## 使用

- `/wowfish gear` 或「钓鱼设置 → 换装方案」显示鱼竿、武器、主副手、当前装备和换装键。最近一次换装的目标、结果和时间会按角色保留，主副手都符合目标时才显示成功。方案缺失、装备找不到或装备槽不一致时，可在这里查看原因并打开换装向导。
- `/wowfish setup` 打开换装向导。选定鱼竿后，选择要换回的主手武器，点击「装备武器并继续」。游戏确认装备后会记录当时的副手并进入最后一步。录入换装键后，点击「装备鱼竿并保存」。保存前请关闭角色窗口里的装备管理器。
- 点击工具栏的装备图标或按快捷键换装。柱状图单独打开或关闭渔获统计，齿轮单独打开或关闭钓鱼设置。
- 已有 F、W 方案的角色可继续用原有 M 键切换。输入 `/wowfish m on` 可启用 M 键。
- 装备鱼竿后，左键点击鱼钩图标抛竿。听到水花声后右键点击浮漂收竿。
- 按住工具栏最右侧的四向箭头可移动工具栏。按住钓鱼面板的标题栏可移动面板。两处位置分别保存。
- 点击工具栏的齿轮，或输入 `/wowfish settings`。在「钓鱼操作」可直接管理两种快捷键、水花声增强、交互键、自动拾取和鱼漂搜索。v0.11.6 在每个游戏账号首次加载新版时自动开启交互键。此后可在「钓鱼操作」关闭，重载界面或切换角色会保留选择。开启交互键后，听见水花声再按同一个抛竿 / 收竿键。
- 点击录入按钮后可录入游戏能识别的字母、数字、小键盘、方向键、符号键和组合键。录入鼠标时，指针停在按钮上，再按中键、侧键或滚动滚轮。游戏可识别的鼠标扩展键编号到 `BUTTON31`，实际取决于鼠标和驱动。主键盘和小键盘的回车均禁用，Esc 取消录入。也可用 `/wowfish bind NUMPAD1` 或 `/wowfish bind BUTTON6` 设置抛竿键。
- 游戏已绑定的键可以直接录入。插件只在对应快捷键生效时临时覆盖原操作，换键、点击「清除」或停用插件后，原操作恢复。同一个键交给最后保存的插件动作，另一个动作的快捷键会清除。向导在保存换装方案时才应用快捷键变动。
- 鱼漂经常选不中时，可将搜索角度设为 2、搜索距离设为 30，并可分别恢复客户端默认值。
- `/wowfish` 或 `/wowfish loot` 打开钓鱼面板。顶部集中显示抛竿次数、有收获的竿数、渔获件数、钓鱼用时、两种总价和每小时统计，列表显示各物品的单价。列表底部的提示条显示最近渔获和鱼饵剩余时间。总价采用当前保存的单价乘数量，缺少价格的数量会另行标明。
- 「钓鱼设置 → 钓鱼操作」中的「打开拍卖行自动查价」默认开启，按角色保存。关闭后仍可在「购买」页底部或渔获统计中点「更新拍卖价」。手动搜索、离开「购买」页或关闭拍卖行会结束当前查价。渔获列表为空时会查询资料库中的渔获与烹饪成品。
- 在渔获统计里点「我的挂单」或输入 `/wowfish auctions`。窗口分为「在售挂单」「拍卖行已售」「每日记录」。打开拍卖行会同步挂单、一口价及拍卖行仍可查到的已售和应收。成交确认会出现在窗口和聊天框。打开游戏邮箱可按结算单累计鱼类出售所得，金额包含退回的押金并扣除手续费。
- 「每日记录」按角色保存。成交笔数按插件确认日记录，结算条数和实际所得按首次同步结算单的日期记录。用「上个记录日」「下个记录日」切换。升级前已有的累计所得继续显示，旧记录中有日期的各鱼种最近成交确认会带入每日记录。
- 点击「鱼类资料」可打开资料库。面板右下角的「关于」列出 WFDB 网站地址、插件说明和致谢。也可使用 `/wowfish fish` 和 `/wowfish about`。
- `/wowfish export` 导出最多 20 组近期实钓记录，可复制到 [WFDB 钓鱼数据库](https://wfdb.cc/fishing/) 预览。插件在本地记录渔获、地图、日期、地区、客户端版本、鱼饵状态与数量，由玩家决定是否投稿。

本次渔获在重新登录或重载界面后保留。右上角的「结束本次」在确认后清空本次渔获、计时和目标进度。计时只累计鱼竿引导时间，达到 1 分钟后显示每小时收获竿数、拍卖估价及 NPC 售价，缺价物品不计入对应估价。拍卖报价和本角色的累计钓获数量、地点独立保存。

在鱼类详情点「设置目标」可设置本次要钓的数量，完成进度显示在渔获面板。只统计设定目标后实际拾取的目标鱼。若客户端提供鱼竿的临时附魔剩余时间，渔获面板会显示鱼饵倒计时，并在最后 30 秒和到期时提醒。

## 渔获资料

当前源码目录有 89 条记录，包括普通鱼 27 条、任务鱼 7 条、比赛鱼 4 条、纪念鱼 29 条、膨胀鱼 12 条和非鱼类水产 10 条。在 `/wowfish fish` 中点「非鱼类水产」，可查看冬鱿鱼、黑爪龙虾、7 种不同重量的纪念龙虾和巨型蚌壳。物品资料核对客户端版本为 1.60.1.70862。

鱼名和 NPC 价格优先取游戏客户端的当前信息。部分物品在客户端缓存完成前显示英文名称，加载物品资料后会更新。

钓点标明参考资料、无限服玩家报告或社区实测的来源。社区实测须有可核对的无限服钓获记录，区服未公开时显示「未知」。黑爪龙虾和巨型蚌壳（物品 `7973`）的参考钓点见 WOWF.IO。冬鱿鱼的钓点可在 Forever Mastery 标注的 cMaNGOS Classic-DB 资料中核对，7 和 9 磅重龙虾的钓点来自 FishDex 经典旧世资料。 [WOWF.IO 渔获](https://wowf.io/zh/professions/fishing/catch) · [冬鱿鱼参考钓点](https://forevermastery.com/en/items/13755-raw-winter-squid) · [FishDex 数据](https://github.com/Renaud-Sto/FishDex/blob/603d1c1b776e7d9265c1e57c7233fc84f999e919/FishDex/Data.lua)

点「当前区域」可以筛选当前位置的鱼类，也可以在搜索框输入其他地区。鱼类详情会显示本角色实际钓到的地点和数量。悬停在社区实测的地点按钮上可查看原始记录网址。

点击鱼类详情中的钓点可打开游戏世界地图。没有独立地图的洞穴、海湾和岛屿会打开所在地区。地点与地图编号依据国服客户端的 AreaTable 和 UiMap。 [地图数据](https://wago.tools/db2/UiMap?build=1.60.1.70862)

## 烹饪资料

「烹饪」收录 24 条使用资料库渔获作原料的配方。可按配方、材料或成品查找，也可从渔获详情直接打开相关配方。每条配方列出技能变色点数、材料用量及成品。渔获和成品使用游戏内物品图标，鼠标悬停可查看当前游戏说明。

配方资料来自无限图鉴导出的国服客户端 1.60.1.70862，选取烹饪技能线 185 中使用资料库鱼类的配方，排除探索赛季分类。变黄和变灰取自客户端配方表，变绿按两者的中点计算。 [配方数据](https://wuxianwow.com/data/recipes.json) · [烹饪专业](https://wuxianwow.com/profession/185)

## 参考来源与致谢

感谢以下作者与项目公开源码、记录和游戏数据，为这个插件提供实现参考与资料基础。

- **Blizzard Entertainment / Gethe** 提供游戏界面与 API 文档及其源码镜像。装备管理、物品信息、拍卖行接口和事件按该资料核对。感谢暴雪提供插件接口，感谢 Gethe 维护源码镜像。[无限服界面源码](https://github.com/Gethe/wow-ui-source/tree/forever)
- **DasAoD / Fishing-OneKey** 的公开源码提供同键抛竿与交互键的实现参考。感谢作者分享。[Fishing-OneKey](https://github.com/DasAoD/Fishing-Onekey)
- **DigitalPenguin1 / Classic Fishing Companion** 的作者源码用于核对钓鱼战利品事件、水花声增强和声音设置恢复。感谢作者分享实现与修复记录。[Classic Fishing Companion](https://github.com/DigitalPenguin1/ClassicFishingCompanion)
- **xIGBClutchIx / ForeverPlusPlus** 的实测记录提供无限服接口差异和拍卖行首次查询可能返回空结果的参考。感谢维护者分享测试过程。[接口实测记录](https://github.com/xIGBClutchIx/ForeverPlusPlus/blob/main/docs/forever-api.md)
- **renaud / FishDex** 的 MIT 授权目录为普通鱼、任务鱼、纪念鱼编号与经典钓点提供数据种子。感谢作者开放数据。引用版本为 `603d1c1b776e7d9265c1e57c7233fc84f999e919`，完整授权保存在 `THIRD_PARTY_LICENSES.txt`。[FishDex 数据目录](https://github.com/Renaud-Sto/FishDex/blob/603d1c1b776e7d9265c1e57c7233fc84f999e919/FishDex/Data.lua)
- **timemir / Pagle** 对无限服鱼类资料范围、客户端数据与钓获地点资料的缺口做了公开研究，用于核对目录覆盖范围。感谢作者分享研究与来源记录。[鱼类数据研究](https://github.com/timemir/pagle-addon/blob/main/docs/research/forever-content-data.md)
- **Wago.tools** 提供客户端 `ItemSparse` 和 `AreaTable` 的公开数据导出，用于核对物品编号、重量鱼、膨胀鱼、卖价及地区名。感谢提供数据工具。[Wago.tools](https://wago.tools/db2/ItemSparse?build=1.60.1.70862)
- **无限图鉴 wuxianwow.com** 的公开中文客户端物品数据用于核对名称和 NPC 单价。数据清单版本为 `1.60.1.70862`。感谢整理与开放数据。[数据说明](https://wuxianwow.com/ai)、[物品数据](https://wuxianwow.com/data/items.json)
- **WOWF.IO** 是核对中文鱼名、配方用途与参考地区的优先资料。钓鱼专题同时提供鱼类清单与按区域查阅的钓点参考。[钓鱼渔获](https://wowf.io/zh/professions/fishing/catch) · [钓鱼点](https://wowf.io/zh/professions/fishing/nodes) · [数据来源说明](https://wowf.io/zh/about)
- **Wowhead 玩家报告** 为无限新增鱼「奇想鳍鱼」在赤脊山鱼群的记录提供线索，资料页标为待本角色实钓核对。感谢参与提交钓鱼观察的玩家。[奇想鳍鱼](https://www.wowhead.com/forever/item=251524/whimsyfin)
- **AzerDex / ForeverDB 社区** 的公开钓获记录用于核对提瑞斯法林地和银松森林的钓点。依据第 15 次发布逐条核对物品编号与地图。来源页的最后观察日期分别为 2026 年 10 月 21 日和 9 月 24 日，区服未公开。[采集方法](https://azerdex.com/about/data) · [提瑞斯法林地](https://azerdex.com/fishing/1420) · [银松森林开放水域](https://azerdex.com/fishing/1421) · [银松森林鼠尾鱼群](https://azerdex.com/object/-1569625634)

上述网站与作者各自拥有相关内容的权利。游戏物品名称、图标与游戏数据属于 Blizzard Entertainment。第三方 MIT 授权声明随插件一并保留。
