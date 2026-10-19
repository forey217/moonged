# MoonGED 0.2.0 标准语义符合性

本次实现以官方 [FamilySearch GEDCOM 7.0.18](https://github.com/FamilySearch/GEDCOM/releases/tag/v7.0.18) 为基准。完整文本读写、标准结构和数据类型检查、可机械判定的跨记录约束已接入同一个 MoonBit 核心，SDK、CLI 和本地工作台共用。原来的“只保留文档并检查少量字段”范围由本版本替换。

## 交付与验证对应表

| 范围 | 实现 | 可重复的证据 |
| --- | --- | --- |
| 标准结构 | 179 种类型，1,379 种父子组合、9 种文档级位置；上下文分型、必填、单例、空结构、头尾及载荷类型 | `schema.mbt`；官方 YAML 正例遍历每个标准父子组合；删除必填项、重复单例、替换载荷的负例 |
| 枚举 | 全部 12 组，包括 ADOP、EVEN、EVENATTR、MEDI、PEDI、QUAY、RESN、ROLE、SEX、两类 STAT、NAME-TYPE；NO 随父结构约束 | 官方枚举逐值正例、非法值负例；枚举列表、扩展取值及 relocated-standard 规则 |
| 数据类型 | 文本、非负整数、枚举、日期三类、时间、年龄、列表、姓名、语言标签、媒体类型、Special、文件路径、URI、标签定义、经纬度；指针/空指针另按目标类型核对 | `datatypes.mbt`、`date_validation.mbt`、`semantic_wbtest.mbt`；位置敏感的载荷拒绝及格式边界正反例 |
| 日期 | 四种标准历法的月份、日数、闰年、纪元；精确日期只允许完整 Gregorian 日期；区间与时间段按上下文区分 | Gregorian/Julian/BCE、跨历法区间、法革历补充日、希伯来历大小月和闰月测试；独立 pyluach 2.3.0 的 1,040 个边界向量 |
| 跨记录 | 标识唯一、引用存在和目标类型；FAM 指向成员时必须存在对应 FAMS/FAMC；SOUR/SNOTE/OBJE 互引不得成环；REFN 不得在不同结构间复用 | 行号及关联行号诊断；家庭、来源/媒体循环、共享备注循环的正反例 |
| 跨结构 | 翻译必须声明格式，继承缺省语言/媒体类型，并与原文和同级翻译有不同的有效格式；泛型 EVEN/FACT/IDNO 的 TYPE 必填；NO 的事件位置合法 | 模式表要求与手写条件规则联合检查；翻译继承冲突、重复翻译及未知扩展案例 |
| 完整读写 | 全部记录、同类字段次序、CONT、显著空白、指针、未知扩展、Unicode 保留；文本规范化不经过人物投影重建 | 36 份文档输入/输出与独立解析器比对，另有 BOM/CRLF/空白 golden；详见 `text-conformance.md` |

表中 179 种类型包含 HEAD/TRLR，CONT 被解析器折叠为多行载荷，不重复计为普通节点。运行时共有 1,388 条结构位置规则（1,379 + 9）。官方 TSV 生成运行时表，官方发布包中的 YAML 独立提取测试定义，避免把实现自身生成的输出当预期。

## 验证结果和复现

本地 JS、Wasm GC、Wasm：57 个工作区测试通过，其中核心 55 个、独立消费模块 2 个。Node 的 11 个测试通过，其中包含 2,422 个官方 YAML 符合性案例：1,541 个正例、881 个负例。日期测试另包含 1,040 个独立向量。这些案例通过具体断言检验结果，不通过拆分提交满足次数。native 的实际结果以 GitHub Actions 为准。

```sh
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target wasm --deny-warn
node scripts/build-engine.mjs
node --test tests/*.test.mjs
node scripts/verify-interop.mjs --parser PATH_TO_JS_GEDCOM --schema PATH_TO_G7VALIDATION_JSON --report _build/interop.json
```

语义批量报告输出到 `_build/semantic-conformance.json`，含语料 SHA-256、通过数和失败明细。`spec/gedcom-7.0.18/provenance.json` 记录固定数据及许可证的校验值。Python 只用于离线生成测试资料和模式表，不参与 SDK、CLI 或网页运行。

官方源：`FamilySearch/GEDCOM` 的 `v7.0.18` 发布包，`extracted-files/`。重新生成模式：`python scripts/generate-schema.py` 后运行 `moon fmt`。独立语料生成脚本接受官方发布包的 `extracted-files/tags` 目录；日期向量脚本使用固定的 pyluach 2.3.0。标准数据保留 Apache-2.0 LICENSE、NOTICE；实现代码保持 MIT。

## 语义保留和计算边界

- 文本读写不丢字段，不改变标签拼写、真实指针、姓名优先顺序和扩展原文。规范化可以改变 BOM、换行和末尾换行。对非法语义文件也允许读取并报告；`normalize` 本身是保留内容的操作，不能代替 `inspect`。本地工作台在存在错误时禁用直接导出。
- Gregorian、Julian 使用前推历；Hebrew 使用固定历算法，常年 ADR 在计算时依标准建议解释为 ADS，原文不改。结果表示历日的 Julian day，不推断日落时刻或地理时区。
- 法革历 1–14 年采用历史闰年 3、7、11；更晚年份没有自行选定一种推演规则，保留合法载荷并报告计算未评估。扩展历法同样不会被套成 Gregorian。
- 标准整数和年份的词法检查不受 Int32 限制；日期运算 API 的年份资源范围为 1–9,999,999。范围外仍可读写并通过词法检查，单独提示无法计算，不误报为格式非法。
- 未知扩展结构、扩展枚举/历法的含义保留并提示未评估；已知 relocated-standard 继续套用它的标准载荷和子结构约束。标准记录不能 relocated，也不能用 relocated 标签替代原本已允许的标准标签。
- 语言标签检查 BCP 47 的良构语法及重复变体/扩展，媒体类型检查标准语法；不会联网核准 IANA 的每项登记、外部文件实际内容、URL 可达性、史料真实性或自然语言翻译是否准确。
- HTML 注释提供标准要求的纯文本转换函数；不执行 HTML。非核心命名实体及非文本 NOTE MIME 会产生诊断；不会在保存时偷偷改写备注。
- 数据质量建议单列 warning，例如祖先环、明显出生/死亡顺序冲突、从人物侧单向声明的关系、重复 CHIL 等；规范的必须项产生 error。家庭角色不用于推断性别或生物亲缘。

这里的完整范围是 GEDCOM 7.0 数据集的标准文本结构、全部标准载荷类别和上述可机械检查的规则。GEDZIP 媒体归档属于标准第 4 章，本版本不交付；也不交付旧版转换或联网扩展认证。有限测试并非穷尽所有字符串的证明，也没有声称获得第三方符合性认证。

## 给复审的可操作案例

1. 把 `INDI.SEX` 改为 `MALE`，报告 `payload-type`；把 `INDI` 下放一个 `HUSB`，报告 `structure-context`；给同一个 INDI 两个 SEX，报告 `structure-cardinality`。
2. `HEBREW 30 CSH 5783` 合法、5784 年对应 30 日非法；`FRENCH_R 6 COMP 3` 合法、2 年非法；`CHAN.DATE 1900` 不满足 DateExact，即使相同载荷在 BIRT.DATE 中合法。
3. FAM.CHIL 指向人物但人物没有 FAMC，报告 `required-reciprocal-link`；补齐后该错误消失。来源与共享备注互相引用则报告 `source-reference-cycle`，清理循环后恢复。
4. NOTE 原文 LANG en，TRAN 仍 LANG en 且媒体不变，报告 `translation-distinct`；改成 fr 或不同的文本媒体类型即符合格式差异要求。未知扩展仍保留，不冒充已验证其外部语义。
