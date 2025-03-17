#ifndef __rvfi_dii_h__
#define __rvfi_dii_h__

extern std::mutex rvfi_dii_mtx;
extern std::mutex rvfi_dii_shutdown_mutex;
extern std::condition_variable rvfi_dii_cv;

extern std::thread rvfi_dii_server;
extern std::thread rvfi_dii_client;

extern bool rvfi_dii_server_started;
extern bool rvfi_dii_server_time_to_exit;
extern bool rvfi_dii_client_connected_or_dead;

extern int rvfi_dii_portnum;
extern int rvfi_dii_server_fd;
extern int rvfi_dii_socket;
extern pid_t testrig_vengine_pid;

#endif
