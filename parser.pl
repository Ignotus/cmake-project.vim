#!/usr/bin/perl 
use strict;
use warnings;
use Cwd;
use File::Find::Rule;

my $dir = $ARGV[0];
my @builds = File::Find::Rule->file()
                            ->name("build.make")
                            ->in($dir);

my @dependencies = File::Find::Rule->file()
                            ->name("DependInfo.cmake")
                            ->in($dir);
my @accum = ();

foreach my $filename(@dependencies) {
    open(FILE, $filename);
    my @data = <FILE>;
    push (@accum, cppfiles(\@data));
    close(FILE);
}

foreach my $filename(@builds) {
    open(FILE, $filename);
    my @data = <FILE>;
    push(@accum, headerfiles(\@data));
    close(FILE);
}

foreach my $pair(@accum) {
    print $pair->{'dir'} . " " . $pair->{'file'} . "\n";
}

sub headerfiles {
     my @result = ();
    foreach my $line(@{(shift)}) {
        if ($line =~ m/((([a-zA-Z_\/]+)\/)?[a-zA-Z_]+\.(h|hpp)):.*/) {
            push(@result, { 'dir' => getcwd . "/" . $dir, 'file' => $1});
        }
    }
    return @result;
   
}

sub cppfiles {
    my @result = ();
    foreach my $line(@{(shift)}) {
        if ($line =~ m/\s*\"([a-zA-Z_\/]+)\/([a-zA-Z_]+\.(cpp|cc)).*/) {
            push(@result, { 'dir' => $1, 'file' => $2});
        }
    }
    return @result;
}

