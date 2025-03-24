module rv32i_dii(input rvfi_ext_enable, input rvfi_dii_enable, input halt);

   import "DPI-C" function void rvfi_set_pc_data(longint, longint);
   import "DPI-C" function void rvfi_set_inst_meta_data(longint, byte, byte, byte, byte, byte, byte);
   import "DPI-C" function void rvfi_set_ext_integer_data(longint, longint, longint, byte, byte, byte);
   import "DPI-C" function void rvfi_set_ext_mem_data(longint i[4], longint j[4], int, int, longint);
   import "DPI-C" function void rvfi_set_exec_packet_v2(byte, byte);
   import "DPI-C" context task rvfi_get_next_instr(output longint);
   import "DPI-C" function void compare_rvfi_ext_execution_packetv2(longint);

   // compute mem rd/wr masks:
   reg [64:0] mem_rmask;
   always_comb begin
       case (1'b1)
           rv32i_core.instr_trap: mem_rmask = 64'b0;
           rv32i_core.is_lb || rv32i_core.is_lbu: mem_rmask = 64'b1;
           rv32i_core.is_lh || rv32i_core.is_lhu: mem_rmask = 64'b11;
           rv32i_core.is_lw: mem_rmask = 64'b1111;
           default: mem_rmask = 0;
       endcase
   end

   reg [64:0] mem_wmask;
   always_comb begin
       case (1'b1)
           rv32i_core.instr_trap: mem_wmask = 64'b0;
           rv32i_core.is_sb: mem_wmask = 64'b1;
           rv32i_core.is_sh: mem_wmask = 64'b11;
           rv32i_core.is_sw: mem_wmask = 64'b1111;
           default: mem_wmask = 0;
       endcase
   end

   int rvfi_order;

   function void set_rvfi_order(int order);
     rvfi_order = order;
   endfunction
   export "DPI-C" function set_rvfi_order;


   bit integer_data_available;
   bit memory_access_data_available;

   bit [31:0] dii_instr;

   wire [31:0] rs1_val = 0; //~rv32i_core.i_instr_decode.is_op_imm ? rv32i_core.rs1_val : 32'b0;
   wire [5:0] rs1 = 0; //~rv32i_core.i_instr_decode.is_op_imm ? (rv32i_core.rs1 & {5{~rv32i_core.i_instr_decode.sel_u_type_imm}}) : 32'b0;

   always @(posedge rv32i_core.clk) begin
       if (rvfi_ext_enable && ~halt) begin
           if (rv32i_core.rst_n) begin
              if (!(rv32i_core.instr_trap || rv32i_core.machine_interrupt || (rv32i_core.wfi_pending && ~rv32i_core.wfi_clear)))
                rvfi_order++;

              rvfi_set_pc_data(rv32i_core.pc, rv32i_core.nxt_pc_w_trap);
              rvfi_set_inst_meta_data(rv32i_core.instr & {{16{~rv32i_core.i_instr_decode.rvc_valid}}, {16{1'b1}}}, rv32i_core.instr_trap || (rv32i_core.machine_interrupt && ~((rv32i_core.is_wfi || rv32i_core.wfi_pending) && ~rv32i_core.wfi_clear)), 0, rv32i_core.machine_interrupt, rv32i_core.i_zicsr.priv_mode, 1, ~rv32i_core.dec_err & 1'b1);

              if (integer_data_available)
                  rvfi_set_ext_integer_data(rv32i_core.rd_val, rs1_val, 0, rv32i_core.rd, rs1 , 0);

              if (memory_access_data_available)
                  rvfi_set_ext_mem_data({rv32i_core.ld_data, 32'b0, 32'b0, 32'b0}, {rv32i_core.rs2_val, 32'b0, 32'b0, 32'b0}, mem_rmask, mem_wmask, rv32i_core.alu_output);

              rvfi_set_exec_packet_v2(integer_data_available, memory_access_data_available);

              // Per-instruction-retirement checking, if enabled:
              if (rvfi_ext_enable && ~rvfi_dii_enable) begin
                  void'(compare_rvfi_ext_execution_packetv2(longint'($time)));
              end

           end
       end


       if (rvfi_dii_enable && ((~rv32i_core.rst_n && halt) || rv32i_core.rst_n)) begin
           rvfi_get_next_instr(dii_instr);
           force rv32i_core.instr = dii_instr;
       end
   end

   assign integer_data_available = ~rv32i_core.instr_trap && (rv32i_core.rd!=0) && (rv32i_core.wr_valid);

   assign memory_access_data_available = (~rv32i_core.instr_trap || rv32i_core.trap_st_amo_access_fault) && (rv32i_core.i_instr_decode.is_store || rv32i_core.i_instr_decode.is_load);

endmodule

