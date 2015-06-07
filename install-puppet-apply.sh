#!/bin/bash
#
# Desc: Install basic puppet apply. 
# Just set PUPPETMASTER var. Set hosts file. 
# Date: 2015-06-09
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL7 + Puppet 3.7

# Verbose output.
#set -x
# Uncomment for no output.
#exec > /dev/null 2>&1
# Exit if anything fails
set -e

## Environment 
RETVAL=0
  
## Disable firewall and SElinux 
  if !( grep 'SELINUX=disabled' /etc/sysconfig/selinux ); then
    sed 's/SELINUX=[a-z]*/SELINUX=disabled/' /etc/sysconfig/selinux -i 
  fi

  systemctl disable firewalld && systemctl stop firewalld && iptables -F

## Repo and package
  if ! (rpm -qa puppet); then
    yum install -y https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
    yum install -y puppet  
  fi
  
## Create tree
mkdir -pv /etc/puppet/{data,environments/production/{manifests/nodes,modules/test_class/{files,manifests,templates}}}

## Test node def, hiera and resource
cat << EOF > /etc/puppet/environments/production/manifests/nodes/nodes.pp
  node default {
#  include .........
  }
EOF

## Create papply
cat << EOF > /usr/local/bin/papply
#!/bin/bash
## $1 to allow for --noop

ENV=production
puppet apply  --modulepath=/etc/puppet/environments/\${ENV}/modules /etc/puppet/environments/\${ENV}/manifests/nodes/nodes.pp $1
EOF

chmod 755 /usr/local/bin/papply

## Test papply
papply

exit ${RETVAL}
# EOF

ChangeLog: 
