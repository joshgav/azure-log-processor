PACKAGE   = github.com/joshgav/azure-log-processor
BASE      = $(GOPATH)/src/$(PACKAGE)
GO = go

deployment:
	$(BASE)/scripts/deploy.sh

receiver: dep
	cd $(BASE) && $(GO) build -o $(BASE)/out/receiver .

dep:
	go get -u github.com/golang/dep/cmd/dep
	cd $(BASE) && dep ensure

.PHONY: dep deployment receiver
