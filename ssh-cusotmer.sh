#!/bin/bash

# SSH 安全配置脚本
# 功能：
# 1. 修改 SSH 端口
# 2. 禁用密码登录，仅允许密钥登录
# 3. 允许 root 登录（密钥）
# 4. 指定允许登录的用户
# 5. 自动备份、语法检查、重启 SSH
# 6. 检查 root 是否被锁定，自动解锁

set -e

# ================= 用户输入 =================
NEW_PORT="$1"                  # 新的 SSH 端口号
ALLOWED_USERS="${2:-}"         # 允许登录的用户（可选）
# ============================================

# 0. 必须是 root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m错误：必须使用 root 权限运行\033[0m"
    exit 1
fi

# 1. 参数验证
if [ -z "$NEW_PORT" ] || ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1024 ] || [ "$NEW_PORT" -gt 65535 ]; then
    echo -e "\033[31m错误：请提供一个 1024-65535 的合法端口号\033[0m"
    echo "用法：sudo bash $0 <端口号> [允许用户列表]"
    echo "示例：sudo bash $0 2222 \"admin,deploy\""
    exit 1
fi

# 2. 检查 root SSH 密钥
echo -e "\033[34m检查 root 用户 SSH 密钥...\033[0m"
if [ ! -s "/root/.ssh/authorized_keys" ]; then
    echo -e "\033[33m警告：/root/.ssh/authorized_keys 不存在或为空\033[0m"
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\033[31m已取消操作。\033[0m"
        exit 1
    fi
else
    echo -e "\033[32m√ root 密钥已配置\033[0m"
fi

# 3. 配置路径
CONFIG_FILE="/etc/ssh/sshd_config.d/99-ssh-security.conf"
BACKUP_DIR="/etc/ssh/sshd_config.bak"
mkdir -p "$BACKUP_DIR"

# 4. 备份配置
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$BACKUP_DIR/sshd_$(date +%Y%m%d%H%M%S).bak"
else
    [ -f /etc/ssh/sshd_config ] && cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_$(date +%Y%m%d%H%M%S).bak"
fi

# 5. 写入新配置
mkdir -p "$(dirname "$CONFIG_FILE")"
cat > "$CONFIG_FILE" << EOF
# 生成时间：$(date)

Port $NEW_PORT
AddressFamily inet
Protocol 2

PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no

$([ -n "$ALLOWED_USERS" ] && echo "AllowUsers ${ALLOWED_USERS//,/ }")

ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 5

HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-ed25519
KexAlgorithms curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF

# 6. 检查语法
echo -e "\033[34m验证 SSH 配置语法...\033[0m"
if ! sshd -t -f "$CONFIG_FILE"; then
    echo -e "\033[31m错误：SSH 配置无效，请检查语法。\033[0m"
    exit 1
fi

# 7. 检查 root 是否被锁
ROOT_LOCKED=$(passwd -S root | awk '{print $2}')
if [ "$ROOT_LOCKED" = "L" ]; then
    echo -e "\033[33m警告：root 账户已锁定，尝试解锁...\033[0m"
    if passwd -u root; then
        echo -e "\033[32m√ root 账户已解锁\033[0m"
    else
        echo -e "\033[31m× 解锁失败，请手动检查 root 状态\033[0m"
    fi
else
    echo -e "\033[32m√ root 未锁定\033[0m"
fi

# 8. 重启 SSH 服务（兼容 sshd/ssh）
echo -e "\033[34m正在重启 SSH 服务...\033[0m"
if systemctl list-units --type=service | grep -q "sshd.service"; then
    systemctl restart sshd
else
    systemctl restart ssh
fi

echo -e "\033[32m√ SSH 配置已生效，服务已重启！\033[0m"

# 9. 提示后续操作
cat << EOF

\033[33m=== 后续操作建议 ===\033[0m

1. 测试登录新端口（新会话）：
   ssh -p $NEW_PORT root@<服务器IP>

2. 建议修改防火墙规则：
   ufw allow $NEW_PORT/tcp
   ufw deny 22/tcp

3. 权限要求：
   - ~/.ssh/authorized_keys 文件必须存在，权限为 600
   - ~/.ssh 目录权限为 700

4. 如无法登录，可使用控制台修复。

EOF
