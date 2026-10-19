# MoonGED

[English](README_EN.md) · [标准语义符合性与案例](docs/semantic-conformance.md) · [完整文档读写](docs/text-conformance.md) · [独立核对](docs/interop.md)

MoonBit 原生 GEDCOM 7 数据交换、家庭关系查询和审查工具库。输入家谱软件导出的 UTF-8 `.ged` 文件，读取人物、家庭、事件和史料引用，检查断链，再导出或供其他 MoonBit 项目查询。

核心以 MoonBit 实现，只依赖标准库。JavaScript 只负责本地文件、界面和进程适配。所有演示文件均为虚构人物，没有上传家谱或访问账户的功能。

## 已有能力

- 带资源限额的完整文本容器解析及增量 UTF-8 字节解析，不按已实现字段筛选文档。支持跨字节分块、BOM、LF/CRLF/CR；保留 Unicode、显著空白、CONT 多行备注、扩展结构及空引用。
- 规范化 GEDCOM 写出。记录和同类字段顺序保留，默认无 BOM、LF 和末尾换行；SDK 可选择 BOM 与 LF/CRLF/CR，不承诺字节级不变。
- 完整标准结构表审查：依据官方 GEDCOM 7.0.18 发布版的 179 种结构、1,379 种父子组合及 9 种文档级位置，检查上下文、必填项、单例、载荷、全部 12 组枚举、引用目标和数据类型。另检查家庭反向链接、来源引用环、翻译继承/重复和 REFN 冲突。
- 人物、家庭、事件视图；有界祖先/后代遍历及最短家庭路径。PEDI 收养等限定按原记录保留，不据此推断生物亲缘。
- 四种标准历法、日期/日期区间/精确日期的上下文检查。Gregorian、Julian、Hebrew 及法革历历史区间可换算日界；支持 BCE、部分日期、双端不同历法，ABT/EST 不产生假定生日。法革历延伸年份、扩展历法及超大年份保留并明确提示计算边界。
- 整条记录的引用闭包提取及标识重映射。闭包可能包含整个相连家族，提供记录上限，不用于隐私过滤。
- Node CLI、中文本地工作台和独立 MoonBit 模块接入样例。

## 从源码运行

需要 MoonBit 稳定工具链及 Node.js 24。首次运行：

```sh
moon test --target js --deny-warn
node scripts/build-engine.mjs
node scripts/moonged.mjs inspect examples/family.ged
node scripts/moonged.mjs path examples/family.ged I5 I1
node scripts/moonged.mjs normalize examples/family.ged --save exported.ged
node scripts/moonged.mjs csv examples/family.ged --save people.csv
node scripts/serve.mjs
```

浏览器打开 `http://127.0.0.1:4273/`。页面先显示合成家谱，可选择自己的 `.ged` 文件在本地处理；文件不会上传。网页限制 8 MiB，展示前 20 个家庭和前 500 个可查询人物。

CLI 还提供 `people`、`ancestors`、`descendants`、`nodes`；`--help` 显示参数。标识不带两端的 `@`。退出码：0 成功、1 语法/I/O 失败、2 用法错误或 inspect 审查错误。`normalize` 保存容器内容，先运行 `inspect` 可确认标准语义诊断。

`--save` 先完成计算，再以同目录临时文件和硬链接发布 UTF-8 结果，拒绝覆盖已存在文件。目录需存在，文件系统需支持硬链接。CSV 使用 RFC 4180 引号并默认对常见表格公式开头加单引号；需要原始数据时调用 `people_csv(..., spreadsheet_safe=false)`。

## 在 MoonBit 项目中接入

模块名称：`forey217/moonged`，本次版本 `0.2.0`。发布及实际独立安装状态见 [发布记录](docs/registry-verification.md)。仓库中的 `examples/consumer` 是独立模块，本地工作区通过 `moon.work` 使用源码依赖。

```moonbit
import { "forey217/moonged" @ged }

fn parent_names(text : String, child_id : String) -> Array[String] raise {
  let doc = @ged.parse(text)
  let graph = @ged.graph(doc)
  graph.ancestors(child_id, max_depth=1)
    .map(fn(r) raise { @ged.person(doc, r.person).display_name() })
}
```

完整 API 见 `pkg.generated.mbti`。Document、Parser 和图的内部容器私有；返回的节点数组是副本。查询遇到重复标识时拒绝静默选择一个定义。人物未设标识仍可在视图中读取；查询使用已有标识，未设标识的家庭也可以贡献其明确记录的关系。

## 验证与可复用场景

1. 导入/再导出：中文和多行备注经 CLI/网页规范化，36 份合成文件与独立解析器比较输入和输出节点，并接受官方 schema 的参考工具检查。
2. 档案/CI：错误样例报告第 6 行悬空引用与第 7 行重复标识，inspect 返回 2；网页禁用错误文件的直接导出。
3. SDK 接入：独立模块调用公开 API；关系样例跨两代保留 ADOPTED 限定，并可重命名标识或提取完整引用记录。

本地通过 55 个核心测试、2 个独立模块测试及 11 个 Node 测试；其中包含从官方 YAML 独立提取的 2,422 个符合性正反案例和 pyluach 2.3.0 的 1,040 个希伯来历边界向量。另保留 36 份文档与独立解析器的往返比对。JS、Wasm GC、Wasm 本地运行，native 以远程 CI 实际记录为准。详细统计、再现命令和语义边界见 [符合性说明](docs/semantic-conformance.md)。

## 明确的范围

目标为 FamilySearch GEDCOM 7.0 UTF-8 数据集，按 7.0.18 的第 1–3 章实现文本读写、完整标准结构表及数据类型检查和可机械判定的跨记录规则。未知扩展的外部定义、史料内容及语言/媒体登记有效性不做远程认证，单独报告为未评估范围。文件可缺少末尾换行，输出补上标准换行。测试通过是具体覆盖证据，不代表第三方认证或数学上的穷尽证明。

不支持 GEDZIP、GEDCOM 5 转换、ANSEL、远程媒体、家谱网站登录或记录真实性认证。不读取私人账户，不合并同名人物，不自动确认生物亲缘。日期范围提示、最短关系路径和审查通过都不等于史料事实已被证明。暂未取得生产使用反馈。

默认资源政策：100,000 个结构、128 层、单行 1,048,576 UTF-16 单位、文档 16,777,216 单位；Limits 可以显式调整。文本流按 Unicode 字符边界分块，任意字节流应使用 ByteParser。未完成物理行有缓冲，解析后的完整 Document 仍保留在内存中，不宣称常量内存处理整份家谱。

## 许可证与开发说明

原创实现，MIT。依据 [FamilySearch GEDCOM 7](https://gedcom.io/specifications/FamilySearchGEDCOMv7.html)，外部标准及参考工具保留各自许可，见 `THIRD_PARTY_NOTICES.md`。

项目使用 AI 辅助开发，参赛者需要理解功能、边界和技术选择。生态调查仅证明在所查索引和搜索范围中没有检出同类 MoonBit GEDCOM 工具，不保证唯一或审核通过。MoonConfig 历史仓库没有被覆盖或更名。
