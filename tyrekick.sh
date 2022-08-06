Skip to content
Search or jump to…
Pull requests
Issues
Marketplace
Explore
 
@jedboywonder 
jedboywonder
/
bft
Public
Code
Issues
Pull requests
Actions
Projects
Wiki
Security
Insights
Settings
bft/bft.sh
@jedboywonder
jedboywonder Update bft.sh
Latest commit b13a9e4 10 days ago
 History
 1 contributor
671 lines (608 sloc)  19.6 KB

#!/bin/sh
# DO NOT RUN ON A DEVICE IN SERVICE OR A DEVICE WHERE YOU CARE ABOUT THE CURRENT CONFIG
#
# Big Friendly Test (bft)
# this is a proof of concept and may lack the desired robustness
#
# this is a script to perform tests on a fresh OpenWrt install
# assumes standard image like rc#  or formal release for current config.
# snapshot or a already modified device may not work well
# assumes some things like eth0 exists radio names like radio0 radio1, etc
# not intended for device in use, config will get stomped
# you may want to change the country code or some other settings

help_menu() {
  echo "Usage:
  ${0##*/} [-h] [-s medium]
Options:
  -h, --help
    display this help and exit
  -s size
    small or medium
  -d delay in seconds for radio before moving to next config
Examples:
Show help:
   ${0##*/} -h
Run default:
   ${0##*/}
Run small size
   ${0##*/} -s small
Run medium size
   ${0##*/} -s medium -d 120
  "
}

TSIZE="small"
# parse args
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h) help_menu; exit 0;;
    -s) TSIZE="$2"; shift 2;;
    -d) TDELAY="$2"; shift 2;;
    -*) echo "unknown option: $1" >&2; exit 1;;
    *) handle_argument "$1"; shift 1;;
  esac
done

echo the size is $TSIZE
if [[ "$TSIZE" != "small" && "$TSIZE" != "medium" ]] ; then
   echo "invalid size, only small and medium allowed"
   exit 1
else
   echo  the size is valid, $TSIZE
fi

SLEEPX=1
# SLEEPNO below 140 may not be enouch time for DFS channels to come up, ymmv
SLEEPNO=160
# for small size shorten SLEEPNO to run faster
if [[ "$TSIZE" == "small" ]];then
   SLEEPNO=10
fi
if [[ -n "${TDELAY}" ]]; then
  SLEEPNO=${TDELAY}
fi
#echo TDELAY $TDELAY
#echo sleepno $SLEEPNO

RUNID=$(date  '+%Y-%m-%d-%H-%M-%S')
OUTDIR="/tmp/bft-$RUNID"
mkdir $OUTDIR

cp /proc/cpuinfo $OUTDIR/
cp /proc/meminfo $OUTDIR/
cp /etc/openwrt_release $OUTDIR/
cp /etc/os-release $OUTDIR/
iw list > $OUTDIR/iwlist.out
ifconfig > $OUTDIR/ifconfig.out

MODEL="$(cat /proc/cpuinfo | grep machine | head -n 1 | awk -F: '{ print $2}' | sed 's/ //' | sed 's/ /-/g')"
MACRAW="$(cat /sys/class/net/eth0/address  | sed 's/://g')"
OUI="$(echo "${MACRAW}" | cut -c1-6)"

RELVAL="$(cat /etc/openwrt_release | grep DISTRIB_RELEASE | awk -F= '{ print $2 }' | sed "s/'//g")"
OUTLOG=$OUTDIR/bft-${MODEL}-${RELVAL}-${RUNID}.log
DATA=$OUTDIR/bft-${MODEL}-${RELVAL}-${RUNID}.csv

echo "model,OUI,testID,result" > $DATA

echo Running Test on model:${MODEL} with eth0 MAC of ${MACRAW} and log file of $OUTLOG | tee -a  $OUTLOG
cat /etc/openwrt_release | grep DISTRIB_RELEASE >> $OUTLOG
cat /etc/openwrt_release | grep DISTRIB_TARGET  >> $OUTLOG

WIFIKEY="$(cat /proc/sys/kernel/random/uuid | sed 's/[-]//g' | head -c 12 )"
echo Key for WIFI test is:  ${WIFIKEY} | tee -a $OUTLOG

test_init() {
logread > $OUTDIR/logread-initial
echo "init "| tee -a  $OUTLOG
    uci set system.@system[0].log_size='512'
return 0
}

test_opkg() {
echo "test opkg " | tee -a  $OUTLOG
opkg update
opkg install unzip
UNZIPH="$(unzip -h | grep UnZip | head -n 1)"
if [[ -n "$UNZIPH" ]]
then
   RESULT=pass
else
   RESULT=fail
fi

echo "$MODEL,$OUI,opkg-unzip-000001,$RESULT"
echo "$MODEL,$OUI,opkg-unzip-000001,$RESULT" >> $DATA

return 0
}

test_extraoptions() {
echo "test wireless extra options  " | tee -a  $OUTLOG

for radio in 'radio0' 'radio1' 'radio2' 'radio3'
do
  echo "check for $radio"  | tee -a $OUTLOG
  TRADIO="$(uci -q get wireless."$radio")"
  #echo TRADIO = $TRADIO
  if [ "$TRADIO" == "wifi-device" ]
  then
    echo testing $radio | tee -a $OUTLOG
    uci -q set wireless.${radio}.disabled='0'
    BAND="$(uci get wireless.$radio.band)"
    #echo BAND $BAND
tencr="psk2"

# 2g  ----------------------------------------------------------
    if [ "$BAND" == "2g" ]
    then
    tchan=11
    tpow=10
    uci -q set wireless.test_${radio}.txpower="$tpow"
    uci -q set wireless.test_${radio}.encryption="${tencr}"
    uci -q set wireless.${radio}.channel="$tchan"
    uci -q set wireless.default_${radio}.disabled='1'
    uci -q set wireless.test_${radio}=wifi-iface
    uci -q set wireless.test_${radio}.device="$radio"
    uci -q set wireless.test_${radio}.mode="ap"
    uci -q set wireless.test_${radio}.network="lan"
    uci -q set wireless.test_${radio}.key="${WIFIKEY}"
    uci -q set wireless.test_${radio}.disabled='0'
uci -q del wireless.${radio}.disabled
uci -q set wireless.test_${radio}.ssid='${radio}-max2'
uci -q set wireless.test_${radio}.ieee80211r='1'
uci -q set wireless.test_${radio}.mobility_domain='BEEF'
uci -q set wireless.test_${radio}.reassociation_deadline='55555'
uci -q set wireless.test_${radio}.ft_over_ds='0'
uci -q set wireless.test_${radio}.ft_psk_generate_local='0'
uci -q set wireless.test_${radio}.r0_key_lifetime='4444'
uci -q set wireless.test_${radio}.r1_key_holder='ACEED00CEE77'
uci -q set wireless.test_${radio}.pmk_r1_push='1'
uci -q set wireless.test_${radio}.ieee80211w='1'
uci -q set wireless.test_${radio}.ieee80211w_max_timeout='456'
uci -q set wireless.test_${radio}.ieee80211w_retry_timeout='123'
uci -q set wireless.${radio}.cell_density='0'
    uci -q set wireless.test_${radio}.ssid="--EX-${radio}-${BAND}-${tchan}-${tpow}-${tencr}"
    echo ${radio}-${BAND}-${tchan}-${tpow}-${tencr}  | tee -a $OUTLOG

# 5g  ---------------------------------------------------------
    elif [ "$BAND" == "5g" ]; then
    tchan=36
    tpow=10
    tencr="psk2+ccmp"
    uci set wireless.${radio}.country='US'
    #uci set wireless.${radio}.htmode='VHT20'
    uci -q set wireless.test_${radio}.txpower="$tpow"
    uci -q set wireless.${radio}.channel="$tchan"
    uci -q set wireless.default_${radio}.disabled='1'
    uci -q set wireless.test_${radio}=wifi-iface
    uci -q set wireless.test_${radio}.device="$radio"
    uci -q set wireless.test_${radio}.mode="ap"
    uci -q set wireless.test_${radio}.network="lan"
    uci -q set wireless.test_${radio}.key="${WIFIKEY}"
    uci -q set wireless.test_${radio}.disabled='0'
uci -q set wireless.test_${radio}.encryption="${tencr}"
uci -q set wireless.test_${radio}.macfilter='deny'
uci -q add_list wireless.test_${radio}.maclist='FA:1F:D0:6C:A7:AE'
uci -q set wireless.test_${radio}.isolate='1'
uci -q set wireless.test_${radio}.short_preamble='0'
uci -q set wireless.test_${radio}.wpa_group_rekey='300'
uci -q set wireless.test_${radio}.skip_inactivity_poll='1'
uci -q set wireless.test_${radio}.max_inactivity='600'
uci -q set wireless.test_${radio}.max_listen_interval='32768'
uci -q set wireless.test_${radio}.disassoc_low_ack='0'
uci -q set wireless.test_${radio}.wpa_disable_eapol_key_retries='1'
uci -q set wireless.${radio}.htmode='VHT80'
uci -q set wireless.${radio}.cell_density='0'
uci -q set wireless.${radio}.frag='256'
uci -q set wireless.${radio}.rts='100'
uci -q set wireless.${radio}.beacon_int='50'

    uci -q set wireless.test_${radio}.ssid="--EX-${radio}-${BAND}-${tchan}-${tpow}-${tencr}"
    echo ${radio}-${BAND}-${tchan}-${tpow}-${tencr}  | tee -a $OUTLOG

    else
      echo unknown band  | tee -a $OUTLOG
    fi
# make sure no old message are included in success check
logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn
logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn
logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn

         uci commit wireless
         wifi reload
         let SLEEPTIME=SLEEPX*SLEEPNO
         sleep $SLEEPTIME
         #check test result
         WRESFAIL="$(logread | tail -n 10 | grep netifd | grep Wireless | grep ${radio} | grep fail | head -n 1)"
         #echo FAIL GREP $WRESFAIL
         WRESPASS="$(logread | tail -n 10 | grep netifd | grep Wireless | grep 'is now up'  | head -n 1)"
         #echo PASS GREP $WRESPASS
         if [ -n "$WRESFAIL" ]
         then
         RESULT=fail
         elif [ -n "$WRESPASS" ]
         then
         RESULT=pass
         else
         RESULT=unknown
         fi
         echo "$MODEL,$OUI,wireless-extra-options-${radio}-${BAND}-${tchan}-${tpow}-${tencr},$RESULT"
         echo "$MODEL,$OUI,wireless-extra-options-${radio}-${BAND}-${tchan}-${tpow}-${tencr},$RESULT" >> $DATA

    uci -q set wireless.test_${radio}.disabled='1'

  else
    echo ${radio} does not exist skip  | tee -a $OUTLOG
  fi

  #echo "tradio $TRADIO"

done
uci commit wireless
wifi down
wifi up

return 0
}

test_allradioon() {
echo "test all radios on  " | tee -a  $OUTLOG

RADIOCOUNT=0
for radio in 'radio0' 'radio1' 'radio2' 'radio3'
do
  echo "check for $radio"  | tee -a $OUTLOG
  TRADIO="$(uci -q get wireless."$radio")"
  #echo TRADIO = $TRADIO
  if [ "$TRADIO" == "wifi-device" ]
  then
    let "RADIOCOUNT+=1"
    echo testing $radio | tee -a $OUTLOG
    uci -q set wireless.${radio}.disabled='0'
    BAND="$(uci get wireless.$radio.band)"
    #echo BAND $BAND
# 2g  ----------------------------------------------------------
    if [ "$BAND" == "2g" ]
    then
    tchan=1
    tpow=20
# 5g  ---------------------------------------------------------
    elif [ "$BAND" == "5g" ]; then
    tchan=36
    tpow=20
    uci set wireless.${radio}.country='US'
    uci set wireless.${radio}.htmode='VHT20'
    else
      echo unknown band  | tee -a $OUTLOG
    fi
# set encryption values
tencr="psk2"
    uci -q set wireless.${radio}.channel="$tchan"
    uci -q set wireless.default_${radio}.disabled='1'
    uci -q set wireless.test_${radio}=wifi-iface
    uci -q set wireless.test_${radio}.device="$radio"
    uci -q set wireless.test_${radio}.mode="ap"
    uci -q set wireless.test_${radio}.network="lan"
    uci -q set wireless.test_${radio}.key="${WIFIKEY}"
    uci -q set wireless.test_${radio}.disabled='0'
    uci -q set wireless.test_${radio}.txpower="$tpow"
    uci -q set wireless.test_${radio}.encryption="${tencr}"
    uci -q set wireless.test_${radio}.ssid="--AR-${radio}-${BAND}-${tchan}-${tpow}-${tencr}"
         echo ${radio}-${BAND}-${tchan}-${tpow}-${tencr}  | tee -a $OUTLOG

  else
    echo ${radio} does not exist skip  | tee -a $OUTLOG
  fi
done
echo RADIOCOUNT  $RADIOCOUNT

# make sure no old message are included in success check
logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn
logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn
logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn

         uci commit wireless
         wifi reload
         let SLEEPTIME=SLEEPX*SLEEPNO
         sleep $SLEEPTIME
         #check test result
         WRESFAIL="$(logread | tail -n 10 | grep netifd | grep Wireless | grep radio | grep fail | head -n 1)"
         #echo FAIL GREP $WRESFAIL
         WRESPASS="$(logread | tail -n 10 | grep netifd | grep Wireless | grep radio | grep 'is now up'  | wc -l )"
         #echo PASS GREP $WRESPASS
         if [ -n "$WRESFAIL" ]
         then
         RESULT=fail
         elif [ "${RADIOCOUNT}" -eq "${WRESPASS}" ]
         then
         RESULT=pass
         else
         RESULT=unknown
         fi
         echo "$MODEL,$OUI,all-radio-on-000001,$RESULT"
         echo "$MODEL,$OUI,all-radio-on-000001,$RESULT" >> $DATA

#disable radios
for radio in 'radio0' 'radio1' 'radio2' 'radio3'
do
  echo "check for $radio"  | tee -a $OUTLOG
  TRADIO="$(uci -q get wireless."$radio")"
  if [ "$TRADIO" == "wifi-device" ]
  then
    echo disable test_ ${radio} | tee -a $OUTLOG
    uci -q set wireless.test_${radio}.disabled='1'
  fi
done
uci commit wireless
wifi down
wifi up

return 0
}

test_inet(){
echo "test for internet connectivty" | tee -a  $OUTLOG
wget --quiet -O /tmp/ffdetect http://detectportal.firefox.com
wget --quiet -O /tmp/httpbinip http://httpbin.org/ip
wget --quiet -O /tmp/apple http://www.apple.com/library/test/success.html
wget --quiet -O /tmp/ncsi http://www.msftncsi.com/ncsi.txt
T1="$(cat /tmp/httpbinip | grep origin | head -n 1 )"
T2="$(cat /tmp/ffdetect | grep success | head -n 1 )"
T3="$(cat /tmp/ncsi     | grep NCSI  | head -n 1 )"
T4="$(cat /tmp/apple    | grep Success | head -n 1 )"

if [[ -n "$T1" && -n "$T2" &&  -n "$T3" && -n "$T4" ]]
then
   RESULT=pass
else
   RESULT=fail
fi

echo "$MODEL,$OUI,inet-dns-000001,$RESULT"
echo "$MODEL,$OUI,inet-dns-000001,$RESULT" >> $DATA
return 0
}

test_http(){
echo "test http"| tee -a  $OUTLOG
rm -f /www2/*
rmdir /www2
mkdir /www2
HCREATE=$(date  '+%Y-%m-%d-%H-%M-%S')
cat << ENDHERE >> /www2/index.html
<html>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Expires" content="0" />
<header>
<title>BFT HTML TEST FILE TESTHTTP</title>
</header>
<body>
<h3>BFT HTML TEST FILE FOR RUNID:${RUNID} <BR>FILE CREATED: $(date  '+%Y-%m-%d-%H-%M-%S')</html>
</body></html>
ENDHERE

UHTTPID=$(uci add uhttpd uhttpd)
#echo UHTTPID=$UHTTPID
uci rename uhttpd.@uhttpd[-1]=www2
uci add_list uhttpd.@uhttpd[-1].listen_http=0.0.0.0:8080
uci set uhttpd.@uhttpd[-1].home=/www2
uci set uhttpd.@uhttpd[-1].rfc1918_filter=1
uci set uhttpd.@uhttpd[-1].max_requests=3
uci set uhttpd.@uhttpd[-1].max_connections=100
uci set uhttpd.@uhttpd[-1].script_timeout=60
uci set uhttpd.@uhttpd[-1].http_keepalive=20
uci set uhttpd.@uhttpd[-1].network_timeout=30
uci set uhttpd.@uhttpd[-1].tcp_keepalive=1
uci commit uhttpd
/etc/init.d/uhttpd restart

# check pass / fail
PORTLISTEN="$(netstat -nap | grep 8080 | grep uhttpd | grep LISTEN)"
#echo PORTLISTEN $PORTLISTEN
wget http://0.0.0.0:8080/index.html -O ${OUTDIR}/index.html
HGET="$(grep TESTHTTP ${OUTDIR}/index.html | head -n 1)"
#echo HGET $HGET

if [[ -n "$PORTLISTEN" && -n "$HGET" ]]
then
   RESULT=pass
else
   RESULT=fail
fi

echo "$MODEL,$OUI,uhttpd-000001,$RESULT"
echo "$MODEL,$OUI,uhttpd-000001,$RESULT" >> $DATA

# TEST FW
nft list ruleset > $OUTDIR/nft-ruleset.txt
LIP=192.168.1.1
echo "Check luci http://${LIP}/cgi-bin/luci/  should work"
echo "Check web page without FW http://${LIP}:8080  should work"
echo "waiting a bit"
sleep 10
echo "blocking inbound dest port 8080" | tee -a  $OUTLOG
RULE1=$(uci add firewall rule)
#echo RULE1 $RULE1
uci set firewall.@rule[-1].name='BLOCK PORT 8080'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='8080'
uci set firewall.@rule[-1].target='REJECT'
uci set firewall.@rule[-1].enabled='1'
uci commit firewall
service firewall restart
echo "Check luci http://${LIP}/cgi-bin/luci/  should work"
echo "Check web page without FW http://${LIP}:8080  should FAIL"
echo "waiting a bit"
sleep  10
if [[ -d "/etc/nftables.d" ]]
then
  echo "seems to be nftables" | tee -a  $OUTLOG
  RULENFT="$(nft list ruleset | grep 8080 | head -n 1)"
  if [ -n "$RULENFT" ]
  then
    RESULT=pass
  else
    RESULT=fail
  fi
    echo "$MODEL,$OUI,firewall-fw4-test-000001,$RESULT"
    echo "$MODEL,$OUI,firewall-fw4-test-000001,$RESULT" >> $DATA

else
  echo "no nftables"| tee -a  $OUTLOG
fi
uci del firewall.${RULE1}
uci commit firewall
service firewall restart
echo "Check luci http://${LIP}/cgi-bin/luci/  should work"
echo "Check web page without FW http://${LIP}:8080  should work"
echo "waiting a bit"
sleep 10
uci del uhttpd.www2
uci commit uhttpd
service uhttpd restart
return 0
}

test_ntp() {
echo "ntp" | tee -a  $OUTLOG
# don't need ntpd service for test
killall ntpd
#run as background so can kill it
#ntpd -w -p 0.openwrt.pool.ntp.org -p 1.openwrt.pool.ntp.org
NTPQRES="$(ntpd -w -p 0.openwrt.pool.ntp.org -p 1.openwrt.pool.ntp.org &> $OUTDIR/ntpd.out &)"
sleep 6
killall ntpd
NTPDRES="$(cat $OUTDIR/ntpd.out | grep ntpd | grep reply | head -n 1)"
#echo $NTPDRES
if [ -z "$NTPDRES" ]
then
  RESULT=fail
else
  RESULT=pass
fi
echo "$MODEL,$OUI,ntp-000001,$RESULT" >> $DATA
echo "$MODEL,$OUI,ntp-000001,$RESULT"
killall ntpd
return 0
}

test_wireless() {
echo "wireless" | tee -a $OUTLOG
for radio in 'radio0' 'radio1' 'radio2' 'radio3'
do
  echo "check for $radio"  | tee -a $OUTLOG
  TRADIO="$(uci -q get wireless."$radio")"
  #echo TRADIO = $TRADIO
  if [ "$TRADIO" == "wifi-device" ]
  then
    echo testing $radio | tee -a $OUTLOG
    uci -q set wireless.${radio}.disabled='0'
    BAND="$(uci get wireless.$radio.band)"
    #echo BAND $BAND
# 2g  ----------------------------------------------------------
    if [ "$BAND" == "2g" ]
    then
        #assign channels and txpower values
# set based on test size
if [ "$TSIZE" == "medium" ]; then
CHANNELS=" \
1 \
6 \
11 \
"
TXPOWERS=" \
10 \
1 \
"
elif [ "$TSIZE" == "small" ]; then
CHANNELS=" \
6 \
"
TXPOWERS=" \
10 \
"
else
CHANNELS=" \
6 \
"
TXPOWERS=" \
10 \
"
fi
# 5g  ---------------------------------------------------------
    elif [ "$BAND" == "5g" ]; then
if [ "$TSIZE" == "medium" ]; then
CHANNELS=" \
36 \
100 \
149 \
165 \
"
TXPOWERS=" \
4 \
1 \
"
elif [ "$TSIZE" == "small" ]; then
CHANNELS=" \
36 \
"
TXPOWERS=" \
4 \
"
else
CHANNELS=" \
36 \
"
TXPOWERS=" \
4 \
"
fi
    uci set wireless.${radio}.country='US'
    uci set wireless.${radio}.htmode='VHT20'
    else
      echo unknown band  | tee -a $OUTLOG
    fi
# set encryption values
if [ "$TSIZE" == "medium" ]; then
ENCRS=" \
psk2 \
sae \
sae-mixed \
"
elif [ "$TSIZE" == "small" ]; then
ENCRS=" \
psk2 \
"
else
ENCRS=" \
psk2 \
"
fi

    uci -q set wireless.default_${radio}.disabled='1'
    uci -q set wireless.test_${radio}=wifi-iface
    uci -q set wireless.test_${radio}.device="$radio"
    uci -q set wireless.test_${radio}.mode="ap"
    uci -q set wireless.test_${radio}.network="lan"
    uci -q set wireless.test_${radio}.key="${WIFIKEY}"
    uci -q set wireless.test_${radio}.disabled='0'
      for channel in $CHANNELS
      do
      uci -q set wireless.${radio}.channel="${channel}"
        for TXPOWER in $TXPOWERS
        do
         for encr in $ENCRS
         do
         uci -q set wireless.test_${radio}.encryption="${encr}"
         uci -q set wireless.${radio}.txpower="${TXPOWER}"
         uci -q set wireless.test_${radio}.ssid="---${radio}-${BAND}-${channel}-${TXPOWER}-${encr}"
         echo ${radio}-${BAND}-${channel}-${TXPOWER}-${encr}  | tee -a $OUTLOG
# make sure no old message are included in success check
logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn
logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn
logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn; logger -p daemon.notice -t netifd dngn

         uci commit wireless
         wifi reload
         let SLEEPTIME=SLEEPX*SLEEPNO
         sleep $SLEEPTIME
         #check test result
         WRESFAIL="$(logread | tail -n 10 | grep netifd | grep Wireless | grep ${radio} | grep fail | head -n 1)"
         #echo FAIL GREP $WRESFAIL
         WRESPASS="$(logread | tail -n 10 | grep netifd | grep Wireless | grep 'is now up'  | head -n 1)"
         #echo PASS GREP $WRESPASS
         if [ -n "$WRESFAIL" ]
         then
         RESULT=fail
         elif [ -n "$WRESPASS" ]
         then
         RESULT=pass
         else
         RESULT=unknown
         fi
         echo "$MODEL,$OUI,${radio}-${BAND}-${channel}-${TXPOWER}-${encr},$RESULT"
         echo "$MODEL,$OUI,${radio}-${BAND}-${channel}-${TXPOWER}-${encr},$RESULT" >> $DATA

         done
      done
    done
    uci -q set wireless.test_${radio}.disabled='1'

  else
    echo ${radio} does not exist skip  | tee -a $OUTLOG
  fi

  #echo "tradio $TRADIO"

done
uci commit wireless
wifi down
wifi up
return 0
}

#  MAIN
test_init

echo start tests $(date  '+%Y-%m-%d-%H-%M-%S') | tee -a $OUTLOG
test_inet
test_ntp
test_http
test_opkg
test_allradioon
test_extraoptions
test_wireless
logread > $OUTDIR/logread-final
echo end tests $(date  '+%Y-%m-%d-%H-%M-%S') | tee -a $OUTLOG
echo see $OUTDIR for collected files and test results .csv
Footer
© 2022 GitHub, Inc.
Footer navigation
Terms
Privacy
Security
Status
Docs
Contact GitHub
Pricing
API
Training
Blog
About
