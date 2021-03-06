##########################################################################
# Genotyping Uncertainty with Sequencing data and linkage MAPping
# Copyright 2017-2018 Timothy P. Bilton <tbilton@maths.otago.ac.nz>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################
### R Function for reading in RA data.
### Author: Timothy Bilton
### Date: 6/02/18

#' Read an Reference/Alternate (RA) file.
#' 
#' Function which processes an RA file containing full-sib families into R and filters the data.
#' 
#' RA format is a tab-delimited with columns, CHROM, POS, SAMPLES
#' where SAMPLES consists of sampleIDs, which typically consist of a colon-delimited sampleID, flowcellID, lane, seqlibID.
#' e.g.,
#' \tabular{llll}{
#' CHROM \tab  POS  \tab   999220:C4TWKACXX:7:56 \tab  999204:C4TWKACXX:7:56 \cr
#' 1     \tab  415  \tab   5,0                   \tab  0,3                   \cr
#' 1     \tab  443  \tab   1,0                   \tab  4,4                   \cr
#' 1     \tab  448  \tab   0,0                   \tab  0,2
#' }
#' 
#' Currently, the data is filtered based on the followin criteria:
#' \itemize{
#' \item Minor Allele Frequency (MAF): SNPs with a MAF that is below the specified threshold are discarded.
#' \item Proportion of missing genotypes (MISS): SNPs where the proportion of genotypes (e.g., non zero read depth)
#' is less than the specified threshold are discarded.
#' \item Distance between adjacent SNPs (BIN): SNPs which less than a specified distance apart are binned and one
#' SNP is retained by random select.
#' \item Read depth of parental genotypes (DEPTH): Parental genotypes which are (collectly) homozygous are discarded 
#' if the sum of the read depths is not above the specified threshold. SNPs where the segregation type is not inferred 
#' are discarded.
#' \item P-value for segregation test (PVALUE): SNPs must pass a segregation test to be retained in the data set 
#' for a given p-value. Note that the segregation test is adjusted for low depth as given in the supplementary 
#' methods of Bilton et al. (2017).
#' }
#' 
#' @param RAfile Character string giving the path to the RA file to be read into R. Typically the required string is
#' returned from the VCFtoRA function when the VCF file is converted to RA format.
#' @param pedfile Character string giving the path to the pedigree file of the samples in the RA file. See Detials for more information on specification of this file.
#' @param gform Character string specifying whether the SNPs in the RA data have been called using Uneak (\code{gform="uneak"})
#' or using an reference based assembly (\code{gform="reference"}).
#' @param sampthres A numeric value giving the filtering threshold for which infividual samples are removed.
#' @param filter A list containing name elements corresponding to the filtering threshold to use for the processing of the full sib families.
#' See Details for more iinformation regarding the filtering criteria available.
#' @param excsamp A character vector of the sample IDs that are to be excluded (or discarded). Note that the sample IDs must correspond
#' to those given in the RA file that is to be processed.
#' @return A list containing the following elements will be returned;
#' \itemize{
#' \item genon: Matrix of genotypes for the simulated sequencing data.
#' \item depth_Ref: Matrix of the allele counts for the reference allele.
#' \item depth_Alt: Matrix of the allele counts for the alternate allele.
#' \item chrom: Vector of the chromosome number corresponding to each SNP as given in the RA file.
#' \item pos: Vector of chromosome positions corresponding to each SNP as given in the RA file.
#' \item config: Vector of segregation types used in the simulation.
#' \item famInfo: A list containing the information of the pedigree structure as supplied in the pedfile file.
#' simulation.
#' }
#' @author Timothy P. Bilton
#' @export readRA
#' @examples
#' MKfile <- Manuka11()
#' RAfile <- VCFtoRA(MKfile$vcf, makePed=F)
#' MKdata <- readRA(RAfile, MKfile$ped)
#' @export readRA


#### Function for reading in RA data and converting to genon and depth matrices.
readRA <- function(RAfile, pedfile, gform = "reference", sampthres = 0.01, filter=list(MAF=0.05, MISS=0.2, BIN=0, DEPTH=5, PVALUE=0.01), excsamp=NULL){
  
  ## Do some checks
  if(!is.character(RAfile) || length(RAfile) != 1)
    stop("File name of RA data set is not a string of length one")
  if(!is.character(gform) || length(gform) != 1 || !(gform %in% c("reference","uneak")))
    stop("gform argument must be either 'reference' or 'uneak'")
  ## check the filtering criteria
  if(is.null(filter$MAF) || filter$MAF<0 || filter$MAF>1 || !is.numeric(filter$MAF)){
    warning("Minor allele frequency filter has not be specified or is invalid. Setting to 0.05:")
    filter$MAF <- 0.05
  }
  if(is.null(filter$MISS) || filter$MISS<0 || filter$MISS>1 || !is.numeric(filter$MISS)){
    warning("Proportion of missing data filter has not be specified or is invalid. Setting to 20%:")
    filter$MISS <- 0.2
  }
  if(is.null(filter$BIN) || filter$BIN<0 || filter$BIN>1 || !is.numeric(filter$BIN)){
    warning("Minimum distance between adjacent SNPs is not specified or is invalid. Setting to 0:")
    filter$BIN <- 0 
  }
  if(is.null(filter$DEPTH) || filter$DEPTH<0 || is.infinite(filter$DEPTH) || !is.numeric(filter$DEPTH)){
    warning("Minimum depth on the parental genotypes filter has not be specified or is invalid. Setting to a depth of 5")
    filter$DEPTH <- 5
  }
  if(is.null(filter$DEPTH) || filter$DEPTH<0 || is.infinite(filter$DEPTH) || !is.numeric(filter$DEPTH)){
    warning("P-value for segregation test is not specified or invalid. Setting a P-value of 0.01:")
    filter$DEPTH <- 5
  }
  if( !is.null(excsamp) & (!is.vector(excsamp) || !is.character(excsamp)) )
    stop("Input for samples which are to be excluded is invalid. Check argument 'excsamp'")
  
  ## separate character between reference and alternate allele count
  gsep <- switch(gform, denovo = "|", reference = ",")
  ## Process the individuals info
  ghead <- scan(RAfile, what = "", nlines = 1, sep = "\t")
  
  ## Read in the data
  # If reference based
  if (gform == "reference"){
    genosin <- scan(RAfile, skip = 1, sep = "\t", what = c(list(chrom = "", coord = ""), rep(list(""), length(ghead) - 2)))
    chrom <- genosin[[1]]
    pos <- genosin[[2]]
    SNP_Names <- paste(genosin[[1]],genosin[[2]],sep="_")
    indID <- ghead[3:length(ghead)]
  }
  else if (gform == "denovo"){
    genosin <- scan(RAfile, skip = 1, sep = "\t", what = c(list(chrom = ""), rep(list(""), length(ghead) - 6), list(hetc1 = 0, hetc2 = 0, acount1 = 0, acount2 = 0, p = 0)))
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
  
  ### Process the full-sib family
  
  ## sort out the pedigree
  ped <- read.csv(pedfile, stringsAsFactors=F)
  famInfo = list()
  ## work out how many families there are
  parents <- unique(ped[c("Mother","Father")])
  parents <- parents[which(apply(parents,1, function(x) all(x %in% ped$IndividualID))),]
  ## Create each family
  for(fam in 1:nrow(parents)){
    progIndx <- which(apply(ped[c("Mother","Father")],1,function(x) all(x == parents[fam,])))
    famName <- unique(ped$Family[progIndx])
    if(length(famName) != 1)
      stop("Individuals with the same parents have different family names")
    cat("Creating pedigree for family", famName, "\n")
    father <- parents[fam,"Father"]
    mother <- parents[fam,"Mother"]
    if(!(father %in% ped$IndividualID))
      stop("The father is not in the pedigree file")
    if(!(mother %in% ped$IndividualID))
      stop("The mother is not in the pedigree file")
    # create the family structure information
    famInfo[[famName]] <- list()
    famInfo[[famName]]$parents <- list(Father=ped$SampleID[which(ped$IndividualID==father)],
                                       Mother=ped$SampleID[which(ped$IndividualID==mother)])
    famInfo[[famName]]$progeny <- ped$SampleID[progIndx]
  }

  ## subset the data for the ful-sib families and perform the filtering
  noFam <- length(famInfo)
  config_all <- config_infer_all <- nInd_all <- indx <- indID_all <- vector(mode = "list", length = noFam)
  
  cat("-------------\n")
  cat("Processing Data.\n\n")
  
  cat("Filtering criteria for removing SNPs :\n")
  cat("Minor allele frequency (MAF) < ", filter$MAF,"\n")
  cat("Percentage of missing genotypes > ", filter$MISS*100,"%\n\n",sep="")
  
  genon_all <- depth_Ref_all <- depth_Alt_all <- vector(mode="list", length=noFam)
  
  ## extract the data and format correct for each family.
  for(fam in 1:noFam){
    cat("Processing Family ",names(famInfo)[fam],".\n\n",sep="")
    mum <- famInfo[[fam]]$parents$Mother
    dad <- famInfo[[fam]]$parents$Father
    patgrandmum <- famInfo[[fam]]$grandparents$paternalGrandMother
    patgranddad <- famInfo[[fam]]$grandparents$paternalGrandFather
    matgrandmum <- famInfo[[fam]]$grandparents$maternalGrandMother
    matgranddad <- famInfo[[fam]]$grandparents$maternalGrandFather
    ## index the parents
    mumIndx <- which(indID %in% mum)
    if(length(mumIndx) == 0)
      stop(paste0("Mother ID not found family ",fam,"."))
    dadIndx <- which(indID %in% dad)
    if(length(dadIndx) == 0)
      stop(paste0("Father ID not found family ",fam,"."))
    ## index the grandparents
    patgrandparents <- matgrandparents <- FALSE
    if(!is.null(patgrandmum) && !is.null(patgranddad)){
      patgrandparents <- TRUE
      patgrandmumIndx <- which(indID %in% patgrandmum)
      patgranddadIndx <- which(indID %in% patgranddad)
    }
    if(!is.null(matgrandmum) && !is.null(matgranddad)){
      matgrandparents <- TRUE
      matgrandmumIndx <- which(indID %in% matgrandmum)
      matgranddadIndx <- which(indID %in% matgranddad)
    }
    ## index the progeny
    progIndx <- which(indID %in% famInfo[[fam]]$progeny)
    nInd <- length(progIndx)
    indID_all[[fam]] <- indID[progIndx]
    ## subset the data
    genon_prog <- genon[progIndx,]
    depth_Ref_prog <- depth_Ref[progIndx,]
    depth_Alt_prog <- depth_Alt[progIndx,]
    
    ## Determine the segregation types of the loci
    genon_mum <- matrix(genon[mumIndx,], nrow=length(mumIndx), ncol=nSnps) 
    genon_dad <- matrix(genon[dadIndx,], nrow=length(mumIndx), ncol=nSnps)
    depth_mum <- matrix(depth_Ref[mumIndx,] + depth_Alt[mumIndx,], nrow=length(mumIndx), ncol=nSnps)
    depth_dad <- matrix(depth_Ref[dadIndx,] + depth_Alt[dadIndx,], nrow=length(mumIndx), ncol=nSnps)
    
    if(patgrandparents){
      genon_patgrandmum <- matrix(genon[patgrandmumIndx,], nrow=length(patgrandmumIndx), ncol=nSnps) 
      depth_patgrandmum <- matrix(depth_Ref[patgrandmumIndx,] + depth_Alt[patgrandmumIndx,], nrow=length(patgrandmumIndx), ncol=nSnps)
      genon_patgranddad <- matrix(genon[patgranddadIndx,], nrow=length(patgranddadIndx), ncol=nSnps) 
      depth_patgranddad <- matrix(depth_Ref[patgranddadIndx,] + depth_Alt[patgranddadIndx,], nrow=length(patgranddadIndx), ncol=nSnps)
    }
    if(matgrandparents){
      genon_matgrandmum <- matrix(genon[matgrandmumIndx,], nrow=length(matgrandmumIndx), ncol=nSnps) 
      depth_matgrandmum <- matrix(depth_Ref[matgrandmumIndx,] + depth_Alt[matgrandmumIndx,], nrow=length(matgrandmumIndx), ncol=nSnps)
      genon_matgranddad <- matrix(genon[matgranddadIndx,], nrow=length(matgranddadIndx), ncol=nSnps) 
      depth_matgranddad <- matrix(depth_Ref[matgranddadIndx,] + depth_Alt[matgranddadIndx,], nrow=length(matgranddadIndx), ncol=nSnps)
    }
    
    parHap_pat <- sapply(1:nSnps,function(x){
      x_p = genon_dad[,x]; d_p = depth_dad[,x]
      if(any(x_p==1,na.rm=T))
        return("AB")
      else if(sum(d_p) > filter$DEPTH){
        if(all(x_p==2, na.rm=T))
          return("AA")
        else if(all(x_p==0, na.rm=T))
          return("BB")
        else if(patgrandparents){
          if(sum(depth_patgranddad[,x])>filter$DEPTH && sum(depth_patgrandmum)>filter$DEPTH){
            x_gp = genon_patgranddad[,x]; x_gm = genon_patgrandmum[,x]
            if((x_gp == 2 & x_gm == 0) || (x_gp == 0 & x_gm == 2))
              return("AB")
            else if(x_gp == 2 & x_gm == 2)
              return("AA")
            else if(x_gp == 0 & x_gm == 0)
              return("BB")
          }
        }
        else
          return(NA)
      }
      else
        return(NA)
    })
    
    parHap_mat <- sapply(1:nSnps,function(x){
      x_m = genon_mum[,x]; d_m = depth_mum[,x]
      if(any(x_m==1,na.rm=T))
        return("AB")
      else if(sum(d_m) > filter$DEPTH){
        if(all(x_m==2, na.rm=T))
          return("AA")
        else if(all(x_m==0, na.rm=T))
          return("BB")
        else if(matgrandparents){
          if(sum(depth_matgranddad[,x])>filter$DEPTH && sum(depth_matgrandmum)>filter$DEPTH){
            x_gp = genon_matgranddad[,x]; x_gm = genon_matgrandmum[,x]
            if((x_gp == 2 & x_gm == 0) || (x_gp == 0 & x_gm == 2))
              return("AB")
            else if(x_gp == 2 & x_gm == 2)
              return("AA")
            else if(x_gp == 0 & x_gm == 0)
              return("BB")
          }
        }
        else
          return(NA)
      }
      else
        return(NA)
    })
    
    config <- rep(NA,nSnps)
    config[which(parHap_pat == "AB" & parHap_mat == "AB")] <- 1
    config[which(parHap_pat == "AB" & parHap_mat == "AA")] <- 2
    config[which(parHap_pat == "AB" & parHap_mat == "BB")] <- 3
    config[which(parHap_pat == "AA" & parHap_mat == "AB")] <- 4
    config[which(parHap_pat == "BB" & parHap_mat == "AB")] <- 5
    
    #### Segregation test to determine if the SNPs have been miss-classified
    seg_Dis <- sapply(1:nSnps,function(x){
      if(is.na(config[x]))
        return(NA)
      else{
        d = depth_Ref_prog[,x] + depth_Alt_prog[,x]
        g = genon_prog[,x]
        K = sum(1/2^(d[which(d != 0)])*0.5)/sum(d != 0)
        nAA = sum(g==2, na.rm=T)
        nAB = sum(g==1, na.rm=T)
        nBB = sum(g==0, na.rm=T)
        ## check that there are sufficient data to perform the chisq test
        if(sum(nAA+nAB+nBB)/length(g) <= (1-filter$MISS))
          return(NA)
        else if(config[x] == 1){
          exp_prob <- c(0.25 + K,0.5 - 2*K, 0.25 + K)
          ctest <- suppressWarnings(chisq.test(c(nBB,nAB,nAA), p = exp_prob))
          return(ifelse(ctest$p.value < filter$PVALUE, TRUE, FALSE))
        }
        else if(config[x] %in% c(2,4)){
          exp_prob <- c(K, 0.5 - 2*K, 0.5 + K)
          ctest <- suppressWarnings(chisq.test(c(nBB,nAB,nAA), p = exp_prob))
          return(ifelse(ctest$p.value < filter$PVALUE, TRUE, FALSE))
        }
        else if(config[x] %in% c(3,5)){
          exp_prob <- c(0.5 + K, 0.5 - 2*K, K)
          ctest <- suppressWarnings(chisq.test(c(nBB,nAB,nAA), p = exp_prob))
          return(ifelse(ctest$p.value < filter$PVALUE, TRUE, FALSE))
        }
      }
    },simplify = T)
    config[which(seg_Dis)] <- NA
    
    ## Run the filtering of the progeny SNPs
    MAF <- colMeans(genon_prog, na.rm=T)/2
    MAF <- pmin(MAF,1-MAF)
    miss <- apply(genon_prog,2, function(x) sum(is.na(x))/length(x))
    
    ## Extract one SNP from each read.
    if(filter$BIN > 0){
      oneSNP <- rep(FALSE,nSnps)
      oneSNP[unlist(sapply(unique(chrom), function(x){
        ind <- which(chrom == x)
        g1_diff <- diff(pos[ind])
        SNP_bin <- c(0,cumsum(g1_diff > filter$BIN)) + 1
        set.seed(58473+as.numeric(which(x==chrom))[1])
        keepPos <- sapply(unique(SNP_bin), function(y) {
          ind2 <- which(SNP_bin == y)
          if(length(ind2) > 1)
            return(sample(ind2,size=1))
          else if(length(ind2) == 1)
            return(ind2)
        })
        return(ind[keepPos])
      },USE.NAMES = F ))] <- TRUE
    }
    else 
      oneSNP <- rep(TRUE,nSnps)
    
    indx[[fam]] <- (MAF > filter$MAF) & (miss < filter$MISS) & (!is.na(config)) & oneSNP
    
    
    ## save the data for this family to variables
    config_all[[fam]] <- config
    nInd_all[[fam]] <- nInd
    genon_all[[fam]] <- genon_prog
    depth_Ref_all[[fam]] <- depth_Ref_prog
    depth_Alt_all[[fam]] <- depth_Alt_prog
  }
  indx_all <- apply(matrix(unlist(indx),nrow=noFam),2,function(x) all(x))
  genon_all <- lapply(genon_all, function(x) x[,indx_all])
  depth_Ref_all <- lapply(depth_Ref_all, function(x) x[,indx_all])
  depth_Alt_all <- lapply(depth_Alt_all, function(x) x[,indx_all])
  config_all <- lapply(config_all, function(x) x[indx_all])
  
  return(list(genon=genon_all, depth_Ref=depth_Ref_all, depth_Alt=depth_Alt_all,
              chrom=chrom[indx_all], pos=pos[indx_all], config=config_all, famInfo=famInfo))
}
  