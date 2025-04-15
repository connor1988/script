#!/bin/bash

# 颜色设置
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m"  # No Color

# 辅助函数：检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 打印网络接口
print_interfaces() {
    ip -4 -o addr show | awk '{print " inet "$4" "$2}'
}

# 获取网卡使用量（使用 vnstat）
print_network_usage() {
    # 定义颜色
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color

    # 检查 vnstat 是否已安装
    if command -v vnstat >/dev/null 2>&1; then
        echo -e "${YELLOW}========== Network Usage ==========${NC}"
        for interface_path in /sys/class/net/*; do
            interface=$(basename "$interface_path")
            if [[ "$interface" != "lo" && ! "$interface" == veth* && ! "$interface" == br-* ]]; then
                echo -e "${BLUE}$interface${NC}:"
                vnstat -i "$interface" --oneline | awk -F\; -v GREEN="$GREEN" -v NC="$NC" \
                    '{print GREEN "  Received: " $4 "   Transmitted: " $5 NC}'
                echo ""
            fi
        done
    else
        echo -e "${RED}vnstat command not found! Please install vnstat.${NC}"
    fi
}


print_hourly_network_usage() {
    if command_exists vnstat; then
        echo -e "\n${YELLOW}Hourly Network Usage per Interface:${NC}"
        for interface in $(ls /sys/class/net/); do
            if [[ "$interface" != "lo" && ! "$interface" == veth* && ! "$interface" == br-* ]]; then
                echo -e "\n${BLUE}Interface: $interface${NC}"
                vnstat -i "$interface" -h | tail -n 12
            fi
        done
    else
        echo -e "${RED}vnstat not found. Please install it to see network usage stats.${NC}"
    fi
}


print_network_connections_with_location() {
    echo -e "\n${YELLOW}Active Network Connections (with Port & Location from ipinfo.io + cache):${NC}"

    CACHE_FILE="$HOME/.ip_location_cache"
    CACHE_TTL=$((60 * 60 * 24))  # 24 hours

    if ! command_exists jq; then
        echo -e "${RED}jq not found. Install it with: sudo apt install jq${NC}"
        return
    fi

    mkdir -p "$(dirname "$CACHE_FILE")"
    touch "$CACHE_FILE"

    # 获取 ESTABLISHED 的远程 IP:PORT
    ss -tnp | grep ESTAB | awk '{print $5}' | sort | uniq | while read -r ip_port; do
        ip=$(echo "$ip_port" | awk -F':' '{OFS=":"; if (NF>2) {print $(NF-1), $NF} else {print $1, $2}}' | cut -d: -f1)
        port=$(echo "$ip_port" | awk -F':' '{print $NF}')

        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ && "$ip" != "127.0.0.1" ]]; then
            location=""

            # 从缓存查找
            if grep -q "^$ip|" "$CACHE_FILE"; then
                line=$(grep "^$ip|" "$CACHE_FILE")
                timestamp=$(echo "$line" | cut -d'|' -f2)
                now=$(date +%s)

                if (( now - timestamp < CACHE_TTL )); then
                    location=$(echo "$line" | cut -d'|' -f3-)
                fi
            fi

            # 如果缓存失效或没有，则请求 ipinfo.io
            if [[ -z "$location" ]]; then
                info=$(curl -s --max-time 2 "https://ipinfo.io/$ip/json")
                city=$(echo "$info" | jq -r '.city // "N/A"')
                region=$(echo "$info" | jq -r '.region // "N/A"')
                country=$(echo "$info" | jq -r '.country // "N/A"')
                org=$(echo "$info" | jq -r '.org // "N/A"')
                location="$city, $region, $country ($org)"

                # 写入缓存
                now=$(date +%s)
                # 删除旧记录
                sed -i "\|^$ip|d" "$CACHE_FILE"
                echo "$ip|$now|$location" >> "$CACHE_FILE"
            fi

            echo -e "${GREEN}$ip:$port${NC} — ${BLUE}$location${NC}"
        fi
    done
}


# 获取主机名
HOSTNAME=$(hostname)
HOSTNAME_UPPER=$(echo "$HOSTNAME" | tr 'a-z' 'A-Z')

# 计算横幅宽度并居中
WIDTH=80
BANNER="**                          $HOSTNAME_UPPER                                **"
BANNER_WIDTH=$((${#BANNER}))

# 计算空格数，使标题居中
PADDING=$((($WIDTH - $BANNER_WIDTH) / 2))
PADDING_STR=$(printf "%-${PADDING}s" " ")

# 打印欢迎信息
echo "******************************************************************************"
echo -e "${PADDING_STR}${BANNER}"
echo "******************************************************************************"
echo ""
echo -e " Welcome ${BLUE}$(whoami)${NC} to the ${GREEN}${HOSTNAME}${NC}"
echo ""
echo " Date: $(date)"
echo ""
echo -e " Hostname:   ${HOSTNAME}"
echo -e " CPU Model:  $(lscpu | grep 'Model name' | grep -v 'BIOS'| awk -F: '{print $2}' | sed 's/^ *//')"
echo ""
echo -e " On-line CPU(s) list:                  $(lscpu | grep 'On-line CPU' | awk -F: '{print $2}' | sed 's/^ *//')"
echo ""
echo -e " OS: ${BLUE}$(awk -F= '/^PRETTY_NAME=/{gsub(/"/, "", $2); print $2}' /etc/os-release)${NC}"
echo ""
echo -e " Total Memory:        $(grep MemTotal /proc/meminfo | awk '{print $2}' ) kB"
echo -e " Free Memory:         $(grep MemFree /proc/meminfo | awk '{print $2}' ) kB"
echo ""
echo -e " Swap Total:          $(grep SwapTotal /proc/meminfo | awk '{print $2}' ) kB"
echo -e " Swap Free:           $(grep SwapFree /proc/meminfo | awk '{print $2}' ) kB"
echo ""

# 获取磁盘使用率
echo " Disk usage:"
df -h / | tail -1
echo ""

# 获取内存使用率
echo " Memory usage:"
free -h
echo ""

# 获取 CPU 使用率
echo " CPU usage (1 second interval):"
top -bn1 | grep "Cpu(s)" | sed "s/Cpu(s):/ CPU(s):/g" | awk '{print $2, $3, $4, $5, $6}'
echo ""

# 获取系统负载
echo " System Load:"
uptime
echo ""

# 获取负载平均值（过去 1 分钟、5 分钟、15 分钟）
echo " Load Average:"
cat /proc/loadavg
echo ""

# 获取网卡流量统计（显示每个网卡）
print_network_usage
echo ""

# 打印接口信息
echo " Interfaces:"
print_interfaces

print_hourly_network_usage


print_network_connections_with_location
echo "******************************************************************************"
