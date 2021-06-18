#!/bin/bash
# Includes
SRC_DIR=`dirname "$0"`
. $SRC_DIR/backup.config
#
echo -e "\nYour are about to restore from '$DEST_SERVER'" "Please enter $THIS_MACHINE's sudo password ->"
sudo sshfs "$USER@$DEST_SERVER:backups" /mnt/$DEST_SERVER -o allow_other 

RESTORE_FILE=$(ls /mnt/$DEST_SERVER/$THIS_MACHINE-*.$EXT_ENC|tail -n 1)
if [[ -f $RESTORE_FILE ]] 
then
echo "Located backup file is -> $RESTORE_FILE"
	else
echo "No backup file has been found!"
exit;
fi


if [[ "." = "$SRC_DIR" ]]
then
	echo "Error, you are in the backup source directory: $PWD!"
	exit 1;
fi

##
if [[ -z $1 ]]
then
	echo -e "No list of files has been provided, the whole backup will be restored into '$PWD' directory."
	read -p "Are you sure you want to proceed? (Answer Yes/No): " rep; 
	if [[ $rep =~ ^Y|^y ]]
	then
          gpg --decrypt --batch --passphrase $GPG_PASS $RESTORE_FILE | tar -Jxv; 
	else
	     echo "Restore has been skipped.";
	     exit 1;
	fi
else 
echo "Restoring files from $1..."
gpg --decrypt --batch --passphrase $GPG_PASS $RESTORE_FILE | tar xvJ --files-from $1 $2 $3 $4 $5; 
echo "done with restore from $RESTORE_FILE" `date` ", have a nice day!"
fi
# This file originated from https://github.com/wbudic/B_L_R_via_sshfs