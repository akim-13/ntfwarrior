#!/data/data/com.termux/files/usr/bin/bash

TASKRC="/data/data/com.termux/files/home/.config/taskwarrior/taskrc"
# Cool bash 4.0+ feature to make $1 lowercase
input="${1,,}"
output=$(eval "task rc:$TASKRC $input" 2>&1)

/data/data/com.termux/files/home/.config/taskwarrior/start_daemon "$output"

#termux-notification --title "Daemon" --action "bash -lc 'am start --user 0 -n com.termux/com.termux.app.TermuxActivity && $XDG_CONFIG_HOME/taskwarrior/start_daemon'" --button1 "Add" --button1-action "bash -lc '$XDG_CONFIG_HOME/taskwarrior/new_task \$REPLY'" --button2 "List" --button2-action "bash -lc '$XDG_CONFIG_HOME/taskwarrior/list_tasks'" --button3 "CMD" --button3-action "bash -lc '$XDG_CONFIG_HOME/taskwarrior/cmd \$REPLY'" --content "$output" --id 1 --ongoing --alert-once --group "daemon"
