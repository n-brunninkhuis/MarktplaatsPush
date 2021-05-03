#!/usr/bin/php
<?php

	ini_set('display_errors', 1);
	ini_set('display_startup_errors', 1);
	error_reporting(E_ALL);

	$settings = [
		"working_dir"	=>			"/home/niek/bin",
		"log_file"	=>				"/home/niek/bin/.mp_log",
		"queries_file"	=>			"/home/niek/bin/.mp_json",
		"old_queries_file"	=>		"/home/niek/bin/.mp_old",
		"items_pushed_file"	=>		"/home/niek/bin/.mp_items",
		"postcode"	=>				"5040AA",
		"pushover_token"	=>		"TOKEN",
		"pushover_user"	=>			"USER",

		"found_items" => 			0,
		"new_items" => 				0,
		"pushed_items" => 			0,
		"list" =>					"",
	];

	if (!file_exists($settings['working_dir'])) touch($settings['working_dir']);
	if (!file_exists($settings['log_file'])) touch($settings['log_file']);
	if (!file_exists($settings['queries_file'])) touch($settings['queries_file']);
	if (!file_exists($settings['old_queries_file'])) touch($settings['old_queries_file']);
	
	if (isset($argv[1])) {
		$a = $argv[1];
		if 		($a == "-p") echo find_items_and_push();
		elseif  ($a == "-l") echo list_queries();
		elseif  ($a == "-d" && isset($argv[2])) delete_query($argv[2]);
		elseif  ($a == "-a" && isset($argv[2])) echo add_query($argv[2]);
		else 	show_help();
	} else {
		show_help();
	}



	function show_help() {
		echo "Usage:\n";
		echo "\tmp [options] \"[URL]\" [ID]\n\n";
		echo "Options:\n";
		echo "\t-p [PUSH]\tFind items and push. Add second argument to skip push.\n";
		echo "\t-l\t\tList queries\n";
		echo "\t-d [ID]\t\tDelete query\n";
		echo "\t-a \"[URL]\"\tAdd query\n\n";
	}



	function find_items_and_push() {

		global $settings;

		$queries = json_decode(file_get_contents($settings['queries_file']));
		$return = date("Y-m-d H:i:s").": ";

		if (isset($argv[2])) {$push = false;} else {$push = true;}

		foreach ($queries as $q) {
			run_query($q, $push);
		}

		$return .= "{$settings['found_items']} found, {$settings['pushed_items']} pushed\n";
		$return .= 	$settings['list'];

		file_put_contents($settings['log_file'], $return, FILE_APPEND);
		return $return;

	}



	function run_query($q, $push) {

		global $settings;

		$query = rawurlencode($q[0]);
			if ($q[1]) { $l1 = "l1CategoryId={$q[1]}&"; } else { $l1 = ""; }
			if ($q[2]) { $l2 = "l2CategoryId={$q[2]}&"; } else { $l2 = ""; }
			if ($q[3]) {
				$distance = $q[3]*1000;
				$dist = "distanceMeters={$distance}&";
			} else { $dist = ""; }
			if ($q[4]) {
				if (is_int($q[4][0])) { $from = $q[4][0] * 100; } else { $from = "null"; } 
				if (is_int($q[4][1])) { $to = $q[4][1] * 100; } else { $to = "null"; } 
				$pricerange = "attributeRanges[]=PriceCents%3A{$from}%3A{$to}&";
			} else { $pricerange = ""; }
			if ($q[5]) { $attr = "attributesById[]=".implode('&attributesById[]=', $q[5])."&"; } else { $attr = ""; }

			$search_url =	"https://www.marktplaats.nl/lrp/api/search?".
							$pricerange.
							$attr.
							$l1.
							$l2.
							$dist.
							"asSavedSearch=true&".
							"limit=30&".
							"offset=0&".
							"postcode={$settings['postcode']}&".
							"query={$query}&".
							"searchInTitleAndDescription=true&".
							"viewOptions=list-view";

			//echo $search_url."\n";

			$json = file_get_contents($search_url);
			$array = json_decode($json, true);

			//print_r($array['listings'])."\n";

			foreach ($array['listings'] as $key => $item) {
				
				$items_array = json_decode(file_get_contents($settings['items_pushed_file']), true);
				$settings['found_items']++;

				// print_r($item);

				if (!in_array($item['itemId'], $items_array)) {

					$settings['new_items']++;
					$t = $item['priceInfo']['priceType'];
					$price_euros = round($item['priceInfo']['priceCents'] / 100);
					if ($price_euros > 0) {
						$p = " • €".$price_euros;
					} else {
						$p = "";
					}
					
					if ($t == "RESERVED") {
						$msg = false;
					} elseif ($t == "FIXED") {
						$msg = "Vaste prijs{$p}";
					} elseif ($t == "MIN_BID" || $t == "FAST_BID") {
						$msg = "Bieden{$p}";
					} elseif ($t == "NOTK") {
						$msg = "N.o.t.k.";
					} elseif ($t == "FREE") {
						$msg = "Gratis";
					} elseif ($t == "SEE_DESCRIPTION") {
						$msg = "Zie beschrijving";
					} else {
						$msg = "{$t}";
					}

					if ($msg) {
						$settings['pushed_items']++;
						$title = $item['title'];
						$mp_url = "https://link.marktplaats.nl/{$item['itemId']}";
						$maps_url = "https://www.google.nl/maps/dir/Thuis/{$item['location']['cityName']}/";
						$km = round($item['location']['distanceMeters']/1000 * 1.3);

						$settings['list'] .= substr($title,0,25)." ";

						if ($push) {

							$image_url = str_replace("_82.JPG", "_86.JPG", "https:".$item['imageUrls'][0]);
							file_put_contents($settings['working_dir']."/marktplaats.jpg", file_get_contents($image_url));

							$msg = 	"<b>".$msg." • {$km}km</b>\n\n".
									"{$item['description']}\n\n".
									"<a href='{$mp_url}'>Bekijk advertentie</a>\n\n".
									"<a href='{$maps_url}'>Route naar {$item['location']['cityName']}</a>";

							curl_setopt_array($ch = curl_init(), array(
								CURLOPT_URL => "https://api.pushover.net/1/messages.json",
								CURLOPT_POSTFIELDS => array(
									"token" => $settings['pushover_token'],
									"user" => $settings['pushover_user'],
									"html" => 1,
									"title" => $title,
									"message" => $msg,
									"url_title" => "Advertentie bekijken",
									"url" => $mp_url,
									"attachment" => curl_file_create($settings['working_dir']."/marktplaats.jpg", "image/jpeg"),
								),
								CURLOPT_SAFE_UPLOAD => true,
								CURLOPT_RETURNTRANSFER => true,
							));
							$content = curl_exec($ch);
							curl_close($ch);
							$settings['list'] .= $content;

							unlink($settings['working_dir']."/marktplaats.jpg");

						}

						$settings['list'] .= "\n";

					}

					$items_array[] = $item['itemId'];
					file_put_contents($settings['items_pushed_file'], json_encode($items_array));

				}
				
			}

	}



	function list_queries() {

		global $settings;

		$queries = json_decode(file_get_contents($settings['queries_file']));

		foreach ($queries as $key => $value) {
			if ($value[0]) $value[0] = " • \"{$value[0]}\"";
			if ($value[3]) $value[3] = " • <{$value[3]}km";
			if ($value[4][0] || $value[4][1]) {
				if ($value[4][0]) { 
					$from = "€{$value[4][0]}";
				} else {
					$from = "€0";
				}
				if ($value[4][1]) { 
					$to = "€{$value[4][0]}";
				} else {
					$to = "∞";
				}
				$price = " • {$from} - {$to}";
			} else {
				$price = "";
			}
			echo "[{$key}]\t{$value[6]}{$value[0]}{$value[3]}{$price}\n";
		}

	}



	function add_query($url) {

		global $settings;

		$append = [false, false, false, false, [false,false], false, false, $url];

		if (strpos($url, "#")) {

			$html = file_get_contents($url);
			$start = strpos($html, "window.dataLayer");
			$end = strpos($html, "]", $start);
			$json = substr($html, ($start+19), ($end-$start+1-19));
			$array = json_decode($json, true);
			
			//print_r($array);

			if ($array[0]['c']['l1']['id']) $append[1] = $array[0]['c']['l1']['id'];
			if ($array[0]['c']['l2']['id']) $append[2] = $array[0]['c']['l2']['id'];
			if (isset($array[0]['c']['l2']['n'])) {
				$append[6] = $array[0]['c']['l2']['n'];
			} elseif (isset($array[0]['c']['l1']['n'])) {
				$append[6] = $array[0]['c']['l1']['n'];
			}  else {
				$append[6] = "Alles";
			}

			$url_after_hastag = substr($url, strpos($url, "#")+1);
			$url_after_hastag_parts = explode("|", $url_after_hastag);

			$url_before_hastag = substr($url, 0, strpos($url, "#"));
			$url_before_hastag_parts = explode("/", $url_before_hastag);

			$i = 0;
			foreach ($url_before_hastag_parts as $value) {
				if ($value == "f") {
					$append[5] = array_map('intval', explode('+', $url_before_hastag_parts[$i+2]));
				}
				$i++;
			}

			foreach ($url_after_hastag_parts as $value) {
				$split = explode(":", $value);
				if ($split[0] == "q") {
					$append[0] = str_replace("+", " ", $split[1]);
				}
				elseif ($split[0] == "f") {
					if (!is_array($append[5])) {$append[5] = [];}
					$append[5] = array_merge($append[5], array_map('intval', explode(",", $split[1])));
				}
				elseif ($split[0] == "distanceMeters") {
					$append[3] = $split[1] / 1000;
				}
				elseif ($split[0] == "PriceCentsFrom") {
					$append[4][0] = $split[1] / 100;
				}
				elseif ($split[0] == "PriceCentsTo") {
					$append[4][1] = $split[1] / 100;
				}
				// To do: constructionYearFrom, constructionYearTo
			}

		} else {

			$url_parts = explode("/", $url);
			$append[0] = str_replace("+", " ", $url_parts[4]);
			$append[6] = "Alles";

		}

		run_query($append, false);

		$queries = json_decode(file_get_contents($settings['queries_file']));
		$queries[] = $append;
		file_put_contents($settings['queries_file'], json_encode($queries));

		echo list_queries();

	}



	function delete_query($id) {

		global $settings;

		$queries = json_decode(file_get_contents($settings['queries_file']));
		
		$old_queries = json_decode(file_get_contents($settings['old_queries_file']));
		$old_queries[] = $queries[$id];
		file_put_contents($settings['old_queries_file'], json_encode(array_values($old_queries)));

		unset($queries[$id]);
		file_put_contents($settings['queries_file'], json_encode(array_values($queries)));

		echo list_queries();

	}



?>
