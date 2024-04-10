provider "google" {
  # credentials = file("/Users/jainammehta/Desktop/Cloud/dev-csye-6225-08af72cd9221.json")
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "my_vpc" {
  count                   = var.vpc_count
  name                    = "${var.vpc_name}-${count.index}"
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = var.routing_mode
}

resource "google_compute_subnetwork" "webapp" {
  count         = var.vpc_count
  name          = "webapp-${count.index}"
  region        = var.region
  network       = google_compute_network.my_vpc[count.index].self_link
  ip_cidr_range = "${var.webapp_cidr_block}/${var.cidr_range}"
}

resource "google_compute_route" "webapp_route" {
  count            = var.vpc_count
  name             = "webapp-route-${count.index}"
  network          = google_compute_network.my_vpc[count.index].self_link
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  depends_on       = [google_compute_subnetwork.webapp]
  tags             = ["webapp-${count.index}"]
}

resource "google_compute_subnetwork" "db_subnet" {
  count         = var.vpc_count
  name          = "db-${count.index}"
  region        = var.region
  network       = google_compute_network.my_vpc[count.index].self_link
  ip_cidr_range = "${var.db_cidr_block}/${var.cidr_range}"
}

resource "google_project_service" "service_networking" {
  service = "servicenetworking.googleapis.com"
}

resource "google_compute_global_address" "private_services_access" {
  count         = var.vpc_count
  name          = "private-services-access-${count.index}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.my_vpc[count.index].self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.vpc_count
  network                 = google_compute_network.my_vpc[count.index].self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services_access[count.index].name]
  deletion_policy         = "ABANDON"
}

resource "google_kms_key_ring" "my_key_ring" {
  name     = var.key_ring_name
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "sql_crypto_key" {
  name            = var.sql_ring_name
  key_ring        = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s" # 30 days in seconds


  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }
}

resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  project  = var.project_id
  provider = google-beta
  service  = "sqladmin.googleapis.com"
}

resource "google_kms_crypto_key_iam_binding" "crypto_key" {
  provider      = google-beta
  crypto_key_id = google_kms_crypto_key.sql_crypto_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}",
  ]
}

resource "google_sql_database_instance" "cloud_instance" {
  depends_on       = [google_service_networking_connection.private_vpc_connection, google_kms_crypto_key.sql_crypto_key]
  count            = var.vpc_count
  name             = "sql-instance-${count.index}"
  database_version = var.database_version
  region           = var.region
  settings {
    tier = "db-custom-1-3840"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.my_vpc[count.index].self_link
    }
    disk_type         = var.disk_type
    disk_size         = var.disk_size
    disk_autoresize   = false
    availability_type = var.availability_type
    backup_configuration {
      binary_log_enabled = true
      enabled            = true
    }
  }
  encryption_key_name = google_kms_crypto_key.sql_crypto_key.id
  deletion_protection = false
}



resource "google_sql_database" "database" {
  count    = var.vpc_count
  name     = var.database_name
  instance = google_sql_database_instance.cloud_instance[count.index].name
}

resource "random_password" "password" {
  length           = var.password_length
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "users" {
  name     = var.database_username
  count    = var.vpc_count
  instance = google_sql_database_instance.cloud_instance[count.index].name
  password = random_password.password.result
  host     = "%"
}

resource "google_compute_firewall" "allow_application_traffic" {
  depends_on = [google_compute_network.my_vpc]
  priority   = var.FIREWALL_PRIORITY
  count      = var.vpc_count
  name       = "allow-http-firewall-${count.index}"
  network    = google_compute_network.my_vpc[count.index].name
  allow {
    protocol = "tcp"
    ports    = [var.NODE_PORT]
  }
  source_ranges = [var.source_range]
  target_tags   = ["open-http-${count.index}"]
}

resource "google_compute_firewall" "deny_ssh_from_internet" {
  depends_on = [google_compute_network.my_vpc]
  priority   = var.FIREWALL_PRIORITY
  count      = var.vpc_count
  name       = "deny-ssh-${count.index}"
  network    = google_compute_network.my_vpc[count.index].name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [var.source_range]
  target_tags   = ["deny-ssh-${count.index}"]
}

resource "google_compute_address" "instance_static_ip" {
  count  = var.vpc_count
  name   = "instance-static-ip-${count.index}"
  region = var.region
}

resource "google_service_account" "my_service_account" {
  account_id   = "my-service-account-1"
  display_name = "My Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "logging_admin" {
  project = var.project_id
  role    = "roles/logging.admin"
  member  = "serviceAccount:${google_service_account.my_service_account.email}"
}

resource "google_project_iam_member" "monitoring_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.my_service_account.email}"
}

resource "google_project_iam_member" "pub_sub_role" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.my_service_account.email}"
}

resource "google_pubsub_topic" "pubusub_topic" {
  name = var.pub_sub_name
}

resource "google_pubsub_subscription" "pubsub_subscription" {
  name                       = var.subscription_name
  topic                      = google_pubsub_topic.pubusub_topic.name
  message_retention_duration = "604800s"
}

resource "google_compute_firewall" "allow-lb-ip" {
  depends_on = [google_compute_network.my_vpc]
  priority   = var.FIREWALL_PRIORITY
  name       = "allow-lb-ip"
  network    = google_compute_network.my_vpc[0].name
  allow {
    protocol = "tcp"
    ports    = [var.NODE_PORT]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["allow-lb-ip"]
}

resource "google_kms_crypto_key" "instance_crypto_key" {
  name            = var.instance_ring_name
  key_ring        = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s"
  purpose         = "Encrypt_Decrypt"
}


resource "google_kms_crypto_key_iam_binding" "instance_binding" {
  depends_on    = [google_kms_crypto_key.instance_crypto_key]
  crypto_key_id = google_kms_crypto_key.instance_crypto_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members       = [var.service_agent_instance_email]
}

resource "google_compute_region_instance_template" "instance_template" {
  depends_on   = [google_kms_crypto_key_iam_binding.instance_binding]
  name_prefix  = "instance-template-vpc"
  machine_type = var.machine_type
  region       = var.region

  tags = ["http-server", "allow-lb-ip", "deny-ssh-0"]
  metadata = {
    "startup-script" = <<EOF
      #!/bin/bash
      echo "user=${google_sql_user.users[0].name}" > /tmp/.env
      echo "password=${google_sql_user.users[0].password}" >> /tmp/.env
      echo "host=${google_sql_database_instance.cloud_instance[0].private_ip_address}" >> /tmp/.env
      echo "database=${google_sql_database.database[0].name}" >> /tmp/.env
      echo "projectId=${var.project_id}" >> /tmp/.env
      echo "pubSub=${google_pubsub_topic.pubusub_topic.name}" >> /tmp/.env
      chown csye6225:csye6225 /tmp/.env
      mv /tmp/.env /home/csye6225/webapp/
      sudo systemctl start node.service
    EOF
  }

  disk {
    source_image = "projects/dev-csye-6225/global/images/${var.image_name}"
    auto_delete  = true
    boot         = true
    disk_size_gb = var.boot_disk_size
    disk_type    = var.boot_disk_type
    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.instance_crypto_key.id
    }
  }

  network_interface {
    network    = google_compute_network.my_vpc[0].self_link
    subnetwork = google_compute_subnetwork.webapp[0].self_link

    access_config {
      network_tier = "PREMIUM"
    }
  }

  service_account {
    email  = google_service_account.my_service_account.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_compute_health_check" "webapp_health_check" {
  name                = "webapp-health-check"
  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    request_path = "/healthz"
    port         = 8080
  }
}

resource "google_compute_region_instance_group_manager" "webapp_instance_group" {
  name               = "webapp-instance-group"
  region             = var.region
  base_instance_name = "webapp"
  target_size        = 1

  version {
    instance_template = google_compute_region_instance_template.instance_template.self_link
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.webapp_health_check.self_link
    initial_delay_sec = 300
  }
  named_port {
    name = "http"
    port = 8080
  }
}

resource "google_compute_region_autoscaler" "webapp_autoscaler" {
  name   = "webapp-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.webapp_instance_group.id

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = var.cooldown_period

    cpu_utilization {
      target = var.autoscale_policy
    }
  }
}

resource "google_compute_backend_service" "webapp_backend_service" {
  name                            = "web-backend-service"
  project                         = var.project_id
  connection_draining_timeout_sec = 0
  health_checks                   = [google_compute_health_check.webapp_health_check.self_link]
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  port_name                       = "http"
  protocol                        = "HTTP"
  session_affinity                = "NONE"
  timeout_sec                     = 30
  backend {
    group           = google_compute_region_instance_group_manager.webapp_instance_group.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "webapp_url_map" {
  name            = "webapp-url-map"
  default_service = google_compute_backend_service.webapp_backend_service.self_link
}

resource "google_compute_managed_ssl_certificate" "webapp_ssl_cert" {
  project  = var.project_id
  name     = var.ssl_certificate_name
  provider = google-beta
  managed {
    domains = [var.domain_name]
  }
}

resource "google_compute_target_https_proxy" "webapp_https_proxy" {
  name             = "webapp-https-proxy"
  url_map          = google_compute_url_map.webapp_url_map.self_link
  depends_on       = [google_compute_managed_ssl_certificate.webapp_ssl_cert]
  ssl_certificates = [google_compute_managed_ssl_certificate.webapp_ssl_cert.name]
  project          = var.project_id
}

resource "google_compute_global_address" "webapp_global_ip" {
  ip_version = "IPV4"
  name       = "webapp-global-ip"
}

resource "google_compute_global_forwarding_rule" "webapp_forwarding_rule" {

  name                  = "webapp-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.webapp_https_proxy.id
  ip_address            = google_compute_global_address.webapp_global_ip.id
}

resource "google_dns_record_set" "a_record" {
  count        = var.vpc_count
  name         = var.a_record_name
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone
  rrdatas      = [google_compute_global_address.webapp_global_ip.address]
}

resource "google_kms_crypto_key" "bucket_crypto_key" {
  name            = var.bucket_key_ring_name
  key_ring        = google_kms_key_ring.my_key_ring.id
  rotation_period = "2592000s"


  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }
}

data "google_storage_project_service_account" "gcs_account" {
}

resource "google_kms_crypto_key_iam_binding" "binding" {
  crypto_key_id = google_kms_crypto_key.bucket_crypto_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_bucket" "bucket" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket_crypto_key.id
  }
  depends_on = [google_kms_crypto_key_iam_binding.binding]
}

resource "google_storage_bucket_iam_binding" "public" {
  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.objectViewer"

  members = [
    "allUsers",
  ]
}


resource "google_storage_bucket_object" "object" {
  name   = var.bucket_object_name
  bucket = google_storage_bucket.bucket.name
  source = var.bucket_object_source
}
resource "google_compute_subnetwork" "custom_subnet" {
  name          = "${var.vpc_name}-custom-subnet"
  ip_cidr_range = var.custom_subnet_cidr_range
  region        = var.region
  network       = google_compute_network.my_vpc[0].self_link
}

resource "google_vpc_access_connector" "my_connector" {
  name          = var.vpc_access_connector_name
  region        = var.region
  network       = google_compute_network.my_vpc[0].name
  ip_cidr_range = var.vpc_access_connector_cidr_range
}


resource "google_cloudfunctions2_function" "function" {
  name        = var.function_name
  location    = var.region
  description = "A Cloud Function to send emails"

  build_config {
    entry_point = var.pub_sub_name
    runtime     = var.nodejs_version

    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
        object = google_storage_bucket_object.object.name

      }
    }
  }

  service_config {
    available_memory = var.available_memory
    environment_variables = {
      MAILGUN_API_KEY = var.mailgun_api_key
      MAILGUN_DOMAIN  = var.mailgun_domain
      user            = google_sql_user.users[0].name
      password        = google_sql_user.users[0].password
      database        = google_sql_database.database[0].name
      host            = google_sql_database_instance.cloud_instance[0].private_ip_address
      PUB_SUB_NAME    = var.pub_sub_name
    }
    vpc_connector = google_vpc_access_connector.my_connector.name
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.pubusub_topic.id
  }
}
