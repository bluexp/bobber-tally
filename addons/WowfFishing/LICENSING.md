# BobberTally 许可问答 / Licensing FAQ

协议版本 1.0，制定于 2026 年 11 月 17 日。本文帮助理解，完整且优先适用的条款见同目录 [LICENSE](LICENSE)，署名见 [NOTICE](NOTICE)。适用于明确随附新协议的副本；旧标签和既有发布 ZIP 保持原样。

## 能否免费自用？如何注明出处？

可以非商业自用、自学和自行修改。保留插件里的 `LICENSE`、`NOTICE`、`THIRD_PARTY_LICENSES.txt` 及已有署名和致谢即可，无需发帖打卡、注册或公开游戏账号。

## 发给朋友、做镜像或发布修改版可以吗？

可以免费、非商业分享。随包附上协议、署名和第三方许可，并在下载页或 README 清楚标明作者与来源。修改版还须标明非官方版本、修改者、日期和主要改动，随包提供完整可读的插件源码及必要构建说明，衍生部分沿用本协议 1.0。

可复制的署名：

```text
BobberTally（无限钓鱼助手），原作者 bluexp
项目来源：https://github.com/bluexp/bobber-tally
许可：BobberTally 非商业使用及署名许可协议 1.0
```

修改版以“基于 BobberTally（无限钓鱼助手）”开头，并另列你的修改信息。

## 哪些属于商用？

收费下载、付费整合包、会员专享、订阅解锁、有偿安装或维护、商业产品集成、工作室或代练业务使用，以及直接通过插件分发、演示、教程或推广获取广告、带货或赞助收益，都不在授权内。免费赠送但服务于营利业务，也不会自动变成非商业。

个人正常支付游戏订阅费，或在游戏内以虚拟货币进行正常游戏交易，不因此成为商用。通过现实货币交易游戏资产的业务属于商业使用。注明出处不能替代商业授权。

## 截图、视频和教程如何署名？

依赖本协议授权的公开展示，在正文、简介或相邻说明中注明项目、原作者及仓库链接即可，同一作品署名一次，无需每帧加水印。私人截图不需要公开发声明。广告分成、赞助等直接变现的功能演示或教程不在本许可内；独立的法定合理引用等权利仍按法律处理。

## 为什么不直接使用 MIT、GPL 或 CC BY-NC？

MIT、GPL 等通常允许商业使用，无法实现本项目的禁止商用要求。OSI《开源定义》第 6 条要求不限制商业领域使用，因此本项目准确称为“源码可用、非商业使用及署名许可”，不宣称是 OSI 开源。Creative Commons 官方也不建议将 CC 许可用于软件。

这是项目专用协议，`LicenseRef-BobberTally-NC-Attribution-1.0` 是自定义标识，不代表该协议已进入 SPDX 标准许可清单或经过 OSI 审批。

## FishDex 的 MIT 数据也禁止商用吗？旧版本呢？

本协议不能取消第三方许可的既有权利。FishDex 引用数据继续按 [MIT 原文](THIRD_PARTY_LICENSES.txt) 使用；单独依据 MIT 使用其数据时，应遵守 MIT，而不是将本项目的限制强加给它。完整插件包含本项目原创代码，使用完整插件仍须遵守本项目协议。其他引用资料和游戏素材按各自权利处理，署名本身不等于有权重新许可。

新协议只覆盖明确随附它的副本。既有发布 ZIP 和标签不被改写，有效旧授权不被追溯撤回；旧版没有项目许可也不表示默认允许商用。

## 参考项目的源码能否直接并入本许可？

不能仅凭已致谢就这样做。[Classic Fishing Companion 的 LICENSE](https://github.com/DigitalPenguin1/ClassicFishingCompanion/blob/main/LICENSE) 为 GPLv3；如实际复制其受保护代码，须评估并遵守 GPL 义务，不能通过本协议增设禁止商用限制。对于 [Fishing-OneKey](https://github.com/DasAoD/Fishing-Onekey)，本次核对的仓库根目录、README 和主 Lua 文件未见明确许可声明，公开可读也不能替代复制或再许可授权。

这些项目目前在使用说明中列为实现参考；本次许可设计不把参考关系当作版权授权，也不据此认定本项目构成或不构成衍生作品。可学习功能与 API 行为；拟纳入第三方受保护表达时，须先取得相容授权或排除有关内容。本协议只授权项目有权许可的原创部分。

## 如何咨询授权？

通过 [GitHub Issues](https://github.com/bluexp/bobber-tally/issues) 发起许可咨询或联系请求。商用须事先取得有权授权的对应版权人的明确书面许可，本项目不承诺提供该许可。不要在公开 Issue 填写身份、合同或其他敏感信息。

## 维护及打包

本次只制定许可 1.0，插件功能版本仍为 v0.11.3，不替换已发布 ZIP。后续正式发版须使用新的插件版本号，并运行仓库打包脚本：

```sh
python3 tools/package-bobber-tally.py vX.Y.Z
```

脚本要求根目录与插件内 `LICENSE`、`NOTICE` 完全一致，并将协议、署名、本问答及第三方许可随 TOC 和源码一起打包。已有输出文件不会被覆盖。编辑协议或署名时，先维护根目录版本，再同步到插件目录。

## 参考依据

- [OSI《开源定义》](https://opensource.org/osd)，第 6 条。
- [Creative Commons 软件许可问答](https://creativecommons.org/faq/#can-i-apply-a-creative-commons-license-to-software)。
- [GitHub：仓库许可与公开仓库的查看和 Fork 权利](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)。
- [暴雪插件开发政策](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642)。项目自身许可不能替代平台条款。

## English

License version 1.0 was prepared on November 17, 2026. This FAQ is explanatory; the accompanying [LICENSE](LICENSE) controls. [NOTICE](NOTICE) contains the required credit. Only copies expressly carrying the new license are covered; existing tags and release archives are preserved.

**Personal use:** Noncommercial play, study, and personal modifications are permitted. Keep the license, notice, third-party licenses, credits, and acknowledgments. No public usage announcement, registration, or identity disclosure is required.

**Sharing and modifications:** Free noncommercial redistribution is permitted. Include the full terms and notices and credit the project and source visibly. Identify unofficial modifications, their author, date, and main changes; include complete readable add-on source and necessary build instructions. Derivative portions remain under version 1.0 of the same terms.

```text
BobberTally, originally by bluexp
Source: https://github.com/bluexp/bobber-tally
License: BobberTally Noncommercial Attribution License 1.0
```

For modified versions, use “Based on BobberTally” and add modification details.

**Commercial use:** Paid downloads, paid bundles, membership gates, subscriptions, paid setup or maintenance, commercial integration, boosting businesses, and directly monetized distribution, demonstrations, tutorials, or promotion are excluded. Free access does not excuse supporting a for-profit business. Ordinary personal game subscriptions and normal in-game virtual-currency transactions alone are allowed; real-world trading businesses are commercial. Credit does not authorize commercial use.

**Screenshots and tutorials:** For public works relying on this grant, credit the project, original author, and repository once in the work or description. No frame-by-frame watermark is required. Private screenshots need no public announcement. Directly monetized demonstrations and tutorials are outside the grant; independent statutory rights remain unaffected.

**License classification:** MIT and GPL permit commercial use. A noncommercial restriction does not meet the [OSI definition](https://opensource.org/osd). [Creative Commons advises against CC licenses for software](https://creativecommons.org/faq/#can-i-apply-a-creative-commons-license-to-software). This project uses a custom source-available license. Its `LicenseRef` identifier is not a claim of SPDX listing or OSI approval.

**Third parties and history:** FishDex data retains its independent [MIT license](THIRD_PARTY_LICENSES.txt). Do not apply the project's restrictions to independently used MIT material. The complete add-on includes project code subject to these terms. Other third-party rights remain intact. New terms do not retroactively rewrite old archives or valid earlier permissions; an unlicensed public copy is not automatically available for commercial use.

**Implementation references:** [Classic Fishing Companion uses GPLv3](https://github.com/DigitalPenguin1/ClassicFishingCompanion/blob/main/LICENSE); copied protected code cannot simply be relicensed with a noncommercial restriction. No express license was found in the inspected Fishing-OneKey repository root, README, or main Lua file. Public availability and acknowledgments are not permission. These projects are identified as references; this licensing work does not determine derivative-work status. Obtain compatible rights or exclude protected third-party expression before incorporation. The project license grants only rights the licensors can grant.

**Contact:** Ask through [GitHub Issues](https://github.com/bluexp/bobber-tally/issues). Additional rights require prior express written consent from each authorized rightsholder; no commercial grant is promised. Keep sensitive details out of public issues.

**Packaging:** This licensing change does not change v0.11.3 functionality or replace its released archive. For the next release, use a new add-on version and `python3 tools/package-bobber-tally.py vX.Y.Z`. The script checks matching root/add-on license and notice files and includes this FAQ and all licensing files. Existing archives are never overwritten. Edit root LICENSE/NOTICE first, then synchronize their add-on copies.
