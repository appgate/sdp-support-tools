provider "aws" {
  region  = "${var.aws_region}"
}

resource "aws_vpc" "default" {
    cidr_block = "${var.vpc_cidr}"
    enable_dns_hostnames = true
  tags = {
    Name = "${var.namespace}-SDP-VPC",
    env = "${var.envtag}",
    owner = "${var.ownertag}"
  }
}

resource "aws_internet_gateway" "default" {
    vpc_id = "${aws_vpc.default.id}"
    tags = {
       Name = "${var.namespace}-Gateway",
       env = "${var.envtag}",
       owner = "${var.ownertag}"
  }
}


# Learn our public IP address
data "http" "icanhazip" {
   url = "http://icanhazip.com"
}


/*
  Public Subnet
*/
resource "aws_subnet" "public-subnet" {
    vpc_id = "${aws_vpc.default.id}"

    cidr_block = "${var.public_subnet_cidr}"
 #   availability_zone = "eu-west-1a"

    tags = {
        Name = "${var.namespace}-Public Subnet"
        env = "${var.envtag}"
        owner = "${var.ownertag}"
    }
}

resource "aws_route_table" "public-subnet" {
    vpc_id = "${aws_vpc.default.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.default.id}"
    }

    tags = {
        Name = "${var.namespace}-Public Route"
        env = "${var.envtag}"
        owner = "${var.ownertag}"
    }
}

resource "aws_route_table_association" "public-subnet" {
    subnet_id = "${aws_subnet.public-subnet.id}"
    route_table_id = "${aws_route_table.public-subnet.id}"
}

/*
  Private Subnet
*/
resource "aws_subnet" "private-subnet" {
    vpc_id = "${aws_vpc.default.id}"

    cidr_block = "${var.private_subnet_cidr}"
#    availability_zone = "eu-west-1a"

    tags = {
        Name = "${var.namespace}-Private Subnet"
        env = "${var.envtag}"
        owner = "${var.ownertag}"
    }
}

resource "aws_route_table" "private-subnet" {
    vpc_id = "${aws_vpc.default.id}"

    route {
        cidr_block = "0.0.0.0/0"
#        instance_id = "${aws_instance.nat.id}"
         gateway_id = "${aws_internet_gateway.default.id}"
    }

    tags = {
        Name = "${var.namespace}-Private Route"
        env = "${var.envtag}"
        owner = "${var.ownertag}"
    }
}

resource "aws_route_table_association" "private-subnet" {
    subnet_id = "${aws_subnet.private-subnet.id}"
    route_table_id = "${aws_route_table.private-subnet.id}"
}


/*
  SDP Server Security groups
*/
resource "aws_security_group" "SDP" {
    name = "${var.namespace}-SDP SG"
    description = "Allow incoming connections from Home IP"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.icanhazip.body)}/32"]
    }


    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 444
        to_port = 444
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.icanhazip.body)}/32"]
    }


    ingress {
        from_port = 8443
        to_port = 8443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }



    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress { # Private Web server
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }

    egress { # Private Web Server SSL
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }

    egress { # LDAP
        from_port = 389
        to_port = 389
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }

    egress { # LDAPS
        from_port = 636
        to_port = 636
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }

    egress { # TCP DNS
        from_port = 53
        to_port = 53
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }

    egress { # UDP DNS
        from_port = 53
        to_port = 53
        protocol = "udp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 8443
        to_port = 8443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    vpc_id = "${aws_vpc.default.id}"

    tags = {
        Name = "${var.namespace}-SDP SG"
        env = "${var.envtag}"
        owner = "${var.ownertag}"
    }
}

/*
  Private Servers
*/
resource "aws_security_group" "SDP-private" {
    name = "${var.namespace}-SDP Private SG"
    description = "Allow incoming connections."

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.icanhazip.body)}/32"]
    }

    ingress {
        from_port = 3389
        to_port = 3389
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.icanhazip.body)}/32"]
    }

    ingress {
        from_port = 5985
        to_port = 5985
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.icanhazip.body)}/32"]
    }

    ingress {
        from_port = 5986
        to_port = 5986
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.icanhazip.body)}/32"]
    }

    ingress { # Web Server
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = ["${aws_security_group.SDP.id}"]
    }

    ingress { # Web Server SSL
        from_port = 443
        to_port = 443
        protocol = "tcp"
        security_groups = ["${aws_security_group.SDP.id}"]
    }

    ingress { # TCP DNS
        from_port = 53
        to_port = 53
        protocol = "tcp"
        security_groups = ["${aws_security_group.SDP.id}"]
    }

    ingress { # UDP DNS
        from_port = 53
        to_port = 53
        protocol = "udp"
        security_groups = ["${aws_security_group.SDP.id}"]
    }

    ingress { # LDAP
        from_port = 389
        to_port = 389
        protocol = "tcp"
        security_groups = ["${aws_security_group.SDP.id}"]
    }

    ingress { # LDAPS
        from_port = 636
        to_port = 636
        protocol = "tcp"
        security_groups = ["${aws_security_group.SDP.id}"]
    }

    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["${var.vpc_cidr}"]
    }

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    vpc_id = "${aws_vpc.default.id}"

    tags = {
        Name = "${var.namespace}-Private SDP SG"
        env = "${var.envtag}"
        owner = "${var.ownertag}"
    }
}

output "SDP-SG-id" {
   value = aws_security_group.SDP.id
}

output "SDP-private-SG-id" {
   value = aws_security_group.SDP-private.id
}

output "SDP-public-subnet-id" {
   value = aws_subnet.public-subnet.id
}

output "SDP-private-subnet-id" {
   value = aws_subnet.private-subnet.id
}

output "SDP-private-subnet-cidr" {
   value = aws_subnet.private-subnet.cidr_block
}
