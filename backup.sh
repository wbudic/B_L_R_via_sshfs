#!/bin/bash
# Includes
SRC_DIR=`dirname "$0"`
. $SRC_DIR/backup.config
#
DATE=$(date +%Y%m%d)
BACKUP_FILE="$THIS_MACHINE-$DATE.tar.gz.enc"
BACKUP_INDEX="$THIS_MACHINE-$DATE.lst.gz"
BACKUP_START=`date +%F%t%T`

echo "Your are about to backup '$HOME' to $BACKUP_FILE" "please enter $this_machine's sudo password ->"
sudo sshfs "$USER@$DEST_SERVER:backups" /mnt/$DEST_SERVER -o allow_other 

function backup () {
    
echo "Creating /mnt/$DEST_SERVER/$BACKUP_FILE"
pushd $HOME
tar -cvzi $EXCLUDES --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups \
$DIRECTORIES $WILDFILES | \
gpg -c --no-symkey-cache --batch --passphrase $GPG_PASS > /mnt/$DEST_SERVER/$BACKUP_FILE 2>&1 ;  
echo '#########################################################################'; 
ls -lah "/mnt/$DEST_SERVER/$BACKUP_FILE"; 
df -h "/mnt/$DEST_SERVER/$BACKUP_FILE";
#Remove older backups
find /mnt/$DEST_SERVER/$THIS_MACHINE*.tar.gz.enc -mtime +1 -exec rm {} + 
find /mnt/$DEST_SERVER/$THIS_MACHINE*.lst.gz -mtime +1 -exec rm {} + 
echo '#########################################################################'; 
echo "Backup has finished for: $USER@$DEST_SERVER:backups/mnt/$DEST_SERVER/$BACKUPFILE"
BACKUP_END=`date +%F%t%T`;
echo "Backup started: $BACKUP_START"
echo "Backup ended  : $BACKUP_END"
echo -n "Backup took: ";
dateutils.ddiff -f "%H hours and %M minutes %S seconds." "$BACKUP_START" "$BACKUP_END";
popd
}


##
backup 
echo "Creating contents list file, please wait..."
gpg -q --decrypt --batch --passphrase $GPG_PASS "/mnt/$DEST_SERVER/$BACKUP_FILE" | \
tar tvz | awk -F " " '{print $6}' | pv | gzip -c --best >  /mnt/$DEST_SERVER/$BACKUP_INDEX ; 
echo "done with backup " `date`", have a nice day!"

