#!/data/data/com.termux/files/usr/bin/bash

XDG_DATA_HOME="/data/data/com.termux/files/home/.local/share"
rc="/data/data/com.termux/files/home/.config/taskwarrior/taskrc"

read new_task

# Check if the required fields are present in the JSON data
if ! echo $new_task | jq 'has("uuid") and has("description") and has("ntf1") and has("due")' | grep -q true; then
    echo
    echo "ERROR: can't process hook, missing fields."
    exit 1
fi

uuid=$(echo $new_task | jq -r .uuid )
desc=$(echo $new_task | jq -r .description )
# E.g. 23:00 on 17/09
due=$(echo $new_task | jq -r .due | awk '{printf "%s:%s on %s/%s\n", substr($0, 10,2), substr($0, 13,2), substr($0,5,2), substr($0,7,2)}')


# E.g. 20230709T151010Z
ntf1_iso=$(echo $new_task | jq -r .ntf1 )
# E.g. 1688915410
ntf1_epoch=$(date -u -d "$(echo $ntf1_iso | sed -E 's/(....)(..)(..)T(..)(..)(..)Z/\1-\2-\3T\4:\5:\6Z/')" +%s)

cur_epoch=$(date -u +%s)
period_ms=$(((ntf1_epoch - cur_epoch)*1000))

ntf_file="$XDG_DATA_HOME/taskwarrior/ntfs/$uuid"
echo "if [ \"\$(date -u +%s)\" -lt \"$ntf1_epoch\" ]; then exit 0; fi" > $ntf_file

# int from 1 to 32767
rand_id=$RANDOM

# For testing
#termux-notification --title "$desc" --content "Due at $due" --button1 "Start/Stop" --button1-action "task rc:$rc +ACTIVE _uuids | grep -q \"^$uuid$\" && (task rc:$rc stop $uuid && termux-toast Task stopped) || (task rc:$rc start $uuid && termux-toast Task started)" --button2 "Done" --button2-action "task rc:$rc done $uuid && termux-notification-remove $rand_id" --id $rand_id --ongoing

echo "termux-notification --title \"$desc\" --content \"Due at $due\" --button1 \"Start/Stop\" --button1-action \"task rc:$rc +ACTIVE _uuids | grep -q '^'\"$uuid\"'$' && (task rc:$rc stop $uuid && termux-toast Task stopped) || (task rc:$rc start $uuid && termux-toast Task started)\" --button2 \"Done\" --button2-action \"task rc:$rc done $uuid && termux-notification-remove $rand_id\" --id $rand_id --ongoing" >> $ntf_file
#echo "termux-notification --title \"$desc\" --content \"Due $due\" --button1 \"Start/Stop\" --button1-action \"echo\" --button2 \"Done\" --button2-action \"task rc:$rc done $uuid && termux-notification-remove $rand_id\" --id $rand_id --ongoing" >> $ntf_file

echo "termux-job-scheduler --cancel --job-id $rand_id" >> $ntf_file
chmod +x $ntf_file

termux-job-scheduler --script $ntf_file --job-id $rand_id --period-ms $period_ms --persisted true --battery-not-low false > /dev/null

# Task json
echo $new_task
# Feedback (terminal output)
echo

