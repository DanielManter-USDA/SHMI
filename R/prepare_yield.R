#' @keywords internal
#' @noRd
.prepare_yield <- function(crop) {

  # ---- Convert units ----
  convert_to_kg_ha <- function(value, unit) {
    if (is.na(value) || is.na(unit)) return(NA_real_)
    unit <- tolower(trimws(unit))

    if (unit %in% c("kg/ha", "kgs/ha", "kgs/hectare", "kg/hectare"))
      return(value)

    if (unit %in% c("lbs/ha", "lb/ha", "lbs/hectare", "lb/hectare"))
      return(value * 0.453592)

    if (unit %in% c("kg/acre", "kgs/acre"))
      return(value / 0.404686)

    if (unit %in% c("lbs/acre", "lb/acre"))
      return(value * 0.453592 / 0.404686)

    if (grepl("bushel", unit))
      return(NA_real_)  # cannot convert

    return(NA_real_)
  }

  yield <- crop %>%
    mutate(
      yield_kg_ha = map2_dbl(CD_yield, CD_yield_units, convert_to_kg_ha),
      yield_kg_ha = round(yield_kg_ha, 1)
    )

  yield <- yield %>%
    mutate(
      year = coalesce(
        year(crop_end),
        year(crop_start)
      )
    ) %>%
    select(MGT_combo, CD_seq_num, CD_cat, CD_name, year, yield_kg_ha)

  yield
}
