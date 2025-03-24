module instr_decode (
    input [31:0] instr,
    output dec_err,
    output [4:0] rd,
    output [4:0] rs1,
    output [4:0] rs2,
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
    output is_sfence_vma,
    output is_pause,

    // SYSTEM
    output is_ecall,
    output is_ebreak,
    output is_mret,
    output is_sret,
    output is_wfi,

    // CSR
    output is_csrrw,
    output is_csrrs,
    output is_csrrc,
    output is_csrrwi,
    output is_csrrsi,
    output is_csrrci,

    output is_load,
    output is_store,
    output is_amo
);

  reg rv32_dec_err;
  reg [4:0] rv32_rd;
  reg [4:0] rv32_rs1;
  reg [4:0] rv32_rs2;
  reg [31:0] rv32_imm;
  reg rv32_wr_valid;

  // AUIPUC (U-type imm)
  reg rv32_is_auipc;

  // JAL (J-type imm)
  reg rv32_is_jal;

  // JALR (I-type imm)
  reg rv32_is_jalr;

  // BRANCH (B-type imm)
  reg rv32_is_branch;
  reg rv32_is_beq;
  reg rv32_is_bne;
  reg rv32_is_blt;
  reg rv32_is_bge;
  reg rv32_is_bltu;
  reg rv32_is_bgeu;

  // LUI (U-type imm);
  reg rv32_is_lui;

  // LOAD (I-type imm)
  reg rv32_is_lb;
  reg rv32_is_lh;
  reg rv32_is_lw;
  reg rv32_is_lbu;
  reg rv32_is_lhu;

  // STORE (S-type imm)
  reg rv32_is_sb;
  reg rv32_is_sh;
  reg rv32_is_sw;

  // OP-IMM (I-type imm)
  reg rv32_is_addi;
  reg rv32_is_slti;
  reg rv32_is_stliu;
  reg rv32_is_xori;
  reg rv32_is_ori;
  reg rv32_is_andi;

  // OP-IMM-SHIFT (modified I-type imm)
  reg rv32_is_slli;
  reg rv32_is_srli;
  reg rv32_is_srai;

  // OP (no imm)
  reg rv32_is_add;
  reg rv32_is_sub;

  reg rv32_is_sll;
  reg rv32_is_slt;
  reg rv32_is_sltu;

  reg rv32_is_xor;
  reg rv32_is_srl;
  reg rv32_is_sra;
  reg rv32_is_or;
  reg rv32_is_and;

  // MISC-MEM
  reg rv32_is_fence;
  reg rv32_is_fence_tso;
  reg rv32_is_sfence_vma;
  reg rv32_is_pause;

  // SYSTEM
  reg rv32_is_ecall;
  reg rv32_is_ebreak;
  reg rv32_is_mret;
  reg rv32_is_sret;
  reg rv32_is_wfi;

  // CSR
  reg rv32_is_csrrw;
  reg rv32_is_csrrs;
  reg rv32_is_csrrc;
  reg rv32_is_csrrwi;
  reg rv32_is_csrrsi;
  reg rv32_is_csrrci;

  reg rv32_is_load;
  reg rv32_is_store;



  // Compressed instructions
  // -----------------------
  reg rvc_valid;
  reg rvc_dec_err;
  reg [4:0] rvc_rd;
  reg [4:0] rvc_rs1;
  reg [4:0] rvc_rs2;
  reg [31:0] rvc_imm;
  reg rvc_wr_valid;

  reg rvc_is_nop;
  reg rvc_is_c_addi4spn;
  reg rvc_is_c_lw;
  reg rvc_is_c_sw;

  reg rvc_is_c_addi;
  reg rvc_is_c_jal;
  reg rvc_is_c_li;
  reg rvc_is_c_addi16sp;
  reg rvc_is_c_lui;
  reg rvc_is_c_srli;
  reg rvc_is_c_srai;
  reg rvc_is_c_andi;
  reg rvc_is_c_sub;
  reg rvc_is_c_xor;
  reg rvc_is_c_or;
  reg rvc_is_c_and;
  reg rvc_is_c_j;
  reg rvc_is_c_beqz;
  reg rvc_is_c_bnez;

  reg rvc_is_c_slli;
  reg rvc_is_c_lwsp;
  reg rvc_is_c_jr;
  reg rvc_is_c_mv;
  reg rvc_is_c_ebreak;
  reg rvc_is_c_jalr;
  reg rvc_is_c_add;
  reg rvc_is_c_swsp;


  rv32i_instr_decode i_rv32i_decode (
      .instr(instr),
      .dec_err(rv32_dec_err),
      .rd(rv32_rd),
      .rs1(rv32_rs1),
      .rs2(rv32_rs2),
      .imm(rv32_imm),
      .wr_valid(rv32_wr_valid),

      // AUIPUC (U-type imm)
      .is_auipc(rv32_is_auipc),

      // JAL (J-type imm)
      .is_jal(rv32_is_jal),

      // JALR (I-type imm)
      .is_jalr(rv32_is_jalr),

      // BRANCH (B-type imm)
      .is_branch(rv32_is_branch),
      .is_beq(rv32_is_beq),
      .is_bne(rv32_is_bne),
      .is_blt(rv32_is_blt),
      .is_bge(rv32_is_bge),
      .is_bltu(rv32_is_bltu),
      .is_bgeu(rv32_is_bgeu),

      // LUI (U-type imm);
      .is_lui(rv32_is_lui),

      // LOAD (I-type imm)
      .is_lb (rv32_is_lb),
      .is_lh (rv32_is_lh),
      .is_lw (rv32_is_lw),
      .is_lbu(rv32_is_lbu),
      .is_lhu(rv32_is_lhu),

      // STORE (S-type imm)
      .is_sb(rv32_is_sb),
      .is_sh(rv32_is_sh),
      .is_sw(rv32_is_sw),

      // OP-IMM (I-type imm)
      .is_addi (rv32_is_addi),
      .is_slti (rv32_is_slti),
      .is_stliu(rv32_is_stliu),
      .is_xori (rv32_is_xori),
      .is_ori  (rv32_is_ori),
      .is_andi (rv32_is_andi),

      // OP-IMM-SHIFT (modified I-type imm)
      .is_slli(rv32_is_slli),
      .is_srli(rv32_is_srli),
      .is_srai(rv32_is_srai),

      // OP (no imm)
      .is_add(rv32_is_add),
      .is_sub(rv32_is_sub),

      .is_sll (rv32_is_sll),
      .is_slt (rv32_is_slt),
      .is_sltu(rv32_is_sltu),

      .is_xor(rv32_is_xor),
      .is_srl(rv32_is_srl),
      .is_sra(rv32_is_sra),
      .is_or (rv32_is_or),
      .is_and(rv32_is_and),

      // MISC-MEM
      .is_fence(rv32_is_fence),
      .is_fence_tso(rv32_is_fence_tso),
      .is_sfence_vma(rv32_is_sfence_vma),
      .is_pause(rv32_is_pause),

      // SYSTEM
      .is_ecall(rv32_is_ecall),
      .is_ebreak(rv32_is_ebreak),
      .is_mret(rv32_is_mret),
      .is_sret(rv32_is_sret),
      .is_wfi(rv32_is_wfi),

      // CSR
      .is_csrrw (rv32_is_csrrw),
      .is_csrrs (rv32_is_csrrs),
      .is_csrrc (rv32_is_csrrc),
      .is_csrrwi(rv32_is_csrrwi),
      .is_csrrsi(rv32_is_csrrsi),
      .is_csrrci(rv32_is_csrrci),

      .is_load (rv32_is_load),
      .is_store(rv32_is_store),
      .is_amo  (is_amo)
  );


  rvc32_instr_decode i_rvc32_decode (
      .instr(instr),
      .valid_rvc(rvc_valid),
      .dec_err(rvc_dec_err),
      .rd(rvc_rd),
      .rs1(rvc_rs1),
      .rs2(rvc_rs2),
      .imm(rvc_imm),
      .wr_valid(rvc_wr_valid),

      .is_nop(rvc_is_nop),
      .is_c_addi4spn(rvc_is_c_addi4spn),
      .is_c_lw(rvc_is_c_lw),
      .is_c_sw(rvc_is_c_sw),

      .is_c_addi(rvc_is_c_addi),
      .is_c_jal(rvc_is_c_jal),
      .is_c_li(rvc_is_c_li),
      .is_c_addi16sp(rvc_is_c_addi16sp),
      .is_c_lui(rvc_is_c_lui),
      .is_c_srli(rvc_is_c_srli),
      .is_c_srai(rvc_is_c_srai),
      .is_c_andi(rvc_is_c_andi),
      .is_c_sub(rvc_is_c_sub),
      .is_c_xor(rvc_is_c_xor),
      .is_c_or(rvc_is_c_or),
      .is_c_and(rvc_is_c_and),
      .is_c_j(rvc_is_c_j),
      .is_c_beqz(rvc_is_c_beqz),
      .is_c_bnez(rvc_is_c_bnez),

      .is_c_slli(rvc_is_c_slli),
      .is_c_lwsp(rvc_is_c_lwsp),
      .is_c_jr(rvc_is_c_jr),
      .is_c_mv(rvc_is_c_mv),
      .is_c_ebreak(rvc_is_c_ebreak),
      .is_c_jalr(rvc_is_c_jalr),
      .is_c_add(rvc_is_c_add),
      .is_c_swsp(rvc_is_c_swsp)
  );

  assign dec_err = i_rv32i_decode.valid_32b_instr ? rv32_dec_err : rvc_dec_err;
  assign rd = i_rv32i_decode.valid_32b_instr ? rv32_rd : rvc_rd;
  assign rs1 = i_rv32i_decode.valid_32b_instr ? rv32_rs1 : rvc_rs1;
  assign rs2 = i_rv32i_decode.valid_32b_instr ? rv32_rs2 : rvc_rs2;
  assign imm = i_rv32i_decode.valid_32b_instr ? rv32_imm : rvc_imm;
  assign wr_valid = i_rv32i_decode.valid_32b_instr ? rv32_wr_valid : rvc_wr_valid;

  // AUIPUC (U-type imm)
  assign is_auipc = rv32_is_auipc;

  // JAL (J-type imm)
  assign is_jal = i_rv32i_decode.valid_32b_instr ? rv32_is_jal : (rvc_is_c_jal || rvc_is_c_j);

  // JALR (I-type imm)
  assign is_jalr = i_rv32i_decode.valid_32b_instr ? rv32_is_jalr : (rvc_is_c_jalr || rvc_is_c_jr);

  // BRANCH (B-type imm)
  assign is_branch = rv32_is_branch;
  assign is_beq = i_rv32i_decode.valid_32b_instr ? rv32_is_beq : rvc_is_c_beqz;
  assign is_bne = i_rv32i_decode.valid_32b_instr ? rv32_is_bne : rvc_is_c_bnez;
  assign is_blt = rv32_is_blt;
  assign is_bge = rv32_is_bge;
  assign is_bltu = rv32_is_bltu;
  assign is_bgeu = rv32_is_bgeu;

  // LUI (U-type imm);
  assign is_lui = i_rv32i_decode.valid_32b_instr ? rv32_is_lui : rvc_is_c_lui;

  // LOAD (I-type imm)
  assign is_lb = rv32_is_lb;
  assign is_lh = rv32_is_lh;
  assign is_lw = i_rv32i_decode.valid_32b_instr ? rv32_is_lw : (rvc_is_c_lw || rvc_is_c_lwsp);
  assign is_lbu = rv32_is_lbu;
  assign is_lhu = rv32_is_lhu;

  // STORE (S-type imm)
  assign is_sb = rv32_is_sb;
  assign is_sh = rv32_is_sh;
  assign is_sw = i_rv32i_decode.valid_32b_instr ? rv32_is_sw : (rvc_is_c_sw || rvc_is_c_swsp);

  // OP-IMM (I-type imm)
  assign is_addi = i_rv32i_decode.valid_32b_instr ? rv32_is_addi : (rvc_is_c_li  || rvc_is_c_addi || rvc_is_c_addi4spn || rvc_is_c_addi16sp);
  assign is_slti = rv32_is_slti;
  assign is_stliu = rv32_is_stliu;
  assign is_xori = rv32_is_xori;
  assign is_ori = rv32_is_ori;
  assign is_andi = i_rv32i_decode.valid_32b_instr ? rv32_is_andi : rvc_is_c_andi;

  // OP-IMM-SHIFT (modified I-type imm)
  assign is_slli = i_rv32i_decode.valid_32b_instr ? rv32_is_slli : rvc_is_c_slli;
  assign is_srli = i_rv32i_decode.valid_32b_instr ? rv32_is_srli : rvc_is_c_srli;
  assign is_srai = i_rv32i_decode.valid_32b_instr ? rv32_is_srai : rvc_is_c_srai;

  // OP (no imm)
  assign is_add = i_rv32i_decode.valid_32b_instr ? rv32_is_add : (rvc_is_c_add || rvc_is_c_mv);
  assign is_sub = i_rv32i_decode.valid_32b_instr ? rv32_is_sub : rvc_is_c_sub;

  assign is_sll = rv32_is_sll;
  assign is_slt = rv32_is_slt;
  assign is_sltu = rv32_is_sltu;

  assign is_xor = i_rv32i_decode.valid_32b_instr ? rv32_is_xor : rvc_is_c_xor;
  assign is_srl = rv32_is_srl;
  assign is_sra = rv32_is_sra;
  assign is_or = i_rv32i_decode.valid_32b_instr ? rv32_is_or : rvc_is_c_or;
  assign is_and = i_rv32i_decode.valid_32b_instr ? rv32_is_and : rvc_is_c_and;

  // MISC-MEM
  assign is_fence = rv32_is_fence;
  assign is_fence_tso = rv32_is_fence_tso;
  assign is_sfence_vma = rv32_is_sfence_vma;
  assign is_pause = rv32_is_pause;

  // SYSTEM
  assign is_ecall = rv32_is_ecall;
  assign is_ebreak = i_rv32i_decode.valid_32b_instr ? rv32_is_ebreak : rvc_is_c_ebreak;
  assign is_mret = rv32_is_mret;
  assign is_sret = rv32_is_sret;
  assign is_wfi = rv32_is_wfi;

  // CSR
  assign is_csrrw = rv32_is_csrrw;
  assign is_csrrs = rv32_is_csrrs;
  assign is_csrrc = rv32_is_csrrc;
  assign is_csrrwi = rv32_is_csrrwi;
  assign is_csrrsi = rv32_is_csrrsi;
  assign is_csrrci = rv32_is_csrrci;

  assign is_load = rv32_is_load || rvc_is_c_lw || rvc_is_c_lwsp;
  assign is_store = rv32_is_store || rvc_is_c_sw || rvc_is_c_swsp;

endmodule
