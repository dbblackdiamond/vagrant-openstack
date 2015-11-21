#!/bin/bash

while [[ $# > 1 ]]
do
  key="$1"

  case $key in
    -c|--config)
    CONFIGFILE="$2"
    shift
    ;;
    *)
    # unknown option
    ;;
  esac
  shift
done

source ${CONFIGFILE}

echo "Setting up swap space..."
fallocate -l 8G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

echo "Setting up the Compute Node..."
echo "Setting up /etc/hosts..."
cat /vagrant/files/hosts >> /etc/hosts

echo "Setting up Openstack Repository for version ${VERSION}..."
if [ ${VERSION} == "kilo" ]; then
        apt-get -qq -y --force-yes install ubuntu-cloud-keyring
        echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" "trusty-updates/kilo main" > /etc/apt/sources.list.d/cloudarchive-kilo.list
elif [ ${VERSION} == "liberty" ]; then
        apt-get -qq -y --force-yes install software-properties-common
        add-apt-repository -y cloud-archive:liberty
fi
apt-get -qq update && apt-get -qq -y --force-yes dist-upgrade

# Install ntp
echo "Installing and configuring NTP..."
apt-get -qq -y --force-yes install ntp
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" /vagrant/files/other_ntp.conf.orig > /etc/ntp.conf

echo "Configuring sdb..."
apt-get -qq -y --force-yes install parted lvm2 qemu
parted /dev/sdb mklabel msdos
parted /dev/sdb mkpart primary 512 100%
pvcreate /dev/sdb1
vgcreate cinder-volumes /dev/sdb1
#cp /vagrant/files/cinder/lvm.conf /etc/lvm/lvm.conf

echo "Installing and Configuring Cinder..."
apt-get -qq -y --force-yes install cinder-volume python-mysqldb
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/RABBIT_PASS/${RABBITMQPWD}/" -e "s/CINDER_PASS/${CINDER_PASS}/" \
	-e "s/BLOCKPRIVIP/${PRIVATEIP}/" /vagrant/files/cinder/cinder.conf.block.orig > /etc/cinder/cinder.conf
service tgt restart
service cinder-volume restart
rm -f /var/lib/cinder/cinder.sqlite
