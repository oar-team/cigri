OCAMLOPT=ocamlopt
EXEC=sched_equitCigri
OCAMLDEP=ocamldep
OCAMLPREP=-pp camlp4o

ALLOBJS=mysql.cmxa sched_equit.cmx
PREPROCESSEDOBJS=mysql.cmx
CC=gcc-2.95
CFLAGS=-g -O2 -I/usr/lib/ocaml/3.06 

all: $(ALLOBJS)
	$(OCAMLOPT) -o $(EXEC) unix.cmxa $(OCAMLFLAGS) $(ALLOBJS)

sched_equit.cmx: mysql.cmxa mysql.cmi
mysql.cmx: mysql.cmi

%.cmx: %.ml
	$(OCAMLOPT) $(OCAMLFLAGS) -c $<
$(PREPROCESSEDOBJS): %.cmx : %.ml
	$(OCAMLOPT) $(OCAMLOPTFLAGS) $(OCAMLPREP) -c $<
%.d : %.ml
	@set -e; $(OCAMLDEP) $< > $@; \
		[ -s $@ ] || rm -f $@
%.cmi: %.mli
	$(OCAMLOPT) $(OCAMLFLAGS) -c $<

mysql.cmxa: mysql_stubs.o mysql.cmx
	$(OCAMLOPT) -a -o $@  -cclib -lmysqlclient mysql_stubs.o mysql.cmx

clean: 
	rm -f *.o *.cmo *.cmx *.cmi *.so *.cma *.cmxa *.a $(EXEC)
