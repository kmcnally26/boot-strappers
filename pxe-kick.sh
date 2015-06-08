#!/bin/bash
#
# Desc: Kickstart file, PXE cfg and DHCP lease
#
# Date: 2014-03-05
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL7

# Verbose output.
# set -x
# Exit if anything fails
set -e
# Uncomment for no output.
#exec > /dev/null 2>&1

RETVAL=0

## We need 3 arguments
  if [ $# -ne 3 ]; then
    echo 'Script requires 3 args FQDN, IP and MAC:'
    echo 'test.example.com 172.16.105.133 00:44:D6:AC:12:88' ; exit 1
  fi

## Set build detail here
KICKSTART_DIR=/var/www/html/kickstart
PXELINUX_DIR=/var/lib/tftpboot/pxelinux.cfg
DHCP_CONF_FILE=/etc/dhcp/dhcpd.conf
PUPPET_MASTER=puppet.example.com
ROOT_PW=password
HTTPURL='http://172.16.105.160/kickstart/'


echo Checking DHCP config for conflicting entries
#################################################

  if egrep "${2}|${3}" ${DHCP_CONF_FILE}; then
    echo
    echo "Remove conflicting entries from ${DHCP_CONF_FILE}" ; exit 1
  else

    echo
    echo Creating dhcpd.conf .........

cat << EOF >> ${DHCP_CONF_FILE}
host ${1} {
    hardware ethernet ${3};
    fixed-address ${2};
}

EOF

    echo
    echo Restarting dhcpd .........
    systemctl restart dhcpd.service

  fi


echo
echo Creating the kickstart file .............
##############################################

echo "
text
url --url ${HTTPURL}/centos
skipx
cmdline
keyboard --vckeymap=uk --xlayouts='gb'
lang en_GB.UTF-8
reboot

network  --bootproto=dhcp --activate
network  --hostname=${1}
auth --enableshadow --passalgo=sha512
rootpw  ${ROOT_PW}
timezone Europe/London --isUtc

bootloader --location=mbr --boot-drive=sda
ignoredisk --only-use=sda
autopart --type=lvm
clearpart --none --initlabel 

%packages
@core

%end

%post --nochroot
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(
cp -va /etc/resolv.conf /mnt/sysimage/etc/resolv.conf
/usr/bin/chvt 1
) 2>&1 | tee /mnt/sysimage/root/install.postnochroot.log
%end
%post
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(

echo Moving CentOS repos to /opt
#mv -f /etc/yum.repos.d/C* /opt

echo Installing puppet client
#yum -t -y -e 0 install puppet

echo Configuring puppet
cat << EOF > /etc/puppet/puppet.conf
[main]
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
[agent]
server=${PUPPET_MASTER}
report=true
pluginsync=true
environment=prd
EOF

echo Requesting a puppet cert
#puppet agent --waitforcert 10 --certname ${1} --server ${PUPPET_MASTER} --onetime --no-daemonize --test --ssldir /var/lib/puppet/ssl --report true --pluginsync true
sync
) 2>&1 | tee /root/install.post.log
%end
" > ${KICKSTART_DIR}/${1}-ks


echo
echo Creating the PXE file ................
###########################################
cat << EOF > ${PXELINUX_DIR}/01-${3,,}
DEFAULT linux
LABEL linux
    KERNEL boot/CentOS-7.1-x86_64-vmlinuz
    APPEND initrd=boot/CentOS-7.1-x86_64-initrd.img inst.ks=http://${HTTPURL}/${1}-ks devfs=nomount ip=dhcp

EOF
## Rename file as needed by pxelinux
mv -f ${PXELINUX_DIR}/01-${3,,} ${PXELINUX_DIR}/$( echo 01-${3,,} | sed 's/\:/\-/g')


echo Done
echo
echo 
echo '##############################################################################'
echo
echo "Created PXE file: $PXELINUX_DIR/$( echo 01-${3,,} | sed 's/\:/\-/g')"
echo "Created Kickstart file: $KICKSTART_DIR/$1-ks"
echo "Added entry to ${DHCP_CONF_FILE} for ${1}"
echo

exit ${RETVAL}
# EOF
