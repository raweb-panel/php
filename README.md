# php

- Debian 12/11.
- Ubuntu 24.04/22.04.
- AlmaLinux 9/8.

Debian Based.
```bash
apt update; apt install -y wget apt-transport-https ca-certificates gnupg2 sudo
echo "deb [trusted=yes] https://repo.julio.al/ $(cat /etc/os-release | grep VERSION_CODENAME= | cut -d= -f2) main" | sudo tee /etc/apt/sources.list.d/raweb.list
sudo apt update; sudo apt install -y raweb-php84
```

AlmaLinux Based.
```bash
sudo dnf install -y wget ca-certificates gnupg2
# For AlmaLinux 9:
sudo tee /etc/yum.repos.d/raweb.repo << 'EOF'
[raweb-alma9]
name=Raweb Panel Repository for AlmaLinux 9
baseurl=https://repo.julio.al/rpm/alma9/x86_64
enabled=1
gpgcheck=0
EOF

# For AlmaLinux 8, use the following instead:
sudo tee /etc/yum.repos.d/raweb.repo << 'EOF'
[raweb-alma8]
name=Raweb Panel Repository for AlmaLinux 8
baseurl=https://repo.julio.al/rpm/alma8/x86_64
enabled=1
gpgcheck=0
EOF

# Update repository cache
sudo dnf makecache

# Install package
sudo dnf install raweb-php84
```
