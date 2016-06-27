#!/bin/bash
exec > /tmp/configure.log 2>&1

set -euo pipefail
. /etc/environment.tf

# Calculate IP_INT
IP_INT="${IP_INT_PREFIX}.${INDEX}.1"

# Configuring consul
case "$STATE" in
  new)
    CLUSTER=
    for ((i=0;i<SERVERS;i++)); do
      CLUSTER="master$i=http://${IP_INT_PREFIX}.$i.1:2380,$CLUSTER"
    done

    OPTS="--initial-cluster-state new --initial-cluster $CLUSTER  --initial-advertise-peer-urls http://$IP_INT:2380"
    ;;
  existing)
    ENDPOINTS=
    for ((i=0;i<=SERVERS;i++)); do
      [ "$i" -eq "$INDEX" ] && continue
      ENDPOINTS="http://${IP_INT_PREFIX}.$i.1:4001,$ENDPOINTS"
    done

    /opt/etcd/etcdctl --endpoint $ENDPOINTS member add $(hostname) "http://$IP_INT:2380"
    OPTS="--initial-cluster-state existing"
    ;;
  *)
    echo "State $STATE is invalid, aborting" >&2
    exit 1 
esac

cat <<EOF > /etc/environment.calc
OPTS='$OPTS'
IP_INT='$IP_INT'
EOF

# Enabling services here, so they don't come up unconfigured
for s in tinc@default etcd k8s-apiserver k8s-controller-manager \
         k8s-kubelet k8s-proxy k8s-scheduler; do
  systemctl enable "$s"
  systemctl start  "$s" || true # Might fail due to lack of other cluster members not being up yet
done

# Waiting for things to be ready
if [ "$STATE" = "existing" ]; then
  while ! /opt/etcd/etcdctl cluster-health; do
    echo "Waiting for cluster to become healthy"
    sleep 1
  done
fi
