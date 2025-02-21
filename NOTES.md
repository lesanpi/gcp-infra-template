1. Crear repositorio de docker en artifact Repository

2. El error ERROR: (gcloud.compute.instances.update-container) Instance doesn't have gce-container-declaration metadata key - it is not a container ocurre porque la instancia de Google Compute Engine (GCE) no está configurada para ejecutar contenedores. Para usar el comando gcloud compute instances update-container, la instancia debe tener habilitada la opción de "Deploy a container image to this VM instance" durante su creación.

Ve a Compute Engine en la consola de Google Cloud.
Haz clic en "Crear instancia".
En la sección "Contenedores", marca la casilla que dice "Implementar un contenedor en esta instancia de VM".

3. Hay que crear distintos triggers para cada ambiente, por lo tanto distintos cloudbuild.yaml
   dev.cloudbuild.yaml
   stg.cloudbuild.yaml
   prod.cloudbuild.yaml
