# Security Configuration

Security hardening documentation and setup scripts for Linux systems.

## Contents

- **SSH-SECURITY.md** - Complete SSH hardening guide with fail2ban and firewall
- **setup-ssh-security.sh** - Automated setup script (coming soon)

## Quick Start

### 1. Review Documentation

Read through `SSH-SECURITY.md` to understand the security setup.

### 2. Customize for Your Environment

Before applying, determine your:
- **LAN subnet** (e.g., `192.168.1.0/24`)
- **Tailscale subnet** (usually `100.0.0.0/8`)
- **Custom SSH port** (choose a non-standard port)
- **Username** (your system username)

### 3. Apply Configuration

Follow the step-by-step instructions in `SSH-SECURITY.md` or use the setup script:

```bash
cd ~/.config/dotfiles/linux/security
# Review and customize the script first
./setup-ssh-security.sh
```

## Security Layers

### 1. SSH Hardening
- Custom port (reduces automated attacks)
- Key-based authentication (recommended)
- Password authentication (with fail2ban protection)
- Root login disabled
- User whitelist

### 2. Fail2ban
- Automatic IP banning after failed attempts
- Whitelisted trusted networks
- UFW integration for consistent firewall rules

### 3. Firewall (UFW)
- Default deny incoming
- Explicit allow rules for trusted networks only
- Source IP restrictions (LAN + VPN only)

## Network Architecture

```
Internet
    │
    ├─── ❌ Blocked (UFW default deny)
    │
    ├─── Tailscale VPN (100.0.0.0/8)
    │         │
    │         └─── ✅ Allowed (whitelisted)
    │
    └─── LAN (192.168.x.0/24)
              │
              └─── ✅ Allowed (whitelisted)
```

## Services Covered

Currently documented:
- SSH (OpenSSH)

Future additions:
- RDP (GNOME Remote Desktop)
- VPN (Tailscale, WireGuard)
- Web services (if applicable)

## Maintenance

### Regular Checks

```bash
# Check fail2ban status
sudo fail2ban-client status sshd

# Review SSH logs
sudo journalctl -u sshd --since today

# Check firewall rules
sudo ufw status numbered
```

### After System Updates

```bash
# Verify SSH still works
ssh -p <PORT> <USER>@localhost

# Restart services if needed
sudo systemctl restart sshd
sudo systemctl restart fail2ban
```

## Troubleshooting

See `SSH-SECURITY.md` for detailed troubleshooting steps.

Common issues:
- SSH won't start → Check config with `sudo sshd -t`
- Fail2ban not banning → Verify log paths and filter
- Locked out → Whitelist your network or use physical access

## AI-Assisted Recreation

This documentation is designed to be used with AI assistants to recreate the security setup on new systems. See the "AI Recreation Instructions" section in each document.

## Contributing

When adding new security configurations:
1. Create a new `.md` file in this directory
2. Follow the same structure as `SSH-SECURITY.md`
3. Use placeholders for sensitive info (e.g., `<CUSTOM_PORT>`)
4. Include AI recreation instructions
5. Update this README

## Security Notice

⚠️ **Important:**
- Never commit actual ports, IPs, or passwords to git
- Use placeholders in documentation
- Keep actual values in password manager
- Test changes in safe environment first

## References

- [Arch Wiki - Security](https://wiki.archlinux.org/title/Security)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
