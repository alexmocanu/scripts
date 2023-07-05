# replace these with your desired credentials
USERNAME=alex
PASSWORD=pass

# update packages
apk update && apk upgrade 

# Create user account as admin (Add to wheel group and set up doas)
setup-user -a $USERNAME

# Set user password
echo $USERNAME:$PASSWORD | chpasswd

# Enable sudo support:
# Add sudo package, Enable sudo for members of wheel and sudo groups
apk add sudo
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/wheel
echo '%sudo ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/sudo

# Install desktop
setup-desktop xfce

# Install shadow package (for user utils)
apk add shadow

# Setup some groups needed by our new user account
adduser $USERNAME audio # access to audio devices (the soundcard or a microphone).
adduser $USERNAME video # access to video devices (webcams for example)
adduser $USERNAME netdev # manage network interfaces through the network manager and wicd.

# Install networkmanager and wpa_supplicant
apk add networkmanager networkmanager-openrc networkmanager-tui networkmanager-wifi wpa_supplicant network-manager-applet
rc-update add networkmanager
rc-update add wpa_supplicant default

# Setup some more groups 
adduser $USERNAME dialout # ... 
adduser $USERNAME plugdev # allow mount removable devices

# Reset the networks configuration file leaving only the loopback interface. Network manager won't touch any interface configured here and they will appear as unmanaged.
truncate -s0 /etc/network/interfaces
echo 'auto lo' >> /etc/network/interfaces
echo 'iface lo inet loopback' >> /etc/network/interfaces

# Truncate the wpa supplicant configuration for the same reason. NM uses wpa_supplicant but any interface in this conf. file will be ignored 
truncate -s0 /etc/wpa_supplicant/wpa_supplicant.conf

# Install Samba
apk add samba
rc-update add samba

# Configure Samba to accept user shares (allow sharing directories without messing around with the smb.conf file)

export USERSHARES_DIR="/var/lib/samba/usershares"
export USERSHARES_GROUP="sambashare"
mkdir -p ${USERSHARES_DIR}
groupadd ${USERSHARES_GROUP}
chown root:${USERSHARES_GROUP} ${USERSHARES_DIR}
chmod 01770 ${USERSHARES_DIR}

# Backup the old smb.conf file
mv /etc/samba/smb.conf /etc/samba/smb.conf_old
cp basic_samba_config.conf /etc/samba/smb.conf

# Add our user acount to the sambashare group - enables samba user shares
usermod -a -G ${USERSHARES_GROUP} ${USERNAME}

# Creates a Samba user and sets it's password. We use the same username and password as our regular user for convenience.
# Please note that Samba users and passwords are not synced with the system. Changing the samba password is done separately with the smbpasswd command
(echo "$PASSWORD"; echo "$PASSWORD") | smbpasswd -s -a "$USERNAME"

# Install the cups server for printing support and enable thge cups service
apk add cups cups-libs cups-client cups-filters
# apk add cups-pdf hplip # The cups-pdf and hplip packages are available only in the testing repository. You might have to enable it or set it up with the @testing tag and install these packages as explained here: https://wiki.alpinelinux.org/wiki/Repositories
rc-update add cupsd boot

#fix error: Failed to group devices: 'The name org.fedoraproject.Config.Printing was not provided by any .service files' when trying to add a new printer from KDE
apk add system-config-printer 

#Set up groups membership to enable printing
adduser root lp
adduser root lpadmin
adduser $USERNAME lp
adduser $USERNAME lpadmin

#additional stuff for thunar: gvfs plugins, fuse, ntfs, etc.
apk add $(apk search --quiet --exact gvfs* | grep -v -- '\-doc$' | grep -v '\-dev')
apk add fuse udisks2 fuse-openrc ntfs-3g
rc-update add fuse

#bluetooth support - untested
#apk add bluez bluez-alsa-openrc bluez-libs bluez-obexd bluez-openrc bluez-firmware bluez-btmon bluez-hid2hci bluez-btmgmt bluez-cups bluez-plugins bluez-meshctl bluez-alsa
#apk add blueman networkmanager-bluetooth
#rc-update add bluetooth
#rc-service bluetooth start
