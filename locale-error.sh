#!/bin/bash

# Locale自动配置脚本 - 用于解决Debian 12上的Perl警告问题
# 使用方法: sudo bash configure_locale.sh

set -e  # 出错时终止脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 此脚本需要root权限运行。请使用sudo命令执行。${NC}"
    exit 1
fi

echo -e "${YELLOW}正在更新软件包列表...${NC}"
apt-get update -y

echo -e "${YELLOW}正在安装locales包...${NC}"
apt-get install -y locales

echo -e "${YELLOW}正在生成所需的Locale...${NC}"
# 生成en_US.UTF-8和zh_CN.UTF-8 (可根据需要修改)
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i -e 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales

echo -e "${YELLOW}正在设置系统默认Locale...${NC}"
# 设置系统默认Locale
echo "LANG=en_US.UTF-8" > /etc/default/locale
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale

# 更新环境变量
echo 'export LANG=en_US.UTF-8' > /etc/profile.d/locale.sh
echo 'export LC_ALL=en_US.UTF-8' >> /etc/profile.d/locale.sh

echo -e "${GREEN}Locale配置完成！${NC}"
echo -e "${GREEN}请重新登录会话或重启系统使更改完全生效。${NC}"

# 验证当前设置
echo -e "\n${YELLOW}当前Locale设置:${NC}"
locale -a | grep -E 'en_US|zh_CN'
echo "LANG=$(echo $LANG)"
echo "LC_ALL=$(echo $LC_ALL)"    
