#!/bin/bash

# 1. 提示用户输入目标子网
read -p "请输入目标子网（默认: 192.168.4.0/24）: " INPUT_SUBNET
TARGET_SUBNET=${INPUT_SUBNET:-192.168.4.0/24}
PRIORITY=5200

echo "将使用子网: $TARGET_SUBNET 和优先级: $PRIORITY"

# 2. 写入检测脚本
cat <<EOF | sudo tee /usr/local/bin/check_add_iprule.sh > /dev/null
#!/bin/bash

TARGET_SUBNET="$TARGET_SUBNET"
PRIORITY="$PRIORITY"

rule_exists=\$(ip rule show | grep -w "\$TARGET_SUBNET" | grep -w "priority \$PRIORITY")

if [ -n "\$rule_exists" ]; then
    echo "规则已存在：\$rule_exists"
    exit 0
fi

has_target_ip=\$(ip addr | grep -Eo "\${TARGET_SUBNET%.*}\.[0-9]{1,3}")

if [ -n "\$has_target_ip" ]; then
    echo "检测到本地地址为 \$has_target_ip，添加 ip rule..."
    ip rule add to \$TARGET_SUBNET table main priority \$PRIORITY
    if [ \$? -eq 0 ]; then
        echo "规则添加成功 ✅"
    else
        echo "规则添加失败 ❌"
    fi
else
    echo "未检测到本地 \$TARGET_SUBNET 地址，不添加规则。"
fi
EOF

# 3. 添加执行权限
sudo chmod +x /usr/local/bin/check_add_iprule.sh

# 4. 写入 systemd 服务文件
cat <<EOF | sudo tee /etc/systemd/system/check_add_iprule.service > /dev/null
[Unit]
Description=Check and Add IP Rule for $TARGET_SUBNET
After=network.target

[Service]
ExecStart=/usr/local/bin/check_add_iprule.sh
Type=simple
Restart=on-failure
User=root
Environment=PATH=/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

# 5. 启用并启动 systemd 服务
sudo systemctl daemon-reload
sudo systemctl enable check_add_iprule.service
sudo systemctl start check_add_iprule.service

# 6. 状态检查
echo "服务已启动，状态如下："
sudo systemctl status check_add_iprule.service --no-pager
