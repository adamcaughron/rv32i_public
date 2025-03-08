#include <algorithm>
#include <arpa/inet.h>
#include <condition_variable>
#include <iostream>
#include <mutex>
#include <netinet/in.h>
#include <queue>
#include <string>
#include <thread>
#include <unistd.h>

#include "rv32i_tb_exports.h"

/*
 * See https://github.com/CTSRD-CHERI/TestRIG/blob/master/RVFI-DII.md
 * for a description of RVFI_DII v1 protocol.
 *
 * RVFI_DII v2 protocol is not documented AFAIK.
 * See
 * https://github.com/riscv/sail-riscv/blob/91b55d35e57fbd66b932ecb884c114054663cf2e/model/rvfi_dii.sail
 * and
 * https://github.com/riscv/sail-riscv/blob/91b55d35e57fbd66b932ecb884c114054663cf2e/c_emulator/riscv_sim.c
 * for an implementation.
 */

#pragma pack(push, 1)

struct RVFI_DII_Instruction_Packet {
  uint32_t rvfi_instr;
  uint16_t rvfi_time;
  uint8_t rvfi_cmd;
  uint8_t padding;
};

struct RVFI_DII_Execution_Packet {
  uint8_t rvfi_intr;       // [87] Trap handler
  uint8_t rvfi_halt;       // [86] Halt indicator
  uint8_t rvfi_trap;       // [85] Trap indicator
  uint8_t rvfi_rd_addr;    // [84] Write register address
  uint8_t rvfi_rs2_addr;   // [83]
  uint8_t rvfi_rs1_addr;   // [82] Read register addresses
  uint8_t rvfi_mem_wmask;  // [81] Write mask
  uint8_t rvfi_mem_rmask;  // [80] Read mask
  uint64_t rvfi_mem_wdata; // [72 - 79] Write data
  uint64_t rvfi_mem_rdata; // [64 - 71] Read data
  uint64_t rvfi_mem_addr;  // [56 - 63] Memory access addr
  uint64_t rvfi_rd_wdata;  // [48 - 55] Write register value
  uint64_t rvfi_rs2_data;  // [40 - 47]
  uint64_t rvfi_rs1_data;  // [32 - 39] Read register values
  uint64_t rvfi_insn;      // [24 - 31] Instruction word
  uint64_t rvfi_pc_wdata;  // [16 - 23] PC after instr
  uint64_t rvfi_pc_rdata;  // [08 - 15] PC before instr
  uint64_t rvfi_order;     // [00 - 07] Instruction number
};

struct RVFI_DII_Execution_Packet_InstMetaData {
  uint64_t rvfi_order; //  :  63 .. 0,
  uint64_t rvfi_insn;  //  : 127 .. 64,
  uint8_t rvfi_trap;   //  : 135 .. 128,
  uint8_t rvfi_halt;   //  : 143 .. 136,
  uint8_t rvfi_intr;   //  : 151 .. 144,
  uint8_t rvfi_mode;   //  : 159 .. 152,
  uint8_t rvfi_ixl;    //  : 167 .. 160,
  uint8_t rvfi_valid;  //  : 175 .. 168,
  uint16_t padding;    //  : 191 .. 176,
};

struct RVFI_DII_Execution_Packet_PC {
  uint64_t rvfi_pc_rdata; //  :  63 .. 0,
  uint64_t rvfi_pc_wdata; //  : 127 .. 64,
};

struct RVFI_DII_Execution_Packet_Ext_Integer {
  uint64_t magic;          //  :  63 .. 0, // must be "int-data"
  uint64_t rvfi_rd_wdata;  //  : 127 .. 64,
  uint64_t rvfi_rs1_rdata; //  : 191 .. 128,
  uint64_t rvfi_rs2_rdata; //  : 255 .. 192,
  uint8_t rvfi_rd_addr;    //  : 263 .. 256,
  uint8_t rvfi_rs1_addr;   //  : 271 .. 264,
  uint8_t rvfi_rs2_addr;   //  : 279 .. 272,
  uint64_t padding : 40;   //  : 319 .. 280,
};

struct RVFI_DII_Execution_Packet_Ext_MemAccess {
  uint64_t magic;             //  :  63 .. 0, // must be "mem-data"
  uint64_t rvfi_mem_rdata[4]; //  : 319 .. 64,
  uint64_t rvfi_mem_wdata[4]; //  : 575 .. 320,
  uint32_t rvfi_mem_rmask;    //  : 607 .. 576,
  uint32_t rvfi_mem_wmask;    //  : 639 .. 608,
  uint64_t rvfi_mem_addr;     //  : 703 .. 640,
};

struct RVFI_DII_Execution_PacketV2 {
  uint64_t magic;      //  :  63 .. 0, // must be set to 'trace-v2'
  uint64_t trace_size; //  : 127 .. 64,
  RVFI_DII_Execution_Packet_InstMetaData basic_data; //  : 319 .. 128,
  RVFI_DII_Execution_Packet_PC pc_data;              //  : 447 .. 320,
  uint8_t integer_data_available : 1;                //  : 448,
  uint8_t memory_access_data_available : 1;          //  : 449,
  uint8_t floating_point_data_available : 1;         //  : 450,
  uint8_t csr_read_write_data_available : 1;         //  : 451,
  uint8_t cheri_data_available : 1;                  //  : 452,
  uint8_t cheri_scr_read_write_data_available : 1;   //  : 453,
  uint8_t trap_data_available : 1;                   //  : 454,
  uint8_t unused_data_available_fields[7];           //  : 511 .. 455,
};

const uint64_t v2_trace_magic = 0x32762d6563617274;
const uint64_t int_data_magic = 0x617461642d746e69;
const uint64_t mem_data_magic = 0x617461642d6d656d;

#pragma pack(pop)

std::mutex mtx;
std::condition_variable cv;
std::queue<RVFI_DII_Execution_PacketV2> execution_packet_queue;
std::queue<RVFI_DII_Execution_Packet_Ext_Integer> ext_integer_packet_queue;
std::queue<RVFI_DII_Execution_Packet_Ext_MemAccess> ext_mem_packet_queue;
std::queue<RVFI_DII_Instruction_Packet> instruction_packet_queue;

bool time_to_exit = false;
bool client_connected = false;

int portnum;
int rvfi_dii_socket;

void rvfi_dii_server_thread() {
  int server_fd;
  struct sockaddr_in address;
  int opt = 1;
  int addrlen = sizeof(address);
  uint8_t buffer[8] = {0};

  // Creating socket file descriptor
  if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
    perror("socket failed");
    exit(EXIT_FAILURE);
  }

  // Forcefully attaching socket to the port
  if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt,
                 sizeof(opt))) {
    perror("setsockopt");
    exit(EXIT_FAILURE);
  }

  address.sin_family = AF_INET;
  address.sin_addr.s_addr = INADDR_ANY;
  address.sin_port = htons(portnum);

  // Forcefully attaching socket to the port
  if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
    perror("bind failed");
    exit(EXIT_FAILURE);
  }

  if (listen(server_fd, 3) < 0) {
    perror("listen");
    exit(EXIT_FAILURE);
  }

  if (!portnum) {
    // Retrieve the assigned port number
    sockaddr_in bound_address;
    socklen_t address_length = sizeof(bound_address);
    if (getsockname(server_fd, (struct sockaddr *)&bound_address,
                    &address_length) == -1) {
      perror("getsockname failed.");
      close(server_fd);
    } else {
      portnum = ntohs(bound_address.sin_port);
    }
  }

  std::cout << "rvfi_dii_server_thread: Ready for client to connect on port "
            << portnum << "..." << std::endl;

  if ((rvfi_dii_socket = accept(server_fd, (struct sockaddr *)&address,
                                (socklen_t *)&addrlen)) < 0) {
    perror("accept");
    exit(EXIT_FAILURE);
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

  client_connected = true;
  cv.notify_one();

  // stayin' alive
  std::unique_lock<std::mutex> lock(mtx);
  cv.wait(lock, [] { return time_to_exit; });
  std::cout
      << "rvfi_dii_server_thread received signal; cleaning up and exiting..."
      << std::endl;

  close(rvfi_dii_socket);
  close(server_fd);

  return;
}

void send_execution_packet(
    RVFI_DII_Execution_PacketV2 *exec_packet,
    RVFI_DII_Execution_Packet_Ext_Integer *exec_ext_integer_data,
    RVFI_DII_Execution_Packet_Ext_MemAccess *exec_ext_mem_data) {

  uint8_t *packet_data = reinterpret_cast<uint8_t *>(exec_packet);
  send(rvfi_dii_socket, packet_data, sizeof(RVFI_DII_Execution_PacketV2), 0);

  if (exec_packet->integer_data_available) {
    uint8_t *ext_int_data = reinterpret_cast<uint8_t *>(exec_ext_integer_data);
    send(rvfi_dii_socket, ext_int_data,
         sizeof(RVFI_DII_Execution_Packet_Ext_Integer), 0);
  }

  if (exec_packet->memory_access_data_available) {
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

std::thread server;

RVFI_DII_Execution_PacketV2 exec_packet;
RVFI_DII_Execution_Packet_InstMetaData exec_inst_meta_data;
RVFI_DII_Execution_Packet_PC exec_packet_pc;
RVFI_DII_Execution_Packet_Ext_Integer exec_ext_integer_data;
RVFI_DII_Execution_Packet_Ext_MemAccess exec_ext_mem_data;

uint64_t rvfi_order = 0;

extern "C" {
void initialize_rvfi_dii(int _portnum = 0) {
  printf("In initialize_rvfi_dii of %s; starting rvfi_dii server "
         "thread...\n",
         __FILE__);
  time_to_exit = false;

  portnum = _portnum;

  // Move this to a C++ function (TODO):
  server = std::thread(rvfi_dii_server_thread);

  do {
    std::unique_lock<std::mutex> lock(mtx);
    cv.wait(lock, [] { return 1; });
  } while (!client_connected);
}

void finalize_rvfi_dii() {
  printf("In finalize_rvfi_dii of %s. Asking server thread to "
         "stop....\n",
         __FILE__);

  // Move this to a C++ function (TODO):
  {
    std::lock_guard<std::mutex> lock(mtx);
    time_to_exit = true;
  }
  cv.notify_one();
  server.join();
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

  exec_packet.basic_data.rvfi_insn = rvfi_inst;
  exec_packet.basic_data.rvfi_trap = rvfi_trap;
  exec_packet.basic_data.rvfi_halt = rvfi_halt;
  exec_packet.basic_data.rvfi_intr = rvfi_intr;
  exec_packet.basic_data.rvfi_mode = rvfi_mode;
  exec_packet.basic_data.rvfi_ixl = rvfi_ixl;
  exec_packet.basic_data.rvfi_valid = rvfi_valid;
}

void rvfi_set_pc_data(uint64_t pc_rdata, uint64_t pc_wdata) {

  /*
  printf("rvfi_set_pc_data: pc_rdata = 0x%08x   pc_wdata = 0x%08x\n", pc_rdata,
         pc_wdata);
  fflush(stdout);
  */
  exec_packet.pc_data.rvfi_pc_rdata = pc_rdata;
  exec_packet.pc_data.rvfi_pc_wdata = pc_wdata;
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
  exec_packet.magic = v2_trace_magic;
  exec_packet.integer_data_available = integer_data_available;
  exec_packet.memory_access_data_available = memory_access_data_available;

  exec_packet.trace_size = sizeof(RVFI_DII_Execution_PacketV2);

  if (integer_data_available) {
    exec_packet.trace_size += sizeof(RVFI_DII_Execution_Packet_Ext_Integer);
  }

  if (memory_access_data_available) {
    exec_packet.trace_size += sizeof(RVFI_DII_Execution_Packet_Ext_MemAccess);
  }

  send_execution_packet(&exec_packet, &exec_ext_integer_data,
                        &exec_ext_mem_data);
}

void rvfi_get_next_instr(uint64_t *_instr) {
  uint32_t instr = get_next_instr_packet();
  // printf("Returning next instruction %08x\n", instr);
  *_instr = instr;
}
}
