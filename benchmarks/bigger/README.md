# Larger benchmark case 

* 2 Chromosomes
* 700 SNPs
* 200 Individuals

## Memory usage

* Peak memory usage is about 7.5 GB - nothing to worry about

Note, `sacct` can be used to check the peak memory usage, known as `MaxRSS` (here `63505` is the job ID for the Slurm job):

```
[csco212@mahuika02 ~]$ sacct -j 63505
        JobName        JobID      User               Start    Elapsed     AveCPU     MinCPU   TotalCPU  AllocCPUS      State     ReqMem     MaxRSS                       NodeList
--------------- ------------ --------- ------------------- ---------- ---------- ---------- ---------- ---------- ---------- ---------- ---------- ------------------------------
        gus-big        63505   csco212 2018-08-30T13:03:09   00:23:56                         06:03:47         32  COMPLETED       16Gn                                    wbl001
          batch  63505.batch           2018-08-30T13:03:09   00:23:56   00:00:00   00:00:00  00:02.894         32  COMPLETED       16Gn      8004K                         wbl001
         extern 63505.extern           2018-08-30T13:03:09   00:23:56   00:00:00   00:00:00   00:00:00         32  COMPLETED       16Gn       748K                         wbl001
        Rscript      63505.0           2018-08-30T13:03:14   00:23:51   05:13:06   05:13:06   06:03:44         16  COMPLETED       16Gn   7513524K                         wbl001
```

## Performance

Added Rprof profiling:

```r
Rprof("profile.out", line.profiling = TRUE)

# code to be profiled

Rprof(NULL)
```

Hotpaths output:

```
> library(proftools)
> pd <- readProfileData("profile.out")
> hotPaths(pd, total.pct = 10.0)
 path                             total.pct self.pct
 simData$rf_est                   99.92      0.00
 . infer_OPGP_FS (FS.R:772)       94.64      0.00
 . . rf_est_FS_UP (OPGP.R:112)    94.64      0.00
 . . . optim (rfEst.R:443)        94.64      0.00
 . . . . .External2               94.64      0.04
 . . . . . <Anonymous>            94.61      0.07
 . . . . . . fn                   94.54      0.00
 . . . . . . . ?? (wrappers.R:82) 45.68     45.68
 . . . . . . . ?? (wrappers.R:84) 30.67     30.67
 . . . . . . . ?? (wrappers.R:83) 15.97     15.97
```

Around 90% time spent in three lines in wrappers.R, inside `ll_fs_up_ss_scaled_err`:

```r
Kaa <- bcoef_mat*(1-ep)^ref*ep^alt
Kbb <- bcoef_mat*(1-ep)^alt*ep^ref
.Call("ll_fs_up_ss_scaled_err_c",r,Kaa,Kab,Kbb,config,nInd,nSnps)
```

* Converted loop in `ll_fs_up_ss_scaled_err_c` to use OpenMP
* Moved calculation of `Kaa` and `Kbb` into the C function (and parallelised with OpenMP)

### Benchmark results

Timings on Mahuika with 16 cores. The second column is with the likelihood function running in parallel
with OpenMP. The third column adds in moving the calculation of `Kaa` and `Kbb` to C and using OpenMP.

| Component | Original time (mins) | Parallel likelihood time (mins) | Parallel likelihood and Kaa/Kbb time (mins) |
|-----------|----------------------|---------------------------------|---------------------------------------------|
| rf_2pt    | 3.2                  | 3.2                             | 3.2                                         |
| rf_est    | 480.9                | 219.6                           | 20.3                                        |
| Total     | 484.4                | 223.1                           | 23.7                                        |

* `rf_est` ~24x faster
* Overall ~20x faster
* Two things contributing to speedup
  - Moving `Kaa` and `Kbb` array calculations to C
  - Parallelising the array calculations and likelihood calculation with OpenMP
