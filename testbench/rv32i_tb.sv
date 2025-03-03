///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

module rv32i_tb ();

  string all_tests[] = '{
	  `include "all_riscv_tests.sv"
  };

  string mem_init_file;

  reg clk = 0;
  reg rst_n = 0;

  // Instantiate the DUT
  rv32i_core i_rv32i_core(
    .clk(clk),
    .rst_n(rst_n)
  );

  task load_test(string test_mem_file);
  	// Program memory initialization
  	// Generate register initialization instructions:
  	for (int j=1; j<32; j++) begin
  		i_rv32i_core.mem[(j-1)] = {{20{1'b0}}, j[4:0], 5'b00100, 2'b11};
  	end
  	// Load memory image:
  	// $display("Initializing memory from file %s", test_mem_file);
  	$readmemh(test_mem_file, i_rv32i_core.mem);
  	$writememh("mem_readback.hex", i_rv32i_core.mem);
  endtask

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
	$display("%s result: TEST TIMEOUT", test_name);
  endtask

  task run_test(string test_name);
	load_test(test_name);
	reset_pulse();
	poll_for_test_completion(test_name);
  endtask

  initial begin
	if ($value$plusargs("mem_init_file=%s", mem_init_file)) begin
		$display("Running test %s (from mem_init_file commandline arg)", mem_init_file);
		run_test(mem_init_file);
	end else begin
		$display("Running all tests...");
		for (int j=0; j<all_tests.size(); j++) begin
			$display("Test %d: %s", j, all_tests[j]);
			run_test(all_tests[j]);
		end
	end
	$finish;
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

endmodule // rv32i_tb
