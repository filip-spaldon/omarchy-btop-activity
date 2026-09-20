#!/usr/bin/env python3

import os
import re
import sys


proc_root, dri_root = sys.argv[1:3]
uid = os.getuid()
device_name = re.compile(r"^(?:card|renderD)[0-9]+$")
drm = set()

try:
    names = os.listdir(dri_root)
except OSError:
    sys.exit(0)

for name in names:
    if not device_name.fullmatch(name):
        continue
    try:
        st = os.stat(os.path.join(dri_root, name), follow_symlinks=True)
    except OSError:
        continue
    drm.add((st.st_dev, st.st_ino))

if not drm:
    sys.exit(0)

try:
    processes = os.scandir(proc_root)
except OSError:
    sys.exit(0)

with processes:
    for process in processes:
        if not process.name.isdigit():
            continue
        try:
            if process.stat(follow_symlinks=False).st_uid != uid:
                continue
            fdinfo_dir = os.path.join(process.path, "fdinfo")
            with os.scandir(os.path.join(process.path, "fd")) as fds:
                for fd in fds:
                    if not fd.name.isdigit():
                        continue
                    try:
                        st = fd.stat(follow_symlinks=True)
                    except OSError:
                        continue
                    if (st.st_dev, st.st_ino) not in drm:
                        continue
                    info = os.path.join(fdinfo_dir, fd.name)
                    if os.access(info, os.R_OK):
                        sys.stdout.buffer.write(os.fsencode(info) + b"\0")
        except OSError:
            continue
