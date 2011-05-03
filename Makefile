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

SPEC_OPTS=--colour --format nested

.PHONY: man

all: usage

usage:
	@echo "WORK IN PROGRESS..."
	@echo "Usage: make < rdoc | yard | tests | cov >"

rdoc:
	rdoc -o doc/rdoc

yard:
	yard -o doc/yard lib modules

spec: tests

rspec: tests

tests: spec/*/*_spec.rb
	rspec $? ${SPEC_OPTS}

cov: rcov

rcov: spec/*/*_spec.rb modules/*/* lib/* spec/spec_helper.rb
	rcov -I lib:spec spec/**/*.rb --exclude gems -o doc/rcov -T

test-setup: test-setup-pg test-setup-mysql

test-setup-pg:
	database/init_db.rb -u cigritest -p cigritest -d cigritest -t psql -s database/psql_structure.sql
	sudo -u postgres psql cigritest -f spec/init_fill.sql

test-setup-mysql:
	database/init_db.rb -u cigritest -p cigritest -d cigritest -t mysql -s database/mysql_structure.sql
	mysql -u cigritest -pcigritest cigritest < spec/init_fill.sql


test-clean: test-clean-pg test-clean-mysql

test-clean-pg:
	-sudo -u postgres psql -c "drop database cigritest"
	-sudo -u postgres psql -c "drop role cigritest"

test-clean-mysql:
	-mysql -u root -p -e "drop database cigritest; drop user cigritest@localhost"


install: install-cigri-libs install-cigri-user-cmds install-sudoers

install-sudoers:
	install -d -m 0755 $(DESTDIR)/etc/sudoers.d
	install -m 0440 etc/sudoers.d/cigri $(DESTDIR)/etc/sudoers.d/cigri
	perl -i -pe "s#/usr/local/share/cigri#$(CIGRIDIR)#g" $(DESTDIR)/etc/sudoers.d/cigri
		
install-cigri-libs:
	install -d -m 0755 $(DESTDIR)/$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)/$(CIGRIDIR)/lib
	@for file in lib/*; do install -m 0644 $$file $(DESTDIR)/$(CIGRIDIR)/lib/; done

install-cigri-user-cmds:
	install -d -m 0755 $(DESTDIR)/$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)/$(CIGRIDIR)/bin
	install -m 0755 bin/gridsub.rb $(DESTDIR)/$(CIGRIDIR)/bin/gridsub
	install -m 0755 tools/sudowrapper.sh $(DESTDIR)/$(BINDIR)/gridsub
	perl -i -pe "s#CIGRIDIR=.*#CIGRIDIR='$(CIGRIDIR)'\;#;;\
                             s#CIGRIUSER=.*#CIGRIUSER='$(CIGRIUSER)'\;#;;\
                             s#CMD=.*#CMD='gridsub'\;#;;\
                                " $(DESTDIR)$(BINDIR)/gridsub

clean:
	rm -rf doc/rdoc doc/yard doc/rcov .yardoc
	@cd lib; for file in *; do rm -f $(DESTDIR)/$(CIGRIDIR)/lib/$$file; done
	rm -f $(DESTDIR)/etc/sudoers.d/cigri
	rm -f $(DESTDIR)/$(CIGRIDIR)/bin/gridsub
	rm -f $(DESTDIR)$(BINDIR)/gridsub
