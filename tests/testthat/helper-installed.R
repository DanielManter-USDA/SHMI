# Run the *installed* SHMI package in a separate R process.
#
# devtools::test() loads the development version under the name "SHMI", so
# the installed version cannot be loaded into the same session. callr starts
# a fresh R process that loads SHMI from the library instead.
#
# By default the child uses the current .libPaths(). To compare against a
# version installed somewhere else, set SHMI_REF_LIB to that library path.

.ref_lib <- function() {
  lib <- Sys.getenv("SHMI_REF_LIB")
  if (nzchar(lib)) lib else .libPaths()
}

# Is an installed SHMI available to a child process? Returns its version or NA.
installed_shmi_version <- function(lib = .ref_lib()) {
  callr::r(
    function() {
      if (!requireNamespace("SHMI", quietly = TRUE)) return(NA_character_)
      as.character(utils::packageVersion("SHMI"))
    },
    libpath = lib
  )
}

# Run prepare + build with the installed version; returns indicator_df.
# The child's console output is captured to a log so that if the process
# fails or crashes, the last lines are shown in the error message.
run_shmi_installed <- function(path, settings = NULL, expert_mode = FALSE,
                               lib = .ref_lib()) {
  log_file <- tempfile("shmi_installed_", fileext = ".log")

  tryCatch(
    callr::r(
      function(path, settings, expert_mode) {
        options(cli.unicode = FALSE)   # avoid non-ASCII output issues on Windows
        suppressMessages({
          inputs <- SHMI::prepare_shmi_inputs(path, verbose = FALSE)
          out    <- SHMI::build_shmi(inputs, settings = settings,
                                     expert_mode = expert_mode)
        })
        as.data.frame(out$indicator_df)
      },
      args    = list(path = normalizePath(path), settings = settings,
                     expert_mode = expert_mode),
      libpath = lib,
      stdout  = log_file,
      stderr  = "2>&1"
    ),
    error = function(e) {
      log_tail <- if (file.exists(log_file)) {
        utils::tail(readLines(log_file, warn = FALSE), 30)
      } else {
        "(no output captured)"
      }
      stop(
        "Installed SHMI failed in the subprocess: ", conditionMessage(e),
        "\n--- last lines of subprocess output (", log_file, ") ---\n",
        paste(log_tail, collapse = "\n"),
        call. = FALSE
      )
    }
  )
}

# Run prepare + build with the development version loaded in this session
run_shmi_dev <- function(path, settings = NULL, expert_mode = FALSE) {
  suppressMessages({
    inputs <- prepare_shmi_inputs(path, verbose = FALSE)
    out    <- build_shmi(inputs, settings = settings, expert_mode = expert_mode)
  })
  list(inputs = inputs, scores = as.data.frame(out$indicator_df))
}

# Unit-by-unit comparison of two indicator tables
compare_scores <- function(ref, new,
                           pillars = c("SHMI", "Cover", "Diversity",
                                       "InvDist", "OrgInput")) {
  cmp <- dplyr::full_join(
    ref[c("MGT_combo", pillars)], new[c("MGT_combo", pillars)],
    by = "MGT_combo", suffix = c("_installed", "_dev")
  )
  for (p in pillars) {
    cmp[[paste0("d_", p)]] <- cmp[[paste0(p, "_dev")]] - cmp[[paste0(p, "_installed")]]
  }
  cmp
}
