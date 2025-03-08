#!/usr/bin/perl
use strict;
use warnings;

# File path for input and output
my $input_file = '/home/jsp/SnPbTe_alloys/dp_train_new/initial/Sn15Pb17Te32-T300-P0/Sn15Pb17Te32-T300-P0.in';
my $output_file = 'modified_Sn15Pb17Te32-T300-P0.in';

# Open the input file for reading
open my $in, '<', $input_file or die "Cannot open file $input_file: $!";

# Open the output file for writing
open my $out, '>', $output_file or die "Cannot open file $output_file: $!";

# Initialize counters for atom types 1 and 2
my $type1_count = 0;
my $type2_count = 0;

# Read through each line in the input file
while (my $line = <$in>) {
    # If the line contains atom data, we need to process it
    if ($line =~ /^\d+\s+[1-3]\s+/) {
        # Split the line by whitespace
        my @fields = split(/\s+/, $line);
        
        # Count the number of type 1 and type 2 atoms
        if ($fields[1] == 1) {
            $type1_count++;
        } elsif ($fields[1] == 2) {
            $type2_count++;
        }
    }
    else {
        # For all other lines, just print them as is
        print $out $line;
    }
}

# Now we know how many type 1 and type 2 atoms there are.
my $current_type1 = 1;
my $current_type2 = 2;
my $type1_limit = $type1_count;
my $type2_limit = $type2_count;

# Go back to the beginning of the file and modify atom types
seek($in, 0, 0);

while (my $line = <$in>) {
    # If the line contains atom data, we need to process it
    if ($line =~ /^\d+\s+[1-3]\s+/) {
        # Split the line by whitespace
        my @fields = split(/\s+/, $line);
        
        # Keep the original number of atoms for type 1 and type 2
        if ($fields[1] == 1) {
            # If it's type 1, make it type 2 if there are still type 2 atoms left
            if ($current_type2 <= $type2_limit) {
                $fields[1] = 2;
                $current_type2++;
            }
        }
        elsif ($fields[1] == 2) {
            # If it's type 2, make it type 1 if there are still type 1 atoms left
            if ($current_type1 <= $type1_limit) {
                $fields[1] = 1;
                $current_type1++;
            }
        }
        
        # Join the fields back together and write to the output file
        print $out join(' ', @fields) . "\n";
    }
    else {
        # For all other lines, just print them as is
        print $out $line;
    }
}

# Close the files
close $in;
close $out;

print "Atom types 1 and 2 have been switched while keeping their original counts, and saved to $output_file.\n";
