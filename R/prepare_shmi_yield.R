#' Prepare crop-specific yield data for SHMI analysis
#'
#' Reads the `Crop_Diversity` sheet from an SHMI Excel template, extracts
#' yield information, validates units and structure, and computes
#' per-management-unit *and per-crop* yield statistics including mean
#' yield, variance, coefficient of variation, and Taylor's law parameters.
#'
#' This function mirrors the structure and validation workflow of
#' `prepare_shmi_inputs()`, but focuses exclusively on yield. It is
#' intentionally separate from the SHMI core so that yield remains
#' optional and analysis-focused.
#'
#' @param path Path to an SHMI Excel template (e.g., `"SHMI_template.xlsx"`).
#' @param exclude Optional character vector of `MGT_combo` identifiers to
#'   exclude from the yield summary.
#' @param verbose Logical; print progress messages? Default `TRUE`.
#' @param start_date_override Optional date (YYYY-MM-DD) to override the
#'   earliest allowable date for yield records.
#' @param end_date_override Optional date (YYYY-MM-DD) to override the
#'   latest allowable date for yield records.
#'
#' @return A tibble with one row per `(MGT_combo, crop)` containing:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{crop} — crop name (CD_name)
#'     \item \code{n_years}
#'     \item \code{mean_yield}
#'     \item \code{var_yield}
#'     \item \code{cv_yield}
#'     \item \code{log_mean}
#'     \item \code{log_var}
#'     \item \code{yield_units}
#'   }
#'
#' @export
prepare_shmi_yield <- function(path,
                               exclude = NULL,
                               verbose = TRUE,
                               start_date_override = NULL,
                               end_date_override = NULL) {

  # ------------------------------------------------------------
  # 0. Validate Excel file before ingestion
  # ------------------------------------------------------------
  val <- validate_excel_input(path)

  if (!val$ok) {
    message("❌ Excel input validation failed.\n")
    message("Errors:\n", paste0(" - ", val$errors, collapse = "\n"))
    stop("Fix the errors above and re-run prepare_shmi_yield().")
  }

  if (verbose) {
    message("✅ Excel input validation passed.\n")
    message("Input summary:")
    print(val$summary)

    if (length(val$warnings) > 0) {
      message("\nWarnings:")
      message(paste0(" - ", val$warnings, collapse = "\n"))
    }
  }

  # ------------------------------------------------------------
  # 1. Normalize override dates
  # ------------------------------------------------------------
  if (!is.null(start_date_override)) {
    start_date_override <- as.Date(start_date_override)
    if (is.na(start_date_override)) {
      stop("start_date_override must be a valid date (YYYY-MM-DD).", call. = FALSE)
    }
  }

  if (!is.null(end_date_override)) {
    end_date_override <- as.Date(end_date_override)
    if (is.na(end_date_override)) {
      stop("end_date_override must be a valid date (YYYY-MM-DD).", call. = FALSE)
    }
  }

  # ------------------------------------------------------------
  # 2. Exclusion list
  # ------------------------------------------------------------
  if (verbose) {
    message("Excluding ", length(exclude), " management units:")
    message(paste("  -", exclude, collapse = "\n"))
  }

  # ------------------------------------------------------------
  # 3. Safe sheet reader (mirrors prepare_shmi_inputs)
  # ------------------------------------------------------------
  safe_read <- function(sheet, required_cols, ...) {

    if (!sheet %in% readxl::excel_sheets(path)) {
      if (verbose) message("Sheet '", sheet, "' not found; returning empty tibble.")
      return(tibble::tibble(!!!setNames(
        replicate(length(required_cols), logical(), simplify = FALSE),
        required_cols
      )))
    }

    df <- readxl::read_xlsx(path, sheet = sheet, ...)
    df <- janitor::remove_empty(df, "rows")
    df <- janitor::remove_empty(df, "cols")

    if (nrow(df) == 0) {
      if (verbose) message("Sheet '", sheet, "' is empty; returning empty tibble.")
      return(tibble::tibble(!!!setNames(
        replicate(length(required_cols), logical(), simplify = FALSE),
        required_cols
      )))
    }

    missing <- setdiff(required_cols, names(df))
    if (length(missing) > 0) {
      stop(
        "Sheet '", sheet, "' is missing required columns: ",
        paste(missing, collapse = ", "),
        call. = FALSE
      )
    }

    if ("MGT_combo" %in% names(df)) {
      bad <- sum(is.na(df$MGT_combo))
      if (bad > 0 && verbose) {
        message("Removed ", bad, " rows with NA MGT_combo from sheet '", sheet, "'.")
      }
      df <- df %>% dplyr::filter(!is.na(MGT_combo))
    }

    df
  }

  # ------------------------------------------------------------
  # 4. Read crop diversity sheet (yield lives here)
  # ------------------------------------------------------------
  crop_div <- safe_read(
    "Crop_Diversity",
    required_cols = c("MGT_combo", "CD_seq_num", "CD_plant_date", "CD_term_date"),
    skip = 3
  )

  if (!is.null(exclude)) {
    crop_div <- crop_div %>% dplyr::filter(!MGT_combo %in% exclude)
  }

  # ------------------------------------------------------------
  # 5. Filter to rows with yield
  # ------------------------------------------------------------
  yield_raw <- crop_div %>% dplyr::filter(!is.na(CD_yield))

  if (nrow(yield_raw) == 0) {
    if (verbose) message("No yield data found; returning empty tibble.")
    return(tibble::tibble())
  }

  # ------------------------------------------------------------
  # 6. Unit consistency check (per crop × MGT)
  # ------------------------------------------------------------
  unit_check <- yield_raw %>%
    dplyr::group_by(MGT_combo, CD_name) %>%
    dplyr::summarise(
      n_units = dplyr::n_distinct(CD_yield_units),
      units   = paste(unique(CD_yield_units), collapse = "; "),
      .groups = "drop"
    )

  inconsistent <- unit_check %>% dplyr::filter(n_units > 1)

  if (nrow(inconsistent) > 0) {
    warning(
      "Inconsistent yield units detected:\n",
      paste0(" - ", inconsistent$MGT_combo, " / ", inconsistent$CD_name,
             " (", inconsistent$units, ")",
             collapse = "\n"),
      "\nUsing the first unit encountered for each."
    )
  }

  # ------------------------------------------------------------
  # 7. Compute yield metrics per (MGT_combo × crop)
  # ------------------------------------------------------------
  yield_summary <- yield_raw %>%
    dplyr::group_by(MGT_combo, crop = CD_name) %>%
    dplyr::summarise(
      n_years     = dplyr::n(),
      mean_yield  = mean(CD_yield, na.rm = TRUE),
      var_yield   = stats::var(CD_yield, na.rm = TRUE),
      cv_yield    = stats::sd(CD_yield, na.rm = TRUE) / mean(CD_yield, na.rm = TRUE),
      log_mean    = log(mean_yield),
      log_var     = log(var_yield),
      yield_units = dplyr::first(CD_yield_units),
      .groups = "drop"
    )

  if (verbose) {
    message("Yield summary computed for ",
            nrow(yield_summary), " crop × management combinations.")
  }

  return(yield_summary)
}
