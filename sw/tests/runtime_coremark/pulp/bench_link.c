#include "core_portme.h"
#include "bench/bench.h"

/* link to pulp bench */
void bench_start_time(void) {
  reset_timer();
  start_timer();
}

void bench_stop_time(void) {
  stop_timer();
}

int bench_get_time(void) {
  get_time();
}
