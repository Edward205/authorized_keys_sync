#! /bin/bash

if [ "$(id -u)" -ne 0 ]; then 
  echo "Run this script as root, so that it can install in /opt and add a cron entry."
  exit
fi

echo -n "Enter authorized keys URL: "
read -r url

echo -n "Enter your signature: "
read -r signature

echo -n "Targeted user: "
read -r user

if [ -e "server_agent.sh" ]; then
  mkdir -p /opt/authorized_keys_sync
  path="/opt/authorized_keys_sync/server_agent_$user.sh"
  touch $path
  cat server_agent.sh | sed "s|<your_keys_url>|$url|g" | sed "s/<your_signature>/$signature/g" | sed "s/<your_user>/$user/g" | sed "s|<current_path>|$path|g" > $path
  chmod -R 700 /opt/authorized_keys_sync/

  cron_entry=$(crontab -l 2>&1) || true
  if [[ "$cron_entry" != *"$path"* ]]; then
    ( crontab -l 2>/dev/null; echo "0 */6 * * * /opt/authorized_keys_sync/server_agent_$user.sh" ) | crontab -
  else
    echo "Cron entry already exists for this script."
  fi

  sudo -u $user bash -c 'mkdir ~/.ssh' 2> /dev/null

  if grep -q -F "#PasswordAuthentication yes" "/etc/ssh/sshd_config"; then
    echo "Consider disabling PasswordAuthentication in /etc/ssh/sshd_config."
  fi

else
  echo "server_agent.sh must be in the same directory as this script."
fi

echo "Done."