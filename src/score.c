/*
##########################################################################
# Genotyping Uncertainty with Sequencing data and linkage MAPping (GUSMap)
# Copyright 2017 Timothy P. Bilton <tbilton@maths.otago.ac.nz>
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
 */

#include <R.h>
#include <Rinternals.h>
#include <Rmath.h>
#include <math.h>
#include "probFun.h"

// TO delete

static unsigned long gcd_ui(unsigned long x, unsigned long y) {
  unsigned long t;
  if (y < x) { t = x; x = y; y = t; }
  while (y > 0) {
    t = y;  y = x % y;  x = t;  // y1 <- x0 % y0 ; x1 <- y0
  }
  return x;
}

unsigned long binomial(unsigned long a, unsigned long b) {
  unsigned long n, d, g, r = 1;
  n = a + b;
  if (a == 0) return 1;
  if (a == 1) return n;
  if (a >= n) return (a == n);
  if (a > n/2) a = n-a;
  for (d = 1; d <= a; d++) {
    if (r >= ULONG_MAX/n) {  // Possible overflow 
      unsigned long nr, dr;  // reduced numerator / denominator 
      g = gcd_ui(n, d);  nr = n/g;  dr = d/g;
      g = gcd_ui(r, dr);  r = r/g;  dr = dr/g;
      if (r >= ULONG_MAX/nr) return 0;  // Unavoidable overflow
      r *= nr;
      r /= dr;
      n--;
    } else {
      r *= n--;
      r /= d;
    }
  }
  return r;
}



// Function for extracting entries of the emission probability matrix
// when the OPGPs are known
double Qentry(int OPGP,double Kaa,double Kab, double Kbb,int elem){
  switch(OPGP){
  case 1:
    if(elem == 1)
      return Kbb;
    else if ((elem == 2)|(elem == 3))  
      return Kab;
    else if (elem == 4)
      return Kaa;
  case 2:
    if(elem == 3)
      return Kbb;
    else if ((elem == 1)|(elem == 4))
      return Kab;
    else if (elem == 2)
      return Kaa;
  case 3:
    if(elem == 2) 
      return Kbb;
    else if ((elem == 1)|(elem == 4))
      return Kab;
    else if (elem == 3)
      return Kaa;
  case 4:
    if(elem == 4) 
      return Kbb;
    else if ((elem == 2)|(elem == 3))
      return Kab;
    else if (elem == 1)
      return Kaa;
  case 5:
    if ((elem == 1)|(elem == 2))
      return Kab;
    else if ((elem == 3)|(elem == 4))
      return Kaa;
  case 6:
    if ((elem == 1)|(elem == 2))
      return Kaa;
    else if ((elem == 3)|(elem == 4))
      return Kab;
  case 7:
    if ((elem == 1)|(elem == 2))
      return Kbb;
    else if ((elem == 3)|(elem == 4))
      return Kab;
  case 8:
    if ((elem == 1)|(elem == 2))
      return Kab;
    else if ((elem == 3)|(elem == 4))
      return Kbb;
  case 9:
    if ((elem == 1)|(elem == 3))
      return Kab;
    else if ((elem == 2)|(elem == 4))
      return Kaa;
  case 10:
    if ((elem == 1)|(elem == 3))
      return Kaa;
    else if ((elem == 2)|(elem == 4))
      return Kab;
  case 11:
    if ((elem == 1)|(elem == 3))
      return Kbb;
    else if ((elem == 2)|(elem == 4))
      return Kab;
  case 12:
    if ((elem == 1)|(elem == 3))
      return Kab;
    else if ((elem == 2)|(elem == 4))
      return Kbb;
  case 13:
    return Kaa;
  case 14:
    return Kab;
  case 15:
    return Kab;
  case 16:
    return Kbb;
  } // end of Switch
  return -1;
}


// Function for extracting entries of the emission probability matrix
// when the OPGP are considered the baseline (and so phase is unknown and the r.f's are sex-specific)
double Qentry_up(int config,double Kaa,double Kab, double Kbb,int elem){
  switch(config){
  case 1:
    if(elem == 1)
      return Kbb;
    else if ((elem == 2)|(elem == 3))  
      return Kab;
    else if (elem == 4)
      return Kaa;
  case 2:
    if ((elem == 1)|(elem == 2))
      return Kab;
    else if ((elem == 3)|(elem == 4))
      return Kaa;
  case 3:
    if ((elem == 1)|(elem == 2))
      return Kbb;
    else if ((elem == 3)|(elem == 4))
      return Kab;
  case 4:
    if ((elem == 1)|(elem == 3))
      return Kab;
    else if ((elem == 2)|(elem == 4))
      return Kaa;
  case 5:
    if ((elem == 1)|(elem == 3))
      return Kbb;
    else if ((elem == 2)|(elem == 4))
      return Kab;
  } // end of Switch
  return -1;
}

// Function for returning a specified enetry of the transition matrix for a given recombination fraction value
double Tmat(int s1, int s2, double rval){
  int sSum = s1 + s2*4;
  if((sSum == 0)|(sSum == 5)|(sSum == 10)|(sSum == 15))
    return (1-rval)*(1-rval);
  else if((sSum == 3)|(sSum == 6)|(sSum == 9)|(sSum == 12))
    return rval*rval;
  else
    return (1-rval)*rval;
}

// Function for returning a specified enetry of the transition matrix for a given recombination fraction value
// when the r.f.'s are sex-specific 
double Tmat_ss(int s1, int s2, double r_f, double r_m){
  int sSum = s1 + s2*4;
  if((sSum == 0)|(sSum == 5)|(sSum == 10)|(sSum == 15))
    return (1-r_f)*(1-r_m);
  else if((sSum == 3)|(sSum == 6)|(sSum == 9)|(sSum == 12))
    return r_f*r_m;
  else if((sSum == 1)|(sSum == 4)|(sSum == 11)|(sSum == 14))
    return (1-r_f)*r_m;
  else 
    return r_f*(1-r_m);
}

/////


// Derivative function for rf's
double der_rf(int s1, int s2, double rval){
  double er;
  int sSum = s1 + s2*4;
  if((sSum == 0)|(sSum == 5)|(sSum == 10)|(sSum == 15)){
    er = exp(rval);
    return er*(2+er)/(2*pow(1+er,3));
  }
  else if((sSum == 3)|(sSum == 6)|(sSum == 9)|(sSum == 12)){
    er = exp(-rval);
    return er/(2*pow(1+er,3));
  }
  else{
    er = exp(-rval);
    return pow(er,2)/(2*pow(1+er,3));
  }
}


// Derivative funcations for epsilon
double partial_der_epsilon(int geno, double epsilon, int a, int d){
  switch(geno){
  case 1:
    if(a==0)
      return -d*pow(1+exp(-epsilon),-d-1)*exp(-epsilon);
    if(a==d) 
      return -a*pow(1+exp(epsilon),-a-1)*exp(epsilon);
    else{
      double e1 = 1+exp(epsilon);
      double e2 = 1+exp(-epsilon);
      return binomial(a,d-a)*(pow(e1,-a-1)*pow(e2,-d+a-1)*(-a*e1+(d-a)*e2));
    }
  case 2:
    return 0;
  case 3:
    if(a==0)
      return -d*pow(1+exp(epsilon),-d-1)*exp(epsilon);
    if(a==d) 
      return -a*pow(1+exp(-epsilon),-a-1)*exp(-epsilon);
    else{
      double e1 = 1+exp(epsilon);
      double e2 = 1+exp(-epsilon);
      return binomial(a,d-a)*(pow(e1,-d+a-1)*pow(e2,-a-1)*(-(d-a)*e1+a*e2));
    }
  }
  return -1;
}


double der_epsilon(int OPGP, double epsilon, int a, int b, int elem){
  if((a == 0) & (b == 0))
    return 0;
  int d = a + b;
  switch(OPGP){
  case 1:
    if(elem == 1)
      return partial_der_epsilon(3, epsilon, a, d);
    else if ((elem == 2)|(elem == 3))  
      return partial_der_epsilon(2, epsilon, a, d);
    else if (elem == 4)
      return partial_der_epsilon(1, epsilon, a, d);
  case 2:
    if(elem == 3)
      return partial_der_epsilon(3, epsilon, a, d);
    else if ((elem == 1)|(elem == 4))
      return partial_der_epsilon(2, epsilon, a, d);
    else if (elem == 2)
      return partial_der_epsilon(1, epsilon, a, d);
  case 3:
    if(elem == 2) 
      return partial_der_epsilon(3, epsilon, a, d);
    else if ((elem == 1)|(elem == 4))
      return partial_der_epsilon(2, epsilon, a, d);
    else if (elem == 3)
      return partial_der_epsilon(1, epsilon, a, d);
  case 4:
    if(elem == 4) 
      return partial_der_epsilon(3, epsilon, a, d);
    else if ((elem == 2)|(elem == 3))
      return partial_der_epsilon(2, epsilon, a, d);
    else if (elem == 1)
      return partial_der_epsilon(1, epsilon, a, d);
  case 5:
    if ((elem == 1)|(elem == 2))
      return partial_der_epsilon(2, epsilon, a, d);
    else if ((elem == 3)|(elem == 4))
      return partial_der_epsilon(1, epsilon, a, d);
  case 6:
    if ((elem == 1)|(elem == 2))
      return partial_der_epsilon(1, epsilon, a, d);
    else if ((elem == 3)|(elem == 4))
      return partial_der_epsilon(2, epsilon, a, d);
  case 7:
    if ((elem == 1)|(elem == 2))
      return partial_der_epsilon(3, epsilon, a, d);
    else if ((elem == 3)|(elem == 4))
      return partial_der_epsilon(2, epsilon, a, d);
  case 8:
    if ((elem == 1)|(elem == 2))
      return partial_der_epsilon(2, epsilon, a, d);
    else if ((elem == 3)|(elem == 4))
      return partial_der_epsilon(3, epsilon, a, d);
  case 9:
    if ((elem == 1)|(elem == 3))
      return partial_der_epsilon(2, epsilon, a, d);
    else if ((elem == 2)|(elem == 4))
      return partial_der_epsilon(1, epsilon, a, d);
  case 10:
    if ((elem == 1)|(elem == 3))
      return partial_der_epsilon(1, epsilon, a, d);
    else if ((elem == 2)|(elem == 4))
      return partial_der_epsilon(2, epsilon, a, d);
  case 11:
    if ((elem == 1)|(elem == 3))
      return partial_der_epsilon(3, epsilon, a, d);
    else if ((elem == 2)|(elem == 4))
      return partial_der_epsilon(2, epsilon, a, d);
  case 12:
    if ((elem == 1)|(elem == 3))
      return partial_der_epsilon(2, epsilon, a, d);
    else if ((elem == 2)|(elem == 4))
      return partial_der_epsilon(3, epsilon, a, d);
  case 13:
    return partial_der_epsilon(1, epsilon, a, d);
  case 14:
    return partial_der_epsilon(2, epsilon, a, d);
  case 15:
    return partial_der_epsilon(2, epsilon, a, d);
  case 16:
    return partial_der_epsilon(3, epsilon, a, d);
  } // end of Switch
  return -1;
}


SEXP score_fs_scaled_err_c(SEXP r, SEXP epsilon, SEXP depth_Ref, SEXP depth_Alt, SEXP Kaa, SEXP Kab, SEXP Kbb, SEXP OPGP, SEXP nInd, SEXP nSnps){
  // Initialize variables
  int s1, s2, ind, snp, snp_der, nInd_c, nSnps_c, *pOPGP, *pdepth_Ref, *pdepth_Alt;
  double *pscore, *pr, *pKaa, *pKab, *pKbb, epsilon_c, delta;
  double alphaTilde[4], alphaDot[4], sum, sum_der, w_new;
  // Load R input variables into C
  nInd_c = INTEGER(nInd)[0];
  nSnps_c = INTEGER(nSnps)[0];
  // Define the pointers to the other input R variables
  pOPGP = INTEGER(OPGP);
  pdepth_Ref = INTEGER(depth_Ref);
  pdepth_Alt = INTEGER(depth_Alt);
  pKaa = REAL(Kaa);
  pKab = REAL(Kab);
  pKbb = REAL(Kbb);
  pr = REAL(r); 
  epsilon_c = REAL(epsilon)[0];
  // Define the output variable
  SEXP score;
  PROTECT(score = allocVector(REALSXP, nSnps_c));
  pscore = REAL(score);
  //SEXP pout = PROTECT(allocVector(VECSXP, 3));
  double llval = 0, phi[4][nSnps_c], phi_prev[4][nSnps_c], score_c[nSnps_c];
  
  // Now compute the likelihood and score function
  for(ind = 0; ind < nInd_c; ind++){
    // Compute forward probabilities at snp 1
    sum = 0;
    for(s1 = 0; s1 < 4; s1++){
      //Rprintf("Q value :%.6f at snp %i in ind %i\n", Qentry(pOPGP[0], pKaa[ind], pKab[ind], pKbb[ind], s1+1, delta_c), 0, ind);
      alphaDot[s1] = 0.25 * Qentry(pOPGP[0], pKaa[ind], pKab[ind], pKbb[ind], s1+1);
      sum = sum + alphaDot[s1];
      // Compute the derivative for epsilon
      Rprintf("phi at epsilon :%.6f fpr a = %i and b = %i\n", der_epsilon(pOPGP[0], epsilon_c, pdepth_Ref[ind], pdepth_Alt[ind], s1+1), pdepth_Ref[ind], pdepth_Alt[ind]);
      phi_prev[s1][nSnps_c-1] = 0.25*der_epsilon(pOPGP[0], epsilon_c, pdepth_Ref[ind], pdepth_Alt[ind], s1+1);
    }
    //Scale forward probabilities
    for(s1 = 0; s1 < 4; s1++){
      alphaTilde[s1] = alphaDot[s1]/sum;
    }

    // add contribution to likelihood
    //w_logcumsum = log(sum);
    llval = llval + log(sum);

    // iterate over the remaining SNPs
    for(snp = 1; snp < nSnps_c; snp++){
      // compute the next forward probabilities for snp \ell
      w_new = 0;
      for(s2 = 0; s2 < 4; s2++){
        sum = 0;
        for(s1 = 0; s1 < 4; s1++){
          sum = sum + Tmat(s1, s2, pr[snp-1]) * alphaTilde[s1];
        }
        //Rprintf("Q value :%.6f at snp %i in ind %i\n", Qentry(pOPGP[snp], pKaa[ind + nInd_c*snp], pKab[ind + nInd_c*snp], pKbb[ind + nInd_c*snp], s2+1, delta_c), snp, ind);
        delta = Qentry(pOPGP[snp], pKaa[ind + nInd_c*snp], pKab[ind + nInd_c*snp], pKbb[ind + nInd_c*snp], s2+1);
        alphaDot[s2] = sum * delta;
        // add contribution to new weight
        w_new = w_new + alphaDot[s2];
      }
      //Compute the derivatives
      for(s2 = 0; s2 < 4; s2++){
        delta = Qentry(pOPGP[snp], pKaa[ind + nInd_c*snp], pKab[ind + nInd_c*snp], pKbb[ind + nInd_c*snp], s2+1);
        //rf's
        sum_der = 0;
        for(s1 = 0; s1 < 4; s1++){
          sum_der = sum_der + der_rf(s1, s2, pr[snp-1]) * alphaTilde[s1];
        }
        phi[s2][snp-1] = sum_der * delta * 1/w_new;
        for(snp_der = snp; snp_der < nSnps_c-1; snp_der++){
          sum_der = 0;
          for(s1 = 0; s1 < 4; s1++){
            sum_der = sum_der + phi_prev[s1][snp_der] * Tmat(s1, s2, pr[snp-1]);
          }
          phi[s2][snp_der] = sum_der * delta * 1/w_new;
        }
        //sequencing error parameter
        sum_der = 0;
        for(s1 = 0; s1 < 4; s1++){  
          sum_der = sum_der + ((phi_prev[s1][nSnps_c-1] * delta + alphaTilde[s1] * 
            der_epsilon(pOPGP[snp], epsilon_c, pdepth_Ref[ind + nInd_c*snp], pdepth_Alt[ind + nInd_c*snp], s1+1))) * Tmat(s1, s2, pr[snp-1]);
        }
        Rprintf("phi at epsilon :%.6f foe weight of %.6f\n", sum_der, 1/w_new);
        phi[s2][nSnps_c-1] = sum_der * 1/w_new;
      }
      // Add contribution to the likelihood
      llval = llval + log(w_new);

      // Scale the forward probability vector
      for(s2 = 0; s2 < 4; s2++){
        alphaTilde[s2] = alphaDot[s2]/w_new;
        // update the derivative vectors
        for(snp_der = snp; snp_der < nSnps_c; snp_der++){
          phi_prev[s2][snp_der] = phi[s2][snp_der];
        }
      }
    }
    // add contributions to the score vector
    for(snp_der = 0; snp_der < nSnps_c; snp_der++){
      sum_der = 0;
      for(s2 = 0; s2 < 4; s2++)
        sum_der = sum_der + phi[s2][snp_der];
      score_c[snp_der] = sum_der;
    }
  }
  // Compute the score for each parameter
  for(snp_der=0; snp_der<nSnps_c; snp_der++){
    pscore[snp_der] = score_c[snp_der];
  }
  // Clean up and return likelihood value
  Rprintf("Likelihood value: %f", llval);
  UNPROTECT(1);
  return score;
}



