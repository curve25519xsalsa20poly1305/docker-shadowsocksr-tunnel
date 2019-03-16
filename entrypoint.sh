#!/usr/bin/env bash

function spawn {
    if [[ -z ${PIDS+x} ]]; then PIDS=(); fi
    "$@" &
    PIDS+=($!)
}

function join {
    if [[ ! -z ${PIDS+x} ]]; then
        for pid in "${PIDS[@]}"; do
            wait "${pid}"
        done
    fi
}

function on_kill {
    if [[ ! -z ${PIDS+x} ]]; then
        for pid in "${PIDS[@]}"; do
            kill "${pid}" 2> /dev/null
        done
    fi
    kill "${ENTRYPOINT_PID}" 2> /dev/null
}

export ENTRYPOINT_PID="${BASHPID}"

trap "on_kill" EXIT
trap "on_kill" SIGINT

cat << EOF > /etc/shadowsocksr/config.json
{
    "server": "${SERVER_ADDR}",
    "server_port": ${SERVER_PORT},
    "local_address": "0.0.0.0",
    "local_port": ${REDIR_PORT},
    "password": "${SERVER_PASS}",
    "timeout": ${TIMEOUT},
    "method": "${METHOD}",
    "protocol": "${PROTO}",
    "protocol_param": "${PROTO_PARAM}",
    "obfs": "${OBFS}",
    "obfs_param": "${OBFS_PARAM}",
    "redirect": "",
    "dns_ipv6": false,
    "fast_open": false,
    "workers": 1
}
EOF

SERVER_IP=$(getent hosts "${SERVER_ADDR}" | awk '{ print $1 }')

mkfifo /shadowsocksr-fifo
spawn ss-redir -c /etc/shadowsocksr/config.json --up shadowsocksr-up.sh

if [[ -n "${SOCKS5_PORT}" ]]; then
    mkfifo /socks5-fifo
    SOCKS5_UP=socks5-up.sh spawn socks5
    cat /socks5-fifo > /dev/null
    rm -f /socks5-fifo
fi

cat /shadowsocksr-fifo > /dev/null
rm -f /shadowsocksr-fifo

iptables -t nat -N SSR_TCP
iptables -t nat -A SSR_TCP -p tcp -d "${SERVER_IP}" -j RETURN
iptables -t nat -A SSR_TCP -p tcp -d 0.0.0.0/8 -j RETURN
iptables -t nat -A SSR_TCP -p tcp -d 10.0.0.0/8 -j RETURN
iptables -t nat -A SSR_TCP -p tcp -d 127.0.0.0/8 -j RETURN
iptables -t nat -A SSR_TCP -p tcp -d 169.254.0.0/16 -j RETURN
iptables -t nat -A SSR_TCP -p tcp -d 172.16.0.0/12 -j RETURN
iptables -t nat -A SSR_TCP -p tcp -d 192.168.0.0/16 -j RETURN
iptables -t nat -A SSR_TCP -p tcp -d 224.0.0.0/4 -j RETURN
iptables -t nat -A SSR_TCP -p tcp -d 240.0.0.0/4 -j RETURN
iptables -t nat -A SSR_TCP -p tcp -j REDIRECT --to-ports "${REDIR_PORT}"
iptables -t nat -A OUTPUT -p tcp -j SSR_TCP

ip route add local default dev lo table 100
ip rule add fwmark 1 lookup 100

iptables -t mangle -N SSR_UDP
iptables -t mangle -A SSR_UDP -p udp -d 0.0.0.0/8 -j RETURN
iptables -t mangle -A SSR_UDP -p udp -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A SSR_UDP -p udp -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A SSR_UDP -p udp -d 169.254.0.0/16 -j RETURN
iptables -t mangle -A SSR_UDP -p udp -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A SSR_UDP -p udp -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A SSR_UDP -p udp -d 224.0.0.0/4 -j RETURN
iptables -t mangle -A SSR_UDP -p udp -d 240.0.0.0/4 -j RETURN
iptables -t mangle -A SSR_UDP -p udp -j DROP
iptables -t mangle -A SSR_UDP -p udp -j TPROXY --on-port "${REDIR_PORT}" --tproxy-mark 0x01/0x01
iptables -t mangle -A PREROUTING -p udp -j SSR_UDP

if [[ -n "${SOCKS5_UP}" ]]; then
    "${SOCKS5_UP}" &
fi

if [[ -n "${SHADOWSOCKSR_UP}" ]]; then
    "${SHADOWSOCKSR_UP}" &
fi

if [[ $# -gt 0 ]]; then
    "$@"
fi

if [[ $# -eq 0 || "${DAEMON_MODE}" == true ]]; then
    join
fi
