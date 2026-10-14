# 独立工具核对

2026-10-13 本地验证：33 份本项目自建的合成文件，输入节点语义、规范化后节点语义与独立解析器一致；独立 GEDCOM 7 schema 验证器对这些导出文件报错为 0。样例不含真实人员信息。

参考解析器：gedcom7code/js-gedcom，MIT/Unlicense，固定提交 `9296068bd6a461cdd93f9edc74d8457995897afe`。参考 schema：FamilySearch/GEDCOM-registries，固定提交 `05519e8aa4162843e737dd761df3a2aae7ea0860`。CI 单独下载固定版本，不将外部实现混入 MoonBit 核心。

对拍包括：中文、非 BMP 字符、转义 @、空白续行、LF/CRLF/CR、人物与家庭指针、收养关系和不完整日期。查看 `scripts/verify-interop.mjs` 与 CI 上传的原始 JSON 报告。

参考解析器有已观察到的边界：它把行值开头的多个空格归入分隔符并报警；GEDCOM 7 §1.3 要求单个分隔符后的空格保留为行值。该情况按规范进行本项目单元测试，没有把它算作独立工具对拍成功。

这些结果不证明完整 GEDCOM 7 一致性，也不证明兼容所有家谱软件。MoonGED 的语义审查是明确列出的检查子集，未实现的标准结构仍保留在读写模型中。

复现：

```sh
node scripts/build-engine.mjs
node scripts/verify-interop.mjs --parser PATH_TO_JS_GEDCOM --schema PATH_TO_G7VALIDATION_JSON
```
