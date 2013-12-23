# Copyright Sean O'Riordain 2013
# Licenced under a BSD licence

library(rstan)

kUseNTDS <- TRUE # FALSE #
kDoPlots <- FALSE # TRUE #

if (kUseNTDS) {
  # The NTDS data, transformed into cumulative times
  # the failure time in days from the start of testing
  # Data published by Jelinski and Moranda 1972
  bugt <- c(9, 21, 32, 36, 43, 45, 50, 58, 63, 70, 71, 77,
    78, 87, 91, 92, 95, 98, 104, 105, 116, 149, 156, 247,
    249, 250, 337, 384, 396, 405, 540, 798, 814, 849)
  # restrict bugs to the first 26 elements to match the paper
  # by Goel and Okumoto (1979)
  N <- 26
} else {
  # ffv5
  # Data derived from the recorded times in days between some Firefox bugs in Bugzilla
  # Data extracted by Sean O'Riordain
  bugt <- c(1, 7.77, 16.74, 22.44, 24.08, 34.5, 34.64, 35.74, 36.99, 37.96,
      40.94, 42.11, 43.85, 44.3, 45.4, 55.78, 56.78, 65.77, 65.88,
      66.54, 69.87, 72.68, 75.91, 76.27, 77.84, 79.91, 81.53, 85.73,
      87, 87.74, 90.75, 92.92, 97.55, 97.85, 98.15, 99.91, 100.98,
      101.34, 104.64, 108.36, 108.67, 112)
  N <- length(bugt)
}
bugs_dat <- list(N=N, bugs=bugt[1:N])


if (kDoPlots) {
  plot(1:N, bugt)
}

# Simple Goel-Okumoto Non-Homogenous Poission Process model
smodel <- '
  data {
    int<lower=0> N; // number of data points (bugs observed)
    real<lower=0> bugs[N]; // the observed bug times in days
  }
  transformed data {
    real<lower=0> bugsn;
    bugsn <- bugs[N];
  }
  parameters {
    real<lower=1, upper=5000> alpha; // estimated number of bugs in the system
    real<lower=0, upper=0.1> beta;  // finding "rate" parameter
  }
  model{
    real embt;
    real summands[N];
    real log_alpha;
    real log_beta;
    for (i in 1:N) {
      // summands[i] <- -beta*bugs[i] - alpha*(1-exp(-beta*bugs[i]))/N;
      summands[i] <- -beta*bugs[i];
    }
    // faster than doing this inside the loop
    // removing the constants should not make any difference!
    increment_log_prob(sum(summands) + N*(log(alpha)+log(beta)) - alpha*(1-exp(-beta*bugsn)));
  }'


# approx 18.4 seconds including the compile for 1000 reps and 4 chains,
# or 22.6 secs for 10k reps x 4 chains
# of which about 17.9 seconds is due to the compile
system.time( fit <- stan(model_code=smodel, data=bugs_dat, iter=1000, chains=4, diagnostic_file='diagnostic_file.dat') )

print(fit)

if (kDoPlots) {
  source('stanGgplot.R')

  stanPathPlot(fit)
}

