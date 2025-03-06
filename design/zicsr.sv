module zicsr (
    input clk,
    input rst_n,

    output logic [31:0] read_data,

    input [31:0] write_data,
    input [11:0] csr,

    input is_csrrw,
    input is_csrrs,
    input is_csrrc,
    input is_csrrwi,
    input is_csrrsi,
    input is_csrrci
);

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

  // etc...

  // Read mux
  always_comb begin
    case (csr)
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

      default: read_data = 32'hx;
    endcase
  end

  // Write logic
  wire [31:0] wr_val;

  // FIXME / TODO - this is not correct vis-a-vis rs1/rd=x0
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
      mstatus <= 32'b0;
      misa <= 32'b0;
      medeleg <= 32'b0;
      mideleg <= 32'b0;
      mie <= 32'b0;
      mtvec <= 32'b0;
      mcouteren <= 32'b0;
      mstatush <= 32'b0;
      medelegh <= 32'b0;

      // Machine trap handling
      mscratch <= 32'b0;
      mepc <= 32'b0;
      mcause <= 32'b0;
      mtval <= 32'b0;
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
    end else begin
      // Machine trap status
      if (csr == 12'h300) mstatus <= wr_val;
      else if (csr == 12'h301) misa <= wr_val;
      else if (csr == 12'h302) medeleg <= wr_val;
      else if (csr == 12'h303) mideleg <= wr_val;
      else if (csr == 12'h304) mie <= wr_val;
      else if (csr == 12'h305) mtvec <= wr_val;
      else if (csr == 12'h306) mcouteren <= wr_val;
      else if (csr == 12'h310) mstatus <= wr_val;
      else if (csr == 12'h312) medeleg <= wr_val;

      // Machine trap handling
      else if (csr == 12'h340) mscratch <= wr_val;
      else if (csr == 12'h341) mepc <= wr_val;
      else if (csr == 12'h342) mcause <= wr_val;
      else if (csr == 12'h343) mtval <= wr_val;
      else if (csr == 12'h344) mip <= wr_val;
      else if (csr == 12'h34a) mtinst <= wr_val;
      else if (csr == 12'h34b) mtval2 <= wr_val;

      // Machine configuration
      else if (csr == 12'h30a) menvcfg <= wr_val;
      else if (csr == 12'h31a) menvcfgh <= wr_val;
      else if (csr == 12'h747) mseccfg <= wr_val;
      else if (csr == 12'h757) mseccfgh <= wr_val;
    end
  end


  // Read logic



endmodule
