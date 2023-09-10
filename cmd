#!/data/data/com.termux/files/usr/bin/bash

TASKRC="/data/data/com.termux/files/home/.config/taskwarrior/taskrc"

input=$1

eval "task rc:$TASKRC $input"
