Vagrant.configure("2") do |config|
    

    config.vm.define "vm1" do |vm1|
        vm1.vm.provider "virtualbox" do |vb, override|
            ovveride.vm.box = "ubuntu/focal64"
            vb.name = "vm1"
            vb.gui = false
            vb.check_guest_additions = false
            vb.cpus = 2
            vb.memory = 4096
            vb.customize ["modifyvm", :id, "--groups", "/cks-cluster"]
            vb.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
            override.vm.disk :disk, primary: true, size: "50GB"
            override.vm.synced_folder "./formation", "/home/vagrant/cks"
        end

        vm1.vm.provider :libvirt do |v, override|
            override.vm.box = "alvistack/ubuntu-20.04"
            override.vm.box_version = "20241215.1.1"
            v.default_prefix = "formation-cks-"
            v.memory = 4096
            v.cpus = 2
            v.forward_ssh_port = true
            v.nested = true
            v.machine_virtual_size = 50
            v.graphics_type = "none"
            v.inputs = []
            override.vm.synced_folder "./formation", "/home/vagrant/cks",
                type: "nfs",
                nfs_version: "4",
                nfs_udp: false
        end

        vm1.vm.hostname = "cks-master"
        vm1.vm.network "private_network", ip: "172.16.0.2", hostname: true
        vm1.vm.network "forwarded_port", guest: 8080, host: 8080, auto_correct: true
        vm1.vm.network "forwarded_port", guest: 8443, host: 8443, auto_correct: true
        (30000..32767).each do |port|
            vm1.vm.network "forwarded_port", guest: port, host: port, auto_correct: true
        end
        vm1.vm.provision "shell", inline: <<-SHELL
            apt update
            apt upgrade -y
            apt autoremove -y
        SHELL
    end

    config.vm.define "vm2" do |vm2|
        vm2.vm.provider "virtualbox" do |vb, override|
            ovveride.vm.box = "ubuntu/focal64"
            vb.name = "vm2"
            vb.gui = false
            vb.check_guest_additions = false
            vb.cpus = 2
            vb.memory = 4096
            vb.customize ["modifyvm", :id, "--groups", "/cks-cluster"]
            vb.customize ['modifyvm', :id, '--nested-hw-virt', 'on']
            override.vm.disk :disk, primary: true, size: "50GB"
            override.vm.synced_folder "./formation", "/home/vagrant/cks"
        end

        vm2.vm.provider :libvirt do |v, override|
            override.vm.box = "alvistack/ubuntu-20.04"
            override.vm.box_version = "20241215.1.1"
            v.default_prefix = "formation-cks-"
            v.memory = 4096
            v.cpus = 2
            v.forward_ssh_port = true
            v.nested = true
            v.machine_virtual_size = 50
            v.graphics_type = "none"
            v.inputs = []
            override.vm.synced_folder "./formation", "/home/vagrant/cks", 
                type: "nfs",
                nfs_version: "4",
                nfs_udp: false
        end

        vm2.vm.hostname = "cks-worker"
        vm2.vm.network "private_network", ip: "172.16.0.3", hostname: true
        vm2.vm.provision "shell", inline: <<-SHELL
            apt update
            apt upgrade -y
            apt autoremove -y
        SHELL
    end
end