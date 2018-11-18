#!/bin/bash

#set -x

sshopts="-o StrictHostKeyChecking=no"

session_name="workstation"
password=""

vms=("centralmsvm" "centralinfravm" "centralk8mastervm" "canvm" "regional_sblb" "vrr")

canvm=($(grep canvm /etc/hosts | awk '{print $1}'))
centralinfravm=($(grep centralinfravm /etc/hosts | awk '{print $1}'))
centralk8mastervm=($(grep centralk8mastervm /etc/hosts | awk '{print $1}'))
centralmsvm=($(grep centralmsvm /etc/hosts | awk '{print $1}'))
regional_sblb=($(grep regional-sblb /etc/hosts | awk '{print $1}'))
vrr=($(grep vrr /etc/hosts | awk '{print $1}'))

function expect-func {
    echo "
stty -echo
spawn ssh ${sshopts} -t root@$1
expect \"yes/no\" {
        send \"yes\r\"
        expect \"*?assword\" { send \"$2\r\" }
} \"*?assword\" { send \"$2\r\" }

interact
"
}

function tmux-send {
  name="$1-$3"
  result=$(expect-func $2 ${password})
  tmux new-window -n $name
  tmux send-keys -t ${session_name}:$3  "expect -c '${result}'" ENTER
  tmux send-keys -t ${session_name}:$3  "clear" ENTER
}


if ! tmux list-sessions -F '#{session_name}' 2>&1 | grep --quiet ${session_name}; then
  echo -n Remote ssh password for root:
  read -s password
  tmux start-server
  tmux new-session -d -s ${session_name} -n host
  tmux set-option -t ${session_name} -g -w allow-rename off
  tmux set-option -t ${session_name} -g history-limit 100000
  if tmux -V |awk '{split($2, ver, "."); if (ver[1] < 2) exit 1 ; else if (ver[1] == 2 && ver[2] < 1) exit 0 }'; then
     tmux set-option -t ${session_name} -g mouse-utf8 on
     tmux set-option -t ${session_name} -g mouse on
  else 
     tmux set-option -t ${session_name} -g mode-mouse on
     tmux set-option -t ${session_name} -g mouse-resize-pane on
     tmux set-option -t ${session_name} -g mouse-select-pane on
     tmux set-option -t ${session_name} -g mouse-select-window on
  fi
  wnum=1
  for v in "${vms[@]}"; do
     arr=${!v}
     [[ ${#arr[@]} -ge 0 ]] && for i in "${arr[@]}"; do tmux-send $v $i $wnum; wnum=$((wnum+1)); done
  done
  tmux select-window -t ${session_name}:0
fi
tmux attach-session -t ${session_name}
