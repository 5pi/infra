variable "domain" {
  type = "string"
}

variable "api_token" {
  type = "string"
}

variable "cluster_state" {
  type        = "string"
  default     = "existing"
  description = "Set this to 'new' for initial cluster creation"
}

variable "servers" {}

variable "ip_int_prefix" {
  type = "string"
}

variable "image" {
  type    = "string"
  default = "19162982"
}

provider "digitalocean" {
  token = "${var.api_token}"
}

resource "digitalocean_ssh_key" "default" {
  name       = "default"
  public_key = "${file("id_rsa.pub")}"
}

resource "digitalocean_droplet" "master" {
  count              = "${var.servers}"
  name               = "master${count.index}"
  image              = "${var.image}"
  region             = "fra1"
  size               = "512mb"
  private_networking = true
  ipv6               = true
  ssh_keys           = ["${digitalocean_ssh_key.default.id}"]

  provisioner "file" {
    source      = "configure.sh"
    destination = "/tmp/configure.sh"
  }

  provisioner "file" {
    source      = "../config/generated/tinc/master${count.index}/rsa_key.priv"
    destination = "/etc/tinc/default/rsa_key.priv"
  }

  provisioner "file" {
    source      = "../config/generated/master${count.index}.pem"
    destination = "/etc/ssl/server.pem"
  }

  provisioner "file" {
    source      = "../config/generated/master${count.index}-key.pem"
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

resource "digitalocean_record" "master_a" {
  count  = "${var.servers}"
  domain = "${var.domain}"
  type   = "A"
  name   = "master${count.index}"
  value  = "${element(digitalocean_droplet.master.*.ipv4_address_private, count.index)}"
}

resource "digitalocean_record" "edge_a" {
  count  = "${var.servers}"
  domain = "${var.domain}"
  type   = "A"
  name   = "edge"
  value  = "${element(digitalocean_droplet.master.*.ipv4_address, count.index)}"
}

resource "digitalocean_record" "edge_aaaa" {
  count  = "${var.servers}"
  domain = "${var.domain}"
  type   = "AAAA"
  name   = "edge"
  value  = "${element(digitalocean_droplet.master.*.ipv6_address, count.index)}"
}

# Site-specific records / FIXME: use modules
## textkrieg.de
### @
resource "digitalocean_record" "textkrieg_a" {
  count  = "${var.servers}"
  domain = "textkrieg.de"
  name   = "@"
  type   = "A"
  value  = "${element(digitalocean_droplet.master.*.ipv4_address, count.index)}"
}
resource "digitalocean_record" "textkrieg_aaaa" {
  count  = "${var.servers}"
  domain = "textkrieg.de"
  name   = "@"
  type   = "AAAA"
  value  = "${element(digitalocean_droplet.master.*.ipv6_address, count.index)}"
}
### www
resource "digitalocean_record" "textkrieg_www_a" {
  count  = "${var.servers}"
  domain = "textkrieg.de"
  name   = "www"
  type   = "A"
  value  = "${element(digitalocean_droplet.master.*.ipv4_address, count.index)}"
}
resource "digitalocean_record" "textkrieg_www_aaaa" {
  count  = "${var.servers}"
  domain = "textkrieg.de"
  name   = "www"
  type   = "AAAA"
  value  = "${element(digitalocean_droplet.master.*.ipv6_address, count.index)}"
}
## 5pi.de
### @
resource "digitalocean_record" "5pi_a" {
  count  = "${var.servers}"
  domain = "5pi.de"
  name   = "@"
  type   = "A"
  value  = "${element(digitalocean_droplet.master.*.ipv4_address, count.index)}"
}
resource "digitalocean_record" "5pi_aaaa" {
  count  = "${var.servers}"
  domain = "5pi.de"
  name   = "@"
  type   = "AAAA"
  value  = "${element(digitalocean_droplet.master.*.ipv6_address, count.index)}"
}
### www
resource "digitalocean_record" "5pi_www_a" {
  count  = "${var.servers}"
  domain = "5pi.de"
  name   = "www"
  type   = "A"
  value  = "${element(digitalocean_droplet.master.*.ipv4_address, count.index)}"
}
resource "digitalocean_record" "5pi_www_aaaa" {
  count  = "${var.servers}"
  domain = "5pi.de"
  name   = "www"
  type   = "AAAA"
  value  = "${element(digitalocean_droplet.master.*.ipv6_address, count.index)}"
}

