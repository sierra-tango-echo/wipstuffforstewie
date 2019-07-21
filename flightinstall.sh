mkdir -p /var/lib/flightinstall/bin/
cat << 'EOF' > /var/lib/flightinstall/bin/flightinstall
#!/bin/bash
function flightinstall {
  echo "-------------------------------------------------------------------------------"
  echo "Flight deployment Suite - Copyright (c) 2008-2019 Alces Flight Ltd"
  echo "-------------------------------------------------------------------------------"
  if [ -f /var/lib/flightinstall/RUN ]; then
    echo "Running Flight install scripts.."
    curl http://10.10.0.1/metalware/`hostname -s`/files/repo/main/main.sh | /bin/bash | tee /tmp/metalware-default-output
    touch /flightinstall.reboot
    echo "Done!"
    rm -f /var/lib/flightinstall/RUN
  fi
  echo "-------------------------------------------------------------------------------"
}
trap flightinstall EXIT
EOF

cat << 'EOF' > /var/lib/flightinstall/bin/flightinstall_complete
#!/bin/bash
/bin/systemctl disable flightinstall.service
if [ -f /flightinstall.reboot ]; then
  echo -n "Reboot flag set.. Rebooting.."
  rm -f /flightinstall.reboot
  shutdown -r now
fi
EOF

cat << 'EOF' >> /etc/systemd/system/flightinstall.service
[Unit]
Description=FlightInstall service
After=network-online.target remote-fs.target
Before=display-manager.service getty@tty1.service
[Service]
ExecStart=/bin/bash /var/lib/flightinstall/bin/flightinstall
Type=oneshot
ExecStartPost=/bin/bash /var/lib/flightinstall/bin/flightinstall_complete
SysVStartPriority=99
TimeoutSec=0
RemainAfterExit=yes
Environment=HOME=/root
Environment=USER=root
[Install]
WantedBy=multi-user.target
EOF

chmod 664 /etc/systemd/system/flightinstall.service
systemctl daemon-reload
systemctl enable flightinstall.service
touch /var/lib/flightinstall/RUN
