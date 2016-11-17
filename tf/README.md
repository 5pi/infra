# Terraform Deployment
## Prerequisits
- `id\_rsa.pub`, a pub key the machine terraform runs on has access to
- add private key to ssh agent
- create domain

## Operations
To deploy a new cluster, you need to run `terraform apply -var
cluster_state=new` which will configure etcd in initial bootstrapping mode.

The option `cluster_state=new` enables etcd bootstrapping and make it not wait
for a fully formed cluster before continuing. This is required when deploying
the cluster the first time.

Since terraform doesn't provide flexible enough orchestration to support rolling
upgrades, updates to the stack needs to be deployed by running `./upgrade`.
