# Security Quick Reference

Fast reference for common security tasks and commands.

## SSH

### Connection
```bash
ssh -p <PORT> <USER>@<HOST>
```

### Configuration
```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Test config
sudo sshd -t

# Restart SSH
sudo systemctl restart sshd
```

## Fail2ban

### Status
```bash
# All jails
sudo fail2ban-client status

# Specific jail
sudo fail2ban-client status sshd
```

### Management
```bash
# Reload config
sudo fail2ban-client reload

# Unban IP
sudo fail2ban-client set sshd unbanip <IP>

# Ban IP manually
sudo fail2ban-client set sshd banip <IP>
```

### Logs
```bash
# Fail2ban logs
sudo journalctl -u fail2ban -f

# SSH auth logs
sudo journalctl -u sshd -f
```

## Firewall (UFW)

### Status
```bash
# View rules
sudo ufw status numbered
sudo ufw status verbose

# Show app profiles
sudo ufw app list
```

### Management
```bash
# Enable/disable
sudo ufw enable
sudo ufw disable

# Reload
sudo ufw reload

# Reset (careful!)
sudo ufw reset
```

### Rules
```bash
# Allow from subnet
sudo ufw allow from <SUBNET> to any port <PORT> proto tcp

# Delete rule
sudo ufw delete <RULE_NUMBER>

# Insert rule at position
sudo ufw insert 1 allow from <IP>
```

## Monitoring

### Active Connections
```bash
# All listening ports
sudo ss -tlnp

# Specific port
sudo ss -tlnp | grep :<PORT>

# Active SSH connections
sudo ss -tnp | grep :22
```

### Login Attempts
```bash
# Recent SSH logins
sudo journalctl -u sshd --since today | grep Accepted

# Failed attempts
sudo journalctl -u sshd --since today | grep Failed

# Last logins
last -n 20
lastlog
```

### System Security
```bash
# Check for rootkits (install rkhunter first)
sudo rkhunter --check

# Check open ports
sudo nmap -sT localhost

# List all users
cat /etc/passwd | grep /bin/bash
```

## Emergency

### Locked Out
```bash
# Physical access required
# 1. Boot into system
# 2. Unban IP:
sudo fail2ban-client set sshd unbanip <YOUR_IP>

# 3. Check UFW:
sudo ufw status numbered
sudo ufw delete <RULE_NUMBER>  # if banned by UFW
```

### SSH Won't Start
```bash
# Check config
sudo sshd -t

# Check logs
sudo journalctl -u sshd -n 50

# Check if port is in use
sudo ss -tlnp | grep :<PORT>

# Try starting manually
sudo /usr/bin/sshd -D -d  # debug mode
```

### Reset Fail2ban
```bash
# Stop service
sudo systemctl stop fail2ban

# Clear database
sudo rm /var/lib/fail2ban/fail2ban.sqlite3

# Start service
sudo systemctl start fail2ban
```

## Security Audit

### Quick Check
```bash
# SSH config
sudo sshd -t && echo "SSH: OK"

# Fail2ban status
sudo fail2ban-client status | grep "Jail list"

# Firewall status
sudo ufw status | grep "Status: active"

# Open ports
sudo ss -tlnp | grep LISTEN
```

### Full Audit
```bash
# Create audit script
cat > /tmp/security-audit.sh << 'EOF'
#!/bin/bash
echo "=== SSH Configuration ==="
sudo sshd -t 2>&1
echo ""

echo "=== Fail2ban Status ==="
sudo fail2ban-client status
echo ""

echo "=== Firewall Rules ==="
sudo ufw status numbered
echo ""

echo "=== Open Ports ==="
sudo ss -tlnp | grep LISTEN
echo ""

echo "=== Recent Failed Logins ==="
sudo journalctl -u sshd --since "1 day ago" | grep -i failed | tail -10
echo ""

echo "=== Currently Banned IPs ==="
sudo fail2ban-client status sshd | grep "Banned IP"
EOF

chmod +x /tmp/security-audit.sh
/tmp/security-audit.sh
```

## Common Ports

| Service | Default Port | Custom Port (Example) |
|---------|--------------|----------------------|
| SSH | 22 | 2222, 2200, 10022 |
| RDP | 3389 | 3390, 13389 |
| VNC | 5900 | 5901, 15900 |
| KDE Connect | 1714-1764 (TCP/UDP) | - |
| Apollo/Sunshine | 47989-47990, 47998-48010 | - |
| HTTP | 80 | 8080, 8000 |
| HTTPS | 443 | 8443, 4443 |

## Network Subnets

| Network | Typical Range | CIDR |
|---------|---------------|------|
| Localhost | 127.0.0.1 | 127.0.0.1/8 |
| Private Class A | 10.0.0.0 - 10.255.255.255 | 10.0.0.0/8 |
| Private Class B | 172.16.0.0 - 172.31.255.255 | 172.16.0.0/12 |
| Private Class C | 192.168.0.0 - 192.168.255.255 | 192.168.0.0/16 |
| Tailscale | 100.64.0.0 - 100.127.255.255 | 100.0.0.0/8 |

## Useful Aliases

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# Security aliases
alias sshstatus='sudo systemctl status sshd'
alias sshrestart='sudo systemctl restart sshd'
alias sshlog='sudo journalctl -u sshd -f'

alias f2bstatus='sudo fail2ban-client status'
alias f2bssh='sudo fail2ban-client status sshd'
alias f2bunban='sudo fail2ban-client set sshd unbanip'

alias fwstatus='sudo ufw status numbered'
alias fwreload='sudo ufw reload'

alias ports='sudo ss -tlnp'
alias connections='sudo ss -tnp'

# GSConnect/KDE Connect
alias gsconnect='gnome-extensions prefs gsconnect@andyholmes.github.io'
alias gsconnect-restart='gnome-extensions disable gsconnect@andyholmes.github.io && sleep 1 && gnome-extensions enable gsconnect@andyholmes.github.io'
```

## Documentation

For detailed information, see:
- `SSH-SECURITY.md` - Complete SSH security guide
- `README.md` - Security overview

## Support

If you need help:
1. Check logs: `sudo journalctl -u <service> -n 50`
2. Test config: Service-specific test commands
3. Review documentation in this directory
4. Use AI assistant with documentation for guidance
