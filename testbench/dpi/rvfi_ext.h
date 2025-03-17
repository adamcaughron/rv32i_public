#ifndef __rvfi_ext_h__
#define __rvfi_ext_h__

extern std::thread rvfi_ext_server;
extern std::thread rvfi_ext_client;

extern int rvfi_ext_portnum;
extern int rvfi_ext_client_fd;
extern int rvfi_ext_socket;
extern pid_t sail_riscv_pid;

#endif
