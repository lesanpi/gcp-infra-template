# main.tf
provider "google" {
  project = "p2pets" # Reemplaza con tu PROJECT_ID
  region  = "us-central1"
  zone    = "us-central1-f"
}

# 1. Instance Template
resource "google_compute_instance_template" "my-instance-template" {
  name         = "my-instance-template"
  machine_type = "f1-micro"
  tags         = ["web", "development"]

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-focal-v20250213"
    auto_delete  = true
    boot         = true
  }



  # Habilitar contenedores
  metadata = {
    gce-container-declaration = <<-EOT
      spec:
        containers:
          - name: nginx
            image: us-central1-docker.pkg.dev/p2pets/my-repo/my-image:latest
            stdin: false
            tty: false
            ports:
              - containerPort: 80
              - containerPort: 443
        restartPolicy: Always
    EOT
  }

  # Asegúrate de que el servicio de contenedores esté instalado
  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }


  network_interface {
    network = "default"
    access_config {
      # Se asigna IP externa
    }
  }
}

# 2. Health Check
resource "google_compute_health_check" "my-health-check" {
  name = "my-health-check"

  http_health_check {
    port = 80
  }

  check_interval_sec  = 5
  timeout_sec         = 5
  unhealthy_threshold = 2
  healthy_threshold   = 2
}

# 3. Instance Group Manager
resource "google_compute_instance_group_manager" "my-instance-group" {
  name               = "my-instance-group"
  base_instance_name = "my-instance"
  zone               = "us-central1-f"
  target_size        = 1


  version {
    instance_template = google_compute_instance_template.my-instance-template.self_link
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.my-health-check.self_link
    initial_delay_sec = 300
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }
}

# 4. Backend Service
resource "google_compute_backend_service" "motivapp-web" {
  name                  = "motivapp-web"
  protocol              = "HTTP"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_instance_group_manager.my-instance-group.instance_group
  }

  health_checks = [google_compute_health_check.my-health-check.self_link]
}

# 5. URL Map
resource "google_compute_url_map" "my-url-map" {
  name            = "my-url-map"
  default_service = google_compute_backend_service.motivapp-web.self_link

  host_rule {
    hosts        = ["*"]
    path_matcher = "path-matcher-1"
  }

  path_matcher {
    name            = "path-matcher-1"
    default_service = google_compute_backend_service.motivapp-web.self_link
  }
}

# 6. HTTP Proxy
resource "google_compute_target_http_proxy" "my-http-proxy" {
  name    = "my-http-proxy"
  url_map = google_compute_url_map.my-url-map.self_link
}

# 7. HTTPS Proxy (requiere certificado SSL)
resource "google_compute_target_https_proxy" "my-https-proxy" {
  name    = "my-https-proxy"
  url_map = google_compute_url_map.my-url-map.self_link

  ssl_certificates = ["projects/p2pets/global/sslCertificates/motivapp-certificate"]
}

# 8. Global Address
resource "google_compute_global_address" "my-ip-address" {
  name = "my-ip-address"
}

# 9. Forwarding Rules
resource "google_compute_global_forwarding_rule" "http" {
  name       = "my-http-forwarding-rule"
  target     = google_compute_target_http_proxy.my-http-proxy.self_link
  ip_address = google_compute_global_address.my-ip-address.address
  port_range = "80"
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = "my-https-forwarding-rule"
  target     = google_compute_target_https_proxy.my-https-proxy.self_link
  ip_address = google_compute_global_address.my-ip-address.address
  port_range = "443"
}

# 10. DNS Record
resource "google_dns_record_set" "motivapp-dns" {
  name         = "motivapp.lesanpi.com."
  type         = "A"
  ttl          = 3600
  managed_zone = "lesanpi"
  rrdatas      = [google_compute_global_address.my-ip-address.address]
}

# 11. Instance Schedule (Requiere configuración especial)
resource "google_compute_resource_policy" "instance-schedule" {
  name   = "apagar-encender"
  region = "us-central1"

  instance_schedule_policy {
    vm_start_schedule {
      schedule = "0 11 * * *"
    }
    vm_stop_schedule {
      schedule = "0 22 * * *"
    }
    time_zone = "America/Caracas"
  }
}




### PIPELINE


# # 1. Conectar el repositorio de GitHub a Cloud Source Repositories
# resource "google_sourcerepo_repository" "motivapp-repo" {
#   name = "motivapp-repo"
# }

# # 2. Configurar el trigger de Cloud Build
# resource "google_cloudbuild_trigger" "motivapp-trigger" {
#   name        = "motivapp-trigger"
#   description = "Trigger para la rama development"

#   trigger_template {
#     branch_name = "development"
#     repo_name   = google_sourcerepo_repository.motivapp-repo.name
#   }

#   build {
#     step {
#       name = "gcr.io/cloud-builders/npm"
#       args = ["install"]
#     }

#     step {
#       name = "gcr.io/cloud-builders/npm"
#       args = ["run", "build"]
#     }

#     artifacts {
#       images = []
#       objects {
#         location = "gs://${google_storage_bucket.build-artifacts.name}/build"
#         paths    = ["app/.next"]
#       }
#     }
#   }
# }

# # 3. Bucket para almacenar los artefactos de construcción
# resource "google_storage_bucket" "build-artifacts" {
#   name     = "motivapp-build-artifacts"
#   location = "us-central1"
# }

# # 4. Configurar Cloud Deploy para el despliegue en VMs
# resource "google_clouddeploy_delivery_pipeline" "motivapp-pipeline" {
#   name        = "motivapp-pipeline"
#   description = "Pipeline de despliegue para la aplicación Next.js"
#   location    = "us-central1"

#   serial_pipeline {
#     stages {
#       target_id = "development-vms"
#     }
#   }
# }

# resource "google_clouddeploy_target" "development-vms" {
#   name        = "development-vms"
#   description = "Despliegue en VMs de desarrollo"
#   location    = "us-central1"

#   custom_target {
#     custom_target_type = "vm-deployer"
#   }
# }

# # 6. Permisos IAM para Cloud Build y Cloud Deploy
# resource "google_project_iam_member" "cloudbuild-deployer" {
#   project = "p2pets"
#   role    = "roles/clouddeploy.developer"
#   member  = "serviceAccount:${google_service_account.cloudbuild.email}"
# }

# resource "google_service_account" "cloudbuild" {
#   account_id   = "cloudbuild-sa"
#   display_name = "Cloud Build Service Account"
# }
