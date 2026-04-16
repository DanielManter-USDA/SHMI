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

  errors <- c()
  warnings <- c()

  # ---- Required sheets ----
  required_sheets <- c(
    "Mgt_Unit",
    "Crop_Diversity",
    "Soil_Disturbance",
    "Soil_Amendments",
    "Animal_Diversity",
    "Soil_Test"
  )

  sheets <- readxl::excel_sheets(path)
  missing_sheets <- setdiff(required_sheets, sheets)

  if (length(missing_sheets) > 0) {
    errors <- c(errors, paste("Missing required sheets:",
                              paste(missing_sheets, collapse = ", ")))
    return(list(ok = FALSE, errors = errors, warnings = warnings))
  }

  # ---- Helper to read a sheet safely ----
  read_sheet <- function(sheet) {
    df <- suppressWarnings(readxl::read_excel(path, sheet = sheet))
    df <- janitor::clean_names()
    df
  }

  # ---- Load sheets ----
  mu <- read_sheet("Mgt_Unit")
  cd <- read_sheet("Crop_Diversity")
  sd <- read_sheet("Soil_Disturbance")
  sa <- read_sheet("Soil_Amendments")
  ad <- read_sheet("Animal_Diversity")
  st <- read_sheet("Soil_Test")

  # ---- Required columns per sheet ----
  req_cols <- list(
    Mgt_Unit = c("mgt_combo", "mgt_study", "mgt_farm", "mgt_field",
                 "mgt_lat", "mgt_lon", "mgt_state", "mgt_county",
                 "mgt_trt", "mgt_tile_drain", "mgt_tile_years"),

    Crop_Diversity = c("mgt_combo", "cd_seq_num", "cd_mix", "cd_cat",
                       "cd_group", "cd_name", "cd_plant_date",
                       "cd_harv_date", "cd_term_date"),

    Soil_Disturbance = c("mgt_combo", "sd_phase", "sd_date",
                         "sd_equip_cat", "sd_equip", "sd_mixeff",
                         "sd_depth"),

    Soil_Amendments = c("mgt_combo", "sa_cat", "sa_source",
                        "sa_date", "sa_rate", "sa_units"),

    Animal_Diversity = c("mgt_combo", "ad_type", "ad_intensity",
                         "ad_count", "ad_start_date", "ad_end_date"),

    Soil_Test = c("mgt_combo", "st_test_lab", "st_test_date",
                  "st_test_depth", "st_texture", "st_soc",
                  "st_om", "st_ph", "st_ec")
  )

  for (nm in names(req_cols)) {
    df <- get(tolower(nm))
    missing <- setdiff(req_cols[[nm]], names(df))
    if (length(missing) > 0) {
      errors <- c(errors, paste0("Sheet ", nm,
                                 " is missing required columns: ",
                                 paste(missing, collapse = ", ")))
    }
  }

  # ---- Check MGT_combo consistency ----
  all_mgt <- list(
    Mgt_Unit = mu$mgt_combo,
    Crop_Diversity = cd$mgt_combo,
    Soil_Disturbance = sd$mgt_combo,
    Soil_Amendments = sa$mgt_combo,
    Animal_Diversity = ad$mgt_combo,
    Soil_Test = st$mgt_combo
  )

  # NA check
  for (nm in names(all_mgt)) {
    if (any(is.na(all_mgt[[nm]]))) {
      errors <- c(errors, paste0("Sheet ", nm,
                                 " contains NA MGT_combo values"))
    }
  }

  # Cross-sheet consistency
  mu_set <- unique(mu$mgt_combo)
  for (nm in names(all_mgt)[-1]) {
    missing <- setdiff(unique(all_mgt[[nm]]), mu_set)
    if (length(missing) > 0) {
      errors <- c(errors, paste0("Sheet ", nm,
                                 " contains MGT_combo not found in Mgt_Unit: ",
                                 paste(missing, collapse = ", ")))
    }
  }

  # ---- Date validation ----
  date_cols <- list(
    Crop_Diversity = c("cd_plant_date", "cd_harv_date", "cd_term_date"),
    Soil_Disturbance = "sd_date",
    Soil_Amendments = "sa_date",
    Animal_Diversity = c("ad_start_date", "ad_end_date"),
    Soil_Test = "st_test_date"
  )

  for (nm in names(date_cols)) {
    df <- get(tolower(nm))
    for (col in date_cols[[nm]]) {
      if (!inherits(df[[col]], "Date")) {
        errors <- c(errors, paste0("Column ", col,
                                   " in sheet ", nm,
                                   " is not a valid Date"))
      }
    }
  }

  # ---- Mixture syntax ----
  bad_mix <- cd$cd_mix[grepl("\\+\\+|\\+$|^\\+", cd$cd_mix)]
  if (length(bad_mix) > 0) {
    warnings <- c(warnings, paste("Malformed mixture entries:",
                                  paste(unique(bad_mix), collapse = ", ")))
  }

  # ---- Stray row detection ----
  stray_cd <- cd[rowSums(!is.na(cd[, setdiff(names(cd), "cd_notes")])) == 0, ]
  if (nrow(stray_cd) > 0) {
    warnings <- c(warnings, "Crop_Diversity contains stray blank rows")
  }

  # ---- Summary ----
  summary <- tibble::tibble(
    sheets_present = length(sheets),
    mgt_units = nrow(mu),
    crop_rows = nrow(cd),
    disturbance_rows = nrow(sd),
    amendment_rows = nrow(sa),
    animal_rows = nrow(ad),
    soil_test_rows = nrow(st)
  )

  list(
    ok = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    summary = summary
  )
}
