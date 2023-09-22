#!/data/data/com.termux/files/usr/bin/bash

XDG_DATA_HOME="/data/data/com.termux/files/home/.local/share"
rc="/data/data/com.termux/files/home/.config/taskwarrior/taskrc"

read new_task

# Check if the required fields are present in the JSON data.
if ! echo $new_task | jq 'has("uuid") and has("description") and has("ntf1") and has("due") and has("status")' | grep -q true; then
    echo
    echo "ERROR: can't process hook, missing fields."
    exit 1
fi

uuid=$(echo $new_task | jq -r .uuid )
desc=$(echo $new_task | jq -r .description )

# E.g. 20230709T151010Z
ntf1_iso=$(echo $new_task | jq -r .ntf1 )
due_iso=$(echo $new_task | jq -r .due)

# Everything has to be converted to epoch to do arithmetic
# operations and avoid potential time zones discrepancies.
# E.g. 1688915410
ntf1_epoch=$(date -u -d "$(echo $ntf1_iso | sed -E 's/(....)(..)(..)T(..)(..)(..)Z/\1-\2-\3T\4:\5:\6Z/')" +%s)
due_epoch=$(date -u -d "$(echo $due_iso | sed -E 's/(....)(..)(..)T(..)(..)(..)Z/\1-\2-\3T\4:\5:\6Z/')" +%s)
cur_epoch=$(date -u +%s)

stat=$(echo $new_task | jq -r .status )
# Check if task is recurring.
if jq -e 'has("rtype")' <<< "$new_task" > /dev/null; then
	# Skip task if it is a recurrence template.
	if [[ "$stat" == "recurring" ]]; then
		echo $new_task
		echo
		exit 0
	# Update ntf1_epoch according to the difference between `due` and `ntf1` of the recurrence template (parent task).
	elif jq -e 'has("parent")' <<< "$new_task" > /dev/null; then
		parent_uuid=$(echo $new_task | jq -r .parent )
		# Cannot use `task` command, creates infinite loop,
		# therefore find the first line containing parent uuid in the data file.
		par_data=$(grep -m 1 "$parent_uuid" /data/data/com.termux/files/home/.local/share/taskwarrior/pending.data)
		due_par_epoch=$(echo "$par_data" | awk -F 'due:' '{print $2}' | cut -d ' ' -f 1 | tr -d '"')
		ntf1_par_epoch=$(echo "$par_data" | awk -F 'ntf1:' '{print $2}' | cut -d ' ' -f 1 | tr -d '"')
		ntf1_epoch=$(( due_epoch - (due_par_epoch - ntf1_par_epoch) ))
	else
		echo
		echo "Error: wtf is this task"
		exit 1
	fi
fi

ntf1_period_ms=$(( (ntf1_epoch - cur_epoch)*1000 ))
ntf1_iso_converted=$(date -u -d "@$ntf1_epoch" +"%Y%m%dT%H%M%SZ")

# Update the actual ntf1 json.
new_task=$(echo "$new_task" | jq --arg new_val "$ntf1_iso_converted" '.ntf1 = $new_val')

# E.g. 5:30pm on 20/09 (Wed)
due_formatted=$(date -d "@$due_epoch" +"%I:%M %p on %d/%m (%a)")

# Create ntf directory if it doesn't exist.
ntf_dir="$XDG_DATA_HOME"/taskwarrior/ntfs
if [[ ! -d "$ntf_dir" ]]; then
    mkdir "$ntf_dir"
fi

ntf_file="$ntf_dir/$uuid"
echo "if [ \"\$(date -u +%s)\" -lt \"$ntf1_epoch\" ]; then exit 0; fi" > $ntf_file

# int from 1 to 32767
rand_id=$RANDOM

# For testing
#termux-notification --title "$desc" --content "$due_formatted" --button1 "Start/Stop" --button1-action "task rc:$rc +ACTIVE _uuids | grep -q '^'"$uuid"'$' && (task rc:$rc stop $uuid && termux-toast Task stopped) || (task rc:$rc start $uuid && termux-toast Task started)" --button2 "Done" --button2-action "task rc:$rc done $uuid && termux-notification-remove $rand_id" --button3 "Dismiss" --button3-action "termux-notification-remove $rand_id" --id $rand_id --ongoing

echo "termux-notification --title \"$desc\" --content \"$due_formatted\" --button1 \"Start/Stop\" --button1-action \"task rc:$rc +ACTIVE _uuids | grep -q '^'\"$uuid\"'$' && (task rc:$rc stop $uuid && termux-toast Task stopped) || (task rc:$rc start $uuid && termux-toast Task started)\" --button2 \"Done\" --button2-action \"task rc:$rc done $uuid && termux-notification-remove $rand_id\" --button3 \"Dismiss\" --button3-action \"termux-notification-remove $rand_id\" --id $rand_id --ongoing" >> $ntf_file

echo "termux-job-scheduler --cancel --job-id $rand_id" >> $ntf_file
chmod +x $ntf_file

termux-job-scheduler --script $ntf_file --job-id $rand_id --period-ms $ntf1_period_ms --persisted true --battery-not-low false > /dev/null

# Task json
echo $new_task
# Feedback (terminal output)
echo

