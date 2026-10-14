# Mooncakes 发布与独立安装验证

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
