#!/bin/bash
set -e

echo "Entering PostgreSQL interactive terminal..."
# Switch to the postgres user and run psql interactively
sudo -u postgres psql

echo "Exited PostgreSQL interactive terminal."