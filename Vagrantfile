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
  # commenté pour utiliser uniquement le réseau privé statique ci-dessous pour la communication hôte-VM et inter-VM
  # config.vm.network "private_network", type: "dhcp"

  # Configuration du répertoire drbd (remplace compose)
  # Assurez-vous que le répertoire 'drbd' existe localement à la racine du projet Vagrant
  config.vm.synced_folder "drbd", "/drbd",
    owner: "root", # Peut rester root ou être l'UID/GID ci-dessous
    group: "root", # Peut rester root ou être l'UID/GID ci-dessous
    mount_options: ["dmode=775,fmode=664", "uid=999", "gid=999"], # AJOUT DE UID/GID
    create: true

  # Node 2
  config.vm.define "filer2" do |node2|
    node2.vm.hostname = "filer2"
    node2.vm.network "private_network", ip: "192.168.56.102"
    
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

    # Provisionnement des permissions pour les volumes Docker spécifiques à filer2
    node2.vm.provision "shell", name: "Set Docker Volume Permissions for Filer2", inline: <<-SHELL
      echo "Applying specific permissions for Docker volumes on Filer2..."
      
      # Pour MariaDB (projet nuage)
      echo "Setting permissions for Nuage MariaDB data..."
      mkdir -p /drbd/nuage/docker/volumes/mariadb_data
      sudo chown -R 999:999 /drbd/nuage/docker/volumes/mariadb_data
      sudo chmod -R u+rwx /drbd/nuage/docker/volumes/mariadb_data
      
      # Pour Nextcloud app data (projet nuage)
      echo "Setting permissions for Nuage Nextcloud app data..."
      mkdir -p /drbd/nuage/docker/volumes/nextcloud_app_data
      sudo chown -R 33:33 /drbd/nuage/docker/volumes/nextcloud_app_data # UID 33 pour www-data
      sudo chmod -R u+rwx,g+rwx /drbd/nuage/docker/volumes/nextcloud_app_data
      
      echo "Filer2 Docker volume permissions applied."
    SHELL
    
    node2.vm.provision "shell", inline: <<-SHELL
      systemctl start corosync pacemaker
      systemctl enable corosync pacemaker
    SHELL
  end

  # Node 1 (configuré en dernier)
  config.vm.define "filer1" do |node1|
    node1.vm.hostname = "filer1"
    node1.vm.network "private_network", ip: "192.168.56.101"
    
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

    # Provisionnement des permissions pour les volumes Docker spécifiques à filer1
    node1.vm.provision "shell", name: "Set Docker Volume Permissions for Filer1", inline: <<-SHELL
      echo "Applying specific permissions for Docker volumes on Filer1..."
      
      # Pour MariaDB du projet dawanorg (r1)
      echo "Setting permissions for DawanOrg MariaDB data..."
      mkdir -p /drbd/dawanorg/docker/volumes/mariadb_data 
      sudo chown -R 999:999 /drbd/dawanorg/docker/volumes/mariadb_data
      sudo chmod -R u+rwx /drbd/dawanorg/docker/volumes/mariadb_data
      
      # Ajoutez ici d'autres chown/chmod pour les volumes des projets sur filer1 si nécessaire
      # Exemple pour jehannorg (en supposant qu'il utilise aussi MariaDB avec uid 999)
      # mkdir -p /drbd/jehannorg/docker/volumes/mariadb_data 
      # sudo chown -R 999:999 /drbd/jehannorg/docker/volumes/mariadb_data
      # sudo chmod -R u+rwx /drbd/jehannorg/docker/volumes/mariadb_data

      echo "Filer1 Docker volume permissions applied."
    SHELL
    
    node1.vm.provision "shell", inline: <<-SHELL
      systemctl start corosync pacemaker
      systemctl enable corosync pacemaker
      # Vérification finale
      sleep 10
      corosync-cmapctl | grep members
    SHELL
  end
end 