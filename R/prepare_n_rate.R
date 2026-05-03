#' @keywords internal
#' @noRd
.prepare_n_rate <- function(path,
                            start_date_override = NULL,
                            end_date_override   = NULL) {

  # ---- Load MGT_Unit (preserve all components) ----
  mgt <- .safe_read(
    path,
    "Mgt_Unit",
    required_cols = c("MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt"),
    skip = 3
  )

  # ---- Load Soil Amendments ----
  amend <- .safe_read(
    path,
    "Soil_Amendments",
    required_cols = c("MGT_combo", "SA_date", "SA_N", "SA_units"),
    skip = 3
  ) %>%
    mutate(SA_date = as.Date(.parse_shmi_date(SA_date)))

  # ---- Clip by overrides ----
  if (!is.null(start_date_override)) {
    S <- as.Date(start_date_override)
    amend <- amend %>% filter(SA_date >= S)
  }

  if (!is.null(end_date_override)) {
    E <- as.Date(end_date_override)
    amend <- amend %>% filter(SA_date <= E)
  }

  # ---- Load Crop_Diversity to get crop_year ----
  crop <- .safe_read(
    path,
    "Crop_Diversity",
    required_cols = c("MGT_combo", "CD_plant_date", "CD_term_date"),
    skip = 3
  )

  # CD_harv_date is optional (same as .prepare_yield)
  if (!"CD_harv_date" %in% names(crop)) {
    crop$CD_harv_date <- NA
  }

  crop <- crop %>%
    mutate(
      CD_plant_date = as.Date(.parse_shmi_date(CD_plant_date)),
      CD_term_date  = as.Date(.parse_shmi_date(CD_term_date)),
      CD_harv_date  = as.Date(.parse_shmi_date(CD_harv_date)),
      crop_year = dplyr::coalesce(
        lubridate::year(CD_harv_date),
        lubridate::year(CD_term_date)
      )
    ) %>%
    distinct(MGT_combo, crop_year)

  # ---- Unit conversion helper ----
  convert_n_to_kg_ha <- function(value, unit) {

    if (is.na(value)) return(NA_real_)
    if (is.na(unit))  return(NA_real_)

    unit <- tolower(trimws(unit))

    if (unit %in% c("kgs/hectare", "kg/ha", "kgs/ha", "kg/hectare"))
      return(value)

    if (unit %in% c("tonnes/hectare", "t/ha"))
      return(value * 1000)

    if (unit %in% c("lbs/acre", "lb/acre"))
      return(value * 0.453592 / 0.404686)

    if (unit %in% c("tons/acre", "ton/acre"))
      return(value * 907.185 / 0.404686)

    stop(paste("Unknown SA_units:", unit))
  }

  # ---- Convert N to kg/ha ----
  amend <- amend %>%
    mutate(
      N_kg_ha = purrr::map2_dbl(SA_N, SA_units, convert_n_to_kg_ha),
      SA_year = lubridate::year(SA_date)
    )

  # ---- Join amendments to crop_year (critical step) ----
  # This assigns each amendment to the crop_year it belongs to.
  amend_year <- amend %>%
    left_join(
      crop,
      by = "MGT_combo"
    ) %>%
    # keep only amendments whose SA_date falls within that crop_year
    filter(SA_year == crop_year)

  # ---- Summarize N per MGT_combo × crop_year ----
  n_rate_raw <- amend_year %>%
    group_by(MGT_combo, crop_year) %>%
    summarize(
      N_kg_ha = sum(N_kg_ha, na.rm = TRUE),
      .groups = "drop"
    )

  # ---- Expand only across actual crop_years for each MGT_combo ----
  n_rate <- crop %>%
    left_join(n_rate_raw, by = c("MGT_combo", "crop_year")) %>%
    mutate(N_kg_ha = round(N_kg_ha, 1)) %>%
    mutate(N_kg_ha = replace_na(N_kg_ha, 0))

  # ---- Add MGT components ----
  n_rate <- n_rate %>%
    left_join(mgt, by = "MGT_combo") %>%
    select(
      MGT_combo, MGT_study, MGT_farm, MGT_field, MGT_trt,
      crop_year, N_kg_ha
    )

  n_rate
}
