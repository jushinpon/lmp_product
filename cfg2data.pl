#!/usr/bin/perl

use warnings;
use strict;
use List::Util qw(min max);
use Cwd;
use Parallel::ForkManager;

my $currentPath = getcwd();
my $forkNo = 4;  # Adjust parallel execution settings as needed
my $pm = Parallel::ForkManager->new($forkNo);

# Collect all CFG files (fix for missing -exec argument issue)
my @cfg_files = map { chomp; $_ } `find ./ -type f -name "*.cfg"`;
@cfg_files = sort @cfg_files;

# Process each CFG file
foreach my $cfg (@cfg_files) {
    my $pid = $pm->start and next;
    
    my $basename = `basename "$cfg"`;
    my $dirname = `dirname "$cfg"`;
    chomp ($basename, $dirname);
    $basename =~ s/\.cfg$//;
    
    my $data_file = "$dirname/$basename.data";
    
    # Extract box bounds
    my ($xlo_bound, $xhi_bound, $xy) = split /\s+/, `awk '/ITEM: BOX BOUNDS/{getline; print}' "$cfg" | head -1`;
    my ($ylo_bound, $yhi_bound, $xz) = split /\s+/, `awk '/ITEM: BOX BOUNDS/{getline; getline; print}' "$cfg" | head -1`;
    my ($zlo_bound, $zhi_bound, $yz) = split /\s+/, `awk '/ITEM: BOX BOUNDS/{getline; getline; getline; print}' "$cfg" | head -1`;
    
    chomp ($xlo_bound, $xhi_bound, $xy, $ylo_bound, $yhi_bound, $xz, $zlo_bound, $zhi_bound, $yz);
    
    $xy ||= 0.0;
    $xz ||= 0.0;
    $yz ||= 0.0;
    
    my $xlo = $xlo_bound - min(0.0, $xy, $xz, ($xy + $xz));
    my $xhi = $xhi_bound - max(0.0, $xy, $xz, ($xy + $xz));
    my $ylo = $ylo_bound - min(0.0, $yz);
    my $yhi = $yhi_bound - max(0.0, $yz);
    my $lx = sprintf("%.6f", $xhi - $xlo);
    my $ly = sprintf("%.6f", $yhi - $ylo);
    my $lz = sprintf("%.6f", $zhi_bound - $zlo_bound);

    # Extract atomic positions and types
    my @atoms = `awk '/ITEM: ATOMS/{found=1; next} found {print}' "$cfg"`;
    chomp @atoms;

    my @elements;
    my @positions;

    foreach my $line (@atoms) {
        my @data = split /\s+/, $line;
        push @elements, $data[1]; # Adjust this index based on actual format
        push @positions, "$data[2] $data[3] $data[4]";
    }

    my %element_ids;
    my $id = 1;
    foreach my $element (sort keys %{{ map { $_ => 1 } @elements }}) {
        $element_ids{$element} = $id++;
    }
    
    # Write LAMMPS data file
    open(my $fh, '>', $data_file) or die "Could not open file '$data_file' $!";
    print $fh "# LAMMPS data file from CFG: $basename.cfg\n\n";
    print $fh scalar(@positions) . " atoms\n";
    print $fh scalar(keys %element_ids) . " atom types\n\n";
    print $fh "$xlo $xhi xlo xhi\n";
    print $fh "$ylo $yhi ylo yhi\n";
    print $fh "$zlo_bound $zhi_bound zlo zhi\n";
    print $fh "$xy $xz $yz xy xz yz\n\n" if ($xy || $xz || $yz);
    
    print $fh "Masses\n\n";
    foreach my $elem (sort keys %element_ids) {
        print $fh "$element_ids{$elem} 1.0 # $elem\n";
    }
    
    print $fh "\nAtoms\n\n";
    for my $i (0..$#positions) {
        print $fh ($i+1) . " $element_ids{$elements[$i]} $positions[$i]\n";
    }
    close $fh;
    
    print "Converted $cfg to $data_file\n";
    
    $pm->finish;
}
$pm->wait_all_children;

print "Conversion completed!\n";