PACKAGE   = github.com/joshgav/go-eh-demo
BASE      = $(GOPATH)/src/$(PACKAGE)
NODE_PATH = test/receiver-node/
GO_PATH   = test/receiver-go/

GO = go
NODE = node
NPM = npm

deploy: dep
	$(BASE)/tools/deploy.sh

build: receivers

receivers: receiver-go receiver-node

receiver-go: dep
	cd $(BASE) && $(GO) build -o $(BASE)/dist/receiver-go ./$(GO_PATH)

receiver-node: npm

dep: $(BASE)
	go get -u github.com/golang/dep
	cd $(BASE) && dep ensure

npm: $(BASE)
	cd $(BASE)/$(NODE_PATH) && $(NPM) install

.PHONY: build receiver dep deploy
