use strict;
use warnings;

# Read file
open FILE, "<tasks.txt" or die $!;
my @lines = <FILE>;
close FILE;

# Structure data
my $osnames = {'WinNT 5.1'=>'XP', 'WinNT 5.2'=>'XP x64', 'WinNT 6.1'=>'7', 'WinNT 6.1 x64'=>'7',
	'MacOSX 10.5.8'=>'Leopard','MacOSX 10.6'=>'Snow Leopard', 'MacOSX 10.7'=>'Lion', 'MacOSX 10.7 x64'=>'Lion',
	'Fedora 12'=>'', 'Fedora 12 x64'=>'', 'Android (armv6)'=>'', 'Android (armv7a)'=>'', 'b2g gb'=>'', 'b2g ics'=>''};
my $data = [];
foreach my $line (@lines) {
	my ($name, $time) = $line=~/^(.*) (\d+\.\d+)\s*$/;
	my $hw =
		($name=~/^(Android Debug|Android XUL|Android) mozilla-central build/ ? "rev3" :
		($name=~/Tegra 250/i ? "tegra250" :
		($name=~/armv6[ _].* build$/i ? "rev3" :
		($name=~/armv7a/i ? "armv7a" :
		($name=~/^Rev3 / ? "rev3" :
		($name=~/^Rev4 / ? "rev4" :
		($name=~/^(WINNT 5.2|WINNT 6.1 x86-64|Linux|Linux x86-64) mozilla-central/ ? "rev3" :
		($name=~/^(OS X 10.7|OS X 10.7 64-bit) mozilla-central/ ? "rev4" :
		($name=~/^jetpack-mozilla-central-(xp|win7|w764|fedora|fedora64|leopard)-/ ? "rev3" :
		($name=~/^jetpack-mozilla-central-(lion|snowleopard)-/ ? "rev4" :
		"NA"))))))))));
	my $product =
		($name=~/^Android XUL .*\bmozilla-central /i ? "ff-mobile-xul" :
		($name=~/^Android .*\bmozilla-central /i ? "ff-mobile" :
		($name=~/^B2G .*\bmozilla-central /i ? "b2g" :
		($name=~/^jetpack-/i ? "jetpack" :
		($name=~/^ test jetpack /i ? "jetpack" :
		($name=~/^(?:Rev\d |)(WINNT \d+\.\d|OS X \d+\.\d|MacOSX (Lion|Snow Leopard|Leopard) \d+(\.\d)*|Fedora \d+|Linux)( x86-64| x64| 64-bit|) mozilla-central /i ? "ff-desktop" :
		($name=~/^jetpack-mozilla-central-(xp|win7|w764|fedora|fedora64|leopard|lion|snowleopard)-/ ? "ff-desktop" :
		"NA")))))));
	my $os =
		($name=~/^Android (?:Debug |XUL |)(Armv6 |Tegra 250 |)mozilla-central /i ? "Android".($1 eq "Armv6 " ? " (armv6)" : " (armv7a)") :
		($name=~/^B2G (gb|ics)_.*\bmozilla-central /i ? "b2g $1" :
		($name=~/^(?:Rev\d |)WINNT (\d+\.\d)( x86-64| x64| 64-bit|) mozilla-central /i ? "WinNT $1".($2 ne "" ? " x64" : "") :
		($name=~/^(?:Rev\d |)OS X 10\.7( 64-bit|) mozilla-central /i ? "MacOSX 10.7".($1 ne "" ? " x64" : "") :
		($name=~/^(?:Rev\d |)MacOSX (Lion|Snow Leopard|Leopard) (\d+(?:\.\d)*)( x86-64| x64| 64-bit|) mozilla-central /i ? "MacOSX $2".($3 ne "" ? " x64" : "") :
		($name=~/^(?:Rev\d |)(?:Fedora 12|Linux)( x86-64| x64| 64-bit|) mozilla-central /i ? "Fedora 12".($1 ne "" ? " x64" : "") :
		($name=~/^jetpack-mozilla-central-(xp|win7|w764|fedora|fedora64|leopard|lion|snowleopard)-/ ?
			($1 eq "xp" ? "WinNT 5.1" :
			($1 eq "win7" || $1 eq "w764"? "WinNT 6.1" :
			($1 eq "fedora" || $1 eq "fedora64" ? "Fedora 12" :
			($1 eq "leopard" ? "MacOSX 10.5.8" :
			($1 eq "snowleopard" ? "MacOSX 10.6" :
			($1 eq "lion" ? "MacOSX 10.7" : "NA")))))).
			($1=~/64$/ ? " x64" : "") :
		"NA")))))));
	if ($os eq "MacOSX 10.7") { $os .= " x64"; } # Assume all lion machines are 64-bit
	$os .= (exists $osnames->{$os} ? ($osnames->{$os} ne "" ? " (".$osnames->{$os}.")" : "") : "NA");
	my $flag =
		($name=~/ (opt|debug) test / ? $1 :
		($name=~/B2G (?:gb|ics)_armv7a_gecko(-debug|)/ ? ($1 ne "" ? "debug" : "opt") :
		($name=~/ talos (.*)/ ? "opt" :
		($name=~/^Android (Debug |)(?:Armv6 |XUL |)mozilla-central build$/ ? ($1 ne "" ? "debug" : "opt") :
		($name=~/^(?:Linux|OS X \d+\.\d+|WINNT \d+\.\d+)(?: x86-64| 64-bit|) mozilla-central (leak test |)build$/ ? ($1 ne "" ? "leak" : "opt") :
		($name=~/^jetpack-.*-(opt|debug)$/ ? $1 :
		"NA"))))));
	my $task =
		($name=~/(?: opt test | debug test )(.*)/ ? "test $1" :
		($name=~/ talos (.*)/ ? "talos $1" :
		($name=~/ build$/ ? "build" :
		($name=~/^jetpack-/ ? "build" :
		"NA"))));
	push($data, {'name'=>$name,'hw'=>$hw, 'product'=>$product, 'os'=>$os, 'flag'=>$flag, 'task'=>$task, 'time'=>$time, });
}

# Write csv-file
open FILE, ">tasks.csv" or die $!;
print FILE "name\thw\tproduct\tos\tflag\ttask\ttime\n";
foreach my $d (@{$data}) {
	my $time = $d->{'time'};
	$time=~s/\./,/;
	print FILE join("\t", ($d->{'name'}, $d->{'hw'}, $d->{'product'}, $d->{'os'}, $d->{'flag'}, $d->{'task'}, $time))."\n";
}
close FILE;

# Write html-html
open FILE, ">tasks.html" or die $!;
print FILE "<!DOCTYPE html><html><meta charset=utf-8><head><title>Build tasks</title><style>
	body{font-family:verdana,arial; font-size:11px;}
	table{border-collapse:collapse;}
	th,td{ vertical-align:top; }
	th{ text-align:inherit; background:#eeeeee; }
	.columns td { padding:0 10px 0 0; }
	.columns td td { padding:1px; }
	.tabular th,.tabular td{ border:1px solid #cccccc;white-space:nowrap; }
	.num{ text-align:right; }
	.rowhead { vertical-align:bottom; }
	.colhead { text-align:right; }
	th.vert { height:200px; text-align:center; vertical-align:bottom; }
	th.vert div {
		-moz-transform-origin:0 0; -moz-transform:translateY(100%) rotate(-90deg);
		-webkit-transform-origin:0 0; -webkit-transform:translateY(100%) rotate(-90deg);
		transform-origin:0 0; transform:translateY(100%) rotate(-90deg);
		margin:0 -185px 0 0;
		text-align:left;
		vertical-align:top;
		width:200px;
		filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=3);
		margin-bottom: 190px\\9;}
</style></head><body><table class=columns><tr>";
foreach my $type ('desktop', 'mobile') {
	my ($cols, $rows, $colcount, $rowcount, $cells) = ({}, {}, {}, {}, {});
	foreach my $d (@{$data}) {
		if (($type eq "desktop") != ($d->{'hw'} eq "rev3" || $d->{'hw'} eq "rev4")) { next; }
		my ($col, $row) = ($d->{'hw'}."\t".$d->{'os'}, $d->{'product'}."\t".$d->{'flag'}."\t".$d->{'task'});
		if (!$cols->{$col}) { $cols->{$col} = {'hw'=>$d->{'hw'}, 'os'=>$d->{'os'}}; $colcount->{$d->{'hw'}}++; }
		if (!$rows->{$row}) { $rows->{$row} = {'product'=>$d->{'product'}, 'flag'=>$d->{'flag'}, 'task'=>$d->{'task'}}; $rowcount->{$d->{'product'}}++; $rowcount->{$d->{'product'}."\t".$d->{'flag'}}++; }
		if ($cells->{$col."\t".$row}) { die "Dublicate key '".$col."\t".$row."' for:\n'".$cells->{$col."\t".$row}->{'name'}."'\n'".$d->{'name'}."' "; }
		$cells->{$col."\t".$row} = $d;
	}

	print FILE "<td><h2>".$type." hardware</h2><table class=tabular>";
	print FILE "<tr><th><th><th class=colhead>Build HW";
	my $prevhw = "_";
	foreach my $col (sort keys %{$cols}) {
		my ($hw, $os) = ($cols->{$col}->{'hw'}, $cols->{$col}->{'os'});
		print FILE ($prevhw ne $hw ? "<th colspan=".$colcount->{$hw}.">".$hw : "");
		$prevhw = $hw;
	}
	print FILE "<tr><th><th><th class=colhead>Target OS";
	foreach my $col (sort keys %{$cols}) {
		my ($hw, $os) = ($cols->{$col}->{'hw'}, $cols->{$col}->{'os'});
		print FILE "<th rowspan=2 class=vert><div>".$os."</div>";
	}
	print FILE "<tr><th class=rowhead>Product<th class=rowhead>Flag<th class=rowhead>Task";
	my ($prevproduct, $prevflag) = ("_", "_");
	foreach my $row (sort keys %{$rows}) {
		my ($product, $flag, $task) = ($rows->{$row}->{'product'}, $rows->{$row}->{'flag'}, $rows->{$row}->{'task'});
		print FILE "<tr>".($prevproduct ne $product ? "<th rowspan=".$rowcount->{$product}.">".$product : "").($prevflag ne $product."\t".$flag ? "<th rowspan=".$rowcount->{$product."\t".$flag}.">".$flag : "")."<th>".$task;
		foreach my $col (sort keys %{$cols}) {
			my ($hw, $os) = ($cols->{$col}->{'hw'}, $cols->{$col}->{'os'});
			my $d = (exists $cells->{$col."\t".$row} ? $cells->{$col."\t".$row} : 0);
			print FILE ($d ? "<td class=num title='".$d->{'name'}."'>".int($d->{'time'}) : "<td>");
		}
		$prevproduct = $product; $prevflag = $product."\t".$flag;
	}
	print FILE "</table>";
}
print FILE "</table></body></html>";
close FILE;
