###############################################################################
##  *** ConfLib: ***
##
## - Description:
## Module maison de gestion du fichier de conf de CIGRI
##
## - Fonctionnement:
## Le fichier de conf est le premier fichier lisible issu des 3 possibilites
## suivantes:
##  > fichier passe en param de la fonction init_conf()
##  > $CIGRIDIR/cigri.conf
##  > /etc/cigri.conf
##
## Une ligne du fichier de conf est de la forme:
##  > truc = 45 machin chose bidule 23 # un commentaire
##
## Vous pouvez commencer des lignes de commentaires par "#", elles seront
## ignorees de meme d'ailleurs que toutes les lignes non conformes a
## l'expression reguliere definissant une ligne valide...:)
##
## Apres initialisation du modules a l'aide de la fonction init_conf(),
## la recuperation d'un parametre se fait avec la fonction get_conf("truc").
## La fonction is_conf qd a elle permet de savoir si un parametre est defini.
##
## - Exemple d'utilisation:
##  > use ConfLib qw(init_conf get_conf is_conf);
##  > init_conf();
##  > print "toto = ".get_conf("toto")."\n" if is_conf("toto");
##
###############################################################################
package ConfLibCigri;

use strict;
use warnings;
require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(init_conf get_conf is_conf dump_conf reset_conf);

## le fichier de conf.
my $file = undef;
## container pour les parametres...
my %params;
## regex pour une ligne valide du fichier de conf.
my $regex = qr{^\s*([^#=\s]+)\s*=\s*"([^#]*)"};

## Initialisation de la configuration
## arg1 = fichier de conf ou rien
## si rien -> essaie $CIGRIDIR/cigri.conf puis /etc/cigri.conf
## Attention $CIGRIDIR est une variable de SHELL non de Perl
## Result: 1 if conf file actually loaded, else 0.
sub init_conf {
  unless (defined $file) {
    $file = shift;
    unless ( defined $file and -r $file ) {
      if ( defined $ENV{CIGRIDIR} and -r $ENV{CIGRIDIR}."/cigri.conf" ){
	$file = $ENV{CIGRIDIR}."/cigri.conf";
      } elsif ( -r "/etc/cigri.conf" ) {
	$file = "/etc/cigri.conf";
      } else {
	die "cigri.conf file not found";
      }
    }
    open CIGRICONF, $file;
    %params = ();
    foreach my $line (<CIGRICONF>) {
      if ($line =~ $regex) {
	my ($key,$val) = ($1,$2);
	$val =~ s/\s*$//;
	$params{$key}=$val;
      }
    }
    close CIGRICONF;
    return 1;
  }
  return 0;
}

## recupere un parametre
sub get_conf ( $ ) {
  my $key = shift;
  (defined $key) or die "Gimme a key please !";
  return $params{$key};
}

## teste si un parametre est defini
sub is_conf ( $ ) {
  my $key = shift;
  (defined $key) or die "Gimme a key please !";
  return exists $params{$key};
}

## debug: dump les parametres
sub dump_conf () {
  print "Config file is: ".$file."\n";
  while (my ($key,$val) = each %params) {
    print " ".$key." = ".$val."\n";
  }
  return 1;
}

## reset the module state
sub reset_conf () {
  $file = undef;
  %params = ();
  return 1;
}

return 1;
