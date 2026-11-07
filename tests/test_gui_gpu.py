"""Run the real shell helpers against fake device-tree/DRM data, never hardware."""

import os
from pathlib import Path
import subprocess

import pytest


GUI = Path(__file__).resolve().parents[1] / "src/modules/gui"


@pytest.fixture
def rig(tmp_path):
    model = tmp_path / "model"
    model.write_bytes(b"Raspberry Pi 5 Model B Rev 1.0\0")
    drm = tmp_path / "drm"
    drm.mkdir()
    driver = tmp_path / "drivers/vc4"
    driver.mkdir(parents=True)
    device = drm / "card1/device"
    device.mkdir(parents=True)
    (device / "driver").symlink_to(driver)
    log = tmp_path / "commands"
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for command in ("compton", "xset", "xrandr", "matchbox-window-manager"):
        stub = bin_dir / command
        stub.write_text(f'#!/bin/bash\necho "{command} $*" >> "$COMMAND_LOG"\n')
        stub.chmod(0o755)
    for command in ("sudo", "sed", "shutdown", "reboot", "tee", "touch"):
        stub = bin_dir / command
        stub.write_text(f'#!/bin/bash\necho "FORBIDDEN {command}" >> "$COMMAND_LOG"\nexit 99\n')
        stub.chmod(0o755)
    for command in ("bash", "tr", "basename", "readlink"):
        (bin_dir / command).symlink_to(Path("/usr/bin") / command)
    script = tmp_path / "enable_gpu"
    script.write_text(
        (GUI / "filesystem/opt/scripts/enable_gpu").read_text()
        .replace("/proc/device-tree/model", str(model))
        .replace("/sys/class/drm", str(drm))
    )
    script.chmod(0o755)
    # These represent a card's existing state and must survive every transition.
    files = [tmp_path / name for name in ("gpu_enabled", "config.txt", "cmdline.txt")]
    for file in files:
        file.write_text("existing configuration\n")
    env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}",
               COMMAND_LOG=str(log), DISPLAY=":7")
    return model, drm, script, log, env, files


def run(rig, *args):
    _, _, script, log, env, files = rig
    before = {file: file.read_bytes() for file in files}
    result = subprocess.run(["bash", str(script), *args], env=env,
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert before == {file: file.read_bytes() for file in files}
    commands = log.read_text() if log.exists() else ""
    assert "FORBIDDEN" not in commands
    return commands


def test_card_moves_pi5_pi3_pi5_pi3(rig):
    model, _, _, log, _, _ = rig
    for board, count in (("5 Model B", 0), ("3 Model B Plus", 1),
                         ("5 Model B", 1), ("3 Model B Plus", 2)):
        model.write_bytes(f"Raspberry Pi {board} Rev 1.0\0".encode())
        commands = run(rig, "--session")
        assert commands.count("compton ") == count
    assert "-d :7 --backend glx" in log.read_text()


@pytest.mark.parametrize("board", ["4 Model B", "400 Rev 1.0", "500 Rev 1.0",
                                    "Compute Module 4 Rev 1.0", "Compute Module 5 Rev 1.0",
                                    "1 Model B", "Zero W Rev 1.1", "Unknown"])
def test_modern_or_unknown_boards_are_untouched(rig, board):
    rig[0].write_bytes(f"Raspberry Pi {board}\0".encode())
    assert run(rig, "--session") == ""


@pytest.mark.parametrize("board", ["2 Model B", "3 Model B", "Compute Module 3 Plus", "Zero 2 W"])
def test_known_older_boards_with_vc4(rig, board):
    rig[0].write_bytes(f"Raspberry Pi {board}\0".encode())
    assert run(rig, "--session").count("compton ") == 1


def test_legacy_service_and_marker_are_harmless(rig):
    rig[0].write_bytes(b"Raspberry Pi 3 Model B\0")
    assert run(rig) == ""
    assert run(rig, "--session").count("compton ") == 1


def test_missing_model(rig):
    rig[0].unlink()
    assert run(rig, "--session") == ""


def test_no_bound_vc4(rig):
    rig[0].write_bytes(b"Raspberry Pi 3 Model B\0")
    (rig[1] / "card1/device/driver").unlink()
    assert run(rig, "--session") == ""


def test_missing_compositor(rig):
    rig[0].write_bytes(b"Raspberry Pi 3 Model B\0")
    (Path(rig[4]["PATH"].split(":")[0]) / "compton").unlink()
    # Do not find a host-installed compositor.
    rig[4]["PATH"] = rig[4]["PATH"].split(":")[0]
    assert run(rig, "--session") == ""


@pytest.mark.parametrize("acceleration,expected", [("yes", 1), ("no", 0)])
def test_generated_session_respects_acceleration(rig, acceleration, expected):
    model, _, helper, log, env, _ = rig
    model.write_bytes(b"Raspberry Pi 3 Model B\0")
    script = helper.parent / "start_gui"
    script.write_text(
        (GUI / "filesystem/opt/scripts/start_gui").read_text()
        .replace("GUI_ACCELERATION_PLACEHOLDER", acceleration)
        .replace("GUI_SESSION_PLACEHOLDER", "wait")
        .replace("/opt/custompios/scripts/enable_gpu", str(helper))
    )
    subprocess.run(["bash", str(script)], env=env, check=True)
    assert log.read_text().count("compton ") == expected


def test_build_wires_session_option_and_retires_firstboot():
    assert "systemctl enable enable_gpu_first_boot.service" not in (GUI / "start_chroot_script").read_text()
    assert "GUI_ACCELERATION_PLACEHOLDER@${GUI_INCLUDE_ACCELERATION}" in (GUI / "end_chroot_script").read_text()
