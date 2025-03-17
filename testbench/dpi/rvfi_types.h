#ifndef __rvfi_types_h__
#define __rvfi_types_h__

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

#endif
