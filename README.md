# Authorized keys sync
Securely sync the list of authorized keys for your SSH servers using just a few bash scripts.

## How it works?

You host the authorized keys list on a web host, and configure `cron` on your servers to periodically fetch new keys. The authorized keys list is **signed** with your GPG key, and the signature is checked when new keys are fetched such that attackers won't be able to access all of your servers if they obtain access to your web host. 

## Installation

Dependencies: bash, curl, gpg, cron. Tested on Debian 12 bookworm.

1. Export your public key: `gpg --output public.gpg --export me@example.com`
    
    Transfer it to your target server and import it to the `root` user: `sudo gpg --import public.gpg`

2. Generate the signed list of authorized keys and upload it to your web host

    `./add_client.sh`

    Follow the instructions to add the keys that are on your computer, and any other ones that you might need.

3. Upload the signed list of authorized keys to a public URL. Make sure you are able to edit it, so you can add more keys later

4. Run the installation script (`install_agent.sh`) on each server

    You'll need to enter the URL where the keys are hosted, your signature (`gpg -K`) and the targeted user (the user for which the `authorized_keys` file will be synced). **Don't manually modify `server_agent.sh`,** the script will do it for you.

    The server agent is installed in `/opt/authorized_keys_sync/` under the `root` user, and a cron will be set. Every 6 hours, it will download the keys from the URL, check their signature and replace them with the new version.

### Uninstallation

1. Remove the `/opt/authorized_keys_sync/` folder
2. Remove the cron jobs with `sudo crontab -e`

## Security

The server agent verifies the message in memory, to avoid the possibility of tampering the `tmp` folder. An attacker must have root access to exploit it.

Signed authorized key lists are versioned, meaning they cannot be replayed and once the server agent updates the list to a new version, it will reject any older versions.