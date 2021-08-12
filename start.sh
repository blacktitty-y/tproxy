#!/bin/sh

set -x

count=$(iptables-save | grep CLASH | wc -l)
if [ $count -gt 0 ] ;then
	echo "Already enabled"
	exit 0;
fi

# Local Networks
ipset create localnetwork hash:net
ipset add localnetwork 0.0.0.0/8
ipset add localnetwork 127.0.0.0/8
ipset add localnetwork 10.0.0.0/8
ipset add localnetwork 169.254.0.0/16
ipset add localnetwork 192.168.0.0/16
ipset add localnetwork 224.0.0.0/4
ipset add localnetwork 240.0.0.0/4
ipset add localnetwork 172.16.0.0/12

# TCP
iptables -t nat -N CLASH_LOCAL
iptables -t nat -A CLASH_LOCAL -m owner --uid-owner clash -j RETURN
iptables -t nat -A CLASH_LOCAL -m addrtype --dst-type BROADCAST -j RETURN
iptables -t nat -A CLASH_LOCAL -m set --match-set localnetwork dst -j RETURN
iptables -t nat -A CLASH_LOCAL -p tcp -j REDIRECT --to-ports 7892
iptables -t nat -A OUTPUT -p tcp -m set --match-set localnetwork src -j CLASH_LOCAL
iptables -t nat -A OUTPUT -p tcp -m addrtype --src-type LOCAL -j CLASH_LOCAL

iptables -t nat -N CLASH_EXTERNAL
iptables -t nat -A CLASH_EXTERNAL -m addrtype --dst-type BROADCAST -j RETURN
iptables -t nat -A CLASH_EXTERNAL -m set --match-set localnetwork dst -j RETURN
iptables -t nat -A CLASH_EXTERNAL -p tcp -j REDIRECT --to-ports 7892
iptables -t nat -A PREROUTING -p tcp -m set --match-set localnetwork src -j CLASH_EXTERNAL
iptables -t nat -A PREROUTING -p tcp -m addrtype --src-type LOCAL -j CLASH_EXTERNAL

# UDP
ip rule add fwmark 1 table 100
ip route add local default dev lo table 100
iptables -t mangle -N CLASH_UDP
iptables -t mangle -A CLASH_UDP -p udp --dport 53 -j RETURN
iptables -t mangle -A CLASH_UDP -m addrtype --dst-type BROADCAST -j RETURN
iptables -t mangle -A CLASH_UDP -m set --match-set localnetwork dst -j RETURN
iptables -t mangle -A CLASH_UDP -p udp -j TPROXY --on-port 7892 --tproxy-mark 1
iptables -t mangle -A PREROUTING -p udp -m set --match-set localnetwork src -j CLASH_UDP
iptables -t mangle -A PREROUTING -p udp -m addrtype --src-type LOCAL -j CLASH_UDP

# DNS
iptables -t nat -N CLASH_DNS_LOCAL
iptables -t nat -A CLASH_DNS_LOCAL -p udp ! --dport 53 -j RETURN
iptables -t nat -A CLASH_DNS_LOCAL -m owner --uid-owner clash -j RETURN
iptables -t nat -A CLASH_DNS_LOCAL -p udp --dport 53 -j REDIRECT --to-ports 1053
iptables -t nat -A OUTPUT -p udp -j CLASH_DNS_LOCAL

iptables -t nat -N CLASH_DNS_EXTERNAL
iptables -t nat -A CLASH_DNS_EXTERNAL -p udp ! --dport 53 -j RETURN
iptables -t nat -A CLASH_DNS_EXTERNAL -p udp --dport 53 -j REDIRECT --to-ports 1053
iptables -t nat -A PREROUTING -p udp -j CLASH_DNS_EXTERNAL

echo "Done"
