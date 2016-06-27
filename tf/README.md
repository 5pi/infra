# Terraform Deployment
## Prerequisits
- `id\_rsa.pub`, a pub key the machine terraform runs on has access to
- add private key to ssh agent
- create domain

## Operations
**When update a existing stack, always use -parallelism=1 or the etcd cluster
will loose quorum!**

To deploy a new cluster, you need to run `terraform apply -var
cluster_state=new` which will configure etcd in initial bootstrapping mode.

All subsequential runs of terraform should omit `cluster_state=new` which will
disable etcd bootstrapping and make upgrades to the system wait for a healthy
cluster state before continuing.
