{include file="header.tpl" title1="STATISTICS" title2="grid stats"}
{include file="sous_menu.tpl" title1="grille" }

<h1> Grid stats page</h1>
</br>

{if $bouton=="year"}

    change duration, see last:
    <a href ="stats_grille.php?bouton=day">day</a>  -
    <a href ="stats_grille.php?bouton=week">week</a>  -
    <a href ="stats_grille.php?bouton=month">month </a>  -
    year

    <h3> Time repartition on the Cluster during the last year:</h3>
    </br>
    <img src= "camembert.php?bouton={$bouton}" alt="graph">

{elseif $bouton=="month"}

    <!--<form method="post" action="stats_grille.php">
    change duration, see on:
    <input type="submit"  name="bouton" value="day">
    <input type="submit"  name="bouton" value="week">
    .......
    <input type="submit"  name="bouton" value="year">
    </form>
    -->
    change duration, see last:
    <a href ="stats_grille.php?bouton=day">day</a>  -
    <a href ="stats_grille.php?bouton=week">week</a>  -
    month  -
    <a href ="stats_grille.php?bouton=year"> year</a>

    <h3> Time repartition on the Cluster during the last month:</h3>
    <img src= "camembert.php?bouton={$bouton}" alt="graph">
</br>

{elseif $bouton=="day"}

    change duration, see last: .
    day  -
    <a href ="stats_grille.php?bouton=week">week</a>  -
    <a href ="stats_grille.php?bouton=month">month </a>  -
    <a href ="stats_grille.php?bouton=year"> year</a>

    <h3> Time repartition  on the Cluster since yesterday:</h3>
    <img src= "camembert.php?bouton={$bouton}" alt="graph">
    </br>
{else}

    change duration, see last: .
    <a href ="stats_grille.php?bouton=day">day</a>  -
    week  -
    <a href ="stats_grille.php?bouton=month">month </a>  -
    <a href ="stats_grille.php?bouton=year">year</a>

    <h3> Time repartition on the Cluster during the last week:</h3>
    <img src= "camembert.php?bouton=week" alt="graph">
    </br>

{/if}

{include file="foot_sous_menu.tpl"}
{include file="../../../foot.tpl"}
