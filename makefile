
REGISTRY = ghcr.io/filouz
TAG = local
TAG_DEV = dev

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
ROOT_DIR := $(dir $(mkfile_path))

NAMESPACE=opentrek

#######################################################
#######################################################


tegola_clone: 
	git submodule add https://github.com/filouz/tegola ./tegola/src
	
tegola_build:
	docker build $(ROOT_DIR)/tegola/src -t $(REGISTRY)/tegola:$(TAG)

tegola_push:
	docker push $(REGISTRY)/tegola:$(TAG)

#######################################################

app_build:
	docker build $(ROOT_DIR)/app -t $(REGISTRY)/opentrek/app:$(TAG)

app_push:
	docker push $(REGISTRY)/opentrek/app:$(TAG)


app_dev:
	docker run --rm \
		-v $(shell pwd)/app:/usr/share/nginx/html \
		-p 58080:80 \
		nginx


#######################################################

deploy:
	kubectl apply -f deployment/namespace.yaml
	kubectl apply -f deployment/postgis.yaml
	kubectl apply -f deployment/redis.yaml
	kubectl apply -f deployment/app.yaml
	kubectl apply -f deployment/test.yaml

deploy_jupyter:
	kubectl apply -f deployment/jupyter.yaml
	until kubectl get pods -n $(NAMESPACE) -l app=jupyter -o jsonpath="{.items[0].status.phase}" | grep Running ; do sleep 1 ; done
	@POD=$$(kubectl -n $(NAMESPACE) get pods -l app=jupyter -o jsonpath='{.items[0].metadata.name}'); \
	TOKEN=""; \
	END=$$(date -ud "5 minutes" +%s); \
	while [ -z "$$TOKEN" ]; do \
	  CURRENT=$$(date +%s); \
	  if [ $$CURRENT -ge $$END ]; then \
	    echo "Timeout waiting for Jupyter token."; \
	    exit 1; \
	  fi; \
	  sleep 1; \
	  TOKEN=$$(kubectl -n $(NAMESPACE) exec $$POD -- jupyter notebook list | grep -oP '(?<=token=)[^ ]*' | head -1); \
	done; \
	echo "http://localhost:48081/?token=$$TOKEN"

update:
	kubectl -n opentrek cp ./config/config-mvt-postgis.toml busybox:/data/tegola
	kubectl apply -f deployment/tegola.yaml


clean:
	kubectl get pods -A --field-selector 'status.phase=Failed' -o json | kubectl delete -f -
