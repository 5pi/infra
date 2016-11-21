# 5pi.de Infrastructure
*$15/month kubernetes cluster*

This is how I deploy Kubernetes to DigitalOcean.
This aims to be generic enough to also deploy your infrastructure but there
might be some specifics. The biggest limitation right now is that all servers
are both master and minion which is discouraged for any lager infrastructure.

While it's possible that this will become a generic way to setup any kind of
Kubernetes infrastructures, it's not a top priority. If interested in a
deployment on AWS, have a look at [kops](https://github.com/kubernetes/kops)
which is more active developed.

## Overview
Terraform deploys the infrastructure by setting up network, spinning up servers
with an image build by Packer.

This repository contains [packer](/packer) and [terraform](/tf) configuration.
The directory [config](/config) contains configuration that is shared between
the image and terraform templates. See the individual directories for details.

The infrastructure is designed to be immutable. All state is intended to be kept
on DigitalOcean volumes and all change to the host require a new image and
replacement of all instances.

## Deploying a new stack
First you might want to edit `config/env` to customize:

- `REGION`: The DigitalOcean region your cluster should run in
- `DOMAIN`: The Domain used for the cluster (see [tf](/tf) for details)
- `SERVERS`: Number of servers
- `SERVER_SIZE`: Size of servers
- `IP_INT_PREFIX`: Prefix to use for internal private network (tinc)

Then run `mk_credentials` to create TLS CA and keys in `config/generated/`.

Now the image can be build by running `make -C packer`. After finishing, it
should print image id which is used in the next step.

Enter the `tf/` directory and save a ssh public key to `id_rsa.pub`. This key
will be allowed to ssh into the servers.

A DigitalOcean API token is required for running Packer and Terraform as well as
for attaching the DigitalOcean Volumes. This scripts expect it in `~/.do-token`.

Now the stack can be spun up by running:

```
./terraform apply -var cluster_state=new -var image=image-id-from-last-step
```

## Updating a stack
Since the servers are immutable, configuration shouldn't be changed on the
systems directly. Instead a new image should be built. Once the build finished,
the stack can be updated by running this in `tf/`:

```
./upgrade apply -var image=image-id-from-build
```

This is a small wrapper around terraform to apply changes to the cluster one
server at a time. It removes a server from the cluster gracefully and waits for
a replacement to come up and successfully join the cluster.
