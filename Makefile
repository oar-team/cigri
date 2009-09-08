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
CONFDIR=/etc
WWWDIR=/var/www
WWWUSER=www-data
WWWGROUP=www-data
CIGRIOWNER=cigri
CIGRIGROUP=cigri

.PHONY: man

all: usage
install: usage
usage:
	@echo "Usage: make <server-install | user-install | www-install | rc-install>"

sanity-check:
	@[ "`id root`" = "`id`" ] || echo "Warning: root-privileges are required to install some files !"
	@id $(CIGRIOWNER) > /dev/null || ( echo "Error: User $(CIGRIOWNER) does not exist!" ; exit -1 )

configuration:
	install -d -m 0755 $(DESTDIR)$(CONFDIR)
	@if [ -f $(DESTDIR)$(CONFDIR)/cigri.conf ]; then echo "Warning: $(DESTDIR)$(CONFDIR)/cigri.conf already exists, not overwriting it." ; else install -m 0600 Tools/cigri.conf $(DESTDIR)$(CONFDIR) ; chown $(CIGRIOWNER).root $(DESTDIR)$(CONFDIR)/cigri.conf || /bin/true ; fi

sprc:
	@if [ -d $(DESTDIR)/etc/supercat -a \! -f $(DESTDIR)/etc/supercat/spcrc-cigri ] ; then install Tools/spcrc-cigri $(DESTDIR)/etc/supercat ; fi

rc-install:
	@if [ -f /etc/debian_version ]; then install -m 6755 Tools/init_scripts/debian/cigri $(DESTDIR)/etc/init.d/cigri; update-rc.d cigri defaults 90 10; fi
	@if [ -f /etc/redhat-release ]; then install -m 6755 Tools/init_scripts/centos/cigri $(DESTDIR)/etc/init.d/cigri; chkconfig --on cigri; fi
	perl -pi -e "s,> cigri.log,> $(VARDIR)/cigri.log," $(DESTDIR)/etc/init.d/cigri
	perl -pi -e "s,> cigri_collector.log,> $(VARDIR)/cigri_collector.log," $(DESTDIR)/etc/init.d/cigri

doc-install:
	install -d -m 755 $(DESTDIR)$(DOCDIR)
	install Doc/INSTALL $(DESTDIR)$(DOCDIR)
	install AUTHORS $(DESTDIR)$(DOCDIR)
	install COPYING $(DESTDIR)$(DOCDIR)
	cp -r Doc/scheduler $(DESTDIR)$(DOCDIR)
	cp -r Tools/sample_jobs $(DESTDIR)$(DOCDIR)

server-install: sanity-check doc-install sprc configuration rc-install
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	cp -r Almighty ClusterQuery Collector Colombo ConfLib DB Hermes Iolib JDLLib Ldap Mailer Net Nikita Phoenix Runner Scheduler Spritz Updator $(DESTDIR)$(CIGRIDIR)

user-install: sanity-check doc-install configuration
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(BINDIR)
	cp -r ConfLib Iolib $(DESTDIR)$(CIGRIDIR)
	install -d -m 0755 $(DESTDIR)$(CIGRIDIR)/Qfunctions
	install -m 6755 Qfunctions/gridsub.pl $(DESTDIR)$(CIGRIDIR)/Qfunctions
	-chown $(CIGRIOWNER):$(CIGRIGROUP) $(DESTDIR)$(CIGRIDIR)/Qfunctions/gridsub.pl
	-chmod 6755 $(DESTDIR)$(CIGRIDIR)/Qfunctions/gridsub.pl
	echo "#!/bin/sh" > $(DESTDIR)$(BINDIR)/gridsub
	echo '$(CIGRIDIR)/Qfunctions/gridsub.pl $$@' >> $(DESTDIR)$(BINDIR)/gridsub
	chmod 755 $(DESTDIR)$(BINDIR)/gridsub
	install -m 6755 Qfunctions/griddel.pl $(DESTDIR)$(CIGRIDIR)/Qfunctions
	-chown $(CIGRIOWNER):$(CIGRIGROUP) $(DESTDIR)$(CIGRIDIR)/Qfunctions/griddel.pl
	-chmod 6755 $(DESTDIR)$(CIGRIDIR)/Qfunctions/griddel.pl
	echo "#!/bin/sh" > $(DESTDIR)$(BINDIR)/griddel
	echo '$(CIGRIDIR)/Qfunctions/griddel.pl $$@' >> $(DESTDIR)$(BINDIR)/griddel
	chmod 755 $(DESTDIR)$(BINDIR)/griddel
	install -m 6755 Qfunctions/gridstat.rb $(DESTDIR)$(CIGRIDIR)/Qfunctions
	-chmod 6755 $(DESTDIR)$(CIGRIDIR)/Qfunctions/gridstat.rb
	echo "#!/bin/sh" > $(DESTDIR)$(BINDIR)/gridstat
	echo "export CIGRICONFDIR=$(CONFDIR)" >> $(DESTDIR)$(BINDIR)/gridstat
	echo "export CIGRIDIR=$(CIGRIDIR)" >> $(DESTDIR)$(BINDIR)/gridstat
	echo '$(CIGRIDIR)/Qfunctions/gridstat.rb $$@' >> $(DESTDIR)$(BINDIR)/gridstat
	chmod 755 $(DESTDIR)$(BINDIR)/gridstat

www-install: sanity-check
	install -d $(DESTDIR)$(WWWDIR)/cigri
	@if [ -f $(DESTDIR)$(WWWDIR)/cigri/config.inc ]; then mv $(DESTDIR)$(WWWDIR)/cigri/config.inc $(DESTDIR)$(WWWDIR)/cigri/config.inc.orig ; fi
	cp -r www2/* $(DESTDIR)$(WWWDIR)/cigri
	@if [ -f $(DESTDIR)$(WWWDIR)/cigri/config.inc.orig ]; then mv -f $(DESTDIR)$(WWWDIR)/cigri/config.inc.orig $(DESTDIR)$(WWWDIR)/cigri/config.inc; fi
	-chown root:$(WWWGROUP) $(DESTDIR)$(WWWDIR)/cigri/config.inc
	chmod 640 $(DESTDIR)$(WWWDIR)/cigri/config.inc
	install -m 750 -d $(DESTDIR)$(WWWDIR)/cigri/templates_c
	-chown $(WWWUSER):$(CIGRIGROUP) $(DESTDIR)$(WWWDIR)/cigri/templates_c
