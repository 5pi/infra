#!/bin/bash
set -euo pipefail
ETCD_VERSION=3.0.0-beta.0
KUB_VERSION=1.2.4
TORUS_VERSION=0.1.1

ETCD_URL="https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
KUB_URL="https://github.com/kubernetes/kubernetes/releases/download/v${KUB_VERSION}/kubernetes.tar.gz"
TORUS_URL="https://github.com/coreos/torus/releases/download/v${TORUS_VERSION}/torus_v${TORUS_VERSION}_linux_amd64.tar.gz"

cat <<EOF > /etc/apt/apt.conf.d/local
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
}
EOF

sudo systemctl stop apt-daily

# Setup docker repo
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' \
  > /etc/apt/sources.list.d/docker.list

apt-get -qy update
apt-get -qy upgrade

# Install tinc and docker
apt-get -qy install tinc docker-engine

# Set docker options
sed -i 's/^ExecStart=.*/& --storage-driver=overlay --iptables=false --ip-masq=false --bip ${IP_INT_PREFIX}.${INDEX}.1/' /lib/systemd/system/docker.service 

# Install etcd
mkdir /opt/etcd
curl -L "$ETCD_URL" \
  | tar -C /opt/etcd -xzf - --strip-components=1

# Install Kubernetes
curl -L "$KUB_URL" \
  | tar -C /tmp -xzf - kubernetes/server/kubernetes-server-linux-amd64.tar.gz
tar -C /tmp -xzf  /tmp/kubernetes/server/kubernetes-server-linux-amd64.tar.gz kubernetes/server/bin/hyperkube
mv /tmp/kubernetes/server/bin/hyperkube /usr/bin

# Install Torus
mkdir /opt/torus
curl -L "$TORUS_URL" \
  | tar -C /opt/torus -xzf - --strip-components=1

mkdir -p /usr/libexec/kubernetes/kubelet-plugins/volume/exec/coreos.com~torus/
cp /opt/torus/torusblk /usr/libexec/kubernetes/kubelet-plugins/volume/exec/coreos.com~torus/torus

useradd -m -G docker k8s
install -d -m 755 -o k8s -g k8s /etc/kubernetes

# Rsync stuff
rsync -av --chown root:root /tmp/rootfs/ /
