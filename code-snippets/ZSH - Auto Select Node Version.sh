# n auto select nodejs version hook
autoload -U add-zsh-hook
select-node-version() {
    if [[ -f .nvmrc && -r .nvmrc ]] || \
        [[ -f .node-version && -r .node-version ]] || \
        [[ -f .n-node-version && -r .n-node-version ]] || \
        [[ -f package.json && -r package.json ]]; then
        n auto -q &>/dev/null
        local change=$?
    elif [[ ! $(node -v) =~ $(n --lts) ]]; then
        n lts -q &>/dev/null
        local change=$?
    fi
    if [[ $change ]]; then
        echo "Node $(node -v)"
    fi
}
add-zsh-hook chpwd select-node-version
select-node-version