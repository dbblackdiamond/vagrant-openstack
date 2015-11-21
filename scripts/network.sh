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

echo "Setting up the Network Node..."
echo "Setting up /etc/hosts..."
cat /vagrant/files/hosts >> /etc/hosts

echo "Bringing up the outside interface..."
ifconfig ${EXTIF} up promisc
sed -e "s/EXTIF/${EXTIF}/" /vagrant/files/neutron/rc.local.network.orig > /etc/rc.local

echo "Copying resource scripts..."
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${ADMINPWD}/" /vagrant/files/admin-openrc.sh.orig > /home/vagrant/admin-openrc.sh
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${ADMINPWD}/" /vagrant/files/admin-openrc.sh.orig > /root/admin-openrc.sh
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${DEMOPWD}/" /vagrant/files/demo-openrc.sh.orig > /home/vagrant/demo-openrc.sh
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${DEMOPWD}/" /vagrant/files/demo-openrc.sh.orig > /root/demo-openrc.sh

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

echo "Configuring Neutron on Network Node..."
cat /vagrant/files/neutron/sysctl.conf.network >> /etc/sysctl.conf
sysctl -p

apt-get -qq -y --force-yes install neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/NPWD/${NEUTRONPWD}/" \
	-e "s/RPWD/${RABBITMQPWD}/" /vagrant/files/neutron/neutron.conf.network.orig > /etc/neutron/neutron.conf
sed -e "s/LOCALIP/${LOCALIP}/" /vagrant/files/neutron/ml2_conf.ini.network.orig > /etc/neutron/plugins/ml2/ml2_conf.ini
cp /vagrant/files/neutron/l3_agent.ini.network.orig /etc/neutron/l3_agent.ini
cp /vagrant/files/neutron/dhcp_agent.ini.network.orig /etc/neutron/dhcp_agent.ini
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/NPWD/${NEUTRONPWD}/" \
	-e "s/SHAREDSECRET/${SHAREDSECRET}/" /vagrant/files/neutron/metadata_agent.ini.network.orig > /etc/neutron/metadata_agent.ini

service openvswitch-switch restart

echo "Creating Open vSwitch..."
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex ${EXTIF}
for i in plugin-openvswitch-agent l3-agent dhcp-agent metadata-agent; do
	service neutron-${i} restart
done

echo "Creating external network..."
source /root/admin-openrc.sh
sleep 10
neutron net-create ext-net --router:external --provider:physical_network external --provider:network_type flat
echo "Creating external subnet..."
neutron subnet-create ext-net ${EXTSUB}/24 --name ext-subnet --allocation-pool start=${POOLSTART},end=${POOLEND} --disable-dhcp --gateway ${EXTGW}

echo "Creating tenant network and subnet..."
source /home/vagrant/demo-openrc.sh
neutron net-create demo-net
neutron subnet-create demo-net ${DEMOSUB}/24 --name demo-subnet --gateway ${DEMOGW}
neutron router-create demo-router
neutron router-interface-add demo-router demo-subnet
neutron router-gateway-set demo-router ext-net
