
-include .secrets.env
export $(shell sed 's/=.*//' .secrets.env)

GITHUB_TOKEN        ?= default_gh_token
TS_CLIENT_OAUTH_ID  ?= default_ts_id
TS_SECRET_OAUTH_KEY ?= default_ts_key

.PHONY: k3s-up
k3s-up:
	@echo "Checking if k3s is already running"
	@if systemctl is-active --quiet k3s; then \
		echo "Stopping existing k3s cluster"; \
		sudo systemctl stop k3s; \
	fi
	@echo "Ensuring k3s will start without Traefik"
	# Create a systemd override so k3s starts with --disable traefik
	echo 'K3S_EXEC="server --disable traefik"' | sudo tee /etc/systemd/system/k3s.service.env
	sudo systemctl daemon-reexec
	sudo systemctl daemon-reload
	@echo "Starting k3s cluster"
	sudo systemctl start k3s
	@echo "k3s cluster is now running."
	@systemctl status --no-pager k3s | grep Active
	@echo "Copying k3s kubeconfig to ~/.kube/config"
	mkdir -p $$HOME/.kube
	sudo cp /etc/rancher/k3s/k3s.yaml $$HOME/.kube/config
	sudo chown $$(id -u):$$(id -g) $$HOME/.kube/config
	@echo "kubeconfig is now at $$HOME/.kube/config"
	kubectl get nodes

.PHONY: k3s-down
k3s-down:
	@echo "Stopping k3s cluster"
	@if systemctl is-active --quiet k3s; then \
		sudo systemctl stop k3s; \
		echo "k3s cluster stopped."; \
	else \
		echo "k3s is not running."; \
	fi

.PHONY: k3s-status
k3s-status:
	@systemctl status --no-pager k3s || true

.PHONY: k3s-install
k3s-install: # disable traefik in favor of using nginx or tailscale
	curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik" sh -

.PHONY: argo-install
argo-install:
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update

	helm upgrade -i argocd argo/argo-cd \
		--namespace argocd \
		--create-namespace \
		--version 8.3.0

	kubectl apply -n argocd -f gitops/argocd-project.yaml
	kubectl apply -n argocd -f gitops/root-app.yaml

.PHONY: ghcr-secret-setup
ghcr-secret-setup:
	kubectl create ns app || true
	kubectl create secret docker-registry ghcr-secret \
		--docker-server=ghcr.io \
		--docker-username=ytnegmas \
		--docker-password=$(GITHUB_TOKEN) \
		--namespace=app || true

.PHONY: tailscale-secret-setup
tailscale-secret-setup:
	kubectl create ns tailscale || true
	kubectl create secret generic operator-oauth \
		--from-literal=client_id=$(TS_CLIENT_OAUTH_ID) \
		--from-literal=client_secret=$(TS_SECRET_OAUTH_KEY) \
		-n tailscale || true
