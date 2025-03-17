///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
import "DPI-C" task initialize_rvfi_dii(input int portnum, input int spawn_client, input int num_tests);
import "DPI-C" function void finalize_rvfi_dii();

import "DPI-C" function void initialize_rvfi_ext();
import "DPI-C" function void finalize_rvfi_ext();

import "DPI-C" function void initialize_sail_ref_model(string);
import "DPI-C" function void finalize_sail_ref_model();

function automatic int split_ext(string path, ref string base, ref string ext);
    int dot_pos = path.len();
    for (int i=path.len()-1; i>=0; i--) begin
        if (path[i] == ".") begin
            dot_pos = i;
            break;
        end else if (path[i] == "/")
            break;
    end
    base = path.substr(0, dot_pos-1);
    ext = path.substr(dot_pos + 1, path.len()-1);
    return dot_pos == path.len() ? -1 : dot_pos;
endfunction

function automatic int split(string path, ref string directory, ref string filename);
    int i;
    for (i=path.len()-1; i>=0; i--) begin
        if (path[i] == "/") begin
            break;
        end
    end
    directory = path.substr(0, i==0 || i == 1 ? 0 : i-1);
    filename = path.substr(i + 1, path.len()-1);
    return i;
endfunction

function automatic string basename(string path);
    string directory;
    void'(split(path, directory, basename));
endfunction

function string elf_to_hex(string elf_file);
    string elf_to_hex_cmd;
    string test_path;
    string test_basename;
    string test_name;
    string test_extension;
    string hex_mem_file;

    void'(split(elf_file, test_path, test_basename));
    void'(split_ext(test_basename, test_name, test_extension));

    elf_to_hex_cmd = $sformatf("python3 parse_dump.py %s", elf_file);
    $display("Running system command: %s", elf_to_hex_cmd);
    $system(elf_to_hex_cmd);
    elf_to_hex = $sformatf("%s.hex", test_name);
endfunction

function string get_elf_from_test_name(string test_basename);
    string test_name;
    string test_extension;
    string elf_file;

    void'(split_ext(test_basename, test_name, test_extension));

    elf_file = $sformatf("../TestRIG/riscv-implementations/sail-riscv/test/riscv-tests/%s.elf", test_name);

    return elf_file;
endfunction

module rv32i_tb ();

  string all_tests[] = '{
      `include "all_riscv_tests.sv"
  };

  string test_arg="";

  reg clk = 0;
  reg rst_n = 0;
  reg halt = 0;
  reg unhalt = 0;
  reg do_finish = 0;
  reg rvfi_ext_enable = 0;
  reg rvfi_dii_enable = 0;


  // Instantiate the DUT
  rv32i_core i_rv32i_core(
    .clk(clk),
    .rst_n(rst_n)
    //.halt(halt)
  );

  bind i_rv32i_core rv32i_dii i_rv32i_dii(rv32i_tb.rvfi_ext_enable, rv32i_tb.rvfi_dii_enable, rv32i_tb.halt);

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
    halt = 0;
    reset_pulse();
    poll_for_test_completion(test_name);
    halt = 1;
    @(posedge clk);
  endtask

  task execute_elf_test(string elf_file);
    string hex_mem_file;

    if ($test$plusargs("rvfi_ext")) begin
        initialize_rvfi_ext();
        initialize_sail_ref_model(elf_file);
        rvfi_ext_enable = 1;
    end

    hex_mem_file = elf_to_hex(elf_file);
    run_test(hex_mem_file);

    if (rvfi_ext_enable) begin
        $display("execute_elf_test calling finalize_sail_ref_model");
        finalize_sail_ref_model();
    end
  endtask

  initial begin
    string test_path;
    string test_basename;
    string test_name;
    string test_extension;
    string hex_mem_file;

    $value$plusargs("test=%s", test_arg);
    void'(split(test_arg, test_path, test_basename));
    void'(split_ext(test_basename, test_name, test_extension));

    /*
    $display("test_arg = %s", test_arg);
    $display("test_path = %s", test_path);
    $display("test_basename = %s", test_basename);
    $display("test_name = %s", test_name);
    $display("test_extension = %s", test_extension);
    */

    if ($test$plusargs("rvfi_ext") && !$test$plusargs("dii")) begin
        if (test_arg=="" && !$test$plusargs("all_tests")) begin
            $display("When +rvfi_ext is specified, either a test must be specified with +test arg, or +all_tests must be specified.");
            $finish;
        end

        if (test_extension != "" && test_extension.tolower() != "elf") begin
           $display("When +rvfi_ext is specified, the provided +test argument must be an elf file.");
           $finish;
        end
    end

    if (test_arg != "") begin
        string test_hex_file;
        $display("test name is %s", test_name);

        // check for .hex extension, add it if needed:
        if (test_extension.tolower() == "elf") begin
            //test_hex_file = elf_to_hex(test_arg);
            execute_elf_test(test_arg);
        end else begin
           rvfi_dii_enable = 0;
           $display("Running test %s (from \"test\" commandline arg)", test_name);
           run_test(test_arg);
       end
       $finish;
    end else if ($test$plusargs("all_tests")) begin
        string elf_file;
        rvfi_dii_enable = 0;
        $display("Running all tests...");
        for (int j=0; j<all_tests.size(); j++) begin
            $display("Test %d: %s", j, all_tests[j]);
            elf_file = get_elf_from_test_name(all_tests[j]);
            execute_elf_test(elf_file);
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
        rvfi_ext_enable = 1;
        halt = 1;
        $display("Initializing RVFS-DII socket via DPI call from rv32i_tb...");
        initialize_rvfi_dii(portnum, spawn_client, dii_num_tests);
        initialize_rvfi_ext();
    end else begin
        $display("-E- please specify one of: +test=<test>, +all_tests, +dii");
        $finish;
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
      if (rvfi_ext_enable)
        finalize_rvfi_ext();
  end

endmodule // rv32i_tb
