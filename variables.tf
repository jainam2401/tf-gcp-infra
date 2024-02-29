variable "project_id" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "vpc_count" {
  type = number
}

variable "cidr_range" {
  type = number
}

variable "region" {
  type = string
}

variable "auto_create_subnetworks" {
  type = bool
}

variable "routing_mode" {
  type = string
}

variable "webapp_cidr_block" {
  type = string
}

variable "db_cidr_block" {
  type = string
}

variable "NODE_PORT" {
  type = string
}

variable "source_range" {
  type = string
}

variable "image_name" {
  type = string
}

variable "boot_disk_size" {
  type = number
}

variable "boot_disk_type" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "zone" {
  type = string
}

variable "FIREWALL_PRIORITY" {
  type = number
}

variable "database_username" {
  type = string
}

variable "database_name" {
  type = string
}

variable "disk_type" {
  type = string
}

variable "disk_size" {
  type = number
}

variable "availability_type" {
  type = string
}

variable "password_length" {
  type = number
}

variable "database_version" {
  type = string
}