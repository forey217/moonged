# GEDCOM 7 文本读写范围与语义保留约定

适用版本：MoonGED 0.1.1。依据 [FamilySearch GEDCOM 7.0.18](https://gedcom.io/specifications/FamilySearchGEDCOMv7.html)，数据头使用 `HEAD.GEDC.VERS 7.0`。本说明区分整份文档读写、标准规则审查及查询视图；三个层次不会相互代替。

## 最终交付范围

| 层次 | 本版本的承诺 | 未覆盖的部分 |
| --- | --- | --- |
| 文本容器，§1.1–1.3 | 在资源限额内，按层级读取整份 UTF-8 文本，保存全部节点，不按已实现的人物字段筛选；支持七类标准记录及扩展记录、任意合法标签层级、指针、空指针和 CONT | 不处理旧版 GEDCOM、ANSEL 或 GEDZIP；资源限制是本地政策，不是标准限制 |
| 文本写出，§1.1–1.5 | `serialize(Document)` 遍历完整文档，保留层级、节点/记录顺序、标识、指针目标和全部载荷；即使查询视图不认识字段，也继续写出 | 不是原始字节存档；不会自动修复语义不合法的输入 |
| 标准结构与数据类型，§2–3 | 原文保存所有结构和类型载荷。仅对公开实现的头尾、标识、引用、家庭及日期规则诊断 | 不承诺完整结构位置、基数、枚举、扩展数据类型或全部跨记录规则验证；`inspect.valid` 仅表示所选规则未报错 |
| 日期和关系计算 | Gregorian/Julian 的已列日期形式，以及记录中明确给出的家庭关系 | HEBREW、FRENCH_R 和扩展日历只保留并提示；不会改历、补日期或推断生物亲缘 |

七类标准记录为 INDI、FAM、OBJE、REPO、SNOTE、SOUR、SUBM；HEAD 和 TRLR 是文档头尾伪结构。`parse` 检查容器语法，不据其成功宣称整个文档符合全部标准。调用者应保留 Document，用完整写出 API 交换数据。

默认上限为 100,000 个结构、128 层、每物理行 1,048,576 个 UTF-16 单位、全文 16,777,216 个单位。超限明确报错，不截断后返回“成功”。Limits 可调整，节点硬上限 1,000,000、深度硬上限 1,024。容器保存在内存中，不承诺常量内存。

## 保留与规范化

| 输入信息 | 写出后的约定 |
| --- | --- |
| 记录顺序、同类多值字段顺序、层级及父子关系 | 保留，包括多个 NAME 的优先顺序、TRAN/LANG、嵌套引文、媒体元数据、未知扩展及其子树 |
| 中文、非 BMP 字符、组合字符、前导/尾随空格、制表符 | 按载荷保存；不 trim，不做 Unicode NFC/NFD、大小写或日期格式转换 |
| xref、Pointer、`@VOID@`、以 @ 开头的普通文本 | 类型与内容保留；普通文本写回时只对每个物理行开头的 @ 加倍转义；不把普通文字中的标识当作引用 |
| CONT，包括空白行和末尾空行 | 读取为载荷中的 `\n`，写出为紧接父行、位于普通子结构之前的 CONT；不成为独立数据节点 |
| BOM、物理换行、末尾换行 | 默认无 BOM、LF，并补末尾换行；SDK 可选择 `bom=true` 及 LF/CRLF/CR。初始 BOM 没有数据语义。原始混合换行和源行号不保留 |
| 外部媒体路径、URI、MIME、HTML 备注、PHRASE | 只保存文字与结构，不读取媒体、不解析 HTML、不将原始表达改写为推定结论 |

读写不变量是 `equivalent(doc, parse(serialize(doc)))`，比较全部节点的层级、父节点、顺序、标签、标识及载荷类型/值；忽略源行号。独立解析器比对另外提供不同实现的证据，不能用单个自比较代替。

推荐 UTF-8 签名与 CRLF 输出的 SDK 用法：

```moonbit
let doc = @ged.parse_bytes(input)
let output = @ged.serialize_bytes(doc, bom=true, line_ending="\r\n")
```

## 显式变换的边界

- `normalize` 只应用上述文本规范化；不经过人物、家庭或 CSV 视图重建文档。
- `remap_ids` 只改指定 xref 定义与 Pointer 载荷，保持普通文字不变；同时交换标识可以，碰撞、无效目标和未知源标识报错。输入 Document 不变。
- `extract_records` 有意删除未选中的不相连记录，保留选中整条记录并追踪所有指针的传递闭包（包括头部引用）。连接家庭、史料、共享备注或扩展引用都可能扩大闭包；超限失败，不悄悄丢记录。它不是隐私脱敏或单纯祖先导出。
- 人物/家庭/事件视图与 CSV 是查询投影，可能不含来源、媒体、翻译及扩展；不能用它们声称完整 GEDCOM 往返。查询和导出投影不会改写原 Document。

## 可直接复现的复杂输入

所有案例均为自建合成数据。输入、断言和输出预期随仓库交付。

| 案例 | 检查内容 | 证据 |
| --- | --- | --- |
| [all-records.ged](../examples/conformance/all-records.ged) | 七类标准记录、源引用与引文页码、嵌套 TEXT/CONT、共享备注、媒体路径与格式、提交者 | 原始及导出节点与独立解析器相同；参考 schema 校验无错误 |
| [names-events.ged](../examples/conformance/names-events.ged) | 多姓名优先顺序、音译、备注/地点翻译、HEBREW/FRENCH_R、DATE.TIME、MARR.HUSB/WIFE.AGE、空关联及 ROLE | 原始及导出节点独立比对；未支持日历恰有两条提示，文字不改写 |
| [extensions.ged](../examples/conformance/extensions.ged) | 声明的扩展记录/子树、扩展里的 DATE/FAMC/SOUR 等标签、自定义指针与普通 @ 文本 | 全部节点独立比对；按扩展定义保存，不套用同名标准标签的日期/指针规则 |
| [whitespace.ged](../examples/conformance/whitespace.ged) | BOM、CRLF、无末尾换行、有效前导/尾随空格、组合字符、emoji、制表符、空 CONT | CLI 输出逐字等于 [whitespace.expected.ged](../examples/conformance/whitespace.expected.ged)，并验证节点不变及写出幂等性 |

合成扩展定义：`urn:moonged:synthetic-catalog` 对应 `_CATALOG`，载荷为文本或指针；其 FAMC 是馆藏架号文本、DATE 是自由文字目录日期、NOTE.SOUR 是自由文字来源标签。`urn:moonged:synthetic-detail` 对应 `_DETAIL`，载荷为文本。这些是测试用扩展约定，未注册到公共生态；不借同名标准标签推断其语义。标准 §1.5 允许扩展定义子结构；复用标准标签在部分位置可能产生弃用提示，原始扩展内容仍保留。

参考工具的限制也保留在报告中：其行解析器会吞掉行值开头的空格，所以 whitespace 案例以标准 §1.3 和明确的 golden 文件验证，不计为独立解析器一致案例；其 schema 检查器对 FilePath、TagDef 及未知扩展存在“不理解/未注册”的提示，因此“零错误”不是这些语义已被全面验证或零警告的证明。

## 验证与修复记录

0.1.1 新增七个核心测试。四个回归测试在修复前均失败；修复后按父结构位置区分记录/引用与家庭事件年龄，并在扩展子树内停止套用标准标签的指针/日期规则。真实标准指针错误仍会报告。

本地工作区共 46 个 MoonBit 测试（44 核心、2 消费模块）和 9 个 Node 测试；36 份输入的全部节点及导出节点与固定独立解析器一致，其中 3 份为上述复杂文档。whitespace 是额外的规范 golden 案例。后端及远程 CI 结果以实际执行记录为准。这些证据不构成对所有合法文件的穷尽证明或第三方认证。

```sh
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
node scripts/build-engine.mjs
node --test tests/*.test.mjs
node scripts/verify-interop.mjs --parser PATH_TO_JS_GEDCOM --schema PATH_TO_G7VALIDATION_JSON --report _build/interop.json
```

固定参考版本与警告见 [interop.md](interop.md)。
