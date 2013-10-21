use strict;
use warnings;

my $infile = undef;
my $outfile = undef;
my $costPerHour = 0;
for (my $i = 0; $i < scalar(@ARGV); $i++) {
    if ($ARGV[$i] eq "-i") { $infile = $ARGV[++$i]; }
    elsif ($ARGV[$i] eq "-o") { $outfile = $ARGV[++$i]; }
    elsif ($ARGV[$i] eq "-c") { $costPerHour = $ARGV[++$i]; }
    else { die "Unhandled option: ".$ARGV[$i]; }
}
if (!$infile || !$outfile) { print "Usage : $0 -i <input csv file> -o <output html file> [-c <cost per hour>]\n"; exit; }

my $data = readCsv($infile);

sub getFileLines {
    my ($filename) = @_;
    open FILE, "<".$filename or die $!;
    my @lines = <FILE>;
    close FILE;
    @lines;
}

sub readCsv {
    my ($filename) = @_;
    my $data = [];
    my @lines = getFileLines($filename);
    shift @lines;
    foreach my $line (@lines) {
        $line =~s/\s*$//;
        my ($name, $product, $productarch, $hw, $os, $flag, $task, $time) = split(/\t/, $line);
        $time =~s/,/./;
        push(@{$data}, {'name'=>$name,'hw'=>$hw, 'product'=>$product, 'productarch'=>$productarch, 'os'=>$os, 'flag'=>$flag, 'task'=>$task, 'time'=>$time});
    }
    $data;
}

sub formattime {
    my ($t, $header) = @_;
    my $sec = ($header ? "" : "<small>:%02d</small>");
    return ($t >= 3600 ? sprintf("%d:%02d".$sec, $t/3600, ($t/60)%60, $t%60) : sprintf("%d".$sec, $t/60, $t%60)).
        ($header && $costPerHour ? sprintf("~\$%01.2f", $t/3600*$costPerHour) : "");
}

# Try to build a mapping from test-task to build-tasks (i.e. to show who build the thing being tested)
my ($flagProductBuild, $prodTests, $prodPlatform) = ({}, {}, {});
foreach my $d (@{$data}) {
    $d->{'isbuild'} = $d->{'task'}=~/build/;
    if ($d->{'isbuild'}) {
        my $prod = $d->{'product'}."\t".$d->{'productarch'};
        if (!exists $flagProductBuild->{$d->{'flag'}}) { $flagProductBuild->{$d->{'flag'}} = {}; }
        if (exists $flagProductBuild->{$d->{'flag'}}->{$prod}) {
            print "This script assumes each product is build only once:\nProduct: ".$prod."\nBuild 1: ".$flagProductBuild->{$d->{'flag'}}->{$prod}->{'name'}."\nBuild 2: ".$d->{'name'}."\n";
        }
        $flagProductBuild->{$d->{'flag'}}->{$prod} = $d;
        $prodPlatform->{$prod} ||= [];
        if (!(grep {$_->{'hw'} eq $d->{'hw'} && $_->{'os'} eq $d->{'os'}} @{$prodPlatform->{$prod}})) {
            #print "This script assumes each product is build on one platform:\nProduct: ".$prod."\nPlatform 1: ".$prodPlatform->{$prod}->{'hw'}."\t".$prodPlatform->{$prod}->{'os'}."\nPlatform 2: ".$d->{'hw'}."\t".$d->{'os'}."\n";
            push(@{$prodPlatform->{$prod}}, {'hw'=>$d->{'hw'}, 'os'=>$d->{'os'}});
        }
    } else {
        $prodTests->{$d->{'product'}."\t".$d->{'productarch'}}++;
    }
}

# Write html-html
open FILE, ">".$outfile or die $!;
print FILE "<!DOCTYPE html><html><head><meta charset=utf-8><title>Build tasks</title><style>
    body{font-family:verdana,arial; font-size:11px;}
    h2 { margin:0; }
    table{border-collapse:collapse;}
    th,td{ vertical-align:top; }
    th{ text-align:inherit; background:#eeeeee; }
    .columns td { padding:0 10px 0 0; }
    .columns td td { padding:1px; }
    .tabular th,.tabular td{ border:1px solid #cccccc;white-space:nowrap; }

    th.rowhead { vertical-align:bottom; background:#dddddd; }
    th.colhead { text-align:right; background:#dddddd; }
    th.vert { height:150px; width:20px; text-align:center; vertical-align:bottom; border-top:0; border-bottom:0; }
    th.vert div {
        -moz-transform-origin:0 0; -moz-transform:translateY(100%) rotate(-90deg);
        -webkit-transform-origin:0 0; -webkit-transform:translateY(100%) rotate(-90deg);
        transform-origin:0 0; transform:translateY(100%) rotate(-90deg);
        text-align:left;
        vertical-align:top;
        filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=3);
        margin:0 -135px 0 0; width:150px; margin-bottom: 140px\\9;}

    th.vert.platformbase { height:80px; }
    th.vert.platformbase div { margin:0 -65px 0 0; width:80px; margin-bottom: 70px\\9;}

    th.vert.platformarch { height:75px; }
    th.vert.platformarch div { margin:0 -60px 0 0; width:75px; margin-bottom: 65px\\9;}

    th.vert.os { height:120px; }
    th.vert.os div { margin:0 -105px 0 0; width:120px; margin-bottom: 110px\\9;}

    th.vert.hw { height:65px; }
    th.vert.hw div { margin:0 -50px 0 0; width:65px; margin-bottom: 55px\\9;}

    th.bordertop { border-top:1px solid #cccccc; }
    th.borderbottom { border-bottom:1px solid #cccccc; }

    .build { color:#000099; }

    th small { font-weight:normal; color:#999999; }

    .num { text-align:right; }
    .numc { text-align:center; }
    .numc .tip::before { content:'- '; }
    .numc .tip::after { content:' -'; }
    .num small, .numc small { opacity:.5; }

    .tip { position:relative; cursor:default; }
    .tip span { display:none; border:1px solid #666666; background:#ffffee; position:absolute; bottom:10px; left:0px; z-index:1; text-align:left; }
    .tip:hover span { display:block; }
</style></head><body>\n";
my $colkeys = ['product', 'productarch', 'bhw', 'bos', 'hw', 'os'];
my $datagroups = {};
foreach my $d (@{$data}) {
    my $type = ($d->{'product'} eq "firefox" || $d->{'product'} eq "ff-desktop" || $d->{'product'} eq "jetpack" ? "desktop" : ($d->{'product'} =~/b2g/ ? "b2g" : "mobile"));
    if (!$datagroups->{$type}) { $datagroups->{$type} = []; }
    push(@{$datagroups->{$type}}, $d);
}
use Data::Dumper;
foreach my $type ('desktop', 'mobile', 'b2g') {
    # Construct list of columns and rows
    my ($cols, $rows, $colcount, $rowcount, $cells, $rowtimeflag, $rowtime, $coltime) = ({}, {}, {}, {}, {}, {}, {}, {});
    if (!$datagroups->{$type}) { next; }
    foreach my $d (@{$datagroups->{$type}}) {
        my $b = $prodPlatform->{$d->{'product'}."\t".$d->{'productarch'}};
        my $coltemp = {'product'=>$d->{'product'}, 'productarch'=>$d->{'productarch'},
            'bhw'=>$b ? join('<br>', map {$_->{'hw'}} @{$b}) : "", 'bos'=>$b ? join('<br>', map {$_->{'os'}} @{$b}) : "",
            'hw'=>(!$d->{'isbuild'} ? $d->{'hw'} : ''), 'os'=>(!$d->{'isbuild'} ? $d->{'os'} : '')};

        my $col = join("\t", map { $coltemp->{$_} } @{$colkeys});
        my $row = $d->{'flag'}."\t".$d->{'task'};
        if (!$cols->{$col} && (!$d->{'isbuild'} || !$prodTests->{$d->{'product'}."\t".$d->{'productarch'}})) {
            $cols->{$col} = $coltemp;
            for (my $i = 0; $i < scalar(@{$colkeys}); $i++) {
                $colcount->{join("\t", map { $coltemp->{$_} } (@{$colkeys}[0..$i]))}++;
            }
        }
        for (my $i = 0; $i < scalar(@{$colkeys}); $i++) {   
            $coltime->{join("\t", map { $coltemp->{$_} } (@{$colkeys}[0..$i]))} += $d->{'time'};
        }

        if (!$rows->{$row}) {
            $rows->{$row} = {'flag'=>$d->{'flag'}, 'task'=>$d->{'task'}};
            $rowcount->{$d->{'flag'}}++;
        }
        $rowtimeflag->{$d->{'flag'}} += $d->{'time'};
        $rowtime->{$row} += $d->{'time'};

        #if ($cells->{$col."\t".$row}) { print "Dublicate key '".$col."\t".$row."' for:\n'".($cells->{$col."\t".$row}->{'name'}=~s/<table>.*<\/table>|<[^<>]*>//rg)."'\n'".($d->{'name'}=~s/<table>.*<\/table>|<[^<>]*>//rg)."'\n"; }
        $cells->{$col."\t".$row} ||= [];
        push(@{$cells->{$col."\t".$row}}, $d);
    }

    # Write column headers
    print FILE "<h2>".$type." products</h2>\n<table class=tabular>";
    for (my $i = 0; $i < scalar(@{$colkeys}); $i++) {
        print FILE "\n<tr>".($i==0 ? "<th class=rowhead rowspan=6 colspan=2>Flag<th class=rowhead rowspan=6 colspan=2>Task<th rowspan=2 class='colhead vert'><div>Product</div>" :
            ($i==2 ? "<th class='colhead vert' rowspan=2><div>Build platform</div>" :
            ($i==4 ? "<th class='colhead vert' rowspan=2><div>Test platform</div>" : "")));
        my $prevt = "_";
        foreach my $col (sort keys %{$cols}) {
            my $t = join("\t", map { $cols->{$col}->{$_} } (@{$colkeys}[0..$i]));
            my $s = $cols->{$col}->{$colkeys->[$i]};
            $s =~s/ (\(.*)/<br><small>$1<\/small>/;
            print FILE ($prevt ne $t ? "<th".(exists $colcount->{$t} ? " colspan=".$colcount->{$t} : "")." class='vert".
                ($i==0?" bordertop":"").
                ($i%2==1?" borderbottom":"").
                ($i==0?" platformbase":($i==1?" platformarch":($i==2||$i==3?" build":" test"))).
                ($i==2||$i==4?" hw":($i==3||$i==5?" os":""))."'>".
                "<div>".$s.($i < 2 ? "<br><small>".formattime($coltime->{$t},1)."</small>" : "")."</div>" : "");
            $prevt = $t;
        }
    }

    # Write row headers and cells
    my $prevflag = "_";
    foreach my $row (sort {my ($aa,$bb)=($a,$b);$aa =~s/talos/z\0/;$bb =~s/talos/z\0/; $aa cmp $bb} keys %{$rows}) {
        my ($flag, $task) = ($rows->{$row}->{'flag'}, $rows->{$row}->{'task'});
        my $isbuild = $task=~/build/;
        print FILE "\n<tr>".
            ($prevflag ne $flag ? "<th rowspan=".$rowcount->{$flag}.">".$flag."<th class=num rowspan=".$rowcount->{$flag}.">".formattime($rowtimeflag->{$flag},1) : "").
            "<th".($isbuild?" class=build":"").">".$task."<th colspan=2 class='num ".($isbuild?"build":"")."'>".formattime($rowtime->{$row},1);
        my $prevt = "";
        foreach my $col (sort keys %{$cols}) {
            my ($hw, $os) = ($cols->{$col}->{'hw'}, $cols->{$col}->{'os'});
            my $cell = (exists $cells->{$col."\t".$row} ? $cells->{$col."\t".$row} : 0);
            my $prod = $cols->{$col}->{'product'}."\t".$cols->{$col}->{'productarch'};
            my $b = $flagProductBuild->{$flag}->{$prod};
            my $t = $b && $isbuild ? $prod."\t".$b->{'hw'}."\t".$b->{'os'} : '';
            print FILE ($t ?
                ($t ne $prevt ? "<td colspan=".($colcount->{$t} || 1)." class='num".(($colcount->{$t} || 1)>1?"c":"").($isbuild?" build":"")."'><div class=tip><span>".$b->{'name'}." </span>".formattime($b ? $b->{'time'} : 0)."</div>" : "") :
                ($cell ? "<td class='num".($isbuild?" build":"")."'>".join("", map{"<div class=tip><span>".$_->{'name'}." </span>".formattime($_->{'time'})."</div>"} @{$cell}) : "<td>"));
            $prevt = $t;
        }
        $prevflag = $flag;
    }
    print FILE "\n</table>\n";
}
print FILE "
<p><b>Product</b> corresponds to an installer file, that would be produced by a complete build, and that would be made avaliable for download. That is, multiple archs of the product could exist (e.g. one for windows and one for mac), but one product may also be able to run on multiple platforms (e.g. multiple Windows versions or even multiple hardware architectures as on Mac via universal binaries).
<p><b class=build>Build platform</b> is the hardware and OS used to build the product. Since this might be cross-compiled this platform may not have anything to do with product arch. But to make this simple, it is assumed that a product is compiled on one platform only. This assumtion is used to match up build and test tasks.
<p><b>Test platform</b> is the hardware and OS used to test the product. A build of the product might be tested of multiple platforms (or not at all).
</body></html>";
close FILE;
