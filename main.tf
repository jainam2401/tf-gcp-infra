provider "google" {
  credentials = file("/Users/jainammehta/Desktop/Cloud/dev-csye-6225-08af72cd9221.json")
  project     = "dev-csye-6225"
  region      = "us-east1"
}

resource "google_compute_network" "my_vpc" {
  count                   = var.vpc_count
  name                    = "${var.vpc_name}-${count.index}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "webapp" {
  count         = var.vpc_count
  name          = "webapp-${count.index}"
  region        = var.region
  network       = google_compute_network.my_vpc[count.index].self_link
  ip_cidr_range = "10.0.1.0/${var.cidr_range}"
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
  ip_cidr_range = "10.0.2.0/${var.cidr_range}"
}

resource "google_compute_firewall" "allow_application_traffic" {
  depends_on = [google_compute_network.my_vpc]
  priority   = 1000
  count      = var.vpc_count
  name       = "allow-http-firewall-${count.index}"
  network    = google_compute_network.my_vpc[count.index].name
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["open-http-${count.index}"]
}

resource "google_compute_instance" "instances" {
  depends_on = [google_compute_network.my_vpc, google_compute_subnetwork.webapp, google_compute_firewall.allow_application_traffic]
  count      = var.vpc_count
  boot_disk {
    auto_delete = true
    device_name = "instance-vpc-${count.index}"

    initialize_params {
      image = "projects/dev-csye-6225/global/images/centos-image"
      size  = 100
      type  = "pd-balanced"
    }
    mode = "READ_WRITE"
  }
  machine_type = "e2-medium"
  name         = "instance-vpc-${count.index}"
  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }
    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/dev-csye-6225/regions/us-east1/subnetworks/webapp-${count.index}"
  }
  tags = ["http-server", "open-http-${count.index}"]
  zone = "us-east1-b"
}
