#!/bin/bash
#
# Desc: Install basic puppet apply on CentOS 6. 
# Just set PUPPETMASTER var. Set hosts file. 
# Date: 2015-06-09
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL6 + Puppet 3.7

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

  service iptables stop && chkconfig iptables off && iptables -F

## Repo and package
  if ! (rpm -qa puppet); then
    yum install -y https://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
    yum install -y puppet  
  fi
  
## Create tree
mkdir -pv /etc/puppet/{data,environments/production/{manifests/nodes,modules}}

## Test node def, hiera and resource
cat << EOF > /etc/puppet/environments/production/manifests/nodes/nodes.pp
  node default {
#  include .........
  Package { allow_virtual => false, }
  }
EOF

yum -y install hiera
gem install hiera

cat << EOF > /etc/hiera.yaml
:backends:
  - yaml
  - puppet
:hierarchy:
  - global
:yaml:
  :datadir: /etc/puppet/data

EOF

ln -s /etc/hiera.yaml /etc/puppet/hiera.yaml

## Create papply
cat << EOF > /usr/local/bin/papply
#!/bin/bash
## $1 to allow for --noop

ENV=production
puppet apply  --modulepath=/etc/puppet/environments/\${ENV}/modules /etc/puppet/environments/\${ENV}/manifests/nodes/nodes.pp $1
EOF

chmod 755 /usr/local/bin/papply

## Test papply
papply --noop 

exit ${RETVAL}
# EOF

ChangeLog: 
