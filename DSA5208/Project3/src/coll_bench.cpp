// coll_bench.cpp -- micro-benchmark of the three grid collectives of the distributed FFT, with the message sizes of the report.
//   mpirun -np P ./coll_bench [boxes=400] [p=3] [reps=30] > coll_P<P>.csv
// Per rank, the grid sum sends 4*(p*boxes)^2 doubles (Reduce_scatter), the potentials come back with an Allgather of the same total volume, and each of the two
// FFT transposes is an Alltoall of the slab (complex doubles, L^2/P^2 per pair, L = periodic edge rounded up to a multiple of P; here L = 2*p*boxes rounded).
// Output: one CSV line per collective: P,ranks_per_node,collective,bytes_per_rank,min_ms,mean_ms,max_ms  (min/mean/max over ranks of the mean time of `reps` calls,
// each call preceded by a barrier so that the time is transfer + synchronization inside the collective and not the waiting for earlier work).
#include <mpi.h>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <algorithm>
int main(int argc, char** argv) {
  MPI_Init(&argc, &argv);
  int P, r; MPI_Comm_size(MPI_COMM_WORLD, &P); MPI_Comm_rank(MPI_COMM_WORLD, &r);
  int boxes = argc > 1 ? atoi(argv[1]) : 400, p = argc > 2 ? atoi(argv[2]) : 3, reps = argc > 3 ? atoi(argv[3]) : 30;
  MPI_Comm node; MPI_Comm_split_type(MPI_COMM_WORLD, MPI_COMM_TYPE_SHARED, r, MPI_INFO_NULL, &node);
  int rpn; MPI_Comm_size(node, &rpn);
  long M = (long)p * boxes;
  long grid = 4 * M * M; grid = (grid / P + 1) * P;                          // doubles per rank in the grid sum, divisible by P
  long L = 2 * M; L = ((L + P - 1) / P) * P;                                  // periodic edge, divisible by P
  long a2a = std::max(1L, (L * L / ((long)P * P)) * 2);                        // doubles per pair in one transpose (complex = 2 doubles)
  std::vector<double> sb(std::max(grid, a2a * P), 1.0), rb(std::max(grid, a2a * P), 0.0);
  auto bench = [&](const char* name, double bytes, auto&& call) {
    call(); double t = 0;
    for (int i = 0; i < reps; i++) { MPI_Barrier(MPI_COMM_WORLD); double t0 = MPI_Wtime(); call(); t += MPI_Wtime() - t0; }
    t = 1e3 * t / reps; double mn, mx, sm; MPI_Reduce(&t, &mn, 1, MPI_DOUBLE, MPI_MIN, 0, MPI_COMM_WORLD);
    MPI_Reduce(&t, &mx, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD); MPI_Reduce(&t, &sm, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    if (r == 0) std::printf("%d,%d,%s,%.0f,%.3f,%.3f,%.3f\n", P, rpn, name, bytes, mn, sm / P, mx);
  };
  if (r == 0) std::printf("P,ranks_per_node,collective,bytes_per_rank,min_ms,mean_ms,max_ms\n");
  bench("reduce_scatter", 8.0 * grid, [&] { MPI_Reduce_scatter_block(sb.data(), rb.data(), (int)(grid / P), MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD); });
  bench("allgather", 8.0 * grid, [&] { MPI_Allgather(sb.data(), (int)(grid / P), MPI_DOUBLE, rb.data(), (int)(grid / P), MPI_DOUBLE, MPI_COMM_WORLD); });
  bench("alltoall", 8.0 * a2a * P, [&] { MPI_Alltoall(sb.data(), (int)a2a, MPI_DOUBLE, rb.data(), (int)a2a, MPI_DOUBLE, MPI_COMM_WORLD); });
  bench("allreduce", 8.0 * grid, [&] { MPI_Allreduce(sb.data(), rb.data(), (int)grid, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD); });
  MPI_Finalize();
}
