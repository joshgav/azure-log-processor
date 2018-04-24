PACKAGE  = github.com/joshgav/go-eh-demo
BASE     = $(GOPATH)/src/$(PACKAGE)
GO = go

build: receiver

receiver: dep
	cd $(BASE) && $(GO) build -o $(BASE)/dist/receiver-go ./test/receiver-go/ 

dep: $(BASE)
	cd $(BASE) && dep ensure

deploy:
	$(BASE)/tools/deploy.sh

.PHONY: build receiver dep deploy
