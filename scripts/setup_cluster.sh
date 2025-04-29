#!/bin/bash
set -e

# Configuration système de base
echo "192.168.56.101 filer1" >> /etc/hosts
echo "192.168.56.102 filer2" >> /etc/hosts

# Configuration du mot de passe hacluster (nécessaire pour pcs)
echo "hacluster:hacluster" | chpasswd
systemctl enable pcsd
systemctl start pcsd

# Arrêt des services s'ils sont en cours d'exécution
systemctl stop corosync pacemaker

# Nettoyage de toute configuration existante
pcs cluster destroy

# Installation des agents Docker personnalisés sur tous les nœuds
mkdir -p /usr/lib/ocf/resource.d/heartbeat/
cp /vagrant/templates/agent_docker_r1 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r1
cp /vagrant/templates/agent_docker_r2 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r2
chmod 755 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r1
chmod 755 /usr/lib/ocf/resource.d/heartbeat/agent_docker_r2

# Installer Docker Compose si nécessaire
if ! command -v docker-compose &> /dev/null; then
    # Installer Docker Compose directement depuis GitHub
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Créer le répertoire partagé pour les informations de compose
mkdir -p /vagrant/shared
chmod 777 /vagrant/shared
touch /vagrant/shared/compose_r1.db
touch /vagrant/shared/compose_r2.db
chmod 666 /vagrant/shared/compose_r1.db
chmod 666 /vagrant/shared/compose_r2.db

# Configuration initiale du cluster (uniquement sur filer1)
if [[ $(hostname) == "filer1" ]]; then
    pcs host auth filer1 filer2 -u hacluster -p hacluster
    # Générer la configuration de base avec pcs
    pcs cluster setup my_cluster filer1 filer2 --force
    # Remplacer par notre configuration personnalisée
    cp /etc/corosync/corosync.conf /etc/corosync/corosync.conf.pcs_generated
    cp /tmp/corosync.conf /etc/corosync/corosync.conf
    # Forcer la synchronisation sur les deux nœuds
    pcs cluster sync
    pcs cluster start --all
    pcs cluster enable --all
    
    # Attendre que le cluster soit opérationnel
    sleep 30
    # Redémarrer les services pour appliquer la configuration
    pcs cluster stop --all
    pcs cluster start --all

    # Configuration des propriétés de base du cluster
    pcs property set stonith-enabled=true
    pcs property set stonith-action=off
    # Ajout des propriétés supplémentaires comme en prod
    pcs property set cluster-name=my_cluster
    pcs property set cluster-recheck-interval=5min
    pcs property set start-failure-is-fatal=true
    pcs property set pe-warn-series-max=1000
    pcs property set pe-input-series-max=1000
    pcs property set pe-error-series-max=1000
    
    # Configuration du STONITH comme en production
    pcs stonith create stonith-dummy fence_dummy \
        pcmk_host_list="filer2,filer1"

    # Ajout d'une ressource IP flottante de test
    pcs resource create virtual_ip ocf:heartbeat:IPaddr2 \
        ip=192.168.56.100 cidr_netmask=24 op monitor interval=10s

    # Configuration du load balancing comme en prod
    pcs constraint location virtual_ip prefers filer1=50
    pcs constraint location virtual_ip prefers filer2=50

    # Configuration des ressources Docker Compose r1 et r2
    pcs resource create agent_docker_r1 ocf:heartbeat:agent_docker_r1 \
        op monitor interval=30s timeout=30s \
        op start interval=0s timeout=120s \
        op stop interval=0s timeout=120s

    pcs resource create agent_docker_r2 ocf:heartbeat:agent_docker_r2 \
        op monitor interval=30s timeout=30s \
        op start interval=0s timeout=120s \
        op stop interval=0s timeout=120s

    # Configurer les ressources avec des préférences de nœuds strictes
    pcs constraint location agent_docker_r1 prefers filer1=INFINITY
    pcs constraint location agent_docker_r2 prefers filer2=INFINITY

    # Assurer que les ressources restent sur leur nœud préféré 
    # même quand l'autre nœud revient en ligne
    pcs resource defaults resource-stickiness=100
    pcs resource defaults migration-threshold=3

    # Important: Empêcher l'interdépendance via la virtual IP
    # Créer des contraintes indépendantes pour chaque ressource
    # au lieu d'une contrainte avec virtual_ip
    
    # Attendre que les ressources soient déplacées
    sleep 30
    pcs status
    
    # Configurer les logs pour faciliter le débogage
    pcs property set cluster-recheck-interval=1min
fi

# Création du répertoire pour les agents OCF personnalisés
mkdir -p /usr/lib/ocf/resource.d/heartbeat/ 