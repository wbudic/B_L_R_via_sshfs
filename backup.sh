#!/bin/bash
# Included backup.config is only to be modified.
SRC_DIR=`dirname "$0"`
if [[ -f ~/.config/backup.config ]]; then
CONFIG_FILE="$HOME/.config/backup.config"
else
CONFIG_FILE="$SRC_DIR/backup.config"
fi 
#

if ! command -v /usr/bin/fdfind &>  /dev/null 
then
    echo "Terminating, the 'find-fd' utility not found! Try -> sudo apt install fd-find"
    exit
fi

if ! command -v gpg &>  /dev/null 
then
    echo "Terminating, the 'gpg' utility <https://www.gnupg.org> not found! Try -> sudo apt install pgp"
    exit
fi


if [[ $1 =~ ^--config= ]]
then
  _load=$(echo $1 | awk -F= '{print $2}');  shift;
elif [[ $1 =~ ^--config ]]; then
  shift; _load="$1"; shift
fi
if [[ $_load ]]; then 
    if [[ -f $_load ]]; then
        . $_load ; echo "Loaded config file '$_load'"; 
    else
        echo "Error! Config file '$_load' not found!"; exit 2;
    fi
else
        . $CONFIG_FILE
fi

if [[ $1 =~ ^--target= ]]
then
  TARGET=$(echo $1 | awk -F= '{print $2}')
  echo -e "Target directory set as: $TARGET"; IS_LOCAL=1
  shift; 
fi
[[ $1 =~ ^--target ]] && shift #handled as last argument later.

if [[ $1 =~ ^--name= ]]
then
  POSFIX=$(echo $1 | awk -F= '{print $2}');shift
elif [[ $1 =~ ^--name ]]; then
  shift; POSFIX="$1";
fi
[[ $POSFIX ]] && echo -e "Posfix name set as: $POSFIX" && POSTFIX="$POSFIX-";

function showHelp (){
read -r -d '' help <<-__help
\e[1;31mBackup Utility \e[0m - by Will Budić (Mon 30 May 2022)\e[17m
       \e[32m This utility backups your home directory, via an backup.config file specified to an target directory.\e[0m
    \e[1;33mUsage:\e[0;32m

    backup             - Uses all defaults, see/modify this settings in ~/.config/backup.config.
    backup /media/path - Sets destination target to alternative /media/path, this will be checked.

    \e[1;33mOptions:\e[0m

    \e[0;37m--config\e[0;32m{=} {path} - Alternative to ~/.config/backup.config to load, potentialy overwritting default.
                         This option is usually used in combination with the --name posfix.

    \e[0;37m--target\e[0;32m{=} {path} - Specifically assigned backup target path.
    \e[0;37m--name=\e[0;32m{word}      - Assign posfix name for current run, the default config doesn't use it or set it, 
                         so an potetnially existing backup on the target will not be overwritten,
                         i.e. while testing.
    
    \e[0;37m--help\e[1;32m | \e[0;37m-?\e[0;32m        - Prints this help.

    The reason for the backup command being semi-automatic via an config file, is to expect have everything setup in that file
    and usually run once in a week as a background cron job. Or from the command line. 
    As an typical backup can take an long time to run. Use the enarch utility (file://$SRC_DIR/enarch.pl), 
    for smaller e-safe archives instead.

    The resulting backup will be both encrypted and compressed as the final product. 
    \e[31mWarning\e[0m -> \e[0;32mDo not keep an copy of the key or config file on the target or server computer. Store it in a password manager.
    Recomended passwprd manaker I use is -> https://keepassxc.org/

\e[0mThis script originated from https://github.com/wbudic/B_L_R_via_sshfs
__help
echo -e "$help"
exit
}
[[ $1 =~ ^--h || $1 =~ ^-\? ]] && showHelp


DATE=$(date +%Y%m%d)
export BACKUP_START=`date +%F%t%T`
BACKUP_FILE="$THIS_MACHINE-$POSFIX$DATE.$EXT_ENC"
BACKUP_INDEX="$THIS_MACHINE-$POSFIX$DATE.$EXT_LST"

if [[ -z IS_LOCAL || -z "$1" ]] 
then        
    # By default the backup goes to a remote mounting point target in the config file.
    #[[ ! `stat -c%d "$TARGET" > /dev/null 2>&1` ]] && echo "Error target '$TARGET' is not valid!" && exit 2
    
    if [ `stat -c%d "$TARGET" 2>&1` != `stat -c%d "$TARGET/.." 2>&1` ]; then
         [[ $? -eq 1 ]] && exit 1
        echo "We have access, $TARGET is already mounted."
    else
        echo "Your are about to remote backup '$HOME' to $TARGET";    
        sshfs "$USER@$DEST_SERVER:$BACKUP_DIRECTORY" $TARGET -o allow_other
        [[ $? -eq 1 ]] && echo "Error aborting! '$TARGET' is not valid!" && exit 2
        echo "Mounted $TARGET."
    fi    
else
    [[ $1 ]] && TARGET=$1
    #echo "Local target: $TARGET";
    if [[ ! -d "$TARGET" ]] 
    then
        echo -e "\nTarget location doesn't exits: $TARGET"
        echo -e "Available Media:"
        find /media/$USER -maxdepth 2 -type d -print         
        echo -e "\nAvailable Mounts:"
        find /mnt/ -maxdepth 2 -type d -not -path '*/\.*' -print
        exit 1
    else
        echo "Your are about to backup locally to $TARGET/$BACKUP_DIRECTORY/$BACKUP_FILE"
    fi

    if [[ ! -d "$TARGET/$BACKUP_DIRECTORY" ]]; then
            echo -e "Target directory doesn't exist: $TARGET"
            echo -e "If this is expected to be mounted on another server, you don't want it to be created from this script."
            declare -i times=0
            while true; do
                read -p "Do you want it to be created ?" yn
                case $yn in
                    [Yy]* ) mkdir $TARGET/$BACKUP_DIRECTORY; break;;
                    [Nn]* ) exit;;
                    * ) times+=1;let left=3-$times; echo -e "You made $times attempts have $left left.\nPlease answer [y]es or [n]o."; [[ $times > 2 ]] && exit 1;;
                esac
            done
            $TARGET="$TARGET/$BACKUP_DIRECTORY"
    fi
fi


function DoBackup () {

echo "Obtaining file selection list..."
pushd $HOME
echo -e "Started creating $TARGET/$BACKUP_FILE   Using Config:$CONFIG_FILE"

# Add by default all the dotties hotties first.
/usr/bin/fdfind -H -t file --max-depth 1 . | sed -e 's/^\.\///' | sort -d > /tmp/backup.lst

#Check config file specified directories to exist.
for dir in $DIRECTORIES
do
  if [[ -d $dir ]]; then
    directories="$directories $dir"
    elif [[ -f $dir ]]; then #maybe glob expanded to an file?
        glob_files=$(echo -e "$glob_files $dir\f") 
    else
        echo "Skipping specified directory '$dir' not found!"
    fi
done

if [[ ! -z  $directories ]]; then
    echo "Collecting files from: $directories"
    /usr/bin/fdfind -H -t file -I $EXCLUDES . $directories | sort -d  >> /tmp/backup.lst
    [[ $? != 0 ]] && exit $?;
fi

if [[ ! -z  $glob_files ]]; then    
    glob_files=$(echo "$glob_files" | perl -pe 's/\f\s*/\n/g')    
    echo -e "Adding glob files:\n$glob_files"    
    echo -e "$glob_files" | sed -e 's/^[[:blank:]]*//' >> /tmp/backup.lst
    [[ $? != 0 ]] && exit $?;
fi


file_size=0
file_cnt=0
set -f
for entry in $WILDFILES
do
 if [[ $entry =~ ^\*\. ]]; then
        echo "Igoning obsolete extension glob setting -> $entry"        
 else
       set +f
       #via echo glob translate to find the files.
       echo $entry | sed -e 's/ /\n/g' > /tmp/backup_wilderbeasts.lst
       set -f
       while IFS= read -r file; 
       do if [[ -n "$file" ]]; then 
          size=$(stat -c %s "$file"); file_size=$(($file_size + $size));  file_cnt=$(($file_cnt + 1))
          #[[ ! -d  ~/_BACKUP_WILDFILES ]] &&  mkdir ~/_BACKUP_WILDFILES
          rsync -rlR $file ~/_BACKUP_WILDFILES
          echo "_BACKUP_WILDFILES$file" >> /tmp/backup.lst
       fi 
       done < /tmp/backup_wilderbeasts.lst
 fi
done
set +f


#################################################################################################
if [[ "$BACKUP_VERBOSE" -eq 1 ]]; then 

 while NFS= read -r file; 
    do if [[ -n "$file" ]]; then size=$(stat -c %s "$file"); file_size=$(($file_size + $size)); file_cnt=$(($file_cnt + 1)); fi 
 done < <(pv -N "Please wait, obtaining all file stats" -pt -w 100 /tmp/backup.lst)
 echo "Backup File count: $file_cnt";
 target_avail_space=$(df "$TARGET" | awk '{print $4}' | tail -n 1) 
 echo "Target avail space: $target_avail_space"
 file_size_formated=$(numfmt --to=iec-i "$file_size") 
 file_size_kb=$(($file_size / 1024));
 echo "Backup size in kbytes:$file_size";
  
 if [[ $file_size_kb -gt $target_avail_space ]] 
 then
    target_avail_space=$(numfmt --to=iec-i $target_avail_space) 
    echo -e "\nAvailable space on $TARGET is $target_avail_space,"
    echo -e "this is less to volume required of $file_size_formated of $file_cnt files uncompressed.\n"
	read -p "Are you sure you want to proceed? (Answer Yes/No): " rep; 
	if [[ ! $rep =~ ^Y|^y ]]
	then
	     echo "Backup has been skipped."
	     exit 1;
	fi
 fi
 echo '#########################################################################'; 
 echo "  Started archiving! Expected archive size: $file_size_formated";
 echo '#########################################################################'; 
 # Notice - tar archives and compresses in blocks, piped out to pv is not actual byte mass, hence no lineral progressbar.
 tar cJvi --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups -P -T /tmp/backup.lst | \
 pv -N "Backup Status" --timer --rate --bytes -pw 70| \
 gpg -c --no-symkey-cache --batch --passphrase $GPG_PASS > $TARGET/$BACKUP_FILE 2>&1;
 else
 tar cJi --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups \
 -P -T /tmp/backup.lst | \
 gpg -c --no-symkey-cache --batch --passphrase $GPG_PASS > $TARGET/$BACKUP_FILE 2>&1;
fi #of [[ "$BACKUP_VERBOSE" -eq 1 ]];
#################################################################################################
[[ $? != 0 ]] && echo "FATAL ERROR, EXITING BACKUP FOR $TARGET/$BACKUP_FILE !" && exit $?;

echo '#########################################################################'; 
ls -lah "$TARGET/$BACKUP_FILE"; 
if [[ $? == 0 &&  $(ls -la "$TARGET/$BACKUP_FILE" | awk '{print $5}') -eq 0 ]]; then
echo "BACKUP FAILED FOR $TARGET/$BACKUP_FILE!!!"
exit $?
fi 
# Index
cat /tmp/backup.lst | xz -9e -c > $TARGET/$BACKUP_INDEX
rm /tmp/backup.lst
rm /tmp/backup_wilderbeasts.lst
[[ -d  ~/_BACKUP_WILDFILES ]] && rm -rf ~/_BACKUP_WILDFILES 
##
if [[ $? == 0 &&  $(ls -la "$TARGET/$BACKUP_INDEX" | awk '{print $5}') -eq 0 ]]; then
echo "BACKUP FAILED FOR $TARGET/$BACKUP_INDEX!!!"
exit $?
fi 

df -h "$TARGET/$BACKUP_FILE";

#Remove older backups
find $TARGET/backups/$THIS_MACHINE*.$EXT_ENC -mtime +1 -exec rm {} + > /dev/null 2>&1
find $TARGET/backups/$THIS_MACHINE*.$EXT_LST -mtime +1 -exec rm {} + > /dev/null 2>&1
echo '#########################################################################'; 
echo "Backup has finished for: $USER@$DEST_SERVER:$TARGET/$BACKUP_FILE"

export BACKUP_END=`date +%F%t%T`;
export BACKUP_TIME=`dateutils.ddiff -f "%H hours and %M minutes %S seconds" "$BACKUP_START" "$BACKUP_END" \
| awk '{gsub(/^0 hours and /,"");}1' | awk '{gsub(/^0 minutes\s*/,"");}1'`
echo "Backup started : $BACKUP_START"
echo "Backup ended   : $BACKUP_END"
echo "Backup took    : $BACKUP_TIME";

popd > /dev/null
# Mine (Will Budic) user variable concept, should be part of the system.
# So if the computer has been shut down on the last given backup date, 
# to start an backup immediately on the next cron_maintenance script run.
[[ -f "uvar.sh" ]] && uvar.sh -n "LAST_BACKUP_DATE" -v "$BACKUP_END"
echo -e "\nDone with backup of $HOME on " `date` ", have a nice day!"

}

##
crontab -l>crontab.lst
code --list-extensions > vs_code_extensions.lst
DoBackup 
exit 0



