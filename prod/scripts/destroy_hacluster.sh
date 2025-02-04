pcs cluster destroy
systemctl stop pacemaker
systemctl stop corosync
systemctl stop drbd
systemctl start pcsd

