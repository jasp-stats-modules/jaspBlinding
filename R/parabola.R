parabola <- function(jaspResults, dataset, options) {
  # Analysis
  f <- function(x) { options$a * x^2 } # Function to be plotted
  p <- ggplot2::ggplot() +             # Plotting command
    ggplot2::xlim(-3, 3) +
    ggplot2::ylim(0, 10) +
    ggplot2::geom_function(fun = f)
  # add jasp theme
  p <- p + jaspGraphs::geom_rangeframe() +
           jaspGraphs::themeJaspRaw()
  # Aesthetics
  parabolaPlot <- createJaspPlot(title = gettext("Parabola"),
                                 width = 160,
                                 height = 320)
  parabolaPlot$dependOn(c("a")) # Refresh view whenever a changes
  parabolaPlot$info <- gettext("This figure displays a parabola specified via the `a` option.")
  jaspResults[["parabolaPlot"]] <- parabolaPlot
  parabolaPlot$plotObject <- p

  return()
}
