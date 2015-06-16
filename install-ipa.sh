#!/bin/bash
#
# Desc: Build IPA.
#
# Date: 2015-06-12
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL7

# Verbose output.
set -x
# Exit if anything fails
set -e
# Uncomment for no output.
#exec > /dev/null 2>&1

## Environment 
RETVAL=0

MYIP=172.16.105.162
MYNIC=eno16777736
MYDOMAIN=ams1.lastminute.com
MYHOSTNAME=server-eins
FQDN=$MYHOSTNAME.$MYDOMAIN
NAMESERVER=$MYIP
MYREALM=${MYDOMAIN~~}
PASSWORD=password

## Sanity checks

echo Disable firewall and SElinux
  if !( grep 'SELINUX=disabled' /etc/sysconfig/selinux ); then
    sed 's/SELINUX=[a-z]*/SELINUX=disabled/' /etc/sysconfig/selinux -i
    setenforce 0
  fi

  systemctl disable firewalld && systemctl stop firewalld && iptables -F

## Set IPv6 settings for IPA Samba AD trusts

cat << EOF > /etc/sysctl.d/ipv6.conf
# Disable IPv6 interface but leave stack up
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.${MYNIC}.disable_ipv6 = 1

EOF

sysctl -p

ifdown ${MYNIC}
ifup ${MYNIC}

## Check network and hostname

cat << EOF > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
$MYIP $FQDN $MYHOSTNAME

EOF

cat << EOF > /etc/resolv.conf
nameserver $NAMESERVER

EOF

cat << EOF > /etc/hostname
$FQDN

EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$MYNIC
NAME=$MYNIC
DEVICE=$MYNIC
ONBOOT=yes
NETBOOT=yes
IPV6INIT=yes
BOOTPROTO=static
IPADDR=$MYIP
PREFIX=24
TYPE=Ethernet

EOF

echo Installing packages
yum install -y ipa-server bind bind-dyndb-ldap

echo Installing IPA master
ipa-server-install --admin-password=$PASSWORD --ds-password=$PASSWORD --hostname=$FQDN \
--realm=$MYREALM --domain=$MYDOMAIN --no-forwarders --setup-dns --no-ntp --idstart=50000 \
--mkhomedir  --ip-address=${MYIP} --unattended

clear
echo 'IPA is now on configured with these settings'
cat /etc/ipa/default.conf

echo 
echo
echo 'All services are up and running'
ipactl status

echo
echo 'Note: reboot system and check that IPA is up and running and you should be good to go'

exit ${RETVAL}
# EOF

ChangeLog: 
2015-06-13 Tested. 

At install the IP on the nic must match the IP in hosts or pki errors.
