MAKEFLAGS += --no-builtin-rules --no-builtin-variables --warn-undefined-variables
unexport MAKEFLAGS
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

escape = $(subst ','\'',$(1))

define noexpand
ifeq ($$(origin $(1)),environment)
    $(1) := $$(value $(1))
endif
ifeq ($$(origin $(1)),environment override)
    $(1) := $$(value $(1))
endif
ifeq ($$(origin $(1)),command line)
    override $(1) := $$(value $(1))
endif
endef

.PHONY: DO
DO:

.PHONY: all
all: test

.PHONY: test
test: test/local

.PHONY: test/all
test/all: test/local test/docker

.PHONY: test/local
test/local:
	./test/test.sh

test/docker/%: DO
	cd test && \
		DISTRO='$*' docker-compose run --rm test && \
		docker-compose down -v

.PHONY: test/docker
test/docker: test/docker/xenial test/docker/focal
