# These actions will be run at provisioning time
# Most of these commands are ephemeral, so you will probably have to rerun them if you reboot the VM

# Enable IP forwarding
sudo -i sysctl -w net.ipv4.ip_forward=1

# Install Quagga
sudo apt-get install quagga -y
# Option 1: Empty files
# sudo touch /etc/quagga/zebra.conf
# sudo touch /etc/quagga/bgpd.conf
# sudo chown quagga.quagga /etc/quagga/zebra.conf
# sudo chown quagga.quagga /etc/quagga/bgpd.conf
# sudo chmod 640 /etc/quagga/zebra.conf
# sudo chmod 640 /etc/quagga/bgpd.conf
# sudo systemctl enable quagga
# sudo systemctl restart quagga
# sudo systemctl enable bgpd
# sudo systemctl restart bgpd

# Option 2: Sample files
sudo cp /usr/share/doc/quagga/examples/zebra.conf.sample /etc/quagga/zebra.conf
sudo cp /usr/share/doc/quagga/examples/bgpd.conf.sample /etc/quagga/bgpd.conf
# sudo systemctl enable zebra
# sudo systemctl start zebra
