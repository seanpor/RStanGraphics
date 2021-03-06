# an R parser for a Stan diagnostic file which can be created from the 
# rstan interface stan() by using the parameter diagnostic_file='diagnostic_file'
# with a suitable filename prefix - which will get transformed into files like
# diagnostic_file.dat_1.csv 

# this might seem a slow way to do things but the median time on
# my laptop to process the list of 23 items in the Stan diagnostic file is 
# only 42 nanoseconds... which I think is extraordinarily fast!
#
# take a string array of items which look like
# c("A=B", "C=D", "E=F") and convert it into a list
# so it can be accessed like lst[[A] etc...
# or even lst$A
namepairStringToList <- function(lst, convertNumerics=TRUE) {
  p2 <- list()
  for (i in 1:length(lst)) {
    lhs <- gsub('=.*$', '', lst[[i]])
    rhs <- gsub('^.*=', '', lst[[i]])
    if (convertNumerics) {
      pow <- options(warn=-1) # temporarily turn off ALL warnings
      tmp2 <- try(tmp <- as.numeric(rhs), silent=TRUE)
      if(!inherits(tmp2, 'try-error') && !is.na(tmp2)) {
        rhs <- tmp2
      }
      options(pow) # reset the warnings level to what it was before
    }
    p2[[lhs]] <- rhs
  }
  p2
}
# debug(namepairStringToList)
# tstPL <- namepairStringToList(params.txt)
# tstPL2 <- namepairStringToList(params.txt, convertNumerics=TRUE)

# and how do I know it takes 42ns on "average"... well I benchmarked it!
# nb the median result is the same for both with/without convertNumerics!!!
if (FALSE) {
  params.txt <- c("stan_version_major=2", "stan_version_minor=0",
      "stan_version_patch=1", "init=random", "seed=232898634",
      "chain_id=1", "iter=1000", "warmup=500", "save_warmup=1",
      "thin=1", "refresh=100", "stepsize=1", "stepsize_jitter=0",
      "adapt_engaged=1", "adapt_gamma=0.05", "adapt_delta=0.65",
      "adapt_kappa=0.75", "adapt_t0=10", "max_treedepth=10",
      "sampler_t=NUTS(diag_e)", "diagnostic_file=./diagnostic_file.dat_1.csv",
      "append_samples=0")
  f1 <- function() namepairStringToList(params.txt)
  f2 <- function() namepairStringToList(params.txt, convertNumerics=TRUE)
  library(microbenchmark)
  res <- microbenchmark(f1, f2)
  res
  plot(res, log='y')
}


# This is the main function for parsing
# the diagnostic files from Stan and it takes a single file name
# and parses that file and returns a data structure containing
# the parameter information and a data.frame
# with the diagnostic info
parsediagnostic <- function(fnam) {
  # TODO need some asserts here...
  # first is this a file
  # with non-zero length

  # now lets grab the entire file into memory and we'll manipulate it there...
  # might need to add warn=FALSE depending on the stucture of the files
  txt <- readLines(fnam)

  # now lets pull the lines which start with a # 'cause mostly that's where 
  # the parameters are
  hlines.l <- grep('^# ', txt)
  hlines <- txt[hlines.l]
  # did this in two steps so we can see where the breaks are...
  # i.e. a abs(diff()) > 1
  wh <- which(diff(hlines.l) > 1)
  # grab the parameters
  # first the lines they're on
  params.txt <- txt[1:hlines.l[wh[[1]]]]
  # strip off the "# " at the start of the line
  params.txt <- gsub('^# ', '', params.txt)
  # the first of these probably says "Samples Generated by Stan"
  # if so we can remove it...
  if (params.txt[[1]] == "Samples Generated by Stan") {
    params.txt <- params.txt[-1]
  }
  # now we have a bunch of about 22 lines which look something like
  # "stan_version_patch=1"
  # i.e. with an "=" in the middle...
  # these need to be converted into a list...
  retlist <- namepairStringToList(params.txt, convertNumerics=TRUE)

  # pull the adaption samples
  atxt <- txt[(hlines.l[[wh[[1]]]]+2):(hlines.l[[wh[[1]]+1]]-1)]
  acsv <- read.csv(textConnection(atxt), stringsAsFactor=FALSE)
  # note that these are the adaption phase
  acsv$mode <- 'Adaption'
  s1 <- hlines.l[[wh[[1]]+1]]+4
  s2 <- hlines.l[wh[2]+1]-1
  stxt <- txt[s1:s2]
  # but add the header
  stxt <- c(atxt[[1]], stxt)
  scsv <- read.csv(textConnection(stxt), stringsAsFactor=FALSE)
  # note that this is the sampling phase
  scsv$mode <- 'Sampling'
  # make both the adaption and samplind details into one data.frame
  retcsv <- rbind(acsv, scsv)
  retcsv$mode <- as.factor(retcsv$mode)

  # Stepsize is a special case and found in the middle of the diagnostic file
  ss.txt <- txt[[grep('# Step size =', txt)]] # pull the relevant line
  ss.txt <- gsub('^# ', '', ss.txt) # remove leading "# "
  ss.txt <- gsub(' ', '', ss.txt) # remove spaces...
  retlist <- c(retlist, namepairStringToList(ss.txt, convertNumerics=TRUE))
  
  # that's all well and good... but we also need the Diagonal elements of the
  # inverse mass matrix...
  imm.l <- grep('^# Diagonal elements of inverse mass matrix', txt) + 1
  tmp <- txt[imm.l] # but this is in text form... and looks something like
  # "# 1.14485, 1.6325"
  # strip the leading '# '
  tmp <- gsub('^# ', '', tmp)
  # split out and convert to numeric
  retlist$diag.inverse.mass.matrix <- as.numeric(unlist(strsplit(tmp, ', ')))

  # and don't forget the times at the end of the diagnostic file
  et.l <- grep('^# Elapsed Time:', txt)
  # first warmup...
  tmp <- gsub('^.*: ', '', txt[[et.l]])
  tmp <- gsub(' seconds.*$', '', tmp)
  retlist$warmup.time <- as.numeric(tmp)
  # now the sampling time
  tmp <- gsub('^#  *', '', txt[[et.l+1]])
  tmp <- gsub(' seconds.*$', '', tmp)
  retlist$sampling.time <- as.numeric(tmp)
  # and finally the total time
  tmp <- gsub('^#  *', '', txt[[et.l+2]])
  tmp <- gsub(' seconds.*$', '', tmp)
  retlist$total.time <- as.numeric(tmp)


  list(params=retlist, diags=data.frame(retcsv))
}

test.parsediagnostic <- function(fnam) {
  if (is.null(fnam)) { # assume my own dev tree
    fnam1 <- dir(path='./visual-diagnostics-master/',
                 pattern='^diagnostic_file.dat.*$', full=TRUE)[[1]]
  } else {
    fnam1 <- fnam
    # should test for existance here
  }
  # should really give a more sane message...
  stopifnot(nchar(fnam1) > 0) # does it contain a string with length > 0?

  # debug(parsediagnostic)
  tres <- parsediagnostic(fnam1)
  stopifnot(require(ggplot2))

  # alpha, beta is specific to this problem
  q <- qplot(as.ordered(treedepth__), alpha, data=tres$diags, geom='violin',
        xlab='Tree depth', colour=mode) 
  print(q)
  q <- qplot(stepsize__, alpha, data=tres$diags, xlab='Step Size',
             log='x', colour=mode) 
  print(q)

  
  q <- qplot(as.ordered(treedepth__), beta, data=tres$diags, geom='violin',
        xlab='Tree depth', colour=mode) 
  print(q)

  q <- qplot(stepsize__, beta, data=tres$diags, xlab='Step Size', log='x',
             colour=mode) 
  print(q)

  # generic type plots...

  # histogram of Tree Depth
  q <- qplot(ordered(treedepth__), data=tres$diags, geom='histogram',
        xlab='Tree depth')
  print(q)

  # where is the mass of stepsize wrt treedepth - violin plot
  q <- qplot(as.ordered(treedepth__), stepsize__, data=tres$diags, geom='violin',
        xlab='Tree depth') # , colour=mode)
  print(q)

  # so how did tree depth move as the chain progressed?
  q <- qplot(1:nrow(tres$diags), treedepth__, data=tres$diags, xlab='Iteration',
        ylab='Tree depth', geom='line', colour=mode)
  print(q)

  # so how did stepsize move as the chain progressed?
  q <- qplot(1:nrow(tres$diags), stepsize__, data=tres$diags, xlab='Iteration',
        geom='line', colour=mode, log='y')
  print(q)


  # for the record plotting an ACF is done in ggplot2 like
  # http://stackoverflow.com/questions/17788859/acf-plot-with-ggplot2-setting-width-of-geom-bar
  if (FALSE) {
    library(ggplot2)
    set.seed(123)
    x <- arima.sim(n = 200, model = list(ar = 0.6))
    bacf <- acf(x, plot = FALSE)
    bacfdf <- with(bacf, data.frame(lag, acf))

    q <- ggplot(data = bacfdf, mapping = aes(x = lag, y = acf)) +
           geom_hline(aes(yintercept = 0)) +
                  geom_segment(mapping = aes(xend = lag, yend = 0))
    print(q)
  }
}
