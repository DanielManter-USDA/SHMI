#' @keywords internal
#' @noRd
.prepare_n_rate <- function(amend) {

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
      year = lubridate::year(SA_date)
    )

  amend <- amend %>%
    group_by(MGT_combo, year) %>%
    summarize(
      N_kg_ha_yr = sum(N_kg_ha, na.rm=TRUE)
    )

  amend
}
