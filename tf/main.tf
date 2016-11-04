variable "domain" {
  type = "string"
}

variable "region" {
  type = "string"
}

variable "api_token" {
  type = "string"
}

variable "config" {
  type = "string"
  default = "../config"
}

variable "cluster_state" {
  type        = "string"
  default     = "existing"
  description = "Set this to 'new' for initial cluster creation"
}

variable "servers" {}

variable "server_size" {
  type = "string"
}

variable "ip_int_prefix" {
  type = "string"
}

variable "image" {
  type = "string"
}

provider "digitalocean" {
  token = "${var.api_token}"
}

resource "digitalocean_ssh_key" "default" {
  name       = "default"
  public_key = "${file("id_rsa.pub")}"
}

resource "digitalocean_floating_ip" "edge" {
  region = "${var.region}"
  lifecycle {
    ignore_changes = [ "droplet_id" ]
  }
}

output "edge" {
  value = "${digitalocean_floating_ip.edge.ip_address}"
}

resource "digitalocean_droplet" "master" {
  count              = "${var.servers}"
  name               = "master${count.index}"
  image              = "${var.image}"
  region             = "${var.region}"
  size               = "${var.server_size}"
  private_networking = true
  ipv6               = true
  ssh_keys           = ["${digitalocean_ssh_key.default.id}"]
  lifecycle {
    create_before_destroy = true
  }

  provisioner "file" {
    source      = "configure.sh"
    destination = "/tmp/configure.sh"
  }

  provisioner "file" {
    source      = "${var.config}/generated/tinc/master${count.index}/rsa_key.priv"
    destination = "/etc/tinc/default/rsa_key.priv"
  }

  provisioner "file" {
    source      = "${var.config}/generated/master${count.index}.pem"
    destination = "/etc/ssl/server.pem"
  }

  provisioner "file" {
    source      = "${var.config}/generated/master${count.index}-key.pem"
    destination = "/etc/ssl/server-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "cat <<EOF > /etc/environment.tf",
      "DOMAIN=${var.domain}",
      "INDEX=${count.index}",
      "SERVERS=${var.servers}",
      "IP_INT_PREFIX=${var.ip_int_prefix}",
      "IP_PRIVATE=${self.ipv4_address_private}",
      "STATE=${var.cluster_state}",
      "TORUS_SIZE=20GiB",
      "EOF",
      "chmod a+x /tmp/configure.sh",
      "echo '${var.api_token}' | install -m 640 -g k8s /dev/stdin /etc/do.token",
      "exec /tmp/configure.sh",
    ]
  }
}

output "master_ips" {
  value = "${join(",",digitalocean_droplet.master.*.ipv4_address_public)}"
}

# masterX A record pointing to 'internal' IP, used for finding etcd peers
resource "digitalocean_record" "master_a" {
  count  = "${var.servers}"
  domain = "${var.domain}"
  type   = "A"
  name   = "master${count.index}"
  value  = "${element(digitalocean_droplet.master.*.ipv4_address_private, count.index)}"
}

# edge A record pointing to main LB via floating IP
resource "digitalocean_record" "edge_a" {
  count  = "${var.servers}"
  domain = "${var.domain}"
  type   = "A"
  name   = "edge${count.index}"
  value  = "${element(digitalocean_droplet.master.*.ipv4_address, count.index)}"
}

# *.edge A wildcard record pointing to LB via floating IP
resource "digitalocean_record" "star_edge" {
  domain = "${var.domain}"
  type   = "A"
  name   = "*.edge"
  value  = "${digitalocean_floating_ip.edge.ip_address}"
}

# edgeX A record pointing to the public IPs
resource "digitalocean_record" "edge" {
  domain = "${var.domain}"
  type   = "A"
  name   = "edge"
  value  = "${digitalocean_floating_ip.edge.ip_address}"
}
