# -----------------------------------------------------------
# -----------------------------------------------------------
# -------- Ilustration 3: Clustering  -----------------------
# -----------------------------------------------------------
# -----------------------------------------------------------

# Author: N Sekulovski
# Email: n.sekulovski@uva.nl
# Last Edited: 2025-10-16

# The function `maskClusters()` generates simulated datasets 
# that mimic the structure of an original dataset while imposing a 
# user-specified clustering pattern. 
# This blinding protocol is intended for research questions focused 
# on network clustering.

# -------------------------------------------------------------------
# ARGUMENTS
# -------------------------------------------------------------------
# Required:
# - data: the empirical dataset (data.frame or matrix)

# Optional:
# - rep: number of simulated datasets to generate (default: 5)
# - subset_data: whether to subset before simulation (default: FALSE)
# - variable_indices: column indices for simulation when 
#                     `subset_data = TRUE` (default: NULL)
# - row_indices: row indices for simulation when `subset_data = TRUE` 
#                (default: NULL)
# - no_clusters: number of clusters per simulation (integer or vector)
#                default: random integer between 1 and number of variables
# - diag_prob: within-cluster edge probability (default: random 0.6–0.9)
# - off_diag_prob: between-cluster edge probability (default: random 0.05–0.3)
# - insert_true_data: whether to include the original dataset at a random 
#                     position in the output list (default: FALSE)
# - seed: integer seed for reproducibility (default: NULL)
# - ...: additional arguments passed to underlying simulation functions

# -------------------------------------------------------------------
# OUTPUT
# -------------------------------------------------------------------
# Returns a list of simulated datasets (length = `rep`, plus one if 
# `insert_true_data = TRUE`). 
# Each element is a data.frame mirroring the original structure and 
# missingness pattern, with network topology imposed according to the 
# specified clustering.

maskClusters <- function(
    data,
    rep = 5,
    subset_data = FALSE,
    variable_indices = NULL,
    row_indices = NULL,
    no_clusters = NULL,
    diag_prob = NULL,
    off_diag_prob = NULL,
    insert_true_data = FALSE,
    seed = NULL,
    ...
) {
  # Check required packages
  required_packages <- list(
    "bgms" = "install.packages('bgms')",
    "MASS" = "install.packages('MASS')",
    "PseudoMLE" = "devtools::install_github('sekulovskin/PseudoMLE')"
  )

  missing_packages <- character(0)
  for (pkg in names(required_packages)) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      missing_packages <- c(missing_packages, pkg)
    }
  }

  if (length(missing_packages) > 0) {
    install_commands <- sapply(missing_packages, function(pkg) required_packages[[pkg]])
    message("Missing required packages: ", paste(missing_packages, collapse = ", "))
    message("Please install them using:")
    for (i in seq_along(install_commands)) {
      message("  ", install_commands[i])
    }
    if ("PseudoMLE" %in% missing_packages) {
      message("Note: For PseudoMLE, you may also need to install devtools first: install.packages('devtools')")
    }
    return(NULL)
  }

  # Input validation
  if (!is.data.frame(data) && !is.matrix(data)) {
    stop("data must be a data.frame or matrix")
  }
  if (rep < 1 || !is.numeric(rep)) {
    stop("rep must be a positive integer")
  }

  # Validate subsetting arguments
  if (subset_data) {
    if (is.null(variable_indices) || is.null(row_indices)) {
      stop("When subset_data = TRUE, both variable_indices and row_indices must be provided")
    }
    if (any(variable_indices < 1) || any(variable_indices > ncol(data))) {
      stop("variable_indices must be valid column indices")
    }
    if (any(row_indices < 1) || any(row_indices > nrow(data))) {
      stop("row_indices must be valid row indices")
    }
  }

  if (!is.null(seed)) {
    set.seed(seed)  # Set seed for reproducibility
  }

  # Store original dataset for potential embedding
  original_data <- data

  # Subset data if requested
  if (subset_data) {
    data_subset <- data[row_indices, variable_indices, drop = FALSE]
    message("Data subset created: ", nrow(data_subset), " rows x ", ncol(data_subset), " columns")
  } else {
    data_subset <- data
  }

  p <- ncol(data_subset)
  n <- nrow(data_subset)

  # Initialize result lists
  sim_datasets <- vector("list", rep)

  # Measurement level detection
  measurement_levels <- sapply(data_subset, guess_measurement_level)

  # Cluster and edge probability setup with better defaults
  if (is.null(no_clusters)) {
    # if number of clusters is not supplied
    max_clusters <- p # the maximum number of clusters is p
    no_clusters <- sample(1:max_clusters, rep, replace = TRUE)
  } else if (length(no_clusters) == 1) {
    no_clusters <- rep(no_clusters, rep)
  } else if (length(no_clusters) != rep) {
    stop("no_clusters must be NULL, a single value, or a vector of length rep")
  }
  # print the no_clusters used
  message("Using no_clusters: ", paste(no_clusters, collapse = ", "))
  # Set default probabilities if not provided
  if (is.null(diag_prob)) diag_prob <- stats::runif(1, 0.6, 0.9)
  if (is.null(off_diag_prob)) off_diag_prob <- stats::runif(1, 0.05, 0.3)

  # Validate probabilities
  if (diag_prob <= off_diag_prob) {
    warning("diag_prob should be greater than off_diag_prob for meaningful clustering")
  }

  # Determine data type
  all_discrete <- all(measurement_levels %in% c("Binary", "Ordinal"))
  all_interval <- all(measurement_levels == "Interval")

  if (!all_discrete && !all_interval) {
    warning("Mixed measurement levels detected. This function only supports all-discrete (binary and/or ordinal) or all-interval cases.")
    return(NULL)
  }

  # Generate adjacency matrices with clustering structure
  adj_matrices <- vector("list", rep)
  for (i in 1:rep) {
    adj_matrices[[i]] <- generate_planted_partition(
      no_variables = p,
      no_clusters = no_clusters[i],
      diag_prob = diag_prob,
      off_diag_prob = off_diag_prob,
      balanced = TRUE
    )
  }

  # Simulate datasets based on data type
  if (all_discrete) {
    # Get number of categories for each variable
    no_categories <- apply(data_subset, 2, function(x) {
      length(unique(x[!is.na(x)])) - 1  # Exclude NAs from category counting
    })

    for (i in 1:rep) {
      tryCatch({
        # Estimate parameters from subset data
        mples <- PseudoMLE::mple_G(x = as.matrix(data_subset), G = adj_matrices[[i]], ...)

        # Generate simulated data
        sim_data <- bgms::simulate_mrf(
          num_states = n,
          num_variables = p,
          num_categories = no_categories,
          pairwise = mples$interactions,
          main = mples$thresholds,
          ...
        )
        
        # Ensure proper coding (convert from 0-based to 1-based if needed)
        sim_data <- sim_data + 1

        # Convert to data frame with same column names and types
        sim_data <- as.data.frame(sim_data)
        colnames(sim_data) <- colnames(data_subset)

        # Mimic NA structure from subset
        na_positions <- is.na(data_subset)
        sim_data[na_positions] <- NA

        # Embed in original dataset if subsetting was used
        if (subset_data) {
          embedded_data <- original_data  # Create copy of original
          embedded_data[row_indices, variable_indices] <- sim_data
          sim_datasets[[i]] <- embedded_data
        } else {
          sim_datasets[[i]] <- sim_data
        }

      }, error = function(e) {
        warning(paste("Error in simulation", i, ":", e$message))
        sim_datasets[[i]] <- NULL
      })
    }

  } else if (all_interval) {
    for (i in 1:rep) {
      tryCatch({
        # Get precision matrix with adjacency structure imposed on subset data
        precision_matrix <- impose_adjacency_on_precision(data_subset, adj_matrices[[i]])

        # Convert back to covariance for simulation
        cov_matrix <- solve(precision_matrix)

        # Generate multivariate normal data using empirical mean and constrained covariance
        sim_data <- MASS::mvrnorm(
          n = n,
          mu = colMeans(data_subset, na.rm = TRUE),
          Sigma = cov_matrix
        )

        # Create clean data.frame structure
        sim_data <- data.frame(sim_data)
        colnames(sim_data) <- colnames(data_subset)

        # Mimic NA structure from subset
        na_positions <- is.na(data_subset)
        sim_data[na_positions] <- NA

        # Embed in original dataset if subsetting was used
        if (subset_data) {
          embedded_data <- original_data  # Create copy of original
          embedded_data[row_indices, variable_indices] <- sim_data
          sim_datasets[[i]] <- embedded_data
        } else {
          sim_datasets[[i]] <- sim_data
        }

      }, error = function(e) {
        warning(paste("Error in simulation", i, ":", e$message))
        sim_datasets[[i]] <- NULL
      })
    }
  }

  # Remove any NULL entries (failed simulations)
  sim_datasets <- sim_datasets[!sapply(sim_datasets, is.null)]

  # Insert original dataset at random position if requested
  if (insert_true_data && length(sim_datasets) > 0) {
    # Choose random position to insert original data
    insert_position <- sample(1:(length(sim_datasets) + 1), 1)
    sim_datasets <- append(sim_datasets, list(original_data), after = insert_position - 1)
    message("Original dataset inserted at position: ", insert_position)
  }

  return(sim_datasets)
}

# =============================================================================
# Helper functions 
# =============================================================================

# 1. Helper: Guess measurement level
guess_measurement_level <- function(x, ordinal_max_unique = 10) {
  x_no_na <- x[!is.na(x)]
  n_unique <- length(unique(x_no_na))
  if (is.logical(x_no_na)) return("Binary")
  if (n_unique == 2) return("Binary")
  if (is.factor(x)) {
    if (is.ordered(x)) return("Ordinal") else return("Nominal")
  }
  if (is.character(x)) return("Nominal")
  if (is.numeric(x)) {
    if (all(x_no_na == floor(x_no_na)) && n_unique <= ordinal_max_unique) return("Ordinal")
    else return("Interval")
  }
  return("Unknown")
}

# 2. Helper: Generate a clustered adjacency matrix
generate_planted_partition <- function(no_variables, no_clusters, diag_prob, off_diag_prob, balanced = TRUE) {
  if (no_clusters < 1 || no_clusters > no_variables) stop("no_clusters must be between 1 and no_variables (inclusive).")
  # Compute cluster allocation
  if (balanced) {
    sizes <- rep(floor(no_variables / no_clusters), no_clusters)
    remainder <- no_variables %% no_clusters
    if (remainder > 0) sizes[1:remainder] <- sizes[1:remainder] + 1
  } else {
    # Unbalanced allocation
    sizes <- sample(1:(no_variables - no_clusters + 1), no_clusters - 1, replace = TRUE)
    sizes <- c(sizes, no_variables - sum(sizes))
  }
  cluster_allocation_list <- split(seq_len(no_variables), rep(1:no_clusters, times = sizes))
  Q_probs <- matrix(off_diag_prob, nrow = no_clusters, ncol = no_clusters)
  diag(Q_probs) <- diag_prob
  cluster_allocation <- integer(no_variables)
  for (k in seq_along(cluster_allocation_list)) {
    cluster_allocation[cluster_allocation_list[[k]]] <- k
  }
  Z <- cluster_allocation
  G <- matrix(0, nrow = no_variables, ncol = no_variables)
  for (i in 1:(no_variables - 1)) {
    for (j in (i + 1):no_variables) {
      prob <- Q_probs[Z[i], Z[j]]
      G[i, j] <- G[j, i] <- stats::rbinom(1, 1, prob)
    }
  }
  return(G)
}

# 3.Helper function to impose adjacency structure on empirical precision matrix
impose_adjacency_on_precision <- function(empirical_datat, adj_mat) {
  # Get empirical covariance and precision matrices
  cov_emp <- cov(empirical_datat, use = "pairwise.complete.obs")
  prec_emp <- solve(cov_emp)
  
  # Create constraint matrix where non-edges should be zero
  constraint_mask <- adj_mat
  diag(constraint_mask) <- 1  # Always keep diagonal
  
  # Project precision matrix onto the space defined by the adjacency
  prec_proj <- prec_emp * constraint_mask
  
  # Ensure positive definiteness by adjusting eigenvalues
  eig_decomp <- eigen(prec_proj)
  min_eig <- min(eig_decomp$values)
  
  if (min_eig <= 0) {
    # Adjust eigenvalues to be positive
    eig_decomp$values[eig_decomp$values <= 0] <- 0.01
    prec_proj <- eig_decomp$vectors %*% diag(eig_decomp$values) %*% t(eig_decomp$vectors)
    
    # Re-impose sparsity pattern
    prec_proj <- prec_proj * constraint_mask
    
    # Ensure diagonal is reasonable
    diag(prec_proj) <- pmax(diag(prec_proj), 0.1)
  }
  
  return(prec_proj)
}

