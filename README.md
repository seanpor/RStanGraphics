RStanGraphics
=============

Some snippets of code for GGplot2 graphics for RStan.

In particular there is one function stanPathPlot(fit) which takes an RStan
fit object and takes four (default) sub-samples of N=50 (default) consecutive
points from the first chain (default) of the fit object and plots these
sub-samples in different colours.  The legend shows the index numbers of the 
different starting points of the sub-samples.  The xlim, ylim of the plot is
set to the output range of the entire chain from the fit object.

It requires a helper function chooseSubsamples() which will pick the
sub-samples in a random fashion without overlap.

Currently the stanPathPlot function are works for well behaved fit objects,
but it should be more thoroughly exercised for less well behaved fit objects.

The R code is in the file stanGgplot.R
sample_banana_fit_object.rds contains a sample fit object 
samplePathPlot.tex contains the tikz() output from the sample fit object above.

NB. requires the libraries ggplot2 and rstan

To test this, just say something like:

```R
source('stanGgplot.R');
fit <- readRDS('sample_banana_fit_object.rds')
stanPathPlot(fit)
```

The file parsediagnostic.R contains a first cut at reading a Stan
diagnostic file and converting it into an R usable form.
It contains a list of params, e.g. the stuff at the top of the diagnostic
file like stepsize, adapt_gamma and the other "parameters" like
the diagonal elements of the inverse mass matrix and the time taken to 
run this chain.

Constructive feedback welcome.


To-Do
-----
* add some unit tests
* consider adding a density plot in the background
* consider doing only one chain on the density plot, but a longer
  chain than 50 points - which still seems a touch short.
* consider playing with line widths and removing the point geom.
* convert this to a CRAN upload-able package
* add margin plots
* create a pairs plot with margins on the diagonal, and stanPathPlot()
  above the diagonal and plain densities below the diagonal.
