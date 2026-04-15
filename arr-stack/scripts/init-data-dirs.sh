#!/bin/sh
# Creates DATA_ROOT layout expected by compose volume mounts. Runs in the init-dirs
# container (see compose.yml). Mount point inside the container: /data

set -eu

BASE=/data
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

mkdir -p \
  "${BASE}/downloads" \
  "${BASE}/downloads/movies" \
  "${BASE}/downloads/tv" \
  "${BASE}/downloads/music" \
  "${BASE}/downloads/books" \
  "${BASE}/downloads/adult" \
  "${BASE}/tv" \
  "${BASE}/movies" \
  "${BASE}/books" \
  "${BASE}/music" \
  "${BASE}/adult/movies"

# Large media/download roots: set ownership on the directory only (avoid walking trees).
for d in downloads tv movies books music adult; do
  chown "${PUID}:${PGID}" "${BASE}/${d}"
done
