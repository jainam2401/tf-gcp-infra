provider "google" {
  project = "braided-potion-413918"
  region  = "us-east1"
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
  count         = var.vpc_count
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