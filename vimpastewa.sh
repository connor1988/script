#!/bin/bash

# 查找匹配 vim 加数字目录中的 defaults.vim 文件
find /usr/share/vim -type f -path "/usr/share/vim/vim[0-9]*/defaults.vim" | while read -r file; do
    echo "检查文件: $file"

    # 如果包含 set mouse=a，则修改为 set mouse-=a
    if grep -q '^set mouse=a' "$file"; then
        echo "修改: set mouse=a → set mouse-=a"
        # 使用 sed 原地修改（创建备份为 .bak 可选）
        sed -i 's/^set mouse=a/set mouse-=a/' "$file"
    else
        echo "未找到 set mouse=a，跳过"
    fi
done
