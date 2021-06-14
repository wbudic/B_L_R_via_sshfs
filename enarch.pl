#!/bin/perl
use 5.010;
use strict;

my ($gpgpass,$target,$name,$archive,$action,$postfix,$fuzzy,$showfull);
my $host   =`uname -n`;
my $date   = `date "+%Y%m%d"`;
my $ext    = 'tar.gz.enc';
my @paths  = ();
my @DIGITS = "1234567890ABCDEFGHIJKLMWENCARCHIVE" =~ m/./g;


foreach my $a(@ARGV){
    if($a =~ m/~/g)       {print "Error: Directory substitution is not permited. Use full paths please!\n"; exit 0;}    
    elsif($a =~ m/^-+.*(pass)/i)        {$gpgpass = gpgPassCodeCheck($a)}
    elsif($a =~ m/^-+.*(generate)/i)    {print "New gpg passcode: ", gpgPassCodeGenerate(), "\n";exit 1;}
    elsif($a =~ m/^-+.*(target)/i)      {$target = $a; $target =~ s/^-+.*=//;}
    elsif($a =~ m/^-+.*(name)/i)        {$name = $a; $name =~ s/^-+.*=//;}
    elsif($a =~ m/^-+.*(list)/i)        {$action='LIST'; $a=~ s/^-+.*=//g; $showfull=1 if $a eq 'full'}
    elsif($a =~ m/^-+.*(fuzzy)|(fzf)/i) {$action='LIST';$fuzzy=1; $a=~ s/^-+.*=//g; $showfull=1 if $a eq 'full'}
    elsif($a =~ m/^-+.*(restore)/i)     {$action='RESTORE'}
    elsif($a =~ m/^-+h|\?/i)            {&help; $action='HELP' if !$action}
    elsif($a =~ m/^-+.*(postfixid)/i)   {$postfix = $a; $postfix =~ s/^-+.*=//; $postfix =
     0 if $postfix =~ /^of+/ || $postfix =~ /^0/}
    elsif($a !~ m/^-+/){                        
        if(-d $a){           
            if (!$target) {
                 $target = $a; next;
            }else{
                if($a eq $ENV{HOME}){print "Error: Can't archive own home diectory!: $a\n"; exit 0;};
                if($action && $action ne 'ARCHIVE'){
                    print "Error: Can't archive if previous action issued!: $action\n"; exit 0;
                }
                $action='ARCHIVE';
                push @paths, $a;  next;
            }
        }{
            print "Error: Directory path specified is not a valid directory: [$a]\n"; exit 0;
        }
    }
    elsif($a =~ m/^-+restore/i) {$action='RESTORE'}
    else{
         print "Error: Don't understand argument: [$a]\n"; exit 0;
    }    
}

if($action ne 'HELP'){
    if(!$target){
        print "Error: Target directory not specified!\n"; exit 0;
    }
    if(!$name){
        print "Error: Target archive name not specified!\n"; exit 0;
    }
    $target =~ s/\/$//; $host =~ s/\s//;$date =~ s/\s//;
    if($postfix == 1 || $postfix eq 'on'){$postfix="-".&rc}
    $archive = "$target/$host-$name-$date$postfix.$ext";
}

if($action    eq 'ARCHIVE'){&archive;}
elsif($action eq 'RESTORE'){&restore;}
elsif($action eq 'LIST'){&list;}
else{
    print "No action to perform detected.\n";
}


sub archive {
    print "Generating archive: $archive\n";
    print "Passcode: $gpgpass\n";
    system("tar -cvzi " .join(' ', @paths)." | gpg -c --no-symkey-cache --batch --passphrase $gpgpass > $archive 2>&1");
    print "Done generating: $archive\n";
}
sub list {
    #Let's try to find the most current, so with passcode also matches.
    if($postfix && $postfix ne 'off'){
        $archive = "$target/$host-$name-*$postfix.$ext";

    }else{
        $archive = "$target/$host-$name-$date*.$ext";
    }
    my @lst=`ls -c  $archive`;
    $archive = $lst[0];
    $archive =~ s/\s//g;  
    if(-d $archive){
        die "Archive not found: $archive";
    }
    if ($showfull) {$showfull="tvz"}else{$showfull="tz"}
    if ($fuzzy){$fuzzy = "$showfull | fzf --multi --no-sort --sync"}else{$fuzzy = $showfull};
    system("/usr/bin/gpg --no-verbose --decrypt --batch --passphrase $gpgpass $archive | tar $fuzzy 2>&1");    
    print "Listed archive: $archive\n";
}
sub restore {
  system("gpg --decrypt --batch --passphrase $gpgpass $target | tar xvz");
}

sub gpgPassCodeGenerate {
    my $code = "";    
    foreach(1..8){$code .= &rc . '-'}
    $code =~ s/(-$)//;
    return $code;
}sub rc {sprintf ("%s%s", $DIGITS[rand(28)], $DIGITS[rand(28)]);}

sub gpgPassCodeCheck {
    my ($arg, $pass) = @_;
    $arg =~ s/^-+.*pas.+=//;
    $arg = uc $arg;
    if($arg =~ m/(..)-(..)-(..)-(..)-(..)-(..)-(..)-(..)/g){
        my @g = split /[.!-]?/, $arg;
        foreach my $c(@g){            
            $pass=0; #We assume EACH next of it will fail.            
            foreach my $d(@DIGITS){
                if($d eq $c){
                    $pass = 1;
                    last;
                }
            }
            if(!$pass){
                last;
            }
        }    
    }
    if(!$pass){
        print "Error: Invalid GPG passcode format: [$arg]\n";
        exit;
    }
    return $arg;    
}
sub help {
    foreach(<DATA>){print $_}
}
__END__
--------------------------------------------------------------------------------------------------------------
Encode Archive Directories

Options:

-target=path   - Target path directory, if not speciefied first encountered will become.
-name=idn      - Compulsary, indentifier name for the archive.
-ggpgass=code  - Compulsary, GPG encryption/decryption passcode for the archive.
-ggpgenerate   - New GPG passcode, generator.
-list=full     - List contents of desired target named archive, if gpgpass argument provided is valid.
                 If set to full (default) will give full file stats, if set to path only the path.
-fuzzy         - Same as list contents but to fzf utility.
-restore       - Restores into current directory target archive, if gpgpass argument provided is valid.
-postfixid=off - Default is off, when on or set will create a unique archive at destination, with postfix to name.

-h/? - This help file.

Syntax:

Archive is generated from the -name argument and only send to a target path not included in the archive.
The -ggpgass argument must be given:

$ enarch -ggpgass='XX-XX-XX-XX-XX-XX' -name="archive name" target/path /paths/{...}
$ enarch -ggpgass='XX-XX-XX-XX-XX-XX' -postfix=off -name="archive name" -target=/path /paths {...}

To generate an random gpg passcode use (store this one in a safe place):
$ enarch -gpggenerate

To list an archive:

$ enarch -ggpgass='XX-XX-XX-XX-XX-XX' -list -name="archive name" -target=/path /paths {...}

--------------------------------------------------------------------------------------------------------------

