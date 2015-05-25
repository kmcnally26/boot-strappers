#!/bin/bash
#
# Desc: Kickstart DHCP PXE server on a clean install.
#
# Date: 2015-05-23
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL7

# Verbose output.
set -x
# Exit if anything fails
#set -e
# Uncomment for no output.
#exec > /dev/null 

## Environment 
RETVAL=0

## Set host detail here
clear 
echo MYIP=172.16.105.130
echo MYHOSTNAME=kickstart
echo MYDOMAIN=example.com
echo "FQDN=$MYHOSTNAME.$MYDOMAIN"
echo "Shall I carry on? "
  read -p '#> ' ANSWER
    if [ ${ANSWER} != y ] ; then
      echo Aborting
      exit 1
    fi

echo Disable firewall and SElinux 
  if !( grep 'SELINUX=disabled' /etc/sysconfig/selinux ); then
    sed 's/SELINUX=[a-z]*/SELINUX=disabled/' /etc/sysconfig/selinux -i 
  fi

  systemctl disable firewalld && systemctl stop firewalld && iptables -F

  if ! (grep ${MYIP} /etc/hosts) ; then
    echo 'Cant find your IP in /etc/hosts'
    exit 1
  fi

echo INSTALL PACKAGES
yum install dhcp syslinux tftp-server xinetd httpd -y


echo HTTP MEDIA SETUP - MOUNTED ONLY
HTTPMEDIA='/var/www/html/kickstart'
mkdir -p ${HTTPMEDIA}{
mount -o loop /dev/cdrom ${HTTPMEDIA}{
systemctl enable httpd.service
systemctl restart httpd.service


echo TFTP SETUP
DISTRO='CentOS-7.1-x86_64'
cd /var/lib/tftpboot/
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/
mkdir -p /var/lib/tftpboot/pxelinux.cfg/boot
cp ${HTTPMEDIA}{/images/pxeboot/vmlinuz  /var/lib/tftpboot/pxelinux.cfg/boot/${DISTRO}{-vmlinuz
cp ${HTTPMEDIA}{/images/pxeboot/initrd.img  /var/lib/tftpboot/pxelinux.cfg/boot/${DISTRO}{-initrd.img

cat << EOF > /var/lib/tftpboot/pxelinux.cfg/default
PROMPT 0
TIMEOUT 1
ONTIMEOUT install_${DISTRO}
LABEL install_${DISTRO}
    MENU LABEL ${DISTRO}
    KERNEL boot/${DISTRO}-vmlinuz  
    APPEND initrd=boot/${DISTRO}-initrd.img method=http://${MYIP}/kickstart/ devfs=nomount ip=dhcp

EOF

echo XINETD SETUP
sed 's/disable[ \t=]*yes/disable     = no/' /etc/xinetd.d/tftp -i
systemctl enable xinetd.service
systemctl restart xinetd.service

echo DHCP SETUP
BUILDSUBNET=172.16.105.0
BUILDMASK=255.255.255.0
NAMESERVER=172.16.105.150

cat << EOF > /etc/dhcp/dhcpd.conf
# DHCP options
allow booting;
allow bootp;
omapi-port 7911;

option domain-name "${MYDOMAIN}";
option domain-name-servers ${NAMESERVER};
default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;
authoritative;
log-facility local7;

# Subnet settings
subnet $BUILDSUBNET netmask $BUILDMASK {
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


