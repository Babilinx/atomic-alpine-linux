# Atomic Alpine Linux

Atomic Alpine Linux (AAL for short) is a project that want to make an immutable Alpine Linux system.
The goal is to make it work on the most minimal installation using simple `sh` files (no need for `bash`/`fish`/`zsh`)
and capabilities already existing in Alpine Linux.

To make everything work, we are relying on BTRFS snapshots that provide an easy way to have multiple roots
at the same time while keeping used space low, and Unified Kernel Images, so no need for any bootloader
except the one from your UEFI, and you can use secureboot to reduce attack surface on your computer.

The end goal of the project is not to make Alpine Linux easier, instead it brings more complexity into it,
but more to provide a tool that can ensure your system to boot at any time, even if an update breaks one snapshot.

