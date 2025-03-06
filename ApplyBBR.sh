#!/bin/bash
echo Apply BBR
cat << EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p
