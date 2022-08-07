## A test script for OpenWrt
**DO NOT RUN ON A DEVICE IN SERVICE OR A DEVICE WHERE YOU CARE ABOUT THE CURRENT CONFIG**

To run the script.  Do a fresh install on the router, or reset to the factor defaults  with the firstboot command.  Connect the wan port to the internet and your laptop to the lan port.  SSH to the router.
The following commands will download and run the script.

> wget https://raw.githubusercontent.com/jedboywonder/tyrekick/main/tyrekick.sh  
chmod +x tyrekick.sh  
./tyrekick.sh -y  

## Key Facts
This is a script to perform tests on a fresh OpenWrt install; it assumes standard image like rc#  or formal release for current config.  
A snapshot or a already modified device may not work well.  
It assumes some things like eth0 exists radio names like radio0 radio1, etc.  
It is not intended for device in use, config will get stomped.  
You may want to change the country code or some other settings within the script.  


## FAQ
### How long should it take to run the script?  
The small test uses a short delay between wireless tests and runs in about 5-12 minutes.
The medium test uses a longer dealy between wireless tests and tests more wireless configurations.  It takes about 130 minutes to run.

### How do DFS Channels and the time delay work?  
If you run the medium test suite (-s medium) then DFS channels are included.  They take a minute or more to start and their is a delay to accomodate that.  You can adjust the delay (in seconds)  with the -d parameter.  If it is too short DFS channel tests may not pass.

### How do you run only specific tests?  
You would need to edit the script.  Comment out lines near the bottom of the script.  For example, change test_ntp to #test_ntp.

### Can you run the script without an internet connection?  
Yes, but any internet dependent tests will fail.

### What should I do when I'm done testing?  
Reset the device to factor defaults before configuring for other uses.

### How do you run in the background if you don't want to stay connected?  
>(/root/tyrekick.sh -y >/dev/null 2>&1 )&

### What about devices with only one network port?  
Devices sold as extenders may only have 1 physical network port.  An example is the Netgear EX6120.  For these devices a default OpenWrt config sets the port to the br-lan device.  
You can run the script without internet access, but can add internet functionality with a few changes.  Here is one way to do it.  
a) Using a different router with internet access (router 2) set the lan IP of router 2 to 192.168.1.2.  Router 2 should have multiple physical lan ports.  
b) Connect your laptop directly to the device under test (router 1).  
c) Configure dhcp to turn on when rebooted.  Not strictly needed since you can always do a factor reset to gain access.  Or, access the router by setting a static IP (e.g. 192.168.1.99) on your laptop.  
Use the following commands:  
> cat << EOF > /etc/rc.local  
uci set dhcp.lan.ignore='0'  
exit 0  
EOF  

d) on router 1, turn off dhcp  
Use the following commands:  
> uci set dhcp.lan.ignore='1'  
uci commit dhcp  
/etc/init.d/dnsmasq restart  

e) add a temporary route to send internet traffic to router 2  
Use the following command:  
> ip route add 0.0.0.0/0 via 192.168.1.2 dev br-lan  

f) configure a DNS name server  
> echo nameserver 1.1.1.1 > /tmp/resolv.conf  

g) now connect your laptop to a router 2 lan port and connect router 1 to a router 2 laptop  
h) SSH to router 1 (192.168.1.1) from your laptop and run the test  
i) Unplug the router 1 network cable before rebooting it since it will start an additional dhcp server on router 2's lan.  
