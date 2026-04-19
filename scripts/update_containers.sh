#!/bin/bash

# Chemin vers votre fichier docker-compose.yml
COMPOSE_FILE="/storage/.config/docker-compose.yml"

# Vérifier l'existence du fichier
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Fichier docker-compose non trouvé : $COMPOSE_FILE"
    exit 1
fi

echo "🔄 Mise à jour des conteneurs à partir de $COMPOSE_FILE"

# 1. Vérifier et mettre à jour Docker si nécessaire
if command -v docker-compose &> /dev/null; then
    echo "✅ docker-compose détecté"
else
    echo "⚠️ docker-compose non installé. Installez docker-compose-plugin."
    exit 1
fi

# 2. Puller les nouvelles images
echo "📥 Téléchargement des dernières images..."
if ! docker-compose -f "$COMPOSE_FILE" pull; then
    echo "❌ Échec du téléchargement des images"
    exit 1
fi

# 3. Arrêter et supprimer les anciens conteneurs
echo "🛑 Arrêt des conteneurs actuels..."
if ! docker-compose -f "$COMPOSE_FILE" down; then
    echo "❌ Échec de l'arrêt des conteneurs"
    exit 1
fi

# 4. Démarrer les nouveaux conteneurs
echo "🚀 Démarrage des conteneurs mis à jour..."
if ! docker-compose -f "$COMPOSE_FILE" up -d; then
    echo "❌ Échec du démarrage des conteneurs"
    exit 1
fi

# 5. Nettoyer les anciennes images inutilisées
echo "🧹 Nettoyage des images orphelines..."
docker image prune -f

# 6. (Optionnel) Scanner les images pour vulnérabilités
# Assurez-vous d'avoir Trivy installé : https://aquasecurity.github.io/trivy/
# for service in $(docker-compose -f "$COMPOSE_FILE" config --services); do
#     image=$(docker-compose -f "$COMPOSE_FILE" images | grep "$service" | awk '{print $3}')
#     echo "🔍 Analyse de sécurité de l'image : $image"
#     trivy image "$image"
# done

echo "✅ Mise à jour terminée avec succès !"   
