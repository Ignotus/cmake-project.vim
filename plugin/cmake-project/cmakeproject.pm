package cmakeproject;
our $version = '0.1';
use File::Find::Rule;
use Cwd;

sub cmake_project_files {
    my $dir = shift;

    my @dependencies = File::Find::Rule->file()
                                    ->name("DependInfo.cmake")
                                    ->in($dir);
    my @accum = ();

    foreach my $filename(@dependencies) {
        open(FILE, $filename);
        my @data = <FILE>;
        push (@accum, src_files(\@data));
        close(FILE);
    }

    return @accum;
}

sub src_files {
    my @result = ();
    foreach my $line(@{(shift)}) {
        if ($line =~ m/\s*\"([a-zA-Z_\/]+)\/([a-zA-Z_]+\.(cpp|cc)).*/) {
            push(@result, { 'dir' => $1, 'file' => $2});
        }
    }
    return @result;
}

1;
