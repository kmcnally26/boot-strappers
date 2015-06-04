#!/bin/bash
#
# Desc: Custom kickstart file to rebuild the puppet master. Puppet 3.4 on RHEL6. With papply setup.
# We can rebuild all hosts with puppet/dns working. But not the puppet master itself.
# If EVERYTHING was gone. First get a minimal install cd to iLO at the DC. Put this file on INET.
# RHEL6. Press TAB, append to existing line linux ks=http://webserver/thisfile
# All the old certs that are on clients will be no good so delete them
# Add: url, hostname, network settings, repos, puppet config location.
# Below works for this project.
# Date: 2014-05-03
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL6

# Verbose output.
# set -x
# Exit if anything fails
# set -e
# Uncomment for no output.
#exec > /dev/null 2>&1

install 
text
unsupported_hardware 
url --url http://kickstart.example.com/centos/6.5

lang en_US.UTF-8
keyboard uk

repo --name=base-centos-6.5-os --baseurl=https://pulp.example.com/pulp/repos/centos/6/os/x86_64/Packages/ --noverifyssl
repo --name=external-puppet-labs --baseurl=https://pulp.example.com/pulp/repos/centos/6/external/puppet/products/ --noverifyssl
repo --name=external-puppet-dep-labs --baseurl=https://pulp.example.com/pulp/repos/centos/6/external/puppet/dependencies/ --noverifyssl

network --bootproto static --ip 172.16.105.166 --netmask 255.255.255.0 --gateway 172.16.105.1 --nameserver 172.16.105.150 --hostname puppet.example.com --noipv6

rootpw  --iscrypted $6$LV1vaaVuiYwlYGaN$iFg4EidI2vKpmunOWQwCM9xQ96CkmxEmON1RoUCvgeE0Wjt5BlA/HOWwOIDXOJ9SjEyDQgzaokk1t64ThpANq0
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
redhat-lsb-core
git


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

## START of post script. 
echo 'Getting my repos ............' 
sleep 2

cat << EOF >/etc/yum.repos.d/puppet-bootstrap.repo
[base-centos-6.5-os]
sslverify=False
baseurl=https://pulp.example.com/pulp/repos/centos/6/os/x86_64/Packages/
enabled=1
gpgcheck=0
name=Centos 6.5

[external-puppet]
sslverify=False
baseurl=https://pulp.example.com/pulp/repos/centos/6/external/puppet/products/
enabled=1
gpgcheck=0
name=Puppet Labs Products

[external-puppet-deps]
sslverify=False
baseurl=https://pulp.example.com/pulp/repos/centos/6/external/puppet/dependencies/
enabled=1
gpgcheck=0
name=Puppet Labs Dependencies

EOF

## Is this needed? WHy not rpm -e centos-release and then yum clean all
echo 'Moving CentOS repos to /opt .....................'
mv -f /etc/yum.repos.d/C* /opt
yum clean all

echo 'Setting up SSH keys for rsync .....................'
sleep 2

## Get the puppet config
install -o root -g root -m 0700 -d /root/.ssh
cat << EOF >/root/.ssh/known_hosts
puppet,172.16.105.131 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA0k9OReD53sFjAzWcAExyzMJXnGzN5tX0cE91AkxwK6i3Yf499a1jD/U3FPdFm388d1FMl697YpX0JeiKdC8vBHajHy/lrAmCgYbQFBQXz83oq7OvkGgBfM7o/Q12p+9Voqc36JA1r3ueaLZiomtM+uFJuN5Qz7nLTFff0RykeP0fmI0covXa4RVBq7EbxgvusxYX6BuJoIjPFgQi44SbM0uqakbykB8cDoOVJXffB5mECrTAW62LCltENDXBr8OoFo1lU30MmiTjL4/i6/BI0E3bbJJbH0supEFKchd+Aip498Gh65T87p7Q2g8d/qIc2NHZT7C1rPquqrz2rAPJ5w==

EOF

chmod 0644 /root/.ssh/known_hosts

cat << EOF >/root/.ssh/id_rsa
-----BEGIN RSA PRIVATE KEY-----
MIIEoQIBAAKCAQEAzQFm30FHh74lFXizDEe2PbKNVRiJuL9amNYomrTuBg49Y+4U
9XyWCQQDmyBjbN1/Vk9wm6JcEzmF5heZLjd+j/L9lXIET4aqywHjjrTm7H8fr9U3
TUwsIgiR/BIyOxz9vNbJYrLBdtbMf4WjXgxikwHlaKEJcKkhh5RusQu4ne5+/roG
fU+v4iurVAPB/lVIIfAYIcYT9IW+yhxNjPYPdaY5fihJo2611gWcmVWwHxrUaqbG
2WHohpOpgtsHNzFT378ITK/IslPDb+C9ectEzMFvap9y+jxH1wna3OvHeOpeYjey
6eFEFWsUI5K6ztNCnxuIw8y+g+lV4ofZ9URRIQIBIwKCAQA0tze1wFQ42R96jMBT
nWlgUnwdMjIK72BwcZVpnD00wdVFlP4TPUsm48Zpt98NXYck0plMl3bDHWuS8CAT
Mtdm2BVSUITD/g6pOwAAH+Ob5iy4L4M/wyFKlH1PcmSwHWXReQ82ov6MRdzQVZBo
pBlZAHzRwwJtbVHDxxUmNjbJhgKbDr4ixsnGc1IiffTX1y2bkUCSFjPgtNa1y0hB
nANAYjoaAd++hz0KjQNCF/TYP2nWqpfIuHhbR2ACWM7xczZ8N0g3PzO7UL0sLdV3
QRK/2BoQbhekttIHvk61uKvp5zb5rc8C/Z4WMtb3O1H9rmcCqVroJJKUhc3B/8vW
L6OXAoGBAOcrBVd9DCEf1AwjT+jJSCkF2oM6MexQVuqmHszjjJCxsbhRIvDMd1pQ
g7n+nLHTQzkshiYJJQjiN3M8UgX+Gu++mF1UjRGm2RYdvpCm/GxzWFzwNRuyjYUl
80MwcIzrS/AWnOWRN4EqRHBd7wrX02v+H5M6LJSWOo8ua4hYWn9XAoGBAOMG7SDq
zLb3erUcWD175MMUbu8hPc+sGjvSyoQcCsd0PZ85qLnVlBjOQQ7SlLfmbziJiTYY
/bZBYxY9aIccVldaiJIhSV+kzuoYGplYYAE2dgJzaN7jknV2h9dbkJ3//tFkL8S+
z3iU0rUgoI2OPSmWoj6tg7cBbYoXAKqxTQBHAoGBAOCQMRMpBHfzCIDR2Jj+C5WQ
qGI4iESl0MawAKnHGtWz7niJVSRu2le77a1dvMoAbTA54WbHDgihPS4dVv6B0QYm
3Sd2tOyTc8xXaKnGyVNovD0Gmf2mIxOhNXR4MtIJJTJfHBI1S9yPda78KgqIhD0F
fcI4gxP/ppm4ELBV1EEvAoGAOmDd4+SbCnom3h07QwKZ6QVBGOtKaJn4HgMA4CR3
zONgTYPa7fUXdBfHlhjkac2KUF3hdE+RsoXXpqITkHUAQlkbzc4LjZ9oaBTTo8ZE
kpj5xh2tQKDrJYThGh7cC18Vo47KdGuUb3a51s3gJGZnf7kFJg9cYkIyHDHM+LE/
r50CgYAadNYV4fYPvDqPjUpXoqPABrxlHWPUFbnZU8qzYlmwETNmqoOTaLgCpgXH
TrBjr/aPsNIt3YcwVtfmaO0SvOtuj8V7c50A2lsVvY0aGzEJ1RTNpmkS9KxvjCDj
w39iO/GcGgPrbpZ9leq7PkMq+K3sWAY0nGDZGRWuxAE8tKfVBQ==
-----END RSA PRIVATE KEY-----

EOF

chmod 0400 /root/.ssh/id_rsa

echo 'Setting up the puppetmaster ................'
sleep 2
mkdir -p /etc/puppet

## This  works for my test
rsync -az -e 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' puppet.example.com:/etc/puppet/ /etc/puppet

## Or checkout from GIT
#git clone https://github.com/kmcnally26/my_puppet.git /etc/puppet

yum install -y puppet puppet-server

cat << EOF >/etc/puppet/puppet.conf

#
# This file is managed by puppet
#


[main]
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
autosign=true
privatekeydir = $ssldir/private_keys { group = service }
hostprivkey = $privatekeydir/$certname.pem { mode = 640 }

[agent]
server=puppet.example.com
report=true
pluginsync=true
environment=prd

[master]
## Foreman Proxy
autosign = $confdir/autosign.conf {owner = service, group = service, mode = 664 }

ssl_client_header=SSL_CLIENT_S_DN
ssl_client_verify_header=SSL_CLIENT_VERIFY
reports=log, foreman

## Environments
environmentpath = /etc/puppet/environments/


## Foreman ENC
#external_nodes=/etc/puppet/foreman_enc.rb
#node_terminus=exec

EOF

echo 'Starting the puppetmaster .................'
sleep 2
/etc/init.d/puppetmaster start
chkconfig puppetmaster on


echo 'Trying a puppet run against myself ..............................'
sleep 2
puppet agent -t

## END of the post script

sync
## Now everything in post script goes to the install.post.log 
) 2>&1 | tee /root/install.post.log
%end
