#!/bin/bash
# Included backup.config is only to be modified.
SRC_DIR=`dirname "$0"`
if [[ -f ~/.config/backup.config ]]; then
CONFIG_FILE="$HOME/.config/backup.config"
else
CONFIG_FILE="$SRC_DIR/backup.config"
fi 
. $CONFIG_FILE
#
DATE=$(date +%Y%m%d)
BACKUP_FILE="$THIS_MACHINE-$DATE.$EXT_ENC"
BACKUP_INDEX="$THIS_MACHINE-$DATE.$EXT_LST"
export BACKUP_START=`date +%F%t%T`

if ! command -v fd &>  /dev/null 
then
    echo "Terminating, the 'find-fd' utility not found! Try -> sudo apt install fd-find"
    exit
fi

if ! command -v gpg &>  /dev/null 
then
    echo "Terminating, the 'gpg' utility <https://www.gnupg.org> not found! Try -> sudo apt install pgp"
    exit
fi


# By default the backup goes to a mounting point target in the config file.
if [[ -z "$1" ]] 
then        
    echo "Your are about to remote backup '$HOME' to $TARGET";
    if [ `stat -c%d "$TARGET"` != `stat -c%d "$TARGET/.."` ]; then
        echo "We have access, $TARGET is already mounted."
    else
        sshfs "$USER@$DEST_SERVER:$BACKUP_DIRECTORY" $TARGET -o allow_other
    fi    
    [[ $? -eq 1 ]] && exit 1
else        
    TARGET=$1
    if [[ ! -d "$TARGET" ]] 
    then
        echo -e "\nTarget location doesn't exits: $TARGET"
        echo -e "Available Media:"
        find /media/$USER -maxdepth 2 -type d -print         
        echo -e "\nAvailable Mounts:"
        find /mnt/ -maxdepth 2 -type d -not -path '*/\.*' -print
        exit 1
    else
        echo "Your are about to backup locally to $TARGET/$BACUP_DIRECTORY/$BACKUP_FILE"
    fi

    if [[ ! -d "$TARGET/$BACKUP_DIRECTORY" ]]; then
            echo -e "Target directoy doesn't exist: $TARGET"
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

fd -H -t file --max-depth 1 . | sed -e 's/^\.\///' | sort -d > /tmp/backup.lst

#Check config file specified directories to exist.
for dir in $DIRECTORIES
do
  if [[ -d $dir ]]; then
    directories="$directories $dir"
    else
    echo "Skipping specified directory '$dir' not found!"
    fi
done
echo "Collecting files from: $directories"
fd -H -t file -I $EXCLUDES . $directories | sort -d  >> /tmp/backup.lst
[[ $? != 0 ]] && exit $?;

file_size=0
file_cnt=0
set -f
for entry in $WILDFILES
do
 if [[ $entry =~ ^\*\. ]]; then
        echo "Igoning obsolete extension glob steting -> $entry"        
 else
       set +f
       #via echo glob translate to find the files.
       echo $entry | sed -e 's/ /\n/g' > /tmp/backup_wilderbeasts.lst
       set -f
       while IFS= read -r file; 
       do if [[ -n "$file" ]]; then 
          size=$(stat -c %s "$file"); file_size=$(($file_size + $size));  file_cnt=$(($file_cnt + 1))
          echo $file >> /tmp/backup.lst
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
#rm /tmp/backup.lst
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

# This script originated from https://github.com/wbudic/B_L_R_via_sshfs
