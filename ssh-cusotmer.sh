#!/bin/bash

# SSH 安全配置脚本功能：
# 1. 修改 SSH 端口
# 2. 禁用密码登录，强制密钥认证
# 3. 允许 root 登录（仅密钥）
# 4. 允许其他用户登录（仅密钥）
# 5. 自动配置备份与验证
# 6. 服务重启

set -e # 任何错误立即终止脚本

# ================= 用户配置区域 =================
NEW_PORT="$1"                  # 通过参数指定新端口
ALLOWED_USERS="${2:-}"         # 可选参数：指定允许登录的用户（逗号分隔）
# ================================================

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m错误：必须使用 sudo 或 root 用户执行\033[0m"
    exit 1
fi

# 验证端口参数
if [ -z "$NEW_PORT" ] || ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1024 -o "$NEW_PORT" -gt 65535 ]; then
    echo -e "\033[31m错误：必须指定 1024-65535 的有效端口号\033[0m"
    echo "用法：sudo bash $0 <端口号> [允许用户列表]"
    echo "示例：sudo bash $0 2222 \"admin,deploy\""
    exit 1
fi

# 配置文件参数
CONFIG_FILE="/etc/ssh/sshd_config.d/99-ssh-security.conf"
BACKUP_DIR="/etc/ssh/sshd_config.bak"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 备份旧配置
if [ -f "$CONFIG_FILE" ]; then
    backup_file="${BACKUP_DIR}/sshd_$(date +%Y%m%d%H%M%S).bak"
    cp "$CONFIG_FILE" "$backup_file"
    echo -e "\033[34m配置已备份至：$backup_file\033[0m"
fi

# 生成新配置
cat > "$CONFIG_FILE" << EOF
# ===== SSH 安全配置 - 生成时间：$(date) =====

# 基础安全配置
Port $NEW_PORT
AddressFamily inet
Protocol 2

# 认证配置
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no

# 用户访问控制
$([ -n "$ALLOWED_USERS" ] && echo "AllowUsers ${ALLOWED_USERS//,/ }")

# 会话设置
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 5

# 加密算法增强
HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-ed25519
KexAlgorithms curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF

# 配置语法检查
if ! sshd -t -f "$CONFIG_FILE"; then
    echo -e "\033[31m错误：SSH 配置测试失败，请检查语法\033[0m"
    exit 1
fi

# 重启 SSH 服务
systemctl restart ssh

echo -e "\033[32mSSH 安全配置已完成，服务已重启！\033[0m"

# 显示关键提示
cat << EOF

\033[33m=== 后续操作指南 ===\033[0m
1. 公钥部署要求：
   - Root 用户：/root/.ssh/authorized_keys
   - 普通用户：~/.ssh/authorized_keys
   - 权限设置：chmod 600 对应文件

2. 防火墙配置：
   ufw allow $NEW_PORT/tcp
   ufw deny 22/tcp

3. 连接测试命令：
   ssh -p $NEW_PORT -i ~/.ssh/私钥 用户名@服务器IP

4. 重要警告：
   - 确保至少有一个用户已配置公钥
   - 测试连接后再关闭当前会话
   - 生产环境建议启用 fail2ban
EOF
