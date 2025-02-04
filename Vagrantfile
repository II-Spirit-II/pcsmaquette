# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # Configuration commune
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end

  # Configuration réseau commune
  config.vm.network "private_network", type: "dhcp"  # Pour l'interface de management

  # Node 2
  config.vm.define "filer2" do |node2|
    node2.vm.hostname = "filer2"
    node2.vm.network "private_network", ip: "192.168.56.102", 
      virtualbox__intnet: true,
      name: "cluster_net"
    
    node2.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y pacemaker corosync crmsh pcs fence-agents
      
      # Désactiver ufw car il interfère avec corosync
      systemctl stop ufw
      systemctl disable ufw
      
      # Création du répertoire corosync s'il n'existe pas
      mkdir -p /etc/corosync
      
      # Configuration de l'interface réseau pour corosync
      ip link set enp0s8 up
    SHELL
    
    node2.vm.provision "file", source: "templates/corosync.conf", 
      destination: "/tmp/corosync.conf"
    node2.vm.provision "shell", inline: "sudo cp /tmp/corosync.conf /etc/corosync/corosync.conf"
    
    node2.vm.provision "shell", path: "scripts/setup_cluster.sh"
    node2.vm.provision "shell", inline: <<-SHELL
      # Démarrer les services après configuration
      systemctl start corosync pacemaker
      systemctl enable corosync pacemaker
    SHELL
  end

  # Node 1 (configuré en dernier)
  config.vm.define "filer1" do |node1|
    node1.vm.hostname = "filer1"
    node1.vm.network "private_network", ip: "192.168.56.101",
      virtualbox__intnet: true,
      name: "cluster_net"
    
    node1.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y pacemaker corosync crmsh pcs fence-agents ipmitool
      
      # Désactiver ufw car il interfère avec corosync
      systemctl stop ufw
      systemctl disable ufw
      
      # Création du répertoire corosync s'il n'existe pas
      mkdir -p /etc/corosync
      
      # Configuration de l'interface réseau pour corosync
      ip link set enp0s8 up
    SHELL
    
    node1.vm.provision "file", source: "templates/corosync.conf", 
      destination: "/tmp/corosync.conf"
    node1.vm.provision "shell", inline: "sudo cp /tmp/corosync.conf /etc/corosync/corosync.conf"
    
    node1.vm.provision "shell", path: "scripts/setup_cluster.sh"
    node1.vm.provision "shell", inline: <<-SHELL
      systemctl start corosync pacemaker
      systemctl enable corosync pacemaker
      # Vérification finale
      sleep 10
      corosync-cmapctl | grep members
    SHELL
  end
end 