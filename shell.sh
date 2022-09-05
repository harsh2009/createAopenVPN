yum -y install epel-release && yum -y install openvpn easy-rsa
cp -r /usr/share/easy-rsa/3/* /etc/openvpn/easy-rsa/
cp -p /usr/share/doc/easy-rsa-3.0.6/vars.example /etc/openvpn/easy-rsa/vars

cd /etc/openvpn/easy-rsa/
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server1 nopass
./easyrsa sign-req server server1
./easyrsa gen-req client1 nopass
./easyrsa sign-req client client1
./easyrsa gen-dh
openvpn --genkey --secret /etc/openvpn/easy-rsa/ta.key
./easyrsa  gen-crl


cp -p pki/ca.crt /etc/openvpn/server/
cp -p pki/issued/server1.crt /etc/openvpn/server/
cp -p pki/private/server1.key /etc/openvpn/server/
cp -p ta.key /etc/openvpn/server/


cp -p pki/ca.crt /etc/openvpn/client/
cp -p pki/issued/client1.crt /etc/openvpn/client/
cp -p pki/private/client1.key /etc/openvpn/client/
cp -p ta.key /etc/openvpn/client/

cp pki/dh.pem /etc/openvpn/server/
cp pki/crl.pem /etc/openvpn/server/

cat >/etc/openvpn/server/server.conf <<EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server1.crt
key server1.key  # This file should be kept secret
dh dh.pem
crl-verify crl.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 114.114.114.114"
duplicate-cn
keepalive 10 120
tls-auth ta.key 0 # This file is secret
cipher AES-256-CBC
compress lz4-v2
push "compress lz4-v2"
max-clients 100
user nobody
group nobody
persist-key
persist-tun
status openvpn-status.log
log-append  openvpn.log
verb 3
explicit-exit-notify 1
EOF


echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf

firewall-cmd --permanent --add-service=openvpn

firewall-cmd --permanent --add-interface=tun0

firewall-cmd --permanent --add-masquerade

firewall-cmd --permanent --direct --passthrough ipv4 -t nat -A POSTROUTING -s 10.8.0.0/24 -o ens3 -j MASQUERADE

firewall-cmd --reload


systemctl enable openvpn-server@server
systemctl start openvpn-server@server

cat >/etc/openvpn/client/client.ovpn <<EOF
client
dev tun
proto udp
remote 132.226.147.213 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert client1.crt
key client1.key
remote-cert-tls server
tls-auth ta.key 1
cipher AES-256-CBC
verb 3
auth-nocache
comp-lzo
EOF

echo "<ca>" >>/etc/openvpn/client/client.ovpn
cat /etc/openvpn/client/ca.crt >>/etc/openvpn/client/client.ovpn
echo "</ca>" >>/etc/openvpn/client/client.ovpn

echo "<cert>" >>/etc/openvpn/client/client.ovpn
cat /etc/openvpn/client/client1.crt >>/etc/openvpn/client/client.ovpn
echo "</cert>" >>/etc/openvpn/client/client.ovpn

echo "<key>" >>/etc/openvpn/client/client.ovpn
cat /etc/openvpn/client/client1.key >>/etc/openvpn/client/client.ovpn
echo "</key>" >>/etc/openvpn/client/client.ovpn

echo "key-direction 1" >>/etc/openvpn/client/client.ovpn

echo "<tls-auth>" >>/etc/openvpn/client/client.ovpn
cat /etc/openvpn/client/ta.key >>/etc/openvpn/client/client.ovpn
echo "</tls-auth>" >>/etc/openvpn/client/client.ovpn
