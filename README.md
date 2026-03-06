# Brainfuck with System Calls

Thought this would be funny.

This took longer than i thought it would if i'm going to be honest. But, i was so determined to get it done since i thought it was a cool idea.
Anyway, i'm done with this one now. If you find this and want to contribute, then feel free. But, i'm gonna stop.
I will be honest, i got chatgpt to write a lot of it near the end, cause i couldn't be bothered, and wanted the end product as quick as possible.

Quick thing: i haven't tested every syscall ever. I don't plan to, but if you try to do a syscall and it doesn't work, deal with it. Also there's no error messages for debugging, cause fuck you.

## What This Is
This is a Brainfuck interpreter where certain cells (the first few) work like registers, and `.` does a Linux `int 0x80` syscall instead of normal BF output.

Normal Brainfuck ops are supported:
- `+ - < > [ ] .`

## Syscall Register Layout
Before `.` runs, the interpreter reads the first 28 tape cells as 7 little-endian 32-bit registers:
- `eax`: `cells[0..3]`
- `ebx`: `cells[4..7]`
- `ecx`: `cells[8..11]`
- `edx`: `cells[12..15]`
- `esi`: `cells[16..19]`
- `edi`: `cells[20..23]`
- `ebp`: `cells[24..27]`

Little-endian means:
- value = `b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)`

Example:
- `eax = 4` -> `cells[0]=4, cells[1]=0, cells[2]=0, cells[3]=0`

## Pointer Arguments
For syscall args (`ebx`..`ebp`), values can be numeric or pointers:
- If bit 31 is clear, the value is used as-is (numeric arg).
- If bit 31 is set, low 10 bits are treated as a tape index and converted to `&cells[index]`.

Pointer encoding formula:
- `encoded_ptr = 0x80000000 | index`

Example:
- pointer to `cells[40]` is `0x80000028`
- byte layout in a register is `[0x28, 0x00, 0x00, 0x80]`

## How To Write `sys_write`
Linux `write` syscall:
- `eax = 4`
- `ebx = fd` (use `1` for stdout)
- `ecx = pointer to bytes`
- `edx = length`

In this VM:
1. Put `4` in `eax` bytes (`cells[0..3]`)
2. Put `1` in `ebx` bytes (`cells[4..7]`)
3. Put pointer-tagged index in `ecx` bytes (`cells[8..11]`)
4. Put byte length in `edx` bytes (`cells[12..15]`)
5. Place your message in tape cells at that index
6. Run `.`

## Loops
`[` and `]` are standard Brainfuck loops:
- `[` jumps forward to matching `]` if current cell is zero
- `]` jumps back to matching `[` if current cell is non-zero
- nested loops are supported

## Files In This Repo
- `testFile.bf`: small loop + syscall demo
- `HelloWorld.bf`: loop-based `sys_write` program that prints `Hello, World!\n`

## Build / Run
This project targets Linux x86 `int 0x80` style syscalls. I went with 32 bit cause i like how the registers go up in the alphabet. :)

To compile run compile.sh:
```bash
./compile.sh
```

Compile yourself:
```bash
nasm -f elf32 ./src/main.asm -o ./output/main.o
ld -m elf_i386 ./output/main.o -o ./output/main
./output/main HelloWorld.bf
```
