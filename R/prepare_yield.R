#' @keywords internal
#' @noRd
.prepare_yield <- function(path,
                           start_date_override = NULL,
                           end_date_override   = NULL) {

  yield <- .safe_read(
    path,
    "Crop_Diversity",
    required_cols = c("MGT_combo", "CD_seq_num",
                      "CD_plant_date", "CD_term_date",
                      "CD_yield", "CD_yield_units"),
    skip = 3
  )

  # Convert dates
  yield <- yield %>%
    mutate(
      CD_plant_date = as.Date(.parse_shmi_date(CD_plant_date)),
      CD_term_date  = as.Date(.parse_shmi_date(CD_term_date))
    )

  # ---- Window clipping ----
  if (!is.null(start_date_override)) {
    S <- as.Date(start_date_override)

    yield <- yield %>%
      filter(CD_term_date >= S) %>%                 # drop windows ending before S
      mutate(CD_plant_date = pmax(CD_plant_date, S)) # clip overlapping windows
  }

  if (!is.null(end_date_override)) {
    E <- as.Date(end_date_override)

    yield <- yield %>%
      filter(CD_plant_date <= E) %>%                # drop windows starting after E
      mutate(CD_term_date = pmin(CD_term_date, E))  # clip overlapping windows
  }

  # ---- Unit conversion helper ----
  convert_to_kg_ha <- function(value, unit) {

    # If yield is missing, return NA
    if (is.na(value)) return(NA_real_)

    # If unit is missing, warn and return NA
    if (is.na(unit)) {
      warning("Yield unit is NA; returning NA for yield_kg_ha.")
      return(NA_real_)
    }

    unit <- tolower(trimws(unit))

    # Already kg/ha
    if (unit %in% c("kgs/hectare", "kg/ha", "kgs/ha", "kg/hectare"))
      return(value)

    # lbs/hectare
    if (unit %in% c("lbs/hectare", "lb/hectare", "lbs/ha", "lb/ha"))
      return(value * 0.453592)

    # kgs/acre
    if (unit %in% c("kgs/acre", "kg/acre"))
      return(value / 0.404686)

    # lbs/acre
    if (unit %in% c("lbs/acre", "lb/acre"))
      return(value * 0.453592 / 0.404686)

    # Bushels cannot be converted without crop-specific density
    if (grepl("bushel", unit)) {
      stop("Bushel units cannot be converted to kg/ha without crop-specific density.")
    }

    stop(paste("Unknown yield unit:", unit))
  }

  # ---- Apply conversion safely ----
  yield <- yield %>%
    mutate(
      yield_kg_ha = purrr::map2_dbl(CD_yield, CD_yield_units, convert_to_kg_ha)
    ) %>%
    select(MGT_combo, CD_seq_num, CD_name, CD_plant_date, CD_term_date, yield_kg_ha)

  yield
}
