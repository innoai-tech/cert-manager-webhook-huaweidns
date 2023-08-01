WAGON = wagon -p wagon.cue

DEBUG = 0
ifeq ($(DEBUG),1)
	WAGON := $(WAGON) --log-level=debug
endif

ifneq ( ,$(wildcard .secrets/local.mk))
	include .secrets/local.mk
endif

ship:
	$(WAGON) do go ship pushx

fmt:
	cue fmt -s ./cuepkg/...
	cue fmt -s ./cuedevpkg/...

manifests:
	$(WAGON) do export manifests --output .tmp/

airgap:
	$(WAGON) do export airgap --output .tmp/

export KUBECONFIG = ${HOME}/.kube_config/config--infra-staging.yaml
debug.apply:
	kubectl apply -f .tmp/manifests/cert-manager-webhook-huaweidns.yaml

debug:
	kubectl proxy