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

# S'assurer que la configuration corosync est présente
if [ -f /tmp/corosync.conf ]; then
  cp /tmp/corosync.conf /etc/corosync/corosync.conf
elif [ -f /vagrant/templates/corosync.conf ]; then
  cp /vagrant/templates/corosync.conf /etc/corosync/corosync.conf
fi
chown root:root /etc/corosync/corosync.conf
chmod 644 /etc/corosync/corosync.conf

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

    # Installation de l'agent Docker personnalisé
    cp /vagrant/templates/agent_docker_r2 /usr/lib/ocf/resource.d/heartbeat/agent_docker
    chmod 755 /usr/lib/ocf/resource.d/heartbeat/agent_docker

    # Configuration de la ressource Docker
    pcs resource create agent_docker ocf:heartbeat:agent_docker \
        op monitor interval=30s timeout=30s \
        op start interval=0s timeout=60s \
        op stop interval=0s timeout=60s

    # Configuration des contraintes pour Docker
    pcs constraint location agent_docker prefers filer1=50
    pcs constraint location agent_docker prefers filer2=50

    # Ajouter une contrainte d'ordre entre l'IP et Docker
    pcs constraint order virtual_ip then agent_docker

    # Configuration des règles de failover
    pcs constraint colocation add virtual_ip with agent_docker score=INFINITY

    # Attendre que les ressources soient déplacées
    sleep 30
    pcs status
fi

# Création du répertoire pour les agents OCF personnalisés
mkdir -p /usr/lib/ocf/resource.d/heartbeat/ 