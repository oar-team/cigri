{include file="header.tpl"}
<!--    <h4> Goals </h4>
    </br>
    <h4> How it works </h4>
    </br>
    <h4> Contacts </h4>
    </br>
    <h4> Where are the clusters of the grid </h4>
-->
{literal}
<br>
<p align="center"><font size="6"><b>Utilisation
de la grille ci-gri</b></font></p>
<br>
<br>
<ul>
  <p><b><font size="4">Etape 1 :</font></b></p>
</ul>
<p>Pour utiliser la grille de calcul cigri,
Il faut cr&eacute;er un compte sur le serveur cigri central (pawnee) et
sur chaque cluster que vous voulez utiliser (sauf sur ceux sur lesquels
vous en poss&eacute;dez d&eacute;j&agrave; un).<br>
Pour cela, contactez les administrateurs syst&egrave;mes des clusters
ainsi que le responsable grille.<br>
<br>
<b>Responsable grille : </b>Nicolas Capit, Laboratoire TIMC-IMAG, tel
: 04 76 61 20 31, <a href="mailto:nicolas.capit@imag.fr">nicolas.capit@imag.fr</a><br>
<br>
Les clusters disponibles en mode grille sont : (derni&egrave;re mise
&agrave; jour)<br>
</p>
<ul>
  <li><b>Bioimage : </b><a href="http://bioimage.ujf-grenoble.fr/">http://bioimage.ujf-grenoble.fr
    </a>
  </li>
</ul>
<ul>
  <li><b>Tomte : </b><a href="http://www-chimie.ujf-grenoble.fr/">http://www-chimie.ujf-grenoble.fr/
    </a><br>
administrateur : Sebastien Morin <a
 href="mailto:%20sebastien.morin@ujf-grenoble.fr">
sebastien.morin@ujf-grenoble.fr</a>
  </li>
</ul>
<p>
</p>
<ul>
  <p><b><font size="4">Etape 2 :</font></b></p>
</ul>
Apr&egrave;s avoir cr&eacute;&eacute;s vos comptes, vous devez valider
votre application :<br>
transferez votre application sur les clusters concern&eacute;s,
compilez et executez-la (avec plusieurs param&egrave;tres si vous en
avez).<br>
<br>
<ul>
  <p><b><font size="4">Etape 3 :</font></b></p>
</ul>
Une fois assur&eacute; de la validit&eacute;e de votre programme, vous
pouvez cr&eacute;er le JDL (Job Description Language) qui va indiquer
&agrave; la grille comment soumettre votre job.<br>
<p></p>
<p><font size="4">exemple de JDL :</font></p>
<ul>
  <a>
  <i>DEFAULT{<br>
# nbjobs = 6;<br>
paramFile = param.tmp;<br>
}<br>
pawnee{<br>
execFile = $(PATH_PROG_PAWNEE)/test.sh;<br>
}<br>
tomte.ujf-grenoble.fr{<br>
execFile = $(PATH_PROG_TOMTE)/test.sh;<br>
}<br>
  </i>
  </a>
</ul>
<p>Remarques sur les possibilit&eacute;es du JDL :</p>
<ul>
  <p>
  <font size="2">dans DEFAULT :<br>
  <ul>
. soit vous executez votre application X fois en utilisant le mot
cl&eacute; "nbjobs"<br>
  </ul>
  <ul>
. soit vous sp&eacute;cifiez un fichier de param&egrave;tres, chaque
lignes de ce fichiers sera un argument de votre programme .<br>
    <br>
  </ul>
  </font></p>
</ul>
<div style="text-align: left;">A noter que le premier param&egrave;tre
de votre application sera pris en compte comme &eacute;tant le nom de
votre job. Ainsi, lors de la collecte des r&eacute;sultats, les
fichiers contenant la sortie standard et la sortie d'erreur seront
copi&eacute;s vers le serveur CIGRI ET &eacute;galement le fichier (ou
dossier) nomm&eacute; comme le premier param&egrave;tre.<br>
<br>
</div>
<ul>
  <p><b><font size="4">Etape 4 :</font></b></p>
</ul>
<p>Il faut soumettre votre job &agrave; la grille de calcul sur le
serveur cigri central (pawnee): <br>
<i><font size="4">% gridsub -f nom_JDL</font></i> <br>
<br>
Un site web est en cours de developpement pour suivre
l'&eacute;tat des jobs.
</p>
<ul>
  <p><b><font size="4">Etape 5 :</font></b></p>
</ul>
<p>
Les fichiers r&eacute;sultats du job sont cr&eacute;es sur chaque
cluster &agrave; partir de la sortie standard/erreur de votre
application.<br>
Pour recup&eacute;rer vos r&eacute;sultats, tapez la commande :<br>
<i><font size="4">% collectorCigri.pl MJobId </font></i><font size="2">
# MJobId est le num&eacute;ro de job attribu&eacute; lors de la
commande gridsub.pl</font><br>
Cette commande rapatrie les r&eacute;sultats sur le seveur cigri
central dans le r&eacute;pertoire
~cigri/results/username/MJobId/*.tar.gz<br>
</p>
<br>
<br>
<hr>
<p align="center"><font size="4">exemple de
calcul de Pi par la m&eacute;thode Monte-Carlo et utilisation sur la
grille : </font>
</p>
<p align="center"><br>
</p>
<ul>
  <li>
    <p><span style="font-style: normal;"><font size="3">cr&eacute;ez un
compte sur le serveur cigri central (voir avec nicolas capit) et sur
chaque cluster que vous voulez utiliser </font></span></p>
  </li>
</ul>
<ul>
  <li>
    <p><font size="3">R&eacute;cuperez le fichier : <a href="index/pi.tar"><font
 size="3">pi.tar</font></a></font><br>
Ce fichier contient 3 programmes diff&eacute;rents: pi_simple, pi250 et
pi250_arg.<br>
Ces 3 programmes evaluent pi par la m&eacute;thode de Monte-Carlo, voir
le fichier LISEZMOI de pi.tar pour plus de renseignements.</p>
  </li>
</ul>
<ul>
  <p></p>
  <li>
    <p><font size="3"> compilez et executez pi_simple, pi250 et
pi250_arg sur les clusters concern&eacute;s.</font></p>
  </li>
</ul>
<ul>
  <li>
    <p><font size="3"> Sur le serveur cigri central :<br>
cr&eacute;ez un fichier <a href="index/pi_JDL">pi_JDL</a> (execute le meme
job 1000 fois sur les clusters tomte et bioimage)<br>
ou <br>
cr&eacute;er un fichier <a href="index/pi_arg_JDL">pi_arg_JDL</a> (execute 1
job avec 1000 param&egrave;tres sur les clusters tomte et bioimage) </font></p>
  </li>
</ul>
<ul>
  <li>
    <p><font size="3">soumettez votre job par la commande :</font></p>
    <p><font size="3"><i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; % grisub -f
nom_JDL </i></font>&nbsp;&nbsp;<font size="2">(pi_JDL ou pi_arg_JDL)</font>
    </p>
    <p align="left"><font size="3"> un num&eacute;ro de job est
attribu&eacute;.</font></p>
    <p><font size="3">votre job est lanc&eacute;, il ne reste qu'a
attendre. Un site web va etre disponible prochainement pour suivre
l'&eacute;volution de ses jobs.</font></p>
    <p></p>
  </li>
</ul>
<ul>
  <li>
    <p><font size="3">Pour recup&eacute;rer vos fichiers
r&eacute;sultats , tapez</font></p>
    <p><font size="3"><i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; %
collectorCigri.pl</i></font></p>
    <p align="left"><font size="3">vos fichiers sont transfer&eacute;s
sur le serveur cigri central en tar.gz dans
~cigri/results/username/MJobId/*.tar.gz .</font></p>
    <p align="left"></p>
  </li>
</ul>
<ul>
  <li>
    <p align="left"><font size="3">chaque fichier tar.gz comprend 1
fichier de sortie (c'est le resultat de la sortie standard de votre
job) et 1 fichier d'erreur (vide si votre job a reussit)</font></p>
    <p align="left"></p>
  </li>
</ul>
<ul>
  <li>Vous pouvez ainsi avoir une estimation de pi par la
m&eacute;thode de Monte-Carlo apr&egrave;s 1000 executions en executant
le script : <a href="index/script.sh" target="_blank">script.sh </a> (clic
droit puis telecharger sous) par<br>
    <i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; % source script.sh</i><br>
Ce script ajoute chaque ligne des fichiers resultats et divise le total
par le nombre de lignes, on obtient donc un moyennage de pi.
  </li>
</ul>
<p><br>
</p>
<p><br>
<br>
</p>
<hr>
<p align="center"><font size="5">Liens :</font></p>
<table width="100%" border="1" cellpadding="4" cellspacing="0">
  <col width="96*"> <col width="160*"> <tbody>
    <tr valign="top">
      <td width="37%" bgcolor="#e6e6e6">
      <p><font size="3">Site g&eacute;n&eacute;ral sur les grilles</font></p>
      </td>
      <td width="63%" bgcolor="#e6e6e6">
      <p><a href="http://www.globus.org/" target="_blank"><u>http://www.globus.org/</u></a></p>
      </td>
    </tr>
    <tr valign="top">
      <td width="37%" bgcolor="#e6e6e6">
      <p><font size="3">Site DataGrid</font></p>
      </td>
      <td width="63%" bgcolor="#e6e6e6">
      <p><a href="http://eu-datagrid.web.cern.ch/eu-datagrid"
 target="_blank"><u>http://eu-datagrid.web.cern.ch/eu-datagrid</u></a></p>
      </td>
    </tr>
    <tr valign="top">
      <td width="37%" bgcolor="#e6e6e6">
      <p><font size="3">site methode monte-carlo et quasi monte carlo
(eng)</font></p>
      </td>
      <td width="63%" bgcolor="#e6e6e6">
      <p><a href="http://www.mcqmc.org/">http://www.mcqmc.org</a></p>
      </td>
    </tr>
    <tr valign="top">
      <td width="37%" bgcolor="#e6e6e6">
      <p><font size="3">m&eacute;thode monte carlo et quasi monte carlo
et applications (fr)</font></p>
      </td>
      <td width="63%" bgcolor="#e6e6e6">
      <p><a href="http://www.irisa.fr/armor/lesmembres/Tuffin/MC.html"
 target="_blank">http://www.irisa.fr/armor/lesmembres/Tuffin/MC.html</a></p>
      <p><a href="http://www.irisa.fr/armor/lesmembres/Tuffin/QMC.html"
 target="_blank">http://www.irisa.fr/armor/lesmembres/Tuffin/QMC.html</a></p>
      </td>
    </tr>
    <tr valign="top">
      <td width="37%" bgcolor="#e6e6e6">
      <p><font size="3">introduction aux m&eacute;thodes monte-carlo
(fr)</font></p>
      </td>
      <td width="63%" bgcolor="#e6e6e6">
      <p><a
 href="http://cermics.enpc.fr/%7Ebl/PS/SIMULATION-X/poly-monte-carlo-x.pdf">http://cermics.enpc.fr/~bl/PS/SIMULATION-X/poly-monte-carlo-x.pdf</a></p>
      </td>
    </tr>
    <tr valign="top">
      <td width="37%" bgcolor="#e6e6e6">
      <p><font size="3">Aide &agrave; la programmation monte-carlo</font></p>
      </td>
      <td width="63%" bgcolor="#e6e6e6">
      <p><a
 href="http://www.sciences-en-ligne.com/momo/chronomath/java_elem/pi_alea.html"
 target="_blank">http://www.sciences-en-ligne.com/momo/chronomath/java_elem/pi_alea.html</a></p>
      <p><a
 href="http://www.tls.cena.fr/divisions/MSS/SUPPORT/MCARLO/MC_frame.shtml#pi"
 target="_blank">http://www.tls.cena.fr/divisions/MSS/SUPPORT/MCARLO/MC_frame.shtml#pi</a></p>
      </td>
    </tr>
  </tbody>
</table>
<p><br>
<br>
</p>
{/literal}
{include file="../../foot.tpl"}
