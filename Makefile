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
APIBASE=/cigri-api
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

install: 
	@echo "Please, use install-cigri, install-cigri-server or install-cigri-user."

install-cigri: install-cigri-server install-cigri-user

install-cigri-server: install-cigri-libs install-cigri-modules install-cigri-launcher install-cigri-api install-cigri-server-config

install-cigri-user: install-cigri-libs install-cigri-user-cmds install-cigri-user-config

install-cigri-libs:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/lib
	@for file in lib/*; do install -m 0644 $$file $(DESTDIR)$(CIGRIDIR)/lib/; done
	mv $(DESTDIR)$(CIGRIDIR)/lib/cigri-clientlib.rb.in $(DESTDIR)$(CIGRIDIR)/lib/cigri-clientlib.rb
	perl -pi -e "s#%%CIGRICONFDIR%%#$(CIGRICONFDIR)#g" $(DESTDIR)$(CIGRIDIR)/lib/cigri-clientlib.rb

install-cigri-modules:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/modules
	@for file in modules/*; do install -m 0755 $$file $(DESTDIR)$(CIGRIDIR)/modules; done

install-cigri-user-cmds:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/bin
	@for cmd in $(USERCMDS) ; do \
		install -m 0755 bin/$$cmd.rb $(DESTDIR)$(CIGRIDIR)/bin/$$cmd.rb ; \
		echo -e '#!/bin/bash\nCIGRICONFFILE=$(CIGRICONFDIR)/api-clients.conf '$(CIGRIDIR)/bin/$$cmd.rb '$$@' > $(DESTDIR)$(BINDIR)/$$cmd ; \
		chmod 755 $(DESTDIR)$(BINDIR)/$$cmd ; \
	done

install-cigri-user-config:
	if [ -f $(DESTDIR)$(CIGRICONFDIR)/api-clients.conf ]; then echo "$(DESTDIR)$(CIGRICONFDIR)/api-clients.conf found, not erasing."; \
	else install -m 0644 etc/api-clients.conf.in $(DESTDIR)$(CIGRICONFDIR)/api-clients.conf; \
		perl -pi -e "s#%%CIGRIDIR%%#$(CIGRIDIR)#g;;\
		s#%%APIBASE%%#$(APIBASE)#g" $(DESTDIR)$(CIGRICONFDIR)/api-clients.conf; fi
	chown $(CIGRIUSER) $(DESTDIR)$(CIGRICONFDIR)/api-clients.conf

install-cigri-launcher:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -m 0755 sbin/cigri_start.in $(DESTDIR)$(SBINDIR)/cigri_start
	perl -pi -e "s#%%CIGRIDIR%%#$(CIGRIDIR)#g;;\
	     s#%%CIGRIUSER%%#$(CIGRIUSER)#g" $(DESTDIR)$(SBINDIR)/cigri_start
	
install-cigri-api:
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/api
	@for file in api/*; do install -m 0755 $$file $(DESTDIR)$(CIGRIDIR)/api; done
	# The following activates the magic of Passenger's user switching support
	# so that the API runs under the cigri user:
	chown $(CIGRIUSER) $(DESTDIR)$(CIGRIDIR)/api/config.ru
	# Dont'know why, but this directory must exist or passenger fails
	mkdir -p $(WWWDIR)/cigri-api

install-cigri-server-config:
	install -d -m 0755 $(DESTDIR)$(CIGRICONFDIR)
	if [ -f $(DESTDIR)$(CIGRICONFDIR)/cigri.conf ]; then echo "$(DESTDIR)$(CIGRICONFDIR)/cigri.conf found, not erasing."; \
		else install -m 0600 etc/cigri.conf $(DESTDIR)$(CIGRICONFDIR)/cigri.conf; fi
	chown $(CIGRIUSER) $(DESTDIR)$(CIGRICONFDIR)/cigri.conf
	if [ -f $(DESTDIR)$(CIGRICONFDIR)/api-apache.conf ]; then echo "$(DESTDIR)$(CIGRICONFDIR)/api-apache.conf found, not erasing."; \
		else install -m 0644 etc/api-apache.conf.in $(DESTDIR)$(CIGRICONFDIR)/api-apache.conf; \
		perl -pi -e "s#%%CIGRIDIR%%#$(CIGRIDIR)#g;;\
		s#%%APIBASE%%#$(APIBASE)#g" $(DESTDIR)$(CIGRICONFDIR)/api-apache.conf; fi
	chown $(WWWUSER) $(DESTDIR)$(CIGRICONFDIR)/api-apache.conf

clean:
	rm -rf doc/rdoc doc/yard .yardoc $(DESTDIR)$(CIGRIDIR) $(DESTDIR)$(CIGRICONFDIR)
	@for cmd in $(USERCMDS) ; do rm $(DESTDIR)$(BINDIR)/$$cmd ; done
	rm -f $(DESTDIR)$(SBINDIR)/cigri_start
