#!/bin/sh

set -e

[ -z "$GPG_WIZ_SUBKEY_EXPIRE" ] && GPG_WIZ_SUBKEY_EXPIRE='1y'
[ -z "$GPG_WIZ_OUTPUT_DIR" ]    && GPG_WIZ_OUTPUT_DIR="$(pwd)"

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

action_full_gen() (
    require_exec gpg

    log "Please provide the basic information for GPG"

    read -p "email > " email
    [ -z "$email" ] && log_error "Email can not be empty"

    read -p "name > " name
    [ -z "$name" ] && log_error "Name can not be empty"

    log "Where do you want to store the generated files? (default: $GPG_WIZ_OUTPUT_DIR)"

    read -p "dir > " dir
    [ ! -z "$dir" ] && GPG_WIZ_OUTPUT_DIR="$dir"
    [ ! -d "$GPG_WIZ_OUTPUT_DIR" ] && log_error "directory \"$GPG_WIZ_OUTPUT_DIR\" does not exist"

    working_dir="/tmp/gpg_wiz_$(date +%s)"
    mkdir -p "$working_dir"
    cd "$working_dir"

    log "info: working dir: $working_dir"

    file_pre="./$email.gpg"

    file_sec="$file_pre.sec.asc"
    file_pub="$file_pre.pub.asc"
    file_sub="$file_pre.sub.asc"
    file_rev="$file_pre.rev"
    file_txt="$file_pre.txt"
    file_arc="$file_pre.tar.gz"
    file_cmd="$file_pre.cmd"

    log "generating master key..."

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

    log "grabbing revocation cert..."

    cp -v "$(get_gpg_home)/openpgp-revocs.d/$fpr.rev" "$file_rev"

    if [ -x "$(which paperkey)" ]; then
        log "creating paperkey..."
        gpg --export-secret-keys "$fpr" | paperkey --output "$file_txt"
    else
        log "No paperkey found. If you want the wizard to create a paper backup, please install paperkey."
    fi

    if [ -x "$(which tar)" ]; then
        log "creating archive..."
        tar -zcvf "$file_arc" ./*
    else
        log "No tar found. If you want the wizard to create an archive, please install tar."
    fi

    log "deleting keys from gpg..."

    gpg --delete-secret-key --batch --yes "$fpr"

    log "reimporting sub-keys..."

    gpg --import "$file_sub"

    log "copying to output dir..."

    cp -v ./* "$GPG_WIZ_OUTPUT_DIR"

    log "all done."

    gpg --list-secret-keys --keyid-format=long "$email"
)

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
