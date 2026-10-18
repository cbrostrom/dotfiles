#!/usr/bin/env bash
# Silence pam_mail's "You have no mail." banner on login shells (ssh/login/su).
# Debian ships pam_mail with `standard` (announce mail status) by default; on
# headless hosts nobody wants the banner. Idempotent: only adds `quiet` when
# missing; never removes anything. Skips cleanly when pam_mail isn't used.
set -euo pipefail

changed=0
for file in /etc/pam.d/sshd /etc/pam.d/login /etc/pam.d/su; do
    [[ -f "$file" ]] || continue
    if grep -q 'pam_mail.so' "$file" && ! grep 'pam_mail.so' "$file" | grep -q 'quiet'; then
        # Fleet runs over BatchMode ssh; never block on a sudo password prompt.
        if ! sudo -n true 2>/dev/null; then
            echo "[dotfiles] skip: pam_mail quiet needs sudo; run: sudo bash $0"
            exit 0
        fi
        sudo -n sed -i "s/\(pam_mail\.so\)/\1 quiet/" "$file"
        changed=1
    fi
done

if [[ "$changed" -eq 1 ]]; then
    echo "[dotfiles] silenced pam_mail login banner (added quiet)"
fi
