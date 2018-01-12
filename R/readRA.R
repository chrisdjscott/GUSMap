
#### Function for reading in RA data and converting to genon and depth matrices.
readRA <- function(genofile, gform, sampthres = 0.01, excsamp = NULL){
  
  if(!is.character(genofile) || length(genofile) != 1)
    stop("File name of RA data set is not a string of length one")
  if(!is.character(gform) || length(gform) != 1 || !(gform %in% c("reference","denovo")))
    stop("gform argument must be either 'reference' ot 'denovo'")
  
  ## separate character between reference and alternate allele count
  gsep <- switch(gform, denovo = "|", reference = ",")
  ## Process the individuals info
  ghead <- scan(genofile, what = "", nlines = 1, sep = "\t")
  
  ## Read in the data
  # If reference based
  if (gform == "reference"){
    genosin <- scan(genofile, skip = 1, sep = "\t", what = c(list(chrom = "", coord = 0), rep(list(""), length(ghead) - 2)))
    chrom <- genosin[[1]]
    pos <- genosin[[2]]
    SNP_Names <- paste(genosin[[1]],genosin[[2]],sep="_")
    indID <- ghead[3:length(ghead)]
  }
  else if (gform == "denovo"){
    genosin <- scan(genofile, skip = 1, sep = "\t", what = c(list(chrom = ""), rep(list(""), length(ghead) - 6), list(hetc1 = 0, hetc2 = 0, acount1 = 0, acount2 = 0, p = 0)))
    SNP_Names <- genosin[[1]]
    indID <- ghead[2:(length(ghead)-5)]
  }
  
  ## compute dimensions
  nSnps <- length(SNP_Names)
  nInd <- length(ghead) - switch(gform, reference=2, denovo=6)
  
  ## generate the genon and depth matrices
  depth_Ref <- depth_Alt <- matrix(0, nrow = nInd, ncol = nSnps)
  start.ind <- switch(gform, denovo=1, reference=2)
  for (i in 1:nInd){ 
    depths <- strsplit(genosin[[start.ind+i]], split = gsep, fixed = TRUE)
    depth_Ref[i, ] <- as.numeric(unlist(lapply(depths,function(z) z[1])))
    depth_Alt[i, ] <- as.numeric(unlist(lapply(depths,function(z) z[2])))
  }
  genon <- (depth_Ref > 0) + (depth_Alt == 0)
  genon[which(depth_Ref == 0 & depth_Alt == 0)] <- NA
  
  ## Check that the samples meet the minimum sample treshold
  sampDepth <- rowMeans(depth_Ref + depth_Alt)
  badSamp <- which(sampDepth < sampthres)
  if(length(badSamp) > 0){
    cat("Removed ",length(badSamp)," samples due to having a minimum sample threshold below ",sampthres,".\n\n",sep="")
    excsamp <- unique(c(excsamp,indID[badSamp]))
  }
  ## Remove any sample which we don't want
  if(!is.null(excsamp)){
    toRemove <- which(indID %in% excsamp)
    if(length(excsamp) > 0){
      depth_Ref <- depth_Ref[-toRemove,]
      depth_Alt <- depth_Alt[-toRemove,]
      genon <- genon[-toRemove,]
      indID <- indID[-toRemove]
      nInd <- length(indID)
    }
  }
  
  ## Create the objects
  if (gform == "reference"){
    obj <- RA$new(
      list(genon = genon, depth_Ref = depth_Ref, depth_Alt = depth_Alt, chrom = chrom, pos = pos,
           SNP_Names = SNP_Names, indID = indID, nSnps = nSnps, nInd = nInd, gform = gform)
    )
  } else if (gform == "denovo"){
    stop("To be implemented")
  }
  
  return(obj)
}


# #### Function for creating a particular population structure
# createPop <- function(R6obj, pop = c("full-sib"), ...){
#   
#   ## Make new R6 object depending on the family type.
#   if(pop == "full-sib"){
#     newObj <- FS$new(R6obj)
#     return(makePop(R6obj,...))
#   }
#   else{
#     stop(paste("Population structure",pop,"has not yet be implemented\n"))
#   }
# }
# 
# #### Function for creating a full-sib family population
# makeFS(R6obj, famInfo filter, excSamp)
# 
# 
# ### Generic method for creating a population
# makePop <- function(obj, ...){
#   UseMethod("makePop")
# }
# 
# ### Make a full-sib family population
# makePop.fs <- function(obj, famInfo, excSamp, nClust=3, 
#                        filter=list(MAF=0.05, MISS=0.2, SAMP=0.01, BIN=0, DEPTH=0, PVALUE=0.05)){
#   
#   noFam <- length(famInfo)
#   ## Define variables that will be used.
#   config_all <- config_infer_all <- nSnps_all <- nInd_all <- indID <- indx <- vector(mode = "list", length = noFam)
#   
#   cat("-------------\n")
#   cat("Processing Data.\n\n")
#   
#   cat("Filtering criteria for removing SNPs :\n")
#   cat("Minor allele frequency (MAF) < ", MAFthres,"\n")
#   cat("Percentage of missing genotypes > ", MISSthres*100,"%\n\n",sep="")
#   
#   ## extract the data and format correct for each family.
#   for(fam in 1:noFam){
#     cat("Processing Family ",names(famInfo)[fam],".\n\n",sep="")
#     mum <- famInfo[[fam]]$parents$Mother
#     dad <- famInfo[[fam]]$parents$Father
#     ## index the parents
#     mumIndx <- which(ghead %in% mum)
#     if(length(mumIndx) == 0)
#       stop(paste0("Mother ID not found family ",fam,"."))
#     dadIndx <- which(ghead %in% dad)
#     if(length(dadIndx) == 0)
#       stop(paste0("Father ID not found family ",fam,"."))
#     ## index the progeny
#     progIndx <- which(ghead %in% famInfo[[fam]]$progeny)
#     nInd <- length(progIndx)
#     indID[[fam]] <- ghead[progIndx]
#     ## Compute the read count matrices and genon matrix for the offspring
#     depth_Ref <- depth_Alt <- matrix(0, nrow = nInd, ncol = nSnps)
#     for (i in 1:nInd){ 
#       depths <- strsplit(genosin[[progIndx[i]]], split = gsep, fixed = TRUE)
#       depth_Ref[i, ] <- as.numeric(unlist(lapply(depths,function(z) z[1])))
#       depth_Alt[i, ] <- as.numeric(unlist(lapply(depths,function(z) z[2])))
#     }
#     genon <- (depth_Ref > 0) + (depth_Alt == 0)
#     genon[which(depth_Ref == 0 & depth_Alt == 0)] <- NA
#     
#     ## Check that samples meet the sample treshold
#     sampDepth <- rowMeans(depth_Ref + depth_Alt)
#     badSamp <- which(sampDepth < SAMPthres)
#     if(length(badSamp) > 0){
#       cat("Removed ",length(badSamp)," samples due to having a minimum sample threshold below ",SAMPthres,".\n\n",sep="")
#       excSamp <- unique(c(excSamp,indID[[fam]][badSamp]))
#     }
#     ## Remove any sample which we don't want
#     if(!is.null(excSamp)){
#       toRemove <- which(indID[[fam]] %in% excSamp)
#       if(length(excSamp) > 0){
#         depth_Ref <- depth_Ref[-toRemove,]
#         depth_Alt <- depth_Alt[-toRemove,]
#         genon <- genon[-toRemove,]
#         indID[[fam]] <- indID[[fam]][-toRemove]
#         nInd <- length(indID[[fam]])
#       }
#     }
#     
#     ## Determine the segregation types of the loci
#     genon_mum <- depth_mum <- matrix(nrow=length(mumIndx),ncol=nSnps)
#     for(i in 1:length(mumIndx)){
#       genon_mum[i,] <- unlist(lapply(strsplit(genosin[[mumIndx[i]]],split=","), function(x) switch(1+2*(x[1]==0) + (x[2]==0),1,2,0,NA)))
#       depth_mum[i,] <- unlist(lapply(strsplit(genosin[[mumIndx[i]]],split=","), function(x) sum(as.numeric(x))))
#     }
#     genon_dad <- depth_dad <- matrix(nrow=length(dadIndx),ncol=nSnps)
#     for(i in 1:length(dadIndx)){
#       genon_dad[i,] <- unlist(lapply(strsplit(genosin[[dadIndx[i]]],split=","), function(x) switch(1+2*(x[1]==0) + (x[2]==0),1,2,0,NA)))
#       depth_dad[i,] <- unlist(lapply(strsplit(genosin[[dadIndx[i]]],split=","), function(x) sum(as.numeric(x))))
#     }
#     
#     ## Determine segregation type of each SNP if possible
#     config <- unlist(sapply(1:nSnps,function(x){
#       x_p = genon_dad[,x]; x_m = genon_mum[,x]
#       d_p = depth_dad[,x]; d_m = depth_mum[,x]
#       if(sum(d_p)>DEPTHthres & sum(d_p)>DEPTHthres ){
#         if(any(x_p==1,na.rm=T) & any(x_m==1,na.rm=T))
#           return(1)
#         else if(all(x_m==2,na.rm=T) & (any(x_p==1, na.rm=T) | all(x_p %in% c(0,2), na.rm=T)))
#           return(2)
#         else if(all(x_m==0,na.rm=T) & (any(x_p==1, na.rm=T) | all(x_p %in% c(0,2), na.rm=T)))
#           return(3)
#         else if(all(x_p==2,na.rm=T) & (any(x_m==1, na.rm=T) | all(x_m %in% c(0,2), na.rm=T)))
#           return(4)
#         else if(all(x_p==0,na.rm=T) & (any(x_m==1, na.rm=T) | all(x_m %in% c(0,2), na.rm=T)))
#           return(5)
#         else
#           return(NA)
#       }
#       else return(NA)
#     }))
#     
#     #### Segregation test to determine if the SNPs have been miss-classified
#     seg_Dis <- sapply(1:nSnps,function(x){
#       if(is.na(config[x]))
#         return(NA)
#       else{
#         d = depth_Ref[,x] + depth_Alt[,x]
#         g = genon[,x]
#         K = sum(1/2^(d[which(d != 0)])*0.5)/sum(d != 0)
#         nAA = sum(g==2, na.rm=T)
#         nAB = sum(g==1, na.rm=T)
#         nBB = sum(g==0, na.rm=T)
#         ## check that there are sufficient data to perform the chisq test
#         if(sum(nAA+nAB+nBB)/length(g) <= (1-MISSthres))
#           return(NA)
#         else if(config[x] == 1){
#           exp_prob <- c(0.25 + K,0.5 - 2*K, 0.25 + K)
#           ctest <- chisq.test(c(nBB,nAB,nAA), p = exp_prob)
#           return(ifelse(ctest$p.value < pvalue, TRUE, FALSE))
#         }
#         else if(config[x] %in% c(2,4)){
#           exp_prob <- c(K, 0.5 - 2*K, 0.5 + K)
#           ctest <- chisq.test(c(nBB,nAB,nAA), p = exp_prob)
#           return(ifelse(ctest$p.value < pvalue, TRUE, FALSE))
#         }
#         else if(config[x] %in% c(3,5)){
#           exp_prob <- c(0.5 + K, 0.5 - 2*K, K)
#           ctest <- chisq.test(c(nBB,nAB,nAA), p = exp_prob)
#           return(ifelse(ctest$p.value < pvalue, TRUE, FALSE))
#         }
#       }
#     },simplify = T)
#     config[which(seg_Dis)] <- NA
#     
#     ## Run the filtering of the progeny SNPs
#     MAF <- colMeans(genon, na.rm=T)/2
#     MAF <- pmin(MAF,1-MAF)
#     miss <- apply(genon,2, function(x) sum(is.na(x))/length(x))
#     
#     ## Infer geotypes for over SNPs that have passed the MAF and MISS thresholds
#     #propHeter <- sapply(1:nSnps, function(x) sum(genon[,x] == 1,na.rm=T)/sum(!is.na(genon[,x])))
#     toInfer <- (MAF > MAFthres) & (miss < MISSthres) & is.na(config)
#     
#     seg_Infer <- sapply(1:nSnps, function(x){
#       if(!toInfer[x])
#         return(NA)
#       else{
#         d = depth_Ref[,x] + depth_Alt[,x]
#         g = genon[,x]
#         K = sum(1/2^(d[which(d != 0)])*0.5)/sum(d != 0)
#         nAA = sum(g==2, na.rm=T)
#         nAB = sum(g==1, na.rm=T)
#         nBB = sum(g==0, na.rm=T)
#         ## check that there are sufficient data to perform the chisq test
#         if(sum(nAA+nAB+nBB)/length(g) <= (1-MISSthres))
#           return(NA)
#         ## compute chiseq test for both loci types
#         exp_prob_BI <- c(0.25 + K,0.5 - 2*K, 0.25 + K)
#         exp_prob_SI <- c(K, 0.5 - 2*K, 0.5 + K)
#         ctest_BI <- chisq.test(c(nBB,nAB,nAA), p = exp_prob_BI)
#         ctest_SI_1 <- chisq.test(c(nBB,nAB,nAA), p = exp_prob_SI)
#         ctest_SI_2 <- chisq.test(c(nBB,nAB,nAA), p = rev(exp_prob_SI))
#         ## do tests to see if we can infer type
#         if( ctest_BI$p.value > pvalue & ctest_SI_1$p.value < pvalue & ctest_SI_2$p.value < pvalue )
#           return(1)
#         else if ( ctest_BI$p.value < pvalue & ctest_SI_1$p.value > pvalue & ctest_SI_2$p.value < pvalue )
#           return(4)
#         else if ( ctest_BI$p.value < pvalue & ctest_SI_1$p.value < pvalue & ctest_SI_2$p.value > pvalue )
#           return(5)
#         else
#           return(NA)
#       }
#     },simplify = T)
#     
#     indx[[fam]] <- (MAF > MAFthres) & (miss < MISSthres) & ( !is.na(config) | !is.na(seg_Infer) )
#     
#     config[!indx[[fam]]] <- seg_Infer[!indx[[fam]]] <- NA
#     
#     ## Determine the segregation groups
#     config_all[[fam]] <- config
#     config_infer_all[[fam]] <- seg_Infer
#     
#     nSnps_all[[fam]] <- sum(indx[[fam]])
#     nInd_all[[fam]] <- nInd
#   }
#   
#   ## Find all the SNPs to keep and subset the global variables
#   indx_all <- do.call("rbind",indx)
#   indx_all <- apply(indx_all, 2, any)
#   
#   genon_all <- genon[,indx_all]
#   depth_Ref_all <- depth_Ref[,indx_all]
#   depth_Alt_all <- depth_Alt[,indx_all]
#   chrom_all <- chrom[indx_all]
#   pos_all <- pos[indx_all]
#   
#   group <- group_infer <- vector(mode="list", length=noFam)
#   for(fam in 1:noFam){
#     group[[fam]]$BI <- which(config_all[[fam]][indx_all] == 1)
#     group[[fam]]$PI <- which(config_all[[fam]][indx_all] %in% c(2,3))
#     group[[fam]]$MI <- which(config_all[[fam]][indx_all] %in% c(4,5))
#     
#     group_infer[[fam]]$BI <- which(config_infer_all[[fam]][indx_all] == 1) 
#     group_infer[[fam]]$SI <- which(config_infer_all[[fam]][indx_all] %in% c(4,5))
#     
#     config_all[[fam]] <- config_all[[fam]][indx_all]
#     config_infer_all[[fam]] <- config_infer_all[[fam]][indx_all]
#     
#     cat("-------------\n")
#     cat("Family ",names(famInfo)[fam]," Summary:\n\n",sep="")
#     cat("Number of SNPs remaining after filtering:",nSnps_all[[fam]],"\n")
#     cat("Number of progeny:", nInd_all[[fam]],"\n")
#     cat("Number of SNPs with correct segregation type:", sum(!is.na(config_all[[fam]])) ,"\n")
#     cat("Both-informative (BI):", length(group[[fam]]$BI),"\n")
#     cat("Maternal-informative (MI):", length(group[[fam]]$MI),"\n")
#     cat("Paternal-informative (PI):", length(group[[fam]]$PI),"\n")
#     cat("Number of SNPs with inferred segregation type:", sum(!is.na(config_infer_all[[fam]])),"\n")
#     cat("Both-informative (BI):", length(group_infer[[fam]]$BI),"\n")
#     cat("Maternal/Paternal-informative (MI or PI):", length(group_infer[[fam]]$SI),"\n")
#   }
#   
#   
#   
#   
# }
# 
# 
# readRA <- function(obj,...) UseMethod("readRA")
# 
# readRA.fullsib <- function(genofile, gform, famInfo, excSamp=NULL, nClust=3,
#                    MAFthres=0.05, MISSthres=0.1, SAMPthres=0.01, BINthres=0, DEPTHthres=6, pvalue=0.05){
#   
#   if(!is.character(genofile) || length(genofile) != 1)
#     stop("File name of RA data set is not a string of length one")
#   if(!is.character(gform) || length(gform) != 1 || !(gform %in% c("Tassel","uneak")))
#     stop("gform argument must be either 'Tassel' ot 'uneak'")
#   ### check whether the filtering thresholds have been correctly
#   
#   
#   ## separate character between reference and alternate allele count
#   gsep <- switch(gform, uneak = "|", Tassel = ",")
#   ## Process the individuals info
#   ghead <- scan(genofile, what = "", nlines = 1, sep = "\t")
#   ## Read in the data
#   # If reference based
#   if (gform == "Tassel"){
#     genosin <- scan(genofile, skip = 1, sep = "\t", what = c(list(chrom = "", coord = 0), rep(list(""), length(ghead) - 2)))
#     chrom <- genosin[[1]]
#     pos <- genosin[[2]]
#     SNP_Names <- paste(genosin[[1]],genosin[[2]],sep="_")
#   }
#   else if (gform == "uneak"){
#     genosin <- scan(genofile, skip = 1, sep = "\t", what = c(list(chrom = ""), rep(list(""), length(ghead) - 6), list(hetc1 = 0, hetc2 = 0, acount1 = 0, acount2 = 0, p = 0)))
#     SNP_Names <- genosin[[1]]
#   }
#   ## Compute the number of SNPs
#   nSnps <- length(SNP_Names)
#   noFam <- length(famInfo)
#   
#   ## Define some variables
#   config_all <- config_infer_all <- nSnps_all <- nInd_all <- indID <- indx <- vector(mode = "list", length = noFam)
#   #names(config_all) <- names(config_infer_all) <- names(nSnps_all) <-  names(nInd_all) <- names(indID) <-names(famInfo)
# 
#   cat("-------------\n")
#   cat("Processing Data.\n\n")
#   
#   cat("Filtering criteria for removing SNPs :\n")
#   cat("Minor allele frequency (MAF) < ", MAFthres,"\n")
#   cat("Percentage of missing genotypes > ", MISSthres*100,"%\n\n",sep="")
#   
#   ## extract the data and format correct for each family.
#   for(fam in 1:noFam){
#     cat("Processing Family ",names(famInfo)[fam],".\n\n",sep="")
#     mum <- famInfo[[fam]]$parents$Mother
#     dad <- famInfo[[fam]]$parents$Father
#     ## index the parents
#     mumIndx <- which(ghead %in% mum)
#     if(length(mumIndx) == 0)
#       stop(paste0("Mother ID not found family ",fam,"."))
#     dadIndx <- which(ghead %in% dad)
#     if(length(dadIndx) == 0)
#       stop(paste0("Father ID not found family ",fam,"."))
#     ## index the progeny
#     progIndx <- which(ghead %in% famInfo[[fam]]$progeny)
#     nInd <- length(progIndx)
#     indID[[fam]] <- ghead[progIndx]
#     ## Compute the read count matrices and genon matrix for the offspring
#     depth_Ref <- depth_Alt <- matrix(0, nrow = nInd, ncol = nSnps)
#     for (i in 1:nInd){ 
#       depths <- strsplit(genosin[[progIndx[i]]], split = gsep, fixed = TRUE)
#       depth_Ref[i, ] <- as.numeric(unlist(lapply(depths,function(z) z[1])))
#       depth_Alt[i, ] <- as.numeric(unlist(lapply(depths,function(z) z[2])))
#     }
#     genon <- (depth_Ref > 0) + (depth_Alt == 0)
#     genon[which(depth_Ref == 0 & depth_Alt == 0)] <- NA
# 
#     ## Check that samples meet the sample treshold
#     sampDepth <- rowMeans(depth_Ref + depth_Alt)
#     badSamp <- which(sampDepth < SAMPthres)
#     if(length(badSamp) > 0){
#       cat("Removed ",length(badSamp)," samples due to having a minimum sample threshold below ",SAMPthres,".\n\n",sep="")
#       excSamp <- unique(c(excSamp,indID[[fam]][badSamp]))
#     }
#     ## Remove any sample which we don't want
#     if(!is.null(excSamp)){
#       toRemove <- which(indID[[fam]] %in% excSamp)
#       if(length(excSamp) > 0){
#         depth_Ref <- depth_Ref[-toRemove,]
#         depth_Alt <- depth_Alt[-toRemove,]
#         genon <- genon[-toRemove,]
#         indID[[fam]] <- indID[[fam]][-toRemove]
#         nInd <- length(indID[[fam]])
#       }
#     }
#     
#     ## Determine the segregation types of the loci
#     genon_mum <- depth_mum <- matrix(nrow=length(mumIndx),ncol=nSnps)
#     for(i in 1:length(mumIndx)){
#       genon_mum[i,] <- unlist(lapply(strsplit(genosin[[mumIndx[i]]],split=","), function(x) switch(1+2*(x[1]==0) + (x[2]==0),1,2,0,NA)))
#       depth_mum[i,] <- unlist(lapply(strsplit(genosin[[mumIndx[i]]],split=","), function(x) sum(as.numeric(x))))
#     }
#     genon_dad <- depth_dad <- matrix(nrow=length(dadIndx),ncol=nSnps)
#     for(i in 1:length(dadIndx)){
#       genon_dad[i,] <- unlist(lapply(strsplit(genosin[[dadIndx[i]]],split=","), function(x) switch(1+2*(x[1]==0) + (x[2]==0),1,2,0,NA)))
#       depth_dad[i,] <- unlist(lapply(strsplit(genosin[[dadIndx[i]]],split=","), function(x) sum(as.numeric(x))))
#     }
#     
#     ## Determine segregation type of each SNP if possible
#     config <- unlist(sapply(1:nSnps,function(x){
#       x_p = genon_dad[,x]; x_m = genon_mum[,x]
#       d_p = depth_dad[,x]; d_m = depth_mum[,x]
#       if(sum(d_p)>DEPTHthres & sum(d_p)>DEPTHthres ){
#         if(any(x_p==1,na.rm=T) & any(x_m==1,na.rm=T))
#           return(1)
#         else if(all(x_m==2,na.rm=T) & (any(x_p==1, na.rm=T) | all(x_p %in% c(0,2), na.rm=T)))
#           return(2)
#         else if(all(x_m==0,na.rm=T) & (any(x_p==1, na.rm=T) | all(x_p %in% c(0,2), na.rm=T)))
#           return(3)
#         else if(all(x_p==2,na.rm=T) & (any(x_m==1, na.rm=T) | all(x_m %in% c(0,2), na.rm=T)))
#           return(4)
#         else if(all(x_p==0,na.rm=T) & (any(x_m==1, na.rm=T) | all(x_m %in% c(0,2), na.rm=T)))
#           return(5)
#         else
#           return(NA)
#       }
#       else return(NA)
#     }))
#     
#     #### Segregation test to determine if the SNPs have been miss-classified
#     seg_Dis <- sapply(1:nSnps,function(x){
#       if(is.na(config[x]))
#         return(NA)
#       else{
#         d = depth_Ref[,x] + depth_Alt[,x]
#         g = genon[,x]
#         K = sum(1/2^(d[which(d != 0)])*0.5)/sum(d != 0)
#         nAA = sum(g==2, na.rm=T)
#         nAB = sum(g==1, na.rm=T)
#         nBB = sum(g==0, na.rm=T)
#         ## check that there are sufficient data to perform the chisq test
#         if(sum(nAA+nAB+nBB)/length(g) <= (1-MISSthres))
#           return(NA)
#         else if(config[x] == 1){
#           exp_prob <- c(0.25 + K,0.5 - 2*K, 0.25 + K)
#           ctest <- chisq.test(c(nBB,nAB,nAA), p = exp_prob)
#           return(ifelse(ctest$p.value < pvalue, TRUE, FALSE))
#         }
#         else if(config[x] %in% c(2,4)){
#           exp_prob <- c(K, 0.5 - 2*K, 0.5 + K)
#           ctest <- chisq.test(c(nBB,nAB,nAA), p = exp_prob)
#           return(ifelse(ctest$p.value < pvalue, TRUE, FALSE))
#         }
#         else if(config[x] %in% c(3,5)){
#           exp_prob <- c(0.5 + K, 0.5 - 2*K, K)
#           ctest <- chisq.test(c(nBB,nAB,nAA), p = exp_prob)
#           return(ifelse(ctest$p.value < pvalue, TRUE, FALSE))
#         }
#       }
#     },simplify = T)
#     config[which(seg_Dis)] <- NA
#     
#     ## Run the filtering of the progeny SNPs
#     MAF <- colMeans(genon, na.rm=T)/2
#     MAF <- pmin(MAF,1-MAF)
#     miss <- apply(genon,2, function(x) sum(is.na(x))/length(x))
#     
#     ## Infer geotypes for over SNPs that have passed the MAF and MISS thresholds
#     #propHeter <- sapply(1:nSnps, function(x) sum(genon[,x] == 1,na.rm=T)/sum(!is.na(genon[,x])))
#     toInfer <- (MAF > MAFthres) & (miss < MISSthres) & is.na(config)
#     
#     seg_Infer <- sapply(1:nSnps, function(x){
#       if(!toInfer[x])
#         return(NA)
#       else{
#         d = depth_Ref[,x] + depth_Alt[,x]
#         g = genon[,x]
#         K = sum(1/2^(d[which(d != 0)])*0.5)/sum(d != 0)
#         nAA = sum(g==2, na.rm=T)
#         nAB = sum(g==1, na.rm=T)
#         nBB = sum(g==0, na.rm=T)
#         ## check that there are sufficient data to perform the chisq test
#         if(sum(nAA+nAB+nBB)/length(g) <= (1-MISSthres))
#           return(NA)
#         ## compute chiseq test for both loci types
#         exp_prob_BI <- c(0.25 + K,0.5 - 2*K, 0.25 + K)
#         exp_prob_SI <- c(K, 0.5 - 2*K, 0.5 + K)
#         ctest_BI <- chisq.test(c(nBB,nAB,nAA), p = exp_prob_BI)
#         ctest_SI_1 <- chisq.test(c(nBB,nAB,nAA), p = exp_prob_SI)
#         ctest_SI_2 <- chisq.test(c(nBB,nAB,nAA), p = rev(exp_prob_SI))
#         ## do tests to see if we can infer type
#         if( ctest_BI$p.value > pvalue & ctest_SI_1$p.value < pvalue & ctest_SI_2$p.value < pvalue )
#           return(1)
#         else if ( ctest_BI$p.value < pvalue & ctest_SI_1$p.value > pvalue & ctest_SI_2$p.value < pvalue )
#           return(4)
#         else if ( ctest_BI$p.value < pvalue & ctest_SI_1$p.value < pvalue & ctest_SI_2$p.value > pvalue )
#           return(5)
#         else
#           return(NA)
#       }
#     },simplify = T)
#     
#     indx[[fam]] <- (MAF > MAFthres) & (miss < MISSthres) & ( !is.na(config) | !is.na(seg_Infer) )
#     
#     config[!indx[[fam]]] <- seg_Infer[!indx[[fam]]] <- NA
#     
#     ## Determine the segregation groups
#     config_all[[fam]] <- config
#     config_infer_all[[fam]] <- seg_Infer
#     
#     nSnps_all[[fam]] <- sum(indx[[fam]])
#     nInd_all[[fam]] <- nInd
#   }
#   
#   ## Find all the SNPs to keep and subset the global variables
#   indx_all <- do.call("rbind",indx)
#   indx_all <- apply(indx_all, 2, any)
# 
#   genon_all <- genon[,indx_all]
#   depth_Ref_all <- depth_Ref[,indx_all]
#   depth_Alt_all <- depth_Alt[,indx_all]
#   chrom_all <- chrom[indx_all]
#   pos_all <- pos[indx_all]
#   
#   group <- group_infer <- vector(mode="list", length=noFam)
#   for(fam in 1:noFam){
#     group[[fam]]$BI <- which(config_all[[fam]][indx_all] == 1)
#     group[[fam]]$PI <- which(config_all[[fam]][indx_all] %in% c(2,3))
#     group[[fam]]$MI <- which(config_all[[fam]][indx_all] %in% c(4,5))
#     
#     group_infer[[fam]]$BI <- which(config_infer_all[[fam]][indx_all] == 1) 
#     group_infer[[fam]]$SI <- which(config_infer_all[[fam]][indx_all] %in% c(4,5))
#     
#     config_all[[fam]] <- config_all[[fam]][indx_all]
#     config_infer_all[[fam]] <- config_infer_all[[fam]][indx_all]
#     
#     cat("-------------\n")
#     cat("Family ",names(famInfo)[fam]," Summary:\n\n",sep="")
#     cat("Number of SNPs remaining after filtering:",nSnps_all[[fam]],"\n")
#     cat("Number of progeny:", nInd_all[[fam]],"\n")
#     cat("Number of SNPs with correct segregation type:", sum(!is.na(config_all[[fam]])) ,"\n")
#     cat("Both-informative (BI):", length(group[[fam]]$BI),"\n")
#     cat("Maternal-informative (MI):", length(group[[fam]]$MI),"\n")
#     cat("Paternal-informative (PI):", length(group[[fam]]$PI),"\n")
#     cat("Number of SNPs with inferred segregation type:", sum(!is.na(config_infer_all[[fam]])),"\n")
#     cat("Both-informative (BI):", length(group_infer[[fam]]$BI),"\n")
#     cat("Maternal/Paternal-informative (MI or PI):", length(group_infer[[fam]]$SI),"\n")
#   }
#   
#   ## Create the class object
#   obj <- FS$new(indx_all)
#   ## Update the private variables
#   obj$.__enclos_env__$private$genon <- genon_all
#   obj$.__enclos_env__$private$depth_Ref <- depth_Ref_all
#   obj$.__enclos_env__$private$depth_Alt <- depth_Alt_all
#   obj$.__enclos_env__$private$chrom <- chrom_all
#   obj$.__enclos_env__$private$pos <- pos_all
#   obj$.__enclos_env__$private$indID <- indID
#   obj$.__enclos_env__$private$config <- config_all
#   obj$.__enclos_env__$private$config_infer <- config_infer_all
#   obj$.__enclos_env__$private$group <- group
#   obj$.__enclos_env__$private$group_infer <- group_infer
#   obj$.__enclos_env__$private$nInd <- nInd_all
#   obj$.__enclos_env__$private$nSnps <- nSnps_all
#   obj$.__enclos_env__$private$noFam <- noFam
#   
#   return(obj)
# }
#   
# 
# 
# 