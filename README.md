# Backup List Restore via SSHFS

Backup List Restore via an Secure Shell Files System Mount.
The backup is directly over ssh created, is encoded and compressed on the remote system or server.
It is a modifiable, selective backup system, where known application and none required meta data is skipped.
Thus saving you space and backup and restore time, by at least %30.

## Installation

You are required sudo access, and have the following linux packages installed:
```
sudo apt install ssh -y
sudo apt install sshfs -y
sudo apt install gpg -y
sudo apt install pv -y
```
Install also [FZF](https://github.com/junegunn/fzf), to use the awesome **list.sh** script.

### To install this project

```
git clone https://github.com/wbudic/B_L_R_via_sshf
```

## Configuration

Create a mount point, ever once before runing any oth scripts.
```
sudo mkdir /mnt/{REMOTE_SERVER_ALIAS_OR_IP}
```

It is recomended to use an alias in the script. Which is set by modifying your **/etc/hosts** file. And by assigning the remote destination IP address to an alias.

* Update **backup.config** to this remote server alias, to read:

  ```BASH
  DEST_SERVER={REMOTE_SERVER_ALIAS_OR_IP}
  ```
 * Make also further changes in the config file as necessary, depending on your system.
 * Update and change directories in the **backup.sh** script, to suit your home directory.

## Running

./**backup.sh** can be called from any directory.

To restore home root directory is required or an temporary one, with or without an list of files to extract.
Files then can be observed or moved once restored, to desired location.
Examples:

```BASH
you@your_pc:$ mkdir ~/temp/backup; cd ~/temp/backup
you@your_pc:~/temp/backup$ ~/restore.sh restore.lst
```
To create a selective restore list of one or many files. Run ./**list.sh** in the directory you want to restore to. You can select multiple files by highlighting the file in a line and pressing the **tab** key.
```BASH
you@your_pc:~/temp/backup$ ~/list.sh
```
or
```
you@your_pc:~/temp/backup$ ~/list.sh -?
```
to see help on further options.


## Vim Integration

To capture and observe the backup in vim. It is recomended to use the AsyncRun plugin.

Activate the backup in vim with command:

```BASH
:AsyncRun -mode=term -pos=tab ./backup.sh
```
This can take a long time, you can create a new window while it is busy, and/or to navigate to previous tab.
**<ctrl>ws** **gt**

Notice - Large backup list are in raw text format in a terminal, they will not hog your computer or require as much memory as an word document.



