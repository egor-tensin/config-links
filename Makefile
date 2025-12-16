include prelude.mk

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
	./test/local/test.sh

# This is deliberately excluded from test/all, because it's quite destructive.
.PHONY: test/linux-home
test/linux-home:
	./test/linux-home/test.sh

test/docker/%: DO
	cd test/docker && \
		DISTRO='$*' docker compose --progress plain build --force-rm --pull -q && \
		docker compose run --rm test && \
		docker compose down -v

# Xenial has bash 4.3, which doesn't support inherit_errexit, which is a good
# thing to test against.
#
# Keep the list repositories synced with the GitHub actions workflow.
.PHONY: test/docker
test/docker: test/docker/xenial test/docker/focal
