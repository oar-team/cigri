#!/usr/bin/make 

# Under Debian or Ubuntu you must install the packages
# "python-docutils tetex-latex-recommended texlive-fonts-recommended make"

all: doc-admin doc-user doc-devel

doc-admin: doc_admin.html

doc-user: doc_user.html

doc-devel: doc_devel.html

pdf: doc_admin.pdf doc_user.pdf

%.html: %.rst
	rst2html -stg $< $@

%.tex: %.rst
	rst2latex $< $@

%.pdf: %.tex
	pdflatex $< $@
	pdflatex $< $@

clean:
	for i in doc_admin doc_devel doc_user; do rm -f $$i.pdf $$i.html $$i.tex $$i.aux $$i.log $$i.out $$i.toc; done
