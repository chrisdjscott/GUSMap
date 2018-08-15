# Compare atomic operation to thread local storage

Results comparing with the `opt_em` branch (before adding the nThreads option
but that shouldn't affect performance). Results show the mean and standard
error of 5 runs on Mahuika.

Changes are in the `score_fs_scaled_err_c` function in `src/score.c`, see
[here](https://github.com/chrisdjscott/GUSMap/compare/opt_em...openmp-thread-local).

| Number of threads |  rfEst (optim) time with atomic (s) |  rfEst (optim) time without atomic (s) | 
|-------------------|-------------------------------------|----------------------------------------| 
| 1                 |  24.005200 ± 0.001947               |  25.555200 ± 0.001927                  | 
| 2                 |  12.749800 ± 0.052386               |  13.849800 ± 0.001425                  | 
| 4                 |  7.415400 ± 0.012315                |  7.868800 ± 0.002216                   | 
| 8                 |  4.608000 ± 0.0085378               |  4.870000 ± 0.005261                   | 
| 16                |  3.157200 ± 0.001820                |  3.276200 ± 0.001730                   | 
| 36                |  2.370200 ± 0.022809                |  2.403800 ± 0.010089                   | 

