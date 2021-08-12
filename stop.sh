#!/bin/sh

set -x

echo "Removing iptables rules"

ip rule del fwmark 1 table 100
ip route del local default dev lo table 100

# TCP
iptables -t nat -F CLASH_LOCAL
iptables -t nat -D OUTPUT -p tcp -m set --match-set localnetwork src -j CLASH_LOCAL
iptables -t nat -D OUTPUT -p tcp -m addrtype --src-type LOCAL -j CLASH_LOCAL
iptables -t nat -X CLASH_LOCAL

iptables -t nat -F CLASH_EXTERNAL
iptables -t nat -D PREROUTING -p tcp -m set --match-set localnetwork src -j CLASH_EXTERNAL
iptables -t nat -D PREROUTING -p tcp -m addrtype --src-type LOCAL -j CLASH_EXTERNAL
iptables -t nat -X CLASH_EXTERNAL

# UDP
iptables -t mangle -F CLASH_UDP
iptables -t mangle -D PREROUTING -p udp -m set --match-set localnetwork src -j CLASH_UDP
iptables -t mangle -D PREROUTING -p udp -m addrtype --src-type LOCAL -j CLASH_UDP
iptables -t mangle -X CLASH_UDP

# DNS
iptables -t nat -F CLASH_DNS_LOCAL
iptables -t nat -D OUTPUT -p udp -j CLASH_DNS_LOCAL
iptables -t nat -X CLASH_DNS_LOCAL

iptables -t nat -F CLASH_DNS_EXTERNAL
iptables -t nat -D PREROUTING -p udp -j CLASH_DNS_EXTERNAL
iptables -t nat -X CLASH_DNS_EXTERNAL

ipset destroy localnetwork

echo "Done"
