
knitr::opts_chunk$set(echo = TRUE, eval=TRUE)

# load dev version
# assume GUSMAP_DIR is set
gus_root_dir <- Sys.getenv('GUS_ROOT')
gusmap_src_dir <- paste0(gus_root_dir, "/GUSMap")
cat("Loading GUSMap from:", gusmap_src_dir, "\n")
library(devtools)
load_all(gusmap_src_dir, export_all = FALSE)
library(tictoc)

# set number of threads
num_threads <- max(strtoi(Sys.getenv('OMP_NUM_THREADS')), 1)
cat("Running with num_threads =", num_threads, "\n")

# Code for testing GUSMap

tic("RTIME total")

library(GUSMap)

noChr <- 2
#nSnps <- 100
nSnps <- 700
noFam <- 1
set.seed(5721)
config <- list(sapply(1:noChr, function(x) list(sample(c(1,2,4),size=nSnps, prob=c(1,2,2)/5, replace=T)), simplify=T))
simData <- simFS(1/nSnps,epsilon=0.01,config=config,nInd=200, meanDepth=5, noChr=noChr, seed1=687534, seed2=6772)

tic("RTIME rf_2pt")
simData$rf_2pt(nClust=num_threads)
## plot the results
simData$plotChr(parent="maternal")
simData$plotChr(parent="paternal")
toc()

tic("RTIME rf_est")
simData$rf_est(method="optim", mapped = FALSE, nThreads=num_threads)
toc()

toc()
