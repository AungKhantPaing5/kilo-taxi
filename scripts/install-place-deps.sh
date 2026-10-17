#!/bin/sh
set -eu
# Keep all Debian repository traffic on HTTPS for networks that block port 80.
find /etc/apt -type f \( -name '*.sources' -o -name '*.list' \) -exec sed -i \
  -e 's|http://deb.debian.org|https://deb.debian.org|g' \
  -e 's|http://security.debian.org|https://security.debian.org|g' {} +
# Do not proceed with a stale/missing package index after a network failure.
apt-get -o Acquire::Retries=3 -o Acquire::https::Timeout=30 -o APT::Update::Error-Mode=any update
apt-get -o Acquire::Retries=3 -o Acquire::https::Timeout=30 install -y --no-install-recommends libexpat1 libbz2-1.0 liblzma5 libstdc++6 zlib1g
pip install --no-cache-dir 'osmium>=4,<5'
