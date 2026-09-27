#!/usr/bin/env bash

# Removable filesystems and encrypted containers (LUKS and the others that
# udisks can unlock) that udisks knows about, i.e. the ones that are not
# system devices (the same filter that file managers use).
#
#   udisks.sh          - print the waybar status line again on each udisks
#                        event; the output is empty (and waybar hides the
#                        module) when there are no such devices
#   udisks.sh open     - unlock and mount the device if necessary, and open
#                        kitty in its mount point
#   udisks.sh unmount  - unmount all the devices of a drive (e.g. both
#                        partitions of a ventoy stick), and lock the
#                        encrypted ones
#
# When more than one device (for open) or drive (for unmount) applies, a
# zenity list asks which one.

set -uo pipefail

# A JSON array of {device, fs_device, encrypted, locked, name, size, mount,
# drive, drive_name, drive_size, ignored}.
# An encrypted container is one entry: device is the container, fs_device is
# its unlocked filesystem. For a plain filesystem both are the same device.
# fs_device is null when there is no filesystem to mount (a locked container,
# or one with e.g. LVM inside), and mount is null when it is not mounted.
# drive identifies the physical drive; for a device without one (e.g. a loop
# device) it is its partition table, or else the device itself. ignored is
# the udisks hint to not show the device, e.g. for an EFI partition such as
# the VTOYEFI one of ventoy; such a device is listed only to be unmounted
# with the rest of its drive.
drives() {
    busctl --system --json=short call org.freedesktop.UDisks2 /org/freedesktop/UDisks2 \
            org.freedesktop.DBus.ObjectManager GetManagedObjects \
        | jq --compact-output '
            def str: map(select(. != 0)) | implode;
            def human: [., 0]
                | until(.[0] < 1024 or .[1] == 5; [.[0] / 1024, .[1] + 1])
                | "\(.[0] * 10 | round / 10)\(["B", "K", "M", "G", "T", "P"][.[1]])";
            def nonempty: select(. != null and . != "");
            def path: if . == "/" then null else . end;
            .data[0] as $objects
            | [ $objects | to_entries[]
                | .key as $path
                | .value["org.freedesktop.UDisks2.Block"] as $block
                | .value["org.freedesktop.UDisks2.Encrypted"] as $crypt
                # the unlocked side of a container is listed with the container
                | select($block and ($block.CryptoBackingDevice.data | path) == null)
                | select($block.HintSystem.data | not)
                | select($crypt or .value["org.freedesktop.UDisks2.Filesystem"])
                | (if $crypt then $crypt.CleartextDevice.data | path else $path end) as $inner
                | ($inner | if . then $objects[.] else null end) as $inner
                | ($inner["org.freedesktop.UDisks2.Filesystem"]) as $fs
                | ($objects[$block.Drive.data]["org.freedesktop.UDisks2.Drive"] // {}) as $drive
                | ($block.PreferredDevice.data | str) as $device
                # the whole-disk device, for a partition
                | (.value["org.freedesktop.UDisks2.Partition"].Table.data // "/" | path) as $table_path
                | ($table_path | if . then $objects[.]["org.freedesktop.UDisks2.Block"] else null end) as $table
                | ([$drive.Vendor.data, $drive.Model.data] | map(nonempty) | join(" ")
                    | if . == "" then null else . end) as $model
                | {
                    device: $device,
                    fs_device: (if $fs then $inner["org.freedesktop.UDisks2.Block"].PreferredDevice.data | str else null end),
                    encrypted: ($crypt != null),
                    locked: ($crypt != null and $inner == null),
                    name: ($inner["org.freedesktop.UDisks2.Block"].IdLabel.data | nonempty)
                        // ($block.IdLabel.data | nonempty)
                        // $model
                        // $device,
                    size: ($block.Size.data | human),
                    mount: ($fs.MountPoints.data // [] | map(str) | first),
                    drive: (($block.Drive.data | path) // $table_path // $path),
                    drive_name: ($model // ($table.PreferredDevice.data // null | if . then str else null end) // $device),
                    drive_size: ($drive.Size.data // $table.Size.data // $block.Size.data | human),
                    ignored: $block.HintIgnore.data,
                  }
              ]
            | sort_by(.device)'
}

# the entries of drives that are not ignored
shown() {
    drives | jq --compact-output 'map(select(.ignored | not))'
}

status() {
    shown | jq --compact-output '
        if length == 0 then {text: ""} else {
            text: "󰕓 \(length)",
            class: (if any(.mount) then "mounted" else "unmounted" end),
            tooltip: (map(
                    if .mount then "● \(.name) (\(.size)) at \(.mount)"
                    elif .locked then "󰌾 \(.name) (\(.size))"
                    else "○ \(.name) (\(.size))" end
                ) | join("\n")),
        } end'
}

# print the device of an entry of the JSON array $1 of {device, name, size,
# mount, locked}, with a zenity list titled $2 when there are several of them
pick() {
    local list=$1 count
    count=$(jq length <<<"$list")
    if ((count == 0)); then
        return 1
    elif ((count == 1)); then
        jq --raw-output '.[0].device' <<<"$list"
    else
        local rows
        mapfile -t rows < <(jq --raw-output '
            .[] | .device, .name, .size, (.mount // if .locked then "locked" else "" end)' <<<"$list")
        zenity --list --title="$2" --text="$2" \
            --column=Device --column=Name --column=Size --column="Mount point" \
            --hide-column=1 --print-column=1 "${rows[@]}"
    fi
}

# print the field $2 of the entry of device $1, or nothing when it is null
field() {
    drives | jq --raw-output --arg device "$1" --arg field "$2" \
        '.[] | select(.device == $device) | .[$field] // empty'
}

markup_escape() {
    local s=${1//&/&amp;}
    s=${s//</&lt;}
    echo "${s//>/&gt;}"
}

fail() {
    zenity --error --no-markup --title="$1" --text="$2"
    exit 1
}

# ask for the passphrase of the container $1 until it unlocks, or until the
# dialog is cancelled
unlock() {
    local name prompt text passphrase error
    name=$(field "$1" name)
    [[ $name == "$1" ]] || name+=" ($1)"
    prompt="Passphrase for $(markup_escape "$name"):"
    text=$prompt
    while passphrase=$(zenity --entry --hide-text --title="Unlock a drive" --text="$text"); do
        # the key file is used byte for byte, so no newline after the passphrase
        if error=$(printf %s "$passphrase" \
                | udisksctl unlock --block-device "$1" --key-file /dev/stdin 2>&1); then
            return 0
        fi
        text="$(markup_escape "$error")"$'\n\n'"$prompt"
    done
    return 1
}

case ${1:-} in
    open)
        device=$(pick "$(shown)" "Open a drive") || exit 0
        if [[ $(field "$device" locked) == true ]]; then
            unlock "$device" || exit 0
        fi
        fs_device=$(field "$device" fs_device)
        [[ -n $fs_device ]] || fail "Mount failed" "$device has no filesystem that udisks can mount"
        mount=$(field "$device" mount)
        if [[ -z $mount ]]; then
            error=$(udisksctl mount --block-device "$fs_device" 2>&1) || fail "Mount failed" "$error"
            mount=$(field "$device" mount)
        fi
        # spawn through niri, so that kitty gets the session environment and
        # does not live in the cgroup of waybar
        niri msg action spawn -- kitty --directory "$mount"
        ;;
    unmount)
        # the devices that are mounted or unlocked, grouped by drive, with the
        # ignored ones
        busy=$(drives | jq --compact-output '
            map(select(.mount or (.encrypted and (.locked | not))))
            | group_by(.drive)
            | map({
                device: .[0].drive,
                name: .[0].drive_name,
                size: .[0].drive_size,
                mount: (map(.mount // empty) | join(", ")),
                devices: map({device, fs_device, encrypted, mount}),
              })')
        drive=$(pick "$busy" "Unmount a drive") || exit 0
        # try every device, so that one busy partition does not keep the
        # others mounted
        errors=()
        # a separator that is not whitespace, so that bash keeps empty fields
        while IFS=$'\x1f' read -r device fs_device encrypted mount; do
            if [[ -n $mount ]]; then
                error=$(udisksctl unmount --block-device "$fs_device" 2>&1) \
                    || { errors+=("$error"); continue; }
            fi
            if [[ $encrypted == true ]]; then
                error=$(udisksctl lock --block-device "$device" 2>&1) || errors+=("$error")
            fi
        done < <(jq --raw-output --arg drive "$drive" '
            .[] | select(.device == $drive) | .devices[]
            | [.device, .fs_device // "", .encrypted, .mount // ""] | map(tostring) | join("\u001f")' <<<"$busy")
        ((${#errors[@]} == 0)) || fail "Unmount failed" "$(printf '%s\n' "${errors[@]}")"
        ;;
    "")
        previous=
        emit() {
            local line
            line=$(status)
            if [[ $line != "$previous" ]]; then
                echo "$line"
                previous=$line
            fi
        }
        # the monitor must not outlive this script
        coproc monitor { exec udisksctl monitor 2>/dev/null; }
        # bash unsets these when the coproc exits
        monitor_pid=$monitor_PID events=${monitor[0]}
        trap 'kill $monitor_pid 2>/dev/null' EXIT
        trap exit TERM INT HUP
        emit
        # one change makes udisks send a burst of events, so wait for a quiet
        # moment before the status is read again
        while read -r -u "$events" _; do
            while read -r -t 0.3 -u "$events" _; do :; done
            emit
        done
        ;;
    *)
        echo "usage: $0 [open|unmount]" >&2
        exit 2
        ;;
esac
