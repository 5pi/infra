#!/bin/bash
torus_etcd_flags="-C https://$(hostname):2379 --etcd-ca-file /etc/ssl/5pi-ca.pem --etcd-cert-file /etc/ssl/server.pem --etcd-key-file /etc/ssl/server-key.pem"

alias torusctl="torusctl $torus_etcd_flags"
alias torusblk="torusblk $torus_etcd_flags"


alias etcdctl="etcdctl --endpoints https://$(hostname):2379 --ca-file /etc/ssl/5pi-ca.pem --cert-file /etc/ssl/server.pem --key-file /etc/ssl/server-key.pem cluster-health"

