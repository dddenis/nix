#!/usr/bin/env python3

import fcntl
import os
from pathlib import Path
import re
import subprocess
import sys


def main():
    binary = os.environ["HERDR_BIN_PATH"]
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    path = Path(os.environ.get("HERDR_CONFIG_PATH") or config_home / "herdr/config.toml")
    # Write through Home Manager's symlink; serialize repeated shortcut presses.
    with path.open("r+", encoding="utf-8", newline="") as config:
        fcntl.flock(config, fcntl.LOCK_EX)
        content = config.read()
        section = re.search(
            r"(?ms)^[ \t]*\[ui\.sound\][ \t]*(?:#[^\r\n]*)?\r?\n"
            r"(?:(?!^[ \t]*\[).)*",
            content,
        )
        setting = re.search(
            r"(?m)^[ \t]*enabled[ \t]*=[ \t]*(true|false)(?=[ \t]*(?:#[^\r\n]*)?\r?$)",
            section[0] if section else "",
        )
        if setting is None:
            raise ValueError(f"{path}: expected enabled = true or false under [ui.sound]")
        value = "false" if setting[1] == "true" else "true"
        start = section.start() + setting.start(1)
        end = section.start() + setting.end(1)
        config.seek(0)
        config.write(content[:start] + value + content[end:])
        config.truncate()
        config.flush()
        subprocess.run(
            [binary, "server", "reload-config"],
            check=True,
            stdin=subprocess.DEVNULL,
            timeout=10,
        )
    print(f"Herdr sound {'on' if value == 'true' else 'off'}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyError, ValueError, subprocess.SubprocessError) as error:
        print(f"sound-toggle: {error}", file=sys.stderr)
        sys.exit(1)
