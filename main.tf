provider "google" {
  project     = "dev-csye-6225"
  region      = "us-east1"
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
  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [var.source_range]
  target_tags   = ["deny-ssh-${count.index}"]
}

resource "google_compute_instance" "instances" {
  depends_on = [google_compute_network.my_vpc, google_compute_subnetwork.webapp, google_compute_firewall.allow_application_traffic]
  count      = var.vpc_count
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
      network_tier = "PREMIUM"
    }
    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/dev-csye-6225/regions/us-east1/subnetworks/webapp-${count.index}"
  }
  tags = ["http-server", "open-http-${count.index}", "deny-ssh-${count.index}"]
  zone = var.zone
}
