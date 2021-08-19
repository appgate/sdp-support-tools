variable "namespace" {
    description = "Namespace/prefix"
    type=string
}

variable "ownertag" {
    description = "Owner Tag"
    type=string
}

variable "envtag" {
    description = "Environment Tag"
    type=string
}

variable "aws_region" {
    description = "EC2 Region for the VPC"
    type=string
}

variable "vpc_cidr" {
    description = "CIDR for the whole VPC"
    default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    description = "CIDR for the Public Subnet"
    default = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
    description = "CIDR for the Private Subnet"
    default = "10.0.1.0/24"
}
