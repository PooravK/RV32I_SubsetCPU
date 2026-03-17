# RV32I SUBSET CPU

### Specifications
Subset of 32 bit instructions RV32I processor
Harvard style architecture
32-bit word size with 32 general registers
Supports R, I, S, B, U and J type instructions
Modular Design
Five step execution: Fetch, Decode, Execute, Memory, Write Back

### Instructions implemented
R Type: add, sub, and, or, xor, sll, srl, sra, slt, sltu
I Type: addi, andi, ori, xori, slli, srli, srai, slti, sltiu, lw, jalr
S Type: sw
B Type: beq, bne, blt, bge, bltu, bgeu
U Type: lui, auipc
J Type: jal
