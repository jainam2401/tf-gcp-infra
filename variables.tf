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

variable "dns_zone" {
  type = string
}

variable "a_record_name" {
  type = string
}

variable "pub_sub_name" {
  type = string
}
variable "subscription_name" {
  type = string
}

variable "bucket_name" {
  type = string
}
variable "bucket_location" {
  type = string
}
variable "mailgun_api_key" {
  type = string
}
variable "mailgun_domain" {
  type = string
}

variable "function_name" {
  type = string
}

variable "custom_subnet_cidr_range" {
  type = string
}

variable "vpc_access_connector_cidr_range" {
  type = string
}

variable "vpc_access_connector_name" {
  type = string
}

variable "nodejs_version" {
  type = string
}

variable "available_memory" {
  type = string
}

variable "bucket_object_name" {
  type = string
}

variable "bucket_object_source" {
  type = string
}

variable "max_replicas" {
  type = number
}
variable "min_replicas" {
  type = number
}
variable "cooldown_period" {
  type = number
}
variable "autoscale_policy" {
  type = number
}
variable "ssl_certificate_name" {
  type = string
}
variable "domain_name" {
  type = string
}

variable "key_ring_name" {
  type = string
}
variable "instance_ring_name" {
  type = string
}

variable "sql_ring_name" {
  type = string
}

variable "service_agent_instance_email" {
  type = string
}
variable "bucket_key_ring_name" {
  type = string
}
