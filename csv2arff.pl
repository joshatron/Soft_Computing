if (length(@ARGV) == 0) {
    die "Missing file path argument. Use <perl csv2arff.pl -h> for more info.\n";
}
$filename = $ARGV[0];

$relation = $filename;
$relation =~ s/\.\S*//;

$newfile = "$relation.arff";

open(INFILE, '<', $filename) or die "File read failed on: $filename\n";
@data_in = <INFILE>;
close INFILE;

$sampleString = $data_in[0];
$substring = $sampleString;

$count = 0;
@attributes;
do {
    $name = "A$count";

    $replace = $substring;
    $replace =~ s/,.*//;
    
    if ($replace !~ m/[\x20-\x2C]+|[\x3A-\x7E]+|-{2,}/) {
        $attributes[$count] = "\@attribute $name numeric\n";
    } elsif ($replace =~ m/((\d{2,4})[\-\:\.\/]{1}(\d{2})[\-\:\.\/]{1}(\d{2,4}))/) {
        
        $char1 = $replace;
        $char1 =~ s/^\d+//;
        $char1 = substr($char1,0,1);
        $char2 = $replace;
        $char3 = $replace;
        if ($char2 =~ m/t|T/) {
            $char2 = '\'T\'';
        } else {
            $char2 = ' ';
        }
        
        
        
        if ($replace =~ m/(\d{4})[\-\:\.\/]{1}([\d\-\:\.\/]){5}[tT\s]{1}([\d\-\:\.\/]){8}\s*$/) {
            $attributes[$count] = "\@attribute $name date \"yyyy$char1".'MM'.$char1.'dd'.$char2.'HH:mm:ss"'."\n";
        } elsif ($replace =~ m/([\d\-\:\.\/]{6})(\d){4}[tT\s]{1}([\d\-\:\.\/]){8}\s*$/) {
            $attributes[$count] = "\@attribute $name date \"dd$char1".'dd'.$char1.'yyyy'.$char2.'HH:mm:ss"'."\n";
        } else {
            $date = $replace;
            $date_format = "";
            $lastChar = "-1";
            for ($i = 0; $i < length($replace); $i++) {
                $char = substr($date,0,1);
                
                if ($char =~ m/\d/) {
                    $date_format = $date_format . "y";
                } else {
                    $date_format = $date_format . $char;
                }
                $date = substr($date,1);
                $lastChar = $char;
            }
            $date_format =~ s/\s+$//;
            $date_format =~ s/t|T/\'T\'/;
            $attributes[$count] = "\@attribute $name date \"$date_format\"\n";
        }
    } else {
        $attributes[$count] = "\@attribute $name string\n";
    }
    
    $count++;
    $substring = substr($substring, length($replace));
    
} while ($sampleString =~ /,/g);

$index = 0;
@data_out;
foreach $substring (@data_in) {
    $substring =~ s/\s+$//;
    $nextLine = "";
    for ($i = 0; $i < $count; $i++) {
        
        $replace = $substring;
        $replace =~ s/,.*$//;
        
        if ($replace !~ m/[\x20-\x2C]+|[\x3A-\x7E]+|-{2,}/) {
            $nextLine = "$nextLine,$replace";
        } else {
            $nextLine = "$nextLine,\"$replace\"";
        }
        
        $substring =~ s/^[^,]+,//;
    }
    $nextLine =~ s/^,//;
    $data_out[$index] = "$nextLine\n";
    $index++;
}


open(OUTFILE, '>', $newfile) or die "File write failed on: $newfile\n";

print OUTFILE "\@relation $relation\n\n";
print OUTFILE @attributes;
print OUTFILE "\n\@data\n";
print OUTFILE @data_out;

close OUTFILE;

sub help() {
    print "csv2arff, version 1.0\n";
    print "  Creates an ARFF file from a CSV. The resulting ARFF receives the\n";
    print "  name of the input CSV with any extension changed to <.arff>.\n";
    print "         USE: ~\$ perl csv2arff.pl <csv_file_path>\n\n";
}
