#!/bin/bash

declare -a r2_mount_points=(
  "/drbd/dawantv/docker/stack/dawantv"
  "/drbd/nuage/docker/stack/nuage"
)

# Fonction pour vérifier l'état de DRBD
check_drbd_status() {
  local drbd_resource=$1
  local drbd_status=$(drbdadm role $drbd_resource)
  echo "L'état de DRBD pour la ressource $drbd_resource est : $drbd_status"
  if [[ $drbd_status == *"Primary/Secondary"* ]]; then
    return 0
  else
    return 1
  fi
}

# Fonction pour arrêter les conteneurs Docker et démonter les systèmes de fichiers
stop_and_unmount() {
  local mount_point=$1
  
  # Obtenez le nom du projet à partir du chemin du point de montage
  local project_name=$(basename "$mount_point")
  
  # Stopper tous les conteneurs associés à ce projet
  docker ps -q -f "name=^${project_name}-" | xargs -r docker stop
  
  # Démonter le système de fichiers
  umount "$mount_point"
  echo "Les conteneurs Docker pour $project_name ont été stoppés et le système de fichiers a été démonté."
}

for mount_point in "${r2_mount_points[@]}"; do
  echo "Traitement de $mount_point..."
  cd $mount_point
  
  # Obtenez le nom du projet à partir du chemin du point de montage
  project_name=$(basename "$mount_point")

  # Vérifiez si des conteneurs pour ce projet sont en cours d'exécution
  running_containers=$(docker ps -q -f "name=^${project_name}-")

  if check_drbd_status "r2"; then
    if [ -z "$running_containers" ]; then
      if [ -x "init.sh" ]; then
        echo "Démarrage depuis init.sh dans $mount_point..."
        ./init.sh
        echo "Docker $mount_point a démarré."
      else
        echo "Aucun fichier init.sh dans $mount_point. Ignoré..."
      fi
    else
      # Vérifier la santé des conteneurs en cours d'exécution
      unhealthy_containers=$(docker ps -q -f "name=^${project_name}-" -f "health=unhealthy")
      
      if [ -n "$unhealthy_containers" ]; then
        echo "Redémarrage des conteneurs non sains : $unhealthy_containers"
        docker restart $unhealthy_containers
      else
        echo "Tous les conteneurs pour le projet $project_name sont sains. Ignoré..."
      fi
    fi
  else
    # Si l'état de DRBD n'est pas Primary/Secondary, arrêter les conteneurs et démonter les systèmes de fichiers
    stop_and_unmount $mount_point
  fi
done

echo "Les vérifications ont été effectuées."

