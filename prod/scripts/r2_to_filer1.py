#!/usr/bin/python3

import os
import json
import ovh
import sys
import yaml
import subprocess
from shutil import copytree, copy
import time

class IPFailover:

    def __init__(self, conf="/root/pcs/cmdb.yml", server="filer1_server",
                    debug=False, test=False):
        with open(conf, "r") as f:
            self.conf = yaml.safe_load(f)
        self.server = self.conf[server]
        self.api = ovh.Client(
            # Endpoint of API OVH Europe
            endpoint='ovh-eu',
            # Application Key
            application_key=self.conf['app_key'],
            # Application Secret
            application_secret=self.conf['app_secret'],
            # Consumer Key
            consumer_key=self.conf['cons_key'],
        )

        self.__info_docker_stack = {
            '178.32.117.50/32': 'dawantv',
            '178.33.110.250/32': 'nuage'
        }

        self.debug = debug

    def r2_to_filer1(self):
        self.process_ip_failovers()

    def process_ip_failovers(self):
        target = self.server
        print('Migration IP failovers en cours')
        for ip in self.__info_docker_stack:
            self.__move_ip(ip, target)

    def __move_ip(self, ip, target):
        try:
            self.api.get(f"/dedicated/server/{target}/ipCanBeMovedTo",
                ip=ip,
            )
            result = self.api.post(f"/dedicated/server/{target}/ipMove",
                ip=ip,
            )
            print(f"IP: {ip}, moved with success to {target}")
            print(json.dumps(result, indent=4))
        except ovh.exceptions.ResourceConflictError:
            print(f"IP: {ip}, is already routed to {target}")


if __name__ == "__main__":
    server = IPFailover(debug=True, test=False)
    server.r2_to_filer1()
