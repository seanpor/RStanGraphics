# some ggplot2 graphics for RStan
# note that if the chains are long we also require Hadley's "bigvis" package
# to avoid spending too much time hanging around!

# do a path plot of N points, i.e. follow the sequence of the chain
# the default is for N=50 points and the first two variables
# useful for checking that:
# * I have converged
# * I am mixing properly
#
# explore multiple sub-samples in different colours
# perhaps label the starting point numbers of each subsample in the legend
#
# General outline... for a given chain - possibly chosen at random from 
# a fit object... take a pair of parameters and extract a number of different
# subsamples (say 4 by default) and plot them in different colours
# label each subsample with the index of the first of the points in the subsample
#
# consider overlaying this on a two-dimensional density plot or contour plot
#
# validation needed:
# * that there is more than one parameter!
# * the chain specified exists
# * 
#
# Parameter explanations:
# fit - an RStan "fit" object
# whichpair - which pair of parameters do you wish to plot?
# chaini - which chain shall we subsample
# N - the lenght of each subsample
# ns - the number of subsamples
#
# nb - if the length of the chain is < N then the entire chain will be plotted
#    - if the length of the chain is < N*ns, then the number of subsamples
#      will be reduced accordingly - no point in plotting the same point more than once
#    - subsamples will be chosen to be non-overlapping
#
# NB - we can end up with duplicate rows, so ideally we highlight these with a bigger point
# > head(e2)
#           parameters
# iterations    alpha         beta
#       [1,] 1450.828 0.0002808135
#       [2,] 1631.769 0.0002418388
#       [3,] 1631.769 0.0002418388
#       [4,] 1718.608 0.0002664065
#       [5,] 1718.608 0.0002664065
#       [6,] 1482.773 0.0002456264
#
stanPathPlot <- function(fit, whichpair=c(1,2), chaini=1, N=50, ns=4, ignoreDups=TRUE, sDEBUG=FALSE) {
  stopifnot(require(ggplot2))
  # ok... lets be sensible... these MUST be TRUE
  stopifnot(!is.null(fit))
  stopifnot(!is.null(whichpair))
  stopifnot(chaini >=1)
  stopifnot(N > 1)

  # need to set permuted as otherwise there will be a random order to the points in the chain!
  e1 <- extract(fit, permuted=FALSE) 
  e2 <- e1[,chaini,whichpair] # now extract the chain and pair we're interested in
  e2 <- data.frame(e2)
  if (ignoreDups) {
    e2 <- e2[!duplicated(e2),]
  }
  if (sDEBUG) {
    cat('Effective Number of rows is', nrow(e2), '\n')
  }
  # how many will we actually sample?
  if (nrow(e2) > N*ns) { # we can manage to do all the subsamples as required
    # starting indices
    svec <- chooseSubsamples(nrow(e2), N, ns)
    # ending indices
    evec <- svec + N
  } else if (nrow(e2) > N) { # we can't do all of them but we will be able to do at least one
    # we can manage to do nrow(e2) div N
    svec <- chooseSubsamples(nrow(e2), N, nrow(e2) %/% ns)
    evec <- svec + N
  } else { # we can't do subsampling, so lets just plot the lot!
    svec <- 1
    evec <- nrow(e2)
  }
  # there should be very few (say 4) so it's ok to do a for loop... honest!
  for (i in 1:length(svec)) {
    # let's create a data.frame with the required info
    if (i==1) {
      adf <- data.frame(e2[svec[i]:evec[i],])
      adf$label <- svec[i]
    } else {
      tmp <- data.frame(e2[svec[i]:evec[i],])
      tmp$label <- svec[i]
      # not very memory efficient, but we'll optimize later
      adf <- rbind(adf, tmp)
    }
    # tmp <- adf[,1]
  }
  adf$label <- as.factor(adf$label)
  
  q <- qplot(adf[,1], adf[,2], xlab=names(adf)[1], ylab=names(adf)[2], colour=adf$label,
      xlim=range(e2[,1]), ylim=range(e2[,2]), geom=c('path', 'point')) +
    labs(colour='Starting Index')
  # print(q)
  q
}
# having a fit object in memory already I can just say
# saveRDS(fit, file='sample_banana_fit_object.rds')
# and later read it back in using...
# fit <- readRDS('sample_banana_fit_object.rds')
stanPathPlot(fit)


# lets just see what things look like in a LaTeX document
if (FALSE) {
  stopifnot(require(tikzDevice))
  # for marginfigures in a Tufte doc
  kTIKZ.width <- 2.5
  kTIKZ.height <- 2.5
  # for plain figures in a Tufte doc
  kTIKZ.big.width <- 4.0
  kTIKZ.big.height <- 2.8
  tikz('samplePathPlot.tex', width=kTIKZ.big.width, height=kTIKZ.big.height)
    print(stanPathPlot(fit))
  dev.off()
}

if (FALSE) {
  pdf('testing_Path_Plots.pdf', width=(297-20)/25.4, height=(210-20)/25.4)
  for (i in 1:25) {
    stanPathPlot(fit)
  }
  dev.off()
}

# here's an older dumber version
stanPathPlot.1 <- function(fit, whichpair=c(1,2), chaini=1, N=75, ns=4) {
  stopifnot(require(ggplot2))
  # ok... lets be sensible... these MUST be TRUE
  stopifnot(!is.null(fit))
  stopifnot(!is.null(whichpair))
  stopifnot(chaini >=1)
  stopifnot(N > 1)

  # need to set permuted as otherwise there will be a random order to the points in the chain!
  e1 <- extract(fit, permuted=FALSE) 
  eN <- min(N, nrow(e2)) # how many will we actually sample?
  e2 <- e1[,chaini,whichpair]
  eRangeMin <- sample(nrow(e2) - eN, 1)
  eRangeMax <- eRangeMin + eN
  e3 <- e2[c(eRangeMin:eRangeMax),]
  
  qplot(e3[,1], e3[,2], xlab=dimnames(e3)$parameters[1], ylab=dimnames(e3)$parameters[2],
      xlim=range(e2[,1]), ylim=range(e2[,2]), geom='path')
}
# stanPathPlot.1(fit)

# a small helper function to chose a set of sane subsamples for stanPathPlot()
# len - the length of the given chain - typically something like 2000
# N - the length of each subsample - defaults to 75 so we can see the paths
# ns - the number of subsamples - not too many otherwise it makes things hard to 
#
# error proofing and parameter sanity checking needs to be improved
#
# algorithm - not very clever for now... lets just brute force things for now
# and be clever later - this one creates a full set of possible numbers that 
# could be resampled and then after picking each N sized range - removes
# those that have already been sampled - and those that would given
# rise to overlaps
# NB. will temporarily allocate a set of ns integer vectors N-len in size
#
# it's important that we take *random* subsamples
#
# returns a 
chooseSubsamples <- function(len, N=75, ns=4, sDEBUG=FALSE) {
  # some basic sanity checks
  stopifnot(len >2) # lets not be silly!
  stopifnot(N > 1)
  stopifnot(ns >= 1)

  # for the purposes of development lets create some test code
  if (sDEBUG) {
    len <- 20
    N <- 4
    ns <- 3
  }

  # Rn is the full list of possible starting points that are allowed
  Rn <- 1:(len-N)
  starts <- vector(mode='integer', length=ns)
  for (i in 1:ns) { # i <- 1
    starts[i] <- sample(Rn, size=1)
    # now we need to remove these possibilities from Rn
    # but to avoid overlap we also need to remove the N before this too!
    # remember that we are working with indices and not the numbers themselves
    # so we need to do setdiffs NOT Rn[-c(1:3)] etc...
    minRmve <- max(1, starts[i]-N+1)
    maxRmve <- min(len, starts[i]+N-1)
    Rn <- setdiff(Rn, c(minRmve:maxRmve))
    if (sDEBUG) {
      cat(i, starts[i])
      print(Rn)
    }
  }
  sort(starts)
}
# chooseSubsamples(20, 4, 3) # for test purposes
# system.time( { chooseSubsamples(1000) } ) # not measurable at N=1000
# at N=1 million it takes about 0.3secs on this laptop 