#!/bin/bash

# 设置常量
ARCH=$(uname -m)
SING_BOX_VERSION="v1.0.0"  # 请根据最新版本更新
DEB_URL_BASE="https://github.com/SagerNet/sing-box/releases/download"
DEB_FILE=""
CONFIG_DIR="/etc/sing-box"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
SING_BOX_SERVICE="sing-box.service"
SCRIPT_PATH="/usr/local/bin/singbox.sh"

# 订阅转换基础URL
CONVERT_BASE_URL="https://singbox.woaiboluo.monster/config/"
CONVERT_FILE_PARAM="&file=https:/github.com/Toperlock/sing-box-subscribe/raw/main/config_template/config_template_groups_rule_set_tun_fakeip.json"

# 检查是否创建了快捷命令
if [ "$0" != "$SCRIPT_PATH" ]; then
  # 创建脚本文件并添加内容
  echo "创建快捷命令 'singbox'..."
  sudo tee "$SCRIPT_PATH" > /dev/null << 'EOF'
#!/bin/bash
exec /usr/local/bin/singbox.sh
EOF

  sudo chmod +x "$SCRIPT_PATH"

  # 创建符号链接
  sudo ln -sf "$SCRIPT_PATH" /usr/local/bin/singbox
  echo "快捷命令 'singbox' 已创建。"
fi

# 检查 sing-box 服务是否存在
if systemctl list-units --full -all | grep -q "$SING_BOX_SERVICE"; then
  echo "检测到 sing-box 服务已存在。请选择操作："
  echo "1. 重启"
  echo "2. 停止"
  echo "3. 启动"
  echo "4. 删除"
  read -p "请输入选项 (1/2/3/4): " CHOICE

  case "$CHOICE" in
    1)
      echo "正在重启 sing-box 服务..."
      sudo systemctl restart $SING_BOX_SERVICE
      ;;
    2)
      echo "正在停止 sing-box 服务..."
      sudo systemctl stop $SING_BOX_SERVICE
      ;;
    3)
      echo "正在启动 sing-box 服务..."
      sudo systemctl start $SING_BOX_SERVICE
      ;;
    4)
      echo "正在删除 sing-box 服务及相关文件..."
      sudo systemctl stop $SING_BOX_SERVICE
      sudo systemctl disable $SING_BOX_SERVICE
      sudo rm -f $SERVICE_FILE
      sudo rm -rf $CONFIG_DIR
      sudo rm -rf /var/lib/sing-box
      sudo rm -f /usr/bin/sing-box
      sudo systemctl daemon-reload
      echo "sing-box 服务已删除。"
      ;;
    *)
      echo "无效选项。"
      exit 1
      ;;
  esac
  exit 0
fi

# 判断系统架构并设置对应的 DEB 文件名称
if [[ "$ARCH" == "aarch64" ]]; then
  DEB_FILE="sing-box_${SING_BOX_VERSION}_linux_arm64.deb"
elif [[ "$ARCH" == "x86_64" ]]; then
  DEB_FILE="sing-box_${SING_BOX_VERSION}_linux_amd64.deb"
else
  echo "不支持的架构: $ARCH"
  exit 1
fi

# 下载并安装 sing-box
DEB_URL="$DEB_URL_BASE/$SING_BOX_VERSION/$DEB_FILE"
echo "下载 $DEB_URL..."
wget -O /tmp/$DEB_FILE $DEB_URL
if [[ $? -ne 0 ]]; then
  echo "下载失败，检查 URL 或网络连接。"
  exit 1
fi

echo "安装 sing-box..."
sudo dpkg -i /tmp/$DEB_FILE
if [[ $? -ne 0 ]]; then
  echo "安装失败。请检查 dpkg 输出以了解更多信息。"
  exit 1
fi

# 创建配置目录及基本配置文件
echo "创建配置目录 $CONFIG_DIR 和基本配置文件..."
sudo mkdir -p $CONFIG_DIR
echo "{}" | sudo tee $CONFIG_FILE

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
sudo chmod 777 "$CONFIG_FILE"

# 获取本机IP地址
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 将配置文件中的127.0.0.1替换为本机IP地址
sudo sed -i "s/\"external_controller\": \"127.0.0.1:9090\"/\"external_controller\": \"$LOCAL_IP:9090\"/g" "$CONFIG_FILE"

# 配置 systemd 服务文件
echo "配置 sing-box systemd 服务文件..."
sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

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
EOF

# 刷新 systemd 服务配置
echo "刷新 systemd 服务配置..."
sudo systemctl daemon-reload

# 启用和启动 sing-box 服务
echo "启用和启动 sing-box 服务..."
sudo systemctl enable sing-box.service --now

# 提示用户可以使用以下命令管理服务
echo "使用以下命令管理 sing-box 服务:"
echo "启动: sudo systemctl start sing-box.service"
echo "停止: sudo systemctl stop sing-box.service"
echo "重启: sudo systemctl restart sing-box.service"
echo "禁用: sudo systemctl disable sing-box.service"
echo "启用: sudo systemctl enable sing-box.service"
