#include <algorithm>
#include <arpa/inet.h>
#include <condition_variable>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <mutex>
#include <netinet/in.h>
#include <queue>
#include <sstream>
#include <string>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <thread>
#include <unistd.h>

#include "rvfi_ext.h"
#include "rvfi_types.h"

std::thread rvfi_ext_server;
std::thread rvfi_ext_client;

int rvfi_ext_portnum;
int rvfi_ext_client_fd;
int rvfi_ext_socket;
pid_t sail_riscv_pid;

std::queue<RVFI_DII_Execution_PacketV2> rvfi_ext_exec_packet_q;
std::queue<RVFI_DII_Execution_Packet_Ext_Integer> rvfi_ext_ext_integer_q;
std::queue<RVFI_DII_Execution_Packet_Ext_MemAccess> rvfi_ext_ext_memdata_q;

std::mutex rvfi_ext_mtx;
bool trace_done;
int mismatch_count;

extern "C" void compare_rvfi_ext_execution_packetv2(uint64_t time) {
  std::lock_guard<std::mutex> lock(rvfi_ext_mtx);

  if (rvfi_ext_exec_packet_q.empty()) {
    std::cout << "rvfi_ext_exec_packet_q.empty unexpectedly" << std::endl;
    return;
  }
  extern RVFI_DII_Execution_PacketV2 dut_rvfi_ext_packet;
  RVFI_DII_Execution_PacketV2 &dut = dut_rvfi_ext_packet;
  RVFI_DII_Execution_PacketV2 &ref = rvfi_ext_exec_packet_q.front();

  if (trace_done) {
    return;
  }

  // Compare PC
  if (dut.pc_data.rvfi_pc_rdata != ref.pc_data.rvfi_pc_rdata) {
    std::cout << "-E- at t=" << std::dec << time
              << ": Reference model mistmatch on current PC: " << std::endl
              << "\tDUT: PC = 0x" << std::hex << dut.pc_data.rvfi_pc_rdata
              << std::endl
              << "\tref: PC = 0x" << std::hex << ref.pc_data.rvfi_pc_rdata
              << std::endl;
    mismatch_count++;
  }

  if (dut.pc_data.rvfi_pc_wdata != ref.pc_data.rvfi_pc_wdata) {
    std::cout << "-E- at t=" << std::dec << time
              << " Reference model mistmatch on next PC: " << std::endl
              << "\tDUT: PC = 0x" << std::hex << dut.pc_data.rvfi_pc_wdata
              << std::endl
              << "\tref: PC = 0x" << std::hex << ref.pc_data.rvfi_pc_wdata
              << std::endl;
    mismatch_count++;
  }

  // Compare instruction meta data
  // if (dut.basic_data.rvfi_order != ref.basic_data.rvfi_order) {
  //    std::cout << "rvfi_order mismatch (PC=0x" << dut.pc_data.rvfi_pc_rdata
  //    << "): " << std::endl <<
  //           "\tDUT: rvfi_order = " << std::hex << dut.basic_data.rvfi_order
  //           << std::endl <<
  //           "\tref: rvfi_order = " << std::hex << ref.basic_data.rvfi_order
  //           << std::endl;
  //}
  if (dut.basic_data.rvfi_insn != ref.basic_data.rvfi_insn) {
    std::cout << "rvfi_insn mismatch at t=" << std::dec << time << ": (PC=0x"
              << std::hex << dut.pc_data.rvfi_pc_rdata << "):" << std::endl
              << "\tDUT: rvfi_insn = " << std::hex << dut.basic_data.rvfi_insn
              << std::endl
              << "\tref: rvfi_insn = " << std::hex << ref.basic_data.rvfi_insn
              << std::endl;
    mismatch_count++;
  }
  if (dut.basic_data.rvfi_trap != ref.basic_data.rvfi_trap) {
    std::cout << "rvfi_trap mismatch at t=" << std::dec << time << ": (PC=0x"
              << std::hex << dut.pc_data.rvfi_pc_rdata << "):" << std::endl
              << "\tDUT: rvfi_trap = " << std::hex
              << (int)dut.basic_data.rvfi_trap << std::endl
              << "\tref: rvfi_trap = " << std::hex
              << (int)ref.basic_data.rvfi_trap << std::endl;
    mismatch_count++;
  }
  if (dut.basic_data.rvfi_halt != ref.basic_data.rvfi_halt) {
    std::cout << "rvfi_halt mismatch at t=" << std::dec << time << ": (PC=0x"
              << std::hex << dut.pc_data.rvfi_pc_rdata << "):" << std::endl
              << "\tDUT: rvfi_halt = " << std::hex
              << (int)dut.basic_data.rvfi_halt << std::endl
              << "\tref: rvfi_halt = " << std::hex
              << (int)ref.basic_data.rvfi_halt << std::endl;
    mismatch_count++;
  }
  if (dut.basic_data.rvfi_intr != ref.basic_data.rvfi_intr) {
    std::cout << "rvfi_intr mismatch at t=" << std::dec << time << ": (PC=0x"
              << std::hex << dut.pc_data.rvfi_pc_rdata << "):" << std::endl
              << "\tDUT: rvfi_intr = " << std::hex
              << (int)dut.basic_data.rvfi_intr << std::endl
              << "\tref: rvfi_intr = " << std::hex
              << (int)ref.basic_data.rvfi_intr << std::endl;
    mismatch_count++;
  }
  if (dut.basic_data.rvfi_mode != ref.basic_data.rvfi_mode) {
    std::cout << "rvfi_mode mismatch at t=" << std::dec << time << ": (PC=0x"
              << std::hex << dut.pc_data.rvfi_pc_rdata << "):" << std::endl
              << "\tDUT: rvfi_mode = " << std::hex
              << (int)dut.basic_data.rvfi_mode << std::endl
              << "\tref: rvfi_mode = " << std::hex
              << (int)ref.basic_data.rvfi_mode << std::endl;
    mismatch_count++;
  }
  if (dut.basic_data.rvfi_ixl != ref.basic_data.rvfi_ixl) {
    std::cout << "rvfi_ixl mismatch at t=" << std::dec << time << ": (PC=0x"
              << std::hex << dut.pc_data.rvfi_pc_rdata << "):" << std::endl
              << "\tDUT: rvfi_ixl = " << std::hex
              << (int)dut.basic_data.rvfi_ixl << std::endl
              << "\tref: rvfi_ixl = " << std::hex
              << (int)ref.basic_data.rvfi_ixl << std::endl;
    mismatch_count++;
  }
  // if (dut.basic_data.rvfi_valid != ref.basic_data.rvfi_valid) {
  //    std::cout << "rvfi_valid mismatch: (PC=0x" << std::hex <<
  //    dut.pc_data.rvfi_pc_rdata << "):" << std::endl <<
  //           "\tDUT: rvfi_valid = " << std::hex <<
  //           (int)dut.basic_data.rvfi_valid << std::endl <<
  //           "\tref: rvfi_valid = " << std::hex <<
  //           (int)ref.basic_data.rvfi_valid << std::endl;
  //}

  if (dut.integer_data_available || ref.integer_data_available) {
    if (dut.integer_data_available ^ ref.integer_data_available) {
      std::cout << "-E- integer data available mistmatch at t=" << std::dec
                << time << ": (PC=0x" << std::hex << dut.pc_data.rvfi_pc_rdata
                << "):" << std::endl
                << "\tDUT: integer_data_available = " << std::hex
                << (int)dut.integer_data_available << std::endl
                << "\tref: integer_data_available = " << std::hex
                << (int)ref.integer_data_available << std::endl;
      mismatch_count++;
    } else {
    }
  }
  if (dut.memory_access_data_available || ref.memory_access_data_available) {
    if (dut.memory_access_data_available ^ ref.memory_access_data_available) {
      std::cout << "-E- memory access data available mistmatch at t="
                << std::dec << time << ": (PC=0x" << std::hex
                << dut.pc_data.rvfi_pc_rdata << "):" << std::endl
                << "\tDUT: memory_access_data_available = " << std::hex
                << (int)dut.memory_access_data_available << std::endl
                << "\tref: memory_access_data_available = " << std::hex
                << (int)ref.memory_access_data_available << std::endl;
      mismatch_count++;
    } else {
    }
  }

  rvfi_ext_exec_packet_q.pop();
}

void print_rvfi_dii_execution_packetv2(RVFI_DII_Execution_PacketV2 &packet) {
  std::cout << "magic: 0x" << std::hex << packet.magic << std::endl;
  std::cout << "trace_size: 0x" << std::hex << packet.trace_size << std::endl;
  std::cout << "integer_data_available: 0x" << std::hex
            << (0x1 & ((char)packet.integer_data_available)) << std::endl;
  std::cout << "memory_access_data_available: 0x" << std::hex
            << (0x1 & ((char)packet.memory_access_data_available)) << std::endl;
  std::cout << "--->PC: 0x" << std::hex << packet.pc_data.rvfi_pc_rdata
            << std::endl;
  std::cout << "--->next PC: 0x" << std::hex << packet.pc_data.rvfi_pc_wdata
            << std::endl;
}

extern "C" int get_next_trace_packet(uint64_t time);

uint8_t execution_packet_buffer[sizeof(RVFI_DII_Execution_PacketV2)] = {0};
uint8_t integer_data_buffer[sizeof(RVFI_DII_Execution_Packet_Ext_Integer)] = {
    0};
uint8_t mem_data_buffer[sizeof(RVFI_DII_Execution_Packet_Ext_MemAccess)] = {0};

static RVFI_DII_Execution_PacketV2 *sail_rvfi_ext_packet =
    reinterpret_cast<RVFI_DII_Execution_PacketV2 *>(execution_packet_buffer);
static RVFI_DII_Execution_Packet_Ext_Integer *sail_rvfi_ext_integer_packet =
    reinterpret_cast<RVFI_DII_Execution_Packet_Ext_Integer *>(
        integer_data_buffer);
static RVFI_DII_Execution_Packet_Ext_MemAccess *sail_rvfi_ext_memaccess_packet =
    reinterpret_cast<RVFI_DII_Execution_Packet_Ext_MemAccess *>(
        mem_data_buffer);

static void signalHandler(int signum) {
  std::cout << "Interrupt signal (" << signum
            << ") received. Shutting down the server and client threads..."
            << std::endl;

  shutdown(rvfi_ext_client_fd, SHUT_RDWR);
  close(rvfi_ext_client_fd);
  rvfi_ext_client.join();
}

static void rvfi_ext_server_thread(std::string elf_file) {
  // locate sail-riscv executable:
  const char *sail_env_var = std::getenv("SAIL_RISCV");
  std::string sail_riscv_path =
      (sail_env_var != nullptr) ? std::string(sail_env_var) : "../sail-riscv/";

  std::string sail_emu =
      sail_riscv_path + "/build/" + "c_emulator/riscv_sim_rv32d";
  /*
     -C   --disable-compressed
     -I   --disable-writable-misa
     -F   --disable-fdext
     -W   --disable-vector-ext
  */
  sail_emu += " -C -I -F -W ";

  std::string sail_riscv_cmd = sail_emu + " -Vinstr -Vreg -Vmem -Vplatform " +
                               " -e " + std::to_string(rvfi_ext_portnum) +
                               " -p " + elf_file;

  std::cout << "rvfi_ext_server_thread: starting sail-risc reference model "
               "with command: "
            << std::endl
            << sail_riscv_cmd << std::endl;

  // Convert sail_riscv_cmd to char*[] for execvp
  std::istringstream iss(sail_riscv_cmd);
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

  sail_riscv_pid = fork();
  int status;
  if (sail_riscv_pid == 0) {
    // In child process: Replace current process with actual command
    execvp(c_args[0], c_args.data());
    perror("rvfi_ext_server_thread: execvp failed");
    exit(1); // If exec fails, exit child process
  } else if (sail_riscv_pid < 0) {
    std::cerr << "Fork failed!" << std::endl;
  } else {
    // Parent process: Just wait for the child to finish
    waitpid(sail_riscv_pid, &status, 0);
    if ((!WIFEXITED(status)) || (WIFEXITED(status) && WEXITSTATUS(status))) {
      std::cerr
          << "rvfi_ext_server_thread: sail-riscv simulator exited abnormally. "
             "Attempting graceful shutdown..."
          << std::endl;
    }
  }
}

int discard_read();
static void rvfi_ext_client_thread() {
  struct sockaddr_in address;
  int opt = 1;
  int addrlen = sizeof(address);

  // Creating socket file descriptor
  if ((rvfi_ext_client_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
    perror("socket failed");
    exit(EXIT_FAILURE);
  }

  // Forcefully attaching socket to the port
  if (setsockopt(rvfi_ext_client_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT,
                 &opt, sizeof(opt))) {
    perror("setsockopt");
    exit(EXIT_FAILURE);
  }

  address.sin_family = AF_INET;
  address.sin_port = htons(rvfi_ext_portnum);

  // Convert IPv4 address from text to binary form
  if (inet_pton(AF_INET, "127.0.0.1", &address.sin_addr) <= 0) {
    std::cerr << "Invalid address/ Address not supported!" << std::endl;
    return;
  }

  // Connect to server
  int connect_attempts = 0;
  do {
    if (connect(rvfi_ext_client_fd, (struct sockaddr *)&address,
                sizeof(address)) < 0) {
      if (connect_attempts++ >= 20) {
        std::cerr << "Connection failed!" << std::endl;
        return;
      }
      usleep(500);
    } else {
      break;
    }
  } while (1);

  // Discard trace packets up to the elf entry point:
  do {
    discard_read();
  } while (sail_rvfi_ext_packet->pc_data.rvfi_pc_wdata != 0x80000000);

  std::cout << "rvfi_ext_client_thread: Connected to server port "
            << rvfi_ext_portnum << "..." << std::endl;

  while (get_next_trace_packet(0) > 0) {
    std::lock_guard<std::mutex> lock(rvfi_ext_mtx);
    rvfi_ext_exec_packet_q.push(*sail_rvfi_ext_packet);

    if (sail_rvfi_ext_packet->integer_data_available) {
      rvfi_ext_ext_integer_q.push(*sail_rvfi_ext_integer_packet);
    }

    if (sail_rvfi_ext_packet->memory_access_data_available) {
      rvfi_ext_ext_memdata_q.push(*sail_rvfi_ext_memaccess_packet);
    }
    trace_done = false;
  };
}

int discard_read() {
  std::lock_guard<std::mutex> lock(rvfi_ext_mtx);

  if (!rvfi_ext_client_fd) {
    std::cout << "get_next_trace_packet, fd is 0..." << std::endl;
    return -1;
  }

  int valread = read(rvfi_ext_client_fd, execution_packet_buffer,
                     sizeof(RVFI_DII_Execution_PacketV2));

  if (valread <= 0) {

    std::cout << "valread lte to 0..." << std::endl;
    return valread;
  }
  if (sail_rvfi_ext_packet->integer_data_available) {
    read(rvfi_ext_client_fd, integer_data_buffer,
         sizeof(RVFI_DII_Execution_Packet_Ext_Integer));
  }

  if (sail_rvfi_ext_packet->memory_access_data_available) {
    read(rvfi_ext_client_fd, mem_data_buffer,
         sizeof(RVFI_DII_Execution_Packet_Ext_MemAccess));
  }
  return valread;
}

extern RVFI_DII_Execution_PacketV2 dut_rvfi_ext_packet;
int get_next_trace_packet(uint64_t time) {
  // std::lock_guard<std::mutex> lock(rvfi_ext_mtx);
  if (!rvfi_ext_client_fd) {

    std::cout << "get_next_trace_packet, fd is 0..." << std::endl;
    return 0;
  }

  int valread = read(rvfi_ext_client_fd, execution_packet_buffer,
                     sizeof(RVFI_DII_Execution_PacketV2));

  if (valread <= 0) {
    if (valread == 0) {
      std::cout << "get_next_trace_packet: Connection closed by peer"
                << std::endl;
    } else {
      std::cerr << "get_next_trace_packet: Error in recv: " << errno
                << std::endl;
    }
    return valread;
  }

  if (sail_rvfi_ext_packet->integer_data_available) {
    read(rvfi_ext_client_fd, integer_data_buffer,
         sizeof(RVFI_DII_Execution_Packet_Ext_Integer));
  }

  if (sail_rvfi_ext_packet->memory_access_data_available) {
    read(rvfi_ext_client_fd, mem_data_buffer,
         sizeof(RVFI_DII_Execution_Packet_Ext_MemAccess));
  }
  return valread;
}

int find_available_port() {
  int sockfd = socket(AF_INET, SOCK_STREAM, 0);
  if (sockfd < 0) {
    perror("socket");
    return -1;
  }

  struct sockaddr_in addr;
  std::memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = 0; // Let OS assign an available port

  if (bind(sockfd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    perror("bind");
    close(sockfd);
    return -1;
  }

  // Retrieve assigned port
  socklen_t addr_len = sizeof(addr);
  if (getsockname(sockfd, (struct sockaddr *)&addr, &addr_len) < 0) {
    perror("getsockname");
    close(sockfd);
    return -1;
  }

  int port = ntohs(addr.sin_port);
  close(sockfd); // Release the port so the subprocess can use it

  return port;
}

extern "C" {

void initialize_rvfi_ext() {mismatch_count = 0;}
void finalize_rvfi_ext() {}

int rvfi_ext_get_mismatch_count() { return mismatch_count; }

void initialize_sail_ref_model(char *elf_file) {
  std::cout << "In main of %s" << __FILE__ << std::endl;

  struct sigaction sa;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = 0;

  sa.sa_handler = SIG_IGN;          // Ignore SIGPIPE globally
  sigaction(SIGPIPE, &sa, nullptr); // Register SIGPIPE handler

  sa.sa_handler = signalHandler;
  sigaction(SIGINT, &sa, nullptr); // Register SIGINT handler

  rvfi_ext_portnum = find_available_port();

  trace_done = true;

  rvfi_ext_server = std::thread(rvfi_ext_server_thread, std::string(elf_file));
  rvfi_ext_client = std::thread(rvfi_ext_client_thread);

  do {
    std::lock_guard<std::mutex> lock(rvfi_ext_mtx);
    if (!trace_done) {
      break;
    }
  } while (1);
}

void finalize_sail_ref_model() {
  rvfi_ext_client.join();
  rvfi_ext_server.join();

  std::lock_guard<std::mutex> lock(rvfi_ext_mtx);
  trace_done = true;
  while (!rvfi_ext_exec_packet_q.empty()) {
    rvfi_ext_exec_packet_q.pop();
  }
  while (!rvfi_ext_ext_integer_q.empty()) {
    rvfi_ext_ext_integer_q.pop();
  }
  while (!rvfi_ext_ext_memdata_q.empty()) {
    rvfi_ext_ext_memdata_q.pop();
  }
}
}
