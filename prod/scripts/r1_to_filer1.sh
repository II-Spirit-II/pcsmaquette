#!/bin/bash

/usr/bin/python3 /root/pcs/r1_to_filer1.py

if [ $? -eq 0 ]; then
    exit 0  # Succès
else
    exit 1  # Échec
fi
