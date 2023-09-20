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

# E.g. 20230709T151010Z
ntf1_iso=$(echo $new_task | jq -r .ntf1 )
due_iso=$(echo $new_task | jq -r .due)
# E.g. 1688915410
# Everything has to be converted to epoch to do arithmetic
# operations and avoid time zones discrepancies.
ntf1_epoch=$(date -u -d "$(echo $ntf1_iso | sed -E 's/(....)(..)(..)T(..)(..)(..)Z/\1-\2-\3T\4:\5:\6Z/')" +%s)
due_epoch=$(date -u -d "$(echo $due_iso | sed -E 's/(....)(..)(..)T(..)(..)(..)Z/\1-\2-\3T\4:\5:\6Z/')" +%s)
cur_epoch=$(date -u +%s)

# E.g. ntf1:1h means ntf will come 1h before the due date.
ntf1_period=$((ntf1_epoch - cur_epoch))
ntf1_rel_to_due=$((due_epoch - ntf1_period))

# If ntf1:due, i.e. notification comes when the task is due.
if [[ "$ntf1_epoch" -eq "$due_epoch" ]]; then
    ntf1_rel_to_due_period_ms=$(( ntf1_period*1000 ))
    ntf1_rel_to_due_iso=$(date -u -d "@$ntf1_epoch" +"%Y%m%dT%H%M%SZ")
else
    ntf1_rel_to_due_period_ms=$(( (ntf1_rel_to_due - cur_epoch)*1000 ))
    ntf1_rel_to_due_iso=$(date -u -d "@$ntf1_rel_to_due" +"%Y%m%dT%H%M%SZ")
fi

# Update the actual ntf1 json.
new_task=$(echo "$new_task" | jq --arg new_val "$ntf1_rel_to_due_iso" '.ntf1 = $new_val')

# E.g. 5:30pm on 20/09 (Wed)
due_formatted=$(date -d "@$due_epoch" +"%I:%M %p on %d/%m (%a)")

ntf_file="$XDG_DATA_HOME/taskwarrior/ntfs/$uuid"
echo "if [ \"\$(date -u +%s)\" -lt \"$ntf1_epoch\" ]; then exit 0; fi" > $ntf_file

# int from 1 to 32767
rand_id=$RANDOM

# For testing
#termux-notification --title "$desc" --content "$due_formatted" --button1 "Start/Stop" --button1-action "task rc:$rc +ACTIVE _uuids | grep -q '^'"$uuid"'$' && (task rc:$rc stop $uuid && termux-toast Task stopped) || (task rc:$rc start $uuid && termux-toast Task started)" --button2 "Done" --button2-action "task rc:$rc done $uuid && termux-notification-remove $rand_id" --button3 "Dismiss" --button3-action "termux-notification-remove $rand_id" --id $rand_id --ongoing

echo "termux-notification --title \"$desc\" --content \"$due_formatted\" --button1 \"Start/Stop\" --button1-action \"task rc:$rc +ACTIVE _uuids | grep -q '^'\"$uuid\"'$' && (task rc:$rc stop $uuid && termux-toast Task stopped) || (task rc:$rc start $uuid && termux-toast Task started)\" --button2 \"Done\" --button2-action \"task rc:$rc done $uuid && termux-notification-remove $rand_id\" --button3 \"Dismiss\" --button3-action \"termux-notification-remove $rand_id\" --id $rand_id --ongoing" >> $ntf_file

echo "termux-job-scheduler --cancel --job-id $rand_id" >> $ntf_file
chmod +x $ntf_file

termux-job-scheduler --script $ntf_file --job-id $rand_id --period-ms $ntf1_rel_to_due_period_ms --persisted true --battery-not-low false > /dev/null

# Task json
echo $new_task
# Feedback (terminal output)
echo

