#!/bin/bash
#
# Desc: Build a Kickstart DHCP TFTP PXE server on a clean install.
#
# Date: 2015-05-23
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL7

# Verbose output.
set -x
# Exit if anything fails
set -e
# Uncomment for no output.
#exec > /dev/null

## Environment
RETVAL=0

## Set host detail here
MYIP=172.16.105.131
MYHOSTNAME=freeipa001
MYDOMAIN=example.com
FQDN=$MYHOSTNAME.$MYDOMAIN

## Set DHCP
DHCPSUBNET=172.16.105.0
DHCPMASK=255.255.255.0
NAMESERVER=172.16.105.131

## Set distro and HTTP
DISTRO='CentOS-7.1-x86_64'
KSDIR=kickstart
PACKDIR=centos 
DROOT=/var/www/html 

clear
echo "MYIP=$MYIP"
echo "MYHOSTNAME=$MYHOSTNAME"
echo "MYDOMAIN=$MYDOMAIN"
echo "FQDN=$MYHOSTNAME.$MYDOMAIN"
echo "DHCPSUBNET=$DHCPSUBNET"
echo "DHCPMASK=$DHCPMASK"
echo "NAMESERVER=$NAMESERVER"
echo "DISTRO=$DISTRO"
echo "KICKSTARTURL=http://${MYIP}/${KSDIR}/XXXXXXX-ks"
echo "PACKAGEURL=http://${MYIP}/${PACKDIR}/"
echo "Shall I carry on? "
  read -p '#> ' ANSWER
    if [ ${ANSWER} != y ] ; then
      echo Aborting
      exit 1
    fi
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

echo INSTALL PACKAGES
yum install dhcp syslinux tftp-server xinetd httpd vim -y

echo HTTP MEDIA SETUP - MOUNTED ONLY
mkdir -p ${DROOT}/{${KSDIR},${PACKDIR}}
mount -o loop /dev/cdrom  ${DROOT}/${PACKDIR} || echo Looks like cdrom is already mounted
systemctl enable httpd.service
systemctl restart httpd.service

echo TFTP SETUP
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/
mkdir -p /var/lib/tftpboot/{boot,pxelinux.cfg}
cp  ${DROOT}/${PACKDIR}/images/pxeboot/vmlinuz  /var/lib/tftpboot/boot/${DISTRO}-vmlinuz
cp  ${DROOT}/${PACKDIR}/images/pxeboot/initrd.img  /var/lib/tftpboot/boot/${DISTRO}-initrd.img
cat << EOF > /var/lib/tftpboot/pxelinux.cfg/default
DEFAULT ${DISTRO}
LABEL ${DISTRO}
    KERNEL boot/${DISTRO}-vmlinuz
    APPEND initrd=boot/${DISTRO}-initrd.img inst.ks=http://${MYIP}/${KSDIR}/\${1}-ks devfs=nomount ip=dhcp
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
option domain-name "${MYDOMAIN}";
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
echo Downloading pxe-kick.sh
curl -sf -o /root/pxe-kick.sh -L -k https://raw.githubusercontent.com/kmcnally26/boot-strappers/master/pxe-kick.sh
chmod 755 /root/pxe-kick.sh
exit ${RETVAL}
# EOF
