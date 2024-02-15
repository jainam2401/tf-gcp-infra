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