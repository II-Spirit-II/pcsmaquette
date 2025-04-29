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

  # Configuration du répertoire partagé
  config.vm.synced_folder "shared", "/vagrant/shared",
    owner: "root",
    group: "root",
    mount_options: ["dmode=777,fmode=666"]

  # Configuration du répertoire compose
  config.vm.synced_folder "compose", "/vagrant/compose",
    owner: "root",
    group: "root",
    mount_options: ["dmode=755,fmode=644"],
    create: true

  # Node 2
  config.vm.define "filer2" do |node2|
    node2.vm.hostname = "filer2"
    node2.vm.network "private_network", ip: "192.168.56.102", 
      virtualbox__intnet: true,
      name: "cluster_net"
    
    node2.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y pacemaker corosync crmsh pcs fence-agents docker.io resource-agents curl
      
      # Installation de Docker Compose
      if ! command -v docker-compose &> /dev/null; then
        mkdir -p /usr/local/bin
        curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
      fi
      
      # Désactiver ufw car il interfère avec corosync
      systemctl stop ufw
      systemctl disable ufw
      
      # Configuration de SSH pour permettre l'échange d'informations entre nœuds
      if [ ! -f /root/.ssh/id_rsa ]; then
        mkdir -p /root/.ssh
        ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
        cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
      fi
      echo "192.168.56.101 filer1" >> /etc/hosts
      echo "192.168.56.102 filer2" >> /etc/hosts
      
      # Création du répertoire corosync s'il n'existe pas
      mkdir -p /etc/corosync
      
      # Configuration de l'interface réseau pour corosync
      ip link set enp0s8 up
      
      # Installation des agents Docker personnalisés
      mkdir -p /usr/lib/ocf/resource.d/heartbeat/
      cp /vagrant/templates/agent_docker_r1 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r1
      cp /vagrant/templates/agent_docker_r2 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r2
      chmod 755 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r1
      chmod 755 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r2
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
      apt-get install -y pacemaker corosync crmsh pcs fence-agents docker.io resource-agents curl
      
      # Installation de Docker Compose
      if ! command -v docker-compose &> /dev/null; then
        mkdir -p /usr/local/bin
        curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
      fi
      
      # Désactiver ufw car il interfère avec corosync
      systemctl stop ufw
      systemctl disable ufw
      
      # Configuration de SSH pour permettre l'échange d'informations entre nœuds
      if [ ! -f /root/.ssh/id_rsa ]; then
        mkdir -p /root/.ssh
        ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
        cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
      fi
      echo "192.168.56.101 filer1" >> /etc/hosts
      echo "192.168.56.102 filer2" >> /etc/hosts
      
      # Création du répertoire corosync s'il n'existe pas
      mkdir -p /etc/corosync
      
      # Configuration de l'interface réseau pour corosync
      ip link set enp0s8 up
      
      # Installation des agents Docker personnalisés
      mkdir -p /usr/lib/ocf/resource.d/heartbeat/
      cp /vagrant/templates/agent_docker_r1 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r1
      cp /vagrant/templates/agent_docker_r2 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r2
      chmod 755 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r1
      chmod 755 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r2
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