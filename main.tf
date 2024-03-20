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

# Allocate IP range for the Private Services Access
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

resource "google_sql_database_instance" "cloud_instance" {
  depends_on       = [google_service_networking_connection.private_vpc_connection]
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
  name       = "allow-httpterra-firewall-${count.index}"
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
  account_id   = "my-service-account"
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

resource "google_compute_instance" "instances" {
  depends_on = [
    google_compute_address.instance_static_ip,
    google_compute_network.my_vpc,
    google_compute_subnetwork.webapp,
    google_compute_firewall.allow_application_traffic,
    google_sql_database_instance.cloud_instance
  ]
  count = var.vpc_count
  boot_disk {
    auto_delete = true
    device_name = "instance-vpc-${count.index}"

    initialize_params {
      image = "projects/dev-csye-6225/global/images/${var.image_name}"
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
    mode = "READ_WRITE"
  }
  machine_type = "e2-medium"
  name         = "instance-vpc-${count.index}"
  network_interface {
    access_config {
      nat_ip       = google_compute_address.instance_static_ip[count.index].address
      network_tier = "PREMIUM"
    }
    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/dev-csye-6225/regions/us-east1/subnetworks/webapp-${count.index}"
  }
  tags = ["http-server", "open-http-${count.index}", "deny-ssh-${count.index}"]
  zone = var.zone
  metadata = {
    "startup-script" = <<EOF
      #!/bin/bash
      echo "user=${google_sql_user.users[count.index].name}" > /tmp/.env
      echo "password=${google_sql_user.users[count.index].password}" >> /tmp/.env
      echo "host=${google_sql_database_instance.cloud_instance[count.index].private_ip_address}" >> /tmp/.env
      echo "database=${google_sql_database.database[count.index].name}" >> /tmp/.env
      echo "projectId=${var.project_id}" >> /tmp/.env
      chown csye6225:csye6225 /tmp/.env
      mv /tmp/.env /home/csye6225/webapp/
      sudo systemctl start node.service
    EOF
  }
   service_account {
    email  = google_service_account.my_service_account.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
resource "google_dns_record_set" "a_record" {
  count        = var.vpc_count
  name         = "jainammehta.website."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone
  rrdatas      = [google_compute_address.instance_static_ip[count.index].address]
}
