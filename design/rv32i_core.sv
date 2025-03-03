module rv32i_core(
    input clk,
    input rst_n
);

reg [3:0][7:0] mem[0:32768];

// ALU result
wire [31:0] alu_output;
wire [31:0] rd_val;

reg [31:0] pc;
reg [31:0] nxt_pc;
reg [31:0] nxt_seq_pc;

reg [31:0] ld_data;

wire dec_err;
wire [5:0] rd;
wire [5:0] rs1;
wire [5:0] rs2;
wire [31:0] imm;
wire [31:0] rs1_val;
wire [31:0] rs2_val;

wire is_auipc;
wire is_jal;
wire is_jalr;

    // BRANCH (B-type imm)
wire is_branch;
wire is_beq;
wire is_bne;
wire is_blt;
wire is_bge;
wire is_bltu;
wire is_bgeu;

    // LOAD (I-type imm)
wire is_lui;
wire is_lb;
wire is_lh;
wire is_lw;
wire is_lbu;
wire is_lhu;

    // STORE (S-type imm)
wire is_sb;
wire is_sh;
wire is_sw;

    // OP-IMM (I-type imm)
wire is_addi;
wire is_slti;
wire is_stliu;
wire is_xori;
wire is_ori;
wire is_andi;

    // OP-IMM-SHIFT (modified I-type imm)
wire is_slli;
wire is_srli;
wire is_srai;

    // OP (no imm)
wire is_add;
wire is_sub;

wire is_sll;
wire is_slt;
wire is_sltu;

wire is_xor;
wire is_srl;
wire is_sra;
wire is_or;
wire is_and;

    // MISC-MEM
wire is_fence;
wire is_fence_tso;
wire is_pause;

    // SYSTEM
wire is_ecall;
wire is_ebreak;


always @(posedge clk)
    if (~rst_n)
        pc <= 32'b0;
    else
    pc <= nxt_pc;

// NEXT PC COMPUTATION
assign nxt_seq_pc = pc + 3'b100;
assign nxt_pc = {dec_err ? {32{1'b0}} :
        // this would be later in pipelined operation:
        (alu_output && (is_beq || is_bne ||
                is_blt || is_bge ||
                is_bltu || is_bgeu)
        ) ? pc + $signed(imm) :
        is_jal ? pc + $signed(imm) :
        // this would be later in pipelined operation:
        is_jalr ? rs1_val + $signed(imm) :
        (is_ecall || is_ebreak) ? pc : // ?
        nxt_seq_pc } [30:0];


// INSTRUCTION FETCH
wire [31:0] instr = mem[pc>>2];


// INSTRUCTION DECODE
instr_decode i_instr_decode(
    .instr(instr),
    .dec_err( dec_err ),
    .rd( rd ),
    .rs1( rs1 ),
    .rs2( rs2 ),
    .imm( imm ),
    .wr_valid( wr_valid ),

    .is_auipc( is_auipc ),
    .is_jal( is_jal ),
    .is_jalr( is_jalr ),
    .is_branch( is_branch ),

    // BRANCH (B-type imm)
    .is_beq( is_beq ),
    .is_bne( is_bne ),
    .is_blt( is_blt ),
    .is_bge( is_bge ),
    .is_bltu( is_bltu ),
    .is_bgeu( is_bgeu ),

    // LOAD (I-type imm)
    .is_lui( is_lui ),
    .is_lb( is_lb ),
    .is_lh( is_lh ),
    .is_lw( is_lw ),
    .is_lbu( is_lbu ),
    .is_lhu( is_lhu ),

    // STORE (S-type imm)
    .is_sb( is_sb ),
    .is_sh( is_sh ),
    .is_sw( is_sw ),

    // OP-IMM (I-type imm)
    .is_addi( is_addi ),
    .is_slti( is_slti ),
    .is_stliu( is_stliu ),
    .is_xori( is_xori ),
    .is_ori( is_ori ),
    .is_andi( is_andi ),

    // OP-IMM-SHIFT (modified I-type imm)
    .is_slli( is_slli ),
    .is_srli( is_srli ),
    .is_srai( is_srai ),

    // OP (no imm)
    .is_add( is_add ),
    .is_sub( is_sub ),

    .is_sll( is_sll ),
    .is_slt( is_slt ),
    .is_sltu( is_sltu ),

    .is_xor( is_xor ),
    .is_srl( is_srl ),
    .is_sra( is_sra ),
    .is_or( is_or ),
    .is_and( is_and ),

    // MISC-MEM
    .is_fence( is_fence ),
    .is_fence_tso( is_fence_tso ),
    .is_pause( is_pause ),

    // SYSTEM
    .is_ecall( is_ecall ),
    .is_ebreak( is_ebreak )
);


// REGISTER FILE
regfile i_regfile(
    .clk( clk ),
    .rst_n( rst_n ),
    .rd( rd ),
    .rs1( rs1),
    .rs2( rs2 ),
    .wr_en( wr_valid ),
    .wr_data( rd_val ),
    .rd_rs1( rs1_val ),
    .rd_rs2( rs2_val )
);


// ALU
alu i_alu(
   .rd_val( alu_output ),
   .rs1_val( is_auipc ? pc : rs1_val ),
   .rs2_val( rs2_val ),
   .imm ( imm ),
   .*
);

// Load-Store "Unit"
// Compute memory indices to support unaligned access:
wire [31:2] b0_index = (alu_output[30:0] >> 2);
wire [31:2] b1_index = (alu_output[30:0] & 2'b11 == 2'b11) ? (alu_output[30:0] >> 2) + 1 : (alu_output[30:0] >> 2);
wire [31:2] b2_index = (alu_output[30:0] & 2'b11 == 2'b1?) ? (alu_output[30:0] >> 2) + 1 : (alu_output[30:0] >> 2);
wire [31:2] b3_index = (alu_output[30:0] & 2'b11 != 2'b00) ? (alu_output[30:0] >> 2) + 1 : (alu_output[30:0] >> 2);

wire [1:0] b0_offset = alu_output[1:0];
wire [1:0] b1_offset = b0_offset + 1;
wire [1:0] b2_offset = b1_offset + 1;
wire [1:0] b3_offset = b2_offset + 1;

// Perform "load":
always_comb begin
    case (1'b1)
        is_lb: ld_data = {{24{mem[b0_index][b0_offset][7]}}, mem[b0_index][b0_offset]};
        is_lh: ld_data = {{16{mem[b1_index][b1_offset][7]}}, mem[b1_index][b1_offset], mem[b0_index][b0_offset]};
        is_lw: ld_data = {mem[b3_index][b3_offset], mem[b2_index][b2_offset], mem[b1_index][b1_offset], mem[b0_index][b0_offset]};
        is_lbu: ld_data = {{24{1'b0}}, mem[b0_index][b0_offset]};
        is_lhu: ld_data = {{16{1'b0}}, mem[b1_index][b1_offset], mem[b0_index][b0_offset]};
        default: ld_data = 32'bx;
    endcase
end

// Perform "store":
always @(posedge clk) begin
    if (rst_n) begin
        if (is_sb || is_sh || is_sw)
            mem[b0_index][b0_offset] <= rs2_val[7:0];
        if (is_sh || is_sw)
            mem[b1_index][b1_offset] <= rs2_val[15:8];
        if (is_sw) begin
            mem[b2_index][b2_offset] <= rs2_val[23:16];
            mem[b3_index][b3_offset] <= rs2_val[31:24];
        end
    end
end


// Select write-back value (next PC; immediate value; or ALU output)
assign rd_val = is_jal | is_jalr ? nxt_seq_pc : is_lui ? imm : (is_lb || is_lh || is_lw || is_lbu || is_lhu) ? ld_data : alu_output;


endmodule
