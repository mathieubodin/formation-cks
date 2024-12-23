Vagrant.configure("2") do |config|
    config.vm.synced_folder '.', '/vagrant', disabled: true

    config.vm.define "vm1" do |vm_config|
        vm_config.vm.provider "virtualbox" do |vb, override|
            override.vm.box = "ubuntu/focal64"
            vb.name = "vm1"
            vb.gui = false
            vb.check_guest_additions = false
            vb.cpus = 2
            vb.memory = 4096
            vb.customize ["modifyvm", :id, "--groups", "/cks-cluster"]
            vb.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
            override.vm.disk :disk, primary: true, size: "50GB"
            override.vm.synced_folder "./formation", "/home/vagrant/cks"
            override.vm.network "private_network", ip: "172.16.0.2", hostname: true
        end

        vm_config.vm.provider :libvirt do |lv, override|
            override.vm.box = "alvistack/ubuntu-20.04"
            override.vm.box_version = "20241215.1.1"
            lv.default_prefix = "formation-cks-"
            lv.memory = 3072
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
        vm_config.vm.network "forwarded_port", guest: 80, host: 80, auto_correct: true
        vm_config.vm.network "forwarded_port", guest: 443, host: 443, auto_correct: true
        # (30000..32767).each do |port|
        #     vm_config.vm.network "forwarded_port", guest: port, host: port, auto_correct: true
        # end
        vm_config.vm.provision "shell", inline: <<-SHELL
            apt update
            apt upgrade -y
            apt autoremove -y
        SHELL
    end

    config.vm.define "vm2" do |vm_config|
        vm_config.vm.provider :virtualbox do |vb, override|
            override.vm.box = "ubuntu/focal64"
            vb.name = "vm2"
            vb.gui = false
            vb.check_guest_additions = false
            vb.cpus = 2
            vb.memory = 3072
            vb.customize ["modifyvm", :id, "--groups", "/cks-cluster"]
            vb.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
            override.vm.disk :disk, primary: true, size: "50GB"
            override.vm.synced_folder "./formation", "/home/vagrant/cks"
            override.vm.network "private_network", ip: "172.16.0.3", hostname: true
        end

        vm_config.vm.provider :libvirt do |lv, override|
            override.vm.box = "alvistack/ubuntu-20.04"
            override.vm.box_version = "20241215.1.1"
            lv.default_prefix = "formation-cks-"
            lv.memory = 4096
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
            apt update
            apt upgrade -y
            apt autoremove -y
        SHELL
    end
end