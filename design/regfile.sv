module regfile (
    input clk,
    input rst_n,
    input [5:0] rd,
    input [5:0] rs1,
    input [5:0] rs2,
    input wr_en,
    input [31:0] wr_data,
    output [31:0] rd_rs1,
    output [31:0] rd_rs2
);

  reg [31:0] data[31:1];

  always @(posedge clk) begin
    if (rst_n && wr_en && (|rd)) data[rd] <= wr_data;
  end

  assign rd_rs1 = (rst_n && |rs1) ? data[rs1] : 32'b0;
  assign rd_rs2 = (rst_n && |rs2) ? data[rs2] : 32'b0;

endmodule
