`timescale 1ns/1ps
`include "rtl/cpu_top.v"

module tb_cpu_top;

    reg clk;
    reg rst;

    cpu_top uut (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("cpu_waveform.vcd");
        $dumpvars(0, tb_cpu_top);
    end

    initial begin

        rst = 1;
        #20;

        rst = 0;

        uut.IMEM.mem[0]  = 32'h00A00093;  // addi x1, x0, 10
        uut.IMEM.mem[1]  = 32'h00300113;  // addi x2, x0, 3
        uut.IMEM.mem[2]  = 32'hFFB00193;  // addi x3, x0, -5
        uut.IMEM.mem[3]  = 32'h00200213;  // addi x4, x0, 2

        uut.IMEM.mem[4]  = 32'h002082B3;  // add  x5, x1, x2
        uut.IMEM.mem[5]  = 32'h40208333;  // sub  x6, x1, x2
        uut.IMEM.mem[6]  = 32'h0020F3B3;  // and  x7, x1, x2
        uut.IMEM.mem[7]  = 32'h0020E433;  // or   x8, x1, x2
        uut.IMEM.mem[8]  = 32'h0020C4B3;  // xor  x9, x1, x2
        uut.IMEM.mem[9]  = 32'h00112533;  // slt  x10, x2, x1
        uut.IMEM.mem[10] = 32'h0011B5B3;  // sltu x11, x3, x1
        uut.IMEM.mem[11] = 32'h00409633;  // sll  x12, x1, x4
        uut.IMEM.mem[12] = 32'h0040D6B3;  // srl  x13, x1, x4
        uut.IMEM.mem[13] = 32'h4041D733;  // sra  x14, x3, x4

        #3000;

        rst = 1;
        #20;
        $finish;
    end
endmodule