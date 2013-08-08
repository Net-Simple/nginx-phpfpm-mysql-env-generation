#!/bin/bash
### Скрипт конфигурации IPTables ###

# Очищаем предыдущие записи
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X 

# Установка политик по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Разрешаем локальный интерфейс
iptables -A INPUT -i lo -j ACCEPT

# Простая защита от DoS-атаки
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j ACCEPT

# Защита от спуфинга
iptables -I INPUT -m conntrack --ctstate NEW,INVALID -p tcp --tcp-flags SYN,ACK SYN,ACK -j REJECT --reject-with tcp-reset
# Защита от попытки открыть входящее соединение TCP не через SYN
iptables -I INPUT -m conntrack --ctstate NEW -p tcp ! --syn -j DROP

# Закрываемся от кривого icmp
iptables -I INPUT -p icmp -f -j DROP
# REL, ESTB allow
iptables -A INPUT -p tcp -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p udp -m state --state RELATED,ESTABLISHED -j ACCEPT

# Начнем с базовых вещей. Разрешим передачу трафика уже открытым соединениям:
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Разрешение главных типов протокола ICMP
iptables -A INPUT -p icmp --icmp-type 3 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type 11 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type 12 -j ACCEPT

# Защита сервера SSH от брутфорса
iptables -A INPUT -p tcp --syn --dport 22 -m recent --name dmitro --set
iptables -A INPUT -p tcp --syn --dport 22 -m recent --name dmitro --update --seconds 30 --hitcount 3 -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT


# Для работы OpenVPN #
/sbin/modprobe ip_tables
/sbin/modprobe iptable_filter
/sbin/modprobe iptable_mangle
/sbin/modprobe iptable_nat
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -p
iptables -I FORWARD 1 -i tap0 -p udp -j ACCEPT
iptables -I FORWARD 1 -i tap0 -p tcp -j ACCEPT
iptables -t nat -A POSTROUTING -s 192.168.231.0/24 -o eth0 -j SNAT --to-source 111.111.231.242
iptables -A INPUT -p udp --dport 1194 -j ACCEPT
#
iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited


# Просмотр
iptables -L --line-number
echo
echo "Adding DONE, maybe OK"
echo "Saving to rc, PSE wait!"
service iptables save
echo
service iptables restart
echo "Done"

service iptables restart
service network restart
service openvpn restart

iptables -A INPUT -p tcp --dport 8083 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT