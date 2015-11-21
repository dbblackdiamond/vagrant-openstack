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

echo "Installing Nova-Compute..."
apt-get -qq -y --force-yes install nova-compute-vmware sysfsutils python-novaclient python-suds
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/COMPIP/${COMPUTEPUBIP}/" \
	-e "s/COMPPRIVIP/${COMPUTEPRIVIP}/" -e "s/CTRLPUBIP/${CONTROLLERPUBIP}/" \
	-e "s/RPWD/${RABBITMQPWD}/" -e "s/NPWD/${NEUTRONPWD}/" -e "s/PWD/${NOVAPWD}/" \
	/vagrant/files/nova/nova.conf.compute.orig > /etc/nova/nova.conf

sed -e "s/VCENTER_PASS/${VCENTER_PASS}/" -e "s/VCENTER_USER/${VCENTER_USER}/" \
    -e "s/VCENTER_IP/${VCENTER_IP}/" -e "s/VCENTER_CLUSTER/${VCENTER_CLUSTER}/" \
    -e "s/DATASTORE_REGEX/${DATASTORE_REGEX}/" /vagrant/files/nova/nova-compute.conf.vmware.orig > /etc/nova/nova-compute.conf

echo "Copying environment scripts..."
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${ADMINPWD}/" /vagrant/files/admin-openrc.sh.orig > /home/vagrant/admin-openrc.sh
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${ADMINPWD}/" /vagrant/files/admin-openrc.sh.orig > /root/admin-openrc.sh
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${DEMOPWD}/" /vagrant/files/demo-openrc.sh.orig > /home/vagrant/demo-openrc.sh
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${DEMOPWD}/" /vagrant/files/demo-openrc.sh.orig > /root/demo-openrc.sh

service nova-compute restart
rm -f /var/lib/nova/nova.sqlite

echo "Configuring Neutron on Compute Node..."
apt-get -qq -y --force-yes install neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/NPWD/${NEUTRONPWD}/" \
	-e "s/RPWD/${RABBITMQPWD}/" /vagrant/files/neutron/neutron.conf.compute.orig > /etc/neutron/neutron.conf
sed -e "s/LOCALIP/${COMPUTELOCALIP}/" /vagrant/files/neutron/ml2_conf.ini.compute.orig > /etc/neutron/plugins/ml2/ml2_conf.ini
service openvswitch-switch restart
service neutron-plugin-openvswitch-agent restart

echo "Installing and Configuring Telemetry on Compute node..."
apt-get -qq -y --force-yes install ceilometer-agent-compute
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/RABBIT_PASS/${RABBITMQPWD}/" -e "s/CEILOMETER_PASS/${CEILOMETER_PASS}/" \
	/vagrant/files/ceilometer/ceilometer.conf.compute.orig > /etc/ceilometer/ceilometer.conf
service ceilometer-agent-compute restart
