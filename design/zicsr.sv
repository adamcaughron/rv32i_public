module zicsr (
    input clk,
    input rst_n,

    output logic [31:0] read_data,
    output logic invalid_csr,
    output wire machine_interrupt,
    output wire supervisor_interrupt,
    output wire medelegated,

    input [31:0] write_data,
    input [11:0] csr,

    input [31:0] pc,
    input [31:0] nxt_pc,
    input [31:0] instr,
    input [33:0] mem_addr,

    input is_csrrw,
    input is_csrrs,
    input is_csrrc,
    input is_csrrwi,
    input is_csrrsi,
    input is_csrrci,

    input is_ebreak,
    input is_ecall,
    input is_mret,
    input is_sret,

    input trap_instr_addr_misaligned,
    input trap_illegal_instr,
    input trap_breakpt,
    input trap_ld_addr_misaligned,
    input trap_ld_access_fault,
    input trap_st_amo_addr_misaligned,
    input trap_st_amo_access_fault
);

  reg [1:0] priv_mode;

  // Machine Information Registers
  reg [31:0] mvendorid;
  reg [31:0] marchid;
  reg [31:0] mimpid;
  reg [31:0] mhartid;
  reg [31:0] mconfigptr;

  // Machine trap registers
  reg [31:0] mstatus;
  reg [31:0] misa;
  reg [31:0] medeleg;
  reg [31:0] mideleg;
  reg [31:0] mie;
  reg [31:0] mtvec;
  reg [31:0] mcouteren;
  reg [31:0] mstatush;
  reg [31:0] medelegh;

  // Machine trap handling
  reg [31:0] mscratch;
  reg [31:0] mepc;
  reg [31:0] mcause;
  reg [31:0] mtval;
  reg [31:0] mip;
  reg [31:0] mtinst;
  reg [31:0] mtval2;

  // Machine configuration
  reg [31:0] menvcfg;
  reg [31:0] menvcfgh;
  reg [31:0] mseccfg;
  reg [31:0] mseccfgh;

  // Machine memory protection
  reg [31:0] pmpcfg[0:15];
  reg [31:0] pmpaddr[0:63];

  // Machine state enable registers
  reg [31:0] mstateen0;
  reg [31:0] mstateen1;
  reg [31:0] mstateen2;
  reg [31:0] mstateen3;
  reg [31:0] mstateen0h;
  reg [31:0] mstateen1h;
  reg [31:0] mstateen2h;
  reg [31:0] mstateen3h;

  // Machine non-maskable interrupt handling
  reg [31:0] mnscratch;
  reg [31:0] mnepc;
  reg [31:0] mncause;
  reg [31:0] mnstatus;

  // Machine counter/timers
  reg [31:0] mcycle;
  reg [31:0] minstret;
  reg [31:0] mnpmcounter[3:31];
  reg [31:0] mcycleh;
  reg [31:0] minstreth;
  reg [31:0] mnpmcounterh[3:31];

  // Supervisor trap setup
  reg [31:0] sstatus;
  reg [31:0] sie;
  reg [31:0] stvec;

  // Supervisor trap handling
  reg [31:0] sscratch;
  reg [31:0] sepc;
  reg [31:0] scause;
  reg [31:0] stval;
  reg [31:0] sip;

  // Supervisor Protection and Translation
  reg [31:0] satp;

  reg [31:0] tselect;


  // etc...

  wire wr_en;
  wire rd_end;
  wire [31:0] wr_val;

  assign medelegated = trap_instr_addr_misaligned && medeleg[0] ||
                       trap_illegal_instr && medeleg[2] ||
                       trap_breakpt && medeleg[3] ||
                       trap_ld_addr_misaligned && medeleg[4] ||
                       trap_ld_access_fault && medeleg[5] ||
                       trap_st_amo_addr_misaligned && medeleg[6] ||
                       trap_st_amo_access_fault && medeleg[7] ||
                       (is_ecall && priv_mode == 3'b00) && medeleg[8] ||
                       (is_ecall && priv_mode == 3'b01) && medeleg[9];

  wire exception_occurred = is_ebreak ||
                            is_ecall ||
                            trap_instr_addr_misaligned ||
                            trap_illegal_instr ||
                            trap_breakpt ||
                            trap_ld_addr_misaligned ||
                            trap_ld_access_fault ||
                            trap_st_amo_addr_misaligned ||
                            trap_st_amo_access_fault ;

  wire ssi = |(mip & mie & (1'b1 << 1));
  wire msi = |(mip & mie & (1'b1 << 3));
  wire sti = |(mip & mie & (1'b1 << 5));
  wire mti = |(mip & mie & (1'b1 << 7));
  wire sei = |(mip & mie & (1'b1 << 9));
  wire mei = |(mip & mie & (1'b1 << 11));
  wire coi = |(mip & mie & (1'b1 << 13));

  wire machine_interrupt;
  assign machine_interrupt = (msi || mti || mei || ssi || sti || sei) && ((mstatus[3] && (priv_mode == 3'b11))) || ((msi || mti || mei) && (priv_mode != 3'b11)); // || (priv_mode != 3'b11)); // && !(|(medeleg & mip & mie));

  wire supervisor_interrupt;
  assign supervisor_interrupt = (ssi || sti || sei) && (mstatus[1] && (priv_mode == 3'b01)) ; // || (priv_mode != 3'b00)) && (|(medeleg & mip & mie));

  reg [ 3:0] mi_cause_num;
  reg [31:0] mi_vector_addr;
  always_comb begin
    case (1'b1)
      (ssi):   mi_cause_num = 1;
      (msi):   mi_cause_num = 3;
      (sti):   mi_cause_num = 5;
      (mti):   mi_cause_num = 7;
      (sei):   mi_cause_num = 9;
      (mei):   mi_cause_num = 11;
      (coi):   mi_cause_num = 13;
      default: mi_cause_num = 0;
    endcase
    mi_vector_addr = mtvec[0] ? {mtvec[31:2], 2'b00} + (mi_cause_num << 2) : mtvec;
  end

  // FIXME / TODO - this is not correct vis-a-vis rs1/rd=x0
  assign rd_en = is_csrrw || is_csrrwi || is_csrrs || is_csrrsi || is_csrrc || is_csrrci;

  // Read mux
  always_comb begin
    if (~rd_en) begin
      invalid_csr = 0;
      read_data   = 32'b0;
    end else begin
      invalid_csr = 0;
      case (csr)
        // Supervisor trap setup
        12'h100: read_data = mstatus;
        12'h104: read_data = sie;
        12'h105: read_data = stvec;

        // Supervisor trap handling
        12'h140: read_data = sscratch;
        12'h141: read_data = sepc;
        12'h142: read_data = scause;
        12'h143: read_data = stval;
        12'h144: read_data = sip;

        // Supervisor Protection and Translation
        12'h180: read_data = satp;

        // Machine information registers
        12'hf11: read_data = mvendorid;
        12'hf12: read_data = marchid;
        12'hf13: read_data = mimpid;
        12'hf14: read_data = mhartid;
        12'hf15: read_data = mconfigptr;

        // Machine trap status
        12'h300: read_data = mstatus;
        12'h301: read_data = misa;
        12'h302: read_data = medeleg;
        12'h303: read_data = mideleg;
        12'h304: read_data = mie;
        12'h305: read_data = mtvec;
        12'h306: read_data = mcouteren;
        12'h310: read_data = mstatush;
        12'h312: read_data = medelegh;

        // Machine trap handling
        12'h340: read_data = mscratch;
        12'h341: read_data = mepc;
        12'h342: read_data = mcause;
        12'h343: read_data = mtval;
        12'h344: read_data = mip;
        12'h34a: read_data = mtinst;
        12'h34b: read_data = mtval2;

        // Machine configuration
        12'h30a: read_data = menvcfg;
        12'h31a: read_data = menvcfgh;
        12'h747: read_data = mseccfg;
        12'h757: read_data = mseccfgh;

        12'h7a0: read_data = tselect;
        default: begin
          read_data   = 32'hx;
          invalid_csr = 1;
        end
      endcase
    end
  end

  // Write logic

  // FIXME / TODO - this is not correct vis-a-vis rs1/rd=x0
  assign wr_en = is_csrrw || is_csrrwi || is_csrrs || is_csrrsi || is_csrrc || is_csrrci;

  assign wr_val = (is_csrrw || is_csrrwi) ? write_data :
                (is_csrrs || is_csrrsi) ? read_data | write_data :
                (is_csrrc || is_csrrci) ? read_data & ~write_data : 32'bx;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      // Machine Information Registers
      mvendorid <= 32'b0;
      marchid <= 32'b0;
      mimpid <= 32'b0;
      mhartid <= 32'b0;
      mconfigptr <= 32'b0;

      // Machine trap registers
      //mstatus <= 32'b0;
      misa <= 1'b1 << 30 | 1'b1 << 20 | 1'b1 << 18 | 1'b1 << 8 | 1'b1 << 2;
      medeleg <= 32'b0;
      mideleg <= 32'b0;
      mie <= 32'b0;
      mtvec <= 32'b0;
      mcouteren <= 32'b0;
      mstatush <= 32'b0;
      medelegh <= 32'b0;

      // Machine trap handling
      mscratch <= 32'b0;
      // mepc <= 32'b0;
      // mcause <= 32'b0;
      // mtval <= 32'b0;
      mip <= 32'b0;
      mtinst <= 32'b0;
      mtval2 <= 32'b0;

      // Machine configuration
      menvcfg <= 32'b0;
      menvcfgh <= 32'b0;
      mseccfg <= 32'b0;
      mseccfgh <= 32'b0;

      // Machine memory protection
      for (int i = 0; i < 16; i++) pmpcfg[i] <= 32'b0;
      for (int i = 0; i < 64; i++) pmpaddr[i] <= 32'b0;

      // Machine state enable registers
      mstateen0 <= 32'b0;
      mstateen1 <= 32'b0;
      mstateen2 <= 32'b0;
      mstateen3 <= 32'b0;
      mstateen0h <= 32'b0;
      mstateen1h <= 32'b0;
      mstateen2h <= 32'b0;
      mstateen3h <= 32'b0;

      // Machine non-maskable interrupt handling
      mnscratch <= 32'b0;
      mnepc <= 32'b0;
      mncause <= 32'b0;
      mnstatus <= 32'b0;

      // Machine counter/timers
      mcycle <= 32'b0;
      minstret <= 32'b0;
      //mnpmcounter [3:31] <= 32'b0;
      mcycleh <= 32'b0;
      minstreth <= 32'b0;
      //mnpmcounterh [3:31] <= 32'b0;

      // Supervisor trap setup
      sstatus <= 32'b0;
      sie <= 32'b0;
      stvec <= 32'b0;
      stval <= 32'b0;
      sip <= 32'b0;

      // Supervisor Protection and Translation
      satp <= 32'b0;

      tselect <= 32'b0;
    end else if (wr_en) begin
      // Machine trap status
      //if (csr == 12'h300)
      //    mstatus <= wr_val;
      //if (csr == 12'h301) misa <= wr_val;
      if (csr == 12'h302) medeleg <= wr_val;
      else if (csr == 12'h303) mideleg <= wr_val;
      else if (csr == 12'h304) mie <= wr_val;
      else if (csr == 12'h305) mtvec <= wr_val;
      else if (csr == 12'h306) mcouteren <= wr_val;
      else if (csr == 12'h310) mstatush <= wr_val;
      else if (csr == 12'h312) medelegh <= wr_val;

      // Machine trap handling
      else if (csr == 12'h340) mscratch <= wr_val;
      //else if (csr == 12'h341)
      //    mepc <= wr_val;
      //else if (csr == 12'h342)
      //    mcause <= wr_val;
      //else if (csr == 12'h343)
      //    mtval <= wr_val;
      else if (csr == 12'h344) mip <= wr_val;
      else if (csr == 12'h34a) mtinst <= wr_val;
      else if (csr == 12'h34b) mtval2 <= wr_val;

      // Machine configuration
      else if (csr == 12'h30a) menvcfg <= wr_val;
      else if (csr == 12'h31a) menvcfgh <= wr_val;
      else if (csr == 12'h747) mseccfg <= wr_val;
      else if (csr == 12'h757) mseccfgh <= wr_val;

      // Supervisor trap setup
      //else if (csr == 12'h100) sstatus <= wr_val;
      else if (csr == 12'h104) sie <= wr_val;
      else if (csr == 12'h105) stvec <= wr_val;

      // Supervisor trap handling
      else if (csr == 12'h140) sscratch <= wr_val;
      else if (csr == 12'h143) stval <= wr_val;
      else if (csr == 12'h144) sip <= wr_val;
      // Supervisor Protection and Translation
      else if (csr == 12'h180) satp <= wr_val;

      else if (csr == 12'h7a0) tselect <= ~wr_val;  // ?????

      else if (csr[11:4] == 8'h3a) pmpcfg[csr[3:0]] <= wr_val;

      else if ((csr[11:4] == 8'h3b)) pmpaddr[csr[3:0]] <= wr_val;

      else if ((csr[11:4] == 8'h3c)) pmpaddr[{2'b01, csr[3:0]}] <= wr_val;

      else if ((csr[11:4] == 8'h3d)) pmpaddr[{2'b10, csr[3:0]}] <= wr_val;

      else if ((csr[11:4] == 8'h3e)) pmpaddr[{2'b11, csr[3:0]}] <= wr_val;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) mstatus <= 32'b0;
    else if ((exception_occurred & !medelegated) || machine_interrupt) begin
      mstatus[12:11] <= priv_mode;  // MPP
      mstatus[7] <= mstatus[3];  // MPIE
      mstatus[3] <= 1'b0;  // MIE

    end else if (is_mret) begin
      mstatus[12:11] <= 2'b00;
      mstatus[7] <= 1'b1;  // MPIE
      mstatus[3] <= mstatus[7];  // MIE
    end else if (is_sret) mstatus[8] <= 1'b0;
    else if (wr_en && (csr == 12'h300)) mstatus <= wr_val;
    else if (wr_en && (csr == 12'h100)) begin
      mstatus[1] <= wr_val[1];
      mstatus[5] <= wr_val[5];
      mstatus[6] <= wr_val[6];
      mstatus[8] <= wr_val[8];  // ?????
      mstatus[10:9] <= wr_val[10:9];
      mstatus[14:13] <= wr_val[14:13];
      mstatus[16:15] <= wr_val[16:15];
      mstatus[18] <= wr_val[18];
      mstatus[19] <= wr_val[19];
      mstatus[31] <= wr_val[31];
    end else mstatus <= mstatus;
  end
  //
  // Supervisor trap setup
  //else if (csr == 12'h100) sstatus <= wr_val;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) mcause <= 32'b0;
    else begin
      case (1'b1)
        trap_instr_addr_misaligned: mcause <= 0;
        trap_illegal_instr: mcause <= 2;
        (is_ebreak && priv_mode == 3'b11): mcause <= 3;
        trap_ld_addr_misaligned: mcause <= 4;
        trap_ld_access_fault: mcause <= 5;
        trap_st_amo_addr_misaligned: mcause <= 6;
        trap_st_amo_access_fault: mcause <= 7;
        (is_ecall && priv_mode == 3'b00): mcause <= 8;
        (is_ecall && priv_mode == 3'b01): mcause <= 9;
        (is_ecall && priv_mode == 3'b11): mcause <= 11;
        (wr_en && csr == 12'h342): mcause <= wr_val;
        default: mcause <= mcause;
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) mtval <= 32'b0;
    else begin
      case (1'b1)
        trap_instr_addr_misaligned: mtval <= rv32i_core.is_jalr ? rv32i_core.jalr_target : nxt_pc;
        trap_ld_addr_misaligned: mtval <= mem_addr;
        trap_ld_access_fault: mtval <= mem_addr;
        trap_st_amo_addr_misaligned: mtval <= mem_addr;
        trap_st_amo_access_fault: mtval <= mem_addr;
        (wr_en && csr == 12'h343): mtval <= wr_val;
        default: mtval <= mtval;
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) stval <= 32'b0;
    else if (priv_mode != 2'b11 && medelegated) begin
      case (1'b1)
        trap_instr_addr_misaligned: stval <= rv32i_core.is_jalr ? rv32i_core.jalr_target : nxt_pc;
        trap_ld_addr_misaligned: stval <= mem_addr;
        trap_ld_access_fault: stval <= mem_addr;
        trap_st_amo_addr_misaligned: stval <= mem_addr;
        trap_st_amo_access_fault: stval <= mem_addr;
        (wr_en && csr == 12'h343): stval <= wr_val;
        default: stval <= stval;
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) scause <= 32'b0;
    else if (is_ebreak && priv_mode == 3'b01) scause <= 3;
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) mepc <= 32'b0;
    else if (exception_occurred) mepc <= pc;
    else if (wr_en && csr == 12'h341) mepc <= wr_val;
    else mepc <= mepc;
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) sepc <= 32'b0;
    else if (priv_mode == 2'b01 && exception_occurred) sepc <= pc;
    else if (wr_en && csr == 12'h141) sepc <= wr_val;
    else sepc <= sepc;
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      priv_mode <= 2'b11;
    end else if (exception_occurred) begin
      if (priv_mode != 2'b11 && medelegated) priv_mode <= 2'b01;
      else priv_mode <= 2'b11;
    end else if (machine_interrupt) begin
      priv_mode <= 2'b11;
    end else if (is_mret) priv_mode <= mstatus[12:11];
    else if (is_sret) priv_mode <= {1'b0, mstatus[8]};
  end
  // Read logic


  // Physical memory protection address matching
  reg pmp_addr_match;
  reg [3:0] pmp_match_ind;
  reg [31:0] compare_mask;
  int z;
  always_comb begin
    pmp_addr_match = 0;
    pmp_match_ind = 0;
    compare_mask = 0;
    z = 0;
    for (int i = 0; i < 16; i++) begin
      //case( pmpcfg[4:3] )
      //  0: break; //disabled
      //  1: break; //tor
      //  2: break; //na4
      //  3: break; //napot
      //endcase
      if (pmpcfg[i][4:3] == 2'b01) begin
        if (i == 0) pmp_addr_match = mem_addr < pmpaddr[i];
        else pmp_addr_match = (mem_addr < pmpaddr[i]) && (mem_addr >= pmpaddr[i-1]);

        if (pmp_addr_match) begin
          pmp_match_ind = i;
          break;
        end
      end else if (pmpcfg[i][4:3] == 2'b10) begin
        pmp_addr_match = mem_addr[33:2] == pmpaddr[i];
        if (pmp_addr_match) begin
          pmp_match_ind = i;
          break;
        end
      end else if (pmpcfg[i][4:3] == 2'b11) begin
        compare_mask = 1;
        for (z = 0; z <= 31; z++)
        if (pmpaddr[i][z]) compare_mask = (compare_mask << 1) | 1'b1;
        else break;

        pmp_addr_match = &((mem_addr[33:2] ^~ pmpaddr[i][31:0]) | compare_mask);
        if (pmp_addr_match) begin
          pmp_match_ind = i;
          break;
        end
      end
    end
  end


endmodule
