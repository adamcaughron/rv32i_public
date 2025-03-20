#include <algorithm>
#include <condition_variable>
#include <iostream>
#include <mutex>
#include <netinet/in.h>
#include <queue>
#include <sstream>
#include <string>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <thread>
#include <unistd.h>

#include "rv32i_tb_exports.h"
#include "rvfi_types.h"

#include "rvfi_dii.h"

std::mutex rvfi_dii_mtx;
std::mutex rvfi_dii_shutdown_mutex;
std::condition_variable rvfi_dii_cv;

std::thread rvfi_dii_server;
std::thread rvfi_dii_client;

bool rvfi_dii_server_started = false;
bool rvfi_dii_server_time_to_exit = false;
bool rvfi_dii_client_connected_or_dead = false;

int rvfi_dii_portnum;
int rvfi_dii_server_fd;
int rvfi_dii_socket;
pid_t testrig_vengine_pid;

// forward declarations
void shutdown_server_thread();
void shutdown_client_thread();

void shutdown_client_server() {
  std::lock_guard<std::mutex> lock(rvfi_dii_shutdown_mutex);
  shutdown_client_thread();
  shutdown_server_thread();
}

void signalHandler(int signum) {
  std::cout << "Interrupt signal (" << signum
            << ") received. Shutting down the server and client threads..."
            << std::endl;

  shutdown_client_server();
}

void rvfi_dii_client_thread(int num_tests) {
  std::string test_rig_cmd = "../TestRIG/utils/scripts/runTestRIG.py -b "
                             "manual --implementation-B-port " +
                             std::to_string(rvfi_dii_portnum) +
                             " --no-shrink --no-save --test-len 10000";

  // locate sail-riscv executable:
  const char *sail_env_var = std::getenv("SAIL_RISCV");
  if (sail_env_var != nullptr) {
    std::string sail_riscv_path =
        std::string(sail_env_var) + "/build/c_emulator/";
    test_rig_cmd += " --path-to-sail-riscv-dir " + sail_riscv_path;
  }

  if (num_tests) {
    test_rig_cmd += " -n " + std::to_string(num_tests);
  }

  std::cout << "rvfi_dii_client_thread: starting TestRIG VEngine and "
               "sail-riscv reference model with command: "
            << std::endl
            << test_rig_cmd << std::endl;

  // Convert test_rig_cmd to char*[] for execvp
  std::istringstream iss(test_rig_cmd);
  std::vector<std::string> args;
  std::string word;

  while (iss >> word) {
    args.push_back(word);
  }

  std::vector<char *> c_args;

  for (auto &arg : args) {
    // c_args.push_back(arg.data()); // TODO update to C++20
    c_args.push_back(&arg[0]);
  }
  c_args.push_back(nullptr);

  int result = 0;

  testrig_vengine_pid = fork();
  int status;
  if (testrig_vengine_pid == 0) {
    // In child process: Replace current process with actual command
    execvp(c_args[0], c_args.data());
    perror("rvfi_dii_client_thread: execvp failed");
    exit(1); // If exec fails, exit child process
  } else if (testrig_vengine_pid < 0) {
    std::cerr << "Fork failed!" << std::endl;
  } else {
    // Parent process: Just wait for the child to finish
    waitpid(testrig_vengine_pid, &status, 0);
    if ((!WIFEXITED(status)) || (WIFEXITED(status) && WEXITSTATUS(status))) {
      std::cerr << "rvfi_dii_client_thread: TestRIG exited abnormally. "
                   "Attempting graceful shutdown..."
                << std::endl;
      rvfi_dii_server_time_to_exit = true;
      rvfi_dii_client_connected_or_dead = true;
      rvfi_dii_cv.notify_all();
    }
  }
}

void rvfi_dii_server_thread() {
  struct sockaddr_in address;
  int opt = 1;
  int addrlen = sizeof(address);
  uint8_t buffer[8] = {0};

  // Creating socket file descriptor
  if ((rvfi_dii_server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
    perror("socket failed");
    exit(EXIT_FAILURE);
  }

  // Forcefully attaching socket to the port
  if (setsockopt(rvfi_dii_server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT,
                 &opt, sizeof(opt))) {
    perror("setsockopt");
    exit(EXIT_FAILURE);
  }

  // Set SO_RCVTIMEO (2-second timeout for accept)
  struct timeval timeout;
  timeout.tv_sec = 2;  // 2 seconds
  timeout.tv_usec = 0; // 0 microseconds
  setsockopt(rvfi_dii_server_fd, SOL_SOCKET, SO_RCVTIMEO, &timeout,
             sizeof(timeout));

  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  address.sin_port = htons(rvfi_dii_portnum);

  // Forcefully attaching socket to the port
  if (bind(rvfi_dii_server_fd, (struct sockaddr *)&address, sizeof(address)) <
      0) {
    perror("bind failed");
    exit(EXIT_FAILURE);
  }

  if (listen(rvfi_dii_server_fd, 3) < 0) {
    perror("listen");
    exit(EXIT_FAILURE);
  }

  if (!rvfi_dii_portnum) {
    // Retrieve the assigned port number
    sockaddr_in bound_address;
    socklen_t address_length = sizeof(bound_address);
    if (getsockname(rvfi_dii_server_fd, (struct sockaddr *)&bound_address,
                    &address_length) == -1) {
      perror("getsockname failed.");
      close(rvfi_dii_server_fd);
    } else {
      rvfi_dii_portnum = ntohs(bound_address.sin_port);
    }
  }

  std::cout << "rvfi_dii_server_thread: Ready for client to connect on port "
            << rvfi_dii_portnum << "..." << std::endl;

  // Notify parent thread
  rvfi_dii_server_started = true;
  rvfi_dii_cv.notify_all();

  while (true) {
    if ((rvfi_dii_socket =
             accept(rvfi_dii_server_fd, (struct sockaddr *)&address,
                    (socklen_t *)&addrlen)) < 0) {
      if (errno == EWOULDBLOCK || errno == EAGAIN) {
        if (rvfi_dii_server_time_to_exit) {
          return;
        }
        continue;
      }
      perror("accept");
      exit(EXIT_FAILURE);
    } else {
      break;
    }
  }

  std::cout << "rvfi_dii_server_thread: RVFI_DII VEngine client connection "
               "established."
            << std::endl;

  read(rvfi_dii_socket, buffer, 8);
  RVFI_DII_Instruction_Packet *instr =
      reinterpret_cast<RVFI_DII_Instruction_Packet *>(buffer);

  if (instr->rvfi_cmd == 0 &&
      (instr->rvfi_instr == (('V' << 24) | ('E' << 16) | ('R' << 8) | 'S'))) {
    /*
     * Reset with insn set to 'VERS' is a version negotiation request
     * and not a actual reset request. Respond with a message say that
     * we support version 2.
     */
    std::cout << "rvfi_dii_server_thread: Received EndOfTrace version "
                 "negotiation packet.\n";
    uint8_t rsp_data[(sizeof(RVFI_DII_Execution_Packet))];
    std::fill(rsp_data, rsp_data + sizeof(RVFI_DII_Execution_Packet), 0);
    RVFI_DII_Execution_Packet *rsp_packet =
        reinterpret_cast<RVFI_DII_Execution_Packet *>(rsp_data);
    rsp_packet->rvfi_halt = 0x3;
    std::reverse(rsp_data, rsp_data + sizeof(RVFI_DII_Execution_Packet));

    /*
    std::cout << "Sending trace response of size " << std::dec
              << sizeof(RVFI_DII_Execution_Packet) << ":" << std::endl
              << std::hex << rsp_data << std::endl;
    */

    send(rvfi_dii_socket, rsp_data, sizeof(RVFI_DII_Execution_Packet), 0);

    svScope tb_scope = svGetScopeFromName("rv32i_tb");
    if (tb_scope) {
      svSetScope(tb_scope);
      do_halt();
    } else {
      perror("Weren't able to get the scope of work.rv32i_tb");
      exit(EXIT_FAILURE);
    }
  } else {
    std::cout << "Did not receive EndOfTrace version negotiation packet as "
                 "expected.\n";
    std::cout << "padding:" << std::hex
              << static_cast<unsigned int>(instr->padding) << std::endl;
    std::cout << "rvfi_cmd:" << std::hex
              << static_cast<unsigned int>(instr->rvfi_cmd) << std::endl;
    std::cout << "rvfi_time:" << std::hex
              << static_cast<unsigned int>(instr->rvfi_time) << std::endl;
    std::cout << "rvfi_instr:" << std::hex
              << static_cast<unsigned int>(instr->rvfi_instr) << std::endl;
    std::cout << "Crashing and burning..." << std::endl;
    exit(EXIT_FAILURE);
  }

  read(rvfi_dii_socket, buffer, 8);
  instr = reinterpret_cast<RVFI_DII_Instruction_Packet *>(buffer);

  if (instr->rvfi_instr == 2 && instr->rvfi_cmd == 'v') {
    std::cout
        << "rvfi_dii_server_thread: Engine requested trace in V2 format..."
        << std::endl;
    struct {
      char msg[8];
      uint64_t version;
    } version_response = {{'v', 'e', 'r', 's', 'i', 'o', 'n', '='},
                          instr->rvfi_instr};
    /*
    std::cout << "Sending trace response of size " << std::dec
              << sizeof(version_response) << std::endl;
    */
    send(rvfi_dii_socket, &version_response, sizeof(version_response), 0);
  } else {
    std::cout << "Did not receive version2 request packet as expected.\n";
    std::cout << "padding:" << std::hex
              << static_cast<unsigned int>(instr->padding) << std::endl;
    std::cout << "rvfi_cmd:" << std::hex
              << static_cast<unsigned int>(instr->rvfi_cmd) << std::endl;
    std::cout << "rvfi_time:" << std::hex
              << static_cast<unsigned int>(instr->rvfi_time) << std::endl;
    std::cout << "rvfi_instr:" << std::hex
              << static_cast<unsigned int>(instr->rvfi_instr) << std::endl;
    std::cout << "Crashing and burning..." << std::endl;
    exit(EXIT_FAILURE);
  }

  std::cout << std::flush;

  rvfi_dii_client_connected_or_dead = true;
  rvfi_dii_cv.notify_all();

  // stayin' alive
  do {
    std::unique_lock<std::mutex> lock(rvfi_dii_mtx);
    rvfi_dii_cv.wait(lock, [] { return rvfi_dii_server_time_to_exit; });
  } while (!rvfi_dii_server_time_to_exit);

  std::cout
      << "rvfi_dii_server_thread received signal; cleaning up and exiting..."
      << std::endl;

  close(rvfi_dii_socket);
  close(rvfi_dii_server_fd);

  return;
}

void send_execution_packet(
    RVFI_DII_Execution_PacketV2 *dut_rvfi_ext_packet,
    RVFI_DII_Execution_Packet_Ext_Integer *exec_ext_integer_data,
    RVFI_DII_Execution_Packet_Ext_MemAccess *exec_ext_mem_data) {

  uint8_t *packet_data = reinterpret_cast<uint8_t *>(dut_rvfi_ext_packet);
  send(rvfi_dii_socket, packet_data, sizeof(RVFI_DII_Execution_PacketV2), 0);

  if (dut_rvfi_ext_packet->integer_data_available) {
    uint8_t *ext_int_data = reinterpret_cast<uint8_t *>(exec_ext_integer_data);
    send(rvfi_dii_socket, ext_int_data,
         sizeof(RVFI_DII_Execution_Packet_Ext_Integer), 0);
  }

  if (dut_rvfi_ext_packet->memory_access_data_available) {
    uint8_t *ext_mem_data = reinterpret_cast<uint8_t *>(exec_ext_mem_data);
    send(rvfi_dii_socket, ext_mem_data,
         sizeof(RVFI_DII_Execution_Packet_Ext_MemAccess), 0);
  }
}

uint32_t get_next_instr_packet() {
  static bool is_halted = true;
  int bytes_read;
  uint8_t buffer[sizeof(RVFI_DII_Execution_Packet_Ext_MemAccess)];

  /*
  std::cout << "rvfi_dii get_next_instr_packet: Attempting to read next
  instruction from socket..."
            << std::endl;
  */

  bytes_read = read(rvfi_dii_socket, buffer, 8);

  if (bytes_read <= 0) {
    std::cout << "rvfi_dii get_next_instr_packet: Client has disconnected. "
                 "Finish simulation..."
              << std::endl;

    svScope tb_scope = svGetScopeFromName("rv32i_tb");
    if (tb_scope) {
      svSetScope(tb_scope);
      do_queue_finish();
    } else {
      perror(
          "rvfi_dii get_next_instr_packet: Unable to get the rv32i_tb scope");
      exit(EXIT_FAILURE);
    }
    return 0;
  }

  RVFI_DII_Instruction_Packet *instr =
      reinterpret_cast<RVFI_DII_Instruction_Packet *>(buffer);

  /*
  std::cout << "get_next_instr_packet:" << std::endl;
  std::cout << "\t rvfi_instr: " << "0x" << std::hex << instr->rvfi_instr <<
  std::endl; std::cout << "\t rvfi_time: "  << "0x" << std::hex <<
  instr->rvfi_time << std::endl; std::cout << "\t rvfi_cmd: "   << "0x" <<
  std::hex << instr->rvfi_cmd << " : " << std::dec << instr->rvfi_cmd <<
  std::endl; printf("rvfi_cmd == %0x\n", instr->rvfi_cmd);
  */

  if (instr->rvfi_cmd == 0) {
    /*
    std::cout << "rvfi_dii get_next_instr_packet command is halt/reset"
              << std::endl;
    */
    uint8_t rsp_data[(sizeof(RVFI_DII_Execution_PacketV2))];
    std::fill(rsp_data, rsp_data + sizeof(RVFI_DII_Execution_Packet), 0);
    RVFI_DII_Execution_PacketV2 *rsp_packet =
        reinterpret_cast<RVFI_DII_Execution_PacketV2 *>(rsp_data);
    rsp_packet->magic = v2_trace_magic;
    rsp_packet->trace_size = sizeof(RVFI_DII_Execution_PacketV2);
    rsp_packet->basic_data.rvfi_halt = 1;
    /*
    std::cout << "Sending trace response of size " << std::dec
              << sizeof(RVFI_DII_Execution_PacketV2) << "(0x" << std::hex
              << sizeof(rsp_data) << ")"
              << ":" << std::endl
              << std::hex << rsp_data << std::endl;
    */
    send(rvfi_dii_socket, rsp_data, sizeof(RVFI_DII_Execution_PacketV2), 0);

    svScope tb_scope = svGetScopeFromName("rv32i_tb");
    if (tb_scope) {
      svSetScope(tb_scope);
      do_halt();
      is_halted = true;
    } else {
      perror("rvfi_dii get_next_instr_packet: Weren't able to get the scope of "
             "rv32i_tb");
      exit(EXIT_FAILURE);
    }

    return get_next_instr_packet();

  } else if (instr->rvfi_cmd == 1) {
    // Instruction received
    if (is_halted) {
      svScope tb_scope = svGetScopeFromName("rv32i_tb");
      if (tb_scope) {
        svSetScope(tb_scope);
        do_unhalt();
        is_halted = false;
      } else {
        perror("rvfi_dii get_next_instr_packet: Weren't able to get the scope "
               "of rv32i_tb");
        exit(EXIT_FAILURE);
      }
    }
  }

  return instr->rvfi_instr;
}

RVFI_DII_Execution_PacketV2 dut_rvfi_ext_packet;
RVFI_DII_Execution_Packet_InstMetaData exec_inst_meta_data;
RVFI_DII_Execution_Packet_PC exec_packet_pc;
RVFI_DII_Execution_Packet_Ext_Integer exec_ext_integer_data;
RVFI_DII_Execution_Packet_Ext_MemAccess exec_ext_mem_data;

uint64_t rvfi_order = 0;

void shutdown_server_thread() {
  rvfi_dii_server_time_to_exit = true;
  rvfi_dii_cv.notify_all();
  if (rvfi_dii_server.joinable()) {
    rvfi_dii_server.join();
  }
}
void shutdown_client_thread() {
  if (testrig_vengine_pid) {
    std::cout << "Killing TestRIG subprocess " << (intmax_t)testrig_vengine_pid
              << std::endl;
    kill(testrig_vengine_pid, SIGKILL);
    testrig_vengine_pid = 0;
  }
  if (rvfi_dii_client.joinable()) {
    rvfi_dii_client.join();
  }
}

extern "C" {
void initialize_rvfi_dii(int _portnum = 0, bool spawn_client = true,
                         int num_tests = 0) {
  printf("In initialize_rvfi_dii of %s; starting rvfi_dii server "
         "thread...\n",
         __FILE__);

  struct sigaction sa;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = 0;

  sa.sa_handler = SIG_IGN;          // Ignore SIGPIPE globally
  sigaction(SIGPIPE, &sa, nullptr); // Register SIGPIPE handler

  sa.sa_handler = signalHandler;
  sigaction(SIGINT, &sa, nullptr); // Register SIGINT handler

  rvfi_dii_server_time_to_exit = false;
  rvfi_dii_portnum = _portnum;

  // Move this to a C++ function (TODO):
  rvfi_dii_server = std::thread(rvfi_dii_server_thread);

  // Wait for server to start
  do {
    std::unique_lock<std::mutex> lock(rvfi_dii_mtx);
    rvfi_dii_cv.wait(lock, [] { return rvfi_dii_server_started; });
  } while (!rvfi_dii_server_started);

  if (spawn_client) {
    // Start DII client thread
    rvfi_dii_client = std::thread(rvfi_dii_client_thread, num_tests);
  }

  // Wait for client to connect
  do {
    std::unique_lock<std::mutex> lock(rvfi_dii_mtx);
    rvfi_dii_cv.wait(lock, [] { return rvfi_dii_client_connected_or_dead; });
  } while (rvfi_dii_client.joinable() && !rvfi_dii_client_connected_or_dead);
}

void finalize_rvfi_dii() {
  printf("In finalize_rvfi_dii of %s. Asking server thread to "
         "stop....\n",
         __FILE__);
  shutdown_client_server();
}

void rvfi_set_inst_meta_data(uint64_t rvfi_inst, uint8_t rvfi_trap,
                             uint8_t rvfi_halt, uint8_t rvfi_intr,
                             uint8_t rvfi_mode, uint8_t rvfi_ixl,
                             uint8_t rvfi_valid) {

  /*
  printf("rvfi_set_inst_meta_data:\n");
  printf("\t rvfi_inst : 0x%01x\n", rvfi_inst);
  printf("\t rvfi_trap : 0x%01x\n", rvfi_trap);
  printf("\t rvfi_halt : 0x%01x\n", rvfi_halt);
  printf("\t rvfi_intr : 0x%01x\n", rvfi_intr);
  printf("\t rvfi_mode : 0x%01x\n", rvfi_mode);
  printf("\t rvfi_ixl  : 0x%01x\n", rvfi_ixl );
  printf("\t rvfi_valid: 0x%01x\n", rvfi_valid);
  */

  dut_rvfi_ext_packet.basic_data.rvfi_insn = rvfi_inst;
  dut_rvfi_ext_packet.basic_data.rvfi_trap = rvfi_trap;
  dut_rvfi_ext_packet.basic_data.rvfi_halt = rvfi_halt;
  dut_rvfi_ext_packet.basic_data.rvfi_intr = rvfi_intr;
  dut_rvfi_ext_packet.basic_data.rvfi_mode = rvfi_mode;
  dut_rvfi_ext_packet.basic_data.rvfi_ixl = rvfi_ixl;
  dut_rvfi_ext_packet.basic_data.rvfi_valid = rvfi_valid;
}

void rvfi_set_pc_data(uint64_t pc_rdata, uint64_t pc_wdata) {

  /*
  printf("rvfi_set_pc_data: pc_rdata = 0x%08x   pc_wdata = 0x%08x\n", pc_rdata,
         pc_wdata);
  fflush(stdout);
  */
  dut_rvfi_ext_packet.pc_data.rvfi_pc_rdata = pc_rdata;
  dut_rvfi_ext_packet.pc_data.rvfi_pc_wdata = pc_wdata;
}

void rvfi_set_ext_integer_data(uint64_t rd_wdata, uint64_t rs1_rdata,
                               uint64_t rs2_rdata, uint8_t rd_addr,
                               uint8_t rs1_addr, uint8_t rs2_addr) {

  /*
  printf("rvfi_set_ext_integer_data:\n");
  printf("\t rvfi_rd_wdata:  0x%08x\n", rd_wdata);
  printf("\t rvfi_rs1_rdata: 0x%08x\n", rs1_rdata);
  printf("\t rvfi_rs2_rdata: 0x%08x\n", rs2_rdata);
  printf("\t rvfi_rd_addr:   0x%01x\n", rd_addr);
  printf("\t rvfi_rs1_addr:  0x%01x\n", rs1_addr);
  printf("\t rvfi_rs2_addr:  0x%01x\n", rs2_addr);
  */

  exec_ext_integer_data.magic = int_data_magic;
  exec_ext_integer_data.rvfi_rd_wdata = rd_addr ? rd_wdata : 0;
  exec_ext_integer_data.rvfi_rs1_rdata = rs1_rdata;
  exec_ext_integer_data.rvfi_rs2_rdata = rs2_rdata;
  exec_ext_integer_data.rvfi_rd_addr = rd_addr;
  exec_ext_integer_data.rvfi_rs1_addr = rs1_addr;
  exec_ext_integer_data.rvfi_rs2_addr = rs2_addr;
}

void rvfi_set_ext_mem_data(uint64_t rvfi_mem_rdata[4],
                           uint64_t rvfi_mem_wdata[4], uint32_t rvfi_mem_rmask,
                           uint32_t rvfi_mem_wmask, uint64_t rvfi_mem_addr) {

  /*
  printf("rvfi_set_ext_mem_data:\n");
  for (int i = 0; i < 4; i++) {
    printf("\t rvfi_mem_rdata[%d]: %08x\n", i, rvfi_mem_rdata[i]);
  }
  for (int i = 0; i < 4; i++) {
    printf("\t rvfi_mem_wdata[%d]: %08x\n", i, rvfi_mem_wdata[i]);
  }
  printf("\t rvfi_mem_rmask: %08x\n", rvfi_mem_rmask);
  printf("\t rvfi_mem_wmask: %08x\n", rvfi_mem_wmask);
  printf("\t rvfi_mem_addr:  %08x\n", rvfi_mem_addr);
  */

  exec_ext_mem_data.magic = mem_data_magic;
  for (int i = 0; i < 4; i++) {
    exec_ext_mem_data.rvfi_mem_rdata[i] = rvfi_mem_rdata[i];
    exec_ext_mem_data.rvfi_mem_wdata[i] = rvfi_mem_wdata[i];
  }
  exec_ext_mem_data.rvfi_mem_rmask = rvfi_mem_rmask;
  exec_ext_mem_data.rvfi_mem_wmask = rvfi_mem_wmask;
  exec_ext_mem_data.rvfi_mem_addr = rvfi_mem_addr;
}

void rvfi_set_exec_packet_v2(uint8_t integer_data_available,
                             uint8_t memory_access_data_available) {
  dut_rvfi_ext_packet.magic = v2_trace_magic;
  dut_rvfi_ext_packet.integer_data_available = integer_data_available;
  dut_rvfi_ext_packet.memory_access_data_available =
      memory_access_data_available;

  dut_rvfi_ext_packet.trace_size = sizeof(RVFI_DII_Execution_PacketV2);

  if (integer_data_available) {
    dut_rvfi_ext_packet.trace_size +=
        sizeof(RVFI_DII_Execution_Packet_Ext_Integer);
  }

  if (memory_access_data_available) {
    dut_rvfi_ext_packet.trace_size +=
        sizeof(RVFI_DII_Execution_Packet_Ext_MemAccess);
  }

  send_execution_packet(&dut_rvfi_ext_packet, &exec_ext_integer_data,
                        &exec_ext_mem_data);
}

void rvfi_get_next_instr(uint64_t *_instr) {
  uint32_t instr = get_next_instr_packet();
  // printf("Returning next instruction %08x\n", instr);
  *_instr = instr;
}
}
