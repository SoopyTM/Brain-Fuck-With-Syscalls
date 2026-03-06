#!/bin/bash

nasm -f elf32 ./src/main.asm -o ./output/main.o
ld -m elf_i386 ./output/main.o -o ./output/main
echo Compiled file is in ./output, and is named "main".
