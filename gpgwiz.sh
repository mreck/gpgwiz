#!/bin/sh

[ -z "$GPG_WIZ_SUBKEY_EXPIRE" ] && GPG_WIZ_SUBKEY_EXPIRE='1y'
[ -z "$GPG_WIZ_EXPORT_DIR" ]    && GPG_WIZ_EXPORT_DIR='.'

log() {
    echo ''
    echo "[gpg-wiz] $@"
    echo ''
}

log_error() {
    log "ERROR: $@"
    exit 1
}

require_exec() {
    for e in "$@"; do
        if [ ! -x "$(which $e)" ]; then
            log_error "Missing requirement! Executable '$e' not found."
        fi
    done
}

get_gpg_home() {
    if [ ! -z "$GNUPGHOME" ]; then
        echo "$GNUPGHOME"
    else
        echo "$HOME/.gnupg"
    fi
}

action_full_gen() {
    require_exec gpg

    log "Please provide the basic information for GPG"

    read -p "email > " email
    [ -z "$email" ] && log_error "Email can not be empty"

    read -p "name > " name
    [ -z "$name" ] && log_error "Name can not be empty"

    log "Where do you want to store the generated files? (default '.')"

    read -p "dir > " dir
    [ ! -z "$dir" ] && GPG_WIZ_EXPORT_DIR="$dir"
    if [ -d "$GPG_WIZ_EXPORT_DIR" ] && log_error "directory \"$GPG_WIZ_EXPORT_DIR\" does not exist"

    file_sec="$GPG_WIZ_EXPORT_DIR/$email.sec.asc"
    file_pub="$GPG_WIZ_EXPORT_DIR/$email.pub.asc"
    file_sub="$GPG_WIZ_EXPORT_DIR/$email.sub-sec.asc"
    file_rev="$GPG_WIZ_EXPORT_DIR/$email.rev"

    log "generating master key..."

    timestamp="$(date +%s)"
    file_cmd="/tmp/gpg_wiz_cmd_$timestamp"

    touch "$file_cmd"
    echo "%echo Generating master key" >> "$file_cmd"
    echo "Key-Type: RSA"               >> "$file_cmd"
    echo "Key-Length: 4096"            >> "$file_cmd"
    echo "Key-Usage: sign"             >> "$file_cmd"
    echo "Name-Real: $name"            >> "$file_cmd"
    echo "Name-Email: $email"          >> "$file_cmd"
    echo "Expire-Date: 0"              >> "$file_cmd"
    echo "%commit"                     >> "$file_cmd"
    echo "%echo done"                  >> "$file_cmd"

    gpg --batch --generate-key "$file_cmd"

    log "generating sub-keys..."

    fpr="$( gpg --list-secret-keys "$email" | sed -n '2p' | sed 's/ //g' )"

    gpg --quick-add-key "$fpr" "rsa4096" "sign"    "$GPG_WIZ_SUBKEY_EXPIRE"
    gpg --quick-add-key "$fpr" "rsa4096" "auth"    "$GPG_WIZ_SUBKEY_EXPIRE"
    gpg --quick-add-key "$fpr" "rsa4096" "encrypt" "$GPG_WIZ_SUBKEY_EXPIRE"

    log "exporting keys..."

    gpg --armor --export-secret-keys    "$fpr" > "$file_sec"
    gpg --armor --export                "$fpr" > "$file_pub"
    gpg --armor --export-secret-subkeys "$fpr" > "$file_sub"

    cp -v "$(get_gpg_home)/openpgp-revocs.d/$fpr.rev" "$file_rev"

    if [ -x "$(which tar)" ]; then
        log "creating archive..."

        tar -zcvf                                           \
            $GPG_WIZ_EXPORT_DIR/$email.key-export.tar.gz    \
            "$file_sec" "$file_pub" "$file_sub" "$file_rev"
    fi

    log "deleting keys from gpg..."

    gpg --delete-secret-key --batch --yes "$fpr"

    log "reimporting sub-keys..."

    gpg --import "$file_sub"

    log "all done."

    gpg --list-secret-keys --keyid-format=long "$email"
}

action_list() {
    require_exec gpg
    log "listing keys..."
    gpg --list-public-keys --keyid-format=long
    log "listing secret keys..."
    gpg --list-secret-keys --keyid-format=long
}

prompt_for_action() {
    log "What do you want to do?"
    echo "1. Generation full set of keys with removed master key"
    echo "2. List all keys"
    read -p "> " action

    case "$action" in
        "1" )
            action_full_gen
            ;;
        "2" )
            action_list
            ;;
        * )
            log_error "invalid choice"
            ;;
    esac
}

prompt_for_action
