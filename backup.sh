#!/bin/bash
# Included backup.config is only to be modified.
SRC_DIR=`dirname "$0"`
if [[ -f ~/.config/backup.config ]]; then
. ~/.config/backup.config
else
. $SRC_DIR/backup.config
fi 
#
DATE=$(date +%Y%m%d)
BACKUP_FILE="$BACKUP_DIRECTORY/$THIS_MACHINE-$DATE.$EXT_ENC"
BACKUP_INDEX="$BACKUP_DIRECTORY/$THIS_MACHINE-$DATE.$EXT_LST"
BACKUP_START=`date +%F%t%T`
# By default the backup goes to a mounting point target in the config file.
TARGET=$1
if [[ -z "$TARGET" ]] 
then
    TARGET="/mnt/$DEST_SERVER"    
    echo "Your are about to remote backup '$HOME' to $TARGET";
    if [ `stat -c%d "$TARGET"` != `stat -c%d "$TARGET/.."` ]; then
        echo "Pass, $TARGET is already mounted."
    else
        sshfs "$USER@$DEST_SERVER:" $TARGET -o allow_other
    fi    
    [[ $? -eq 1 ]] && exit 1
else        
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
fi

if [[ ! -d "$TARGET/$BACKUP_DIRECTORY" ]]; then
        echo -e "Target directoy doesn't exist: $TARGET/$BACKUP_DIRECTORY"
        declare -i times=0
        while true; do
            read -p "Do you want it to be created ?" yn
            case $yn in
                [Yy]* ) mkdir $TARGET/$BACKUP_DIRECTORY; break;;
                [Nn]* ) exit;;
                * ) times+=1;let left=3-$times; echo -e "You made $times attempts have $left left.\nPlease answer [y]es or [n]o."; [[ $times > 2 ]] && exit 1;;
            esac
        done
fi


function DoBackup () {    
echo "Started creating $TARGET/$BACKUP_FILE"
pushd $HOME
crontab -l>crontab.lst

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
echo "Backup started: $BACKUP_START"
echo "Backup ended  : $BACKUP_END"
echo "Backup took   : ";
dateutils.ddiff -f "%H hours and %M minutes %S seconds." "$BACKUP_START" "$BACKUP_END" \
| awk '{gsub(/^0 hours and/,"");}1' | awk '{gsub(/^0 minutes\s*/,"");}1'
popd > /dev/null
echo -e "\nDone with backup of $HOME on " `date` ", have a nice day!"
}

##
DoBackup 
exit 0

# This script originated from https://github.com/wbudic/B_L_R_via_sshfs
