module alu(
    output reg [31:0] rd_val,
    input [31:0] rs1_val,
    input [31:0] rs2_val,
    input [31:0] imm,

    input is_auipc,

    // BRANCH (B-type imm)
    input is_beq,
    input is_bne,
    input is_blt,
    input is_bge,
    input is_bltu,
    input is_bgeu,

    // LOAD (I-type imm)
    input is_lb,
    input is_lh,
    input is_lw,
    input is_lbu,
    input is_lhu,

    // STORE (S-type imm)
    input is_sb,
    input is_sh,
    input is_sw,

    // OP-IMM (I-type imm)
    input is_addi,
    input is_slti,
    input is_stliu,
    input is_xori,
    input is_ori,
    input is_andi,

    // OP-IMM-SHIFT (modified I-type imm)
    input is_slli,
    input is_srli,
    input is_srai,

    // OP (no imm)
    input is_add,
    input is_sub,

    input is_sll,
    input is_slt,
    input is_sltu,

    input is_xor,
    input is_srl,
    input is_sra,
    input is_or,
    input is_and
);

wire do_foo;
always_comb begin
case(1'b1)

	is_auipc: rd_val = rs1_val + $signed(imm);

	// BRANCH (B-type imm)
	is_beq: rd_val = rs1_val == rs2_val;
	is_bne: rd_val = rs1_val != rs2_val;

	// FIXME - signed comparisons
	is_blt: rd_val = $signed(rs1_val) < $signed(rs2_val);
        is_bge: rd_val = $signed(rs1_val) >= $signed(rs2_val);

        is_bltu: rd_val = rs1_val < rs2_val;
        is_bgeu: rd_val = rs1_val >= rs2_val;

	// LOAD (I-type imm)
        (is_lb  || is_lh ||
         is_lw  ||
         is_lbu ||
         is_lhu ) : rd_val = rs1_val + $signed(imm);

	// STORE (S-type imm)
	(is_sb  ||
	 is_sh  ||
	 is_sw ) : rd_val = rs1_val + $signed(imm);

	// OP-IMM (I-type imm)
	is_addi : rd_val = $signed(rs1_val) + $signed(imm);
	is_slti : rd_val = $signed(rs1_val) < $signed(imm);
	is_stliu: rd_val = rs1_val < imm;
	is_xori : rd_val = rs1_val ^ imm;
	is_ori  : rd_val = rs1_val | imm;
	is_andi : rd_val = rs1_val & imm;

	// OP-IMM-SHIFT (modified I-type imm)
	is_slli: rd_val = rs1_val << imm;
	is_srli: rd_val = rs1_val >> imm;
	is_srai: rd_val = $signed(rs1_val) >>> imm;

	// OP (no imm)
	is_add : rd_val = $signed(rs1_val) + $signed(rs2_val);
	is_sub : rd_val = $signed(rs1_val) - $signed(rs2_val);

	is_sll : rd_val = rs1_val << rs2_val[4:0];
	is_slt : rd_val = $signed(rs1_val) < $signed(rs2_val);
	is_sltu: rd_val = rs1_val < rs2_val;

	is_xor : rd_val = rs1_val ^ rs2_val;
	is_srl : rd_val = rs1_val >> rs2_val[4:0];
	is_sra : rd_val = $signed(rs1_val) >>> rs2_val[4:0];
	is_or  : rd_val = rs1_val | rs2_val;
	is_and : rd_val = rs1_val & rs2_val;

	default: rd_val = {32{1'bx}};
endcase
end

endmodule
