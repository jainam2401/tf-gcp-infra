variable "vpc_name" {
  type    = string
  default = "my-vpc"
}

variable "vpc_count" {
  type    = number
  default = 1
}

variable "cidr_range" {
  type    = number
  default = 24
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "auto_create_subnetworks" {
  type    = bool
  default = false
}

variable "routing_mode" {
  type    = string
  default = "REGIONAL"
}

variable "webapp_cidr_block" {
  type    = string
  default = "10.0.1.0"
}

variable "db_cidr_block" {
  type    = string
  default = "10.0.2.0"
}

variable "NODE_PORT" {
  type    = string
  default = "8080"
}

variable "source_range" {
  type    = string
  default = "0.0.0.0/0"
}

variable "image_name" {
  type    = string
  default = "centos-image"
}

variable "boot_disk_size" {
  type    = number
  default = 100
}

variable "boot_disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "zone" {
  type    = string
  default = "us-east1-b"
}
