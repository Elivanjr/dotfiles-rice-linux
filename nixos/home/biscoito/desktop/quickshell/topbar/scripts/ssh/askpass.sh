#!/bin/sh
# askpass.sh — o ssh chama este script quando precisa de senha ou passphrase
# (SSH_ASKPASS + SSH_ASKPASS_REQUIRE=force, definidos no SshWidget.qml).
# O texto do prompt chega em $1; o que for digitado sai no stdout.
exec zenity --entry --hide-text --title="Autenticação SSH" --text="$1" 2>/dev/null
