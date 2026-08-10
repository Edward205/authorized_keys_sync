#! /bin/bash

AUTHORIZED_KEYS_URL="<your_keys_url>"
SIGNATURE="<your_signature>"
TARGET_USER="<your_user>"
SCRIPT_PATH="<current_path>"
VERSION=0

message="$(curl -s "$AUTHORIZED_KEYS_URL")"

signed_by="$(echo -ne "$message" | gpg --status-fd=1 --verify - 2> /dev/null | awk '/^\[GNUPG:\] VALIDSIG / { print $3; exit }')"
if [[ -n "$SIGNATURE" && "$signed_by" == "$SIGNATURE" ]]; then

  content="$(gpg --decrypt <<< "$message" 2>/dev/null)"
  got_version=$(("$(echo -e "$content" | head -n 1)"))
  if [[ $got_version -gt $VERSION ]]; then
    content="$(echo -e "$content" | tail -n +2)"
    sed -i "0,/VERSION=$VERSION/s//VERSION=$got_version/" $SCRIPT_PATH
    printf '%s\n' "$content" | sudo -u "$TARGET_USER" tee "/home/$TARGET_USER/.ssh/authorized_keys" >/dev/null
    sudo -u $TARGET_USER bash -c 'chmod 600 ~/.ssh/authorized_keys'
  else
    echo "Message version has already been consumed."
  fi


else
  echo "Message signature doesn't match the expected signature or is invalid." >&2
  # send error to a webhook? 
fi