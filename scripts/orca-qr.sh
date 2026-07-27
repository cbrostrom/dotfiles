#!/bin/bash
# Get Orca QR code from linuxbro for mobile pairing

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ Orca Mobile Pairing - QR Extraction                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"

# Option 1: Extract pairing code from systemd journal
echo -e "\n[Method 1] Get pairing code from service logs:"
PAIRING_CODE=$(ssh linuxbro "sudo journalctl -u orca-serve -n 20 --no-pager 2>/dev/null | grep -oP 'code=\K[^\"&]+' | head -1" 2>/dev/null)

if [ -n "$PAIRING_CODE" ]; then
  echo "Pairing code: $PAIRING_CODE"
  echo -e "\nFull pairing URL:"
  echo "orca://pair?code=$PAIRING_CODE"
else
  echo "Could not extract pairing code from logs"
fi

# Option 2: Web URL with embedded pairing info
echo -e "\n[Method 2] Web client URL (includes QR):"
WEB_URL=$(ssh linuxbro "sudo journalctl -u orca-serve -n 20 --no-pager 2>/dev/null | grep -oP 'Web client URL: \K.*' | head -1" 2>/dev/null)

if [ -n "$WEB_URL" ]; then
  echo "$WEB_URL"
  echo -e "\nOpen this URL in browser on local Mac to see QR code"
else
  echo "Fallback web URL:"
  echo "http://100.100.1.100:6768/web-index.html"
fi

# Option 3: Generate QR code locally (requires qrencode)
echo -e "\n[Method 3] Generate QR code locally:"
if command -v qrencode &>/dev/null; then
  if [ -n "$PAIRING_CODE" ]; then
    PAIRING_URL="orca://pair?code=$PAIRING_CODE"
    echo "Generating QR code for: $PAIRING_URL"
    qrencode -t UTF8 "$PAIRING_URL"
  fi
else
  echo "qrencode not installed. Install with: brew install qrencode"
fi

echo -e "\n[Method 4] Use Orca app to display QR:"
echo "1. SSH to linuxbro: ssh linuxbro"
echo "2. Check service status:"
echo "   sudo systemctl status orca-serve --no-pager"
echo "3. View full logs:"
echo "   sudo journalctl -u orca-serve -f"
echo "4. Look for: 'Web client URL:' or 'Pairing URL:'"
echo "5. Copy URL to browser: http://100.100.1.100:6768/web-index.html"

echo -e "\n[Method 5] Direct from linuxbro console:"
echo "ssh linuxbro 'sudo journalctl -u orca-serve -n 5 --no-pager'"
