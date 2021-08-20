BINDIR := bin
ROOT_PACKAGE := $(shell go list .)
VERSION := $(shell git describe --tags --abbrev=0)
REVISION := $(shell git rev-parse --short HEAD)
#GO_LDFLAGS_VERSION := -X '${ROOT_PACKAGE}.VERSION=${VERSION}' -X '${ROOT_PACKAGE}.REVISION=${REVISION}'
GO_LDFLAGS_VERSION := -X 'main.VERSION=${VERSION}' -X 'main.REVISION=${REVISION}'
GO_LDFLAGS := $(GO_LDFLAGS_VERSION)
GO_BUILD := -ldflags "$(GO_LDFLAGS)"

.PHONY: all
all: build

.PHONY: build
build: interceptor.go
	@go build $(GO_BUILD) -o $(BINDIR)/interceptor -v

.PHONY: run
run: build
	@sudo ./bin/interceptor

.PHONY: clean
clean:
	@go clean
	@rm -rf $(BINDIR)

.PHONY: install
install: build
	@sudo cp bin/interceptor /usr/local/bin/interceptor
	@sudo mkdir -p /usr/local/etc/interceptor
	@sudo cp docker-compose.yml /usr/local/etc/interceptor/docker-compose.yml
	@sudo cp -r .secrets /usr/local/etc/interceptor/.secrets
	@sudo cp systemd/dns-query-interceptor@.service /etc/systemd/system/dns-query-interceptor@.service
	@sudo systemctl daemon-reload
	@sudo systemctl enable dns-query-interceptor@vsix.service
	@sudo docker-compose -f /usr/local/etc/interceptor/docker-compose.yml pull
	@sudo docker-compose -f /usr/local/etc/interceptor/docker-compose.yml up -d postgres
	@sleep 5
	@sudo docker-compose -f /usr/local/etc/interceptor/docker-compose.yml stop

.PHONY: uninstall
uninstall:
	@sudo systemctl disable --now dns-query-interceptor@vsix.service
	@sudo docker-compose -f /usr/local/etc/interceptor/docker-compose.yml kill || true
	@sudo docker-compose -f /usr/local/etc/interceptor/docker-compose.yml rm -f || true
	@sudo docker volume rm interceptor_psql interceptor_pgadmin || true
	@sudo rm -rf /usr/local/bin/interceptor /usr/local/etc/interceptor
	@sudo rm -f /etc/systemd/system/dns-query-interceptor@.service
	@sudo systemctl daemon-reload
