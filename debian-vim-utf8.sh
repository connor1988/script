#!/bin/bash
echo Apply WA to set vim support chinese words in Debian12
cat << EOF >> /etc/vim/vimrc
set encoding=utf-8
set fileencodings=utf-8,latin1
set termencoding=utf-8
EOF
