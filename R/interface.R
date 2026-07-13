interfaceExample <- function(jaspResults, dataset, options) {
  # Just show the options as they are understood the R backend
  jaspResults[["explanation"]] <- createJaspHtml(title = "User inputs, returned as html",
                                                 text = sprintf("Here we show, for pedagogical purposes, the user inputs as they are understood by the R backend."))

  jaspResults[["logicals"]] <- createJaspHtml(
    title = "Logical controls",
    text = sprintf("The tick mark is set to: %s
                      The radio buttons are set to: %s",
                   as.character(options$my_tick_mark), # These variables are defined in .inst/qml/Interface.qml
                   as.character(options$radio_buttons)) # Notice we have to be careful with the data type
  )

  jaspResults[["others"]] <- createJaspHtml(
    title = "Other controls",
    text = sprintf("The chosen dropdown element is: %s
                      The slider value is: %s",
                   as.character(options$my_dropdown),
                   as.character(options$my_slider))
  )

  jaspResults[["keyboard"]] <- createJaspHtml(
    title = "Keyboard controls",
    text = sprintf("The integer is set to: %s
                      The double is set to: %s
                      The percentage is set to: %s
                      The confidence interval is set to: %s
                      The text box is set to: <i>%s</i>",
                   as.character(options$my_integer),
                   as.character(options$my_double),
                   as.character(options$my_percent),
                   as.character(options$my_ci),
                   options$my_text) # No data-type conversion needed for text
  )

  jaspResults[["developers"]] <- createJaspHtml(
    title = "Note for developers",
    text = sprintf("Potential developers will find it useful to inspect the following files:
                      <ul>
                          <li><a href='https://github.com/jasp-stats/jaspModuleTemplate/blob/master/inst/qml/Interface.qml'>./inst/qml/Interface.qml</a>: builds the menu on the left panel</li>
                          <li><a href='https://github.com/jasp-stats/jaspModuleTemplate/blob/master/R/examples.R'>./R/examples.R</a>: builds the output screen you are looking at</li>
                          <li><a href='https://github.com/jasp-stats/jaspModuleTemplate/blob/master/inst/Description.qml'>./inst/Description.qml</a>: adds access to the current submodule to the module icon on the ribbon above</li>
                      </ul>")
  )

  return()
}
