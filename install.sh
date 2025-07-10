

echo "Fix locale error"
curl https://raw.githubusercontent.com/connor1988/script/refs/heads/main/locale-error.sh | bash

echo "应用BBR"
curl https://raw.githubusercontent.com/connor1988/script/refs/heads/main/ApplyBBR.sh | bash

echo "VIM 中文乱码WA"
curl https://raw.githubusercontent.com/connor1988/script/refs/heads/main/debian-vim-utf8.sh | bash

echo "安装docker v2版本"
curl https://raw.githubusercontent.com/connor1988/script/refs/heads/main/docker-compose.sh | bash

echo "安装Welcome 显示，需要提前安装vnstat"
#apt update && apt install vnstat jq -y
#wget https://raw.githubusercontent.com/connor1988/script/refs/heads/main/welcome.sh -O /etc/profile.d/welcome.sh

echo "debian vim不能粘贴WA"
curl https://raw.githubusercontent.com/connor1988/script/refs/heads/main/vimpastewa.sh | bash
