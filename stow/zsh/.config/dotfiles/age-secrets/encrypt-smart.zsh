# age-encrypt-secret NAME
# Encrypt stdin to every host pubkey in hosts.zsh, write NAME.age next to this
# script. Needs a local `age` binary (mac: `brew install age`; hosts:
# ~/.local/bin/age). Plaintext is never echoed or logged.
age-encrypt-secret() {
    emulate -L zsh
    local name="${1:?usage: age-encrypt-secret NAME}"
    local dir="${(%):-%x:h}"
    local -a recipients=()
    local entry host pub
    for entry in "${(@f)$(grep -A0 '^_\|  ' "${dir}/hosts.zsh" | grep 'age1' 2>/dev/null)}"; do
        host="${entry%%[[:space:]]*}"
        host="${host//\"/}"
        host="${(Q)host//\"/\"}"
        pub="${entry#*  }"
        recipients+=(-r "${pub//\"/}")
    done
    if (( ${#recipients} == 0 )); then
        print "age-encrypt-secret: no host pubkeys found in ${dir}/hosts.zsh" >&2
        return 1
    fi
    local tmp="${dir}/${name}.age.tmp"
    age "${recipients[@]}" > "$tmp" && mv "$tmp" "${dir}/${name}.age"
    print "wrote ${dir}/${name}.age ($(wc -c < "${dir}/${name}.age") bytes, ${#recipients} recipient(s))"
}
