module rv32i_core(
    input clk,
    input rst_n
);

reg [3:0][7:0] mem[0:8388608];

reg [31:0] instr;

// ALU result
wire [31:0] alu_output;
wire [31:0] rd_val;

reg [31:0] pc;
reg [31:0] nxt_pc;
reg [31:0] nxt_seq_pc;
reg [31:0] nxt_pc_w_trap;

reg [31:0] ld_data;
reg [31:0] csr_read_data;
reg invalid_csr;
wire machine_interrupt;
wire supervisor_interrupt;
wire medelegated;

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
wire is_sfence_vma;
wire is_pause;

    // SYSTEM
wire is_ecall;
wire is_ebreak;
wire is_mret;
wire is_sret;
wire is_wfi;

   // CSR
wire is_csrrw;
wire is_csrrs;
wire is_csrrc;
wire is_csrrwi;
wire is_csrrsi;
wire is_csrrci;

wire instr_trap;

always @(posedge clk)
    if (~rst_n)
        pc <= 32'h8000_0000;
    else
        pc <= nxt_pc_w_trap;

reg wfi_pending;
wire wfi_clear = |(i_zicsr.mip & i_zicsr.mie) || |(i_zicsr.sip & i_zicsr.sie);
always @(posedge clk or negedge rst_n)
    if (~rst_n)
        wfi_pending <= 0;
    else if (wfi_clear)
        wfi_pending <= 0;
    else
        wfi_pending <= is_wfi;


// NEXT PC COMPUTATION
assign nxt_seq_pc = pc + 3'b100;
wire [31:0] jalr_target = {({1'b0, rs1_val} + $signed(imm))}[31:0];
assign nxt_pc = {
        // this would be later in pipelined operation:
        (alu_output && (is_beq || is_bne ||
                        is_blt || is_bge ||
                        is_bltu || is_bgeu)) ? {{1'b0, pc} + $signed(imm)}[31:0] :
        is_jal ? {{1'b0, pc} + $signed(imm)}[31:0] :
        // this would be later in pipelined operation:
        is_jalr ? {({1'b0, rs1_val} + $signed(imm))&~(32'b1)}[31:0] :
        is_mret ? i_zicsr.mepc :
        is_sret ? i_zicsr.sepc :
        (is_wfi || wfi_pending) && ~wfi_clear ? pc : nxt_seq_pc } [31:0];


assign nxt_pc_w_trap = instr_trap        ? ( !medelegated ? {i_zicsr.mtvec[31:2], 2'b00} :
                                                            {i_zicsr.stvec[31:2], 2'b00} ) :
                       machine_interrupt ? ( i_zicsr.mi_vector_addr ) : nxt_pc;


// INSTRUCTION FETCH
assign instr = mem[pc[30:0]>>2];


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
    .is_sfence_vma( is_sfence_vma ),
    .is_pause( is_pause ),

    // SYSTEM
    .is_ecall( is_ecall ),
    .is_ebreak( is_ebreak ),
    .is_mret( is_mret ),
    .is_sret( is_sret ),
    .is_wfi( is_wfi ),

    // CSR
    .is_csrrw( is_csrrw ),
    .is_csrrs( is_csrrs ),
    .is_csrrc( is_csrrc ),
    .is_csrrwi( is_csrrwi ),
    .is_csrrsi( is_csrrsi ),
    .is_csrrci( is_csrrci )
);


// REGISTER FILE
regfile i_regfile(
    .clk( clk ),
    .rst_n( rst_n ),
    .rd( rd ),
    .rs1( rs1),
    .rs2( rs2 ),
    .wr_en( wr_valid && ~instr_trap && ~machine_interrupt  && ~supervisor_interrupt),  // FIXME no logic in port connections
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
    if (rst_n && ~instr_trap) begin
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

// CSRs:
wire [31:0] csr_write_data;
assign csr_write_data = (is_csrrw || is_csrrs || is_csrrc) ? rs1_val :
                        (is_csrrwi || is_csrrsi || is_csrrci) ? instr[19:15] : 32'bx;
zicsr i_zicsr(
    .clk( clk ),
    .rst_n( rst_n ),
    .read_data( csr_read_data ),
    .write_data( csr_write_data ),
    .invalid_csr( invalid_csr ),
    .csr( imm[11:0] ),
    .pc( pc ),
    .nxt_pc( nxt_pc ),
    .instr( instr ),
    .mem_addr( {2'b00, alu_output} ),
    .is_csrrw( is_csrrw ),
    .is_csrrs( is_csrrs ),
    .is_csrrc( is_csrrc ),
    .is_csrrwi( is_csrrwi ),
    .is_csrrsi( is_csrrsi ),
    .is_csrrci( is_csrrci ),

    .is_ebreak( is_ebreak ),
    .is_ecall( is_ecall ),
    .is_mret( is_mret ),
    .is_sret( is_sret ),
    .*
);


// Select write-back value (next PC; immediate value; or ALU output)
assign rd_val = is_jal | is_jalr ? nxt_seq_pc : is_lui ? imm :
                (is_lb || is_lh || is_lw || is_lbu || is_lhu) ? ld_data :
                (is_csrrw || is_csrrwi || is_csrrs || is_csrrsi || is_csrrc || is_csrrci) ? csr_read_data : alu_output;

// Traps


wire addr_oob = (alu_output < $unsigned(32'h8000_0000)) || ($unsigned(alu_output) >= $unsigned(32'h8080_0000));

// 0 - Instruction address misaligned - Exception is reported on the branch
// or link instruction that targets an address which is not IALIGN-bit aligned
// (32 bit here)
wire trap_instr_addr_misaligned = (is_branch || is_jal || is_jalr) && (|nxt_pc[1:0]);

// 1 - Instruction access fault -- would require implementing Physical Memory Protection CSRs

// 2 - illegal instruction - many
wire trap_illegal_instr = dec_err ||
                          invalid_csr ||
                          (i_zicsr.priv_mode != 2'b11 && is_mret) ||
                          (i_zicsr.priv_mode == 2'b00 && is_sret) ||
                          ((is_csrrw || is_csrrwi || is_csrrs || is_csrrsi || is_csrrc || is_csrrci) && !(i_zicsr.priv_mode >= imm[9:8])) ||
                          (i_zicsr.mstatus[21] && is_wfi) ||
                          (i_zicsr.mstatus[20] && (is_sfence_vma ||
                                                  ((is_csrrw || is_csrrwi || is_csrrs || is_csrrsi || is_csrrc || is_csrrci) && i_zicsr.csr==12'h180))) ||
                          (i_zicsr.mstatus[22] && is_sret);


// 3 - breakpoint
wire trap_breakpt = is_ebreak;

// 4 - load address misaligned
wire trap_ld_addr_misaligned = ((is_lh || is_lhu) && alu_output[0]) || (is_lw && (|alu_output[1:0]));

// 5 - load access fault
wire trap_ld_access_fault = i_instr_decode.is_load && addr_oob;


// 6 - Store/AMO address misaligned
wire trap_st_amo_addr_misaligned = (is_sh && alu_output[0]) || (is_sw && (|alu_output[1:0]));

// 7 - Store/AMO access fault
wire trap_st_amo_access_fault = (i_instr_decode.is_store || i_instr_decode.is_amo) && addr_oob;


assign instr_trap = is_ebreak || is_ecall || trap_instr_addr_misaligned || trap_illegal_instr || trap_breakpt || trap_ld_addr_misaligned || trap_ld_access_fault || trap_st_amo_addr_misaligned || trap_st_amo_access_fault;


endmodule
