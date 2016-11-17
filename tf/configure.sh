#!/bin/bash
exec > /tmp/configure.log 2>&1
ETCDCTL="etcdctl --endpoints https://$(hostname):2379 --ca-file /etc/ssl/5pi-ca.pem --cert-file /etc/ssl/server.pem --key-file /etc/ssl/server-key.pem"

# First fix permissions, no matter what. See hashicorp/terraform#8811
chmod 640  /etc/ssl/server-key.pem
chown :k8s /etc/ssl/server-key.pem
set -euo pipefail
. /etc/environment.tf

# Add servers to /etc/hosts
for ((i=0;i<SERVERS;i++)); do
  echo "${IP_INT_PREFIX}.$i.1 master$i"
done >> /etc/hosts

# Enable swap
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
if ! grep /swapfile /etc/fstab; then
	echo '/swapfile   none    swap    sw    0   0' >> /etc/fstab
fi

# Bring up tinc
systemctl enable tinc@default
systemctl start tinc@default

# Calculate IP_INT
IP_INT="${IP_INT_PREFIX}.${INDEX}.1"

# Configuring etcd
ETCD_SERVERS=
CLUSTER=
for ((i=0;i<SERVERS;i++)); do
  ETCD_SERVERS="https://master$i:2379,$ETCD_SERVERS"
  CLUSTER="master$i=https://${IP_INT_PREFIX}.$i.1:2380,$CLUSTER"
done

case "$STATE" in
  new)
    ETCD_OPTS="--initial-cluster-state new --initial-cluster $CLUSTER --initial-advertise-peer-urls https://$IP_INT:2380"
    ;;
  existing)
    ETCD_OPTS="--initial-cluster-state existing --initial-cluster $CLUSTER"
    ;;
  *)
    echo "State $STATE is invalid, aborting" >&2
    exit 1 
esac

cat <<EOF > /etc/environment.calc
ETCD_OPTS='$ETCD_OPTS'
ETCD_SERVERS='$ETCD_SERVERS'
IP_INT='$IP_INT'
EOF

# Enabling services here, so they don't come up unconfigured
for s in etcd k8s-apiserver k8s-controller-manager \
    k8s-kubelet k8s-proxy k8s-scheduler docker node_exporter; do
  systemctl enable "$s"
  systemctl start  "$s" --no-block
done

if [[ "$STATE" == "new" ]]; then
  exit 0
fi

# Waiting for things to be ready
if [ "$STATE" = "existing" ]; then
  while ! $ETCDCTL cluster-health; do
    echo "Waiting for cluster to become healthy"
    sleep 1
  done
fi
