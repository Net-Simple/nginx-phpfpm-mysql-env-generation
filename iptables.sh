#!/bin/bash
#####################################################################

# 1) Clear old Rules
iptables -F 												# Delete all existing rules

# 2) Default Drop
iptables -P INPUT DROP											# Set default chain policies to DROP
iptables -P FORWARD DROP										# Set default chain policies to DROP
iptables -P OUTPUT DROP											# Set default chain policies to DROP

# 3) Loopback 													
iptables -A INPUT -i lo -j ACCEPT									# Allow loopback access from INPUT
iptables -A OUTPUT -o lo -j ACCEPT									# Allow loopback access from Output

# 4) BLACKLIST IP's
# iptables -A INPUT -s "BLOCK_THIS_IP" -j DROP								# Block a specific ip-address
# iptables -A INPUT -s "BLOCK_THIS_IP" -j DROP								# Block a specific ip-address
# iptables -A INPUT -s "BLOCK_THIS_IP" -j DROP								# Block a specific ip-address
# iptables -A INPUT -s "BLOCK_THIS_IP" -j DROP								# Block a specific ip-address

# 5) WHITELIST IP's
iptables -A INPUT -s 127.0.0.1/32 -j ACCEPT								# Allow Anything from localhost 	
iptables -A INPUT -s "ALLOW_THIS_IP"/32 -j ACCEPT								# Allow Anything from KeyServer


# 6) ALLOWED SERVICES
iptables -A OUTPUT -o eth0 -p tcp --sport 25 -m state --state ESTABLISHED -j ACCEPT			# PORT 25   SMTP   - Allow connections to outbound
iptables -A OUTPUT -p udp -o eth0 --dport 53 -j ACCEPT							# PORT 54   DNS    - Allow connections to outbound 
iptables -A INPUT -p tcp -m tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT			# PORT 80   httpd  - Allow connections from anywhere
iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT		# PORT 80   httpd  - Rate Limit from outside
iptables -A INPUT -p tcp -m tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT			# PORT 443  SSL    - Allow connections from anywhere

# 7) PING
iptables -A INPUT -p icmp -m icmp --icmp-type address-mask-request -j DROP				# Drop Ping from address-mask-request
iptables -A INPUT -p icmp -m icmp --icmp-type timestamp-request -j DROP					# Drop Ping from timestamp-request
iptables -A INPUT -p icmp -m icmp -m limit --limit 1/second -j ACCEPT 					# Rate Limit Ping from outside 

# 8) Validate packets
iptables -A INPUT   -m state --state INVALID -j DROP							# Drop invalid packets 
iptables -A FORWARD -m state --state INVALID -j DROP							# Drop invalid packets 
iptables -A OUTPUT  -m state --state INVALID -j DROP							# Drop invalid packets 
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,FIN SYN,FIN -j DROP					# Drop TCP - SYN,FIN packets 
iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP					# Drop TCP - SYN,RST packets 

# 9) Reject Invalid networks (Spoof)
iptables -A INPUT -s 10.0.0.0/8       -j DROP								# (Spoofed network)
iptables -a INPUT -s 192.0.0.1/24     -j DROP								# (Spoofed network)
iptables -A INPUT -s 169.254.0.0/16   -j DROP								# (Spoofed network)
iptables -A INPUT -s 172.16.0.0/12    -j DROP								# (Spoofed network)
iptables -A INPUT -s 224.0.0.0/4      -j DROP								# (Spoofed network)
iptables -A INPUT -d 224.0.0.0/4      -j DROP								# (Spoofed network)
iptables -A INPUT -s 240.0.0.0/5      -j DROP								# (Spoofed network)
iptables -A INPUT -d 240.0.0.0/5      -j DROP								# (Spoofed network)
iptables -A INPUT -s 0.0.0.0/8        -j DROP								# (Spoofed network)
iptables -A INPUT -d 0.0.0.0/8        -j DROP								# (Spoofed network)
iptables -A INPUT -d 239.255.255.0/24 -j DROP								# (Spoofed network)
iptables -A INPUT -d 255.255.255.255  -j DROP								# (Spoofed network)


# 10) CHAINS

# FTP_BRUTE CHAIN
# iptables -A INPUT -p tcp -m multiport --dports 20,21 -m state --state NEW -m recent --set --name FTP_BRUTE
# iptables -A INPUT -p tcp -m multiport --dports 20,21 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --rttl --name FTP_BRUTE -j DROP

# SYNFLOOD CHAIN
iptables -A INPUT -m state --state NEW -p tcp -m tcp --syn -m recent --name SYNFLOOD--set						
iptables -A INPUT -m state --state NEW -p tcp -m tcp --syn -m recent --name SYNFLOOD --update --seconds 1 --hitcount 60 -j DROP

# Logging CHAIN
iptables -N LOGGING												# Create `LOGGING` chain for logging denied packets
iptables -A INPUT -j LOGGING											# Create `LOGGING` chain for logging denied packets 	
iptables -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "IPTables Packet Dropped: " --log-level 6	# Log denied packets to /var/log/messages
iptables -A LOGGING -j DROP	






