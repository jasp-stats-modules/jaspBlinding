addOne <- function(jaspResults, dataset, options) {
  result <- as.character(options$my_number + 1) # options$my_number comes from the menu created by inst/qml/integer.qml

  jaspResults[["result"]] <- createJaspHtml(text = result,
                                            title = "This is your result:")

  return()
}
