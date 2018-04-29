PACKAGE   = github.com/joshgav/azure-log-processor
BASE      = $(GOPATH)/src/$(PACKAGE)
NODE_PATH = test/receiver-node/
GO_PATH   = test/receiver-go/
PYTHON_PATH = test/receiver-py/

GO = go
NODE = node
NPM = npm
PYTHON = python

deploy: dep
	$(BASE)/tools/deploy/deploy.sh

build: receivers

receivers: receiver-go receiver-node

receiver-go: dep
	cd $(BASE) && $(GO) build -o $(BASE)/dist/receiver-go ./$(GO_PATH)

receiver-node: npm

receiver-py: pip

dep: $(BASE)
	go get -u github.com/golang/dep
	cd $(BASE) && dep ensure

npm: $(BASE)
	cd $(BASE)/$(NODE_PATH) && $(NPM) install

pip: $(BASE)

.PHONY: deploy build receivers receiver-go receiver-node receiver-py dep npm pip
