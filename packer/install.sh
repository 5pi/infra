#!/bin/bash
set -euo pipefail
ETCD_VERSION=3.0.3
KUB_VERSION=1.2.5
NODE_EXPORTER_VERSION=0.12.0

ETCD_URL="https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
KUB_URL="https://github.com/kubernetes/kubernetes/releases/download/v${KUB_VERSION}/kubernetes.tar.gz"
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

cat <<EOF > /etc/apt/apt.conf.d/local
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
}
EOF
export DEBIAN_FRONTEND=noninteractive

sudo systemctl stop apt-daily

# Setup docker repo
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' \
  > /etc/apt/sources.list.d/docker.list

apt-get -qy update
apt-get -qy dist-upgrade

# Install tinc and docker
apt-get -qy install tinc docker-engine
systemctl disable docker apt-daily

# Configure tinc
mkdir -p /etc/tinc/default/hosts
cat <<EOF > /etc/tinc/default/tinc.conf
Name = \$HOST
AddressFamily = ipv4
Interface = tun0
EOF

for n in /tmp/config/generated/tinc/master*; do
  echo "ConnectTo = $(basename $n)"
done >> /etc/tinc/default/tinc.conf

. /tmp/config/env
i=0
for n in /tmp/config/generated/tinc/master*; do
  cat <<EOF > /etc/tinc/default/hosts/master$i
Address = master$i.$DOMAIN
Subnet = $IP_INT_PREFIX.$i.0/24
$(cat $n/rsa_key.pub)
EOF
  let i++ || true
done
cp /tmp/config/generated/ca.pem /etc/ssl/5pi-ca.pem

# Set docker options
sed -i 's/^ExecStart=.*/& --storage-driver=overlay --iptables=false --ip-masq=false --bip ${IP_INT_PREFIX}.${INDEX}.1/' /lib/systemd/system/docker.service 

# Install etcd
curl -L "$ETCD_URL" \
  | tar -C /usr/bin -xzf - --strip-components=1

# Install Kubernetes
curl -L "$KUB_URL" \
  | tar -C /tmp -xzf - kubernetes/server/kubernetes-server-linux-amd64.tar.gz
tar -C /tmp -xzf  /tmp/kubernetes/server/kubernetes-server-linux-amd64.tar.gz kubernetes/server/bin/hyperkube
mv /tmp/kubernetes/server/bin/hyperkube /usr/bin
ln -s hyperkube /usr/bin/kubectl

# Install my patched Torus
for b in torusblk torusctl torusd; do
	curl -L "https://github.com/discordianfish/torus/releases/download/v0.1.1-fish/$b.linux.amd64.gz" \
		| zcat | install -m 755 /dev/stdin -o root -g root /usr/bin/$b
done

useradd -m -G docker k8s
install -d -m 755 -o k8s -g k8s /etc/kubernetes
openssl genrsa 2048 | install -m600 -ok8s /dev/stdin /etc/kubernetes/serviceaccount.key

# Install node-exporter
curl -L "$NODE_EXPORTER_URL" \
  | tar -C /usr/bin -xzf - --strip-components=1

# Rsync stuff
rsync -av --chown root:root /tmp/rootfs/ /
