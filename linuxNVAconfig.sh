# These actions will be run at provisioning time
# Most of these commands are ephemeral, so you will probably have to rerun them if you reboot the VM

# Enable IP forwarding
sudo -i sysctl -w net.ipv4.ip_forward=1

# Install Quagga
sudo apt-get install quagga -y
sudo touch /etc/quagga/zebra.conf
sudo touch /etc/quagga/bgpd.conf

sudo chown quagga.quagga /etc/quagga/zebra.conf
sudo echo "password $1" >> /etc/quagga/zebra.conf
sudo chmod 640 /etc/quagga/zebra.conf
sudo systemctl enable quagga
sudo systemctl restart quagga
