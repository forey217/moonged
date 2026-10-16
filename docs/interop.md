# 独立工具核对

2026-10-16 本地验证：36 份本项目自建的合成文件，输入节点语义、规范化后节点语义与独立解析器一致；采用官方 GEDCOM 7 schema 的参考工具对这些输入和导出文件报错为 0。保留原始警告，不等于零警告或完整标准认证。样例不含真实人员信息。

参考解析器：gedcom7code/js-gedcom，MIT/Unlicense，固定提交 `9296068bd6a461cdd93f9edc74d8457995897afe`。参考 schema：FamilySearch/GEDCOM-registries，固定提交 `05519e8aa4162843e737dd761df3a2aae7ea0860`。CI 单独下载固定版本，不将外部实现混入 MoonBit 核心。

对拍包括：原有 33 份样例，以及 `examples/conformance` 中 all-records、names-events、extensions 三份复杂文档，覆盖七类标准记录、史料与媒体元数据、多姓名/翻译、不同日历、婚姻事件配偶年龄与扩展子树。查看 `scripts/verify-interop.mjs`、[完整范围与逐项约定](text-conformance.md)及 CI 上传的原始 JSON 报告；报告同时给出输入、输出 SHA-256。

参考解析器有已观察到的边界：它把行值开头的多个空格归入分隔符并报警；GEDCOM 7 §1.3 要求单个分隔符后的空格保留为行值。`whitespace.ged` 因而另外通过单元测试与 CLI 对照显式 `whitespace.expected.ged` 逐字验证，没有把它算作独立工具对拍成功。参考 schema 工具对 FilePath、TagDef 及未注册扩展存在不理解、歧义或未注册的提示；这些警告完整写入 JSON，不宣称它已验证这些扩展的自定义语义。

这些结果不证明完整 GEDCOM 7 一致性，也不证明兼容所有家谱软件。MoonGED 的语义审查是明确列出的检查子集，未实现的标准结构仍保留在读写模型中。

复现：

```sh
node scripts/build-engine.mjs
node scripts/verify-interop.mjs --parser PATH_TO_JS_GEDCOM --schema PATH_TO_G7VALIDATION_JSON
```
