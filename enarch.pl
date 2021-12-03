#!/bin/perl
use strict;
use sigtrap qw/die normal-signals/;
use File::stat;

my ($gpgpass,$target,$name,$archive,$action,$postfix,$fuzzy,$showfull,$cocoon, $attach_letter, $vim, $nolog, $cocodb, $alias, $add);
my $xs_level=6;
my $host   =`uname -n`;
my $date   = `date "+%Y%m%d"`;
my $ext    = 'tar.gz.enc';
my %paths  = ();
my %exclds = ();
my %curr   = ();
my @DIGITS = "1234567890ABCDEFGHIJKLMWENCARCHIVE" =~ m/./g;
my $DEBUG  = 0;
my $COCOON_ATTACH_LETTER = 'cocoon_attached_letter.txt';
my $BACKUP_START=`date '+%F %T'`;
my $BACKUP_END;
$ENV{HOME}='/home/will' if not $ENV{HOME};

foreach my $a (@ARGV){
    my $v = $a; $v =~ s/^-+.*[=:]//;
    print "[$a] -> $v\n" if $DEBUG;
    if($a =~ m/~/g){print "Error: Directory substitution is not permited. Use full paths please!\n"; exit 2;}    
    elsif($a =~ m/^-+.*(pass)/i)       {$gpgpass = gpgPassCodeCheck($v);next}
    elsif($a =~ m/^-+.*(generate)/i)    {print "New gpg passcode: ", gpgPassCodeGenerate(), "\n";exit 1;}
    elsif($a =~ m/^-+.*(target)/i)      {$paths{$target} = $target if $target; $target = $v;}
    elsif($a =~ m/^-+.*(name)/i)        {$name = $v;}
    elsif($a =~ m/^-+.*(letter)/i)      {$attach_letter = $v;next}
    elsif($a =~ m/^-+.*(vim)/i)         {$attach_letter = $v;$vim = 1;next}
    elsif($a =~ m/^-+.*(coco.*db)/i)    {$action='ARCHIVE' if !$action; $alias=$v; $cocodb = $ENV{HOME}."/.config/cocoon.db";next}
    elsif($a =~ m/^-+.*(add-to-db)/i)   {$action='REGISTER'; $add=1;$alias=lc $v;next}
    elsif($a =~ m/^-+.*(cocoon)/i)      {$action='ARCHIVE' if !$action; $cocoon=$v;next}
    elsif($a =~ m/^-+.*(list)/i)        {$action='LIST'; $showfull=1 if $v eq 'full'}
    elsif($a =~ m/^-+.*(fuzzy)|(fzf)/i) {$action='LIST'; $fuzzy=1; $showfull=1 if $v eq 'full'}
    elsif($a =~ m/^-+.*(extract)/i)     {$action='RESTORE';next}    
    elsif($a =~ m/^-+.*(restore)/i)     {$action='RESTORE';next}
    elsif($a =~ m/^-+h|\?/i)            {$action='HELP' if !$action; &printHelp;}
    elsif($a =~ m/^-+.*(postfix)/i)     {$postfix = $v; $postfix =0 if $postfix =~ /^of+/ || $postfix =~ /^0/}
    elsif($a =~ m/^-+.*(ex)/i)          {$exclds{"--exclude=$v"}=$v}    
    elsif($a =~ m/^-+.*(cur)|(f)/i)     {$v=strip_trailing($v);$curr{"$v"}=$v}
    elsif($a =~ m/^-+.*(no-logging)/i)  {$nolog=1}
    elsif($a =~ m/^-+.*(xs_level)/i)    {$xs_level=$v if $a ne $v; next}
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
        }elsif(-f $a && $a =~ m/.*\.cocoon$/){
                $target = $a if !$target
        }else{
            print "Error: Directory or path specified is not a valid directory: [$a]\n"; exit 2;
        }
    }    
    else{
         print "Error: Don't understand argument: [$a]\n"; exit 2;
    }    
}
sub strip_trailing{
    my $r = shift;
    if($action eq 'RESTORE'){
       $r=~ s/^\///g;
    }    
    return $r;
}

if($cocoon || $cocodb){
   if($cocodb){&cocoonDB; exit 1 if not $cocoon}
   &cocoon if $cocoon; exit 1;
}
elsif($action ne 'HELP'){
    if(!$target){
        print "Error: Target directory not specified!\nMaybe issue [$0 -?] for help.\n"; exit 2;
    }
    if(!$name){
        print "Error: Target archive name not specified!\nMaybe issue [$0 -?] for help.\n"; exit 2;
    }
    $target =~ s/\/$//; $host =~ s/\s//;$date =~ s/\s//;
    if($postfix == 1 || $postfix eq 'on'){$postfix="-".&rc}
    $archive = "$target/$host-$name-$date$postfix.$ext";
}

if   ($action eq 'ARCHIVE'){&archive;}
elsif($action eq 'RESTORE'){&restore;}
elsif($action eq 'LIST')   {&list;}
else{
    print "No action to perform detected.\n";
}

# Plain archive.
sub archive {
    print "Generating archive: $archive\n";
    print "Passcode: $gpgpass\n";    
    system("tar -cvzi ".join(' ', sort(keys %exclds))." ".
                        join(' ', sort(keys %paths))." ".
                        join(' ', sort(keys %curr)).
           "| pv -N 'Status' -t -b -e -r | gpg -c --no-symkey-cache --batch --passphrase $gpgpass > $archive 2>&1");    
    print "Done generating: $archive\n";
    logToCnf($gpgpass, $archive);
    &printArchivingTook;
}
# An cocoon archive, must have specific cocoon password to which also an letter can be attached.
sub cocoon {
    
    if($action eq "ARCHIVE" && !$name){
        if($cocoon =~ m/.*-cocoon$/){
            print cocoonPassword($gpgpass)."\n";
            exit 0;
        }
        print "Error: Cocoon name not specified! action is $action\n"; 
        exit 2;
    }else{         
        if($name){$archive = "$name.cocoon"}else{$archive = $target}
        $gpgpass = $cocoon if not $gpgpass;  
    }
    my $res;
    $cocoon =cocoonPassword($gpgpass);
    if($action eq "LIST"){
        if ($showfull) {$showfull="-Jtv"}else{$showfull="-Jt"}
        if ($fuzzy){$fuzzy = "$showfull | fzf --multi --no-sort --sync"}else{$fuzzy = $showfull};
           $res = system("gpg --no-verbose --decrypt --batch --passphrase $cocoon $archive 2>/dev/null | pv -N 'Obtaining Listing' | tar $fuzzy ");    
        if($res){
            print "Error: Failed to list archive: $archive. Cocoon password suplied: $cocoon\n";
        }else{
            print "Listed archive: $archive\n";
        }
        if($attach_letter){

            if($attach_letter =~ /-letter$/){
               $attach_letter = $COCOON_ATTACH_LETTER;
            }
            print "\nContents of $attach_letter:\n"; print "-" x 80, "\n";
            $res = 
        system("gpg --no-tty --decrypt --batch --passphrase $cocoon $archive  2>/dev/null | tar -Jxo --to-stdout $attach_letter | cat -"); 
            if($res){
                print "Error: Archive: $archive. Contains no letter: $attach_letter\n";
            }
            else{
                print "-" x 80, "\n";
            }
        }
    }
    elsif($action eq "RESTORE"){
        my $files = join ' ', map "'$_'", sort(keys %curr);        
        $res = system("gpg --decrypt --batch --passphrase $cocoon $archive | tar -Jxv --strip-components 2 $files");
        if($res){
            print "Error: Failed to restore archive: $archive. Cocoon password suplied: $cocoon\n";
        }else{
            print "Restored archive: $archive\n";
        }
    }elsif($action eq "ARCHIVE"){
        if($attach_letter){

            if($attach_letter =~ /-letter$/ || $attach_letter =~ /-vim$/){
               $attach_letter = $COCOON_ATTACH_LETTER;
            }
            elsif(! -f $attach_letter){
                die "Letter file not found: $attach_letter"
            }else{
                $paths{$attach_letter}=$attach_letter;
                undef $attach_letter;
            }

            if($attach_letter){
                if($vim){
                    `touch $attach_letter`;
                     $res = system("vim $attach_letter");
                }else{
                    my ($FH, $input);
                    unless(open $FH, '>', $attach_letter) {
                        die "\nUnable to create $attach_letter\n";
                    }                
                    print "You are editing a letter for a NEW cocoon archive: $archive\n";
                    print "To finish typing finish with an '\\0' as the last line:\n";
                    print "-" x 80, "\n";       
                    while(  $input = <STDIN> ) {
                        chomp($input); last if $input eq "\\0";
                        print $FH "$input\n";              
                    }
                    close $FH;
                }
                $paths{$attach_letter}=$attach_letter; #attaching to path to appear first in archive.
            }
        }
        print "Generating cocoon: $archive\n";$paths{$target} = $target;
        $res = "tar -cvi --use-compress-program=\'xz -"."$xs_level"."T3\'".join(' ', sort(keys %exclds))." ".
                            join(' ', map "'$_'", sort(keys %paths))." ".
                            join(' ', map "'$_'", sort(keys %curr)).
                " | pv -N 'Cocooning' -t -b -e -r | gpg -c --no-symkey-cache --batch --passphrase $cocoon > $archive";
        print $res, "\n\n";
        $res = system($res);

        if($res){
            print "Action: $action failed! Err: $!\n"; 
            exit 0;    
        }else{            
             my $stats = stat($archive);
            `rm $attach_letter` if $attach_letter eq $COCOON_ATTACH_LETTER;            
            
            print  "Action: $action Finished succesfully!\n";            
            print  "Cocoon passcode: $cocoon\n";            
            printf "Cocoon archive: $archive size: %s date: %s \n", human($stats->size),scalar localtime $stats->mtime;
            logToCnf($cocoon, $archive);
            &printArchivingTook;
        }
    }
}

sub human {
        my $x = shift;               
        my $s=" B   KiB MiB GiB TiB EiB PiB YiB ZiB";
        while ($x>=1024 && length($s)>1){
               $x/=1024; $s=substr($s,4)
        }
        my $xf=($s==" B  ")?"~%d ":"%8.2f";
        $s=substr($s,1,3);        
        return sprintf( "$xf%s", $x, $s)
}
      

sub printArchivingTook {
    $BACKUP_END=`date '+%F %T'`;
    my $out =  `dateutils.ddiff -f "%H hours and %M minutes %S seconds." "$BACKUP_START" "$BACKUP_END"`;
    $out =~ s/^0 hours and //;
    $out =~ s/^0 minutes //;
    print "Archiving took: $out";
}
sub logToCnf{
    if(!$nolog){
        my ($pgp, $archive) = @_; $BACKUP_END =`date '+%T'`;
        my $stamp = "$BACKUP_START $BACKUP_END"; $stamp =~ s/\n//g;        
        my $FH; unless (open $FH, '>>', $ENV{HOME}."/.config/enarch.log") {die "Unable to open ". $ENV{HOME}."/.config/enarch.log"}
          print $FH "$stamp $pgp $archive\n";
        close $FH;
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

sub cocoonDB {
    my %data = (); 
    if(-f $cocodb){
        open (my $fh, '<', $cocodb);
         $/=undef;
         my $content = <$fh>;         
         my @ln = $content =~ m/(.*)\n/g;
         foreach (@ln){
             my @p = split /=/, $_;             
             $data{$p[0]}=$p[1] if scalar @p > 0;
             
         }
         close $fh;
    }    

    if($action eq 'LIST' &&not $target ){
        foreach (sort keys %data) {
            print $_,'=', $data{$_}, "\n";
        }
        exit 2;
    }
    
    if($alias){ #if $alias is set we are adding/modifying the db.         
        if(!$add && $action eq 'RESTORE'){
            $cocoon = $data{$alias};
            return undef if $cocoon;            
        }
           my %v =  map { $_ => 1 } values %data;
           if($gpgpass){ #We force the value
               $data{$alias} = $gpgpass; 
           }else{#or generate new one
               $data{$alias} = &gpgPassCodeGenerate for exists($v{$_});           
           }
           open(my $fh, '>', $cocodb) or die "Couldn't write to $cocodb, $!";
           foreach my $k(sort keys %data) {
            print $fh $k,'=', $data{$k}, "\n";
           }
           close $fh;
           print "Added $alias $cocoon to [$cocodb]\n" if $DEBUG;
           $cocoon=$data{$alias};           
    }elsif($cocoon){ #the alias|email is assigned to the $cocoon variable instead of an passcode.
       if(not $data{$cocoon}){
           print "Error alias|email of -> '$cocoon' not found on system!\n";
           exit 0;
       }else{
        $cocoon= $data{$cocoon}
       }       
       print $target, " <-- $action gpgpass[", $cocoon,"]\n";  
       exit 1 if not $name and not $target       
    }    
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
-letter{=file}  - Pipe in or type message to cocoon, for the archive.
-vim            - Open vim to enter the letter or message for the archive.
-no-logging     - Archive action is logged automatically to ~/.config/enarch.log, use this option to dissable this.
-cocodb={email} - Interact with cocoondb for listing, adding, obtaining a stored coocon pass code (see more about bellow).
-xz-level={-6}  - XZ_OPT compression level to use (from 0..9).

-h/? - This help file.

Syntax:

Archive is generated from the -name argument and only send to a target path not included in the archive.
The -ggpgass argument must be given for every action:

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
-- Log format in ~/.config/enarch.log
Use --no-logging to dissable logging
Format:
[YYYY-MM-DD HH:MM:SS{started}] [HH:MM:SS{ended}]:[gpg code]:[target/name]

-- Cocoon DB Interaction
   A special ~/.config/cocoons.db file is kept allowing to store cocoon passwords.
   - To list available entries
   $ enarch --cocodb --list
   - To add entry alias name or email.
   $ enarch --cocodb --add-to-db=alias|email
   - To read cocoon passcode entry for an alias or email.
   $ enarch --cocodb=alias|email

--

-- Full Examples of working with a single file cocoon via the cocodb. alias enarch=~/dev/enarch.pl 
$ enarch --cocodb=SomeEmail@protonmail.com -name=attachment -f='/home/user1/Documents/resume.pdf'
$ enarch --cocodb=SomeEmail@protonmail.com --list=full --target=attachment.coon
$ enarch --cocodb=SomeEmail@protonmail.com --restore --target=attachment.coon
    -- If emailed the passcode you register and use alias john (the emailer generated code) rather then his email.
    $ enarch --cocodb --gpgpass="1W-EA-WA-48-HC-DM-C2-EA" --add-to-db=john
    -- Finally extract the whole.
    $ enarch --cocodb:john --restore --name=attachment
    -- or
    $ enarch --cocodb:john --restore --target=attachment.cocoon
    -- To extract by specific file.
    $ enarch --cocodb:john --restore --name=attachment -f="/home/user1/Documents/resume.pdf"

Notice:
 
 - Argument assignment is smart switching, '--'arg '-'arg and '--pass' with '--gpgpass' are the same.
 - Arguments not dashed are presumed path statements. First one is the target directory if not explicitily set.
 - Command line argumends that can be repeated are --current and --ex, these are recommended to be avoided.
 - You can only archive unique root files, from current directory, with the -current=file_name argument. 
 - You have to generate the GPG passcode before archiving, without one, it can't also be listed or restored.
 - `enarch --gpgpass=xxx... --cocoon`, will dump out for you, the required travel pass.
 
Requirments:
sudo apt install openpgp fzf pv

--------------------------------------------------------------------------------------------------------------
# This file originated from https://github.com/wbudic/B_L_R_via_sshfs
