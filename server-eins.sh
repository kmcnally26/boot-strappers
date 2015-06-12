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

MYIP=10.120.0.15
MYMASK=255.255.0.0
MYNIC=enp0s25    ## As per HP laptop LMN London office

## Set DHCP
DHCPSUBNET=10.120.0.0
DHCPMASK=255.255.0.0
NAMESERVER=${MYIP}
DISTRO='CentOS-7.1-x86_64'

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
${MYIP} server-eins.ams1.lastminute.com server-eins

EOF

cat << EOF > /etc/resolv.conf
nameserver 127.0.0.1

EOF

cat << EOF > /etc/hostname
server-eins.ams1.lastminute.com

EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-${MYNIC}
TYPE=Ethernet
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
NAME=${MYNIC}
UUID=393ceca4-cf1d-4eba-85f7-823e60618ace
DEVICE=${MYNIC}
ONBOOT=yes
IPADDR=${MYIP}
PREFIX=16
DNS1=127.0.0.1
DOMAIN=ams1.lastminute.com
IPV6_PEERDNS=yes
IPV6_PEERROUTES=yes
IPV6_PRIVACY=no


EOF

## Set IPv6 settings for IPA Samba AD trusts

cat << EOF > /etc/sysctl.d/ipv6.conf
# Disable IPv6 interface but leave stack up
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.${MYNIC}.disable_ipv6 = 1

EOF

sysctl -p

ifdown ${MYNIC}
ifup ${MYNIC}

## Disable CentOS repos as we have not inet connection
rm -f /etc/yum.repos.d/*.repo

## Get CentOS 7 repo setup locally and then install ipa server
    
echo 'Attach the usbstick to the laptop and I will cp CentOS 7 DVD packages'
echo "Press y when this is done and I will carry on building this shit? "
  read -p '#> ' ANSWER
    if [ ${ANSWER} != y ] ; then
      echo Aborting
      exit 1
    fi

#umount /dev/cdrom || :
#mount /dev/cdrom /mnt && mkdir -p /var/www/html/repos/centos/7/dvd/ && echo XXXXX cp -rv /mnt/. /var/www/html/repos/centos/7/dvd/
#find /var/www/html/ -type d -exec chmod 755 {} \;

cat << EOF > /etc/yum.repos.d/centos7-dvd.repo
[centos7-dvd]
name=centos7 dvd repo
enabled=1
baseurl=file:///var/www/html/repos/centos/7/dvd/
gpgcheck=0

EOF

yum clean all
yum repolist
yum install -y ipa-server bind bind-dyndb-ldap

#echo Installing IPA master
#ipa-server-install --admin-password=password --ds-password=password --hostname=server-eins.ams1.lastminute.com --realm=AMS1.LASTMINUTE.COM --domain=ams1.lastminute.com --no-forwarders --setup-dns --no-ntp --idstart=50000 --mkhomedir  --ip-address=${MYIP} --unattended

echo Start all IPA services on boot
systemctl enable ipa.service

echo 'Hows IPA looking?'
cat /etc/ipa/default.conf
ipactl status || exit 1

echo TFTP DHCP setup

echo Install packages
yum install -y dhcp syslinux tftp-server xinetd 


echo TFTP SETUP
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/
mkdir -p /var/lib/tftpboot/{boot,pxelinux.cfg}
cp /var/www/html/repos/centos/7/dvd/images/pxeboot/vmlinuz  /var/lib/tftpboot/boot/${DISTRO}-vmlinuz
cp /var/www/html/repos/centos/7/dvd/images/pxeboot/initrd.img  /var/lib/tftpboot/boot/${DISTRO}-initrd.img

cat << EOF > /var/lib/tftpboot/pxelinux.cfg/default
DEFAULT ${DISTRO}
LABEL ${DISTRO}
    KERNEL boot/${DISTRO}-vmlinuz
    APPEND initrd=boot/${DISTRO}-initrd.img inst.ks=http://${MYIP}/kickstart/\${1}-ks devfs=nomount ip=dhcp

EOF

echo XINETD SETUP
sed 's/disable[ \t=]*yes/disable     = no/' /etc/xinetd.d/tftp -i
systemctl enable xinetd.service
systemctl restart xinetd.service

echo DHCP SETUP
cat << EOF > /etc/dhcp/dhcpd.conf
# DHCP options
allow booting;
allow bootp;
omapi-port 7911;

option domain-name "ams1.lastminute.com";
option domain-name-servers ${NAMESERVER};
default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;
authoritative;
log-facility local7;

# Subnet settings
subnet $DHCPSUBNET netmask $DHCPMASK {
    next-server $MYIP;
    filename "pxelinux.0";
    option domain-name-servers $NAMESERVER;
}

# Host declaration example
#host apex {
#   option host-name "apex.example.com";
#   hardware ethernet 00:A0:78:8E:9E:AA;
#   fixed-address 172.16.105.4;
#}

EOF

systemctl enable dhcpd.service
systemctl restart dhcpd.service

xxxxxxxxx GOOD TO HERE

echo 'Attach the usbstick to the laptop and cp these isos to /home/syseng/Downloads/'
echo '/home/syseng/Downloads/CentOS-6.6-x86_64-bin-DVD1.iso'
echo '/home/syseng/Downloads/CentOS-6.6-x86_64-bin-DVD2.iso'
echo "Press y when this is done and I will carry on building this shit? "
  read -p '#> ' ANSWER
    if [ ${ANSWER} != y ] ; then
      echo Aborting
      exit 1
    fi

## Add user
if ! (id syseng) ;then useradd -m -p password syseng ; fi

cat << EOF >> /etc/fstab
## isos
/home/syseng/Downloads/CentOS-6.6-x86_64-bin-DVD1.iso /var/www/html/repos/centos/6/dvd1/         iso9660 defaults 0 0
/home/syseng/Downloads/CentOS-6.6-x86_64-bin-DVD2.iso /var/www/html/repos/centos/6/dvd2          iso9660 defaults 0 0

EOF

echo mounting isos
mount -a || exit 1

echo Dont forget the gems for r10k

echo 'At this point in time you need to attach your usbstick to the laptop and cp the repos/ directory to /var/www/html/'
echo "Press y when this is done and I will carry on building this shit? "
  read -p '#> ' ANSWER
    if [ ${ANSWER} != y ] ; then
      echo Aborting
      exit 1
    fi

## Add all your repo files here for CentOS 6/7
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


exit ${RETVAL}
# EOF

ChangeLog: 

