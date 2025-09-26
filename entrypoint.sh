#!/bin/bash
set -e

# This script runs as ROOT when the container starts.

# 1. Fix the permissions of the /data directory.
#    This directory is the mount point for our persistent volume.
echo "Fixing permissions for /data..."
chown -R elasticsearch:elasticsearch /data

# 2. Hand over control to the original Elasticsearch entrypoint script,
#    but run it as the 'elasticsearch' user.
#    'gosu' is a lightweight tool to switch users.
echo "Permissions fixed. Starting Elasticsearch as 'elasticsearch' user..."
exec gosu elasticsearch /usr/local/bin/docker-entrypoint.sh "$@"