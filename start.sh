#!/bin/bash

set -x

count=$(iptables-save | grep TPROXY_ | wc -l)
if [ $count -gt 0 ] ;then
	echo "Already enabled"
	exit 0;
fi

# Config
source ./config.sh

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.route_localnet=1

ip -4 route add local default dev lo table $table
ip -4 rule add fwmark $mark table $table protocol kernel

ipset create localnetwork hash:net
ipset add localnetwork 0.0.0.0/8
ipset add localnetwork 10.0.0.0/8
ipset add localnetwork 100.64.0.0/10
ipset add localnetwork 127.0.0.0/8
ipset add localnetwork 169.254.0.0/16
ipset add localnetwork 172.16.0.0/12
ipset add localnetwork 192.0.0.0/24
ipset add localnetwork 192.0.2.0/24
ipset add localnetwork 192.88.99.0/24
ipset add localnetwork 192.168.0.0/16
ipset add localnetwork 198.18.0.0/15
ipset add localnetwork 198.51.100.0/24
ipset add localnetwork 203.0.113.0/24
ipset add localnetwork 224.0.0.0/4
ipset add localnetwork 240.0.0.0/4
ipset add localnetwork 255.255.255.255/32

iptables -t mangle -N TPROXY_PREROUTING
iptables -t mangle -N TPROXY_OUTPUT

iptables -t mangle -N TPROXY_RULE
iptables -t mangle -A TPROXY_RULE -j CONNMARK --restore-mark
iptables -t mangle -A TPROXY_RULE -m mark --mark $mark -j RETURN
iptables -t mangle -A TPROXY_RULE -m set --match-set localnetwork dst -j RETURN
iptables -t mangle -A TPROXY_RULE -p tcp -m multiport --dports 1:65535 --syn -j MARK --set-mark $mark
iptables -t mangle -A TPROXY_RULE -p udp -m multiport --dports 1:65535 -m conntrack --ctstate NEW -j MARK --set-mark $mark
iptables -t mangle -A TPROXY_RULE -j CONNMARK --save-mark

iptables -t mangle -A TPROXY_OUTPUT -m owner --uid-owner clash -j RETURN
iptables -t mangle -A TPROXY_OUTPUT -m addrtype --src-type LOCAL ! --dst-type LOCAL -p tcp -j TPROXY_RULE
iptables -t mangle -A TPROXY_OUTPUT -m addrtype --src-type LOCAL ! --dst-type LOCAL -p udp -j TPROXY_RULE

iptables -t mangle -A TPROXY_PREROUTING -i lo -m mark ! --mark $mark -j RETURN
iptables -t mangle -A TPROXY_PREROUTING -m addrtype --dst-type LOCAL -p udp --dport 53 -j RETURN
iptables -t mangle -A TPROXY_PREROUTING -m addrtype --dst-type LOCAL -p udp --dport $dns_port -j RETURN
iptables -t mangle -A TPROXY_PREROUTING -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -p tcp -j TPROXY_RULE
iptables -t mangle -A TPROXY_PREROUTING -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -p udp -j TPROXY_RULE
iptables -t mangle -A TPROXY_PREROUTING -p tcp -m mark --mark $mark -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port
iptables -t mangle -A TPROXY_PREROUTING -p udp -m mark --mark $mark -j TPROXY --on-ip 127.0.0.1 --on-port $tproxy_port

iptables -t mangle -A PREROUTING -j TPROXY_PREROUTING
iptables -t mangle -A OUTPUT -j TPROXY_OUTPUT

# DNS
iptables -t nat -N TPROXY_DNS_LOCAL
iptables -t nat -A TPROXY_DNS_LOCAL -p udp ! --dport 53 -j RETURN
iptables -t nat -A TPROXY_DNS_LOCAL -m owner --uid-owner clash -j RETURN
iptables -t nat -A TPROXY_DNS_LOCAL -p udp --dport 53 -j REDIRECT --to-ports $dns_port
iptables -t nat -A OUTPUT -p udp -j TPROXY_DNS_LOCAL

iptables -t nat -N TPROXY_DNS_EXTERNAL
iptables -t nat -A TPROXY_DNS_EXTERNAL -p udp ! --dport 53 -j RETURN
iptables -t nat -A TPROXY_DNS_EXTERNAL -p udp --dport 53 -j REDIRECT --to-ports $dns_port
iptables -t nat -A PREROUTING -p udp -j TPROXY_DNS_EXTERNAL
