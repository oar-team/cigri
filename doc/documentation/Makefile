#!/usr/bin/make 

# Under Debian or Ubuntu you must install the packages
# "python-docutils tetex-latex-recommended texlive-fonts-recommended make"

all: doc-admin doc-user doc-devel

doc-admin: doc_admin.html

doc-user: doc_user.html

doc-devel: doc_devel.html

pdf: doc_admin.pdf doc_user.pdf doc_devel.pdf

doc_devel.html: doc_lib.rst doc_modules.rst doc_database.rst ../../CHANGELOG

doc_user.html: doc_jdl.rst ../../CHANGELOG example.json

doc_admin.html: 

%.html: %.rst doc_header.rst
	rst2html -stg $< $@

%.tex: %.rst doc_header.rst
	rst2latex $< $@

%.pdf: %.tex doc_header.rst
	pdflatex $< $@
	pdflatex $< $@

clean:
	for i in doc_admin doc_devel doc_user; do rm -f $$i.pdf $$i.html $$i.tex $$i.aux $$i.log $$i.out $$i.toc; done
