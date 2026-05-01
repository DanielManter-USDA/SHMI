#' @keywords internal
#' @noRd
.prepare_n_rate <- function(path,
                            start_date_override = NULL,
                            end_date_override   = NULL) {

  amend <- .safe_read(
    path,
    "Soil_Amendments",
    required_cols = c("MGT_combo", "SA_date", "SA_N", "SA_units"),
    skip = 3
  )

  # Convert dates
  amend <- amend %>%
    mutate(
      SA_date = as.Date(.parse_shmi_date(SA_date))
    )

  # ---- Clip by overrides (instantaneous events) ----
  if (!is.null(start_date_override)) {
    S <- as.Date(start_date_override)
    amend <- amend %>% filter(SA_date >= S)
  }

  if (!is.null(end_date_override)) {
    E <- as.Date(end_date_override)
    amend <- amend %>% filter(SA_date <= E)
  }

  # ---- Unit conversion helper ----
  convert_n_to_kg_ha <- function(value, unit) {

    # If N is missing, return NA
    if (is.na(value)) return(NA_real_)

    # If unit is missing, warn and return NA
    if (is.na(unit)) {
      warning("SA_units is NA; returning NA for N_kg_ha.")
      return(NA_real_)
    }

    unit <- tolower(trimws(unit))

    # kg/ha
    if (unit %in% c("kgs/hectare", "kg/ha", "kgs/ha", "kg/hectare"))
      return(value)

    # tonnes/hectare
    if (unit %in% c("tonnes/hectare", "t/ha"))
      return(value * 1000)

    # lbs/acre
    if (unit %in% c("lbs/acre", "lb/acre"))
      return(value * 0.453592 / 0.404686)

    # tons/acre (US ton)
    if (unit %in% c("tons/acre", "ton/acre"))
      return(value * 907.185 / 0.404686)

    stop(paste("Unknown SA_units:", unit))
  }

  # ---- Convert SA_N to kg/ha ----
  amend <- amend %>%
    mutate(
      N_kg_ha = purrr::map2_dbl(SA_N, SA_units, convert_n_to_kg_ha),
      year    = lubridate::year(SA_date)
    )

  # ---- Summarize by MGT_combo × year ----
  n_rate <- amend %>%
    group_by(MGT_combo, year) %>%
    summarize(
      N_kg_ha = sum(N_kg_ha, na.rm = TRUE),
      .groups = "drop"
    )

  # ---- If a year has no N applied, return 0 ----
  # (This is important for N0 treatments)
  # We do NOT fill missing years here; build_shmi() will merge and fill zeros.

  n_rate
}
