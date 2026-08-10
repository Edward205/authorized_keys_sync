#! /bin/bash

echo -n "Existing authorized keys URL (leave blank if new): "
read -r url

# assemble list of keys
if [[ -z "$url" ]]; then
  echo "Creating new..."
  keys=()
  version=0
elif [[ -n "$url" ]]; then
  echo "Downloading existing authorized keys..."
  keys_to_parse="$(curl -s "$url" --max-time 5)"
  
  keys=()
  if content="$(gpg --decrypt <<< "$keys_to_parse" 2>/dev/null)"; then
    echo "Signature is valid"
    version=$(( $(("$(echo -e "$content" | head -n 1)")) + 1 )) 
    content="$(echo -e "$content" | tail -n +2)" # remove version number in the first line
    # convert newline separated list to array
    mapfile -t keys <<< "$content"
  else
    echo "Signature is NOT valid. File may be corrupt."
    exit 1
  fi
fi

all_keys=(~/.ssh/*)
public_keys=()
for i in "${all_keys[@]}"; do
  if [[ "${i##*.}" == "pub" ]]; then
    public_keys=("${public_keys[@]}" "$i")
  fi
done

another_choice="y"
while [[ $another_choice == "y" ]]; do
  echo -n "Add or Remove keys [A/r]: "
  read -r operation
  if [[ $operation == "r" ]]; then
    # remove a key
    if [[ "${#keys[@]}" -eq 0 ]]; then
      echo "There are no keys."
    else
      for i in "${!keys[@]}"; do
        echo "  $(($i+1)). ${keys[$i]}"
      done
      echo -n "Which key would you like to remove: "
      read -r to_remove
      ((to_remove--))
      unset keys[$to_remove]
    fi
  else
    # add a key
    for i in "${!public_keys[@]}"; do
      echo "  ${i+1}. ${public_keys[$i]}"
    done
    echo "  $(( ${#public_keys[@]} + 1 )). Manual input"
    echo -n "Which key would you like to add: "
    read -r key_i
    ((key_i--))

    key_to_add=""
    if [[ $key_i -ne $(( ${#public_keys[@]} )) ]]; then 
      key_to_add+="$(cat ${public_keys[$key_i]})"
    else
      echo -n "Enter an SSH public key: "
      read -r manual
      key_to_add="$manual"
    fi

    # check duplicate
    is_duplicate=0
    for i in "${keys[@]}"; do
      if [[ $key_to_add == "$i" ]]; then
        is_duplicate=1
        break
      fi
    done
    if [[ $is_duplicate -eq 1 ]]; then
      echo "Duplicate found. Key wasn't added."
    else
      keys+=("$key_to_add")
    fi
  fi

  echo "Currently added keys:"
  if [[ "${#keys[@]}" -eq 0 ]]; then
    echo "none"
  else
    for i in "${!keys[@]}"; do
      echo "  ${keys[$i]}"
    done
  fi

  echo -n "Do another operation? [y/N]: "
  read -r another_choice
  if [[ $another_choice == "Y" || $another_choice == "yes" ]]; then # a bit of normalisation
    another_choice="y"
  fi
done

# convert keys to string
keys_string=""
for i in "${keys[@]}"; do
  keys_string="$i\n$keys_string"
done

# sign string
echo -ne "$version\n$keys_string" | gpg --clearsign > /tmp/signed_authorized_keys

echo -e "\n$(cat /tmp/signed_authorized_keys)"
rm "/tmp/signed_authorized_keys"
# upload keys to server with scp