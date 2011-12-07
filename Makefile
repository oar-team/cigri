#!/usr/bin/make
# $Id$
SHELL=/bin/bash

PREFIX=/usr/local
MANDIR=$(PREFIX)/man
BINDIR=$(PREFIX)/bin
SBINDIR=$(PREFIX)/sbin
CIGRIDIR=$(PREFIX)/share/cigri
DOCDIR=$(PREFIX)/share/doc/cigri
VARDIR=/var/lib/cigri
CIGRICONFDIR=/etc/cigri
WWWDIR=/var/www
WWWUSER=www-data
WWWGROUP=www-data
CIGRIUSER=cigri
CIGRIGROUP=cigri
USERCMDS=$(patsubst bin/%.rb,%,$(wildcard bin/*.rb))

SPEC_OPTS=--colour --format nested

.PHONY: man

all: usage

usage:
	@echo "WORK IN PROGRESS..."
	@echo "Usage: make < install | rdoc | yard | tests | cov >"

rdoc:
	rdoc -o doc/rdoc

yard:
	yard -o doc/yard lib modules

spec: tests

rspec: tests

tests: spec/**/*_spec.rb
	@rspec $? ${SPEC_OPTS}

install: install-cigri-libs install-cigri-modules install-cigri-user-cmds install-cigri-launcher install-cigri-api install-cigri-config

install-cigri-libs:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/lib
	@for file in lib/*; do install -m 0644 $$file $(DESTDIR)$(CIGRIDIR)/lib/; done

install-cigri-modules:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/modules
	@for file in modules/*; do install -m 0755 $$file $(DESTDIR)$(CIGRIDIR)/modules; done

install-cigri-user-cmds:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/bin
	@for cmd in $(USERCMDS) ; do \
		install -m 0755 bin/$$cmd.rb $(DESTDIR)$(CIGRIDIR)/bin/$$cmd.rb ; \
		echo -e '#!/bin/bash\n'$(CIGRIDIR)/bin/$$cmd.rb '$$@' > $(DESTDIR)$(BINDIR)/$$cmd ; \
		chmod 755 $(DESTDIR)$(BINDIR)/$$cmd ; \
	done

install-cigri-launcher:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/sbin
	install -m 0755 sbin/cigri_start.in $(DESTDIR)$(SBINDIR)/cigri_start
	perl -pi -e "s#%%CIGRIDIR%%#$(CIGRIDIR)#g;;\
	     s#%%CIGRIUSER%%#$(CIGRIUSER)#g" $(DESTDIR)$(SBINDIR)/cigri_start
	
install-cigri-api:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/api
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/api/config
	@for file in api/*; do install -m 0755 $$file $(DESTDIR)$(CIGRIDIR)/api; done
	install -m 0755 api/config/environment.rb.in $(DESTDIR)$(CIGRIDIR)/api/config/environment.rb
	perl -pi -e "s#%%CIGRIDIR%%#$(CIGRIDIR)#g;;\
             s#%%CIGRIUSER%%#$(CIGRIUSER)#g" $(DESTDIR)$(CIGRIDIR)/api/config/environment.rb
	perl -pi -e "s#%%CIGRIDIR%%#$(CIGRIDIR)#g;;\
             s#%%CIGRIUSER%%#$(CIGRIUSER)#g" $(DESTDIR)$(CIGRIDIR)/api/launch_api.sh.in
	mv $(DESTDIR)$(CIGRIDIR)/api/launch_api.sh.in $(DESTDIR)$(CIGRIDIR)/api/launch_api.sh

install-cigri-config:
	install -d -m 0755 $(DESTDIR)$(CIGRICONFDIR)
	if [ -f $(DESTDIR)$(CIGRICONFDIR)/cigri.conf ]; then echo "$(DESTDIR)$(CIGRICONFDIR)/cigri.conf found, not erasing."; \
		else install -m 0600 etc/cigri.conf $(DESTDIR)$(CIGRICONFDIR)/cigri.conf; fi
	chown $(CIGRIUSER) $(DESTDIR)$(CIGRICONFDIR)/cigri.conf
	if [ -f $(DESTDIR)$(CIGRICONFDIR)/api-clients.conf ]; then echo "$(DESTDIR)$(CIGRICONFDIR)/api-clients.conf found, not erasing."; \
		else install -m 0644 etc/api-clients.conf $(DESTDIR)$(CIGRICONFDIR)/api-clients.conf; fi
	chown $(CIGRIUSER) $(DESTDIR)$(CIGRICONFDIR)/api-clients.conf
	if [ -f $(DESTDIR)$(CIGRICONFDIR)/api-apache.conf ]; then echo "$(DESTDIR)$(CIGRICONFDIR)/api-apache.conf found, not erasing."; \
		else install -m 0644 etc/api-apache.conf $(DESTDIR)$(CIGRICONFDIR)/api-apache.conf; fi
	chown $(WWWUSER) $(DESTDIR)$(CIGRICONFDIR)/api-apache.conf

clean:
	rm -rf doc/rdoc doc/yard .yardoc $(DESTDIR)$(CIGRIDIR)
	@for cmd in $(USERCMDS) ; do rm $(DESTDIR)$(BINDIR)/$$cmd ; done
	rm -f $(DESTDIR)$(SBINDIR)/cigri_start
