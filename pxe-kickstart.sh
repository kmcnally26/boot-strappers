#!/bin/bash
#
# Desc: Kickstart PXE and DHCP lease
#
# Date: 2014-03-05
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL6

# Verbose output.
# set -x
# Exit if anything fails
set -e
# Uncomment for no output.
#exec > /dev/null 2>&1

## We need 3 arguments
if [ $# -ne 3 ]
  then
    echo 'Script requires 3 args FQDN, IP and MAC:'
    echo 'test.example.com 172.16.105.133 00:44:D6:AC:12:88' ; exit 1
fi

## Set build detail here
KICKSTART_DIR=/var/www/html/kickstart
PXELINUX_DIR=/var/lib/tftpboot/pxelinux.cfg
DHCP_CONF_FILE=/etc/dhcp/dhcpd.conf
PUPPET_MASTER=puppet.example.com
ROOT_PW=password

clear
echo "KICKSTART_DIR=$KICKSTART_DIR"
echo "PXELINUX_DIR=$PXELINUX_DIR"
echo "DHCP_CONF_FILE=$DHCP_CONF_FILE"
echo "PUPPET_MASTER=$PUPPET_MASTER"
echo "ROOT_PW=$ROOT_PW"
echo "Shall I carry on? "
  read -p '#> ' ANSWER
    if [ ${ANSWER} != y ] ; then
      echo Aborting
      exit 1
    fi


echo Checking DHCP config for conflicting entries
if egrep "${2}|${3}" ${DHCP_CONF_FILE}
  then
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
/sbin/service dhcpd restart

fi

echo
echo Creating the kickstart file .............

echo "
install 
text
unsupported_hardware 
url --url http://172.16.105.130/centos/6.5

lang en_US.UTF-8
keyboard uk

repo --name=base-centos-6.5-os --baseurl=https://172.16.105.132/pulp/repos/centos/6/os/x86_64/Packages/ --noverifyssl
repo --name=external-puppet-labs --baseurl=https://172.16.105.132/pulp/repos/centos/6/external/puppetlabs/Products/ --noverifyssl
repo --name=external-puppet-dep-labs --baseurl=https://172.16.105.132/pulp/repos/centos/6/external/puppetlabs/Dependencies/ --noverifyssl

network --onboot yes --device eth0 --bootproto dhcp --noipv6 --hostname ${1}

rootpw  --iscrypted ${ROOT_PW}
firewall --disabled
authconfig --enableshadow --passalgo=sha512
selinux --disabled
timezone --utc Europe/London

bootloader --location=mbr --driveorder=sda 
zerombr yes
clearpart --all

part /boot --fstype=ext4 --size=500
part pv.1 --grow --size=1

volgroup vg_1 --pesize=4096 pv.1
logvol / --fstype=ext4 --name=lv_root --vgname=vg_1 --grow --size=1024 --maxsize=51200
logvol swap --name=lv_swap --vgname=vg_1 --grow --size=1024 --maxsize=1024

reboot

%packages --ignoremissing
@base
@core
puppet


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
mv -f /etc/yum.repos.d/C* /opt


echo Installing puppet client
yum -t -y -e 0 install puppet

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
puppet agent --waitforcert 10 --certname ${1} --server ${PUPPET_MASTER} --onetime --no-daemonize --test --ssldir /var/lib/puppet/ssl --report true --pluginsync true

sync
) 2>&1 | tee /root/install.post.log
 %end
" > ${KICKSTART_DIR}/${1}-ks


echo
echo Creating the PXE file ................
cat << EOF > ${PXELINUX_DIR}/01-${3,,}
PROMPT 0
TIMEOUT 1
ONTIMEOUT install_64bit
LABEL install_64bit
    MENU LABEL ^CentOS 6.5 Install
    KERNEL boot/vmlinuz  
    APPEND ks=http://172.16.105.130/kickstart/$1-ks initrd=boot/initrd.img ramdisk_size=100000 ksdevice=eth0

EOF

## Rename file as needed by pxelinux
mv -f ${PXELINUX_DIR}/01-${3,,} ${PXELINUX_DIR}/$( echo 01-${3,,} | sed 's/\:/\-/g')

echo
echo Removing any existing puppet certs .................
ssh -q root@${PUPPET_MASTER} puppet cert clean $1 >/dev/null

echo Done
echo
echo 
echo '##############################################################################'
echo
echo "Created PXE file: $PXELINUX_DIR/$( echo 01-${3,,} | sed 's/\:/\-/g')"
echo "Created Kickstart file: $KICKSTART_DIR/$1-ks"
echo "Added entry to ${DHCP_CONF_FILE} for ${1}"
echo

exit 0
