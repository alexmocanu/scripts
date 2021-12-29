#Network Interfaces
INTERNAL=enp0s3
EXTERNAL=enp0s8
SERVER_DOMAIN=server.local

apt-get update

####### 1.Configure network interfaces
cp /etc/network/interfaces /etc/network/interfaces_old

truncate -s0 /etc/network/interfaces
echo 'source /etc/network/interfaces.d/*' >> /etc/network/interfaces
echo '# The loopback network interface' >> /etc/network/interfaces
echo 'auto lo' >> /etc/network/interfaces
echo 'iface lo inet loopback' >> /etc/network/interfaces
echo '' >> /etc/network/interfaces
echo '# The primary network interface' >> /etc/network/interfaces
echo "allow-hotplug $EXTERNAL" >> /etc/network/interfaces
echo "iface $EXTERNAL inet dhcp" >> /etc/network/interfaces
echo '' >> /etc/network/interfaces
echo '# The internal network interface' >> /etc/network/interfaces
echo "auto $INTERNAL" >> /etc/network/interfaces
echo "iface $INTERNAL inet static" >> /etc/network/interfaces
echo '        address 10.0.0.1' >> /etc/network/interfaces
echo '        netmask 255.255.255.0' >> /etc/network/interfaces
echo '        broadcast 10.0.0.255' >> /etc/network/interfaces

####### 2. Install and configure dnsmasq for dhcp and dns
apt-get -y install dnsmasq
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.old
truncate -s0 /etc/dnsmasq.conf

echo "interface=$INTERNAL" >> /etc/dnsmasq.conf
echo 'listen-address=127.0.0.1' >> /etc/dnsmasq.conf
echo "domain=$SERVER_DOMAIN" >> /etc/dnsmasq.conf
#remove this line if you don't need dhcp
echo 'dhcp-range=10.0.0.100,10.0.0.150,12h' >> /etc/dnsmasq.conf

#Setup DNS for several internal domains
#https://thinkingeek.com/2020/06/06/local-domain-and-dhcp-with-dnsmasq/
#echo 'address=/website1.local/10.0.0.2' >> /etc/dnsmasq.conf
#echo 'address=/website2.local/10.0.0.2' >> /etc/dnsmasq.conf
#echo 'address=/website3.local/10.0.0.2' >> /etc/dnsmasq.conf

service dnsmasq restart

####### 4. Install and configure iptables, setup ip forwarding
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get -y install iptables iptables-persistent

iptables -X; iptables -F; iptables -t nat -X; iptables -t nat -F

### 4.1 Configure ip forwarding and masquerading
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sed -i 's/net.ipv4.ip_forward=*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

iptables -t nat -A POSTROUTING -o $EXTERNAL -j MASQUERADE
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $INTERNAL -o $EXTERNAL -j ACCEPT

### 4.2 Manage traffic on external nic
###
### I don't block anything by default because my environment consists of several VirtualBox VMs all connected through an internal network (except the gateway VM which also has a second nic connected to the outside - usually bridged) 
### and I need to have stuff open for development/testing unless needed.

#Option 1 - block all incoming connections except certain services
#iptables -A INPUT -i $EXTERNAL -m state --state ESTABLISHED,RELATED -j ACCEPT #Allow incoming traffic on external interface that is a part of a connection we already allowed.
#iptables -A INPUT -i $EXTERNAL -p tcp --dport 22 -j ACCEPT #allow incoming ssh connections. Add more lines like this for other ports
#iptables -A INPUT -i $EXTERNAL -j DROP #Drop anything else not allowed above

#Option 2 - block all on external nic, allow all on internal network
#iptables -A INPUT -i $INTERNAL -p all -j ACCEPT
#iptables -A INPUT -i $EXTERNAL -p all -j DROP

### 4.3 Port forwarding (allow external clients to access certain services on machines within the internal network)
### https://www.digitalocean.com/community/tutorials/how-to-forward-ports-through-a-linux-gateway-with-iptables
#iptables -A FORWARD -i $EXTERNAL -o $INTERNAL -p tcp --syn --dport 80 -m conntrack --ctstate NEW -j ACCEPT
#iptables -A FORWARD -i $INTERNAL -o $EXTERNAL -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
#iptables -A FORWARD -i $EXTERNAL -o $INTERNAL -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
#iptables -t nat -A PREROUTING -i $INTERNAL -p tcp --dport 80 -j DNAT --to-destination 192.0.2.2 #(ip target server)
#iptables -t nat -A POSTROUTING -o $INTERNAL -p tcp --dport 80 -d 192.0.2.2 -j SNAT --to-source 192.0.2.15 #(gateway ip)

### 5 Save iptables
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

### 6 Restart networking services
service networking restart
