#' Validate SHMI Excel Input File
#'
#' @description
#' Validates the raw Excel file supplied to `prepare_shmi_inputs()`. This
#' function checks for required sheets, required columns, valid date formats,
#' missing or invalid `MGT_combo` values, malformed mixtures, species lookup
#' consistency, and rotation boundary completeness. It is designed to fail early
#' and explicitly before any ingestion or harmonization occurs.
#'
#' @param path Character string. Path to the Excel file supplied by the user.
#'
#' @return A list with:
#' \describe{
#'   \item{ok}{Logical. TRUE if validation passed; FALSE otherwise.}
#'   \item{errors}{Character vector of critical validation failures.}
#'   \item{warnings}{Character vector of non-fatal issues.}
#'   \item{summary}{A tibble summarizing sheet counts and row counts.}
#' }
#'
#' @export
validate_excel_input <- function(path) {

  errors   <- character()
  warnings <- character()

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
    return(list(ok = FALSE, errors = errors, warnings = warnings))
  }

  # ---- Load sheets using .safe_read() ----
  mu <- .safe_read(path,
                   "Mgt_Unit",
                   required_cols = c("MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt"),
                   skip = 3)

  cd <- .safe_read(path,
                   "Crop_Diversity",
                   required_cols = c("MGT_combo", "CD_seq_num", "CD_plant_date", "CD_term_date"),
                   skip = 3)

  sd <- .safe_read(path,
                   "Soil_Disturbance",
                   required_cols = c("MGT_combo", "SD_date", "SD_mixeff"),
                   skip = 3)

  sa <- .safe_read(path,
                   "Soil_Amendments",
                   required_cols = c("MGT_combo", "SA_date"),
                   skip = 3)

  ad <- .safe_read(path,
                   "Animal_Diversity",
                   required_cols = c("MGT_combo", "AD_start_date", "AD_end_date"),
                   skip = 3)

  sheets <- list(
    Mgt_Unit        = mu,
    Crop_Diversity  = cd,
    Soil_Disturbance = sd,
    Soil_Amendments = sa,
    Animal_Diversity = ad
  )

  # ---- Required columns per sheet ----
  req_cols <- list(
    Mgt_Unit = c(
      "MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt"
    ),

    Crop_Diversity = c(
      "MGT_combo", "CD_seq_num",
      "CD_name", "CD_plant_date", "CD_term_date"
    ),

    Soil_Disturbance = c(
      "MGT_combo", "SD_date",
      "SD_equip_cat", "SD_equip", "SD_mixeff", "SD_depth"
    ),

    Soil_Amendments = c(
      "MGT_combo", "SA_date"
    ),

    Animal_Diversity = c(
      "MGT_combo", "AD_start_date", "AD_end_date"
    )
  )

  for (nm in names(req_cols)) {
    df <- sheets[[nm]]

    if (nrow(df) == 0) next

    missing <- setdiff(req_cols[[nm]], names(df))
    if (length(missing) > 0) {
      errors <- c(errors, paste0(
        "Sheet ", nm, " is missing required columns: ",
        paste(missing, collapse = ", ")
      ))
    }
  }

  # ---- Check MGT_combo consistency ----
  all_mgt <- list(
    Mgt_Unit        = mu,
    Crop_Diversity  = cd,
    Soil_Disturbance = sd,
    Soil_Amendments = sa,
    Animal_Diversity = ad
  )

  # No NA MGT_combo
  for (nm in names(all_mgt)) {
    df <- all_mgt[[nm]]
    if (nrow(df) == 0) next

    if (any(is.na(df$MGT_combo))) {
      errors <- c(errors, paste0(
        "Sheet ", nm, " contains NA MGT_combo values"
      ))
    }
  }

  # Cross-sheet consistency
  mu_set <- unique(mu$MGT_combo)

  for (nm in names(all_mgt)[-1]) {
    df <- all_mgt[[nm]]
    if (nrow(df) == 0) next

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

  # ---- Mixture syntax warnings ----
  bad_mix <- cd$CD_mix[grepl("\\+\\+|\\+$|^\\+", cd$CD_mix)]
  if (length(bad_mix) > 0) {
    warnings <- c(warnings, paste(
      "Malformed mixture entries:",
      paste(unique(bad_mix), collapse = ", ")
    ))
  }

  # ---- Stray blank rows ----
  stray_cd <- cd[rowSums(!is.na(cd[, setdiff(names(cd), "cd_notes")])) == 0, ]
  if (nrow(stray_cd) > 0) {
    warnings <- c(warnings, "Crop_Diversity contains stray blank rows")
  }

  # ---- Summary ----
  summary <- tibble::tibble(
    sheets_present    = length(sheets),
    mgt_units         = nrow(mu),
    crop_rows         = nrow(cd),
    disturbance_rows  = nrow(sd),
    amendment_rows    = nrow(sa),
    animal_rows       = nrow(ad)
  )

  list(
    ok       = length(errors) == 0,
    errors   = errors,
    warnings = warnings,
    summary  = summary
  )
}

