{literal}
<table border="0" cellpadding="10" cellspacing="0">
<tr><td>
	<h1>Utilisation de la grille ci-gri</h1>
	<ul>
		<li>
	  		<h4><a name="step1">Etape 1 :</a></h4>
		</li>
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
		<li><b>Tomte : </b><a href="http://www-chimie.ujf-grenoble.fr/">http://www-chimie.ujf-grenoble.fr/
	    </a><br>
		administrateur : Sebastien Morin <a href="mailto:%20sebastien.morin@ujf-grenoble.fr">sebastien.morin@ujf-grenoble.fr</a>
		</li>
	</ul>
	<p>
		<a href="#top">Haut de page</a>
	</p>
	<ul>
		<li>
			<h4><a name="step2">Etape 2 :</a></h4>
		</li>
	</ul>
	<p> Apr&egrave;s avoir cr&eacute;&eacute; vos comptes, vous devez valider votre application :</p>
	<ul>
		<li>
			Transf&eacute;rez votre application sur les clusters concern&eacute;s
		</li>
		<li>
			Compilez et ex&eacute;cutez-la (avec plusieurs param&egrave;tres si vous en avez)
		</li>
	</ul>
	<p>
		<a href="#top">Haut de page</a>
	</p>
	<ul>
		<li>
			<h4><a name="step3">Etape 3 :</a></h4>
		</li>
	</ul>

	<p>Une fois assur&eacute; de la validit&eacute; de votre programme, vous pouvez cr&eacute;er le JDL (Job Description Language) qui va indiquer &agrave; la grille comment soumettre votre job.</p>
	<h5>exemple de JDL :</h5>
	<table border="0" width="100%" cellpadding="0" cellspacing="0">
	<colgroup><col width="5%"><col width="95%"></colgroup>
	<tr>
		<td></td>
		<td style="width=90%;" class="smallclass">
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
	 	</td>
	</tr>
	</table>
	<p>Remarques sur les possibilit&eacute;s du JDL :</p>
	<table border="0" width="100%" cellpadding="0" cellspacing="0">
	<colgroup><col width="5%"><col width="5%"><col width="90%"></colgroup>
	<tr>
		<td></td>
		<td colspan="2">
  			dans DEFAULT
		</td>
	</tr>
	<tr>
		<td></td>
		<td></td>
		<td class="smallclass">
			. soit vous ex&eacute;cutez votre application X fois en utilisant le mot cl&eacute; "nbjobs"<br>
			. soit vous sp&eacute;cifiez un fichier de param&egrave;tres, chaque ligne de ce fichier sera un argument de votre programme.
		</td>
	</tr>
	</table>
	<p>A noter que le premier param&egrave;tre de votre application sera pris en compte comme &eacute;tant le nom de votre job. Ainsi, lors de la collecte des r&eacute;sultats, les fichiers contenant la sortie standard et la sortie d'erreur seront copi&eacute;s vers le serveur CIGRI ET &eacute;galement le fichier (ou dossier) nomm&eacute; comme le premier param&egrave;tre.
	</p>
	<p>
		<a href="#top">Haut de page</a>
	</p>

	<ul>
		<li>
			<h4><a name="step4">Etape 4 :</a></h4>
		</li>
	</ul>
	<p>Il faut soumettre votre job &agrave; la grille de calcul sur le serveur cigri central (pawnee): </p>
	<p>&nbsp;&nbsp;&nbsp;&nbsp;<i>% gridsub -f nom_JDL</i></p>
	<p>Un site web est en cours de d&eacute;veloppement pour suivre l'&eacute;tat des jobs.</p>
	<p>
		<a href="#top">Haut de page</a>
	</p>

	<ul>
		<li>
			<h4><a name="step5">Etape 5 :</a></h4>
		</li>
	</ul>
	<p>Les fichiers r&eacute;sultats du job sont cr&eacute;&eacute;s sur chaque cluster &agrave; partir de la sortie standard/erreur de votre application.</p>
	<p>Pour recup&eacute;rer vos r&eacute;sultats, tapez la commande :</p>
	<p>&nbsp;&nbsp;&nbsp;&nbsp;<i>% collectorCigri.pl MJobId </i> <span class="smallclass"># MJobId est le num&eacute;ro de job attribu&eacute; lors de la
	commande gridsub.pl</span></p>
	<p>Cette commande rapatrie les r&eacute;sultats sur le seveur cigri central dans le r&eacute;pertoire</p>
	<p>&nbsp;&nbsp;&nbsp;&nbsp;<i>~cigri/results/username/MJobId/*.tar.gz</i></p>
	<p>
		<a href="#top">Haut de page</a>
	</p>
	<br>
	<br>
	<hr>
	<h4><a name="example">Exemple de calcul de Pi par la m&eacute;thode Monte-Carlo et utilisation sur la grille : </a></h4>
	<table border="0" cellpadding="0" cellspacing="10">
	<colgroup><col width="5%"><col width="2%"><col width="93%"></colgroup>
	<tr>
		<td></td>
		<td valign="top">&nbsp;-&nbsp;</td>
		<td valign="top">
			Cr&eacute;ez un compte sur le serveur cigri central (voir avec nicolas capit) et sur
			chaque cluster que vous voulez utiliser
		</td>
	</tr>
	<tr>
		<td></td>
		<td valign="top">&nbsp;-&nbsp;</td>
		<td valign="top">
			R&eacute;cuperez le fichier : <a href="pi.tar">pi.tar</a><br>
			<table border="0" cellpadding="5" cellspacing="0">
				<tr><td class="smallclass">Ce fichier contient 3 programmes diff&eacute;rents: pi_simple, pi250 et pi250_arg.<br>Ces 3 programmes &eacute;valuent pi par la m&eacute;thode de Monte-Carlo, voir le fichier LISEZMOI de pi.tar pour plus de renseignements.
				</td></tr>
			</table>
		</td>
	</tr>
	<tr>
		<td></td>
		<td valign="top">&nbsp;-&nbsp;</td>
		<td valign="top">
			Compilez et ex&eacute;cutez pi_simple, pi250 et pi250_arg sur les clusters concern&eacute;s.
		</td>
	</tr>
	<tr>
		<td></td>
		<td valign="top">&nbsp;-&nbsp;</td>
		<td valign="top">
			Sur le serveur cigri central :<br>
			cr&eacute;ez un fichier <a href="pi_JDL">pi_JDL</a> <span class="smallclass">(ex&eacute;cute le m&ecirc;me
			job 1000 fois sur les clusters tomte et bioimage)</span><br>
			ou cr&eacute;ez un fichier <a href="pi_arg_JDL">pi_arg_JDL</a><span class="smallclass"> (ex&eacute;cute un
			job avec 1000 param&egrave;tres sur les clusters tomte et bioimage)</span>
		</td>
	</tr>
	<tr>
		<td></td>
		<td valign="top">&nbsp;-&nbsp;</td>
		<td valign="top">
			Soumettez votre job par la commande :<br>
			<i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; % grisub -f nom_JDL </i>&nbsp;&nbsp;(pi_JDL ou pi_arg_JDL)<br>
			<table border="0" cellpadding="5" cellspacing="0">
				<tr><td class="smallclass">Un num&eacute;ro de job est attribu&eacute;.<br>
				Votre job est lanc&eacute;, il ne reste qu'&agrave; attendre.
				Un site web va &ecirc;tre disponible prochainement pour suivre l'&eacute;volution de ses jobs.
				</td></tr>
			</table>
		</td>
	</tr>
	<tr>
		<td></td>
		<td valign="top">&nbsp;-&nbsp;</td>
		<td valign="top">
			Pour recup&eacute;rer vos fichiers r&eacute;sultats, tapez<br>
			<i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; % collectorCigri.pl</i><br>
			<table border="0" cellpadding="5" cellspacing="0">
				<tr><td class="smallclass">Vos fichiers sont transf&eacute;r&eacute;s sur le serveur cigri central en tar.gz dans ~cigri/results/username/MJobId/*.tar.gz
				</td></tr>
			</table>
		</td>
	</tr>
	<tr>
		<td></td>
		<td valign="top">&nbsp;-&nbsp;</td>
		<td valign="top">
			Chaque fichier tar.gz comprend un fichier de sortie <span class="smallclass">(c'est le r&eacute;sultat de la sortie standard de votre job)</span> et un fichier d'erreur <span class="smallclass">(vide si votre job a r&eacute;ussi)</span>
		</td>
	</tr>
	<tr>
		<td></td>
		<td valign="top">&nbsp;-&nbsp;</td>
		<td valign="top">
			Vous pouvez ainsi avoir une estimation de pi par la m&eacute;thode de Monte-Carlo apr&egrave;s 1000 ex&eacute;cutions en ex&eacute;cutant
			le script : <a href="script.sh">script.sh </a> <span class="smallclass">(clic
			droit puis t&eacute;l&eacute;charger sous)</span> par<br>
			<i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; % source script.sh</i><br>
			<table border="0" cellpadding="5" cellspacing="0">
				<tr><td class="smallclass">
					Ce script ajoute chaque ligne des fichiers r&eacute;sultats et divise le total
					par le nombre de lignes, on obtient donc un moyennage de pi.
				</td></tr>
			</table>
		</td>
	</tr>
	</table>
	<p>
		<a href="#top">Haut de page</a>
	</p>
	<br>
	<hr>
	<h4><a name="links">Liens :</a></h4>
	<table width="100%" border="1" cellpadding="4" cellspacing="0" style="background-color:#e6e6e6">
	<colgroup><col width="20%"><col width="80%"></colgroup>
	<tr valign="top">
		<td>
			Site g&eacute;n&eacute;ral sur les grilles
		</td>
		<td>
			<a href="http://www.globus.org/">http://www.globus.org/</a>
		</td>
	</tr>
	<tr valign="top">
		<td>
			Site DataGrid
		</td>
		<td>
			<a href="http://eu-datagrid.web.cern.ch/eu-datagrid">http://eu-datagrid.web.cern.ch/eu-datagrid</a>
		</td>
	</tr>
	<tr valign="top">
		<td>
			Site m&eacute;thode Monte-Carlo et quasi Monte-Carlo (eng)
		</td>
		<td>
			<a href="http://www.mcqmc.org/">http://www.mcqmc.org</a>
		</td>
	</tr>
	<tr valign="top">
		<td>
			M&eacute;thode Monte-Carlo et quasi Monte-Carlo et applications (fr)
		</td>
		<td>
			<a href="http://www.irisa.fr/armor/lesmembres/Tuffin/MC.html">http://www.irisa.fr/armor/lesmembres/Tuffin/MC.html</a>
			<br><br>
			<a href="http://www.irisa.fr/armor/lesmembres/Tuffin/QMC.html">http://www.irisa.fr/armor/lesmembres/Tuffin/QMC.html</a>
		</td>
	</tr>
	<tr valign="top">
		<td>
			Introduction aux m&eacute;thodes Monte-Carlo (fr)
		</td>
		<td>
			<a href="http://cermics.enpc.fr/%7Ebl/PS/SIMULATION-X/poly-monte-carlo-x.pdf">http://cermics.enpc.fr/~bl/PS/SIMULATION-X/poly-monte-carlo-x.pdf</a>
		</td>
	</tr>
	<tr valign="top">
		<td>
			Aide &agrave; la programmation Monte-Carlo
		</td>
		<td>
			<a href="http://www.sciences-en-ligne.com/momo/chronomath/java_elem/pi_alea.html">http://www.sciences-en-ligne.com/momo/chronomath/java_elem/pi_alea.html</a>
			<br><br>
			<a href="http://www.tls.cena.fr/divisions/MSS/SUPPORT/MCARLO/MC_frame.shtml#pi">http://www.tls.cena.fr/divisions/MSS/SUPPORT/MCARLO/MC_frame.shtml#pi</a>
		</td>
	</tr>
	</table>
	<br>
	<p>
		<a href="#top">Haut de page</a>
	</p>
	<br>
</td></tr>
</table>
{/literal}
