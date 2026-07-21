# Security Policy

<div align="center">
  <img src="https://raw.githubusercontent.com/shayanheidari01/ShineNETVPN/main/assets/images/logo.png" width="80" height="80" alt="ShineNET VPN Logo">
  
  **ShineNET VPN Security Policy**
  
  *Last Updated: July 2026*
  
</div>

---

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.2.x   | :white_check_mark: |
| < 1.2   | :x:                |

---

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead, please send an email to: **shinenetvpn@gmail.com**

Include the following information:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### What to Expect

- **Acknowledgment**: We will acknowledge receipt within 48 hours
- **Assessment**: We will investigate and assess the vulnerability within 7 days
- **Resolution**: We aim to release a fix within 30 days for critical vulnerabilities
- **Disclosure**: We will coordinate with you on public disclosure timing

### Safe Harbor

We support safe harbor for security researchers who:
- Make a good faith effort to avoid privacy violations and data destruction
- Only interact with accounts you own or with explicit permission of the account holder
- Do not exploit a vulnerability beyond what is necessary to confirm its existence
- Report vulnerabilities promptly and do not publicly disclose before a fix is available

---

## Security Measures

### Encryption Protocols

ShineNET VPN supports multiple industry-standard VPN protocols:

#### V2Ray/Xray Protocols (Primary)
| Protocol | Encryption | Security Level |
|----------|------------|----------------|
| VMess | AES-128-GCM / ChaCha20-Poly1305 | High |
| VLESS + XTLS | AES-256-GCM / ChaCha20-Poly1305 | Very High |
| Trojan | AES-256-GCM (TLS 1.3) | Very High |
| Shadowsocks | AEAD Ciphers (AES-256-GCM, ChaCha20) | High |

#### Aether Protocols (Cloudflare WARP)
| Protocol | Description | Security Level |
|----------|-------------|----------------|
| MASQUE | HTTP/3 tunnel over QUIC | Very High |
| WireGuard | Modern VPN protocol | High |
| WARP-on-WARP | Double-layer encryption | Very High |

### How Encryption Works

1. **Transport Layer**: All connections use TLS 1.3 or QUIC for transport encryption
2. **Tunnel Layer**: VPN traffic is encrypted using the selected protocol's cipher
3. **No Double Encryption**: When using MASQUE/TLS, the protocol does not add redundant encryption layers

### Server Infrastructure

- **Public Server Configurations**: V2Ray server configurations are sourced from publicly available community lists
- **TLS Encryption**: All V2Ray connections use TLS for transport security
- **Multiple Protocol Support**: VMess, VLESS, Trojan, Shadowsocks with TLS
- **No Server-Side Logging**: We do not operate or control the servers; configurations are fetched from public sources
- **User Responsibility**: Users should verify server trustworthiness before connecting

---

## Security Best Practices for Users

### Before Installing
1. Download APK only from official GitHub releases
2. Verify APK checksum if provided
3. Review app permissions before installation

### While Using
1. Use VPN for all internet traffic when possible
2. Avoid accessing highly sensitive services (banking) through VPN
3. Check for DNS leaks using tools like dnsleaktest.com
4. Update the app regularly to get security patches

### Recommended Settings
- Use VLESS + XTLS or Trojan protocols when available
- Enable "Connect on Boot" for continuous protection
- Use the closest server for better performance and security

---

## Open Source Transparency

ShineNET VPN is fully open source:
- **Source Code**: Available on GitHub for community review
- **No Hidden Code**: All VPN logic is visible in the repository
- **Community Audits**: Independent researchers can verify our security claims
- **Regular Updates**: Security improvements are released regularly

---

## Server Trust Warning

Since V2Ray server configurations are sourced from public community lists:
- ⚠️ **No Guarantees**: We cannot guarantee the trustworthiness of third-party servers
- 🔍 **User Verification**: Users should verify server configurations before connecting
- 🛡️ **TLS Protection**: All connections use TLS encryption regardless of server source
- 📋 **Best Practice**: Prefer servers with known operators or use Aether protocols for maximum security

---

## Data Collection Transparency

### What We DO NOT Collect
- Real IP addresses (only anonymized region)
- Browsing history or activity
- Connection logs or session data
- Personal identifiable information

### What We Collect (Minimal)
- Anonymized IP region (first 3 octets only)
- Device type and Android version
- App version for update checks
- Aggregated server performance metrics

---

## Compliance

- **GDPR**: We comply with European privacy regulations
- **CCPA**: We respect California privacy rights
- **Open Source**: MIT License ensures full transparency

---

## Contact

For security-related inquiries:
- **Email**: shinenetvpn@gmail.com
- **Telegram**: [@ShineNETVPN](https://t.me/ShineNETVPN)
- **GitHub Issues**: For non-security bugs only

---

<div align="center">
  
  **Your security is our priority**
  
  *ShineNET VPN - Transparent, Secure, Private*
  
</div>
