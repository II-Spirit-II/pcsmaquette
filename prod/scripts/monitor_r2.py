import subprocess
import socket
import re

def get_current_node_ip():
    result = subprocess.run(["ip", "a", "show", "public-bond0"], capture_output=True, text=True)
    output = result.stdout

    # Cherche la première occurrence d'une adresse IP sur l'interface 'public-bond0'
    match = re.search(r'inet (\d+\.\d+\.\d+\.\d+)/\d+', output)
    return match.group(1) if match else None

def is_current_node_promoted():
    try:
        promoted_node_ip = subprocess.check_output(
            "pcs status resources | grep -A 2 'Clone Set: drbd_r2-clone' | grep 'Promoted:' | awk '{print $4}'",
            shell=True,
            text=True
        ).strip().strip('[]')

        current_node_ip = get_current_node_ip()
        return promoted_node_ip == current_node_ip
    except subprocess.CalledProcessError:
        return False

def verify_ip_failovers():
    required_ips = ["178.33.110.250", "178.32.117.50"]  # Les IP à vérifier
    result = subprocess.run(["ip", "a"], capture_output=True, text=True)
    output = result.stdout

    missing_ips = []
    for ip in required_ips:
        if ip not in output:
            missing_ips.append(ip)

    return missing_ips

if is_current_node_promoted():
    missing_ips = verify_ip_failovers()
    if missing_ips:
        print("IP failover manquantes sur l'interface : " + ", ".join(missing_ips))
        exit(1)
    else:
        print("Toutes les IP failovers sont correctement configurées.")
        exit(0)
else:
    print("Ce noeud n'est pas le noeud promu pour drbd_r2-clone.")
    exit(0)
