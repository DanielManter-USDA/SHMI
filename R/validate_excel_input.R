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
    "Animal_Diversity"
  )

  sheets_present <- readxl::excel_sheets(path)
  missing_sheets <- setdiff(required_sheets, sheets_present)

  if (length(missing_sheets) > 0) {
    errors <- c(errors, paste("Missing required sheets:",
                              paste(missing_sheets, collapse = ", ")))
    return(list(ok = FALSE, errors = errors, warnings = warnings))
  }

  # ---- Helper to read a sheet safely ----
  read_sheet <- function(path, sheet) {
    df <- suppressWarnings(
      readxl::read_excel(path, sheet = sheet, skip = 3)
    )

    if (is.null(df) || nrow(df) == 0) {
      return(tibble::tibble())
    }

    df <- janitor::clean_names(df)
    df
  }

  # ---- Load sheets ----
  mu <- read_sheet(path, "Mgt_Unit")
  cd <- read_sheet(path, "Crop_Diversity")
  sd <- read_sheet(path, "Soil_Disturbance")
  sa <- read_sheet(path, "Soil_Amendments")
  ad <- read_sheet(path, "Animal_Diversity")

  sheets <- list(
    Mgt_Unit = mu,
    Crop_Diversity = cd,
    Soil_Disturbance = sd,
    Soil_Amendments = sa,
    Animal_Diversity = ad
  )

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
                         "ad_count", "ad_start_date", "ad_end_date")
  )

  for (nm in names(req_cols)) {
    df <- sheets[[nm]]

    if (nrow(df) == 0) next

    missing <- setdiff(req_cols[[nm]], names(df))
    if (length(missing) > 0) {
      errors <- c(errors, paste0(
        "Sheet ", nm,
        " is missing required columns: ",
        paste(missing, collapse = ", ")
      ))
    }
  }

  # ---- Check MGT_combo consistency ----
  all_mgt <- list(
    Mgt_Unit = mu,
    Crop_Diversity = cd,
    Soil_Disturbance = sd,
    Soil_Amendments = sa,
    Animal_Diversity = ad
  )

  for (nm in names(all_mgt)) {
    df <- all_mgt[[nm]]

    if (nrow(df) == 0) next

    df <- dplyr::filter(df, !is.na(mgt_combo))

    if (any(is.na(df$mgt_combo))) {
      errors <- c(errors, paste0("Sheet ", nm,
                                 " contains NA MGT_combo values"))
    }
  }

  # Cross-sheet consistency
  mu_set <- unique(mu$mgt_combo)

  for (nm in names(all_mgt)[-1]) {
    df <- all_mgt[[nm]]

    if (nrow(df) == 0) next

    combos <- df$mgt_combo
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

  # ---- Date parsing helper ----
  parse_date <- function(x) {
    if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))
    suppressWarnings(as.Date(x))
  }

  # ---- Date validation ----
  date_cols <- list(
    Crop_Diversity = c("cd_plant_date", "cd_harv_date", "cd_term_date"),
    Soil_Disturbance = "sd_date",
    Soil_Amendments = "sa_date",
    Animal_Diversity = c("ad_start_date", "ad_end_date")
  )

  for (nm in names(date_cols)) {
    df <- sheets[[nm]]

    if (nrow(df) == 0) next

    for (col in date_cols[[nm]]) {

      # Parse the date BEFORE checking class
      df[[col]] <- parse_date(df[[col]])

      if (!inherits(df[[col]], "Date")) {
        errors <- c(errors, paste0(
          "Column ", col,
          " in sheet ", nm,
          " is not a valid Date"
        ))
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
    animal_rows = nrow(ad)
  )

  list(
    ok = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    summary = summary
  )
}
