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

echo "Setting up the Controller Server..."
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
cp /vagrant/files/keystone/controller_ntp.conf.orig /etc/ntp.conf

echo "Configuring RabbitMQ..."
apt-get -qq -y --force-yes install rabbitmq-server
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" /vagrant/files/keystone/rabbitmq-env.conf.orig > /etc/rabbitmq/rabbitmq-env.conf
service rabbitmq-server restart
sleep 10
rabbitmqctl add_user openstack ${RABBITMQPWD}
rabbitmqctl set_user_tags openstack administrator
rabbitmqctl set_permissions -p '/' openstack ".*" ".*" ".*"

echo "Installing and Configuring database server..."
DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< "mariadb-server mysql-server/root_password password ${ROOTPWD}"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password ${ROOTPWD}" 
apt-get -qq -y --force-yes install mariadb-server python-mysqldb
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" /vagrant/files/keystone/controller_mysqld_openstack.cnf.orig > /etc/mysql/conf.d/mysqld_openstack.cnf
service mysql restart
echo -e "${ROOTPWD}\nn\ny\ny\ny\ny\n" | mysql_secure_installation 2> /dev/null

echo "Configuring All Controller's Databases..."
mysql -u root -p${ROOTPWD} << EOF
create database keystone;
grant all privileges on keystone.* to 'keystone'@'localhost' identified by '${KEYSTONEPWD}';
grant all privileges on keystone.* to 'keystone'@'%' identified by '${KEYSTONEPWD}';
create database glance;
grant all privileges on glance.* to 'glance'@'localhost' identified by '${GLANCEPWD}';
grant all privileges on glance.* to 'glance'@'%' identified by '${GLANCEPWD}';
create database nova;
grant all privileges on nova.* to 'nova'@'localhost' identified by '${NOVAPWD}';
grant all privileges on nova.* to 'nova'@'%' identified by '${NOVAPWD}';
create database neutron;
grant all privileges on neutron.* to 'neutron'@'localhost' identified by '${NEUTRONPWD}';
grant all privileges on neutron.* to 'neutron'@'%' identified by '${NEUTRONPWD}';
create database cinder;
grant all privileges on cinder.* to 'cinder'@'localhost' identified by '${CINDER_PASS}';
grant all privileges on cinder.* to 'cinder'@'%' identified by '${CINDER_PASS}';
EOF

echo "Setting up admin token..."
TOKEN=`openssl rand -hex 10`

echo "Configuring Keystone Pre-requisites..."
echo "manual" > /etc/init/keystone.override
apt-get -qq -y --force-yes install keystone python-openstackclient apache2 libapache2-mod-wsgi memcached python-memcache
sed -e "s/PWD/${KEYSTONEPWD}/" -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/rand_token/${TOKEN}/" /vagrant/files/keystone/keystone.conf.orig > /etc/keystone/keystone.conf
su -s /bin/sh -c "keystone-manage db_sync" keystone
sed -e "s/CTRLHOST/${CONTROLLERNAME}/" /vagrant/files/keystone/apache2.conf.orig > /etc/apache2/apache2.conf
cp /vagrant/files/keystone/wsgi-keystone.conf /etc/apache2/sites-available/wsgi-keystone.conf
ln -s /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled
mkdir -p /var/www/cgi-bin/keystone
if [ ${VERSION} == "kilo" ]; then
    curl http://git.openstack.org/cgit/openstack/keystone/plain/httpd/keystone.py?h=stable/kilo | tee /var/www/cgi-bin/keystone/main /var/www/cgi-bin/keystone/admin
elif [ ${VERSION} == "liberty" ]; then
    curl http://git.openstack.org/cgit/openstack/keystone/plain/httpd/keystone.py?h=stable/liberty | tee /var/www/cgi-bin/keystone/main /var/www/cgi-bin/keystone/admin
fi
chown -R keystone:keystone /var/www/cgi-bin/keystone
chmod 755 /var/www/cgi-bin/keystone/*
service apache2 restart
rm -f /var/lib/keystone/keystone.db

echo "Configuring Keystone..."
export OS_TOKEN=${TOKEN}
export OS_URL=http://${CONTROLLERPRIVATEIP}:35357/v2.0
openstack service create --name keystone --description "Openstack Identity" identity
openstack endpoint create --publicurl http://${CONTROLLERPRIVATEIP}:5000/v2.0 --internalurl http://${CONTROLLERPRIVATEIP}:5000/v2.0 --adminurl http://${CONTROLLERPRIVATEIP}:35357/v2.0 --region RegionOne identity
openstack project create --description "Admin Porject" admin
openstack user create --password ${ADMINPWD} admin
openstack role create admin
openstack role add --project admin --user admin admin
openstack project create --description "Service Project" service
openstack project create --description "Demo Project" demo
openstack user create --password ${DEMOPWD} demo
openstack role create user
openstack role add --project demo --user demo user

echo "Copying resource scripts..."
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${ADMINPWD}/" /vagrant/files/admin-openrc.sh.orig > /home/vagrant/admin-openrc.sh
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${ADMINPWD}/" /vagrant/files/admin-openrc.sh.orig > /root/admin-openrc.sh
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${DEMOPWD}/" /vagrant/files/demo-openrc.sh.orig > /root/demo-openrc.sh
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/PWD/${DEMOPWD}/" /vagrant/files/demo-openrc.sh.orig > /home/vagrant/demo-openrc.sh

echo "Installing Glance..."
apt-get -qq -y --force-yes install glance python-glanceclient qemu-utils
source /root/admin-openrc.sh
openstack user create --password ${GLANCEPWD} glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "Openstack Image Service" image
openstack endpoint create --public http://${CONTROLLERPRIVATEIP}:9292 --internalurl http://${CONTROLLERPRIVATEIP}:9292 --adminurl http://${CONTROLLERPRIVATEIP}:9292 --region RegionOne image

sed -e "s/PWD/${GLANCEPWD}/" -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/RABBIT_PASS/${RABBITMQPWD}/" \
	/vagrant/files/glance/glance-api.conf.orig > /etc/glance/glance-api.conf
sed -e "s/PWD/${GLANCEPWD}/" -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/RABBIT_PASS/${RABBITMQPWD}/" \
	/vagrant/files/glance/glance-registry.conf.orig > /etc/glance/glance-registry.conf
su -s /bin/sh -c "glance-manage db_sync" glance
service glance-registry restart
service glance-api restart
rm -f /var/lib/glance/glance.sqlite

echo "Testing Image Service..."
mkdir /tmp/images
echo "Downloading Cirros Image..."
wget -P /tmp/images http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
echo "Done downloading Cirros Image..."
glance image-create --name "cirros-0.3.4-x86_64" --file /tmp/images/cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --visibility public --progress
if [ ${VMWARE} == "true" ]; then
    qemu-img convert -f qcow2 /tmp/images/cirros-0.3.4-x86_64-disk.img -O vmdk /tmp/images/cirros-0.3.4-x86_64-disk.vmdk
    glance image-create --name "cirros-0.3.4-x86_64-vmware" --container-format bare --disk-format vmdk \
        --property vmware_disktype="sparse" --property vmware_adaptertype="ide" --visibility public \
        --file /tmp/images/cirros-0.3.4-x86_64-disk.vmdk --progress
fi
rm -r /tmp/images

echo "Configuring Nova Controller..."
apt-get -qq -y --force-yes install nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient
openstack user create --password ${NOVAPWD} nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "Openstack Compute" compute
openstack endpoint create --publicurl http://${CONTROLLERPRIVATEIP}:8774/v2/%\(tenant_id\)s \
  --internalurl http://${CONTROLLERPRIVATEIP}:8774/v2/%\(tenant_id\)s \
  --adminurl http://${CONTROLLERPRIVATEIP}:8774/v2/%\(tenant_id\)s \
  --region RegionOne \
  compute

sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/CTRLPIP/${CONTROLLERPUBLICIP}/" \
	-e "s/NPWD/${NEUTRONPWD}/" -e "s/RPWD/${RABBITMQPWD}/" \
	-e "s/PWD/${NOVAPWD}/" /vagrant/files/nova/nova.conf.controller.orig > /etc/nova/nova.conf
su -s /bin/sh -c "nova-manage db sync" nova
for i in api cert consoleauth scheduler conductor novncproxy; do
	service nova-${i} restart
done
rm -f /var/lib/nova/nova.sqlite

echo "Configuring Neutron on the Controller..."
openstack user create --password ${NEUTRONPWD} neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "Openstack Networking" network
openstack endpoint create \
  --publicurl http://${CONTROLLERPRIVATEIP}:9696 \
  --adminurl http://${CONTROLLERPRIVATEIP}:9696 \
  --internalurl http://${CONTROLLERPRIVATEIP}:9696 \
  --region RegionOne \
  network
apt-get -qq -y --force-yes install neutron-server neutron-plugin-ml2 python-neutronclient
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/NPWD/${NOVAPWD}/" -e "s/RPWD/${RABBITMQPWD}/" \
	-e "s/PWD/${NEUTRONPWD}/" /vagrant/files/neutron/neutron.conf.controller.orig > /etc/neutron/neutron.conf
cp /vagrant/files/neutron/ml2_conf.ini.controller.orig /etc/neutron/plugins/ml2/ml2_conf.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
service nova-api restart
service neutron-server restart

echo "Installing the dashboard..."
apt-get -qq -y --force-yes install openstack-dashboard
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" /vagrant/files/horizon/local_settings.py.controller.orig > /etc/openstack-dashboard/local_settings.py
service apache2 restart

echo "Installing and Configuring Cinder..."
source /root/admin-openrc.sh
echo "Cinder password: ${CINDER_PASS}..."
openstack user create --password ${CINDER_PASS} cinder
openstack role add --project service --user cinder admin
openstack service create --name cinder --description "OpenStack Block Storage" volume
openstack service create --name cinderv2 --description "Openstack Block Storage" volumev2
openstack endpoint create \
  --publicurl http://${CONTROLLERPRIVATEIP}:8776/v2/%\(tenant_id\)s \
  --internalurl http://${CONTROLLERPRIVATEIP}:8776/v2/%\(tenant_id\)s \
  --adminurl http://${CONTROLLERPRIVATEIP}:8776/v2/%\(tenant_id\)s \
  --region RegionOne \
  volume
openstack endpoint create \
  --publicurl http://${CONTROLLERPRIVATEIP}:8776/v2/%\(tenant_id\)s \
  --internalurl http://${CONTROLLERPRIVATEIP}:8776/v2/%\(tenant_id\)s \
  --adminurl http://${CONTROLLERPRIVATEIP}:8776/v2/%\(tenant_id\)s \
  --region RegionOne \
  volumev2
apt-get -qq -y --force-yes install cinder-api cinder-scheduler python-cinderclient
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/RABBIT_PASS/${RABBITMQPWD}/" \
        -e "s/CINDER_PASS/${CINDER_PASS}/" /vagrant/files/cinder/cinder.conf.controller.orig > /etc/cinder/cinder.conf
su -s /bin/sh -c "cinder-manage db sync" cinder
service cinder-scheduler restart
service cinder-api restart
rm -f /var/lib/cinder/cinder.sqlite

echo "Installing and Configuring Telemetry..."
apt-get -qq -y --force-yes install mongodb-server mongodb-clients python-pymongo
service mongodb stop
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" /vagrant/files/ceilometer/mongodb.conf.controller.orig > /etc/mongodb.conf 
rm /var/lib/mongodb/journal/prealloc.*
service mongodb start
sleep 10
mongo --host ${CONTROLLERPRIVATEIP} --eval "db = db.getSiblingDB(\"ceilometer\"); db.addUser({user:\"ceilometer\", pwd: \"${CEILOMETER_PASS}\", roles: [\"readWrite\", \"dbAdmin\"]})"
openstack user create --password ${CEILOMETER_PASS} ceilometer
openstack role add --project service --user ceilometer admin
openstack service create --name ceilometer --description "Telemetry" metering
openstack endpoint create \
  --publicurl http://${CONTROLLERPRIVATEIP}:8777 \
  --internalurl http://${CONTROLLERPRIVATEIP}:8777 \
  --adminurl http://${CONTROLLERPRIVATEIP}:8777 \
  --region RegionOne \
  metering
apt-get -qq -y --force-yes install ceilometer-api ceilometer-collector ceilometer-agent-central \
  ceilometer-agent-notification ceilometer-alarm-evaluator ceilometer-alarm-notifier \
  python-ceilometerclient
sed -e "s/CTRLIP/${CONTROLLERPRIVATEIP}/" -e "s/CEILOMETER_PASS/${CEILOMETER_PASS}/" \
	-e "s/RABBIT_PASS/${RABBITMQPWD}/" \
	/vagrant/files/ceilometer/ceilometer.conf.controller.orig > /etc/ceilometer/ceilometer.conf

for i in agent-central agent-notification api collector alarm-evaluator alarm-notifier; do
	service ceilometer-${i} restart
done


# echo "Installing and Configuring Swift..."
# openstack user create --password ${SWIFT_PASS} swift
# openstack role add --project service --user swift admin
# openstack service create --name swift --description "OpenStack Object Storage" object-store
# openstack endpoint create \
#   --publicurl 'http://${CTRLIP}:8080/v1/AUTH_%(tenant_id)s' \
#   --internalurl 'http://${CTRLIP}:8080/v1/AUTH_%(tenant_id)s' \
#   --adminurl http://${CTRLIP}:8080 \
#   --region RegionOne \
#   object-store
# apt-get -qq -y --force-yes swift swift-proxy python-swiftclient python-keystoneclient python-keystonemiddleware memcached
# sed -e "s/CTRLIP/${CTRLIP}/" -e "s/SWIFT_PASS/${SWIFT_PASS}/" /vagrant/files/swift/proxy-server.conf.controller.orig > /etc/swift/proxy-server.conf
