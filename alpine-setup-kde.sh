#replace these with yours
USERNAME=alex
PASSWORD=pass
 
apk update && apk upgrade 
 
#install xorg and drivers
setup-xorg-base $(apk search --quiet --exact xf86-video* | grep -v -- '\-doc$')
 
#install KDE desktop
apk add desktop-file-utils dbus sddm udev sudo
apk add $(apk search plasma -q | grep -v '\-dev' | grep -v '\-lang' | grep -v '\-doc')
apk add konsole dolphin dolphin-plugins okular kwrite ark kwalletmanager
apk add kde-applications-base kde-applications-admin kde-applications-network kde-applications-utils kde-applications-accessibility kde-applications-graphics
apk add kde-applications-base kde-applications-admin kde-applications-accessibility kde-applications-graphics kde-applications-utils kde-applications-network kde-applications-multimedia
#apk add kde-applications-pim kde-applications-webdev kde-applications-games


#configure some services to start at boot
rc-update add sddm
rc-update add dbus
rc-update add udev
 
#create the restricted user
adduser $USERNAME -D && echo $USERNAME:$PASSWORD | chpasswd
adduser $USERNAME audio
adduser $USERNAME video
adduser $USERNAME dialout
 
#optionally add sudo support to this user
echo "$USERNAME ALL=(ALL:ALL) ALL" >> /etc/sudoers
 
#install X11 addons for D-BUS then start the service
apk add dbus-x11
rc-service dbus start
 
#install additional TTF fonts. ttf-opensans and ttf-google-opensans will try to overwrite eachother, not a big deal but you might want to choose between one of them. 
apk add $(apk search -q ttf- | grep -v '\-doc')
 
#start some services
rc-service udev start
#rc-service sddm start
 
#install Network Manager
apk add networkmanager networkmanager-openrc network-manager-applet wpa_supplicant
adduser $USERNAME dialout
adduser $USERNAME plugdev
rc-update add networkmanager
rc-update add wpa_supplicant default
 
truncate -s0 /etc/network/interfaces
echo 'auto lo' >> /etc/network/interfaces
echo 'iface lo inet loopback' >> /etc/network/interfaces

# - wpa supplicant conflicts with NM so we clear this file
truncate -s0 /etc/wpa_supplicant/wpa_supplicant.conf

# - uncomment these lines if you want to stop randomizing your wifi MAC.
#echo '[device]' >> /etc/NetworkManager/NetworkManager.conf
#echo 'wifi.scan-rand-mac-address=no' >> /etc/NetworkManager/NetworkManager.conf

 
#install and configure sound
apk add alsa-utils alsa-utils-doc alsa-lib alsaconf
adduser root audio
rc-service alsa start
rc-update add alsa
amixer -c 0 set 'Master' playback 0% mute
amixer -c 0 set 'Master' playback 100% unmute
amixer -c 0 set 'PCM' playback 0% mute
amixer -c 0 set 'PCM' playback 100% unmute
alsactl store
 
apk add pulseaudio pulseaudio-alsa alsa-plugins-pulse
chmod +x /etc/init.d/pulseaudio
rc-update add pulseaudio
 
echo "REBOOT THE MACHINE!"
