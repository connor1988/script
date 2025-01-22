#!/bin/bash

echo "Execute apt update"
apt upgrade -y

echo "Install Necessary softwares"
apt install curl vim wget gnupg dpkg apt-transport-https lsb-release ca-certificates -y

echo "Add docker compose v2 to soruce list"
curl -sSL https://download.docker.com/linux/debian/gpg | gpg --dearmor > /usr/share/keyrings/docker-ce.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-ce.gpg] https://download.docker.com/linux/debian $(lsb_release -sc) stable" > /etc/apt/sources.list.d/docker.list

echo "Install docker-compose v2"
apt update
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
