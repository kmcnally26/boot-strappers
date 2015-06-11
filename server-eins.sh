#!/bin/bash
#
# Desc: Build server-eins for DC migration if needed.
#
# Date: 2015-06-10
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
10.120.0.15 server-eins.ams1.lastminute.com server-eins

EOF

cat << EOF > /etc/resolv.conf
nameserver 127.0.0.1

EOF

cat << EOF > /etc/hostname
server-eins.ams1.lastminute.com

EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-XXXXXXXXXX
TYPE=Ethernet
BOOTPROTO=static
IPADDR=10.120.0.15
NETMASK=255.255.0.0
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
NAME=XXXXXXXXXX
UUID=XXXXXXXXXXXXXX
ONBOOT=yes
HWADDR=XXXXXXXXXXXXXXX
PEERDNS=yes
PEERROUTES=yes
IPV6_PEERDNS=yes
IPV6_PEERROUTES=yes

EOF

## Set IPv6 settings for IPA Samba AD trusts

cat << EOF > /etc/sysctl.d/ipv6.conf
# Disable IPv6 interface but leave stack up
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.XXXXXXXXX.disable_ipv6 = 1

EOF

sysctl -p


## Execute 
    
echo 'At this point in time you need you to attach the usbstick to the laptop and cp the isos to /home/syseng/Downloads/'
echo '/home/syseng/Downloads/CentOS-7-x86_64-Everything-1503-01.iso'
echo '/home/syseng/Downloads/CentOS-6.6-x86_64-bin-DVD1.iso'
echo '/home/syseng/Downloads/CentOS-6.6-x86_64-bin-DVD2.iso'
echo "Press y when this is done and I will carry on building this shit? "
  read -p '#> ' ANSWER
    if [ ${ANSWER} != y ] ; then
      echo Aborting
      exit 1
    fi

cat << EOF >> /etc/fstab
## isos
/home/syseng/Downloads/CentOS-7-x86_64-Everything-1503-01.iso /var/www/html/repos/centos/7/iso/  iso9660 defaults 0 0
/home/syseng/Downloads/CentOS-6.6-x86_64-bin-DVD1.iso /var/www/html/repos/centos/6/iso1/         iso9660 defaults 0 0
/home/syseng/Downloads/CentOS-6.6-x86_64-bin-DVD2.iso /var/www/html/repos/centos/6/iso2          iso9660 defaults 0 0

EOF

echo mounting isos
mount -a || exit 1

cat << EOF > /etc/yum.repos.d/centos7-dvd.repo
[centos7-dvd]
name=centos7 dvd repo
enabled=1
baseurl=file:///var/www/html/repos/centos/7/iso/
gpgcheck=0

EOF

yum clean all
yum repolist

echo configuring web server for repos
yum install -y httpd 
systemctl enable httpd.service
systemctl restart httpd.service

echo Dont forget the gems for r10k

echo 'At this point in time you need to attach your usbstick to the laptop and cp the repos/ directory to /var/www/html/'
echo "Press y when this is done and I will carry on building this shit? "
  read -p '#> ' ANSWER
    if [ ${ANSWER} != y ] ; then
      echo Aborting
      exit 1
    fi


cat << EOF > /etc/yum.repos.d/puppet-dependencies.repo
[puppet-dependencies]
name=puppet dependencies repo
enabled=1
baseurl=file:///var/www/html/repos/centos/7/yum.puppetlabs.com/el/7/dependencies/x86_64/
gpgcheck=0

EOF

cat << EOF > /etc/yum.repos.d/puppet-products.repo
[puppet-products]
name=puppet products repo
enabled=1
baseurl=file:///var/www/html/repos/centos/7/yum.puppetlabs.com/el/7/products/x86_64/
gpgcheck=0

EOF

echo configuring web server for repos
yum install -y httpd 
systemctl enable httpd.service
systemctl restart httpd.service

echo Do NOT install any packages/updates for CentOS OS  from the inet
echo Use only the provided isos until we get pulp up and running.

echo Installing IPA master
ipa-server-install --admin-password=password --ds-password=password --hostname=server-eins.ams1.lastminute.com \ 
realm=AMS1.LASTMINUTE.COM -domain=ams1.lastminute.com --no-forwarders --setup-dns --no-ntp --idstart=50000 \
--mkhomedir  --unattended

echo Start all IPA services on boot
systemctl enable ipa.service

echo 'Hows IPA looking?
ipactl status
cat /etc/ipa/default

echo You should now reboot 

exit ${RETVAL}
# EOF

ChangeLog: 
