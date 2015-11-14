#!/bin/bash
#
# Desc: Install basic puppet apply on CentOS 6. 
# Date: 2015-06-09
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL6 + Puppet 3.7

## Environment 
RETVAL=0

set -e

## Repo and package
  if ! (rpm -qa | grep puppet); then
    yum install -y https://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
    yum install -y puppet  
  fi
  
## Create tree
mkdir -pv /etc/puppet/{data,modules,manifests}

## Test node def, hiera and resource
cat << EOF > /root/puppet/manifests/nodes.pp
  node default {
#  include .........
  Package { allow_virtual => false, }
  }
EOF

## Install hiera
yum -y install hiera git epel-release
  if ! (gem list | grep hiera); then
    gem install hiera --no-ri --no-rdoc
  fi

cat << EOF > /etc/hiera.yaml
:backends:
  - yaml
  - puppet
:hierarchy:
  - global
:yaml:
  :datadir: /root/puppet/data

EOF

ln -s /etc/hiera.yaml /etc/puppet/hiera.yaml

cat << EOF > /etc/puppet/data/global.yaml
---

EOF

## Create papply
cat << EOF > /usr/local/bin/papply
#!/bin/bash
## $1 to allow for --noop

ENV=production
puppet apply --test --modulepath=/etc/puppet/modules /etc/puppet/manifests/nodes.pp \$1
EOF

chmod 755 /usr/local/bin/papply

## Test papply
papply --noop 

## Install puppet modules
puppet module install puppetlabs-stdlib --modulepath=/etc/puppet/modules
puppet module install puppetlabs-concat --modulepath=/etc/puppet/modules

exit ${RETVAL}
# EOF

ChangeLog: 
