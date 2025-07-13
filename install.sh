

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


#Add change ssh port script
# 询问用户是否要运行脚本
read -p "是否要运行SSH端口修改脚本? (Y/N): " answer

# 检查用户输入
if [[ "$answer" =~ ^[Yy]$ ]]; then
    # 提示用户输入端口
    read -p "请输入端口号: " port

    # 验证端口号是否为数字
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "错误: 端口号必须是数字" >&2
        exit 1
    fi

    # 构建并执行curl命令
    echo "正在运行脚本，端口号: $port"
    curl https://raw.githubusercontent.com/connor1988/script/refs/heads/main/ssh-cusotmer.sh | bash -s "$port"
else
    echo "已取消操作"
    exit 0
fi   
