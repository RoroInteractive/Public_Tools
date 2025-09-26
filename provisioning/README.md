# Provisioning tools
## Passwordless sudo through private key only SSH-access
The following will set up a mac user for private key only SSH-access (user/password ssh access turned off), the user will also be given passwordless sudo.
Mainly an entrypoint for further provisioning.

Steps:
1. Grant Terminal full disk access in System Settings → Privacy & Security → Full Disk Access. (Needed to enable sshd)
2. Run this script with your user and ssh public key  
```bash
bash -c "$(curl -fsSL https://github.com/RoroInteractive/Public_Tools/raw/refs/heads/main/provisioning/enable_ssh_access.sh)" -- "existing_local_user_name" "public_key"
```