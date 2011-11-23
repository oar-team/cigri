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
CIGRICONFDIR=/etc
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

tests: spec/Error/*_spec.rb
	@rspec $? ${SPEC_OPTS}

install: install-cigri-libs install-cigri-modules install-cigri-user-cmds 

install-cigri-libs:
	install -d -m 0755 $(DESTDIR)/$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)/$(CIGRIDIR)/lib
	@for file in lib/*; do install -m 0644 $$file $(DESTDIR)/$(CIGRIDIR)/lib/; done

install-cigri-modules:
	install -d -m 0755 $(DESTDIR)/$(CIGRIDIR)
	@for file in modules/*; do install -m 0755 $$file $(DESTDIR)/$(CIGRIDIR)/; done

install-cigri-user-cmds:
	install -d -m 0755 $(DESTDIR)/$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)/$(CIGRIDIR)/bin
	@for cmd in $(USERCMDS) ; do \
		install -m 0755 bin/$$cmd.rb $(DESTDIR)/$(CIGRIDIR)/bin/$$cmd.rb ; \
		echo -e '#!/bin/bash\n' $(DESTDIR)/$(CIGRIDIR)/bin/$$cmd.rb '$$@' > $(DESTDIR)$(BINDIR)/$$cmd ; \
		chmod 755 $(DESTDIR)$(BINDIR)/$$cmd ; \
	done

clean:
	rm -rf doc/rdoc doc/yard .yardoc $(DESTDIR)/$(CIGRIDIR)
	@for cmd in $(USERCMDS) ; do rm $(DESTDIR)$(BINDIR)/$$cmd ; done
