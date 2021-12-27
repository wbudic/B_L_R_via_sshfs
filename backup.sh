#!/bin/bash
# Includes
SRC_DIR=`dirname "$0"`
. $SRC_DIR/backup.config
#
DATE=$(date +%Y%m%d)
BACKUP_FILE="backups/$THIS_MACHINE-$DATE.$EXT_ENC"
BACKUP_INDEX="backups/$THIS_MACHINE-$DATE.$EXT_LST"
BACKUP_START=`date +%F%t%T`
TARGET="/mnt/$DEST_SERVER"
if [[ -z "$BACKUP_VERBOSE" ]]; then
BACKUP_VERBOSE=$BACKUP_VERBOSE_OUTPUT
fi

if [[ ! -z "$1" ]] 
then
    TARGET=$1    
    if [[ ! -d "$TARGET" ]] 
    then
        echo -e "\nTarget doesn't exits: $TARGET"
        echo -e "Available Media:"
        find /media/$USER -maxdepth 2 -type d -print 
        #ls -lr "/media/$USER" |  awk '! /^total|\./ {print}';
        echo -e "\nAvailable Mounts:"
        #ls -lr "/mnt/"|  awk '! /^total|\./ {print}';
        find /mnt/ -maxdepth 2 -type d -print 
        exit 1;
    else
        IS_LOCAL_MOUNT=1
        DEST_SERVER=$THIS_MACHINE
    fi    
fi
if [ -z $IS_LOCAL_MOUNT ]
then

    echo -e "Your are about to remote backup '$HOME' to $BACKUP_FILE";

    if [ `stat -c%d "$TARGET"` != `stat -c%d "$TARGET/.."` ]; then
        echo "$TARGET is mounted"
    else
        sshfs "$USER@$DEST_SERVER:" $TARGET -o allow_other
    fi    
    [[ $? -eq 1 ]] && exit 1
else
    echo "Your are about to backup '$HOME' to $TARGET/$BACKUP_FILE"
fi

function backup () {    
echo "Starting creating $TARGET/$BACKUP_FILE"
pushd $HOME

#################################################################################################
if [[ "$BACKUP_VERBOSE" -eq 1 ]]; then
 tar cJvi $EXCLUDES --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups \
 $DIRECTORIES $WILDFILES | pv -N "Backup Status" -t -b -e -r | \
 gpg -c --no-symkey-cache --batch --passphrase $GPG_PASS > $TARGET/$BACKUP_FILE 2>&1;
else
 tar cJi $EXCLUDES --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups \
 $DIRECTORIES $WILDFILES | \
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
echo "Creating contents list file, please wait..."

#################################################################################################
if [[ "$BACKUP_VERBOSE" -eq 1 ]]; then
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
}


##
backup 
echo -e "\nDone with backup of $HOME on " `date`", have a nice day!"

exit 0;

# This script originated from https://github.com/wbudic/B_L_R_via_sshfs
