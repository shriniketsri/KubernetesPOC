#!/bin/sh

# Start nginx directly - directories already created in Docker build
exec nginx -g "daemon off;"