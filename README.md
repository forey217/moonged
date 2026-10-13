# MoonGED

[English](README_EN.md) · [标准与边界](docs/interop.md) · [选题调查](docs/ecosystem-review.md)

MoonBit 原生 GEDCOM 7 数据交换、家庭关系查询和审查工具库。输入家谱软件导出的 UTF-8 `.ged` 文件，读取人物、家庭、事件和史料引用，检查断链，再导出或供其他 MoonBit 项目查询。

核心以 MoonBit 实现，只依赖标准库。JavaScript 只负责本地文件、界面和进程适配。所有演示文件均为虚构人物，没有上传家谱或访问账户的功能。

## 已有能力

- 受限文本解析及增量 UTF-8 字节解析。支持跨字节分块、BOM、LF/CRLF/CR；保留 Unicode、显著空白、CONT 多行备注、扩展结构及空引用。
- 规范化 GEDCOM 写出。记录和同类字段顺序保留，BOM/换行规范化，不承诺字节级不变。
- 选定规则审查：HEAD/GEDC/TRLR、重复标识、悬空/类型错误引用、部分单例字段、扩展声明，以及双向链接缺失、关系环路等质量提示。
- 人物、家庭、事件视图；有界祖先/后代遍历及最短家庭路径。PEDI 收养等限定按原记录保留，不据此推断生物亲缘。
- Gregorian/Julian 日期、部分日期与 BCE，保守比较日期范围；ABT/EST 不产生假定的确定生日。其他日历原文保留并提示不做计算。
- 整条记录的引用闭包提取及标识重映射。闭包可能包含整个相连家族，提供记录上限，不用于隐私过滤。
- Node CLI、中文本地工作台和独立 MoonBit 模块接入样例。

## 从源码运行

需要 MoonBit 稳定工具链及 Node.js 24。首次运行：

```sh
moon test --target js --deny-warn
moon build --target js --release cmd/engine
node scripts/moonged.mjs inspect examples/family.ged
node scripts/moonged.mjs path examples/family.ged I5 I1
node scripts/moonged.mjs normalize examples/family.ged --save exported.ged
node scripts/moonged.mjs csv examples/family.ged --save people.csv
node scripts/serve.mjs
```

浏览器打开 `http://127.0.0.1:4273/`。页面先显示合成家谱，可选择自己的 `.ged` 文件在本地处理；文件不会上传。网页限制 8 MiB，展示前 20 个家庭和前 500 个可查询人物。

CLI 还提供 `people`、`ancestors`、`descendants`、`nodes`；`--help` 显示参数。标识不带两端的 `@`。退出码：0 成功、1 语法/I/O 失败、2 用法错误或 inspect 审查错误。规范化是读写操作，不是全面 schema 验证。

`--save` 先完成计算，再以同目录临时文件和硬链接发布 UTF-8 结果，拒绝覆盖已存在文件。目录需存在，文件系统需支持硬链接。CSV 使用 RFC 4180 引号并默认对常见表格公式开头加单引号；需要原始数据时调用 `people_csv(..., spreadsheet_safe=false)`。

## 在 MoonBit 项目中接入

模块名称：`forey217/moonged`，版本 `0.1.0`。仓库中的 `examples/consumer` 是另一个独立模块，通过 `moon.work` 使用源码依赖；包的注册表发布及安装验证状态见发布记录。

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

1. 导入/再导出：中文和多行备注经 CLI/网页规范化，33 份合成文件与独立解析器比较输入和输出节点，并接受官方 schema 的参考工具检查。
2. 档案/CI：错误样例报告第 6 行悬空引用与第 7 行重复标识，inspect 返回 2；网页禁用错误文件的直接导出。
3. SDK 接入：独立模块调用公开 API；关系样例跨两代保留 ADOPTED 限定，并可重命名标识或提取完整引用记录。

本地已通过 35 个核心测试、2 个独立模块测试及 4 个 CLI 进程测试。JS/Wasm GC 本地运行；原生后端由远程 CI 验证，结果以实际 Actions 记录为准。独立对拍的固定版本、原始报告和已发现的参考工具边界见 [interop.md](docs/interop.md)。不以测试数量代替完整标准一致性或生产采用证据。

## 明确的范围

目标为 FamilySearch GEDCOM 7.0 UTF-8 文本。语法模型保留通用结构；语义检查是公开列出的子集，未实现全部结构位置、基数、枚举、日历和数据类型规则。文件可缺少末尾换行，输出补上标准换行。

不支持 GEDZIP、GEDCOM 5 转换、ANSEL、远程媒体、家谱网站登录或记录真实性认证。不读取私人账户，不合并同名人物，不自动确认生物亲缘。日期范围提示、最短关系路径和审查通过都不等于史料事实已被证明。暂未取得生产使用反馈。

默认资源政策：100,000 个结构、128 层、单行 1,048,576 UTF-16 单位、文档 16,777,216 单位；Limits 可以显式调整。文本流按 Unicode 字符边界分块，任意字节流应使用 ByteParser。未完成物理行有缓冲，解析后的完整 Document 仍保留在内存中，不宣称常量内存处理整份家谱。

## 许可证与开发说明

原创实现，MIT。依据 [FamilySearch GEDCOM 7](https://gedcom.io/specifications/FamilySearchGEDCOMv7.html)，外部标准及参考工具保留各自许可，见 `THIRD_PARTY_NOTICES.md`。

项目使用 AI 辅助开发，参赛者需要理解功能、边界和技术选择。生态调查仅证明在所查索引和搜索范围中没有检出同类 MoonBit GEDCOM 工具，不保证唯一或审核通过。MoonConfig 历史仓库没有被覆盖或更名。
