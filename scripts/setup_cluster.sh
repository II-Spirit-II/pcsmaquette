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
    pcs property set stonith-enabled=false
    pcs property set stonith-action=off
    pcs property set no-quorum-policy=ignore

    # Ajout d'une ressource IP flottante de test
    pcs resource create virtual_ip ocf:heartbeat:IPaddr2 \
        ip=192.168.56.100 cidr_netmask=24 op monitor interval=10s
fi 