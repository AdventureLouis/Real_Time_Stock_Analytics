#!/bin/bash

# Check what init system is available
echo "=== Checking Init System ==="
if command -v systemctl >/dev/null 2>&1; then
    echo "systemd detected"
    systemctl --version
elif command -v service >/dev/null 2>&1; then
    echo "SysV init detected"
    service --version 2>/dev/null || echo "service command available"
elif command -v rc-service >/dev/null 2>&1; then
    echo "OpenRC detected"
elif [ -f /etc/init.d ]; then
    echo "Traditional init.d detected"
else
    echo "Unknown init system"
fi

echo -e "\n=== Process 1 ==="
ps -p 1 -o pid,ppid,cmd

echo -e "\n=== Available process managers ==="
which systemctl service rc-service supervisorctl 2>/dev/null || echo "None found"

echo -e "\n=== Cron availability ==="
which crontab 2>/dev/null && echo "crontab available" || echo "crontab not found"

echo -e "\n=== Current user ==="
whoami
id

echo -e "\n=== Available users ==="
cat /etc/passwd | grep -E "(root|ec2-user|ubuntu|admin)" || echo "Standard users not found"