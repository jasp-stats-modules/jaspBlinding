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
  ready <- length(options$variablesToBlind) > 0L || .hasMaskNamesGroups(options)

  if (isTRUE(options$setSeed) && !is.null(options$seed))
    set.seed(as.integer(options$seed))

  isDecoy <- identical(options$blindingMethod, "decoy")
  blinded <- dataset
  decoyDatasets <- NULL

  if (ready) {
    cols   <- options$variablesToBlind %||% character(0)
    groups <- if (length(options$groupingVariables) > 0L) options$groupingVariables else NULL

    if (length(cols) > 0L && !isDecoy) {
      if (identical(options$blindingMethod, "masking")) {
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
        scrambleArgs <- list(data = dataset, cols = cols)
        if (isTRUE(options$byRow)) {
          scrambleArgs$.byrow <- TRUE
        } else {
          if (isTRUE(options$keepRowsTogether)) scrambleArgs$.together <- TRUE
          if (length(groups) > 0L)             scrambleArgs$.groups <- groups
        }
        blinded <- do.call(scramble_variables, scrambleArgs)
      }
    }

    if (isDecoy && length(cols) > 0L) {
      decoyDatasets <- .decoyBlind(dataset, cols, options)
    }

    # Apply mask_names on top of any value-level method (or on its own).
    if (.hasMaskNamesGroups(options)) {
      if (isDecoy && !is.null(decoyDatasets)) {
        decoyDatasets <- lapply(decoyDatasets, .applyMaskNames, options)
      } else {
        blinded <- .applyMaskNames(blinded, options)
      }
    }
  }

  if (isDecoy) {
    # Clear non-decoy results from a previous run
    jaspResults[["blindedTable"]]      <- NULL
    jaspResults[["blindingExportError"]] <- NULL

    if (ready && !is.null(decoyDatasets) && length(decoyDatasets) > 0L) {
      .decoySummary(jaspResults, decoyDatasets, options)
      .decoySave(jaspResults, decoyDatasets, options, state)
    } else {
      .decoySummary(jaspResults, NULL, options)
    }
  } else {
    # Clear decoy results from a previous run
    jaspResults[["decoySummary"]]      <- NULL
    jaspResults[["decoyExportOk"]]     <- NULL
    jaspResults[["blindingExportError"]] <- NULL

    .blindingTable(jaspResults, blinded, options, ready)
    if (ready)
      .blindingSave(jaspResults, blinded, options, state)
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

# .hasMaskNamesGroups ---------------------------------------------------------
# Checks whether the user has defined any mask_names groups with variables.
.hasMaskNamesGroups <- function(options) {
  groups <- options$maskNamesGroups
  if (is.null(groups) || length(groups) == 0L) return(FALSE)
  any(vapply(groups, function(g) {
    vars <- g$variables
    !is.null(vars) && length(vars) > 0L &&
      any(nzchar(trimws(vapply(vars, function(v) v$variable %||% "", character(1)))))
  }, logical(1)))
}

# .applyMaskNames -------------------------------------------------------------
# Applies mask_names for each group defined in the mask variable names section.
# Each group has a prefix and a list of variables. Groups are applied in order,
# chained via piping (as recommended by the vazul docs).
.applyMaskNames <- function(data, options) {
  groups <- options$maskNamesGroups
  if (is.null(groups) || length(groups) == 0L) return(data)

  for (g in groups) {
    prefix <- g$prefix %||% "group_"
    if (!is.character(prefix) || !nzchar(trimws(prefix))) prefix <- "group_"

    vars <- vapply(g$variables, function(v) v$variable %||% "", character(1))
    vars <- trimws(vars)
    vars <- vars[nzchar(vars)]
    if (length(vars) == 0L) next

    data <- mask_names(data, vars, prefix = prefix)
  }

  data
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
               "showBlindedData", "rowsToShow", "maskNamesGroups"))
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
  } else {
    # Clear any stale error block from a previous run
    if (!is.null(jaspResults[["blindingExportError"]]))
      jaspResults[["blindingExportError"]] <- NULL
  }
}

# .decoyBlind -----------------------------------------------------------------
#
# Calls maskClusters() to generate simulated datasets with an imposed
# cluster structure. The function is bundled from the OSF supplementary
# code of the network analysis blinding tutorial (Sekulovski et al.).
# Returns a list of data.frames.
.decoyBlind <- function(dataset, cols, options) {
  dataSubset <- dataset[, cols, drop = FALSE]

  if (ncol(dataSubset) < 2L)
    stop(gettext("Decoy data requires at least 2 variables. Clustering is not meaningful for a single variable."))

  rep        <- as.integer(options$decoyRep %||% 5L)
  if (is.na(rep) || rep < 1L) rep <- 5L

  noClusters <- as.integer(options$decoyNoClusters %||% 0L)
  if (is.na(noClusters) || noClusters < 1L) {
    noClusters <- NULL
  } else if (noClusters > ncol(dataSubset)) {
    stop(gettextf("Number of clusters (%d) cannot exceed the number of variables (%d).",
                  noClusters, ncol(dataSubset)))
  }

  diagProb    <- options$decoyDiagProb %||% 0.75
  offDiagProb <- options$decoyOffDiagProb %||% 0.175
  # 0.75 / 0.175 are sentinel defaults that signal "use random draw".
  # Only pass the values through if the user changed them.
  useDefaultDiag    <- isTRUE(all.equal(as.numeric(diagProb), 0.75))
  useDefaultOffDiag <- isTRUE(all.equal(as.numeric(offDiagProb), 0.175))

  args <- list(
    data              = dataSubset,
    rep               = rep,
    no_clusters       = noClusters,
    insert_true_data  = isTRUE(options$decoyInsertTrueData),
    seed              = if (isTRUE(options$setSeed)) as.integer(options$seed) else NULL
  )
  if (!useDefaultDiag)     args$diag_prob     <- as.numeric(diagProb)
  if (!useDefaultOffDiag)  args$off_diag_prob <- as.numeric(offDiagProb)

  if (isTRUE(options$decoySubsetData)) {
    rowIdx <- .parseIndices(options$decoyRowIndices)
    if (length(rowIdx) > 0L) {
      args$subset_data      <- TRUE
      args$variable_indices <- seq_len(ncol(dataSubset))
      args$row_indices      <- rowIdx
    }
  }

  result <- do.call(maskClusters, args)
  if (is.null(result) || length(result) == 0L)
    stop(gettext("maskClusters returned no datasets. Possible causes: (1) the selected variables have mixed measurement levels (e.g., a combination of continuous and ordinal) — all variables must be either all continuous or all ordinal/binary; or (2) the data is numerically problematic (e.g., extreme values, zero variance, or perfect collinearity) preventing simulation."))
  result
}

# .parseIndices ----------------------------------------------------------------
# Parse a comma-separated index string like "1,3,5" or "1-10,20" into an
# integer vector.
.parseIndices <- function(text) {
  if (is.null(text) || !nzchar(trimws(text))) return(integer(0))
  parts <- trimws(strsplit(text, ",")[[1]])
  out <- integer(0)
  for (p in parts) {
    if (grepl("^-?\\d+-\\d+$", p)) {
      rng <- as.integer(strsplit(p, "-")[[1]])
      out <- c(out, seq(rng[1], rng[2]))
    } else {
      val <- suppressWarnings(as.integer(p))
      if (!is.na(val)) out <- c(out, val)
    }
  }
  out[out > 0L]
}

# .decoySummary ----------------------------------------------------------------
# Shows a brief text summary instead of a data table (the analyst should
# not examine the data in JASP; they export the files and work elsewhere).
.decoySummary <- function(jaspResults, decoyDatasets, options) {
  if (is.null(decoyDatasets) || length(decoyDatasets) == 0L) {
    jaspResults[["decoySummary"]] <- createJaspHtml(
      title = gettext("Decoy data"),
      text  = gettext("No datasets generated. Select variables and set options, then re-run.")
    )
    return()
  }

  n    <- length(decoyDatasets)
  dims <- vapply(decoyDatasets, function(d) paste0(nrow(d), " x ", ncol(d)), character(1))
  text <- paste0(
    n, " dataset", if (n == 1L) "" else "s", " generated.\n\n",
    paste(seq_len(n), ". ", dims, sep = "", collapse = "\n"),
    "\n\nUse \"Save blinded data\" to export each dataset as a separate CSV file."
  )
  jaspResults[["decoySummary"]] <- createJaspHtml(
    title = gettext("Decoy data"),
    text  = text
  )
}

# .decoySave -------------------------------------------------------------------
# Exports each simulated dataset as a separate numbered CSV. The base path
# comes from options$fileFull; files are named by inserting _1, _2, ... before
# the extension.
.decoySave <- function(jaspResults, decoyDatasets, options, state) {
  if (missing(state) || is.null(state) || !is.environment(state))
    state <- new.env(parent = emptyenv())

  basePath <- trimws(options$fileFull %||% state$fileFull %||% "")
  if (!nzchar(basePath)) return()

  # Strip file:// and normalise (shared logic with .blindingSave)
  basePath <- sub("^file://localhost", "", basePath)
  if (startsWith(basePath, "file://")) {
    basePath <- substring(basePath, nchar("file://") + 1L)
  } else if (startsWith(basePath, "file:/")) {
    basePath <- substring(basePath, nchar("file:/") + 1L)
  }
  if (.Platform$OS.type == "windows" && grepl("^/[A-Za-z]:", basePath))
    basePath <- substring(basePath, 2L)
  basePath <- utils::URLdecode(basePath)
  basePath <- normalizePath(basePath, winslash = "/", mustWork = FALSE)

  state$fileFull     <- basePath
  state$lastSavePath <- basePath

  # Split into dir / base / ext
  exportDir  <- dirname(basePath)
  baseName   <- basename(basePath)
  ext        <- tools::file_ext(baseName)
  stem       <- if (nzchar(ext)) sub(paste0("\\.", ext, "$"), "", baseName) else baseName
  if (nzchar(ext)) ext <- paste0(".", ext) else ext <- ".csv"

  if (nzchar(exportDir) && !dir.exists(exportDir))
    dir.create(exportDir, recursive = TRUE, showWarnings = FALSE)

  exportError <- NULL
  written     <- character(0)
  tryCatch({
    nTotal <- length(decoyDatasets)
    width  <- nchar(as.character(nTotal))
    for (i in seq_len(nTotal)) {
      fileName <- sprintf(paste0("%s_%0", width, "d%s"), stem, i, ext)
      filePath <- file.path(exportDir, fileName)
      out <- decoyDatasets[[i]]
      decodedNames <- tryCatch(decodeColNames(names(out)), error = function(e) names(out))
      names(out) <- decodedNames
      utils::write.csv(out, file = filePath, row.names = FALSE)
      written <- c(written, fileName)
    }
  }, error = function(e) {
    exportError <<- conditionMessage(e)
  })

  if (!is.null(exportError)) {
    jaspResults[["blindingExportError"]] <- createJaspHtml(
      title = gettext("Export error"),
      text  = paste(gettext("Failed to save decoy datasets:"), exportError)
    )
    if (!is.null(jaspResults[["decoyExportOk"]]))
      jaspResults[["decoyExportOk"]] <- NULL
  } else {
    jaspResults[["decoyExportOk"]] <- createJaspHtml(
      title = gettext("Export complete"),
      text  = paste0(length(written), " files written to:\n", paste("  ", file.path(exportDir, written), collapse = "\n"))
    )
    if (!is.null(jaspResults[["blindingExportError"]]))
      jaspResults[["blindingExportError"]] <- NULL
  }
}
