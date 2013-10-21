use strict;
use warnings;

my $infile = undef;
my $outfile = undef;
for (my $i = 0; $i < scalar(@ARGV); $i++) {
    if ($ARGV[$i] eq "-i") { $infile = $ARGV[++$i]; }
    elsif ($ARGV[$i] eq "-o") { $outfile = $ARGV[++$i]; }
    else { die "Unhandled option: ".$ARGV[$i]; }
}
if (!$infile || !$outfile) { print "Usage : $0 -i <input txt file> -o <output csv file>"; exit; }

writeCsv($outfile, structureData(getFileLines($infile)));

sub getFileLines {
	my ($filename) = @_;
	open FILE, "<".$filename or die $!;
	my @lines = <FILE>;
	close FILE;
	@lines;
}

# ASAN = Address Sanitizer
sub structureData {
	my @lines = @_;
    my $osnames = {'WinNT 5.1'=>'XP', 'WinNT 5.2'=>'XP 64', 'WinNT 6.1'=>'7', 'WinNT 6.1 64'=>'7', 'WinNT 6.2'=>'8',
        'MacOSX 10.5.8 64'=>'Leopard','MacOSX 10.6 64'=>'Snow Leopard', 'MacOSX 10.7 64'=>'Lion', 'MacOSX 10.8 64'=>'Mountain Lion',
		'Fedora 12'=>'', 'Fedora 12 64'=>'', 'Android'=>'', 'Android'=>'', 'B2G gb (armv7a)'=>'', 'B2G ics (armv7a)'=>'',
        'Ubuntu12.04'=>'Precise Pangolin', 'Ubuntu12.04 x64'=>'Precise Pangolin'};
	my $data = [];
	foreach my $line (@lines) {
		my ($name, $time) = $line=~/^(.*) (\d+\.\d+)\s*$/;

		my $product =
			($name=~/^Android XUL .*\bmozilla-central /i ? "ff-mobile-xul|armv7a" :
			($name=~/^Android( \d+\.\d+| X86|) .*\bmozilla-central /i ? "ff-mobile$1|".($name=~/armv6/i ? "armv6" : "armv7a") :
            ($name=~/^B2G[ _](gb|ics|emulator|ubuntu64_vm).*\bmozilla-central /i ? "b2g|$1" :
			($name=~/^jetpack-mozilla-central-(xp|win7|w764|fedora|fedora64|leopard|lion|snowleopard)-/i ? "ff-desktop|".
				($1 eq "xp"? "Win" : ($1 eq "win7"? "Win" : ($1 eq "w764"? "Win64" : ($1 eq "fedora"? "Linux" : ($1 eq "fedora64"? "Linux64" : ($1 eq "leopard"? "MacOSX" : ($1 eq "lion"? "MacOSX" : ($1 eq "snowleopard" ? "MacOSX" : "NA")))))))) :
			($name=~/ test jetpack/i ? "ff-desktop|".($name=~/ Fedora |Ubuntu/ ? "Linux" : ($name=~/ MacOSX .* (\d+(?:\.\d+)*) / ? "MacOSX" : ($name=~/(WINNT|Windows) (\d+(?:\.\d+)*|XP) / ? "Win" : "NA"))).($name=~/x64 / ? "64" : "") :
            ($name=~/^(?:Rev\d |)(Windows 7|Windows XP|WINNT \d+\.\d|OS X \d+\.\d|MacOSX (Lion|Snow Leopard|Leopard|Mountain Lion) \d+(\.\d)*|Fedora \d+|Ubuntu( VM| ASAN VM| HW) \d+\.\d+|Linux)( x86-64| x64| 64-bit|.64| 32-bit|) mozilla-central /i ?
                "ff-desktop|".
				($name=~/(Fedora |Linux |Ubuntu)/ ? "Linux" : ($name=~/Windows 7 |Windows XP |WINNT / ? "Win" : ($name=~/(^OS X | MacOSX )/ ? "MacOSX" : "NA"))).
                ($name=~/( x86-64|x64| 64-bit) / && !($name=~/(^OS X | MacOSX )/) ? "64" : "") :
            ($name=~/^b2g_mozilla-central_(emulator|emulator-jb|hamachi|hamachi_eng|helix|inari|leo|leo_eng|linux32|linux64|macosx64|nexus-4|unagi|win32)(?:-debug)?_(?:dep|gecko build)$/i ? "b2g|$1" :
			"NA")))))));
        if ($product =~/NA/) { die "Product not found: '".$name."' '".$product."'"; }

		my $build = $name=~/ build$/;
		my $hw =
			($name=~/^Android (?:Debug |XUL |).*(Armv6|Tegra 250|)/ ? ($build ? "Rev3|Fedora 12" : ($1=~s/ //r)."|Android") :
			($name=~/^B2G .*\bmozilla-central build$/ ? ($build ? "Rev3|Fedora 12" : "Tegra250|B2G") :
			($name=~/^(Rev\d|) ?WINNT (\d+\.\d)( x86-64| x64| 64-bit|) mozilla-central /i ? ($1?$1:"Rev3 ")."|WinNT $2".($3 ne "" ? " 64" : "") :
            ($name=~/^(Rev\d|) ?(OS X|MacOSX) (?:Lion |Snow Leopard |Leopard |Mountain Lion |)(\d+(?:\.\d)*)( x86-64| x64| 64-bit|) mozilla-central /i ? ($1?$1:"Rev3 ")."|MacOSX $3 64" :
			($name=~/^(Rev\d|) ?(?:Fedora 12|Linux)( x86-64| x64| 64-bit|x64|) mozilla-central /i ? ($1?$1:"Rev3 ")."|Fedora 12".($2 ne "" ? " 64" : "") :
            ($name=~/^Ubuntu(?: ASAN)? (VM|HW) (12.04(?: x64)?)/ ? $1."|Ubuntu$2" :
            ($name=~/^Windows XP / ? "?|WinNT 5.1" :
            ($name=~/^Windows 7 / ? "?|WinNT 6.1" :
			($name=~/^jetpack-mozilla-central-(xp|win7|w764|fedora|fedora64|leopard|lion|snowleopard)-/ ?
				($1 eq "xp" ? "Rev3|WinNT 5.1" :
				($1 eq "win7" || $1 eq "w764"? "Rev3|WinNT 6.1" :
				($1 eq "fedora" || $1 eq "fedora64" ? "Rev3|Fedora 12" :
				($1 eq "leopard" ? "Rev3|MacOSX 10.5.8 64" :
				($1 eq "snowleopard" ? "Rev4|MacOSX 10.6 64" :
				($1 eq "lion" ? "Rev4|MacOSX 10.7 64" : "NA")))))).
				($1=~/64$/ ? " 64" : "") :
			"NA")))))))));
		my $os = "NA";
		if ($hw=~/(.*)\|(.*)/) { $hw = $1; $os = $2; }
		$os .= (exists $osnames->{$os} ? ($osnames->{$os} ne "" ? " (".$osnames->{$os}.")" : "") : "NA");
        #if ($hw eq "NA") { die "HW not found: '".$name."'"; }        
        if ($os eq "NA") { die "OS not found: '".$name."'"; }        

		my $flag =
            ($name=~/debug static analysis/i ? "debug static analysis" :
            ($name=~/ no-ionmonkey /i ? "no-ionmonkey" :
            ($name=~/ debug asan /i ? "debug asan" :
            ($name=~/ asan /i ? "opt asan" :
            ($name=~/-generational/i ? "debug generational" :
            ($name=~/-rootanalysis/i ? "debug rootanalysis" :
            ($name=~/ leak test /i ? "debug" :
            ($name=~/debug_dep/i ? "debug" :
            ($name=~/_dep/i ? "opt" :
			($name=~/ (opt|debug) /i ? lc($1) :
			($name=~/B2G (?:gb|ics)_armv7a_gecko(-debug|)/ ? ($1 ne "" ? "debug" : "opt") :
			($name=~/ talos (.*)/ ? "opt" :
			($name=~/^Android (Debug |)(?:Armv6 |XUL |)mozilla-central build$/ ? ($1 ne "" ? "debug" : "opt") :
			($name=~/^(?:Linux|OS X \d+\.\d+|WINNT \d+\.\d+)(?: x86-64| 64-bit|) mozilla-central (leak test |)build$/ ? ($1 ne "" ? "debug" : "opt") :
			($name=~/^jetpack-.*-(opt|debug)$/ ? $1 :
            ($name=~/ build$/ ? "opt" :
			"NA"))))))))))))))));
		my $task =
            ($name=~/hsts preload update/ ? "hsts preload update" :
			($name=~/(?: opt test | debug test )(.*)/ ? "test $1" :
			($name=~/ talos (.*)/ ? "talos $1" :
			($name=~/ build$|_dep/ ? "build" :
			($name=~/^jetpack-/ ? "test jetpack2" :
			"NA")))));
		my @product = $product=~/(.*)\|(.*)/;
        push($data, {'name'=>$name,'hw'=>$hw, 'product'=>($product[0] || ''), 'productarch'=>($product[1] || ''), 'os'=>$os, 'flag'=>$flag, 'task'=>$task, 'time'=>$time, });
	}
	$data;
}

sub writeCsv {
	my ($filename, $data) = @_;
	open FILE, ">".$filename or die $!;
	print FILE "name\tproduct\tproductarch\thw\tos\tflag\ttask\ttime\n";
	foreach my $d (@{$data}) {
		print FILE join("\t", ($d->{'name'}, $d->{'product'}, $d->{'productarch'}, $d->{'hw'}, $d->{'os'}, $d->{'flag'}, $d->{'task'}, $d->{'time'}=~s/\./,/r))."\n";
	}
	close FILE;
}
