Vagrant.configure("2") do |config|
    config.vm.synced_folder '.', '/vagrant', disabled: true
    config.ssh.extra_args = ["-t", "cd /home/vagrant/cks; bash --login"]

    config.vm.define "vm1" do |vm_config|
        vm_config.vm.provider "virtualbox" do |vb, override|
            override.vm.box = "ubuntu/focal64"
            vb.name = "vm1"
            vb.gui = false
            vb.check_guest_additions = false
            vb.cpus = 2
            vb.memory = 2048
            vb.customize ["modifyvm", :id, "--groups", "/cks-cluster"]
            vb.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
            override.vm.disk :disk, primary: true, size: "50GB"
            override.vm.synced_folder "./formation", "/home/vagrant/cks"
            override.vm.network "private_network",
                ip: "172.16.0.2",
                virtualbox__intnet: "formation-cks",
                hostname: true
        end

        vm_config.vm.provider :libvirt do |lv, override|
            override.vm.box = "alvistack/ubuntu-20.04"
            override.vm.box_version = "20241215.1.1"
            lv.default_prefix = "formation-cks-"
            lv.memory = 2048
            lv.cpus = 2
            lv.forward_ssh_port = true
            lv.nested = true
            lv.machine_virtual_size = 50
            lv.graphics_type = "none"
            lv.inputs = []
            override.vm.synced_folder "./formation", "/home/vagrant/cks",
                type: "nfs",
                nfs_version: "4",
                nfs_udp: false
            override.vm.network :private_network, 
                ip: "172.16.0.2",
                hostname: true,
                libvirt__network_name: "formation-cks",
                libvirt__dhcp_enabled: false,
                libvirt__netmask: "255.255.255.0"
        end

        vm_config.vm.hostname = "cks-master"
        vm_config.vm.network "forwarded_port", guest: 30080, host: 8080, auto_correct: true
        vm_config.vm.network "forwarded_port", guest: 30443, host: 8443, auto_correct: true
        vm_config.vm.provision "shell", inline: <<-SHELL
            apt update \
            && apt upgrade -y \
            && apt autoremove -y
        SHELL
    end

    config.vm.define "vm2" do |vm_config|
        vm_config.vm.provider :virtualbox do |vb, override|
            override.vm.box = "ubuntu/focal64"
            vb.name = "vm2"
            vb.gui = false
            vb.check_guest_additions = false
            vb.cpus = 2
            vb.memory = 2048
            vb.customize ["modifyvm", :id, "--groups", "/cks-cluster"]
            vb.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
            override.vm.disk :disk, primary: true, size: "50GB"
            override.vm.synced_folder "./formation", "/home/vagrant/cks"
            override.vm.network "private_network",
                ip: "172.16.0.3",
                virtualbox__intnet: "formation-cks",
                hostname: true
        end

        vm_config.vm.provider :libvirt do |lv, override|
            override.vm.box = "alvistack/ubuntu-20.04"
            override.vm.box_version = "20241215.1.1"
            lv.default_prefix = "formation-cks-"
            lv.memory = 2048
            lv.cpus = 2
            lv.forward_ssh_port = true
            lv.nested = true
            lv.machine_virtual_size = 50
            lv.graphics_type = "none"
            lv.inputs = []
            override.vm.synced_folder "./formation", "/home/vagrant/cks", 
                type: "nfs",
                nfs_version: "4",
                nfs_udp: false
            override.vm.network :private_network, 
                ip: "172.16.0.3",
                hostname: true,
                libvirt__network_name: "formation-cks",
                libvirt__dhcp_enabled: false,
                libvirt__netmask: "255.255.255.0"
        end

        vm_config.vm.hostname = "cks-worker"
        vm_config.vm.provision "shell", inline: <<-SHELL
            apt update \
            && apt upgrade -y \
            && apt autoremove -y
        SHELL
    end

    config.vm.define "vm3" do |vm_config|
        vm_config.vm.provider :virtualbox do |vb, override|
            override.vm.box = "ubuntu/focal64"
            vb.name = "vm3"
            vb.gui = false
            vb.check_guest_additions = false
            vb.cpus = 2
            vb.memory = 2048
            vb.customize ["modifyvm", :id, "--groups", "/cks-cluster"]
            vb.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
            override.vm.disk :disk, primary: true, size: "50GB"
            override.vm.synced_folder "./formation", "/home/vagrant/cks"
            override.vm.network "private_network",
                ip: "172.16.0.4",
                virtualbox__intnet: "formation-cks",
                hostname: true
        end

        vm_config.vm.provider :libvirt do |lv, override|
            override.vm.box = "alvistack/ubuntu-20.04"
            override.vm.box_version = "20241215.1.1"
            lv.default_prefix = "formation-cks-"
            lv.memory = 2048
            lv.cpus = 2
            lv.forward_ssh_port = true
            lv.nested = true
            lv.machine_virtual_size = 50
            lv.graphics_type = "none"
            lv.inputs = []
            override.vm.synced_folder "./formation", "/home/vagrant/cks", 
                type: "nfs",
                nfs_version: "4",
                nfs_udp: false
            override.vm.network :private_network, 
                ip: "172.16.0.4",
                hostname: true,
                libvirt__network_name: "formation-cks",
                libvirt__dhcp_enabled: false,
                libvirt__netmask: "255.255.255.0"
        end

        vm_config.vm.hostname = "cks-worker-gvisor"
        vm_config.vm.provision "shell", inline: <<-SHELL
            apt update \
            && apt upgrade -y \
            && apt autoremove -y
        SHELL
    end
end