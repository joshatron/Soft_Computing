#!/usr/bin/perl

###################################
#          CSV2ARFF 1.1           #
###################################

# Print program description and exit if file path was not specified
if (length(@ARGV) == 0 || length($ARGV[0]) == 0) {
    help();
    die "Missing file path argument.\n";
}

$filename = $ARGV[0];           # Get file path

$relation = $filename;          # Default relation name will be the file name
$relation =~ s/\.\S*//;         # Remove file extension

$newfile = "$relation.arff";    # New file name

# Try opening input file, exit on failure
open(INFILE, '<', $filename) or die "File read failed on: $filename\n";

@data_in = <INFILE>;            # Get data from file
close INFILE;                   # Close file

$sampleString = $data_in[0];    # Use first line to determine data types
$substring = $sampleString;     # Remove comma separated entries sequentially from substring

$count = 0;                     # Number of entries processed
@attributes;                    # Attribute section of final ARFF

do {
    $name = "A$count";          # Default name of attribute is A{entry_number}

    $replace = $substring;      # Get the next entry
    $replace =~ s/,.*//;        # Remove all other entries
    
    # If current entry does not contain letters or punctuation (except for one '.' or '-'),
    # then attribute is numeric.
    if ($replace !~ m/[\x20-\x2C]+|[\x3A-\x7E]+|-{2,}|\.{2,}/) {
        $attributes[$count] = "\@attribute $name numeric\n";
        
    # Else if current entry looks like a possible date/time entry, ask user to identify the
    # entry as a date or string and specify the date's format.
    } elsif ($replace =~ m/((\d{2,4})[\-\:\.\/]{1}(\d{2})[\-\:\.\/]{1}(\d{2,4}))/) {
    
        print("\n\nFound possible date/time. Is this entry a date or time? (y/n):\n");
        print("$replace\n");
               
        $in = <STDIN>;
        chomp($in);
        
        if ($in =~ m/y|Y/) {
            print("Please select one of the following options:\n");
            print("1 - default (ISO-8601) date & time format: yyyy-MM-dd\'T\'HH:mm:ss\n");
            print("2 - customize date/time format (e.g. dd-MM-yyyy HH:mm)\n");
            print("or any other key to interpret entry as a string:\n");
            $in = <STDIN>;
            chomp($in);
            if ($in =~ m/1/) {
                $attributes[$count] = "\@attribute $name date \"yyyy-MM-dd\'T\'HH:mm:ss\"\n";
            } elsif ($in =~ m/2/) {
                print("For valid date formats, see javadoc for java.text.SimpleDateFormat.\n");
                print("Please enter the date format:\n");
                $in = <STDIN>;
                chomp($in);
                $attributes[$count] = "\@attribute $name date \"$in\"\n";
            } else {
                $attributes[$count] = "\@attribute $name string\n";
            }
        } else {
            $attributes[$count] = "\@attribute $name string\n";
        }
        print("\n");
        
    # Else, assume the attribute is a string.
    } else {
        $attributes[$count] = "\@attribute $name string\n";
    }
    
    $count++;
    $substring = substr($substring, length($replace));
    
} while ($sampleString =~ /,/g);    # Loop until we run out of commas

$index = 0; # Index for output data array
@data_out;  # data section output

# Loop through every line retrieved from input file
foreach $substring (@data_in) {
    $substring =~ s/\s+$//; # Remove trailing whitespace
    $nextLine = "";         # Build on this string for output
    
    # Iterate through every attribute in this line
    for ($i = 0; $i < $count; $i++) {
        
        $replace = $substring;  # Get the next entry
        $replace =~ s/,.*$//;   # Remove all other entries
        
        # If current entry is numeric, concatenate it to the output string
        if ($replace !~ m/[\x20-\x2C]+|[\x3A-\x7E]+|-{2,}/) {
            $nextLine = "$nextLine,$replace";
            
        # Else, add quotes to the entry to ensure entry follows ARFF requirements
        } else {
            $nextLine = "$nextLine,\"$replace\"";
        }
        
        $substring =~ s/^[^,]+,//;  # Remove current entry from substring
    }
    
    $nextLine =~ s/^,//;                # Remove leading comma in the output string
    $data_out[$index] = "$nextLine\n";  # Store output string in output array
    $index++;
}

print("\nBasic ARFF ready for file write.\n\n");

@header = ();   # Array for possible header info

$quit = 0;      # quit != 0 iff user does not select an option
while ($quit == 0) {
    print("Please enter additional options or any other key to write the ARFF and exit:\n");
    print("0 - Exit program without writing new ARFF file\n");
    print("1 - Change names of the relation and attributes\n");
    print("2 - Change an attribute's data type to NOMINAL and rename it\n");
    print("3 - Change an attribute's data type to DATE and rename it\n");
    print("4 - Change an attribute's data type to STRING and rename it\n");
    print("5 - Change an attribute's data type to NUMERIC and rename it\n");
    print("6 - Create or load a header\n");
    print("7 - Change output file path\n");
    
    $in = <STDIN>;
    chomp($in);
    
    if ($in =~ m/0/) {      # Exit program without writing new ARFF file
        exit;
    } elsif ($in =~ m/1/) { # Change names of the relation and attributes
        name();
    } elsif ($in =~ m/2/) { # Change an attribute's data type to NOMINAL
        nominal();
    } elsif ($in =~ m/3/) { # Change an attribute's data type to DATE
        date();
    } elsif ($in =~ m/4/) { # Change an attribute's data type to STRING
        string();
    } elsif ($in =~ m/5/) { # Change an attribute's data type to NUMERIC
        numeric();
    } elsif ($in =~ m/6/) { # Create or load a header
        header();
    } elsif ($in =~ m/7/) { # Change file name/path
        print("\nEnter a new name for the file ending with .arff extension: \n");
        $newFile = <STDIN>;
        chomp($newFile);
    } else {
        $quit++;            # Write file, then exit the program
    }
}
# Try to open output file in pwd
open(OUTFILE, '>', $newfile) or die "File write failed on: $newfile\n";

# Print the header to the file if a header was created
if (length(@header) > 0) {
    print OUTFILE @header;
}

# Print the relation's name
print OUTFILE "\@relation $relation\n\n";
# Print the relation's attributes
print OUTFILE @attributes;
# Print the relation's data
print OUTFILE "\n\@data\n";
print OUTFILE @data_out;
# Close the file
close OUTFILE;

print("\nNew ARFF created successfully: $newfile\n\n");
# Exit program
exit;



# Enable user to set the attribute-type of a column to DATE
sub date() {
    # Specify column number
    print("\nEnter column number of date attribute (0-n):\n");
    $in = <STDIN>;
    chomp($in);
    $column = $in;
    
    # Optionally rename the attribute
    print("\nPlease enter a name for the attribute, or nothing to cancel:\n");
    $in = <STDIN>;
    chomp($in);
    $name = $in;
    
    # If no name provided, revert to default name
    if ($name !~ m/\S/) {
        print("\nAttribute change cancelled.\n\n");
        return;
    } 
    
    print("Please select one of the following options:\n");
    print("1 - default (ISO-8601) date & time format: yyyy-MM-dd\'T\'HH:mm:ss\n");
    print("2 - customize date/time format (e.g. dd-MM-yyyy HH:mm)\n");
    print("or enter any other key to set attribute as a string:\n");
    $in = <STDIN>;
    chomp($in);
    # If a 1 was entered somewhere, default to ISO-8601 date/time format
    if ($in =~ m/1/) {
        $attributes[$column] = "\@attribute $name date \"yyyy-MM-dd\'T\'HH:mm:ss\"\n";
    # Else if a 2 was entered somewhere, let user set the date/time format
    } elsif ($in =~ m/2/) {
        print("For valid date formats, see javadoc for java.text.SimpleDateFormat.\n");
        print("Please enter the date format:\n");
        $in = <STDIN>;
        chomp($in);
        $attributes[$column] = "\@attribute \"$name\" date \"$in\"\n";
    # Default to string
    } else {
        $attributes[$column] = "\@attribute \"$name\" string\n";
    }
    print("\nAttribute changed to:\n$attributes[$column]\n\n");
}

# Enable user to set the attribute-type of a column to NOMINAL
sub nominal() {
    # Specify column number
    print("Enter column number of nominal attribute (0-n):\n");
    $in = <STDIN>;
    chomp($in);
    $column = int($in);
    
    print("Selected: $attributes[$column]\n");
    
    # Optionally rename the attribute
    print("\nPlease enter a name for the attribute, or nothing to cancel:\n");
    $in = <STDIN>;
    chomp($in);
    $name = $in;
    if ($name !~ m/\S/) {
        print("\nAttribute change cancelled.\n\n");
        return;
    }
    print("Enter every nominal-name separated by commas:\n");
    print("(e.g. name-1,name 2,name3,...,name-last):\n");
    $nominals = <STDIN>;
    chomp($nominals);
    $nominals =~ s/(\s*,\s*)/\",\"/g;
    $attributes[$column] = "\@attribute \"$name\" {\"$nominals\"}\n";
    print("\nAttribute changed to:\n$attributes[$column]\n\n");
}

# Enable user to set the attribute-type of a column to STRING
sub string() {
    # Specify column number
    print("Enter column number of the attribute (0-n):\n");
    $in = <STDIN>;
    chomp($in);
    $column = int($in);
    
    print("Selected: $attributes[$column]\n");
    
    # Optionally rename the attribute
    print("\nPlease enter a name for the attribute, or nothing to cancel:\n");
    $in = <STDIN>;
    chomp($in);
    $name = $in;
    if ($name !~ m/\S/) {
        print("\nAttribute change cancelled.\n\n");
        return;
    }
    
    $attributes[$column] = "\@attribute \"$name\" string\n";
    print("\nAttribute changed to:\n$attributes[$column]\n\n");
}

# Enable user to set the attribute-type of a column to NUMERIC
sub numeric() {
    # Specify column number
    print("Enter column number of the attribute (0-n):\n");
    $in = <STDIN>;
    chomp($in);
    $column = int($in);
    
    print("Selected: $attributes[$column]\n");
    
    # Optionally rename the attribute
    print("\nPlease enter a name for the attribute, or nothing to cancel:\n");
    $in = <STDIN>;
    chomp($in);
    $name = $in;
    if ($name !~ m/\S/) {
        print("\nAttribute change cancelled.\n\n");
        return;
    }
    
    $attributes[$column] = "\@attribute \"$name\" numeric\n";
    print("\nAttribute changed to:\n$attributes[$column]\n\n");
}

# Enable user to set the names of each attribute
sub name() {
    # Specify name of the relation
    print("\nName of the relation: $relation\n");
    print("Rename? (y/n) ");
    $in = <STDIN>;
    chomp($in);
    # Change the relation if 'y' was entered
    if ($in =~ m/y|Y/) {
        print("Please enter a new name for the relation: \n");
        $in = <STDIN>;
        chomp($in);
        $relation = "\"$in\"";
    }
    
    @newAttributes; # Array for new attributes
    $index = 0;     # Index for new attribute array
    
    # Iterate through current attributes, renaming them if the user chooses to
    foreach $line (@attributes) {
        print("\n$line");
        print("Rename? (y/n) ");
        $in = <STDIN>;
        chomp($in);
        if ($in =~ m/y|Y/) {
            print("New attribute name: ");
            $in = <STDIN>;
            chomp($in);
            $line =~ s/^(\@attribute\s\"?\w+\"?\s)//;
            $newAttributes[$index] = "\@attribute \"$in\" $line";
        } else {
            $newAttributes[$index] = $line;
        }
        
        $index++;
    }
    
    @attributes = @newAttributes;   # Update attributes
    print("\n\nRelation/attribute names updated successfully\n\n");
}

# Enable user to create a header for the ARFF
sub header() {
    print("\nPlease enter file path of the file containing header info, or\n");
    print("enter nothing to create a header line-by-line:\n");
    $in = <STDIN>;
    chomp($in);
    
    # User wants to do it the hard way...
    if ($in !~ m/\S/) {
        print("Enter the header line-by-line:\n");
        $in = <STDIN>;
        chomp($in);
        $count = 0;
        while($in =~ m/\S/) {
            $header[$count] = "\% $in\n";
            
            $in = <STDIN>;
            chomp($in);
            $count++;
        }
        
    # User has a .info or similar file, just load that into the header
    } else {
        $opened = open(INFILE, '<', $in);
        unless ($opened) {
            print("File read failed on: $in\n\n");
            return;
        }
        $count = 0;
        foreach $line (<INFILE>) {
            chomp($line);
            $header[$count] = "\% $line\n";
            $count++;
        }
    }
    
    print("\nHeader updated successfully\n\n");
}

# Print program info
sub help() {
    print "csv2arff, version 1.1\n";
    print "  Creates an ARFF file from a CSV. The resulting ARFF receives the\n";
    print "  name of the input CSV with any extension changed to <.arff>.\n";
    print "         USE: ~\$ perl csv2arff.pl <csv_file_path>\n\n";
}
