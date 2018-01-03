.DEFAULT_GOAL := help
.PHONY: help
help: ## Display make tasks
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

export NAME        := kraken
export VERSION     ?= 1.2.4
export TYPE        ?= alpha
export KLIB_VER    ?= latest
export COMMIT      := $(shell git rev-parse HEAD)

.PHONY: bootstrap
bootstrap: setup ## get tools needed for local project development work
	go get github.com/jteeuwen/go-bindata/...

goreleaser := ${GOPATH}/bin/goreleaser
$(goreleaser):
	go get -u github.com/goreleaser/goreleaser/...

gometalinter := ${GOPATH}/bin/gometalinter
$(gometalinter):
	go get github.com/alecthomas/gometalinter

.PHONY: vet
vet: $(gometalinter) ## validate code and configuration
	gometalinter --install
	gometalinter --vendored-linters \
		--disable-all \
		--enable=vet \
		--enable=gofmt \
		--enable=golint \
		--enable=gosimple \
		--sort=path \
		--aggregate \
		--vendor \
		--tests \
		./...

.PHONY: unit-test
unit-test: ## run unit tests
	go test -v -race ./...

.PHONY: accpt-test-aws
accpt-test-aws: HOME = ${PWD}
accpt-test-aws: ## run acceptance tests for AWS (set CI_JOB_ID for local testing)
	hack/accpt_test aws

.PHONY: accpt-test-gke
accpt-test-gke: ## run acceptance tests for GKE (set CI_JOB_ID for local testing)
	hack/accpt_test gke

.PHONY: build # Usage: target=linux make build
build: $(goreleaser) ## build the golang executable for the target archtectures
	goreleaser --rm-dist --snapshot

.PHONY: release
release: $(goreleaser) ## release the kraken with a github release
	VERSION=$(VERSION) TYPE=$(TYPE) $KLIB_VER=$(KLIB_VER) goreleaser --rm-dist

.PHONY: local_build
local_build: ## build for your machine
	CGO_ENABLED=0 go build .

.PHONY: clean
clean: ## Cleanup after make compile
	-rm -rf build dist

.PHONY: regenerate-bindata
regenerate-bindata: ## Regnerate cmd/bindata.go after changes in ./data/
	go-bindata data/
	sed s/package\ main/package\ cmd/ < bindata.go > cmd/bindata.go
	gofmt -s -w cmd/bindata.go
	rm bindata.go