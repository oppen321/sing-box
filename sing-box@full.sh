#!/bin/bash

# 定义常量
BASE_URL="https://go.dev/dl"
GO_VERSION="1.21.5"
DEST_DIR="/tmp"
INSTALL_DIR="/usr/local"
ARCH=$(uname -m)
GO_ARCH="amd64"
SING_BOX_REPO="https://github.com/SagerNet/sing-box.git"
SING_BOX_DIR="/opt/sing-box"
BIN_DIR="/usr/bin"
CONFIG_DIR="/etc/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"

# 订阅转换基础URL
CONVERT_BASE_URL="https://singbox.woaiboluo.monster/config/"
CONVERT_FILE_PARAM="&file=https:/github.com/Toperlock/sing-box-subscribe/raw/main/config_template/config_template_groups_rule_set_tun_fakeip.json"

# 判断系统架构
if [[ "$ARCH" == "aarch64" ]]; then
  GO_ARCH="arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
  GO_ARCH="amd64"
else
  echo "不支持的架构: $ARCH"
  exit 1
fi

# 安装 Go
echo "安装 Go 版本 $GO_VERSION ($GO_ARCH)..."
wget -P $DEST_DIR "$BASE_URL/go$GO_VERSION.linux-$GO_ARCH.tar.gz"
tar -zxf "$DEST_DIR/go$GO_VERSION.linux-$GO_ARCH.tar.gz" -C $INSTALL_DIR

# 配置环境变量
echo "配置环境变量..."
echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc

# 验证 Go 安装
echo "验证 Go 版本..."
go version

# 克隆 sing-box 源码
echo "克隆 sing-box 源码到 $SING_BOX_DIR..."
git clone $SING_BOX_REPO $SING_BOX_DIR

# 构建 sing-box
echo "构建 sing-box..."
cd $SING_BOX_DIR
go build -tags "with_quic with_dhcp with_wireguard with_ech with_utls with_reality_server with_acme with_clash_api with_gvisor with_grpc with_v2ray_api" ./cmd/sing-box
mv ./sing-box $BIN_DIR

# 验证 sing-box 安装
echo "验证 sing-box 版本..."
sing-box version

# 创建配置目录及基本配置文件
echo "创建配置目录 $CONFIG_DIR 和基本配置文件..."
mkdir -p $CONFIG_DIR
echo "{}" > $CONFIG_FILE

# 提示用户输入订阅链接
read -p "请输入你的订阅链接: " SUBSCRIPTION_URL

# 生成完整的转换链接
FULL_CONVERT_URL="${CONVERT_BASE_URL}${SUBSCRIPTION_URL}${CONVERT_FILE_PARAM}"

# 导入订阅链接并转换为 sing-box 格式的 JSON 文件
echo "正在导入并转换订阅链接..."
curl -sL "$FULL_CONVERT_URL" -o "$CONFIG_FILE"

if [ $? -eq 0 ]; then
  echo "订阅链接已成功转换并保存到 $CONFIG_FILE"
else
  echo "订阅链接转换失败，请检查链接或转换服务。"
  exit 1
fi

# 为配置文件赋予权限
chmod 777 "$CONFIG_FILE"

# 获取本机 IP 地址
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 将配置文件中的 "external_controller": "192.168.100.244:9090" 替换为本机 IP 地址
sed -i "s/\"external_controller\": \"192.168.100.244:9090\"/\"external_controller\": \"$LOCAL_IP:9090\"/g" "$CONFIG_FILE"

# 启用 IP 转发
echo "启用 IP 转发..."
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 配置 systemd 服务文件
echo "配置 sing-box systemd 服务文件..."
cat <<EOF> $SERVICE_FILE
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=$BIN_DIR/sing-box -D /var/lib/sing-box -C $CONFIG_DIR run
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# 刷新 systemd 服务配置
echo "刷新 systemd 服务配置..."
systemctl daemon-reload

# 启用和启动 sing-box 服务
echo "启用和启动 sing-box 服务..."
systemctl enable sing-box.service --now

# 显示完成信息
echo "Go 和 sing-box 安装及配置已完成。"

# 提示是否启动服务
read -p "是否现在启动 sing-box 服务？(y/n): " START_NOW
if [ "$START_NOW" == "y" ]; then
  systemctl start sing-box.service
  echo "sing-box 服务已启动。"
else
  echo "sing-box 服务已启用，但尚未启动。"
fi

# 提示用户可以使用以下命令管理服务
echo "使用以下命令管理 sing-box 服务:"
echo "启动: sudo systemctl start sing-box.service"
echo "停止: sudo systemctl stop sing-box.service"
echo "重启: sudo systemctl restart sing-box.service"
echo "禁用: sudo systemctl disable sing-box.service"
echo "启用: sudo systemctl enable sing-box.service"
