#!/bin/bash

# Obtener la lista de instancias con las etiquetas "development" y "web"
INSTANCES=$(gcloud compute instances list --filter="tags.items=development AND tags.items=web" --format="value(name,zone)")

# Verificar si se encontraron instancias
if [ -z "$INSTANCES" ]; then
  echo "No se encontraron instancias con las etiquetas 'development' y 'web'."
  exit 1
fi

# Iterar sobre las instancias y desplegar la imagen
echo "$INSTANCES" | while read -r NAME ZONE; do
  echo "Desplegando en la instancia: $NAME (zona: $ZONE)"
  gcloud compute instances update-container $NAME \
    --zone=$ZONE \
    --container-image=us-central1-docker.pkg.dev/$PROJECT_ID/my-repo/nginx-web:latest
done