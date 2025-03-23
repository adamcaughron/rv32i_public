#include "svdpi.h"

#ifdef __cplusplus
extern "C" {
#endif

/* DPI imports */
void initialize_rvfi_dii(int, bool, int);
void finalize_rvfi_dii();

/* DPI exports */
void do_halt();
int do_unhalt();
void do_queue_finish();
void set_rvfi_order(int);

#ifdef __cplusplus
}
#endif

