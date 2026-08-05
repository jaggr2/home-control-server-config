echo "127.0.0.1 derog-hc" | sudo tee -a /etc/hosts
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
sudo systemctl restart dnsmasq
