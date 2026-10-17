#!/bin/sh
set -eu
# Run in the full official Python image: native osmium libraries are preinstalled.
# No apt-get or connection to Debian package mirrors is needed on the user's host.
python -c 'import ctypes; ctypes.CDLL("libexpat.so.1")'
pip install --no-cache-dir --retries 3 --timeout 30 'osmium==4.3.1'
python -c 'import osmium; print("OSM importer dependencies ready")'
