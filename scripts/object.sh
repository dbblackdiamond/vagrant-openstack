#!/bin/bash

while [[ $# > 1 ]]
do
  key="$1"

  case $key in
    -rp|--rabbitmqpwd)
    RABBITMQPWD="$2"
    shift
    ;;
    -cp|--cinderpass)
    CINDER_PASS="$2"
    shift
    ;;
    -i|--ip)
    PRIVATEIP="$2"
    shift
    ;;
    -pi|--privateip)
    CONTROLLERPRIVATEIP="$2"
    shift
    ;;
    -sz|--sdbsize)
    SDBSIZE="$2"
    shift
    ;;
    *)
    # unknown option
    ;;
  esac
  shift
done

echo "Setting up swap space..."
fallocate -l 8G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

echo "Setting up the Compute Node..."
echo "Setting up /etc/hosts..."
cat /vagrant/files/keystone/controller_hosts >> /etc/hosts

# Install ntp
echo "Installing and configuring NTP..."
apt-get -qq -y --force-yes install ntp
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" /vagrant/files/other_ntp.conf.orig > /etc/ntp.conf

echo "Installing Openstack Repo..."
apt-get -qq install ubuntu-cloud-keyring
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" "trusty-updates/kilo main" > /etc/apt/sources.list.d/cloudarchive-kilo.list
apt-get -qq update && apt-get -qq -y --force-yes dist-upgrade

echo "Configuring sdb..."
apt-get -qq -y --force-yes install parted zfsprogs rsync
parted /dev/sdb mklabel msdos
parted /dev/sdb mkpart primary 512 100%
parted /dev/sdc mklabel msdos
parted /dev/sdc mkpart primary 512 100%
mkfs.xfs /dev/sdb1
mkfs.xfs /dev/sdc1
mkdir -p /srv/node/sdb1
mkdir -p /srv/node/sdc1

echo "/dev/sdb1 /srv/node/sdb1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab
echo "/dev/sdc1 /srv/node/sdc1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab
mount /srv/node/sdb1
mount /srv/node/sdc1
sed -e "s/LOCALIP/${LOCALIP}/" /vagrant/files/swift/rsync.conf.object.orig > /etc/rsync.conf
cp /vagrant/files/swift/rsync.default /etc/default/rsync
service rsync start

apt-get -qq -y --force-yes swift swift-account swift-container swift-object


echo "Installing and Configuring Swift..."
apt-get -qq -y --force-yes install cinder-volume python-mysqldb
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/RABBIT_PASS/${RABBITMQPWD}/" -e "s/CINDER_PASS/${CINDER_PASS}/" \
	-e "s/BLOCKPRIVIP/${PRIVATEIP}/" /vagrant/files/cinder/cinder.conf.block.orig > /etc/cinder/cinder.conf
service tgt restart
service cinder-volume restart
rm -f /var/lib/cinder/cinder.sqlite
