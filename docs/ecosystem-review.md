# 选题调查（2026-10-13）

本项目在选题前调查了现有 MoonBit 格式处理库，交付 GEDCOM 家谱数据交换与关系图工具库。JSON Patch 方向已有 Xu107-hhh/moonbit-jsonpatch 等库，未列为本项目目标。

使用 `moon update` 更新的官方 Mooncakes 索引检查了 2,978 个模块的最新条目：名称、description 和 keywords 中未发现 GEDCOM/genealogy 库。GitHub repository search `moonbit gedcom` 返回 0；网页搜索也未找到同类 MoonBit 库。索引与搜索漏收录和尚未公开的参赛项目会影响结论，不能据此宣称唯一或保证初审通过。提交前应再次更新调查。

已排除的方向及实际重叠证据：

- PCAP/PCAPNG：cghyyrrt/moonbit-pcap 已包含解析、协议分析与导出。
- 固件 HEX/S-record：Zzqy-yi/firmware-image-toolkit、SongYZZZ/moon-firmware 已存在。
- WARC：xiaojing012/moon-warc；HAR：cpypypypy/har-toolkit。
- SARIF、VCD、字幕：索引与 GitHub 中已有同类工具。
- 终端录制：tonyfettes-ghostty、rabbita_xterm 已有 asciicast 播放示例，未选。

其他语言已有成熟 GEDCOM 工具，说明格式具有跨应用复用场景。本项目的生态增量是 MoonBit 可直接调用的数据模型、受限解析、审查与关系查询；不以包装外部解析器代替核心实现。

参考：

- https://gedcom.io/specifications/FamilySearchGEDCOMv7.html
- https://gedcom.io/tools/
- https://github.com/gedcom7code/js-gedcom
- https://moonbitlang.github.io/Hackathon2026/

当前赛事官网给出 10 月 31 日截止。正式申报和评审结果仍由参赛者与组委会确认。
