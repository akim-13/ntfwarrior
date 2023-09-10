#!/data/data/com.termux/files/usr/bin/bash

XDG_DATA_HOME="/data/data/com.termux/files/home/.local/share"

read new_task

# Check if the required fields are present in the JSON data
if ! echo $new_task | jq 'has("uuid") and has("description") and has("ntf1")' | grep -q true; then
    termux-toast "ERROR: one or more fields are missing."
    exit 1
fi

uuid=$(echo $new_task | jq -r .uuid )
desc=$(echo $new_task | jq -r .description )


# E.g. 20230709T151010Z
ntf1_iso=$(echo $new_task | jq -r .ntf1 )
# E.g. 1688915410
ntf1_epoch=$(date -u -d "$(echo $ntf1_iso | sed -E 's/(....)(..)(..)T(..)(..)(..)Z/\1-\2-\3T\4:\5:\6Z/')" +%s)

cur_epoch=$(date -u +%s)
period_ms=$(((ntf1_epoch - cur_epoch)*1000))

ntf_file="$XDG_DATA_HOME/taskwarrior/ntfs/$uuid"
echo "if [ \"\$(date -u +%s)\" -lt \"$ntf1_epoch\" ]; then exit 0; fi" > $ntf_file

echo "termux-notification --content \"$desc\"" >> $ntf_file
# int from 1 to 32767
job_id=$RANDOM
echo "termux-job-scheduler --cancel --job-id $job_id" >> $ntf_file
chmod +x $ntf_file

termux-job-scheduler --script $ntf_file --job-id $job_id --period-ms $period_ms --persisted true --battery-not-low false > /dev/null

# Task json
echo $new_task
# Feedback (terminal output)
echo Task with notification created
#termux-toast "Task created"

# termux-notification --button1 "New task" --button1-action "termux-toast \$REPLY" --id 1 --ongoing --title Daemon --alert-once
