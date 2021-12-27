#!/bin/bash
#login user@email.com xxxxxxxxxxxxxxxxxxxxxxxxxxxx
#sync /home/user/backups /backups
mega-cmd <<EOF
sync /mnt/your_server/backups /backups
cd backups
ls
EOF
# On server to put on mega cloud /backups folder.
#
## pane 1
#  tmux split-window -v
#  tmux send-keys -t $SN:1 'mega-login user@email.com "xxxxxxxxxxxxxxxxxxxxxxxxxxxx"' C-m
#  tmux send-keys -t $SN:1 'mega-sync /home/user/backups /backups' C-m
#

