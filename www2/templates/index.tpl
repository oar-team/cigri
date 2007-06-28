{literal}
<table border="0" cellpadding="10" cellspacing="0">
    <tr>
      <td>
      <h1><a name="usage">Utilisation de la grille ci-gri</a></h1>
      <ul>
        <li>
          <h4><a name="step1">Etape 1 :</a></h4>
        </li>
      </ul>
      <p>Pour utiliser la grille de calcul cigri, Il faut cr&eacute;er
un compte sur le serveur cigri central et sur chaque cluster
que vous voulez utiliser (sauf sur ceux sur lesquels vous en
poss&eacute;dez d&eacute;j&agrave; un).<br>
Pour cela, contactez les administrateurs syst&egrave;mes des clusters
ainsi que le responsable grille.<br>
      <br>
      <p> <a href="#top">Haut de page</a> </p>
      <ul>
        <li>
          <h4><a name="step2">Etape 2 :</a></h4>
        </li>
      </ul>
      <p> Apr&egrave;s avoir cr&eacute;&eacute; vos comptes, vous devez
valider votre application :</p>
      <ul>
        <li> Transf&eacute;rez votre application sur les clusters
concern&eacute;s </li>
        <li> Compilez et ex&eacute;cutez-la (avec plusieurs
param&egrave;tres si vous en avez) </li>
      </ul>
      <p> <a href="#top">Haut de page</a> </p>
      <ul>
        <li>
          <h4><a name="step3">Etape 3 :</a></h4>
        </li>
      </ul>
      <p>Une fois assur&eacute; de la validit&eacute; de votre
programme, vous pouvez cr&eacute;er le JDL (Job Description Language)
qui va indiquer &agrave; la grille comment soumettre votre job.</p>
      <h5>exemple de JDL :</h5>
      <table border="0" cellpadding="0" cellspacing="0" width="100%">
        <colgroup><col width="5%"><col width="95%"></colgroup> <tbody>
          <tr>
            <td><br>
            </td>
            <td style="" class="smallclass"> <i>DEFAULT{<br>
&nbsp;&nbsp;&nbsp; name = testCampagne1<br>
&nbsp;&nbsp;&nbsp; # nbjobs = 6;<br>
&nbsp;&nbsp;&nbsp; paramFile = param.tmp;<br>
}<br>
icluster2.imag.fr{<br>
&nbsp;&nbsp;&nbsp; execFile = /home/user/test.sh ;<br>
&nbsp;&nbsp;&nbsp; walltime = 02:30:00 ;<br>
&nbsp;&nbsp;&nbsp; weight = 1;<br>
&nbsp;&nbsp;&nbsp; execDir = /home/user/testGrilleDir ;<br>
}<br>
tomte.ujf-grenoble.fr{<br>
&nbsp;&nbsp;&nbsp; execFile = /home/nis/user/test.sh;<br>
            </i><i>&nbsp;&nbsp;&nbsp; walltime = 03:00:00 ;<br>
&nbsp;&nbsp;&nbsp; weight = 2;<br>
&nbsp;&nbsp;&nbsp; execDir = /tmp ;</i><br>
            <i> }<br>
            </i> </td>
          </tr>
        </tbody>
      </table>
      <p>Remarques sur les possibilit&eacute;s du JDL :</p>
      <table border="0" cellpadding="0" cellspacing="0" width="100%">
        <colgroup><col width="5%"><col width="5%"><col width="90%"></colgroup>
        <tbody>
          <tr>
            <td><br>
            </td>
            <td colspan="2"> dans DEFAULT </td>
          </tr>
          <tr>
            <td><br>
            </td>
            <td><br>
            </td>
            <td class="smallclass"> . soit vous ex&eacute;cutez votre
application <i>n</i> fois en utilisant le mot cl&eacute; "nbjobs"<br>
. soit vous sp&eacute;cifiez un fichier de param&egrave;tres, chaque
ligne de ce fichier sera un argument de votre programme (donc une
t&acirc;che). </td>
          </tr>
        </tbody>
      </table>
      <p>A noter que le premier param&egrave;tre de votre application
sera pris en compte comme &eacute;tant le nom de votre job. Ainsi, lors
de la collecte des r&eacute;sultats, les fichiers contenant la sortie
standard et la sortie d'erreur seront copi&eacute;s vers le serveur
CIGRI ET &eacute;galement le fichier (ou dossier) nomm&eacute; comme le
premier param&egrave;tre. </p>
      <p> <a href="#top">Haut de page</a> </p>
      <ul>
        <li>
          <h4><a name="step4">Etape 4 :</a></h4>
        </li>
      </ul>
      <p>Il faut soumettre votre job &agrave; la grille de calcul sur
le serveur cigri central (pawnee): </p>
      <p>&nbsp;&nbsp;&nbsp; <i># gridsub -f nom_JDL</i></p>
      <p>Le site web, sur lequel vous &ecirc;tes, vous permet
d'observer l'&eacute;volution de vos campagnes, de g&eacute;rer les
erreurs qui peuvent survenir et d'avoir des graphiques de statistiques.</p>
      <p> <a href="#top">Haut de page</a> </p>
      <ul>
        <li>
          <h4><a name="step5">Etape 5 :</a></h4>
        </li>
      </ul>
      <>Les fichiers r&eacute;sultats du job sont cr&eacute;&eacute;s
sur chaque cluster &agrave; partir de la sortie standard/erreur de
votre application.<br>
Ils sont rappatri&eacute;s sur le serveur, environ, toutes les 30<i>min
      </i>et les archives sont plac&eacute;es dans ~cigri/results/"nom
de l'utilisateur"/"num&eacute;ro de campagne"/<i>.</i><br>
      </>
      <p> <a href="#top">Haut de page</a> </p>
      <br>
      <br>
      <hr>
      <h4><a name="example">Exemple de calcul de Pi par la
m&eacute;thode Monte-Carlo et utilisation sur la grille : </a></h4>
      <table border="0" cellpadding="0" cellspacing="10">
        <colgroup><col width="5%"><col width="2%"><col width="93%"></colgroup>
        <tbody>
          <tr>
            <td><br>
            </td>
            <td valign="top">&nbsp;-&nbsp;</td>
            <td valign="top"> Cr&eacute;ez un compte sur le serveur
cigri central (voir avec nicolas capit) et sur chaque cluster que vous
voulez utiliser </td>
          </tr>
          <tr>
            <td><br>
            </td>
            <td valign="top">&nbsp;-&nbsp;</td>
            <td valign="top"> R&eacute;cuperez le fichier : <a
 href="pi.tar">pi.tar</a><br>
            <table border="0" cellpadding="5" cellspacing="0">
              <tbody>
                <tr>
                  <td class="smallclass">Ce fichier contient 3
programmes diff&eacute;rents: pi_simple, pi250 et pi250_arg.<br>
Ces 3 programmes &eacute;valuent pi par la m&eacute;thode de
Monte-Carlo, voir le fichier LISEZMOI de pi.tar pour plus de
renseignements. </td>
                </tr>
              </tbody>
            </table>
            </td>
          </tr>
          <tr>
            <td><br>
            </td>
            <td valign="top">&nbsp;-&nbsp;</td>
            <td valign="top"> Compilez et ex&eacute;cutez pi_simple,
pi250 et pi250_arg sur les clusters concern&eacute;s. </td>
          </tr>
          <tr>
            <td><br>
            </td>
            <td valign="top">&nbsp;-&nbsp;</td>
            <td valign="top"> Sur le serveur cigri central :<br>
cr&eacute;ez un fichier <a href="pi_JDL">pi_JDL</a> <span
 class="smallclass">(ex&eacute;cute le m&ecirc;me job 1000 fois sur les
clusters tomte et bioimage)</span><br>
ou cr&eacute;ez un fichier <a href="pi_arg_JDL">pi_arg_JDL</a><span
 class="smallclass"> (ex&eacute;cute un job avec 1000 param&egrave;tres
sur les clusters tomte et bioimage)</span> </td>
          </tr>
          <tr>
            <td><br>
            </td>
            <td valign="top">&nbsp;-&nbsp;</td>
            <td valign="top"> Soumettez votre job par la commande :<br>
            <i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; % grisub -f nom_JDL </i>&nbsp;&nbsp;(pi_JDL
ou pi_arg_JDL)<br>
            <table border="0" cellpadding="5" cellspacing="0">
              <tbody>
                <tr>
                  <td class="smallclass">Un num&eacute;ro de job est
attribu&eacute;.<br>
Votre job est lanc&eacute;, il ne reste qu'&agrave; attendre et suivre
l'&eacute;volution sur le portail web. </td>
                </tr>
              </tbody>
            </table>
            </td>
          </tr>
          <tr>
            <td><br>
            </td>
            <td valign="top">&nbsp;-&nbsp;</td>
            <td valign="top"> <i></i>Vos fichiers sont
transf&eacute;r&eacute;s sur le serveur cigri central en tar.gz dans
~cigri/results/username/MJobId/*.tar.gz</td>
          </tr>
          <tr>
            <td><br>
            </td>
            <td valign="top">&nbsp;-&nbsp;</td>
            <td valign="top"> Chaque fichier tar.gz comprend un fichier
de sortie <span class="smallclass">(c'est le r&eacute;sultat de la
sortie standard de votre job)</span> et un fichier d'erreur <span
 class="smallclass">(vide si votre job a r&eacute;ussi)</span> </td>
          </tr>
          <tr>
            <td><br>
            </td>
            <td valign="top">&nbsp;-&nbsp;</td>
            <td valign="top"> Vous pouvez ainsi avoir une estimation de
pi par la m&eacute;thode de Monte-Carlo apr&egrave;s 1000
ex&eacute;cutions en ex&eacute;cutant le script : <a href="script.sh">script.sh
            </a> <span class="smallclass">(clic droit puis
t&eacute;l&eacute;charger sous)</span> par<br>
            <i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; % source script.sh</i><br>
            <table border="0" cellpadding="5" cellspacing="0">
              <tbody>
                <tr>
                  <td class="smallclass"> Ce script ajoute chaque ligne
des fichiers r&eacute;sultats et divise le total par le nombre de
lignes, on obtient donc un moyennage de pi. </td>
                </tr>
              </tbody>
            </table>
            </td>
          </tr>
        </tbody>
      </table>
      <p> <a href="#top">Haut de page</a> </p>
      <br>
      <hr>
      <h4><a name="links">Liens :</a></h4>
      <table style="background-color: rgb(230, 230, 230);" border="1"
 cellpadding="4" cellspacing="0" width="100%">
        <colgroup><col width="20%"><col width="80%"></colgroup> <tbody>
          <tr valign="top">
            <td> Site g&eacute;n&eacute;ral sur les grilles </td>
            <td> <a href="http://www.globus.org/">http://www.globus.org/</a>
            </td>
          </tr>
          <tr valign="top">
            <td> Site DataGrid </td>
            <td> <a href="http://eu-datagrid.web.cern.ch/eu-datagrid">http://eu-datagrid.web.cern.ch/eu-datagrid</a>
            </td>
          </tr>
          <tr valign="top">
            <td> Site m&eacute;thode Monte-Carlo et quasi Monte-Carlo
(eng) </td>
            <td> <a href="http://www.mcqmc.org/">http://www.mcqmc.org</a>
            </td>
          </tr>
          <tr valign="top">
            <td> M&eacute;thode Monte-Carlo et quasi Monte-Carlo et
applications (fr) </td>
            <td> <a
 href="http://www.irisa.fr/armor/lesmembres/Tuffin/MC.html">http://www.irisa.fr/armor/lesmembres/Tuffin/MC.html</a>
            <br>
            <br>
            <a
 href="http://www.irisa.fr/armor/lesmembres/Tuffin/QMC.html">http://www.irisa.fr/armor/lesmembres/Tuffin/QMC.html</a>
            </td>
          </tr>
          <tr valign="top">
            <td> Introduction aux m&eacute;thodes Monte-Carlo (fr) </td>
            <td> <a
 href="http://cermics.enpc.fr/%7Ebl/PS/SIMULATION-X/poly-monte-carlo-x.pdf">http://cermics.enpc.fr/~bl/PS/SIMULATION-X/poly-monte-carlo-x.pdf</a>
            </td>
          </tr>
          <tr valign="top">
            <td> Aide &agrave; la programmation Monte-Carlo </td>
            <td> <a
 href="http://www.sciences-en-ligne.com/momo/chronomath/java_elem/pi_alea.html">http://www.sciences-en-ligne.com/momo/chronomath/java_elem/pi_alea.html</a>
            <br>
            <br>
            <a
 href="http://www.tls.cena.fr/divisions/MSS/SUPPORT/MCARLO/MC_frame.shtml#pi">http://www.tls.cena.fr/divisions/MSS/SUPPORT/MCARLO/MC_frame.shtml#pi</a>
            </td>
          </tr>
        </tbody>
      </table>
      <br>
      <p> <a href="#top">Haut de page</a> </p>
      <br>
      </td>
    </tr>
</table>
{/literal}
