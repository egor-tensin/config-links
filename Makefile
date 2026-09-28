include prelude.mk

.PHONY: DO
DO:

PKG_NAME ?= config-links
DESTDIR  ?=

$(eval $(call noexpand,PKG_NAME))
$(eval $(call noexpand,DESTDIR))

.PHONY: all
all:

.PHONY: test
test:
	./test/main.sh

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

.PHONY: install
install:
	install -D -m 0644 -t '$(call escape,$(DESTDIR)/usr/share/$(PKG_NAME))'     LICENSE.txt
	install -D -m 0644 -t '$(call escape,$(DESTDIR)/usr/share/doc/$(PKG_NAME))' README.md

	find bin -type f -exec install -D -m 0755 -t '$(call escape,$(DESTDIR)/usr/lib/$(PKG_NAME)/bin)' {} ';'
	find lib -type f -exec install -D -m 0644 -t '$(call escape,$(DESTDIR)/usr/lib/$(PKG_NAME)/lib)' {} ';'

	install -d '$(call escape,$(DESTDIR)/usr/bin)'
	find '$(call escape,$(DESTDIR)/usr/lib/$(PKG_NAME)/bin)' -type f -printf '%P\0' | \
	while IFS= read -d '' -r file; do \
		ln -s -- '$(call escape,/usr/lib/$(PKG_NAME)/bin/)'"$$file" '$(call escape,$(DESTDIR)/usr/bin)' ; \
	done
