OCAMLOPT=ocamlopt
EXEC=sched_equitCigri
OCAMLDEP=ocamldep
OCAMLPREP=-pp camlp4o
OCAMLFLAGS=-I /usr/lib/ocaml/3.07/cameleon


LIBS=options.cmx
LOCALLIBS=mysql.cmxa
OBJS=sched_equit.cmx
ALLOBJS=$(LIBS) $(LOCALLIBS) $(OBJS)

PREPROCESSEDOBJS=mysql.cmx sched_equit.cmx
CC=gcc-2.95
CFLAGS=-g -O2 -I/usr/lib/ocaml/3.06

all: $(LOCALLIBS) $(OBJS)
	$(OCAMLOPT) -o $(EXEC)  $(OCAMLFLAGS)  $(ALLOBJS)

sched_equit.cmx: mysql.cmxa mysql.cmi
mysql.cmx: mysql.cmi

%.cmx: %.ml
	$(OCAMLOPT) $(OCAMLFLAGS) -c $<

$(PREPROCESSEDOBJS): %.cmx : %.ml
	$(OCAMLOPT) $(OCAMLFLAGS) $(OCAMLPREP) -c $<

%.d : %.ml
	@set -e; $(OCAMLDEP) $< > $@; \
		[ -s $@ ] || rm -f $@

-include $(OBJS:.cmx=.d)

%.cmi: %.mli
	$(OCAMLOPT) $(OCAMLFLAGS) -c $<

mysql.cmxa: mysql_stubs.o mysql.cmx
	$(OCAMLOPT) -a -o $@  -cclib -lmysqlclient mysql_stubs.o mysql.cmx

clean: 
	rm -f *.o *.cmo *.cmx *.cmi *.so *.cma *.cmxa *.a $(EXEC)
