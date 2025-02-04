#!/bin/bash

# Dépendance : gum (https://github.com/charmbracelet/gum)
if ! command -v gum &>/dev/null; then
    echo "❌ gum n'est pas installé. Installez-le avec :"
    echo "   curl -fsSL https://github.com/charmbracelet/gum/releases/latest/download/gum-linux-amd64 -o /usr/local/bin/gum"
    echo "   chmod +x /usr/local/bin/gum"
    exit 1
fi

# Définition des variables
RESOURCE_NAME="Filer1_additional_IP_mail"

# Association des noms de filer avec leurs IPs
declare -A FILER_IPS=(
    ["filer1"]="162.19.90.124"
    ["filer2"]="57.128.73.105"
)

gum style \
    --foreground 116 --border-foreground 110 --border double \
    --align left --width  30 --margin "1 2" --padding "1 2" \
    'Filer1: 162.19.90.124' \
    'Filer2: 57.128.73.105'

# Récupération du nom du filer et conversion en IP
FILER_NAME="$(gum choose --item.foreground 250 "${!FILER_IPS[@]}")"
FILER_TARGET="${FILER_IPS[$FILER_NAME]}"

# Vérifier si le filer existe dans le mapping
if [ -z "$FILER_TARGET" ]; then
    gum log -t layout -s -l error "❌ Erreur : '$FILER_NAME' n'est pas un nœud valide."
    exit 1
fi

# Vérifier si la ressource existe dans Pacemaker
if ! pcs resource show "$RESOURCE_NAME" &>/dev/null; then
    gum log -t layout -s -l error "❌ Erreur : La ressource '$RESOURCE_NAME' n'existe pas."
    exit 1
fi

# Vérifier si le nœud cible est bien dans le cluster
if ! pcs status | grep -q "$FILER_TARGET"; then
    gum log -t layout -s -l error "❌ Erreur : '$FILER_NAME' ($FILER_TARGET) ne fait pas partie du cluster."
    exit 1
fi

# Confirmation avant la migration
gum confirm "Voulez-vous vraiment migrer '$RESOURCE_NAME' vers '$FILER_NAME' ?" || exit 1

# Effectuer la migration
gum spin --title "Migration de '$RESOURCE_NAME' vers '$FILER_NAME' ($FILER_TARGET)... ⏳" -- pcs resource move "$RESOURCE_NAME" "$FILER_TARGET"

# Vérification du succès de la migration
if [ $? -eq 0 ]; then
    gum log -t layout -s -l debug "✔ Migration réussie vers '$FILER_NAME' ($FILER_TARGET) !"
else
    gum log -t layout -s -l error "❌ Échec de la migration !"
    exit 1
fi

