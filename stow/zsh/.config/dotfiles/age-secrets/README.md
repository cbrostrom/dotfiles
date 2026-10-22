# age-secrets — headless host env secrets (no rbw dependency)

Purpose: secrets needed by shells on headless servers (cloudbro, linuxbro) that
must not depend on an interactive `rbw unlock`. Each host owns an age keypair
(`~/.config/age/key.txt`, 0600, generated on the host itself). Dotfiles here
carry only public keys and `age`-encrypted blobs.

## Layout

- `typesafe.age` — TYPESAFE_API_KEY, encrypted to every host pubkey below.
  Used by the pi `effort-judge` (il) extension.
- `hosts.zsh` — name → age pubkey map, sourced by the encrypt helper.
- `encrypt-smart.zsh` — helper to (re)encrypt a secret to all hosts.

## Encrypting / rotating

```zsh
source ~/.config/dotfiles/age-secrets/encrypt-smart.zsh
echo "the-secret" | age-encrypt-secret typesafe   # writes typesafe.age
```

Source of truth stays in Bitwarden (`Typesafe - JEV`, field `API KEY`);

## Decrypt path (automatic)

`env-secrets.zsh` falls back to `age` when rbw is absent: it decrypts
`typesafe.age` with `~/.config/age/key.txt` and exports `TYPESAFE_API_KEY`.
Plaintext never touches disk on the hosts; it lives in the process env only.
It still protects at rest only — a rooted live host sees the env regardless.
