module rvc32_instr_decode (
    input [31:0] instr,
    output valid_rvc,
    output dec_err,
    output [4:0] rd,
    output [4:0] rs1,
    output [4:0] rs2,
    output [31:0] imm,
    output wr_valid,

    output is_nop,
    output is_c_addi4spn,
    output is_c_lw,
    output is_c_sw,

    output is_c_addi,
    output is_c_jal,
    output is_c_li,
    output is_c_addi16sp,
    output is_c_lui,
    output is_c_srli,
    output is_c_srai,
    output is_c_andi,
    output is_c_sub,
    output is_c_xor,
    output is_c_or,
    output is_c_and,
    output is_c_j,
    output is_c_beqz,
    output is_c_bnez,

    output is_c_slli,
    output is_c_lwsp,
    output is_c_jr,
    output is_c_mv,
    output is_c_ebreak,
    output is_c_jalr,
    output is_c_add,
    output is_c_swsp
);

  wire [2:0] funct3 = instr[15:13];
  wire [3:0] funct4 = instr[15:12];
  wire [5:0] funct6 = instr[15:10];
  wire [1:0] funct2 = instr[11:10];

  wire valid_q0_rvc_inst = instr[1:0] == 2'b00;
  wire valid_q1_rvc_inst = instr[1:0] == 2'b01;
  wire valid_q2_rvc_inst = instr[1:0] == 2'b10;

  assign valid_rvc = valid_q0_rvc_inst || valid_q1_rvc_inst || valid_q2_rvc_inst;

  wire [4:0] rd_or_rs1 = instr[11:7];
  wire [4:0] rs2_or_imm = instr[6:2];
  wire [4:0] rd_or_rs2_rvc = {1'b1, instr[4:2]};
  wire [4:0] rd_or_rs1_rvc = {1'b1, instr[9:7]};

  wire is_hint;

  // for c.lwsp
  wire [31:0] ci_type_imm = {{24{1'b0}}, instr[3:2], instr[12], instr[6:4], 2'b00};

  // for c.swsp
  wire [31:0] css_type_imm = {{24{1'b0}}, instr[8:7], instr[12:9], 2'b00};

  // c.lw and c.sw
  wire [31:0] c_lw_sw_imm = {{25{1'b0}}, instr[5], instr[12:10], instr[6], 2'b00};

  // c.j and c.jal
  wire [31:0] cj_type_imm = {
    {21{instr[12]}},
    instr[8],
    instr[10:9],
    instr[6],
    instr[7],
    instr[2],
    instr[11],
    instr[5:3],
    1'b0
  };

  // c.beqz and c.bnez:
  wire [31:0] cb_type_imm = {{24{instr[12]}}, instr[6:5], instr[2], instr[11:10], instr[4:3], 1'b0};

  // c.li
  wire [31:0] c_li_imm = {{27{instr[12]}}, instr[6:2]};

  // c.lui
  wire [31:0] c_lui_imm = {{15{instr[12]}}, instr[6:2], {12{1'b0}}};

  // c.addi
  wire [31:0] c_addi_imm = {{29{instr[12]}}, instr[6:2]};

  // c.addi16sp
  wire [31:0] c_addi16sp_imm = {
    {23{instr[12]}}, instr[4:3], instr[5], instr[2], instr[6], {4{1'b0}}
  };

  // c.addi4spn
  wire [31:0] c_addi4spn_imm = {{22{1'b0}}, instr[10:7], instr[12:11], instr[5], instr[6], 2'b00};

  // c.slli, c.srli, c.srai
  wire [31:0] c_sr_imm = {{26{1'b0}}, instr[12], instr[6:2]};

  // c.andi
  wire [31:0] c_and_imm = {{27{instr[12]}}, instr[6:2]};




  // for c.lwsp
  assign imm = is_c_lwsp ? ci_type_imm :
               is_c_swsp ? css_type_imm :
               is_c_lw || is_c_sw ? c_lw_sw_imm :
               is_c_j || is_c_jal ? cj_type_imm :
               is_c_beqz || is_c_bnez ? cb_type_imm :
               is_c_li ? c_li_imm :
               is_c_lui ? c_lui_imm :
               is_c_addi ? c_addi_imm :
               is_c_addi16sp ? c_addi16sp_imm :
               is_c_addi4spn ? c_addi4spn_imm :
               is_c_slli || is_c_srli || is_c_srai ? c_sr_imm :
               is_c_andi ? c_and_imm : 0;


  assign is_nop = is_hint || valid_q1_rvc_inst && funct3 == 3'b000 && rd_or_rs1 == 5'b00000;
  assign is_c_addi4spn = valid_q0_rvc_inst && funct3 == 3'b000 && c_addi4spn_imm != 0;
  assign is_c_lw = valid_q0_rvc_inst && funct3 == 3'b010;
  assign is_c_sw = valid_q0_rvc_inst && funct3 == 3'b110;

  wire is_c_addi_or_hint = valid_q1_rvc_inst && funct3 == 3'b000 && rd_or_rs1 != 0;
  assign is_c_addi = is_c_addi_or_hint && c_addi_imm != 0;

  assign is_c_jal  = valid_q1_rvc_inst && funct3 == 3'b001;
  assign is_c_li   = valid_q1_rvc_inst && funct3 == 3'b010 && rd_or_rs1 != 0;

  wire is_c_addi16sp_or_hint = valid_q1_rvc_inst && funct3 == 3'b011 && rd_or_rs1 == 5'b00010;
  assign is_c_addi16sp = is_c_addi16sp_or_hint && c_addi16sp_imm != 0;

  wire is_c_lui_or_hint = valid_q1_rvc_inst && funct3 == 3'b011 && rd_or_rs1 != 5'b00010 && c_lui_imm != 0;
  assign is_c_lui = is_c_lui_or_hint && rd_or_rs1 != 5'b00000;

  wire is_c_srli_or_hint = valid_q1_rvc_inst && funct3 == 3'b100 && funct2 == 2'b00 && instr[12] == 0;
  assign is_c_srli = is_c_srli_or_hint && c_sr_imm != 0;

  wire is_c_srai_or_hint = valid_q1_rvc_inst && funct3 == 3'b100 && funct2 == 2'b01 && instr[12] == 0;
  assign is_c_srai = is_c_srai_or_hint && c_sr_imm != 0;

  assign is_c_andi = valid_q1_rvc_inst && funct3 == 3'b100 && funct2 == 2'b10;
  assign is_c_sub = valid_q1_rvc_inst && funct3 == 3'b100 && funct2 == 2'b11 && instr[12] == 0 && instr[6:5] == 2'b00;
  assign is_c_xor = valid_q1_rvc_inst && funct3 == 3'b100 && funct2 == 2'b11 && instr[12] == 0 && instr[6:5] == 2'b01;
  assign is_c_or = valid_q1_rvc_inst && funct3 == 3'b100 &&  funct2 == 2'b11 && instr[12] == 0 && instr[6:5] == 2'b10;
  assign is_c_and = valid_q1_rvc_inst && funct3 == 3'b100 && funct2 == 2'b11 && instr[12] == 0 && instr[6:5] == 2'b11;

  assign is_c_j = valid_q1_rvc_inst && funct3 == 3'b101;
  assign is_c_beqz = valid_q1_rvc_inst && funct3 == 3'b110;
  assign is_c_bnez = valid_q1_rvc_inst && funct3 == 3'b111;

  wire is_c_slli_or_hint = valid_q2_rvc_inst && funct3 == 3'b000 && rd_or_rs1 != 0;
  assign is_c_slli = is_c_slli_or_hint && c_sr_imm != 0 && instr[12] != 1;

  assign is_hint = ((is_c_slli_or_hint || is_c_srli_or_hint || is_c_srai_or_hint) && c_sr_imm == 0) || (is_c_addi_or_hint && c_addi_imm == 0) || (is_c_lui && rd_or_rs1 == 5'b00000);

  assign is_c_lwsp = valid_q2_rvc_inst && funct3 == 3'b010 && rd_or_rs1 != 0;
  assign is_c_jr = valid_q2_rvc_inst && funct3 == 3'b100 && instr[12] == 0 && rd_or_rs1 !=0 && rs2_or_imm == 0;
  assign is_c_mv = valid_q2_rvc_inst && funct3 == 3'b100 && instr[12] == 0 && rd_or_rs1 !=0 && rs2_or_imm != 0;
  assign is_c_ebreak = valid_q2_rvc_inst && funct3 == 3'b100 && instr[12] == 1 && rd_or_rs1 == 0 && rs2_or_imm == 0;
  assign is_c_jalr = valid_q2_rvc_inst && funct3 == 3'b100 && instr[12] == 1 && rd_or_rs1 != 0 && rs2_or_imm == 0;
  assign is_c_add = valid_q2_rvc_inst && funct3 == 3'b100 && instr[12] == 1 && rd_or_rs1 != 0 && rs2_or_imm != 0;

  assign is_c_swsp = valid_q2_rvc_inst && funct3 == 3'b110;

  assign rs1 = (is_c_lwsp || is_c_swsp || is_c_addi4spn || is_c_addi16sp) ? 5'b00010 :
               valid_q0_rvc_inst ? rd_or_rs1_rvc :
               (valid_q1_rvc_inst && (is_c_addi || is_c_addi16sp || is_c_lui)) || (valid_q2_rvc_inst && ~(is_c_mv)) ? rd_or_rs1 :
               (valid_q1_rvc_inst && ~(is_c_li)) ? rd_or_rs1_rvc : 0;

  assign rs2 = valid_q0_rvc_inst || (valid_q1_rvc_inst && ~(is_c_beqz || is_c_bnez)) ? rd_or_rs2_rvc : valid_q2_rvc_inst ? rs2_or_imm : 0;

  assign rd = valid_q0_rvc_inst ? rd_or_rs2_rvc :
              (is_c_jalr || is_c_jal) ? 5'b00001 :
              (valid_q1_rvc_inst && (is_c_addi || is_c_li || is_c_addi16sp || is_c_lui)) || valid_q2_rvc_inst ? rd_or_rs1 :
              valid_q1_rvc_inst ? rd_or_rs1_rvc : 0;

  wire is_illegal_instr = instr[15:0] == {16{1'b0}};

  assign dec_err = is_illegal_instr ||
                    ((valid_q0_rvc_inst || valid_q1_rvc_inst || valid_q2_rvc_inst) && !(is_nop ||
                                                                                        is_c_addi4spn ||
                                                                                        is_c_lw ||
                                                                                        is_c_sw ||
                                                                                        is_c_addi ||
                                                                                        is_c_jal ||
                                                                                        is_c_li ||
                                                                                        is_c_addi16sp ||
                                                                                        is_c_lui ||
                                                                                        is_c_srli ||
                                                                                        is_c_srai ||
                                                                                        is_c_andi ||
                                                                                        is_c_sub ||
                                                                                        is_c_xor ||
                                                                                        is_c_or ||
                                                                                        is_c_and ||
                                                                                        is_c_j ||
                                                                                        is_c_beqz ||
                                                                                        is_c_bnez ||
                                                                                        is_c_slli ||
                                                                                        is_c_lwsp ||
                                                                                        is_c_jr ||
                                                                                        is_c_mv ||
                                                                                        is_c_ebreak ||
                                                                                        is_c_jalr ||
                                                                                        is_c_add ||
                                                                                        is_c_swsp));

  assign wr_valid = is_c_addi4spn || is_c_lui || is_c_jal || is_c_jalr || is_c_lw ||
                    (valid_q1_rvc_inst && ~(is_nop || is_c_j || is_c_beqz || is_c_bnez)) ||
                    is_c_slli || is_c_lwsp || is_c_mv || is_c_jalr || is_c_add;


endmodule  // rvc32_instr_decode
