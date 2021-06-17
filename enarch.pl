#!/bin/perl
use strict;

my ($gpgpass,$target,$name,$archive,$action,$postfix,$fuzzy,$showfull,$cocoon);
my $host   =`uname -n`;
my $date   = `date "+%Y%m%d"`;
my $ext    = 'tar.gz.enc';
my %paths  = ();
my %exclds = ();
my %curr   = ();
my @DIGITS = "1234567890ABCDEFGHIJKLMWENCARCHIVE" =~ m/./g;
my $DEBUG  = 0;

foreach my $a (@ARGV){
    my $v = $a; $v =~ s/^-+.*=//;
    print "[$a]->$v\n" if $DEBUG;
    if($a =~ m/~/g){print "Error: Directory substitution is not permited. Use full paths please!\n"; exit 2;}    
    elsif($a =~ m/^-+.*(pass)/i)        {$gpgpass = gpgPassCodeCheck($a)}
    elsif($a =~ m/^-+.*(generate)/i)    {print "New gpg passcode: ", gpgPassCodeGenerate(), "\n";exit 1;}
    elsif($a =~ m/^-+.*(target)/i)      {$paths{$target} = $target if $target; $target = $v;}
    elsif($a =~ m/^-+.*(name)/i)        {$name = $v;}
    elsif($a =~ m/^-+.*(cocoon)/i)      {$action='ARCHIVE' if !$action; $cocoon=$v;next}    
    elsif($a =~ m/^-+.*(list)/i)        {$action='LIST'; $showfull=1 if $v eq 'full'}
    elsif($a =~ m/^-+.*(fuzzy)|(fzf)/i) {$action='LIST'; $fuzzy=1; $showfull=1 if $v eq 'full'}
    elsif($a =~ m/^-+.*(restore)/i)     {$action='RESTORE'}
    elsif($a =~ m/^-+h|\?/i)            {$action='HELP' if !$action; &printHelp;}
    elsif($a =~ m/^-+.*(postfix)/i)     {$postfix = $v; $postfix =0 if $postfix =~ /^of+/ || $postfix =~ /^0/}
    elsif($a =~ m/^-+.*(ex)/i)          {$exclds{"--exclude=$v"}=$v}    
    elsif($a =~ m/^-+.*(cur)|(f)/i)     {$curr{"$v"}=$v}
    elsif($a !~ m/^-+/){                        
        if(-d $a){           
            if (!$target) {
                 $target = $a; next;
            }else{
                if($a eq $ENV{HOME}){print "Error: Can't archive own home diectory!: $a\n"; exit 2;};
                if($action && $action ne 'ARCHIVE'){
                    print "Error: Can't archive if previous action issued!: $action\n"; exit 2;
                }
                $action='ARCHIVE';
                $paths{$a}=$a;  next;
            }
        }{
            print "Error: Directory path specified is not a valid directory: [$a]\n"; exit 2;
        }
    }
    elsif($a =~ m/^-+restore/i) {$action='RESTORE'}
    else{
         print "Error: Don't understand argument: [$a]\n"; exit 2;
    }    
}

if($cocoon){&cocoon; exit 1;}
elsif($action ne 'HELP'){
    if(!$target){
        print "Error: Target directory not specified!\n"; exit 2;
    }
    if(!$name){
        print "Error: Target archive name not specified!\n"; exit 2;
    }
    $target =~ s/\/$//; $host =~ s/\s//;$date =~ s/\s//;
    if($postfix == 1 || $postfix eq 'on'){$postfix="-".&rc}
    $archive = "$target/$host-$name-$date$postfix.$ext";
}

if   ($action eq 'ARCHIVE'){&archive;}
elsif($action eq 'RESTORE'){&restore;}
elsif($action eq 'LIST'){&list;}
else{
    print "No action to perform detected.\n";
}


sub archive {
    print "Generating archive: $archive\n";
    print "Passcode: $gpgpass\n";    
    system("tar -cvzi ".join(' ', sort(keys %exclds))." ".
                        join(' ', sort(keys %paths))." ".
                        join(' ', sort(keys %curr)).
           "| gpg -c --no-symkey-cache --batch --passphrase $gpgpass > $archive 2>&1");
    print "Done generating: $archive\n";
}
sub cocoon {
    if(!$name){
        if($cocoon =~ m/.*-cocoon$/){
            print cocoonPassword($gpgpass)."\n";
            exit 0;
        }
        print "Error: Cocoon name not specified!\n"; exit 2;
    }
    $archive = "$name.cocoon";
    $cocoon  = $gpgpass if $cocoon =~ m/.*-cocoon$/g;
    $cocoon  = cocoonPassword($cocoon);

    if($action eq "LIST"){
        if ($showfull) {$showfull="tvz"}else{$showfull="tz"}
        if ($fuzzy){$fuzzy = "$showfull | fzf --multi --no-sort --sync"}else{$fuzzy = $showfull};
        system("gpg --no-verbose --decrypt --batch --passphrase $cocoon $archive | tar $fuzzy 2>&1");    
        print "Listed archive: $archive\n";
    }else{
        print "Generating cocoon: $archive\n";
        system("tar -cvzi ".join(' ', sort(keys %exclds))." ".
                            join(' ', sort(keys %paths))." ".
                            join(' ', sort(keys %curr)).
                " | gpg -c --no-symkey-cache --batch --passphrase $cocoon > $archive");

        print "Action: $action\n";
        print "Cocoon passcode: $cocoon\n";
    }
}
sub list {
    #Let's try to find the most current, so with passcode also matches.
    if($postfix && $postfix ne 'off'){
        $archive = "$target/$host-$name-*$postfix.$ext";

    }else{
        $archive = "$target/$host-$name-$date*.$ext";
    }
    my @lst=`ls -c  $archive`;
    if(@lst){
        $archive = $lst[0];
        $archive =~ s/\s//g;  
        if(-d $archive){
            die "Archive not found: $archive";
        }
        if ($showfull) {$showfull="tvz"}else{$showfull="tz"}
        if ($fuzzy){$fuzzy = "$showfull | fzf --multi --no-sort --sync"}else{$fuzzy = $showfull};
        system("gpg --no-verbose --decrypt --batch --passphrase $gpgpass $archive | tar $fuzzy 2>&1");    
        print "Listed archive: $archive\n";
    }
}
sub restore {
    if($postfix && $postfix ne 'off'){
        $archive = "$target/$host-$name-*$postfix.$ext";

    }else{
        $archive = "$target/$host-$name-$date*.$ext";
    }
    my @lst=`ls -c  $archive`;
    if(@lst){
       $archive = $lst[0];
       $archive =~ s/\s//g;  
       if(-d $archive){
           die "Archive not found: $archive";
       }else{
           print "Start of restore of archive: $archive in ".$ENV{PWD}."\n";
           my $files = join(' ', sort(keys %curr));
           system("gpg --decrypt --batch --passphrase $gpgpass $archive | tar xvz $files");
       }
    }    
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
        exit 2;
    }
    return $arg;    
}
sub cocoonPassword {
    my $gpg = shift;
    my @arr;
    my ($short_form, $code)=(0,"");    
    die "Error passed where is the GPG summit argument \$cocoonPassword\@{$gpg}" if length ($gpg) < 8;
        if($gpg =~ m/-/g){# It is presumed holds the long gpg format.
            @arr = $gpg =~ m/[^-]/g; 
        }
        else{
            @arr = $gpg =~ m/./g; $short_form =1;
        }
        die "Invalid GPG summit passcode provided: $gpg" if scalar @arr == 0;   
        for (my $i=1;$i<(scalar @arr);$i+=2){
             my $pass=0; my $c = $arr[$i];
                IDX:foreach my $d(@DIGITS){ if($d eq $c){$pass = 1; last IDX;}}
                die "Invalid GPG summit passcode provided: [@arr] idx$i:[$c]" if ! $pass;
             $code .= $c;
        }
        $code .= $arr[0]; 
        if($short_form){
           $code = $gpg; $short_form = 6;
        }

        die "Invalid GPG passcode provided:[@arr] $code" if length $code!=8;    
        
    return $code;
}


sub printHelp {foreach(<DATA>){print $_}}
__END__
--------------------------------------------------------------------------------------------------------------
Encode Archive Directories

This utility creates compressed passport protected archives of directories.

Options:

-target=path    - Target path directory, if not speciefied first encountered will become, instead of archived.
-name=idn       - Compulsary, indentifier name or alias for the archive.
-gpggass=code   - Compulsary, GPG encryption/decryption passcode for the archive.
-gpggenerate    - New GPG passcode, generator.
-list=full      - List contents of desired target named archive, if gpgpass argument provided is valid.
                  If set to full (default) will give full file stats, if set to path only the path.
-fuzzy/fzf=full - Same as list contents but to fzf utility.
-restore        - Restores into current directory target archive, if gpgpass argument provided is valid.
-postfixid=off  - Default is off, when on or set will create a unique archive at destination, with postfix to name.
-ex={pattern}   - Repeating, exclude pattern or path per tar specifications.
-current=file   - Repeating, add also directly from the current directory (pwd) file to archive.
-f=file         - Repeating, restore folowing individual file from the archive.
-cocoon=code    - Creates for web transport ready cocoon archive. These have a shorter but not so any arbituary passcode.
                  Cocoons have the .cocoon file extension. Suitable for attaching to emails. 
                  You have to use an exting valid gpgpass, to create an cocoon, which can be shared over the internet.
                  Cocoon password will be provided upon archiving.

-h/? - This help file.

Syntax:

Archive is generated from the -name argument and only send to a target path not included in the archive.
The -ggpgass argument must be given:

$ enarch -gpgpass='XX-XX-XX-XX-XX-XX' -name="archive name" target/path /paths/{...}
$ enarch -gpgpass='XX-XX-XX-XX-XX-XX' -postfix=off -name="archive name" -target=/path /paths {...}

To generate an random gpg passcode use (store this one in a safe place):
$ enarch -gpggenerate

To list an archive:

$ enarch -gpgpass='XX-XX-XX-XX-XX-XX' -list -name="archive name" -target=/path /paths {...}

-- Example to store uvar locally, the new GPG PASSCODE.

$ uvar ENARCH_PASSCODE $(enarch -generate | awk -F': '  '{print $2}');
$ pgppass=$(uvar ENARCH_PASSCODE);

    After, setting the user variable, you can archive, list, restore, with it.
    $ pgp_pass=$(uvar ENARCH_PASSCODE);
    $ enarch -pass=$gpg_pass -postfix=off -name="cur_docos" -target=/mnt/archive_server ~/Documents
    $ enarch --pass=$gpg_pass -name="cur_docos" -target=/mnt/archive_server --fuzzy
    $ enarch --pass=$gpg_pass -name="cur_docos" -target=/mnt/archive_server -restore-to=$HOME/tmp
--
-- Example to create, restore cocoon based archives.
$ enarch --cocoon=XX-XX-XX --name='my_attachments' --f=Docs/file1.doc --f=Docs/file2.doc
$ enarch --cocoon=XX-XX-XX --name='my_attachments' --restore -f=Docs/file2.doc
--
Notice:
 
 - Argument assignment is smart switching, '--'arg '-'arg and '--pass' with '--gpgpass' are the same.
 - Arguments not dashed are presumed path statements. First one is the target directory if not explicitily set.
 - Command line argumends that can be repeated are --current and --ex, these are recommended to be avoided.
 - You can only archive unique root files, from current directory, with the -current=file_name argument. 
 - You have to generate the GPG passcode before archiving, without one, it can't also be listed or restored.
 - `enarch --gpgpass=xxx... --cocoon`, will dump out for you, the required travel pass.
 
Requirments:
openpgp, fzf

--------------------------------------------------------------------------------------------------------------

