`timescale 1ns/1ps

module cpu_top (
    input  wire clk,
    input  wire rst
);
    // Program Counter
    reg [31:0] PC;

    wire [31:0] pc_arch = PC;
    wire [31:0] pc_aligned = {pc_arch[31:2], 2'b00};
    wire [31:0] PC_plus_4 = pc_arch + 32'd4;

    // Instruction fetch
    wire [31:0] instruction;
    fetch_imem IMEM (
        .addr_word(PC[9:2]),
        .instruction(instruction)
    );

    // Decode fields
    wire [6:0] opcode   = instruction[6:0];
    wire [2:0] funct3   = instruction[14:12];
    wire [6:0] funct7   = instruction[31:25];
    wire [4:0] rd_addr  = instruction[11:7];
    wire [4:0] rs1_addr = instruction[19:15];
    wire [4:0] rs2_addr = instruction[24:20];

    // Control signals
    wire        reg_write;
    wire        alu_src;
    wire [3:0]  alu_op;
    wire        mem_read;
    wire        mem_write;
    wire [1:0]  wb_sel;
    wire        branch;
    wire [2:0]  branch_type;
    wire        auipc_flag;
    wire        lui_flag;
    wire        jal_flag;
    wire        jalr_flag;

    decoder DEC (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .wb_sel(wb_sel),
        .branch(branch),
        .branch_type(branch_type),
        .auipc_flag(auipc_flag),
        .lui_flag(lui_flag),
        .jal_flag(jal_flag),
        .jalr_flag(jalr_flag)
    );

    // Register file
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] rd_wdata;

    regfile REGFILE (
        .clk(clk),
        .rst(rst),
        .we(reg_write),
        .waddr(rd_addr),
        .wdata(rd_wdata),
        .raddr1(rs1_addr),
        .raddr2(rs2_addr),
        .rdata1(rs1_data),
        .rdata2(rs2_data)
    );

    // Immediate generation
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    imm_gen IMMGEN (
        .instr(instruction),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_b(imm_b),
        .imm_u(imm_u),
        .imm_j(imm_j)
    );

    // ALU inputs and operation
    wire [31:0] alu_in0 = rs1_data;

    wire [31:0] chosen_imm =
        (lui_flag)   ? imm_u :
        (jal_flag)   ? imm_j :
        (mem_write)  ? imm_s :
        (jalr_flag)  ? imm_i :
                       imm_i;

    wire [31:0] alu_in1 = alu_src ? chosen_imm : rs2_data;

    wire [31:0] alu_result;
    wire        zero_flag;
    wire        lt_signed;
    wire        lt_unsigned;

    alu ALU (
        .in0(alu_in0),
        .in1(alu_in1),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(zero_flag),
        .lt_signed(lt_signed),
        .lt_unsigned(lt_unsigned)
    );

    // Data memory
    wire [31:0] mem_read_data;
    dmem DATAMEM (
        .clk(clk),
        .rst(rst),
        .addr(alu_result),
        .write_data(rs2_data),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .read_data(mem_read_data)
    );

    // Branch and jump decison
    wire branch_taken = branch ? evaluate_branch(branch_type, zero_flag, lt_signed, lt_unsigned) : 1'b0;

    wire [31:0] target_pc =
        (jal_flag)     ? (pc_aligned + imm_j) :
        (jalr_flag)    ? ((rs1_data + imm_i) & ~32'd1) :
        (branch_taken) ? (pc_aligned + imm_b) :
                         pc_aligned;

    wire take_jump_or_branch = jal_flag | jalr_flag | branch_taken;

    // Writeback selection
    wire [31:0] wb_from_alu   = alu_result;
    wire [31:0] wb_from_mem   = mem_read_data;
    wire [31:0] wb_from_pc4   = PC_plus_4;
    wire [31:0] wb_from_uimm  = imm_u;
    wire [31:0] wb_from_auipc = pc_aligned + imm_u;

    reg [31:0] wb_mux_out;
    always @(*) begin
        case (wb_sel)
            2'b00: wb_mux_out = wb_from_alu;
            2'b01: wb_mux_out = wb_from_mem;
            2'b10: wb_mux_out = wb_from_pc4;
            2'b11: wb_mux_out = auipc_flag ? wb_from_auipc : wb_from_uimm;
            default: wb_mux_out = 32'hDEADBEEF;
        endcase
    end
    assign rd_wdata = wb_mux_out;

    // Sequential PC update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC <= 32'd0;
        end else begin
            if (take_jump_or_branch) begin
                PC <= target_pc;
            end else begin
                PC <= PC_plus_4;
            end
        end
    end

    // Branch evaluation
    function evaluate_branch;
        input [2:0] brt;
        input       z;
        input       lt_s;
        input       lt_u;
        begin
            case (brt)
                3'b000: evaluate_branch = z;
                3'b001: evaluate_branch = ~z;
                3'b100: evaluate_branch = lt_s;
                3'b101: evaluate_branch = ~lt_s;
                3'b110: evaluate_branch = lt_u;
                3'b111: evaluate_branch = ~lt_u;
                default: evaluate_branch = 1'b0;
            endcase
        end
    endfunction

endmodule

module fetch_imem (
    input  wire [7:0] addr_word,
    output reg  [31:0] instruction
);
    reg [31:0] mem [0:255];
    integer i;
    initial begin
        for (i = 27; i < 256; i = i + 1) mem[i] = 32'h00000013;
    end

    always @(*) begin
        instruction = mem[addr_word];
    end
endmodule


module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm_i,
    output reg  [31:0] imm_s,
    output reg  [31:0] imm_b,
    output reg  [31:0] imm_u,
    output reg  [31:0] imm_j
);
    always @(*) begin
        imm_i = {{20{instr[31]}}, instr[31:20]};
        imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        imm_u = {instr[31:12], 12'b0};
        imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    end
endmodule


module decoder (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg       reg_write,
    output reg       alu_src,
    output reg [3:0] alu_op,
    output reg       mem_read,
    output reg       mem_write,
    output reg [1:0] wb_sel,
    output reg       branch,
    output reg [2:0] branch_type,
    output reg       auipc_flag,
    output reg       lui_flag,
    output reg       jal_flag,
    output reg       jalr_flag
);
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_AND  = 4'd2;
    localparam ALU_OR   = 4'd3;
    localparam ALU_XOR  = 4'd4;
    localparam ALU_SLL  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_SLT  = 4'd8;
    localparam ALU_SLTU = 4'd9;

    always @(*) begin
        reg_write   = 1'b0;
        alu_src     = 1'b0;
        alu_op      = ALU_ADD;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        wb_sel      = 2'b00;
        branch      = 1'b0;
        branch_type = 3'b000;
        auipc_flag  = 1'b0;
        lui_flag    = 1'b0;
        jal_flag    = 1'b0;
        jalr_flag   = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                alu_src = 1'b0;
                wb_sel = 2'b00;
                case (funct3)
                    3'b000: alu_op = (funct7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
                    3'b111: alu_op = ALU_AND;
                    3'b110: alu_op = ALU_OR;
                    3'b100: alu_op = ALU_XOR;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: alu_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    default: alu_op = ALU_ADD;
                endcase
            end

            7'b0010011: begin // OP-IMM
                reg_write = 1'b1;
                alu_src = 1'b1;
                wb_sel = 2'b00;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b111: alu_op = ALU_AND;
                    3'b110: alu_op = ALU_OR;
                    3'b100: alu_op = ALU_XOR;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: alu_op = (funct7[5] == 1'b1) ? ALU_SRA : ALU_SRL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    default: alu_op = ALU_ADD;
                endcase
            end

            7'b0000011: begin // LOAD
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD;
                mem_read = 1'b1;
                wb_sel = 2'b01;
            end

            7'b0100011: begin // STORE
                reg_write = 1'b0;
                alu_src = 1'b1;
                alu_op = ALU_ADD;
                mem_write = 1'b1;
                wb_sel = 2'b00;
            end

            7'b1100011: begin // BRANCH
                reg_write = 1'b0;
                alu_src = 1'b0;
                branch = 1'b1;
                branch_type = funct3;
                case (funct3)
                    3'b000: alu_op = ALU_SUB;
                    3'b001: alu_op = ALU_SUB;
                    3'b100: alu_op = ALU_SLT;
                    3'b101: alu_op = ALU_SLT;
                    3'b110: alu_op = ALU_SLTU;
                    3'b111: alu_op = ALU_SLTU;
                    default: alu_op = ALU_SUB;
                endcase
            end

            7'b0110111: begin // LUI
                reg_write = 1'b1;
                alu_src = 1'b1;
                wb_sel = 2'b11;
                lui_flag = 1'b1;
            end

            7'b0010111: begin // AUIPC
                reg_write = 1'b1;
                wb_sel = 2'b11;
                auipc_flag = 1'b1;
            end

            7'b1101111: begin // JAL
                reg_write = 1'b1;
                wb_sel = 2'b10;
                jal_flag = 1'b1;
            end

            7'b1100111: begin // JALR
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_op = ALU_ADD;
                wb_sel = 2'b10;
                jalr_flag = 1'b1;
            end

            default: begin
            end
        endcase
    end
endmodule


module alu (
    input  wire [31:0] in0,
    input  wire [31:0] in1,
    input  wire [3:0]  alu_op,
    output reg  [31:0] result,
    output reg         zero,
    output reg         lt_signed,
    output reg         lt_unsigned
);
    always @(*) begin
        case (alu_op)
            4'd0: result = in0 + in1;
            4'd1: result = in0 - in1;
            4'd2: result = in0 & in1;
            4'd3: result = in0 | in1;
            4'd4: result = in0 ^ in1;
            4'd5: result = in0 << in1[4:0];
            4'd6: result = in0 >> in1[4:0];
            4'd7: result = $signed(in0) >>> in1[4:0];
            4'd8: result = ($signed(in0) < $signed(in1)) ? 32'd1 : 32'd0;
            4'd9: result = (in0 < in1) ? 32'd1 : 32'd0;
            default: result = 32'd0;
        endcase

        zero = (result == 32'd0);
        lt_signed = ($signed(in0) < $signed(in1)) ? 1'b1 : 1'b0;
        lt_unsigned = (in0 < in1) ? 1'b1 : 1'b0;
    end
endmodule


module regfile (
    input  wire clk,
    input  wire rst,
    input  wire we,
    input  wire [4:0] waddr,
    input  wire [31:0] wdata,
    input  wire [4:0] raddr1,
    input  wire [4:0] raddr2,
    output reg  [31:0] rdata1,
    output reg  [31:0] rdata2
);
    reg [31:0] regs [0:31];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) regs[i] <= 32'd0;
        end else begin
            if (we && (waddr != 5'd0)) regs[waddr] <= wdata;
            regs[0] <= 32'd0;
        end
    end

    always @(*) begin
        rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
        rdata2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];
    end
endmodule


module dmem (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    input  wire        mem_read,
    input  wire        mem_write,
    output reg  [31:0] read_data
);
    reg [31:0] data_mem [0:1023];
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) data_mem[i] = 32'd0;
        read_data = 32'd0;
    end

    always @(posedge clk) begin
        if (mem_write) begin
            data_mem[addr[11:2]] <= write_data;
        end
    end
    
    always @(*) begin
        if (mem_read)  read_data = data_mem[addr[11:2]];
        else           read_data = 32'd0;
    end
endmodule