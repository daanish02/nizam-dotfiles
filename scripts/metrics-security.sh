#!/usr/bin/env bash
set -euo pipefail

OUT="/var/lib/prometheus/node-exporter/security.prom"
TMP=$(mktemp)

ssh_failed=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || true)
ssh_failed=${ssh_failed:-0}

ssh_invalid=$(grep -c "Invalid user" /var/log/auth.log 2>/dev/null || true)
ssh_invalid=${ssh_invalid:-0}

f2b_total=$(grep -c " Ban " /var/log/fail2ban.log 2>/dev/null || true)
f2b_total=${f2b_total:-0}

f2b_current=0
if command -v fail2ban-client &>/dev/null; then
    jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*://;s/,//g' || true)
    for jail in $jails; do
        count=$(fail2ban-client status "$jail" 2>/dev/null | grep "Currently banned" | awk '{print $NF}' || true)
        count=${count:-0}
        f2b_current=$((f2b_current + count))
    done
fi

ufw_blocked=$(grep -h "UFW BLOCK" /var/log/kern.log /var/log/syslog 2>/dev/null | wc -l || true)
ufw_blocked=${ufw_blocked:-0}

cat > "$TMP" <<EOF
# HELP nizam_ssh_failed_logins_total Total SSH failed password attempts
# TYPE nizam_ssh_failed_logins_total counter
nizam_ssh_failed_logins_total $ssh_failed

# HELP nizam_ssh_invalid_user_total Total SSH invalid user attempts
# TYPE nizam_ssh_invalid_user_total counter
nizam_ssh_invalid_user_total $ssh_invalid

# HELP nizam_fail2ban_bans_total Total IPs banned by fail2ban all time
# TYPE nizam_fail2ban_bans_total counter
nizam_fail2ban_bans_total $f2b_total

# HELP nizam_fail2ban_currently_banned Current number of banned IPs across all jails
# TYPE nizam_fail2ban_currently_banned gauge
nizam_fail2ban_currently_banned $f2b_current

# HELP nizam_ufw_blocked_total Total UFW blocked packets
# TYPE nizam_ufw_blocked_total counter
nizam_ufw_blocked_total $ufw_blocked
EOF

mv "$TMP" "$OUT"
chmod 644 "$OUT"
