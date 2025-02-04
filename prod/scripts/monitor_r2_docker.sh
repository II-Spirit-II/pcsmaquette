#!/bin/bash

declare -a r2_mount_points=(
  "/drbd/dawantv/docker/"
  "/drbd/nuage/docker/"
)

check_mount_points() {
  for mount_point in "${r2_mount_points[@]}"; do
    if ! mountpoint -q "$mount_point"; then
      echo "$mount_point n'est pas monté."
      exit 1
    fi
  done
}

check_docker_containers() {
  for mount_point in "${r2_mount_points[@]}"; do
    project_name=$(basename "$mount_point")
    
    declare -a container_names=("^${project_name}-")

    for container_name in "${container_names[@]}"; do
      unhealthy_containers=$(docker ps -q -f "name=${container_name}" -f "health=unhealthy")
      stopped_containers=$(docker ps -q -f "name=${container_name}" -f "status=exited")

      if [ -n "$unhealthy_containers" ] || [ -n "$stopped_containers" ]; then
        echo "Il y a des conteneurs non sains ou arrêtés pour le projet $project_name avec le nom $container_name."
        exit 1
      fi
    done
  done
}

check_mount_points
check_docker_containers

echo "Tout est sain."
exit 0

