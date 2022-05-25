#!/bin/perl

use 5.30.0;
use strict;
use warnings;
use Time::Piece;
use Number::Bytes::Human ('format_bytes');

my @files = ();
Time::Piece->use_locale();
if(@ARGV && $ARGV[-1] eq '-' ){
    while (<>){
        chomp;
        #say "Entry:[$_]";
        push @files, $_
    }
}else{
    print "Please $0 with '-' as argument to pipe in your list of files.";
    printHelp();
    exit 0;
}

my %name = ( oct(70) => 'RWX',
             oct(60) => 'RW ',
             oct(50) => 'RX ',
             oct(30) => 'WX ',
             oct(20) => 'W  ',
             oct(10) => 'X  ',
             oct(40) => 'R  ',
           );
my @modes = reverse(oct(40), oct(10), oct(20), oct(30), oct(50), oct(60), oct(70));


foreach(@files){
    my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime,
   $ctime, $blksize, $blocks) = stat $_; 
   $size  = format_bytes($size);
   $mtime = localtime($mtime)->strftime("%Y-%M-%dT%H:%M");#ISO 8601 standard
   my $smode = $mode;  $smode &= oct(70);
   for my $mode (@modes) {
        $smode = $name{$mode} and last if ($smode & $mode) == $mode;
    }

   say "$size\t$mtime [$smode]\t$_"
}

sub printHelp {while(<DATA>){print $_} return }
__END__

--------------------------------------------------------------------------------------------------------------
List Files 

This program is just an example script listing files piped.
To produce a list in human readable format.

Example Usage:

find ~ -iname *.doc  | ./listFiles.pl -
find ~ -type f \( -iname "*.jpg" -o -name "*.png" \) | ./listFiles.pl -
# Much faster alternative to find files (~/.local/bin/fd -> /usr/bin/fdfind):
fd . ~ -tf -e jpg -e png | ./listFiles.pl -
# db based fastes is to use locate.
locate "*/$USER/*.doc" | ./listFiles.pl -

--------------------------------------------------------------------------------------------------------------
By: Will Budic
Open Source License -> https://choosealicense.com/licenses/isc/
# This file originated from https://github.com/wbudic/B_L_R_via_sshfs
