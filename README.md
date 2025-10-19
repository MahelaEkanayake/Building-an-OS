# Building-an-OS
This is a study on how to make an OS from scratch to x86 architecture.

This 512-byte binary is a minimal boot sector that halts the CPU.
It starts at 0x7C00, runs in 16-bit real mode, fills unused bytes with zeros, and ends with the BIOS boot signature 0xAA55.
