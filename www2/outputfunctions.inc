<?php

// {{{ cigri_register_menu_item()
// ROLE register a new menu item before displaying in menu.tpl
// IN 	$menu a 2D array
//	$keyword the first $menu dimension
//	$itemname
//	$link URL linked to the item
//	$level 1,2,... used for hierarchical menus
//	$current boolean true if current menu item, false otherwise
// OUT 	true if function succeeds, false otherwise
//	$currentarray stores current item name and link for each menu level
function cigri_register_menu_item(&$menu,&$currentarray,$keyword,$itemname,$link,$level=1,$current = false) {
	// check values
	if (!$keyword || !$itemname || !$link) {
		return false;
	}

	$menu["$keyword"]["name"] = $itemname;
	$menu["$keyword"]["link"] = $link;
	$menu["$keyword"]["level"] = $level;
	$menu["$keyword"]["current"] = $current;

	if ($current) {
		$currentarray[$level]["link"] = $link;
		$currentarray[$level]["name"] = $itemname;
	}
	return true;
}
// }}}

// {{{ cigri_set_page_params()
// ROLE compute page params, check if values are in the limits
// IN
//	$page current page number
//	$step elements step
//	$nbitems total number of items
//	$smarty smarty object reference
//	$getitems $_GET array
//	$formdest form "action" value
// OUT
//	$maxpages total number of pages
//	$minindex index of the first item to display
//	$maxindex index of the last item to display
function cigri_set_page_params(&$page,&$step,$nbitems,&$maxpages,&$minindex,&$maxindex,&$smarty,$getitems,$formdest) {
	// check values
	if (!is_numeric($page)) {
		$page = 1;
	}
	else if ($page < 1) {
		$page = 1;
	}
	if (!is_numeric($step)) {
		$step = 20;
	}
	else if ($step <= 0 || $step >= 200) {
		$step = 20;
	}

	$maxpages = intval(($nbitems+$step - 1) / $step);
	if (($page-1) * $step >= $nbitems) {
		$page = $maxpages;
	}
	$minindex = ($page-1) * $step;
	$maxindex = $minindex + $step;
	if ($maxindex > $nbitems) {
		$maxindex = $nbitems;
	}
	
	// Set smarty vars
	$smarty->assign('formdest',$formdest);
	$smarty->assign('getitems',$getitems);
	$smarty->assign('page',$page);
	$smarty->assign('nextpage',$page+1);
	$smarty->assign('prevpage',$page-1);
	$smarty->assign('step',$step);
	$smarty->assign('nbitems',$nbitems);
	$smarty->assign('maxpages',$maxpages);
	$smarty->assign('minindex',$minindex+1);
	$smarty->assign('maxindex',$maxindex);
}
// }}}

// {{{ cigri_order_by()
// ROLE generates "order by" string and display array
// IN
//	$smarty smarty object reference
//	$get $_GET array
//	$selectnames names on which the order by can be performed
//	$destscript destination script URL
//	$toroot path to cigri www root
// OUT
//	$orderby ORDER BY string to be inserted in sql query
//	$orderarray strings to be added in each item html <a></a> tag
//	$orderimgs string to be added after the column name in order to insert a little "sorting arrow" image
//	$maxindex index of the last item to display
function cigri_order_by(&$get,&$selectnames,$destscript,&$orderby,&$orderarray,&$orderimgs,&$smarty,$toroot) {

	// convert get string
	$getstring = $destscript."?";
	foreach ($get as $key => $value) {
		$getstring .= rawurlencode($key)."=".rawurlencode($value)."&";
	}
	
	// check values
	if ($get['orderby'] && $get['sort']) {
		if (in_array($get['orderby'],$selectnames) && ($get['sort'] == 'ASC' || $get['sort'] == 'DESC')) {
			$orderby = " ORDER BY ".$get['orderby']." ".$get['sort']." ";
			// set right item parameters
			foreach ($selectnames as $value) {
				if ($value == $get['orderby']) {
					if ($get['sort'] == 'ASC') {
						$orderimgs[] = ' <img src="'.$toroot.'desc.gif" alt="Sort" border="0">';
						$orderarray[] = $getstring."orderby=".$value."&sort=DESC";
					}
					else {
						$orderimgs[] = ' <img src="'.$toroot.'asc.gif" alt="Sort" border="0">';
						$orderarray[] = $getstring."orderby=".$value."&sort=ASC";
					}
				}
				else {
					$orderimgs[] = '';
					$orderarray[] = $getstring."orderby=".$value."&sort=DESC";
				}
			}
		}
		else {
			$orderby = '';
			foreach ($selectnames as $value) {
				$orderimgs[] = ' ';
				$orderarray[] = $getstring."orderby=".$value."&sort=DESC";
			}
		}	
	}
	else {
		$orderby = '';
		foreach ($selectnames as $value) {
			$orderimgs[] = ' ';
			$orderarray[] = $getstring."orderby=".$value."&sort=DESC";
		}
	}
	$smarty->assign('itemsorderby',$orderarray);
	$smarty->assign('itemsorderimgs',$orderimgs);
	
}
// }}}
?>
