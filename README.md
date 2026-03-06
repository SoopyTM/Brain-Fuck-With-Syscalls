# Brainfuck with System Calls

Thought this would be funny.

`.` triggers `int 0x80`.

Register mapping uses the first 28 tape bytes as 7 little-endian 32-bit values:
- `eax`: `cells[0..3]`
- `ebx`: `cells[4..7]`
- `ecx`: `cells[8..11]`
- `edx`: `cells[12..15]`
- `esi`: `cells[16..19]`
- `edi`: `cells[20..23]`
- `ebp`: `cells[24..27]`

Pointer convention for syscall args (`ebx`..`ebp`):
- If bit 31 is clear, the value is used as-is (numeric arg).
- If bit 31 is set, low 10 bits are treated as a tape index and converted to `&cells[index]`.
