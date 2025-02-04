#!/bin/bash

declare -a r1_mount_points=(
  "/drbd/dawanfr/docker/stack/dawanfr"
  "/drbd/dawanorg/docker/stack/dawanorg"
  "/drbd/jehannorg/docker/stack/jehannorg"
  "/drbd/dj-serverorg/docker/stack/djserverorg"
)

for mount_point in "${r1_mount_points[@]}"; do
  echo "Traitement de $mount_point..."
  cd $mount_point
  
  # Obtenez le nom du projet à partir du chemin du point de montage
  project_name=$(basename "$mount_point")

  # Vérifiez si des conteneurs pour ce projet sont en cours d'exécution
  running_containers=$(docker ps -q -f "name=^${project_name}-")

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
done

echo "Les vérifications ont été effectuées."

