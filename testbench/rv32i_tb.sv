///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
import "DPI-C" task initialize_rvfi_dii(input int portnum, input int spawn_client, input int num_tests);
import "DPI-C" function void finalize_rvfi_dii();

module rv32i_tb ();

  string all_tests[] = '{
      `include "all_riscv_tests.sv"
  };

  string test_name;

  reg clk = 0;
  reg rst_n = 0;
  reg halt = 0;
  reg unhalt = 0;
  reg do_finish = 0;
  reg rvfi_dii_enable = 0;


  // Instantiate the DUT
  rv32i_core i_rv32i_core(
    .clk(clk),
    .rst_n(rst_n)
    //.halt(halt)
  );

  bind i_rv32i_core rv32i_dii i_rv32i_dii(rv32i_tb.rvfi_dii_enable, rv32i_tb.halt);

  task load_test(string test_mem_file);
      // Program memory initialization
      // Load memory image:
      // $display("Initializing memory from file %s", test_mem_file);
      $readmemh(test_mem_file, i_rv32i_core.mem);
  endtask

  task do_halt();
     halt = 1;
     rst_n = 0;
  endtask

  task do_unhalt();
     foreach(i_rv32i_core.mem[i])
         i_rv32i_core.mem[i] <= 0;
     for(int i=1; i<32; i++)
        i_rv32i_core.i_regfile.data[i] <= 0;
     halt = 0;
     reset_pulse();
  endtask

  function void do_queue_finish();
      $display("In do_queue_finish, simulation to $finish on next clockedge");
      do_finish = 1;
  endfunction

  export "DPI-C" task do_halt;
  export "DPI-C" task do_unhalt;
  export "DPI-C" function do_queue_finish;

  task reset_pulse();
    // Reset pulse
    rst_n = 0;
      repeat(10)
         @(posedge clk);
      rst_n = 1;
  endtask

  task poll_for_test_completion(string test_name);
     // Polling for test pass/fail
    repeat(5000) begin
         @(posedge clk)
         if (i_rv32i_core.is_ecall) begin
             if (i_rv32i_core.i_regfile.data[3] == 32'b01)
                 $display("%s result: TEST PASS", test_name);
             else
                 $display("%s result: TEST FAIL <--!!!!!", test_name);
             return;
         end
    end
    $display("%s result: TEST TIMEOUT <--!!!!!", test_name);
  endtask

  task run_test(string test_name);
    load_test(test_name);
    reset_pulse();
    poll_for_test_completion(test_name);
  endtask

  initial begin
    if ($value$plusargs("test=%s", test_name)) begin
        // check for .hex extension, add it if needed:
        automatic int len = test_name.len();
        if (!(test_name.substr(len-4, len-1) == ".hex"))
            test_name = {test_name, ".hex"};
        rvfi_dii_enable = 0;

        $display("Running test %s (from \"test\" commandline arg)", test_name);
        run_test(test_name);
        $finish;
    end else if ($test$plusargs("all_tests")) begin
        rvfi_dii_enable = 0;
        $display("Running all tests...");
        for (int j=0; j<all_tests.size(); j++) begin
            $display("Test %d: %s", j, all_tests[j]);
            run_test(all_tests[j]);
        end
        $finish;
    end else if ($test$plusargs("dii")) begin
        automatic int portnum = 0;
        automatic int spawn_client = 1;
        automatic int dii_num_tests  = 0;

        $value$plusargs("portnum=%d", portnum);
        if ($test$plusargs("manual_dii_client"))
            spawn_client = 0;
        $value$plusargs("num_tests=%d", dii_num_tests);

        rvfi_dii_enable = 1;
        halt = 1;
        $display("Initializing RVFS-DII socket via DPI call from rv32i_tb...");
        initialize_rvfi_dii(portnum, spawn_client, dii_num_tests);
    end else begin
        $display("-E- please specify one of: +test=<test>, +all_tests, +dii");
    end
  end

  // Generate a clock forever
  initial begin
      forever begin
          #5;
          clk = 1;
          #5;
          clk = 0;
      end
  end

  always @(posedge clk) begin
          if (do_finish)
                  $finish;
  end

  final begin
     if (rvfi_dii_enable)
        finalize_rvfi_dii();
  end

endmodule // rv32i_tb
