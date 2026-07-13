# jaspBlinding -----------------------------------------------------------------
#
# Analysis blinding for JASP: wraps the R package `vazul` to provide masking
# and scrambling of analyst-visible variables during confirmatory data
# analysis (see MacCoun & Perlmutter, 2015). The aim is to reduce
# confirmation bias, p-hacking and HARKing by hiding test-relevant aspects
# of the data until the analysis pipeline is finalised.

`%||%` <- function(a, b) if (!is.null(a)) a else b

# analysisBlinding -------------------------------------------------------------
#
# Main entry point. The function name must match `func:` in
# inst/Description.qml (case-sensitive). The `state` environment persists
# across runs and is used to remember the last save path (jaspSyntheticData
# pattern).
analysisBlinding <- function(jaspResults, dataset, options, state, ...) {
  ready <- length(options$variablesToBlind) > 0L

  if (isTRUE(options$setSeed) && !is.null(options$seed))
    set.seed(as.integer(options$seed))

  blinded <- dataset
  vazulError <- NULL
  if (ready) {
    cols   <- options$variablesToBlind
    groups <- if (length(options$groupingVariables) > 0L) options$groupingVariables else NULL

    tryCatch({
      if (identical(options$blindingMethod, "masking")) {
        # Grouping does not apply to masking (design decision §6.5).
        # mask_variables only processes character/factor columns; v1.1.0
        # *errors* (rather than silently skipping) if a numeric column is in
        # the selection. Pre-filter to categorical columns so numeric ones
        # pass through unchanged, matching the documented intent and giving
        # a friendlier experience.
        isCat <- vapply(dataset[cols], function(x) is.character(x) || is.factor(x), logical(1))
        catCols <- cols[isCat]
        if (length(catCols) > 0L) {
          blinded <- .maskColumns(
            dataset, catCols,
            prefix       = options$maskPrefix %||% "masked_group_",
            across_vars  = isTRUE(options$sameMappingAcrossVariables)
          )
        }
      } else {
        # Build the scramble call so that `.groups` is truly omitted (not
        # passed as NULL): vazul's resolve_group_columns() checks the
        # *expression* of .groups via rlang::quo_is_null(), so passing a
        # variable bound to NULL (e.g. .groups = groups) is *not* the same
        # as omitting the argument and triggers "No columns selected for
        # grouping.". Using do.call with a named list lets us drop .groups
        # entirely when there are no grouping variables.
        # Scrambling mode precedence (design decision §6.4):
        #   .byrow wins over .together (and .groups is ignored when byrow).
        scrambleArgs <- list(data = dataset, cols = cols)
        if (isTRUE(options$byRow)) {
          scrambleArgs$.byrow <- TRUE
        } else {
          if (isTRUE(options$keepRowsTogether)) scrambleArgs$.together <- TRUE
          if (length(groups) > 0L)             scrambleArgs$.groups <- groups
        }
        blinded <- do.call(scramble_variables, scrambleArgs)
      }
    }, error = function(e) {
      vazulError <<- conditionMessage(e)
    })
  }

  .blindingTable(jaspResults, blinded, options, ready)
  if (ready && is.null(vazulError))
    .blindingSave(jaspResults, blinded, options, state)

  if (!is.null(vazulError)) {
    jaspResults[["blindingError"]] <- createJaspHtml(
      title = gettext("Blinding error"),
      text  = paste(gettext("The blinding operation failed:"), vazulError)
    )
  }
}

# .maskColumns ----------------------------------------------------------------
#
# Masks categorical columns using vazul::mask_labels with a user-specified
# prefix. vazul::mask_variables (v1.1.0) has no `prefix` argument, so this
# helper calls mask_labels directly.
#
# - across_vars = FALSE: each column is masked independently (each gets its
#   own prefix_01, prefix_02, ... assignment).
# - across_vars = TRUE:  one shared mapping is created from all unique values
#   across all selected columns, so the same original value gets the same
#   masked label regardless of which column it appears in.
.maskColumns <- function(data, cols, prefix = "masked_group_", across_vars = FALSE) {
  if (!is.character(prefix) || length(prefix) != 1L || !nzchar(prefix))
    prefix <- "masked_group_"

  result <- data

  if (across_vars) {
    # Build one shared mapping from all unique values across selected columns.
    allValues <- unique(unlist(lapply(result[cols], function(x) {
      if (is.factor(x)) as.character(x) else x
    }), use.names = FALSE))
    allValues <- allValues[!is.na(allValues)]
    if (length(allValues) > 0L) {
      masked <- mask_labels(allValues, prefix = prefix)
      mapping <- setNames(masked, allValues)
      result[cols] <- lapply(result[cols], function(x) {
        chars <- if (is.factor(x)) as.character(x) else x
        mapped <- ifelse(is.na(chars), NA_character_, mapping[chars])
        if (is.factor(x)) factor(mapped, levels = unique(mapped)) else mapped
      })
    }
  } else {
    # Independent masking per column.
    result[cols] <- lapply(result[cols], function(x) {
      isFac <- is.factor(x)
      chars <- if (isFac) as.character(x) else x
      if (all(is.na(chars))) return(x)
      masked <- mask_labels(chars, prefix = prefix)
      if (isFac) factor(masked, levels = unique(masked)) else masked
    })
  }

  result
}

# .blindingTable ---------------------------------------------------------------
#
# Renders the (possibly blinded) dataset as a JASP table. The table is always
# attached so the user sees the dataset preview even when `ready == FALSE`;
# it is only filled once `ready == TRUE`. Column names are kept encoded --
# JASP auto-decodes them for display (R guide §column-name encoding).
.blindingTable <- function(jaspResults, data, options, ready) {
  tbl <- createJaspTable(title = gettext("Blinded data"))
  tbl$dependOn(c("variablesToBlind", "groupingVariables", "blindingMethod",
               "keepRowsTogether", "byRow", "sameMappingAcrossVariables",
               "maskPrefix", "setSeed", "seed",
               "showBlindedData", "rowsToShow"))
  tbl$showSpecifiedColumnsOnly <- TRUE

  # Always use string columns so JASP displays the literal values (e.g.
  # masked_group_01) instead of interpreting factors/numerics and showing
  # integer codes.
  if (!is.null(data) && length(names(data)) > 0L) {
    for (col in names(data))
      tbl$addColumnInfo(name = col, title = col, type = "string")
  }

  jaspResults[["blindedTable"]] <- tbl
  if (!ready) return()

  # Limit the displayed preview when requested; the full dataset is always
  # exported to CSV regardless of this setting.
  displayData <- data
  if (isTRUE(options$showBlindedData)) {
    nShow <- suppressWarnings(as.integer(options$rowsToShow)[1L])
    if (is.na(nShow) || nShow < 1L) nShow <- 50L
    if (nrow(displayData) > nShow) displayData <- utils::head(displayData, nShow)
  }

  tbl$setExpectedSize(nrow(displayData))
  for (col in names(displayData))
    tbl[[col]] <- as.character(displayData[[col]])
}

# .blindingSave ----------------------------------------------------------------
#
# Exports the blinded dataset to CSV. Mirrors the jaspSyntheticData pattern:
# no checkbox gate -- a non-empty path in options$fileFull is the trigger.
# The path is sanitised (file:// URIs, Windows drive letters, URL-encoded
# characters) and the write is wrapped in tryCatch; on failure an error
# block is attached rather than aborting the analysis.
.blindingSave <- function(jaspResults, data, options, state) {
  if (missing(state) || is.null(state) || !is.environment(state))
    state <- new.env(parent = emptyenv())

  # Strip file:// prefixes, Windows /C: artefacts, and URL-encoding that the
  # save dialog may inject.
  sanitizeExportPath <- function(path) {
    clean <- path
    clean <- sub("^file://localhost", "", clean)
    if (startsWith(clean, "file://")) {
      clean <- substring(clean, nchar("file://") + 1L)
    } else if (startsWith(clean, "file:/")) {
      clean <- substring(clean, nchar("file:/") + 1L)
    }
    if (.Platform$OS.type == "windows" && grepl("^/[A-Za-z]:", clean))
      clean <- substring(clean, 2L)
    clean <- utils::URLdecode(clean)
    normalizePath(clean, winslash = "/", mustWork = FALSE)
  }

  exportPath <- trimws(options$fileFull %||% state$fileFull %||% "")
  if (!nzchar(exportPath)) return()

  exportPath <- sanitizeExportPath(exportPath)
  state$fileFull     <- exportPath
  state$lastSavePath <- exportPath

  exportError <- NULL
  tryCatch({
    exportDir <- dirname(exportPath)
    if (nzchar(exportDir) && !dir.exists(exportDir))
      dir.create(exportDir, recursive = TRUE, showWarnings = FALSE)
    out <- data
    # Decode encoded column names to human-readable CSV headers.
    decodedNames <- tryCatch(
      decodeColNames(names(out)),
      error = function(e) names(out)
    )
    names(out) <- decodedNames
    utils::write.csv(out, file = exportPath, row.names = FALSE)
  }, error = function(e) {
    exportError <<- conditionMessage(e)
  })

  if (!is.null(exportError)) {
    jaspResults[["blindingExportError"]] <- createJaspHtml(
      title = gettext("Export error"),
      text  = paste(gettext("Failed to save blinded data:"), exportError)
    )
  }
}
