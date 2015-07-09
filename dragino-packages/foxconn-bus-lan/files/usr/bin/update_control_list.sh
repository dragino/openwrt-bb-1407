#!/bin/sh

HAS_INTERNET=0
REDIRECT_IP=`uci get network.lan.ipaddr`
REDIRECT_LIST=`grep 'redirect=' /etc/wifishare/access_control_list.conf | grep -v '#redirect' | awk -F '=' '{print $2}'`
BLOCKIP_LIST=`grep 'block=' /etc/wifishare/access_control_list.conf | grep -v '#block' | awk -F '=' '{print $2}'`
ALLOWIP_LIST=`grep 'allowip=' /etc/wifishare/access_control_list.conf | grep -v '#allowip' | awk -F '=' '{print $2}'`
MEDIA_SERVER=`uci get nodogsplash.settings.media_server_domain`

#check if there is internet connection and store it.
if [ -z `grep 'address=/#/' /etc/dnsmasq.conf` ];then
	HAS_INTERNET=1
fi


#clean current rules: Domain Direct, Black IP List and White IP List
#clean current domain list
sed '/address=/d' /etc/dnsmasq.conf -i
#clean black list
uci delete nodogsplash.authenticated_users.FirewallRule
#clean White IP list
uci delete nodogsplash.preauthenticated_users.FirewallRule

add_default_authenticated_users_access_rule() {
	uci add_list nodogsplash.authenticated_users.FirewallRule="allow tcp port 80"
	uci add_list nodogsplash.authenticated_users.FirewallRule='allow tcp port 22'
	uci add_list nodogsplash.authenticated_users.FirewallRule='allow tcp port 53'
	uci add_list nodogsplash.authenticated_users.FirewallRule='allow udp port 53'
	uci add_list nodogsplash.authenticated_users.FirewallRule='allow tcp port 443'
	uci add_list nodogsplash.authenticated_users.FirewallRule='allow to 192.168.1.1/32'
}

add_default_preauthenticated_users_access_rule() {
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow tcp port 53'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow udp port 53'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow tcp port 6024'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 8.8.8.8/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 192.168.1.1/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 210.83.234.59/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 121.14.39.93/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 58.249.116.221/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 58.249.116.213/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 121.14.39.85/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 112.91.29.133/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 112.91.29.145/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 112.91.29.134/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 120.198.232.228/32'
	uci add_list nodogsplash.preauthenticated_users.FirewallRule='allow to 120.198.232.60/32'
}

echo address=/$MEDIA_SERVER/$REDIRECT_IP >> /etc/dnsmasq.conf

####### Set Up Black List for Authenticated_users #####
###########################
## Black List #############
###########################
### Redirect Domain ###
for domain in `echo $REDIRECT_LIST` ; do
	echo address=/$domain/$REDIRECT_IP >> /etc/dnsmasq.conf
done

#NTP Server 
echo address=/0.openwrt.pool.ntp.org/202.112.10.36 >> /etc/dnsmasq.conf
echo address=/1.openwrt.pool.ntp.org/202.118.1.130 >> /etc/dnsmasq.conf
echo address=/2.openwrt.pool.ntp.org/202.118.1.130 >> /etc/dnsmasq.conf

#Auto Update Server
echo address=/www.dragino.com/173.254.28.23 >> /etc/dnsmasq.conf

#If there is no internet access, we redirect all domains. 
if [ $HAS_INTERNET -eq 0 ];then
	echo address=/#/$REDIRECT_IP >> /etc/dnsmasq.conf
fi
	
### Block IPs ###
for block_ip in `echo $BLOCKIP_LIST` ;do 
#rules first add will have higher priority 
	uci add_list nodogsplash.authenticated_users.FirewallRule="block to $block_ip"
done
add_default_authenticated_users_access_rule




####### Set Up White List For Preauthenticated Users#####
###########################
## White List ##
###########################
### WhiteList IP ###
add_default_preauthenticated_users_access_rule

### Whitelist IPs ###
for allow_ip in `echo $ALLOWIP_LIST` ;do 
#rules first add will have higher priority 
	uci add_list nodogsplash.preauthenticated_users.FirewallRule="allow to $allow_ip"
	uci add_list nodogsplash.authenticated_users.FirewallRule="allow to $allow_ip"
done


####### restart nodogsplah and dnsmasq #####
uci commit nodogsplash

/etc/init.d/dnsmasq	restart
/etc/init.d/ucidog reload

