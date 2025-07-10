#!/bin/bash

# SSH 安全配置脚本（精简备份版本）
# 功能：
# 1. 修改端口 + 强化密钥登录
# 2. 禁用密码登录，允许 root 使用密钥
# 3. 指定允许用户登录
# 4. 自动解锁 root（如被锁）
# 5. 创建全新配置文件，不保留旧 d 目录配置
# 6. 重启 SSH 服务（自动识别 ssh/sshd）

set -e

# ============ 用户参数 ============
NEW_PORT="$1"                  # 必填：新的 SSH 端口号
ALLOWED_USERS="${2:-}"         # 可选：允许登录的用户（逗号分隔）
# ==================================

# 0. 必须是 root 执行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m错误：请使用 root 用户运行本脚本。\033[0m"
    exit 1
fi

# 1. 参数检查
if [ -z "$NEW_PORT" ] || ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1024 ] || [ "$NEW_PORT" -gt 65535 ]; then
    echo -e "\033[31m错误：请指定合法的端口号 (1024-65535)\033[0m"
    echo "用法：sudo bash $0 <端口号> [允许用户列表]"
    echo "示例：sudo bash $0 2222 \"admin,deploy\""
    exit 1
fi

# 2. 检查 root 是否配置 SSH 密钥
echo -e "\033[34m正在检查 root 的密钥配置...\033[0m"
if [ ! -s "/root/.ssh/authorized_keys" ]; then
    echo -e "\033[33m警告：/root/.ssh/authorized_keys 不存在或为空！\033[0m"
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && echo -e "\033[31m已取消\033[0m" && exit 1
else
    echo -e "\033[32m√ 已配置密钥\033[0m"
fi

# 3. 路径配置
CONFIG_FILE="/etc/ssh/sshd_config.d/99-ssh-security.conf"
BACKUP_DIR="/etc/ssh/sshd_config.bak"
mkdir -p "$BACKUP_DIR"

# 4. 仅备份一次主配置文件（底线保障）
if [ -f /etc/ssh/sshd_config ]; then
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config_main_$(date +%Y%m%d%H%M%S).bak"
    echo -e "\033[34m主配置已备份至 $BACKUP_DIR\033[0m"
fi

# 5. 清理原来的 sshd_config.d 配置文件（慎重！）
echo -e "\033[33m清除原有 /etc/ssh/sshd_config.d/*.conf 文件...\033[0m"
find /etc/ssh/sshd_config.d/ -type f -name '*.conf' ! -name 'README' -delete

# 6. 写入全新配置文件
cat > "$CONFIG_FILE" << EOF
# 由 secure-ssh.sh 自动生成，时间：$(date)

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

# 7. 检查 SSH 配置语法
echo -e "\033[34m检查 SSH 配置语法...\033[0m"
sshd -t -f "$CONFIG_FILE" || { echo -e "\033[31m错误：SSH 配置无效，请检查。\033[0m"; exit 1; }

# 8. 安全解锁 root（如果被锁定）
ROOT_STATUS=$(passwd -S root | awk '{print $2}')
if [ "$ROOT_STATUS" = "L" ]; then
    echo -e "\033[33m⚠ root 账户当前被锁定，尝试使用无密码方式解锁...\033[0m"

    # 将 root 密码字段设为 *（禁止密码登录，但解锁账户）
    if usermod -p '*' root; then
        echo -e "\033[32m√ 成功设置 root 为无密码状态\033[0m"
        # 尝试解锁
        if passwd -u root; then
            echo -e "\033[32m√ root 已成功解锁（无密码，适用于密钥登录）\033[0m"
        else
            echo -e "\033[31m× passwd -u 执行失败，请手动检查 root 状态\033[0m"
        fi
    else
        echo -e "\033[31m× 无法通过 usermod 解锁 root，请手动检查 /etc/shadow 状态\033[0m"
    fi
else
    echo -e "\033[32m√ root 账户未锁定，无需处理\033[0m"
fi

# 9. 重启 SSH 服务
echo -e "\033[34m重启 SSH 服务...\033[0m"
if systemctl list-units --type=service | grep -q sshd.service; then
    systemctl restart sshd
else
    systemctl restart ssh
fi

# 10. 完成提示
echo -e "\033[32m✔ SSH 安全配置已生效！\033[0m"

cat << EOF

\033[33m=== 后续建议 ===\033[0m

1. 登录测试：
   ssh -p $NEW_PORT root@<服务器IP>

2. 防火墙建议：
   ufw allow $NEW_PORT/tcp
   ufw deny 22/tcp

3. 文件权限检查：
   chmod 600 ~/.ssh/authorized_keys
   chmod 700 ~/.ssh

4. 成功登录后再关闭旧连接！

EOF
