# 68k Dissasembler Written in Assembly

## Authors

Guiragos Guiragossian

Jonathan R. Hendrickson

Omar Nevarez

Dylan L. Thibault

## Description
The program takes 68k machine code and disassembles it into assembly code. There are 100’s of 68k assemble code instructions; this program focuses on disassembling only 20 of them as well as only 8 addressing modes. The program is written in 68k assembly code.

A trie structure is used to help identify the opcodes. This is done by incrementally testing the most significant bit on the operation, each bit can either be a 0 or 1. As each bit is tested the program is able to narrow down the possible opcode until there is only option available. After identifying said opcode the program branches into decoding that opcode. There is a subroutine for decode all 20 opcodes. 

Each subroutine takes the machine code and through bit testing, shifting and manipulation each instruction is decoded to show the opcode, size, and addressing modes. Depending on the addressing mode the program will then pull additional words from A2, as required. When each instruction is fully decoded, the program increments A2 by 16 bits and returns to the main loop to identify the next opcode.

## File List

1) DisMain.X68 : Dissasembler
2) DissasOutput.txt : Sample test case output
3) DissasReport : Report with deeper explanations of methdology and QA testing

## Run
Load the .X68 Disasasmbler main file into an emulator (e.g. [Easy68K](http://www.easy68k.com/)). Click open file and load an assembled 68k file in to the emulator.
Execute the dissasmbler and give the starting adress in hex. The program will give back the original assembly from the opcode hex given.
