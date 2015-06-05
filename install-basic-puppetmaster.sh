#!/bin/bash
#
# Desc: Install basic puppet master. 
# Just set PUPPETMASTER var. Set hosts file. 
# Date: 2015-03-09
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

## Set FQDN
  echo "Your FQDN on this host is $(hostname -f)"
  while [ "x" = "x$PUPPETMASTER" ]; do
    read -p "Enter new puppet masters FQDN >: " PUPPETMASTER
  done
  
  if ! (grep puppet /etc/hosts) ; then
    echo 'Hosts file does not have a puppet entry'
    exit 1
  fi
  
## Disable firewall and SElinux 
  if !( grep 'SELINUX=disabled' /etc/sysconfig/selinux ); then
    sed 's/SELINUX=[a-z]*/SELINUX=disabled/' /etc/sysconfig/selinux -i 
  fi

  systemctl disable firewalld && systemctl stop firewalld && iptables -F

## Repos and packages 
yum install -y epel-release
yum install -y https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
yum install -y puppet puppet-server facter hiera rubygems 
gem install hiera


## Config
cat << EOF > /etc/puppet/puppet.conf
[main]
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
autosign=true

[agent]
server="$PUPPETMASTER"
environment=production

[master]
environmentpath=/etc/puppet/environments/
EOF

## Create tree
mkdir -pv /etc/puppet/{data,environments/production/{manifests/nodes,modules/test_class/{files,manifests,templates}}}

## Test node def, hiera and resource
cat << EOF > /etc/puppet/environments/production/manifests/nodes/nodes.pp
  node default {
    include test_class
  }
EOF

cat << EOF > /etc/puppet/environments/production/modules/test_class/manifests/init.pp
class test_class (
  \$string = undef

) {

  file { "/tmp/\$string" :
    ensure => present,
    owner  => 'root',
    group  => 'root',
  }
}
EOF

cat << EOF > /etc/puppet/environments/production/environment.conf
modulepath=/etc/puppet/environments/production/modules
manifest=/etc/puppet/environments/production/manifests/nodes
EOF

## Hiera setup
ln -s /etc/hiera.yaml /etc/puppet/hiera.yaml
cat << EOF > /etc/puppet/hiera.yaml
:backends:
  - yaml
  - puppet
:hierarchy:
  - global
:yaml:
  :datadir: /etc/puppet/data
EOF

cat << EOF > /etc/puppet/data/global.yaml
---
test_class::string: 'hiera-test-file'
EOF

echo creating puppet apply
cat << EOF > /usr/local/bin/papply
#!/bin/bash

puppet apply --verbose  --modulepath=/etc/puppet/environments/production/modules/ \
                        /etc/puppet/environments/production/manifests/nodes/nodes.pp $1

EOF

chmod 755 /usr/local/bin/papply

## Create puppet CA
systemctl stop puppetmaster.service
puppet master --verbose --no-daemonize &
sleep 10

## Start the master
systemctl enable puppetmaster.service
systemctl restart puppetmaster.service

## Test a run locally
puppet agent -t

exit ${RETVAL}
# EOF

ChangeLog: 
Install stdlib 
To delete and test: service puppetmaster stop ; rm -rf /var/lib/puppet/ /etc/puppet/ ; yum erase puppet-server puppet hiera facter puppetlabs-release epel-release -y
