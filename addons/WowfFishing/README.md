# 无限钓鱼助手

为《魔兽世界：无限》制作的钓鱼辅助插件，当前版本 0.5.14，客户端接口版本 16001。

## 使用

- `/wowfish setup` 打开配置向导。选择背包里的鱼竿，再选择并装备要换回的主手武器，当前副手会一并记录。装备所选鱼竿后，点击快捷键按钮并按下要录入的按键或组合键，按 Esc 可取消本次录入。保存前请关闭角色窗口里的装备管理器。
- 点击工具栏上的装备图标或按设置的快捷键换装。点击三条横杠图标可打开或关闭钓鱼面板。
- 已有 F、W 方案的角色可继续用原有 M 键切换。输入 `/wowfish m on` 可启用 M 键。
- 装备鱼竿后，左键点击鱼钩图标抛竿。听到水花声后右键点击浮漂收竿。
- 按住工具栏最右侧的四向箭头可移动工具栏。按住钓鱼面板的标题栏可移动面板。两处位置分别保存。
- 在钓鱼面板点击「设置抛竿 / 收竿键」，按下空闲键后松开即可保存。也可用 `/wowfish bind G` 设置，G 可以替换。在游戏设置启用交互键，听见浮漂水花声后按同一键收竿。
- 换装键和抛竿 / 收竿键都支持小键盘数字、运算符、小数点和组合键。用命令设置时，可输入 `/wowfish bind NUMPAD5`。
- `/wowfish` 或 `/wowfish loot` 打开钓鱼面板，查看抛竿统计、渔获、拍卖行和 NPC 单价及合计金额。总价采用当前保存的单价乘数量，缺少价格的数量会另行标明。
- 打开拍卖行后点「更新拍卖价」。本次无渔获时会查询资料库里的鱼类和烹饪成品，报价和查询时间可在资料库中查看。
- 点击水花声旁的「鱼类资料」或面板底部的「关于」，可打开各自的窗口。也可使用 `/wowfish fish` 和 `/wowfish about`。

本次渔获在重新登录或重载界面时清零。拍卖报价和本角色的累计钓获数量、地点会保存。累计记录从启用资料库后开始。

## 鱼类资料

当前目录有 88 条记录，包括普通鱼 29 条、任务鱼 7 条、比赛鱼 4 条、纪念鱼 36 条和膨胀鱼 12 条。纪念鱼按不同重量分别列出。物品资料核对客户端版本为 1.60.1.70862。

鱼名和 NPC 价格优先取游戏客户端的当前信息。部分物品在客户端缓存完成前显示英文名称，加载物品资料后会更新。

钓点包含经典旧世的参考资料和无限服玩家报告，游戏内逐项标明。无限服新增鱼类及钓点仍在补充，钓获条件未核实的条目标为待确认。插件会保存本角色在无限服实际钓到的地点和数量，用于持续核对。

点击鱼类详情中的参考钓点可打开游戏世界地图。没有独立地图的洞穴、海湾和岛屿会打开所在地区。地点与地图编号依据国服客户端的 AreaTable 和 UiMap。 [地图数据](https://wago.tools/db2/UiMap?build=1.60.1.70862)

## 烹饪资料

「烹饪」收录 24 条使用资料库鱼类作原料的配方。可按配方、材料或成品查找，也可从鱼类详情直接打开相关配方。每条配方列出技能变色点数、材料用量及成品。鱼类和成品使用游戏内物品图标，鼠标悬停可查看当前游戏说明。

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
- **WOWF.IO** 的钓鱼渔获资料用于补充中文鱼名、配方用途与参考地区。感谢整理鱼类专题。[钓鱼渔获](https://wowf.io/zh/professions/fishing/catch)
- **Wowhead 玩家报告** 为无限新增鱼「奇想鳍鱼」在赤脊山鱼群的记录提供线索，资料页标为待本角色实钓核对。感谢参与提交钓鱼观察的玩家。[奇想鳍鱼](https://www.wowhead.com/forever/item=251524/whimsyfin)

上述网站与作者各自拥有相关内容的权利。游戏物品名称、图标与游戏数据属于 Blizzard Entertainment。第三方 MIT 授权声明随插件一并保留。
