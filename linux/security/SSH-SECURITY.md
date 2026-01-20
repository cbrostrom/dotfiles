# SSH Security Configuration

Secure SSH setup with custom port, fail2ban protection, and firewall rules.

## Overview

- **Custom SSH Port**: Non-standard port to reduce automated attacks
- **Authentication**: Both SSH keys (recommended) and password (backup)
- **Fail2ban**: Automatic IP banning after failed login attempts
- **Firewall**: UFW rules restricting access to trusted networks only
- **Whitelisting**: LAN and Tailscale networks immune to fail2ban

## SSH Configuration

### File: `/etc/ssh/sshd_config`

```ini
# Network
Port <CUSTOM_PORT>                    # Non-standard port (not 22)
# ListenAddress commented out         # Bind to all interfaces

# Authentication
PermitRootLogin no                    # Disable root login
PubkeyAuthentication yes              # Allow SSH keys
PasswordAuthentication yes            # Allow password (with fail2ban)
PermitEmptyPasswords no               # No empty passwords
ChallengeResponseAuthentication no    # Disable challenge-response

# Access Control
AllowUsers <USERNAME>                 # Only specific user(s)

# Subsystems
Subsystem sftp /usr/lib/ssh/sftp-server
```

### Setup Commands

```bash
# Backup existing config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Edit configuration
sudo nano /etc/ssh/sshd_config

# Test configuration
sudo sshd -t

# Restart SSH
sudo systemctl restart sshd

# Enable at boot
sudo systemctl enable sshd
```

## Fail2ban Configuration

### File: `/etc/fail2ban/jail.d/sshd-custom.conf`

```ini
[sshd]
enabled = true
port = <CUSTOM_PORT>
filter = sshd
logpath = /var/log/auth.log
maxretry = 5                          # Ban after 5 failed attempts
findtime = 10m                        # Within 10 minutes
bantime = 1h                          # Ban for 1 hour
ignoreip = 127.0.0.1/8 ::1 <LAN_SUBNET> <TAILSCALE_SUBNET>
```

### File: `/etc/fail2ban/jail.d/defaults.conf`

```ini
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1 <LAN_SUBNET> <TAILSCALE_SUBNET>
banaction = ufw                       # Use UFW for banning
```

### Setup Commands

```bash
# Install fail2ban
sudo pacman -S fail2ban

# Create jail configuration
sudo nano /etc/fail2ban/jail.d/sshd-custom.conf
sudo nano /etc/fail2ban/jail.d/defaults.conf

# Start and enable fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Reload configuration
sudo fail2ban-client reload
```

### Monitoring Commands

```bash
# Check fail2ban status
sudo fail2ban-client status

# Check SSH jail status
sudo fail2ban-client status sshd

# View fail2ban logs
sudo journalctl -u fail2ban -f

# Unban an IP
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

## Firewall Configuration (UFW)

### SSH Rules

```bash
# Allow SSH from LAN
sudo ufw allow from <LAN_SUBNET> to any port <CUSTOM_PORT> proto tcp comment 'SSH from LAN'

# Allow SSH from Tailscale
sudo ufw allow from <TAILSCALE_SUBNET> to any port <CUSTOM_PORT> proto tcp comment 'SSH from Tailscale'

# Reload firewall
sudo ufw reload

# Verify rules
sudo ufw status numbered
```

### Default Policy

```bash
# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Enable firewall
sudo ufw enable
```

## Network Whitelisting

### Recommended Networks to Whitelist

- **Localhost**: `127.0.0.1/8` and `::1`
- **LAN**: Your local network subnet (e.g., `192.168.1.0/24`)
- **Tailscale**: `100.0.0.0/8` (Tailscale VPN range)
- **VPN**: Any other trusted VPN networks

### Why Whitelist?

- Prevents accidental lockout from trusted networks
- Allows unlimited login attempts from home/VPN
- Fail2ban only protects against external threats

## Security Best Practices

### 1. SSH Key Authentication (Recommended)

```bash
# Generate SSH key (if not exists)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key to server
ssh-copy-id -p <CUSTOM_PORT> <USERNAME>@<SERVER_IP>

# Test key-based login
ssh -p <CUSTOM_PORT> <USERNAME>@<SERVER_IP>

# Optional: Disable password auth after key setup
# Edit /etc/ssh/sshd_config: PasswordAuthentication no
```

### 2. Strong Password Policy

- Minimum 16 characters
- Mix of uppercase, lowercase, numbers, symbols
- Use password manager (Bitwarden, 1Password, etc.)
- Never reuse passwords

### 3. Custom SSH Port

- Use non-standard port (not 22, not common ports)
- Reduces automated scanning and brute force attempts
- Document port in password manager

### 4. Regular Monitoring

```bash
# Monitor SSH login attempts
sudo journalctl -u sshd -f

# Check fail2ban activity
sudo fail2ban-client status sshd

# Review UFW logs
sudo tail -f /var/log/ufw.log
```

## Testing the Setup

### Test SSH Access

```bash
# From LAN
ssh -p <CUSTOM_PORT> <USERNAME>@<LAN_IP>

# From Tailscale
ssh -p <CUSTOM_PORT> <USERNAME>@<TAILSCALE_IP>

# From internet (should timeout if not on VPN)
ssh -p <CUSTOM_PORT> <USERNAME>@<PUBLIC_IP>
```

### Test Fail2ban

```bash
# Simulate failed login attempts (from non-whitelisted IP)
# After 5 failed attempts, IP should be banned

# Check if IP is banned
sudo fail2ban-client status sshd

# Verify UFW rule was added
sudo ufw status numbered
```

## Troubleshooting

### SSH Won't Start

```bash
# Check configuration syntax
sudo sshd -t

# Check logs
sudo journalctl -u sshd -n 50

# Common issues:
# - Port already in use
# - Invalid configuration syntax
# - Firewall blocking port
```

### Fail2ban Not Banning

```bash
# Check jail is enabled
sudo fail2ban-client status

# Check log path is correct
ls -la /var/log/auth.log

# Test filter
sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf

# Check systemd journal integration
sudo journalctl -u sshd | grep "Failed password"
```

### Locked Out

```bash
# If you have physical access:
# 1. Login locally
# 2. Unban your IP: sudo fail2ban-client set sshd unbanip <YOUR_IP>
# 3. Check UFW rules: sudo ufw status numbered
# 4. Delete ban rule if exists: sudo ufw delete <RULE_NUMBER>

# Prevention:
# - Always whitelist your networks
# - Keep a backup access method (physical, console, etc.)
# - Test from whitelisted network first
```

## Files and Locations

### Configuration Files

```
/etc/ssh/sshd_config                           # SSH daemon config
/etc/ssh/sshd_config.backup                    # Backup of original config
/etc/fail2ban/jail.d/sshd-custom.conf          # SSH fail2ban jail
/etc/fail2ban/jail.d/defaults.conf             # Fail2ban defaults
```

### Log Files

```
/var/log/auth.log                              # SSH authentication logs
/var/log/fail2ban.log                          # Fail2ban activity
/var/log/ufw.log                               # Firewall logs
```

### Service Status

```bash
# SSH
sudo systemctl status sshd

# Fail2ban
sudo systemctl status fail2ban

# Firewall
sudo ufw status verbose
```

## Maintenance

### Regular Tasks

```bash
# Weekly: Check banned IPs
sudo fail2ban-client status sshd

# Monthly: Review SSH logs for suspicious activity
sudo journalctl -u sshd --since "1 month ago" | grep -i failed

# Quarterly: Update fail2ban rules if needed
sudo fail2ban-client reload

# As needed: Rotate logs
sudo journalctl --vacuum-time=30d
```

### Updates

```bash
# Update OpenSSH
sudo pacman -S openssh

# Update fail2ban
sudo pacman -S fail2ban

# After updates, restart services
sudo systemctl restart sshd
sudo systemctl restart fail2ban
```

## Additional Security Layers

### Optional Enhancements

1. **Two-Factor Authentication (2FA)**
   - Install: `sudo pacman -S libpam-google-authenticator`
   - Configure PAM and SSH for 2FA

2. **Port Knocking**
   - Hide SSH port until specific sequence is sent
   - Install: `knockd`

3. **SSH Certificates**
   - More secure than keys for large deployments
   - Requires SSH CA infrastructure

4. **Intrusion Detection (IDS)**
   - Install: `sudo pacman -S aide`
   - Monitor file system changes

## References

- [OpenSSH Documentation](https://www.openssh.com/manual.html)
- [Fail2ban Documentation](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [Arch Wiki - SSH](https://wiki.archlinux.org/title/OpenSSH)
- [Arch Wiki - Fail2ban](https://wiki.archlinux.org/title/Fail2ban)

## AI Recreation Instructions

To recreate this security setup on a new system, provide this document to an AI assistant with the following prompt:

```
I need to set up SSH security on my Linux system based on this documentation.
Please help me:
1. Configure SSH with a custom port and secure settings
2. Set up fail2ban to protect against brute force attacks
3. Configure UFW firewall rules for SSH
4. Whitelist my LAN and Tailscale networks

My network details:
- LAN subnet: [YOUR_LAN_SUBNET]
- Tailscale subnet: [YOUR_TAILSCALE_SUBNET]
- Desired SSH port: [YOUR_CUSTOM_PORT]
- Username: [YOUR_USERNAME]

Please walk me through each step and verify the configuration.
```

The AI will use this document as a reference to recreate the exact security setup.
