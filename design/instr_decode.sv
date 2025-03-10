module instr_decode (
    input [31:0] instr,
    output dec_err,
    output [5:0] rd,
    output [5:0] rs1,
    output [5:0] rs2,
    output [31:0] imm,
    output wr_valid,

    // AUIPUC (U-type imm)
    output is_auipc,

    // JAL (J-type imm)
    output is_jal,

    // JALR (I-type imm)
    output is_jalr,

    // BRANCH (B-type imm)
    output is_branch,
    output is_beq,
    output is_bne,
    output is_blt,
    output is_bge,
    output is_bltu,
    output is_bgeu,

    // LUI (U-type imm);
    output is_lui,

    // LOAD (I-type imm)
    output is_lb,
    output is_lh,
    output is_lw,
    output is_lbu,
    output is_lhu,

    // STORE (S-type imm)
    output is_sb,
    output is_sh,
    output is_sw,

    // OP-IMM (I-type imm)
    output is_addi,
    output is_slti,
    output is_stliu,
    output is_xori,
    output is_ori,
    output is_andi,

    // OP-IMM-SHIFT (modified I-type imm)
    output is_slli,
    output is_srli,
    output is_srai,

    // OP (no imm)
    output is_add,
    output is_sub,

    output is_sll,
    output is_slt,
    output is_sltu,

    output is_xor,
    output is_srl,
    output is_sra,
    output is_or,
    output is_and,

    // MISC-MEM
    output is_fence,
    output is_fence_tso,
    output is_pause,

    // SYSTEM
    output is_ecall,
    output is_ebreak,
    output is_mret,
    output is_sret,

    // CSR
    output is_csrrw,
    output is_csrrs,
    output is_csrrc,
    output is_csrrwi,
    output is_csrrsi,
    output is_csrrci
);

  // OPERANDS
  assign rd  = instr[11:7];
  assign rs1 = instr[19:15];
  assign rs2 = instr[24:20];

  wire [2:0] funct3 = instr[14:12];
  wire [6:0] funct7 = instr[31:25];

  wire [4:0] opcode = instr[6:2];

  wire valid_32b_instr = instr[1:0] == 2'b11;

  // 5'b00000 - LOAD
  wire is_load = valid_32b_instr && opcode == 5'b00000;

  // 5'b01000 - STORE
  wire is_store = valid_32b_instr && opcode == 5'b01000;

  // 5'b11000 - BRANCH
  assign is_branch = valid_32b_instr && opcode == 5'b11000;

  // 5'b00011 - MISC-MEM (eg, fence)
  wire is_misc_mem = valid_32b_instr && opcode == 5'b00011;

  // 5'b00100 - OP-IMM
  wire is_op_imm = valid_32b_instr && opcode == 5'b00100;

  // 5'b00101 - AUIPC
  wire is_auipc = valid_32b_instr && opcode == 5'b000101;

  // 5'b01011 - AMO
  wire is_amo = valid_32b_instr && opcode == 5'b01011;

  // 5'b01100 - OP
  wire is_op = valid_32b_instr && opcode == 5'b01100;

  // 5'b01101 - LUI
  wire is_lui = valid_32b_instr && opcode == 5'b01101;

  // 5'b11001 - JALR
  wire is_jalr = valid_32b_instr && opcode == 5'b11001 && funct3 == 3'b000;

  // 5'b11011 - JAL
  wire is_jal = valid_32b_instr && opcode == 5'b11011;

  // 5'b11100 - SYSTEM
  wire is_system = valid_32b_instr && opcode == 5'b11100;


  // Immediate values:
  // U-type:
  wire [31:0] i_type_imm = {{20{instr[31]}}, instr[31:20]};
  wire [31:0] i_type_imm_shift = {{24{1'b0}}, instr[24:20]};
  wire [31:0] u_type_imm = {instr[31:12], {12{1'b0}}};
  wire [31:0] j_type_imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
  wire [31:0] s_type_imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
  wire [31:0] b_type_imm = {{20{instr[31]}}, instr[7], s_type_imm[10:1], 1'b0};

  // RV32I BASE INSTRUCTION SET

  // LUI (U-type imm)
  //  (is_lui)

  // AUIPC (U-type imm)
  //  (is_auipc)

  // JAL (J-type imm)
  //  (is_jal)

  // JALR (I-type imm)
  //  (is_jalr)

  // BRANCH (B-type imm)
  assign is_beq = is_branch && funct3 == 3'b000;
  assign is_bne = is_branch && funct3 == 3'b001;
  assign is_blt = is_branch && funct3 == 3'b100;
  assign is_bge = is_branch && funct3 == 3'b101;
  assign is_bltu = is_branch && funct3 == 3'b110;
  assign is_bgeu = is_branch && funct3 == 3'b111;

  // LOAD (I-type imm)
  assign is_lb = is_load && funct3 == 3'b000;
  assign is_lh = is_load && funct3 == 3'b001;
  assign is_lw = is_load && funct3 == 3'b010;
  assign is_lbu = is_load && funct3 == 3'b100;
  assign is_lhu = is_load && funct3 == 3'b101;

  // STORE (S-type imm)
  assign is_sb = is_store && funct3 == 3'b000;
  assign is_sh = is_store && funct3 == 3'b001;
  assign is_sw = is_store && funct3 == 3'b010;

  // OP-IMM (I-type imm)
  assign is_addi = is_op_imm && funct3 == 3'b000;
  assign is_slti = is_op_imm && funct3 == 3'b010;
  assign is_stliu = is_op_imm && funct3 == 3'b011;
  assign is_xori = is_op_imm && funct3 == 3'b100;
  assign is_ori = is_op_imm && funct3 == 3'b110;
  assign is_andi = is_op_imm && funct3 == 3'b111;

  // OP-IMM-SHIFT (modified I-type imm)
  assign is_slli = is_op_imm && funct3 == 3'b001 && funct7 == 7'b0000000;
  assign is_srli = is_op_imm && funct3 == 3'b101 && funct7 == 7'b0000000;
  assign is_srai = is_op_imm && funct3 == 3'b101 && funct7 == 7'b0100000;

  // OP (no imm)
  assign is_add = is_op && funct3 == 3'b000 && funct7 == 7'b0000000;
  assign is_sub = is_op && funct3 == 3'b000 && funct7 == 7'b0100000;

  assign is_sll = is_op && funct3 == 3'b001 && funct7 == 7'b0000000;
  assign is_slt = is_op && funct3 == 3'b010 && funct7 == 7'b0000000;
  assign is_sltu = is_op && funct3 == 3'b011 && funct7 == 7'b0000000;

  assign is_xor = is_op && funct3 == 3'b100 && funct7 == 7'b0000000;
  assign is_srl = is_op && funct3 == 3'b101 && funct7 == 7'b0000000;
  assign is_sra = is_op && funct3 == 3'b101 && funct7 == 7'b0100000;
  assign is_or = is_op && funct3 == 3'b110 && funct7 == 7'b0000000;
  assign is_and = is_op && funct3 == 3'b111 && funct7 == 7'b0000000;

  // MISC-MEM
  assign is_fence = is_misc_mem && (funct3 == 3'b000 || funct3 == 3'b001);
  assign is_fence_tso = is_misc_mem && funct3 == 3'b000 && rd == 5'b00000 && rs1 == 5'b00000 && instr[31:20] == 12'b100000110011;
  assign is_pause = is_misc_mem && funct3 == 3'b000 && rd == 5'b00000 && rs1 == 5'b00000 && instr[31:20] == 12'b000000010000;

  // SYSTEM
  assign is_ecall = is_system && funct3 == 3'b000 && rd == 5'b00000 && rs1 == 5'b00000 && instr[31:20] == 12'b000000000000;
  assign is_ebreak = is_system && funct3 == 3'b000 && rd == 5'b00000 && rs1 == 5'b00000 && instr[31:20] == 12'b000000000001;
  assign is_mret = is_system && funct3 == 3'b000 && rd == 5'b00000 && rs1 == 5'b00000 && rs2 == 5'b00010 && funct7 == 7'b0011000;
  assign is_sret = is_system && funct3 == 3'b000 && rd == 5'b00000 && rs1 == 5'b00000 && rs2 == 5'b00010 && funct7 == 7'b0001000;

  // CSR
  assign is_csrrw = is_system && funct3 == 3'b001;
  assign is_csrrs = is_system && funct3 == 3'b010;
  assign is_csrrc = is_system && funct3 == 3'b011;
  assign is_csrrwi = is_system && funct3 == 3'b101;
  assign is_csrrsi = is_system && funct3 == 3'b110;
  assign is_csrrci = is_system && funct3 == 3'b111;


  // IMMEDIATE selection

  // LUI (U-type imm)
  // AUIPC (U-type imm)
  wire sel_u_type_imm = is_lui || is_auipc;

  // JAL (J-type imm)
  wire sel_j_type_imm = is_jal;

  // BRANCH (B-type imm)
  wire sel_b_type_imm = is_branch;

  // OP-IMM-SHIFT (modified I-type imm)
  wire sel_modified_i_type_imm = is_slli || is_srli || is_srai;

  // JALR (I-type imm)
  // LOAD (I-type imm)
  wire sel_i_type_imm = is_load || is_jalr || (~sel_modified_i_type_imm && is_op_imm) || is_system;

  // STORE (S-type imm)
  wire sel_s_type_imm = is_store;

  assign imm = sel_u_type_imm ? u_type_imm :
               sel_j_type_imm ? j_type_imm :
               sel_b_type_imm ? b_type_imm :
               sel_modified_i_type_imm ? i_type_imm_shift :
               sel_i_type_imm ? i_type_imm :
               sel_s_type_imm ? s_type_imm : {32{1'bx}};

  assign wr_valid = is_lui || is_auipc || is_jal || is_jalr || is_load || is_op_imm || is_op || is_fence ||
                  is_csrrw || is_csrrwi || is_csrrs || is_csrrsi || is_csrrc || is_csrrci;

  assign dec_err = instr[1:0] != 2'b11 || ~(
    is_auipc ||
    is_jal ||
    is_jalr ||
    is_branch ||
    is_beq ||
    is_bne ||
    is_blt ||
    is_bge ||
    is_bltu ||
    is_bgeu ||
    is_lui ||
    is_lb ||
    is_lh ||
    is_lw ||
    is_lbu ||
    is_lhu ||
    is_sb ||
    is_sh ||
    is_sw ||
    is_addi ||
    is_slti ||
    is_stliu ||
    is_xori ||
    is_ori ||
    is_andi ||
    is_slli ||
    is_srli ||
    is_srai ||
    is_add ||
    is_sub ||
    is_sll ||
    is_slt ||
    is_sltu ||
    is_xor ||
    is_srl ||
    is_sra ||
    is_or ||
    is_and ||
    is_fence ||
    is_fence_tso ||
    is_pause ||
    is_ecall ||
    is_ebreak ||
    is_mret ||
    is_sret ||
    is_csrrw ||
    is_csrrs ||
    is_csrrc ||
    is_csrrwi ||
    is_csrrsi ||
    is_csrrci );

endmodule  // instr_decode
