module zicsr (
    input clk,
    input rst_n,

    output logic [31:0] read_data,
    output logic invalid_csr,
    output wire medelegated,

    input [31:0] write_data,
    input [11:0] csr,

    input [31:0] pc,
    input [31:0] instr,
    input [31:0] mem_addr,

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
  reg [31:0] stvec;

  // Supervisor trap handling
  reg [31:0] sscratch;
  reg [31:0] sepc;
  reg [31:0] scause;

  // Supervisor Protection and Translation
  reg [31:0] satp;


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
        12'h100: read_data = sstatus;
        12'h105: read_data = stvec;

        // Supervisor trap handling
        12'h140: read_data = sscratch;
        12'h141: read_data = sepc;
        12'h142: read_data = scause;

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
      misa <= 1'b1 << 30 | 1'b1 << 20 | 1'b1 << 18;
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
      //pmpcfg [0:15] <= 32'b0;
      //pmpaddr [0:63] <= 32'b0;

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
      stvec <= 32'b0;

      // Supervisor Protection and Translation
      satp <= 32'b0;
    end else if (wr_en) begin
      // Machine trap status
      //if (csr == 12'h300)
      //    mstatus <= wr_val;
      if (csr == 12'h301) misa <= wr_val;
      else if (csr == 12'h302) medeleg <= wr_val;
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
      else if (csr == 12'h100) sstatus <= wr_val;
      else if (csr == 12'h105) stvec <= wr_val;

      // Supervisor trap handling
      else if (csr == 12'h140) sscratch <= wr_val;
      // Supervisor Protection and Translation
      else if (csr == 12'h180) satp <= wr_val;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) mstatus <= 32'b0;
    else if (exception_occurred) mstatus[12:11] <= priv_mode;
    else if (is_mret) mstatus[12:11] <= 2'b00;
    else if (is_sret) mstatus[8] <= 1'b0;
    else if (wr_en && csr == 12'h300) mstatus <= wr_val;
    else mstatus <= mstatus;
  end

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
    end else if (is_mret) priv_mode <= mstatus[12:11];
    else if (is_sret) priv_mode <= {1'b0, mstatus[8]};
  end
  // Read logic



endmodule
