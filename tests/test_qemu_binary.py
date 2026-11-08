"""Exercise QEMU selection without requiring emulation or root privileges."""

import os
from pathlib import Path
import subprocess

import pytest


COMMON = Path(__file__).resolve().parents[1] / "src/common.sh"


@pytest.mark.parametrize("arch", ["arm", "aarch64"])
@pytest.mark.parametrize("packaging", ["legacy", "modern", "both", "dynamic", "missing"])
def test_copy_qemu_binary(tmp_path, arch, packaging):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    (tmp_path / "usr/bin").mkdir(parents=True)
    for suffix in ("-static", ""):
        if (suffix and packaging in ("legacy", "both")) or (
            not suffix and packaging in ("modern", "both", "dynamic")
        ):
            binary = bin_dir / f"qemu-{arch}{suffix}"
            # A script is deliberately not a static ELF: mock only its file output.
            binary.write_text(f"#!/bin/sh\necho {suffix or 'modern'}\n")
            binary.chmod(0o755)
    description = "dynamically linked" if packaging == "dynamic" else "static-pie linked"
    script = f'''
source "{COMMON}"
which() {{
    [ -x "$TEST_BIN/$1" ] || return 1
    echo "$TEST_BIN/$1"
}}
file() {{ echo 'ELF 64-bit, {description}'; }}
copy_qemu_static "{arch}"
'''
    result = subprocess.run(
        ["bash", "-c", script], cwd=tmp_path,
        env=dict(os.environ, TEST_BIN=str(bin_dir)), capture_output=True, text=True,
    )
    copied = tmp_path / f"usr/bin/qemu-{arch}-static"
    if packaging in ("dynamic", "missing"):
        assert result.returncode != 0
        assert "Error:" in result.stderr
        assert not copied.exists()
    else:
        assert result.returncode == 0, result.stderr
        suffix = "-static" if packaging in ("legacy", "both") else ""
        assert copied.read_bytes() == (bin_dir / f"qemu-{arch}{suffix}").read_bytes()


def test_setup_failure_prevents_chroot(tmp_path):
    script = f'''
source "{COMMON}"
cp() {{ :; }}
chmod() {{ :; }}
setup_qemu_static() {{ return 17; }}
chroot() {{ echo 'CHROOT RAN'; }}
chroot_correct_qemu x86_64 arm64 unused unused
'''
    result = subprocess.run(["bash", "-c", script], cwd=tmp_path,
                            capture_output=True, text=True)
    assert result.returncode == 17
    assert "CHROOT RAN" not in result.stdout


def test_generated_chroot_shell_inherits_qemu_helpers(tmp_path):
    binary = tmp_path / "qemu-aarch64"
    binary.write_text("modern static emulator\n")
    (tmp_path / "usr/bin").mkdir(parents=True)
    # Use the builder's actual export list, not a duplicate maintained by the test.
    exports = "\n".join(
        line.strip() for line in COMMON.with_name("custompios").read_text().splitlines()
        if line.strip().startswith("export -f ") and "qemu" in line
    )
    script = f'''
source "{COMMON}"
which() {{
    [ "$1" = qemu-aarch64 ] || return 1
    echo "{binary}"
}}
file() {{ echo 'ELF 64-bit, statically linked'; }}
export -f which file
{exports}
bash -c 'setup_qemu_static x86_64 arm64'
'''
    result = subprocess.run(["bash", "-c", script], cwd=tmp_path,
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "usr/bin/qemu-aarch64-static").read_bytes() == binary.read_bytes()
