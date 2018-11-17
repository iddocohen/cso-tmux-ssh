#!/bin/bash

#set -x

sshopts="-o StrictHostKeyChecking=no"

session_name="workstation"
password=""

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
  #tmux send-keys -t ${session_name}:1  "mkfifo ssh-file; echo '${result}' > ssh-file &" C-m
  #tmux send-keys -t ${session_name}:1  "expect -f ssh-file; rm -f ssh-file" C-m
  tmux send-keys -t ${session_name}:$3  "expect -c '${result}'" ENTER
  tmux send-keys -t ${session_name}:$3  "clear" ENTER
}

if ! tmux list-sessions -F '#{session_name}' 2>&1 | grep --quiet ${session_name}; then
  echo -n Password:
  read -s password
  tmux start-server
  tmux new-session -d -s ${session_name} -n host
  tmux set-option -t ${session_name} -g -w allow-rename off
  tmux set-option -t ${session_name} -g history-limit 100000
  if tmux -V |awk '{split($2, ver, "."); if (ver[1] < 2) exit 1 ; else if (ver[1] == 2 && ver[2] < 1) exit 1 }'; then
     tmux set-option -t ${session_name} -g mouse-utf8 on
     tmux set-option -t ${session_name} -g mouse on
  else 
     tmux set-option -t ${session_name} -g mode-mouse on
     tmux set-option -t ${session_name} -g mouse-resize-pane on
     tmux set-option -t ${session_name} -g mouse-select-pane on
     tmux set-option -t ${session_name} -g mouse-select-window on
  fi
  wnum=1
  [[ -n ${centralmsvm} ]] && for i in "${centralmsvm[@]}"; do tmux-send centralmsvm $i $wnum; wnum=$((wnum+1)); done
  [[ -n ${centralinfravm} ]] && for i in "${centralinfravm[@]}"; do tmux-send centralinfravm $i $wnum; wnum=$((wnum+1)); done
  [[ -n ${centralk8mastervm} ]] && for i in "${centralk8mastervm[@]}"; do tmux-send centralk8mastervm $i $wnum; wnum=$((wnum+1)); done
  [[ -n ${canvm} ]] && for i in "${canvm[@]}"; do tmux-send canvm $i $wnum; wnum=$((wnum+1)); done
  [[ -n ${regional_sblb} ]] && for i in "${regional_sblb[@]}"; do tmux-send regional_sblb $i $wnum; wnum=$((wnum+1)); done
  [[ -n ${vrr} ]] && for i in "${vrr[@]}"; do tmux-send vrr $i $wnum; wnum=$((wnum+1)); done
  
  #[[ -n ${centralinfravm} ]] && tmux new-window -n centralinfravm "sudo ssh ${sshopts} ${centralinfravm}"
  #[[ -n ${centralk8mastervm} ]] && tmux new-window -n centralk8mastervm "sudo ssh ${sshopts} ${centralk8mastervm}"
  #[[ -n ${centralmsvm} ]] && tmux new-window -n centralmsvm "sudo ssh ${sshopts} ${centralmsvm}"
  #[[ -n ${regional_sblb} ]] && tmux new-window -n regional_sblb "sudo ssh ${sshopts} ${regional_sblb}"
  #[[ -n ${vrr} ]] && tmux new-window -n vrr "sudo ssh ${sshopts} ${vrr}"
  tmux select-window -t ${session_name}:1
fi
tmux attach-session -t ${session_name}
