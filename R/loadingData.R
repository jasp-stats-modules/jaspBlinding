processTable <- function(jaspResults, dataset, options) {

  # Auxiliary function.
  # Returns TRUE if and only if an option has been assigned in the GUI
  .isAssigned <- function(option) {
    not_assigned <- as.character(option) == ""
    return(!not_assigned)
  }

  # Only if everything has been assigned ...
  if(.isAssigned(options$ts) && .isAssigned(options$xs)) {
    # ... print the inputs as a table
    stats <- createJaspTable(gettext("Some descriptives"))
    stats$dependOn(c("ts", "xs")) # Declare dependencies to make the object disappear / reappear when needed

    stats$addColumnInfo(name = gettext("times"))
    stats$addColumnInfo(name = gettext("xs"))

    stats[["times"]] <- dataset[[options$ts]]
    stats[["xs"]] <- dataset[[options$xs]]

    jaspResults[["stats"]] <- stats
  } else {
    expl <- createJaspHtml(text = "Select times and positions")
    expl$dependOn(c("ts", "xs")) # Declare dependencies to make the object disappear / reappear when needed

    jaspResults[["Explanation"]] <- expl
  }

}
