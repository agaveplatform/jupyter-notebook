#!/bin/sh
KEYS_PATH=${KEYS_PATH:-$HOME/.ssh}
PRIVATE_KEY=$KEYS_PATH/id_rsa
PUBLIC_KEY=${PRIVATE_KEY}.pub
#set -x
if [ -n "$ROTATE" ]; then

    OLD_KEY_TIMESTAMP=$(date +%s)
    OLD_PRIVATE_KEY=${KEYS_PATH}/id_rsa-${OLD_KEY_TIMESTAMP}
    OLD_PUBLIC_KEY=${OLD_PRIVATE_KEY}.pub

    [ -n "$KEYGEN_DEBUG" ] && echo "Existing keys will be backed up before generating new keys"

    [ -f "$PRIVATE_KEY" ] && mv $PRIVATE_KEY $OLD_PRIVATE_KEY
    [ -n "$KEYGEN_DEBUG" ] && echo "$PRIVATE_KEY => $OLD_PRIVATE_KEY"

    [ -f "$PUBLIC_KEY" ] && mv $PUBLIC_KEY $OLD_PUBLIC_KEY
    [ -n "$KEYGEN_DEBUG" ] && echo "$PUBLIC_KEY => $OLD_PUBLIC_KEY"

    #[ -n "$KEYGEN_DEBUG" ] && ls -al $KEYS_PATH
    #[ -n "$KEYGEN_DEBUG" ] && echo "\n"

#    if [ -f "$KEYS_PATH/authorized_keys" ]; then
#        sed -i '/^.* jovyan@.*$/d' $KEYS_PATH/authorized_keys
#    fi
fi

if [ ! -f "$PRIVATE_KEY" ] || [ -n "$REPLACE" ]; then

  [ -n "$KEYGEN_DEBUG" ] && echo "Writing key pair to ${KEYS_PATH}..."

  if [ -n "$REPLACE" ]; then

    [ -n "$DEBUG" ] && echo "Existing keys will be replaced."
    rm -f $PRIVATE_KEY $PUBLIC_KEY

    if [ -f "$KEYS_PATH/authorized_keys" ]; then

        # remove old public key from authorized keys
        [ -n "$KEYGEN_DEBUG" ] && echo "Removing previous keys from authorized_keys file..."

        sed -i '/^.* '$(whoami)'@.*$/d' $KEYS_PATH/authorized_keys

        [ -n "$KEYGEN_DEBUG" ] && echo "Pruned authorized_keys file:"
        [ -n "$KEYGEN_DEBUG" ] && cat $KEYS_PATH/authorized_keys
        [ -n "$KEYGEN_DEBUG" ] && echo "\n"
    fi
  fi

  /usr/bin/ssh-keygen -q -t rsa -N '' -f $PRIVATE_KEY
  chmod 700 $KEYS_PATH
  chmod 644 $PUBLIC_KEY
  chmod 600 $PRIVATE_KEY


  if [ ! -f "$KEYS_PATH/authorized_keys" ]; then

    [ -n "$KEYGEN_DEBUG" ] && echo "Creating missing authorized_keys file. Current file is owned by $(whoami). Ensure the file has the rights of the intended user..."

    touch "$KEYS_PATH/authorized_keys"

  fi

  [ -n "$KEYGEN_DEBUG" ] && echo "Appending new public key to authorized_keys file..."
#    echo ""
#    echo "Before appending authorized key...\n"
#    cat $KEYS_PATH/authorized_keys
    echo "command=\"/home/jovyan/.singularitycheck.sh\" $(cat $PUBLIC_KEY)" >> $KEYS_PATH/authorized_keys
#    echo "After appending authorized key...\n"
  [ -n "$KEYGEN_DEBUG" ] && echo "Updated authorized_keys file:"
  [ -n "$KEYGEN_DEBUG" ] && cat $KEYS_PATH/authorized_keys

else

  echo "Private key already exists and will be used. You may rotate the current key by setting the \"ROTATE\" environment variable or overwrite it by setting the \"REPLACE\" environment variable."

fi

echo "========= PUBLIC KEY ============"
cat $PUBLIC_KEY
echo "======= END PUBLIC KEY ========="

exit 0

