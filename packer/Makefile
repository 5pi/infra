REVISION := $(shell git rev-parse --short HEAD)
BRANCH   := $(shell git rev-parse --abbrev-ref HEAD)
DO_TOKEN ?= $(shell cat ~/.do-token)

all: check_dirty
	packer build \
		-var api_token=$(DO_TOKEN) \
		-var revision=$(REVISION) \
		-var branch=$(BRANCH) \
		base.json

check_dirty:
	git status --porcelain | grep -q '^ M ' && false || true
