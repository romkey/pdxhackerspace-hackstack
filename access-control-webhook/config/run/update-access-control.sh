#!/bin/sh
/usr/bin/ssh -fi /config/run/automation_rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o HostKeyAlgorithms=+ssh-rsa -o StrictHostKeyChecking=accept-new root@192.168.15.32 force command
