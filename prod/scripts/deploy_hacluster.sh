#!/bin/bash

# Define IP addresses for easy maintenance
FILER1_IP="162.19.90.124"
FILER2_IP="57.128.73.105"

# Cluster name
CLUSTER_NAME="my_cluster"

# Stonith device name
STONITH_DEVICE="stonith_device"

# Filesystem type
FSTYPE="ext4"

# Define the resources and corresponding volumes
declare -a r1_volumes=("11" "12" "13" "14")
declare -a r2_volumes=("21" "22" "23")
declare -a r3_volumes=("31")

declare -a resources=("r1" "r2" "r3")
declare -A volumes=(
  ["r1"]="${r1_volumes[*]}"
  ["r2"]="${r2_volumes[*]}"
  ["r3"]="${r3_volumes[*]}"
)

declare -A dir_map=(
  ["/dev/drbd11"]="/drbd/dawanfr/docker"
  ["/dev/drbd12"]="/drbd/dawanorg/docker"
  ["/dev/drbd13"]="/drbd/jehannorg/docker"
  ["/dev/drbd14"]="/drbd/dj-serverorg/docker"
  ["/dev/drbd21"]="/drbd/dawantv/docker"
  ["/dev/drbd22"]="/drbd/nuage/docker"
  ["/dev/drbd23"]="/drbd/formateur/docker"
)


# Authenticate cluster hosts
pcs host auth $FILER1_IP $FILER2_IP

# Configure cluster with two hosts
pcs cluster setup $CLUSTER_NAME $FILER1_IP $FILER2_IP

# Enable all cluster services
pcs cluster enable --all

# Start all cluster services
pcs cluster start --all

# Configure the stonith device with the host list
pcs stonith create $STONITH_DEVICE fence_dummy pcmk_host_list=$FILER2_IP,$FILER1_IP

# Enable stonith and set its default action
pcs property set stonith-enabled=true
pcs property set stonith-action=off

# Messagerie
pcs resource create Filer1_additional_IP_mail ocf:heartbeat:IPaddr2 ip="91.121.62.97" nic="public-bond0" cidr_netmask="32" op monitor interval="30s"
pcs constraint location Filer1_additional_IP_mail prefers $FILER1_IP=100

# Create an IP resource for the additional IP on filer1
## private
pcs resource create Filer1_additional_IP_drbd ocf:heartbeat:IPaddr2 ip="169.254.113.169" nic="private-bond0" cidr_netmask="32" op monitor interval="30s"
## public
#pcs resource create Filer1_additional_IP_dawanfr ocf:heartbeat:IPaddr2 ip="87.98.143.213" nic="public-bond0" cidr_netmask="32" op monitor interval="30s"
#pcs resource create Filer1_additional_IP_dawanorg ocf:heartbeat:IPaddr2 ip="87.98.143.213" nic="public-bond0" cidr_netmask="32" op monitor interval="30s"
#pcs resource create Filer1_additional_IP_djserverorg ocf:heartbeat:IPaddr2 ip="91.121.60.104" nic="public-bond0" cidr_netmask="32" op monitor interval="30s"
#pcs resource create Filer1_additional_IP_jehannorg ocf:heartbeat:IPaddr2 ip="N/A" nic="public-bond0" cidr_netmask="32" op monitor interval="30s"

# Create an IP resource for the additional IP on filer2
## private
pcs resource create Filer2_additional_IP_drbd ocf:heartbeat:IPaddr2 ip="169.254.60.173" nic="private-bond0" cidr_netmask="32" op monitor interval="30s"
## public
pcs resource create Filer2_additional_IP_nuage ocf:heartbeat:IPaddr2 ip="178.33.110.250" nic="public-bond0" cidr_netmask="32" op monitor interval="30s"
pcs resource create Filer2_additional_IP_dawantv ocf:heartbeat:IPaddr2 ip="178.32.117.50" nic="public-bond0" cidr_netmask="32" op monitor interval="30s"

for resource in "${resources[@]}"; do
  IFS=' ' read -r -a volume_array <<< "${volumes[$resource]}"
  for volume in "${volume_array[@]}"; do
    device="/dev/drbd$volume"
    directory=${dir_map[$device]}

    # Create the DRBD resource for the resource
    pcs resource create drbd_${resource} ocf:linbit:drbd \
        drbd_resource=$resource ignore_missing_notifications=true \
        op monitor timeout="20" interval="20" role="Slave" \
        op monitor timeout="20" interval="10" role="Master"

    # Configure the resource to be promoted as master
    pcs resource promotable drbd_${resource} \
        drbd_resource=$resource \
        master-max=1 master-node-max=1 \
        clone-max=2 clone-node-max=1 \
        notify=true

    if [ "$resource" != "r3" ]; then
      # Create the filesystem for each volume
      pcs resource create fs_${resource}_${volume} ocf:heartbeat:Filesystem device=$device directory=$directory fstype=$FSTYPE

      # Colocate filesystem with DRBD resource
      pcs constraint colocation add fs_${resource}_${volume} with master drbd_${resource}-clone INFINITY
      pcs constraint order promote drbd_${resource}-clone then start fs_${resource}_${volume}
    fi

    # Resource location preference
    if [ "$resource" = "r1" ]; then
      pcs constraint location drbd_${resource}-clone prefers $FILER1_IP=100
    elif [ "$resource" = "r2" ]; then
      pcs constraint location drbd_${resource}-clone prefers $FILER2_IP=100
      elif [ "$resource" = "r3" ]; then
      pcs constraint location drbd_${resource}-clone prefers $FILER1_IP=100
    
      # Create a resource for the target control script
      pcs resource create iSCSI_tgt_${resource} ocf:heartbeat:agent_tgt op start timeout=20s stop timeout=20s monitor interval=10s timeout=20s 
      # Colocate target resource with DRBD resource
      pcs constraint colocation add iSCSI_tgt_${resource} with master drbd_${resource}-clone INFINITY
    
      # Order constraints
      pcs constraint order promote drbd_${resource}-clone then start iSCSI_tgt_${resource}
    
      # Resource location preference
      pcs constraint location iSCSI_tgt_${resource} prefers $FILER1_IP=100
    fi
  done
done

pcs resource create r2_to_filer1 ocf:heartbeat:agent_failoverscript \
script_path="/root/pcs/r2_to_filer1.sh" \
op monitor OCF_CHECK_LEVEL="0" timeout="30s" interval="30s"

pcs constraint colocation add r2_to_filer1 with master drbd_r2-clone INFINITY role=Master

pcs resource create r2_to_filer2 ocf:heartbeat:agent_failoverscript \
script_path="/root/pcs/r2_to_filer2.sh" \
op monitor OCF_CHECK_LEVEL="0" timeout="30s" interval="30s"

pcs constraint colocation add r2_to_filer2 with master drbd_r2-clone INFINITY role=Master

#pcs constraint location r1_to_filer1 prefers $FILER1_IP=100
#pcs constraint location r1_to_filer2 prefers $FILER2_IP=100
pcs constraint location r2_to_filer1 prefers $FILER1_IP=100
pcs constraint location r2_to_filer2 prefers $FILER2_IP=100

#pcs constraint order promote drbd_r1-clone then start r1_to_filer1
#pcs constraint order demote drbd_r1-clone then start r1_to_filer2
pcs constraint order promote drbd_r2-clone then start r2_to_filer1
pcs constraint order demote drbd_r2-clone then start r2_to_filer2

pcs resource create DockerResource_R2 ocf:heartbeat:agent_docker_r2 \
  op start timeout=60s \
  op stop timeout=60s \
  op monitor interval=30s timeout=30s

pcs constraint location DockerResource_R2 prefers $FILER2_IP=100
pcs constraint order promote drbd_r2-clone then start DockerResource_R2
pcs constraint order stop DockerResource_R2 then stop fs_r2_22 kind=Mandatory
pcs constraint order stop DockerResource_R2 then stop fs_r2_21 kind=Mandatory
# pcs resource create DockerResource_R1 ocf:heartbeat:agent_docker_r1 \
#   op start timeout=60s \
#   op stop timeout=60s \
#   op monitor interval=30s timeout=30s

# pcs constraint location DockerResource_R1 prefers $FILER1_IP=100
# pcs constraint order promote drbd_r1-clone then start DockerResource_R1
# pcs constraint order stop DockerResource_R1 then stop fs_r1_11 kind=Mandatory

# Colocate additional IP with DRBD resource on filer1
pcs constraint colocation add Filer1_additional_IP_drbd with master drbd_r1-clone INFINITY
# pcs constraint colocation add Filer1_additional_IP_djserverorg with master drbd_r1-clone INFINITY
# pcs constraint colocation add Filer1_additional_IP_dawanfr with master drbd_r1-clone INFINITY
# pcs constraint colocation add Filer1_additional_IP_dawanorg with master drbd_r1-clone INFINITY
# pcs constraint colocation add Filer1_additional_IP_jehannorg with master drbd_r1-clone INFINITY

# Colocate additional IP with DRBD resource on filer2
pcs constraint colocation add Filer2_additional_IP_drbd with master drbd_r2-clone INFINITY
pcs constraint colocation add Filer2_additional_IP_nuage with master drbd_r2-clone INFINITY
pcs constraint colocation add Filer2_additional_IP_dawantv with master drbd_r2-clone INFINITY
pcs constraint location $STONITH_DEVICE prefers $FILER1_IP

pcs resource create Fail2BanResource ocf:heartbeat:agent_fail2ban op start timeout=30s stop timeout=30s monitor interval=10s

pcs constraint order DockerResource_R2 then Fail2BanResource

pcs constraint location Fail2BanResource prefers $FILER2_IP=100
