#!/bin/bash

find /usr/share/vim -type f -path "/usr/share/vim/vim[0-9]*/defaults.vim" | while read -r file; do
    echo "处理文件: $file"
    #sed -i '/if has.(.*mouse.*)/,/endif/ s/^\s*set mouse=a/set mouse-=a/' "$file"
    sed -i.bak '/if has.(.*mouse.*)/,/endif/ s/^\s*set mouse=a/set mouse-=a/' "$file"
done

