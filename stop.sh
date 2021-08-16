#!/bin/sh

set -x

source ./config.sh

echo "Removing iptables rules"

ip -4 rule del fwmark $mark table $table
ip -4 route del local default dev lo table $table

iptables -t mangle -F TPROXY_OUTPUT
iptables -t mangle -D OUTPUT -j TPROXY_OUTPUT
iptables -t mangle -X TPROXY_OUTPUT

iptables -t mangle -F TPROXY_PREROUTING
iptables -t mangle -D PREROUTING -j TPROXY_PREROUTING
iptables -t mangle -X TPROXY_PREROUTING

iptables -t mangle -F TPROXY_RULE
iptables -t mangle -X TPROXY_RULE

# DNS
iptables -t nat -F TPROXY_DNS_LOCAL
iptables -t nat -D OUTPUT -p udp -j TPROXY_DNS_LOCAL
iptables -t nat -X TPROXY_DNS_LOCAL

iptables -t nat -F TPROXY_DNS_EXTERNAL
iptables -t nat -D PREROUTING -p udp -j TPROXY_DNS_EXTERNAL
iptables -t nat -X TPROXY_DNS_EXTERNAL

ipset destroy localnetwork

echo "Done"
