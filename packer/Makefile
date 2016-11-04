REVISION := $(shell git rev-parse --short HEAD)
BRANCH   := $(shell git rev-parse --abbrev-ref HEAD)
DO_TOKEN ?= $(shell cat ~/.do-token)
CONFIG   ?= ../config

all: check_dirty
	. $(CONFIG)/env && packer build \
		-var api_token=$(DO_TOKEN) \
		-var revision=$(REVISION) \
		-var branch=$(BRANCH) \
		-var region=$$REGION \
		-var config=$(CONFIG) \
		-var build=0 \
		-machine-readable \
		base.json

check_dirty:
	git status --porcelain | grep -q '^ M ' && false || true
