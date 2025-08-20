REGISTRY ?= ghcr.io/ytnegmas/onpremk8s
APP_NAME ?= simple-webapp
GIT_SHA  := $(shell git rev-parse --short HEAD)
IMAGE    := $(REGISTRY)/$(APP_NAME):$(GIT_SHA)

.PHONY: all build run test

all: build run test

build:
	docker buildx build -t $(IMAGE) . --load

test:
	curl -s http://localhost:8000/info | tee response.json
	@echo
	docker stop $(APP_NAME) >/dev/null
