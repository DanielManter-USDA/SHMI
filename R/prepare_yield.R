#' @keywords internal
#' @noRd
.prepare_yield <- function(path,
                           start_date_override = NULL,
                           end_date_override   = NULL) {

  # ---- Load MGT_Unit (preserve all components) ----
  mgt <- .safe_read(
    path,
    "Mgt_Unit",
    required_cols = c("MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt"),
    skip = 3
  )

  # ---- Load yield from Crop_Diversity ----
  yield <- .safe_read(
    path,
    "Crop_Diversity",
    required_cols = c("MGT_combo", "CD_seq_num",
                      "CD_plant_date", "CD_term_date",
                      "CD_yield", "CD_yield_units"),
    skip = 3
  )

  # CD_harv_date is optional
  if (!"CD_harv_date" %in% names(yield)) {
    yield$CD_harv_date <- NA
  }

  # CD_name is optional but needed downstream
  if (!"CD_name" %in% names(yield)) {
    yield$CD_name <- NA_character_
  }

  # ---- Convert dates ----
  yield <- yield %>%
    mutate(
      CD_plant_date = as.Date(.parse_shmi_date(CD_plant_date)),
      CD_term_date  = as.Date(.parse_shmi_date(CD_term_date)),
      CD_harv_date  = as.Date(.parse_shmi_date(CD_harv_date))
    )

  # ---- Assign crop_year (harvest preferred, else termination) ----
  yield <- yield %>%
    mutate(
      crop_year = dplyr::coalesce(
        lubridate::year(CD_harv_date),
        lubridate::year(CD_term_date)
      )
    )

  # ---- Window clipping ----
  if (!is.null(start_date_override)) {
    S <- as.Date(start_date_override)
    yield <- yield %>%
      filter(CD_term_date >= S) %>%
      mutate(CD_plant_date = pmax(CD_plant_date, S))
  }

  if (!is.null(end_date_override)) {
    E <- as.Date(end_date_override)
    yield <- yield %>%
      filter(CD_plant_date <= E) %>%
      mutate(CD_term_date = pmin(CD_term_date, E))
  }

  # ---- Unit conversion helper ----
  convert_to_kg_ha <- function(value, unit) {

    if (is.na(value)) return(NA_real_)
    if (is.na(unit)) return(NA_real_)

    unit <- tolower(trimws(unit))

    if (unit %in% c("kgs/hectare", "kg/ha", "kgs/ha", "kg/hectare"))
      return(value)

    if (unit %in% c("lbs/hectare", "lb/hectare", "lbs/ha", "lb/ha"))
      return(value * 0.453592)

    if (unit %in% c("kgs/acre", "kg/acre"))
      return(value / 0.404686)

    if (unit %in% c("lbs/acre", "lb/acre"))
      return(value * 0.453592 / 0.404686)

    if (grepl("bushel", unit))
      stop("Bushel units cannot be converted to kg/ha without crop-specific density.")

    stop(paste("Unknown yield unit:", unit))
  }

  # ---- Convert yield units ----
  yield <- yield %>%
    mutate(
      yield_kg_ha = purrr::map2_dbl(CD_yield, CD_yield_units, convert_to_kg_ha)
    ) %>%
    mutate(yield_kg_ha = round(yield_kg_ha, 1))

  # ---- Join MGT components (preserve structure) ----
  yield <- yield %>%
    left_join(mgt, by = "MGT_combo") %>%
    select(
      MGT_combo, MGT_study, MGT_farm, MGT_field, MGT_trt,
      CD_seq_num, CD_name,
      CD_plant_date, CD_harv_date, CD_term_date,
      crop_year, yield_kg_ha
    )

  yield
}
