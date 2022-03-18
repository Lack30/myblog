
pwd=$(shell pwd)
msg="rebuilding site $(shell date)"

.PHONY: all
all: build deploy

.PHONY: install
install:
	yarn global add atomic-algolia

.PHONY: build
build:
	hugo -t LoveIt

.PHONY: deploy
deploy: build
	cd $(pwd)/public && \
	git pull && \
	git add . && \
	git commit -m $(msg) && \
	git push -u origin main

	cd $(pwd) && \
	git pull && \
    git add . && \
    git commit -m $(msg) && \
    git push -u origin gh-pages && \
    atomic-algolia
