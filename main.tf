provider "google" {
  project = "braided-potion-413918"
  region = "us-east1" 
}

variable "vpc_name" {
  type    = string
  default = "my-vpc"  # You can provide a default value or leave it empty
}

resource "google_compute_network" "my_vpc" {
  name = var.vpc_name
  auto_create_subnetworks = false
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "webapp" {
  name          = "webapp"
  region        = "us-east1"  # Change this to your desired region
  network       = google_compute_network.my_vpc.self_link
  ip_cidr_range = "10.0.1.0/24"  # Change this to your desired CIDR range
}

resource "google_compute_route" "webapp_route" {
  name                   = "webapp-route"
  network                = google_compute_network.my_vpc.self_link
  dest_range             = "0.0.0.0/0"
  next_hop_gateway       = "default-internet-gateway"
  depends_on = [ google_compute_subnetwork.webapp ]
  tags = [ "webapp" ]
}

resource "google_compute_subnetwork" "db_subnet" {
  name          = "db"
  region        = "us-east1"  # Change this to your desired region
  network       = google_compute_network.my_vpc.self_link
  ip_cidr_range = "10.0.2.0/24"  # Change this to your desired CIDR rang
}