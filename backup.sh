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
BACKUP_START=`date +%F%t%T`
# By default the backup goes to a mounting point target in the config file.
if [[ -z "$1" ]] 
then        
    echo "Your are about to remote backup '$HOME' to $TARGET";
    if [ `stat -c%d "$TARGET"` != `stat -c%d "$TARGET/.."` ]; then
        echo "Pass, $TARGET is already mounted."
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


# @TODO 20220526 Use this function only for intial setup and testing. 
#                It can terminate the backup with nasty tar error on very huge lists of files having large size of files. 
#                Reason why this is happening, is unknown to me. Hard to test, as it can take an hour to fail in middle of backup.
#                The default, and working backup function is after this one.
function DoBackupNEW () {

echo "Obtaining file selection list..."
pushd $HOME
echo -e "Started creating $TARGET/$BACKUP_FILE   Using Config:$CONFIG_FILE"
fd -H -t file --max-depth 1 . | sed -e 's/^\.\///' > /tmp/backup.lst
#Check config file specified directories to exist.
for dir in $DIRECTORIES
do
  if [[ -d $dir ]]; then
    directories="$directories $dir"
    else
    echo "Skipping specified directory '$dir' not found!"
    fi
done
echo "Collecting from:$directories"
fd -H -t file -I $EXCLUDES . $directories | sort -d  >> /tmp/backup.lst
[[ $? != 0 ]] && exit $?;

#################################################################################################
if [[ "$BACKUP_VERBOSE" -eq 1 ]]; then

 file_cnt=$(cat /tmp/backup.lst| wc -l)
 echo "File count:$file_cnt";
 file_size=0
 while IFS= read -r file; 
 do if [[ -n "$file" ]]; then size=$(stat -c %s "$file"); file_size=$(expr "$file_size" + "$size"); fi 
 done < <(pv -N "Please wait, obtaining all file stats" -ptl -s "$file_cnt" /tmp/backup.lst)
 file_size_formated=$(numfmt --to=iec-i $file_size)
 echo '#########################################################################'; 
 echo "  Started archiving! Expected archive size:$file_size ($file_size_formated)";
 echo '#########################################################################'; 
 tar cJvi --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups -T /tmp/backup.lst | \
 pv  -N "Backup Status" -pe --timer --rate --bytes -w 80 -s "$file_size" | \
 gpg -c --no-symkey-cache --batch --passphrase $GPG_PASS > $TARGET/$BACKUP_FILE 2>&1;
else
 tar cJi $EXCLUDES --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups \
 -T /tmp/backup.lst | \
 gpg -c --no-symkey-cache --batch --passphrase $GPG_PASS > $TARGET/$BACKUP_FILE 2>&1;
fi
#################################################################################################
[[ $? != 0 ]] && exit $?;

echo '#########################################################################'; 
ls -lah "$TARGET/$BACKUP_FILE"; 
if [[ $? == 0 &&  $(ls -la "$TARGET/$BACKUP_FILE" | awk '{print $5}') -eq 0 ]]; then
echo "BACKUP FAILED FOR $TARGET/$BACKUP_FILE!!!"
exit $?
fi 
#index
cat /tmp/backup.lst | xz -9e -c > $TARGET/$BACKUP_INDEX

if [[ $? == 0 &&  $(ls -la "$TARGET/$BACKUP_INDEX" | awk '{print $5}') -eq 0 ]]; then
echo "BACKUP FAILED FOR $TARGET/$BACKUP_INDEX!!!"
exit $?
fi 

df -h "$TARGET/$BACKUP_FILE";

#Remove older backups
find $TARGET/backups/$THIS_MACHINE*.$EXT_ENC -mtime +1 -exec rm {} + 
find $TARGET/backups/$THIS_MACHINE*.$EXT_LST -mtime +1 -exec rm {} + 
echo '#########################################################################'; 
echo "Backup has finished for: $USER@$DEST_SERVER:$TARGET/$BACKUP_FILE"

BACKUP_END=`date +%F%t%T`;
BACKUP_TIME=`dateutils.ddiff -f "%H hours and %M minutes %S seconds" "$BACKUP_START" "$BACKUP_END" \
| awk '{gsub(/^0 hours and /,"");}1' | awk '{gsub(/^0 minutes\s*/,"");}1'`
echo "Backup started : $BACKUP_START"
echo "Backup ended   : $BACKUP_END"
echo "Backup took    : $BACKUP_TIME";

popd > /dev/null
echo -e "\nDone with backup of $HOME on " `date` ", have a nice day!"

}

function DoBackup () {
echo -e "Started creating $TARGET/$BACKUP_FILE   Using Config:$CONFIG_FILE"
pushd $HOME

#################################################################################################
if [[ "$BACKUP_VERBOSE" -eq 1 ]]; then
 tar cJvi $EXCLUDES --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups \
 $DIRECTORIES $WILDFILES crontab.lst | pv -N "Backup Status" -t -b -e -r | \
 gpg -c --no-symkey-cache --batch --passphrase $GPG_PASS > $TARGET/$BACKUP_FILE 2>&1;
else
 tar cJi $EXCLUDES --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups \
 $DIRECTORIES $WILDFILES crontab.lst | \
 gpg -c --no-symkey-cache --batch --passphrase $GPG_PASS > $TARGET/$BACKUP_FILE 2>&1;
fi
#################################################################################################
[[ $? != 0 ]] && exit $?;

echo '#########################################################################'; 
ls -lah "$TARGET/$BACKUP_FILE"; 
if [[ $? == 0 &&  $(ls -la "$TARGET/$BACKUP_FILE" | awk '{print $5}') -eq 0 ]]; then
echo "BACKUP FAILED FOR $TARGET/$BACKUP_FILE!!!"
exit $?
fi 
df -h "$TARGET/$BACKUP_FILE";
#Remove older backups
find $TARGET/backups/$THIS_MACHINE*.$EXT_ENC -mtime +1 -exec rm {} + 
find $TARGET/backups/$THIS_MACHINE*.$EXT_LST -mtime +1 -exec rm {} + 
echo '#########################################################################'; 
echo "Backup has finished for: $USER@$DEST_SERVER:$TARGET/$BACKUP_FILE"

#################################################################################################
echo "Creating contents list file, please wait..."
if [[ $BACKUP_VERBOSE -eq 1 ]]; then
 gpg -q --decrypt --batch --passphrase $GPG_PASS "$TARGET/$BACKUP_FILE" | \
 tar -Jt | pv -N "Backup Status" | xz -9e -c > $TARGET/$BACKUP_INDEX
else
 gpg -q --decrypt --batch --passphrase $GPG_PASS "$TARGET/$BACKUP_FILE" | \
 tar -Jt | xz -9e -c > $TARGET/$BACKUP_INDEX
fi
#################################################################################################

if [[ $? == 0 &&  $(ls -la "$TARGET/$BACKUP_INDEX" | awk '{print $5}') -eq 0 ]]; then
echo "BACKUP FAILED FOR $TARGET/$BACKUP_INDEX!!!"
exit $?
fi 

BACKUP_END=`date +%F%t%T`;
BACKUP_TIME=`dateutils.ddiff -f "%H hours and %M minutes %S seconds" "$BACKUP_START" "$BACKUP_END" \
| awk '{gsub(/^0 hours and/,"");}1' | awk '{gsub(/^\s*0 minutes\s*/,"");}1'`
echo "Backup started : $BACKUP_START"
echo "Backup ended   : $BACKUP_END"
echo "Backup took    : $BACKUP_TIME";

popd > /dev/null
echo -e "\nDone with backup of $HOME on " `date` ", have a nice day!"
}

##
crontab -l>crontab.lst
code --list-extensions > vs_code_extensions.lst
DoBackup 
exit 0

# This script originated from https://github.com/wbudic/B_L_R_via_sshfs
