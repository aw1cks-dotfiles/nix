from os import chmod, environ
from pathlib import Path
from shutil import copy
from subprocess import run
from sys import argv, stderr, stdout
from tempfile import NamedTemporaryFile

DISK_IMAGE = Path(argv[1])
if not DISK_IMAGE.is_file():
    raise RuntimeError("could not find disk image")

EXTRA_ARGS = argv[2:] if len(argv) > 2 else []

CPU_COUNT = int(environ.get("TESTVM_NUM_CORES", "2"))
MEM_MB = int(environ.get("TESTVM_MEM_MB", "8192"))

ARCH = environ.get("ARCH", "x86_64").split("-")[0]

if ARCH == "aarch64":
    ovmf_aarch64 = Path(environ["NIXPKG_AARCH64_OVMF__FD"])

    efi_firmware = ovmf_aarch64 / "FV/AAVMF_CODE.fd"
    efivars_src = ovmf_aarch64 / "FV/AAVMF_VARS.fd"

    machine = "virt"
elif ARCH == "x86_64":
    efi_firmware = Path(environ["NIXPKG_X86_64_OVMF__FIRMWARE"])
    efivars_src = Path(environ["NIXPKG_X86_64_OVMF__VARIABLES"])

    machine = "q35"
else:
    raise RuntimeError("Unknown arch: " + ARCH)

if not all([efi_firmware.is_file(), efivars_src.is_file()]):
    raise RuntimeError("Could not find EFI firmware")

if __name__ == "__main__":
    with NamedTemporaryFile(prefix="efivars-") as tmp_efivars:
        _ = copy(efivars_src, tmp_efivars.name)
        chmod(tmp_efivars.name, 0o755)

        qemu_cmd = [
            f"qemu-system-{ARCH}",
            "-machine",
            f"{machine},accel=kvm:tcg",
            "-cpu",
            "max",
            "-smp",
            str(CPU_COUNT),
            "-m",
            str(MEM_MB),
            "-device",
            "virtio-net-pci,netdev=net0",
            "-netdev",
            "user,id=net0,hostfwd=tcp::2222-:222",
            "-drive",
            f"if=pflash,format=raw,readonly=on,file={efi_firmware}",
            "-drive",
            f"if=pflash,format=raw,file={tmp_efivars.name}",
            "-drive",
            f"if=virtio,format=raw,file={DISK_IMAGE}",
            "-device",
            "virtio-gpu-pci",
            *EXTRA_ARGS,
        ]
        if environ.get("MACHINE_TYPE", "desktop") == "server":
            qemu_cmd.extend(["-serial", "mon:stdio"])

        _ = stderr.flush()
        _ = stdout.flush()
        _ = run(qemu_cmd)