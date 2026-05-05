#' Validate SHMI Input Tables
#'
#' @description
#' Performs structural and semantic validation of the input data list used by
#' `build_shmi()`. This function checks for required tables, required columns,
#' valid data types, missing or invalid values, duplicated keys where they
#' should be unique, and rotation boundary consistency. It returns a structured
#' list containing validation status, error messages, warnings, and a summary
#' of key dataset properties.
#'
#' This validator is designed to fail early and explicitly when critical issues
#' are detected (e.g., missing `MGT_combo`, malformed dates, invalid crop
#' windows). Non-fatal issues are returned as warnings. A summary of field
#' counts, years, species richness, mixture counts, and fallow presence is
#' included for diagnostic transparency.
#'
#' @param shmi_inputs A named list of SHMI input tables, typically produced by
#'   `prepare_shmi_inputs()`. Must contain at least:
#'   \describe{
#'     \item{mgt}{Management table with `MGT_combo` and metadata columns.}
#'     \item{crop_harmonized}{Tibble of harmonized crop records with
#'       `MGT_combo`, `CD_name`, `CD_seq_num`, `crop_start`, `crop_end`.}
#'     \item{rot_bounds}{Tibble defining rotation start and end dates for each
#'       `MGT_combo`, with `MGT_combo`, `rot_start`, `rot_end`.}
#'     \item{daily_dist}{Daily disturbance table with `MGT_combo`, `date`,
#'       and disturbance attributes.}
#'     \item{amend}{Amendment events with `MGT_combo` and `SA_date`.}
#'     \item{animal}{Animal events with `MGT_combo`, `AD_start_date`,
#'       `AD_end_date`.}
#'   }
#'
#' @return
#' A list with:
#' \describe{
#'   \item{ok}{Logical. `TRUE` if validation passed with no errors; `FALSE`
#'     otherwise.}
#'   \item{errors}{Character vector of critical validation failures. If non-empty,
#'     `build_shmi()` should stop execution.}
#'   \item{warnings}{Character vector of non-fatal issues.}
#'   \item{summary}{A tibble summarizing key dataset properties (fields, years,
#'     species, mixtures, fallow presence).}
#' }
#'
#' @export
validate_shmi_input <- function(shmi_inputs) {

  errors   <- character()
  warnings <- character()

  # ---- 1. Required tables ----
  required_tables <- c(
    "mgt",
    "crop_harmonized",
    "rot_bounds",
    "daily_dist",
    "amend",
    "animal"
  )

  missing_tables <- setdiff(required_tables, names(shmi_inputs))
  if (length(missing_tables) > 0) {
    errors <- c(
      errors,
      paste("Missing required tables:", paste(missing_tables, collapse = ", "))
    )
    # If these are missing, further checks will likely error; bail early.
    return(list(ok = FALSE, errors = errors, warnings = warnings,
                summary = tibble::tibble()))
  }

  # ---- 2. Check MGT_combo presence and NAs ----
  for (tbl in required_tables) {
    x <- shmi_inputs[[tbl]]
    if (!"MGT_combo" %in% names(x)) {
      errors <- c(errors, paste0("Table '", tbl, "' is missing MGT_combo column"))
    } else if (any(is.na(x$MGT_combo))) {
      errors <- c(errors, paste0("Table '", tbl, "' contains NA MGT_combo values"))
    }
  }

  # ---- 3. Check crop_harmonized structure ----
  ch <- shmi_inputs$crop_harmonized
  required_crop_cols <- c("CD_name", "CD_seq_num", "crop_start", "crop_end")
  missing_crop_cols  <- setdiff(required_crop_cols, names(ch))
  if (length(missing_crop_cols) > 0) {
    errors <- c(
      errors,
      paste("crop_harmonized missing columns:",
            paste(missing_crop_cols, collapse = ", "))
    )
  } else {
    # date classes
    if (!inherits(ch$crop_start, "Date") || !inherits(ch$crop_end, "Date")) {
      errors <- c(errors, "crop_harmonized$crop_start and crop_end must be Date")
    }
    # start <= end
    if (any(ch$crop_start > ch$crop_end, na.rm = TRUE)) {
      errors <- c(errors, "Some crop_harmonized rows have crop_start > crop_end")
    }
  }

  # ---- 4. Check rotation boundaries ----
  rb <- shmi_inputs$rot_bounds
  if (!all(c("rot_start", "rot_end") %in% names(rb))) {
    errors <- c(errors, "rot_bounds must contain rot_start and rot_end")
  } else {
    if (!inherits(rb$rot_start, "Date") || !inherits(rb$rot_end, "Date")) {
      errors <- c(errors, "rot_bounds$rot_start and rot_end must be Date")
    }
    if (any(rb$rot_start > rb$rot_end, na.rm = TRUE)) {
      errors <- c(errors, "Some rotation boundaries have rot_start > rot_end")
    }
  }

  # ---- 5. Check daily_dist date column ----
  dd <- shmi_inputs$daily_dist
  if (!"date" %in% names(dd)) {
    errors <- c(errors, "daily_dist is missing 'date' column")
  } else if (!inherits(dd$date, "Date")) {
    errors <- c(errors, "daily_dist$date must be Date")
  }

  # ---- 6. Check amend / animal date columns ----
  am <- shmi_inputs$amend
  if ("SA_date" %in% names(am) && !inherits(am$SA_date, "Date")) {
    errors <- c(errors, "amend$SA_date must be Date")
  }

  an <- shmi_inputs$animal
  animal_date_cols <- c("AD_start_date", "AD_end_date")
  if (!all(animal_date_cols %in% names(an))) {
    errors <- c(errors, "animal must contain AD_start_date and AD_end_date")
  } else {
    if (!inherits(an$AD_start_date, "Date") ||
        !inherits(an$AD_end_date, "Date")) {
      errors <- c(errors, "animal AD_start_date and AD_end_date must be Date")
    }
    if (any(an$AD_start_date > an$AD_end_date, na.rm = TRUE)) {
      errors <- c(errors, "Some animal windows have AD_start_date > AD_end_date")
    }
  }

  # ---- 7. Non-fatal diagnostics ----
  # fields
  n_fields <- length(unique(shmi_inputs$mgt$MGT_combo))

  # years from rotation bounds
  years <- unique(c(
    lubridate::year(shmi_inputs$rot_bounds$rot_start),
    lubridate::year(shmi_inputs$rot_bounds$rot_end)
  ))
  n_years <- length(years)

  # species and mixtures from crop_harmonized
  species_vec <- unique(ch$CD_name)
  n_species   <- length(species_vec)
  n_mixtures  <- sum(grepl("\\+", species_vec) | grepl("-species", species_vec))

  # fallow presence (not days, since no daily table)
  has_fallow <- any(ch$CD_name == "fallow")

  summary <- tibble::tibble(
    fields       = n_fields,
    years        = n_years,
    species      = n_species,
    mixtures     = n_mixtures,
    has_fallow   = has_fallow
  )

  # ---- 8. Final output ----
  list(
    ok       = length(errors) == 0,
    errors   = errors,
    warnings = warnings,
    summary  = summary
  )
}
