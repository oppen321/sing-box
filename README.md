# sing-box.sh

`sing-box.sh` 是一个自动化脚本，用于配置 Sing-Box 旁路网关。只需提供您的订阅链接，即可轻松设置并访问 Sing-Box 面板。面板可通过 IP 地址加端口 9090 在局域网中访问。

## 功能

- 自动配置 Sing-Box 旁路网关
- 只需输入订阅链接即可完成配置
- 支持局域网访问面板（默认端口 9090）

## 一键安装

要快速安装和配置 Sing-Box，请运行以下命令：

```bash
bash -c "$(curl --insecure -fsSL https://raw.githubusercontent.com/oppen321/sing-box/main/sing-box.sh)"