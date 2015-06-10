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

## Execute 
echo 'At this point in time you need to attach your usb and cp the repos/ directory to /var/www/html/'
echo "Press y when this is done and I will carry on building this shit? "
  read -p '#> ' ANSWER
    if [ ${ANSWER} != y ] ; then
      echo Aborting
      exit 1
    fi
    
echo 'At this point in time you need to attach your usb and cp the isos to /home/syseng/Downloads/'
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
mount -a

cat << EOF > /etc/yum.repos.d/puppet-dependencies.repo
[puppet-dependencies]
name=puppet dependencies repo
enabled=1
baseurl=file:///var/www/html/repos/centos/7/yum.puppetlabs.com/el/7/dependencies/x86_64/
gpgcheck=0

EOF

cat << EOF > /etc/yum.repos.d/puppet-dependencies.repo
[puppet-products]
name=puppet products repo
enabled=1
baseurl=file:///var/www/html/repos/centos/7/yum.puppetlabs.com/el/7/products/x86_64/
gpgcheck=0

EOF

cat << EOF > /etc/yum.repos.d/puppet-dependencies.repo
[centos7-dvd]
name=centos7 dvd repo
enabled=1
baseurl=file:///var/www/html/repos/centos/7/iso/
gpgcheck=0

EOF

echo configuring web server for repos
yum install -y httpd 
systemctl enable httpd.service
systemctl restart httpd.service

exit ${RETVAL}
# EOF

ChangeLog: 