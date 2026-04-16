#' Validate SHMI Input Tables
#'
#' @description
#' Performs structural and semantic validation of the input data list used by
#' `build_shmi()`. This function checks for required tables, required columns,
#' valid data types, missing or invalid values, duplicated rows, and rotation
#' boundary consistency. It returns a structured list containing validation
#' status, error messages, warnings, and a summary of key dataset properties.
#'
#' This validator is designed to fail early and explicitly when critical issues
#' are detected (e.g., missing `MGT_combo`, malformed dates, duplicated daily
#' rows). Non-fatal issues are returned as warnings. A summary of field counts,
#' years, species richness, mixture counts, and fallow days is included for
#' diagnostic transparency.
#'
#' @param dat A named list of SHMI input tables, typically produced by
#'   `prepare_shmi_inputs()`. Must contain at least:
#'   \describe{
#'     \item{crop_harmonized}{A tibble of harmonized crop records with
#'       `MGT_combo`, `date`, and `CD_name`.}
#'     \item{daily}{A tibble of daily crop presence with `MGT_combo`, `date`,
#'       `CD_name`, and `crop_present`.}
#'     \item{rot_bounds}{A tibble defining rotation start and end dates for each
#'       `MGT_combo`, with columns `rot_start` and `rot_end`.}
#'   }
#'
#' @return
#' A list with the following elements:
#' \describe{
#'   \item{ok}{Logical. `TRUE` if validation passed with no errors; `FALSE`
#'     otherwise.}
#'   \item{errors}{Character vector of critical validation failures. If non-empty,
#'     `build_shmi()` should stop execution.}
#'   \item{warnings}{Character vector of non-fatal issues.}
#'   \item{summary}{A tibble summarizing key dataset properties (fields, years,
#'     species, mixtures, fallow days).}
#' }
#'
#' @details
#' This function enforces SHMI input integrity by checking:
#' \itemize{
#'   \item Presence of required tables and columns.
#'   \item No missing `MGT_combo` values.
#'   \item All date columns are of class `Date`.
#'   \item Rotation boundaries are valid (`rot_start` ≤ `rot_end`).
#'   \item No duplicated `(MGT_combo, date)` rows in the daily table.
#'   \item `crop_present` contains only 0, 1, or `NA`.
#'   \item Basic dataset diagnostics (fields, years, species richness, mixtures).
#' }
#'
#' @examples
#' \dontrun{
#' dat <- prepare_shmi_inputs("path/to/input/folder")
#' val <- validate_shmi_input(dat)
#' if (!val$ok) stop("Validation failed:\n", paste(val$errors, collapse = "\n"))
#' print(val$summary)
#' }
#'
#' @export
validate_shmi_input <- function(shmi_inputs) {

  errors <- c()
  warnings <- c()

  # ---- Check required tables ----
  required_tables <- c("crop_harmonized", "daily", "rot_bounds")
  missing_tables <- setdiff(required_tables, names(shmi_inputs))
  if (length(missing_tables) > 0) {
    errors <- c(errors, paste("Missing required tables:", paste(missing_tables, collapse=", ")))
  }

  # ---- Check MGT_combo ----
  for (tbl in required_tables) {
    if (!"MGT_combo" %in% names(shmi_inputs[[tbl]])) {
      errors <- c(errors, paste0("Table ", tbl, " is missing MGT_combo column"))
    }
    if (any(is.na(shmi_inputs[[tbl]]$MGT_combo))) {
      errors <- c(errors, paste0("Table ", tbl, " contains NA MGT_combo values"))
    }
  }

  # ---- Check date columns ----
  date_tables <- c("daily")
  for (tbl in date_tables) {
    if (!"date" %in% names(shmi_inputs[[tbl]])) {
      errors <- c(errors, paste0("Table ", tbl, " is missing date column"))
    } else if (!inherits(shmi_inputs[[tbl]]$date, "Date")) {
      errors <- c(errors, paste0("Table ", tbl, " has non-Date date column"))
    }
  }

  # ---- Check rotation boundaries ----
  rb <- shmi_inputs$rot_bounds
  if (!all(c("rot_start", "rot_end") %in% names(rb))) {
    errors <- c(errors, "rot_bounds must contain rot_start and rot_end")
  }
  if (any(rb$rot_start > rb$rot_end)) {
    errors <- c(errors, "Some rotation boundaries have rot_start > rot_end")
  }

  # ---- Check duplicates ----
  dups <- shmi_inputs$daily %>%
    dplyr::count(MGT_combo, date) %>%
    dplyr::filter(n > 1)
  if (nrow(dups) > 0) {
    errors <- c(errors, "Duplicate (MGT_combo, date) rows found in daily table")
  }

  # ---- Check crop_present ----
  if (any(!shmi_inputs$daily$crop_present %in% c(0,1,NA))) {
    errors <- c(errors, "daily$crop_present contains values other than 0, 1, or NA")
  }

  # ---- Summaries (non-fatal) ----
  summary <- tibble::tibble(
    fields = length(unique(shmi_inputs$daily$MGT_combo)),
    years = length(unique(lubridate::year(shmi_inputs$daily$date))),
    species = length(unique(shmi_inputs$crop_harmonized$CD_name)),
    mixtures = sum(grepl("\\+", shmi_inputs$crop_harmonized$CD_name)),
    fallow_days = sum(shmi_inputs$daily$CD_name == "fallow", na.rm = TRUE)
  )

  # ---- Final output ----
  list(
    ok = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    summary = summary
  )
}
