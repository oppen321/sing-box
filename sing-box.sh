#!/bin/bash

# 定义下载URL前缀和目标目录
BASE_URL="https://github.com/SagerNet/sing-box/releases/latest/download"
DEST_DIR="/tmp/sing-box"
BIN_DIR="/usr/bin"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
CONFIG_DIR="/etc/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"

# 定义订阅转换基础URL
CONVERT_BASE_URL="https://singbox.woaiboluo.monster/config/"
CONVERT_FILE_PARAM="&file=https:/github.com/Toperlock/sing-box-subscribe/raw/main/config_template/config_template_groups_rule_set_tun_fakeip.json"

# 检测设备架构
ARCH=$(uname -m)

# 根据架构选择下载文件
case $ARCH in
  x86_64)
    FILE="sing-box-linux-amd64.zip"
    ;;
  aarch64)
    FILE="sing-box-linux-arm64.zip"
    ;;
  armv7l)
    FILE="sing-box-linux-armv7.zip"
    ;;
  *)
    echo "不支持的架构: $ARCH"
    exit 1
    ;;
esac

# 下载sing-box二进制文件
echo "正在下载 $FILE..."
mkdir -p "$DEST_DIR"
curl -L -o "$DEST_DIR/$FILE" "$BASE_URL/$FILE"

# 使用unzip解压文件
echo "正在解压文件..."
unzip "$DEST_DIR/$FILE" -d "$DEST_DIR"

# 将解压后的二进制文件移动到/usr/bin目录
echo "正在移动二进制文件到 $BIN_DIR..."
mv "$DEST_DIR/sing-box" "$BIN_DIR/sing-box"

# 为二进制文件添加可执行权限
chmod +x "$BIN_DIR/sing-box"

# 确保配置目录存在
if [ ! -d "$CONFIG_DIR" ]; then
  echo "创建配置目录: $CONFIG_DIR"
  mkdir -p "$CONFIG_DIR"
fi

# 提示用户输入订阅链接
read -p "请输入你的订阅链接: " SUBSCRIPTION_URL

# 生成完整的转换链接
FULL_CONVERT_URL="${CONVERT_BASE_URL}${SUBSCRIPTION_URL}${CONVERT_FILE_PARAM}"

# 导入订阅链接并转换为sing-box格式的JSON文件
echo "正在导入并转换订阅链接..."
curl -sL "$FULL_CONVERT_URL" -o "$CONFIG_FILE"

if [ $? -eq 0 ]; then
  echo "订阅链接已成功转换并保存到 $CONFIG_FILE"
else
  echo "订阅链接转换失败，请检查链接或转换服务。"
  exit 1
fi

# 获取本机IP地址
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 将配置文件中的127.0.0.1替换为本机IP地址
sed -i "s/127.0.0.1/$LOCAL_IP/g" "$CONFIG_FILE"

# 启用IP转发
echo "启用IP转发..."
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 创建或更新systemd服务文件
echo "创建或更新sing-box服务文件..."
cat <<EOL > $SERVICE_FILE
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target network-online.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOL

# 重新加载systemd服务并启用sing-box
echo "重新加载systemd服务并启用sing-box..."
systemctl daemon-reload
systemctl enable sing-box.service
systemctl start sing-box.service

# 显示完成信息
echo "sing-box安装、配置及订阅导入已完成，服务已启动。"
