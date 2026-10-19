# Mooncakes 发布与独立安装验证

## 0.2.0 — 2026-10-19

`moon publish --frozen` 返回 `200 OK`。软件包：[forey217/moonged@0.2.0](https://mooncakes.io/docs/forey217/moonged@0.2.0)。

独立消费项目在只关联 bin/lib 的全新工具链目录安装，没有 credentials.json、moon.work 或源码路径覆盖；`moon whoami` 为 `Not logged in`。`moon add forey217/moonged@0.2.0`、依赖树、JS deny-warn 检查均通过。注册表下载的 69 个文件（含标准数据 LICENSE/NOTICE）与发布压缩包逐字节一致。

三个外部 API 测试分别覆盖：错误枚举与必需家庭反向引用；希伯来历/法革历的实际换算及中文 HTML 纯文本投影；未知扩展内容的保留及 BOM/CRLF 往返。JS、Wasm GC 均为 `Total tests: 3, passed: 3, failed: 0`。

原始验证记录随本次桌面材料交付，源码验证逻辑使用实际发布包和 `.mooncakes` 下载文件逐字节比较。该记录说明软件包可安装及调用，不表示评审已经通过或生产采用。

## 0.1.1 — 2026-10-16

`moon publish --frozen` 返回 `200 OK`。软件包：https://mooncakes.io/docs/forey217/moonged@0.1.1 。

全新独立模块执行 `moon add forey217/moonged@0.1.1`；工具链目录只关联编译器和标准库，不含登录凭据，`moon whoami` 返回 `Not logged in`。没有 moon.work、路径覆盖或预下载依赖。注册表下载的 49 个文件与发布压缩包逐字节一致。

`moon check --target js --deny-warn` 通过，三个外部调用测试在 JS、WasmGC 均通过：共享备注与提交者记录及配偶年龄；扩展文字保留且真实标准指针错误仍报告；BOM/CRLF 与显著空白经公开 API 读写不变。

本次验证数据为合成文本，不代表生产采用；完整读写范围见 [text-conformance.md](text-conformance.md)。工具链 moon 0.1.20261012、moonc 0.10.15+943464bfa。

## 0.1.0 历史记录

2026 年 10 月 14 日，`forey217/moonged@0.1.0` 发布成功，注册表响应 `200 OK`。

软件包页面：https://mooncakes.io/docs/forey217/moonged@0.1.0

验证使用一个全新的独立模块与单独的工具链目录，只关联编译器和标准库，没有复制登录凭据；`moon whoami` 返回 `Not logged in`。验证目录没有 `moon.work`、源码路径覆盖或预先下载的依赖。

执行 `moon add forey217/moonged@0.1.0` 后，依赖树显示来自注册表的同版本模块。下载的 41 个文件与发布压缩包逐字节一致。

随后执行：

```sh
moon check --target js --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
```

检查通过，两个外部调用测试在 JS 与 WasmGC 上均为 `2 passed, 0 failed`。测试实际通过公开 API 读取家庭关系、取得父母姓名、读写保留原数据语义，并验证返回的数组不能改写 Document 内部容器。示例源码见 `examples/consumer`。

验证工具链：moon `0.1.20261012`、moonc `v0.10.15+943464bfa`。这是独立安装与合成数据接入验证，不等于生产采用记录。
