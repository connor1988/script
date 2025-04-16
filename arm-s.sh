#!/bin/bash

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

arch=$(uname -m)
# 获取传感器信息（保留原始格式）
if sensors &>/dev/null; then
  r=$(sensors | grep -E 'Package id 0|fan|Physical id 0|Core|temp[0-9]+' |
      grep '^[a-zA-Z0-9]' |
      while IFS=: read -r key val; do
        clean_key=$(echo "$key" | tr -d ' ')
        temp_val=$(echo "$val" | grep -o '[+-][0-9.]\+°C' | head -n1)
        if [[ -n "$temp_val" ]]; then
          echo "\"$clean_key\":\"$temp_val\","
        fi
      done |
      tr -d '\n' |
      sed 's/,$//' |
      sed 's/°C/\&deg;C/g')
else
  r="\"sensors\":\"N/A\""
fi

# 初始化
curC="N/A"
maxC="N/A"
minC="N/A"

if [[ "$arch" == arm* || "$arch" == aarch64 ]]; then
  freq_base="/sys/devices/system/cpu/cpu0/cpufreq"

  if [[ -f "$freq_base/scaling_cur_freq" ]]; then
    freq_val=$(cat "$freq_base/scaling_cur_freq")
    curC=$(awk -v val="$freq_val" 'BEGIN { printf "%.3f", val / 1000 }')
  fi

  if [[ -f "$freq_base/scaling_max_freq" ]]; then
    max_val=$(cat "$freq_base/scaling_max_freq")
    maxC=$(awk -v val="$max_val" 'BEGIN { printf "%.2f", val / 1000 }')
  fi

  if [[ -f "$freq_base/scaling_min_freq" ]]; then
    min_val=$(cat "$freq_base/scaling_min_freq")
    minC=$(awk -v val="$min_val" 'BEGIN { printf "%.4f", val / 1000 }')
  fi
fi


# 拼接 CPU 字段
c="\"CPU-MHz\":\"$curC\",\"CPU-max-MHz\":\"$maxC\",\"CPU-min-MHz\":\"$minC\""

#r=$(echo "$r" | grep -oP 'Core 0:\s+\+?\K[+-]?\d+\.?\d*')
# 最终组合
r="{$r,$c}"
echo $r
