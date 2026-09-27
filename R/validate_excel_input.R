#' Validate an SHMI Excel workbook
#'
#' Checks a workbook before it is read by [prepare_shmi_inputs()], which
#' calls this function automatically.
#'
#' @details
#' Errors (validation fails):
#' * a required sheet is missing, or a required column is missing from a
#'   non-empty sheet;
#' * `MGT_combo` is missing in any row, is duplicated in `Mgt_Unit`, or does
#'   not appear in `Mgt_Unit`;
#' * a disturbance pass has a missing or unparseable `SD_date`;
#' * `SD_mixeff` or `SD_depth` is non-numeric or negative.
#'
#' Warnings (validation passes):
#' * `SD_depth` greater than 20 inches (possibly entered in cm);
#' * stray blank rows in `Crop_Diversity`.
#'
#' Checks that depend on the disturbance method (EPA or STIR) are made later
#' by [validate_shmi_input()], because the method is chosen in
#' [build_shmi()].
#'
#' @param path Path to the SHMI Excel workbook.
#' @param verbose Logical. Report rows removed while reading.
#'
#' @return A list with `ok` (logical), `errors` and `warnings` (character
#'   vectors), and `summary` (a tibble of row counts per sheet; empty if the
#'   check stopped because sheets were missing).
#'
#' @seealso [prepare_shmi_inputs()], [validate_shmi_input()]
#'
#' @export
validate_excel_input <- function(path, verbose = TRUE) {

  errors   <- character()
  warnings <- character()

  # NULL-safe row count (.safe_read() can return NULL for empty sheets)
  .n <- function(df) if (is.null(df)) 0L else nrow(df)

  # Format the first few offending rows for messages
  .first_rows <- function(df, cols, n = 5) {
    ids <- unique(do.call(paste, df[cols]))
    paste0(paste(utils::head(ids, n), collapse = "; "),
           if (length(ids) > n) paste0(" (+", length(ids) - n, " more)") else "")
  }

  # ---- Required sheets ----
  required_sheets <- c(
    "Mgt_Unit",
    "Crop_Diversity",
    "Soil_Disturbance",
    "Soil_Amendments",
    "Animal_Diversity"
  )

  sheets_present <- readxl::excel_sheets(path)
  missing_sheets <- setdiff(required_sheets, sheets_present)

  if (length(missing_sheets) > 0) {
    errors <- c(errors, paste(
      "Missing required sheets:",
      paste(missing_sheets, collapse = ", ")
    ))
    return(list(ok = FALSE, errors = errors, warnings = warnings,
                summary = tibble::tibble()))
  }

  # ---- Load sheets using .safe_read() ----
  mu <- .safe_read(path,
                   sheet = "Mgt_Unit",
                   required_cols = c("MGT_combo", "MGT_study", "MGT_field", "MGT_trt"),
                   skip = 3,
                   verbose = verbose)

  cd <- .safe_read(path,
                   sheet = "Crop_Diversity",
                   required_cols = c("MGT_combo", "CD_plant_date", "CD_term_date"),
                   skip = 3,
                   verbose = verbose)

  sd <- .safe_read(path,
                   sheet = "Soil_Disturbance",
                   required_cols = c("MGT_combo", "SD_date", "SD_mixeff"),
                   skip = 3,
                   verbose = verbose)

  sa <- .safe_read(path,
                   sheet = "Soil_Amendments",
                   required_cols = NULL,
                   skip = 3,
                   verbose = verbose)

  ad <- .safe_read(path,
                   sheet = "Animal_Diversity",
                   required_cols = NULL,
                   skip = 3,
                   verbose = verbose)

  sheets <- list(
    Mgt_Unit         = mu,
    Crop_Diversity   = cd,
    Soil_Disturbance = sd,
    Soil_Amendments  = sa,
    Animal_Diversity = ad
  )

  # ---- Required columns per sheet ----
  req_cols <- list(
    Mgt_Unit = c(
      "MGT_combo", "MGT_study", "MGT_field", "MGT_trt"
    ),

    Crop_Diversity = c(
      "MGT_combo", "CD_name", "CD_plant_date", "CD_term_date"
    ),

    Soil_Disturbance = c(
      "MGT_combo", "SD_date", "SD_mixeff"
    )
  )

  for (nm in names(req_cols)) {
    df <- sheets[[nm]]

    if (.n(df) == 0) next

    missing <- setdiff(req_cols[[nm]], names(df))
    if (length(missing) > 0) {
      errors <- c(errors, paste0(
        "Sheet ", nm, " is missing required columns: ",
        paste(missing, collapse = ", ")
      ))
    }
  }

  # ---- Check MGT_combo consistency ----

  # No NA MGT_combo
  for (nm in names(sheets)) {
    df <- sheets[[nm]]
    if (.n(df) == 0) next

    if ("MGT_combo" %in% names(df)) {
      if (any(is.na(df$MGT_combo))) {
        errors <- c(errors, paste0("Sheet ", nm, " contains NA MGT_combo values"))
      }
    }
  }

  # Duplicated management units
  if (.n(mu) > 0 && "MGT_combo" %in% names(mu)) {
    dups <- unique(mu$MGT_combo[duplicated(mu$MGT_combo) & !is.na(mu$MGT_combo)])
    if (length(dups) > 0) {
      errors <- c(errors, paste0(
        "Mgt_Unit contains duplicated MGT_combo values: ",
        paste(utils::head(dups, 10), collapse = ", ")
      ))
    }
  }

  # Cross-sheet consistency
  mu_set <- unique(mu$MGT_combo)

  for (nm in names(sheets)[-1]) {
    df <- sheets[[nm]]
    if (.n(df) == 0) next
    if (!"MGT_combo" %in% names(df)) next

    combos <- df$MGT_combo
    combos <- combos[!is.na(combos)]

    missing <- setdiff(unique(combos), mu_set)

    if (length(missing) > 0) {
      errors <- c(errors, paste0(
        "Sheet ", nm,
        " contains MGT_combo not found in Mgt_Unit: ",
        paste(missing, collapse = ", ")
      ))
    }
  }

  # ---- Soil_Disturbance: dates and values (method-independent) ----
  if (.n(sd) > 0 && all(c("MGT_combo", "SD_date", "SD_mixeff") %in% names(sd))) {

    # Missing or unparseable dates: these passes cannot be placed in a year
    parsed_date <- unname(.parse_shmi_date(sd$SD_date))
    bad_date    <- is.na(parsed_date)
    if (any(bad_date)) {
      errors <- c(errors, paste0(
        "Soil_Disturbance has ", sum(bad_date),
        " row(s) with a missing or unparseable SD_date. First affected (MGT_combo): ",
        paste(utils::head(unique(sd$MGT_combo[bad_date]), 5), collapse = ", ")
      ))
    }

    # SD_mixeff: must be numeric and non-negative
    mixeff <- suppressWarnings(as.numeric(sd$SD_mixeff))
    non_num <- !is.na(sd$SD_mixeff) & is.na(mixeff)
    if (any(non_num)) {
      errors <- c(errors, paste0(
        "Soil_Disturbance has ", sum(non_num),
        " non-numeric SD_mixeff value(s): ",
        paste(utils::head(unique(sd$SD_mixeff[non_num]), 5), collapse = ", ")
      ))
    }
    if (any(mixeff < 0, na.rm = TRUE)) {
      errors <- c(errors, "Soil_Disturbance contains negative SD_mixeff values.")
    }

    # SD_depth (optional column; required only for EPA, checked later)
    if ("SD_depth" %in% names(sd) && !all(is.na(sd$SD_depth))) {

      depth <- suppressWarnings(as.numeric(sd$SD_depth))

      non_num <- !is.na(sd$SD_depth) & is.na(depth)
      if (any(non_num)) {
        errors <- c(errors, paste0(
          "Soil_Disturbance has ", sum(non_num),
          " non-numeric SD_depth value(s) (enter numbers in inches only): ",
          paste(utils::head(unique(sd$SD_depth[non_num]), 5), collapse = ", ")
        ))
      }

      if (any(depth < 0, na.rm = TRUE)) {
        errors <- c(errors, "Soil_Disturbance contains negative SD_depth values.")
      }

      # Plausibility check on units (template expects inches)
      max_plausible_in <- 20   # ~51 cm; deeper than normal tillage
      deep <- !is.na(depth) & depth > max_plausible_in
      if (any(deep)) {
        warnings <- c(warnings, paste0(
          sum(deep), " disturbance pass(es) have SD_depth > ", max_plausible_in,
          " inches. SD_depth is expected in inches; values this large may have ",
          "been entered in cm. Depths are capped at 30 cm (~11.8 in) in the EPA ",
          "method, so unit errors are otherwise absorbed silently. First affected: ",
          .first_rows(sd[deep, ], c("MGT_combo", "SD_date", "SD_depth"))
        ))
      }
    }
  }

  # ---- Stray blank rows ----
  if (.n(cd) > 0) {
    check_cols <- setdiff(names(cd), c("CD_notes", "user_name"))
    stray_cd <- cd[rowSums(!is.na(cd[, check_cols, drop = FALSE])) == 0, ]
    if (nrow(stray_cd) > 0) {
      warnings <- c(warnings, "Crop_Diversity contains stray blank rows")
    }
  }

  # ---- Summary ----
  summary <- tibble::tibble(
    sheets_present    = length(sheets),
    mgt_units         = .n(mu),
    crop_rows         = .n(cd),
    disturbance_rows  = .n(sd),
    amendment_rows    = .n(sa),
    animal_rows       = .n(ad)
  )

  list(
    ok       = length(errors) == 0,
    errors   = errors,
    warnings = warnings,
    summary  = summary
  )
}
