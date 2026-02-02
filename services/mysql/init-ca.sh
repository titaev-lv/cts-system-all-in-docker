#!/bin/bash

set -e

# Execute the original docker-entrypoint script
exec docker-entrypoint.sh "$@"
