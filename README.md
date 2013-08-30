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

Feedback welcome.

To-Do
-----
* add some unit tests
* consider adding a density plot in the background
* consider doing only one chain on the density plot, but a longer
  chain than 50 points - which still seems a touch short.
* consider playing with line widths and removing the point geom.
* convert this to a CRAN upload-able package