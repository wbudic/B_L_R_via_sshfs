#!/bin/bash
# Includes
SRC_DIR=`dirname "$0"`
. $SRC_DIR/backup.config
#
DIRECTORIES="Documents dev Pictures Public Videos dev .cinnamon"
#DIRECTORIES="dev/LifeLog"
BACKUP_FILE="$THIS_MACHINE-$(date +%Y%m%d).tar.gz.enc"
BACKUP_INDEX="$THIS_MACHINE-$(date +%Y%m%d).lst"
BACKUP_START=`date +%F%t%T`

echo "Your about to backup '$HOME' to $BACKUP_FILE" "Please enter $THIS_MACHINE's sudo password ->"
sudo sshfs "$USER@$DEST_SERVER:backups" /mnt/$DEST_SERVER -o allow_other 

function backup () {

echo "Creating /mnt/$DEST_SERVER/$BACKUP_FILE"
pushd $HOME
tar cvzi - \
 --exclude='*Cache*' --exclude='*chromium*' --exclude='*.config/Code/*'  \
 --exclude='*.config/Signal/*' --exclude='*.config/*torrent*/*' \
 --exclude='*.config/session/*' --exclude='*.config/libreoffice/*' --exclude='*.config/google-chrome/*'  \
 --exclude-caches-all --exclude-vcs --exclude-vcs-ignores --exclude-backups $DIRECTORIES \
 *.sh .vim* .bash* .configREM .tmux.conf | \
gpg -c --no-symkey-cache --batch --passphrase $GPG_PASS > /mnt/$DEST_SERVER/$BACKUP_FILE 2>&1 ;  
echo '#########################################################################'; 
ls -lah "/mnt/$DEST_SERVER/$BACKUP_FILE"; 
df -h "/mnt/$DEST_SERVER/$BACKUP_FILE";
#Remove older backups
find /mnt/$DEST_SERVER/$THIS_MACHINE*.tar.gz -mtime 1 -exec rm {} + 
echo '#########################################################################'; 
echo "Backed has finished of: $USER@$DEST_SERVER:backups/mnt/$DEST_SERVER/$BACKUPFILE"
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
gpg --decrypt --batch --passphrase $GPG_PASS "/mnt/$DEST_SERVER/$BACKUP_FILE" | \
tar tvz | awk -F " " '{print $6}' > /mnt/$DEST_SERVER/$BACKUP_INDEX ; 
echo "done with backup " `date` ", have a nice day!"

