#!/bin/bash
#
# Desc: Install basic puppet apply. 
# Just set PUPPETMASTER var. Set hosts file. 
# Date: 2015-06-09
# Author: <kevin.mcnally@lastminute.com>
# System: RHEL7 + Puppet 

set -e

## Environment 
RETVAL=0

## Repo and package
  if ! (rpm -qa  | grep puppet); then
    yum install -y https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
    yum install -y puppet  
  fi
  
## Create tree
mkdir -pv /etc/puppet/{data,manifests,modules}

## Test node def, hiera and resource
cat << EOF > /etc/puppet/manifests/site.pp
  node default {
#  include .........
}

  Package { allow_virtual => false, }
EOF

yum -y install hiera git epel-release
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
puppet apply --test --modulepath=/etc/puppet/modules /etc/puppet/manifests/site.pp \$1
EOF

chmod 755 /usr/local/bin/papply

## Test papply
papply --noop

exit ${RETVAL}
# EOF

ChangeLog: 
