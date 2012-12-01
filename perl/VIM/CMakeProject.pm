# vim-cmake-project
# Copyright (C) 2012 Minh Ngo <nlminhtl@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
package VIM::CMakeProject;
our $version = '1.0.0';
use File::Find::Rule;
use Cwd qw(abs_path cwd);
use List::MoreUtils qw(uniq);

sub cmake_project_files {
    my $dir = shift;

    my @dependencies = File::Find::Rule->file()
                                    ->name("DependInfo.cmake")
                                    ->in($dir);
    my @internals = File::Find::Rule->file()
                                    -> name("depend.internal")
                                    ->in($dir);
    my @accum = ();

    foreach my $filename(@dependencies) {
        push @accum, src_files($filename);
    }

    my $currentdir = abs_path(cwd());
    foreach my $filename(@internals) {
        push @accum, header_files($filename, $currentdir);
    }

    return sort(uniq @accum);
}

sub header_files {
    my @result = ();
    
    my ($file, $currentdir) = @_;
    open(FILE, $file);
 
    while (<FILE>) {
        if ($_ =~ m/\s*(([a-zA-Z0-9_\/\-. ]+)\/([a-zA-Z0-9_\/\- ]+\.(hpp|h)))$/) {
            my $abs = abs_path($1);
            if (index($abs, $currentdir) != -1) {
                push @result, $abs; 
            }
        }
    }

    return @result;
}


sub src_files {
    my @result = ();
    open(FILE, shift);
    while (<FILE>) {
        if ($_ =~ m/\s*\"(([a-zA-Z0-9_\/\- ]+)\/([a-zA-Z0-9_\/\- ]+\.(cpp|cc|c))).*/) {
            push @result, $1;
        }
    }
    return @result;
}

1;
