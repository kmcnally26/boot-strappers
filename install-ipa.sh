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

MYIP=10.120.0.15
MYDOMAIN=ams1.lastminute.com
MYHOSTNAME=server-eins
FQDN=$MYHOSTNAME.$MYDOMAIN
NAMESERVER=$MYIP
MYREALM=${MYHOSTNAME~~}
PASSWORD=password

## Sanity checks

echo Disable firewall and SElinux
  if !( grep 'SELINUX=disabled' /etc/sysconfig/selinux ); then
    sed 's/SELINUX=[a-z]*/SELINUX=disabled/' /etc/sysconfig/selinux -i
    setenforce 0
  fi

  systemctl disable firewalld && systemctl stop firewalld && iptables -F


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

echo Installing packages
yum install -y ipa-server bind bind-dyndb-ldap

echo Installing IPA master
ipa-server-install --admin-password=$PASSWORD --ds-password=$PASSWORD --hostname=$MYHOSTNAME \
--realm=$MYREALM --domain=$MYDOMAIN --no-forwarders --setup-dns --no-ntp --idstart=50000 \
--mkhomedir  --ip-address=${MYIP} --unattended

echo Start all IPA services on boot
systemctl enable ipa.service

echo 'Hows IPA looking?'
cat /etc/ipa/default.conf
ipactl status

exit ${RETVAL}
# EOF

ChangeLog: 

At install the IP on the nic must match the IP in hosts or pki errors.


