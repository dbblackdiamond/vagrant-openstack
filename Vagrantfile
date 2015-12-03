# -*- mode: ruby -*-
# vi: set ft=ruby :
#
require 'yaml'

# Loading the configuration fine
env = YAML.load_file("config/config.yml")

# TBD Create a configuration file for each node so the script can just source it and get all the right variables

# We need to figure out what the addresses of the controller are, as we need them to set up some of the nodes
controllerip = "0.0.0.0"
controllerpubip = "0.0.0.0"
env['nodes'].split(',').each do |node|
	if env[node]['role'] == "controller"
		controllerip = env[node]['mgmtip']
		controllerpubip = env[node]['extip']
	end
end

# Creation of the host file that will be distributed to all the nodes
fname = File.open('files/hosts', 'w+')
env['nodes'].split(',').each do |node|
    line = env[node]['mgmtip'] + "\t" + env[node]['name'] + "\t"
    fname.puts line
    line = env[node]['tunip'] + "\t" + env[node]['name'] + "-tun\n"
    fname.puts line
end
fname.close

# Figure out what the version is that we are trying to install
version = env['version']

Vagrant.configure(2) do |config|
	env['nodes'].split(',').each do |node|
		name = env[node]['name']
		mgmtip = env[node]['mgmtip']
		extip = env[node]['extip']
		tunip = env[node]['tunip']
		config.vm.define name do |node_config|
			node_config.vm.box = "ubuntu/trusty64"
			node_config.ssh.insert_key = false
			node_config.vm.host_name = "#{name}"
			if env[node]['role'] == "controller"
                # Creating and Opening the configuration file for the provisoining script
                fconfig = File.open("files/#{name}.cfg", "w+")
                fconfig.puts "VERSION=#{version}\n"
                fconfig.puts "CONTROLLERNAME=#{name}\n"
                fconfig.puts "CONTROLLERPUBLICIP=#{extip}\n"
                fconfig.puts "CONTROLLERPRIVATEIP=#{mgmtip}\n"
                fconfig.puts "ADMINPWD=#{env['password']['admin']}\n"
                fconfig.puts "DEMOPWD=#{env['password']['demo']}\n"
                fconfig.puts "KEYSTONEPWD=#{env['password']['keystone']}\n"
                fconfig.puts "RABBITMQPWD=#{env['password']['rabbit']}\n"
                fconfig.puts "ROOTPWD=#{env['password']['root']}\n"
                fconfig.puts "GLANCEPWD=#{env['password']['glance']}\n"
                fconfig.puts "NOVAPWD=#{env['password']['nova']}\n"
                fconfig.puts "NEUTRONPWD=#{env['password']['neutron']}\n"
                fconfig.puts "CINDER_PASS=#{env['password']['cinder']}\n"
                fconfig.puts "CEILOMETER_PASS=#{env['password']['ceilometer']}\n"
                fconfig.puts "VMWARE=#{env[node]['vmware']}\n"
                fconfig.close
                # Customizing the VM based on the info in the config file
				node_config.vm.provider "virtualbox" do |vb|
					vb.memory = env[node]['memory']
                    vb.cpus = env[node]['cpu']
				end
				node_config.vm.network "public_network", bridge: "p4p1", ip: "#{extip}"
				node_config.vm.network "private_network", ip: "#{mgmtip}", intnet: "openstack_internal"
				node_config.vm.network "private_network", ip: "#{tunip}", intnet: "openstack_tunnel"
				node_config.vm.synced_folder ".", "/vagrant"
				node_config.vm.provision "shell" do |s|
					s.path = "scripts/controller.sh"
					s.args = "-c /vagrant/files/#{name}.cfg"
				end
			elsif env[node]['role'] == "compute"
                # Creating and Opening the configuration file for the provisoining script
                fconfig = File.open("files/#{name}.cfg", "w+")
                fconfig.puts "VERSION=#{version}\n"
                fconfig.puts "CONTROLLERPUBLICIP=#{controllerpubip}\n"
                fconfig.puts "CONTROLLERPRIVATEIP=#{controllerip}\n"
                fconfig.puts "ADMINPWD=#{env['password']['admin']}\n"
                fconfig.puts "DEMOPWD=#{env['password']['demo']}\n"
                fconfig.puts "RABBITMQPWD=#{env['password']['rabbit']}\n"
                fconfig.puts "ROOTPWD=#{env['password']['root']}\n"
                fconfig.puts "NOVAPWD=#{env['password']['nova']}\n"
                fconfig.puts "NEUTRONPWD=#{env['password']['neutron']}\n"
                fconfig.puts "COMPUTEPUBIP=#{extip}\n"
                fconfig.puts "COMPUTELOCALIP=#{tunip}\n"
                fconfig.puts "COMPUTEPRIVIP=#{mgmtip}\n"
                fconfig.close
				node_config.vm.provider "virtualbox" do |vb|
					vb.memory = env[node]['memory']
                    vb.cpus = env[node]['cpu']
				end
				node_config.vm.network "public_network", bridge: "p4p1", ip: "#{extip}"
				node_config.vm.network "private_network", ip: "#{mgmtip}", intnet: "openstack_internal"
				node_config.vm.network "private_network", ip: "#{tunip}", intnet: "openstack_tunnel"
				node_config.vm.synced_folder ".", "/vagrant"
				node_config.vm.provision "shell" do |s|
					s.path = "scripts/compute.sh"
					s.args = "-c /vagrant/files/#{name}.cfg"
				end
			elsif env[node]['role'] == "vmware"
                # Creating and Opening the configuration file for the provisoining script
                fconfig = File.open("files/#{name}.cfg", "w+")
                fconfig.puts "VERSION=#{version}\n"
                fconfig.puts "CONTROLLERPUBLICIP=#{controllerpubip}\n"
                fconfig.puts "CONTROLLERPRIVATEIP=#{controllerip}\n"
                fconfig.puts "ADMINPWD=#{env['password']['admin']}\n"
                fconfig.puts "DEMOPWD=#{env['password']['demo']}\n"
                fconfig.puts "RABBITMQPWD=#{env['password']['rabbit']}\n"
                fconfig.puts "ROOTPWD=#{env['password']['root']}\n"
                fconfig.puts "NOVAPWD=#{env['password']['nova']}\n"
                fconfig.puts "NEUTRONPWD=#{env['password']['neutron']}\n"
                fconfig.puts "COMPUTEIP=#{extip}\n"
                fconfig.puts "COMPUTELOCALIP=#{tunip}\n"
                fconfig.puts "COMPUTEPRIVIP=#{mgmtip}\n"
                fconfig.puts "VCENTER_PASS=#{env[node]['vcenter_pass']}\n"
                fconfig.puts "VCENTER_USER=#{env[node]['vcenter_user']}\n"
                fconfig.puts "VCENTER_IP=#{env[node]['vcenter_ip']}\n"
                fconfig.puts "VCENTER_CLUSTER=#{env[node]['vcenter_cluster']}\n"
                fconfig.puts "DATASTORE_REGEX=#{env[node]['datastore_regex']}\n"
                fconfig.close
				node_config.vm.provider "virtualbox" do |vb|
					vb.memory = env[node]['memory']
                    vb.cpus = env[node]['cpu']
				end
				node_config.vm.network "public_network", bridge: "p4p1", ip: "#{extip}"
				node_config.vm.network "private_network", ip: "#{mgmtip}", intnet: "openstack_internal"
				node_config.vm.network "private_network", ip: "#{tunip}", intnet: "openstack_tunnel"
				node_config.vm.synced_folder ".", "/vagrant"
				node_config.vm.provision "shell" do |s|
					s.path = "scripts/vmware.sh"
					s.args = "-c /vagrant/files/#{name}.cfg"
				end
			elsif env[node]['role'] == "network"
                # Creating and Opening the configuration file for the provisoining script
                fconfig = File.open("files/#{name}.cfg", "w+")
                fconfig.puts "VERSION=#{version}\n"
                fconfig.puts "CONTROLLERPRIVATEIP=#{controllerip}\n"
                fconfig.puts "ADMINPWD=#{env['password']['admin']}\n"
                fconfig.puts "DEMOPWD=#{env['password']['demo']}\n"
                fconfig.puts "RABBITMQPWD=#{env['password']['rabbit']}\n"
                fconfig.puts "NOVAPWD=#{env['password']['nova']}\n"
                fconfig.puts "NEUTRONPWD=#{env['password']['neutron']}\n"
                fconfig.puts "SHAREDSECRET=#{env[node]['sharedsecret']}\n"
                fconfig.puts "EXTIF=#{env[node]['extif']}\n"
                fconfig.puts "EXTSUB=#{env[node]['extsubnet']}\n"
                fconfig.puts "EXTGW=#{env[node]['extgw']}\n"
                fconfig.puts "POOLSTART=#{env[node]['poolipstart']}\n"
                fconfig.puts "POOLEND=#{env[node]['poolipend']}\n"
                fconfig.puts "DEMOSUB=#{env[node]['demosubnet']}\n"
                fconfig.puts "DEMOGW=#{env[node]['demogw']}\n"
                fconfig.puts "LOCALIP=#{env[node]['tunip']}\n"
                fconfig.close
				node_config.vm.network "public_network", bridge: "p4p1", auto_config: false
				node_config.vm.network "private_network", ip: "#{mgmtip}", intnet: "openstack_internal"
				node_config.vm.network "private_network", ip: "#{tunip}", intnet: "openstack_tunnel"
				node_config.vm.synced_folder ".", "/vagrant"

				node_config.vm.provider "virtualbox" do |vb|
					vb.memory = env[node]['memory']
                    vb.cpus = env[node]['cpu']
                    vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
				end
				node_config.vm.provision "shell" do |s|
					s.path = "scripts/network.sh"
					s.args = "-c /vagrant/files/#{name}.cfg"
				end
			elsif env[node]['role'] == "block"
                # Creating and Opening the configuration file for the provisoining script
                fconfig = File.open("files/#{name}.cfg", "w+")
                fconfig.puts "VERSION=#{version}\n"
                fconfig.puts "CONTROLLERPRIVATEIP=#{controllerip}\n"
                fconfig.puts "RABBITMQPWD=#{env['password']['rabbit']}\n"
                fconfig.puts "CINDER_PASS=#{env['password']['cinder']}\n"
                fconfig.puts "PRIVATEIP=#{extip}\n"
				sdbsize = env[node]['size'] * 1024
                fconfig.puts "SDBSIZE=#{sdbsize}\n"
                fconfig.close
				node_config.vm.provider "virtualbox" do |vb|
					unless File.exist?(env[node]['disk'])
						vb.customize ['createhd', '--filename', env[node]['disk'], '--variant', 'Fixed', '--size', sdbsize]
					end
					vb.customize ['storageattach', :id, '--storagectl', 'SATAController', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', env[node]['disk']]
					vb.memory = env[node]['memory']
                    vb.cpus = env[node]['cpu']
				end
				node_config.vm.network "public_network", bridge: "p4p1", ip: "#{extip}"
				node_config.vm.network "private_network", ip: "#{mgmtip}", intnet: "openstack_internal"
				node_config.vm.network "private_network", ip: "#{tunip}", intnet: "openstack_tunnel"
				node_config.vm.synced_folder ".", "/vagrant"
				node_config.vm.provision "shell" do |s|
					s.path = "scripts/block.sh"
					s.args = "-c /vagrant/files/#{name}.cfg"
				end
            end
		end
	end
end
