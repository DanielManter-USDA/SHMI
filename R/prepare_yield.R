#' Prepare harvest-level yields (internal)
#'
#' Converts each crop row that reports a yield to kg/ha. Yield is taken from
#' the raw Crop_Diversity rows (one per harvest), not from crop episodes, so
#' perennial cuttings stay separate and rows with different units are never
#' averaged together.
#'
#' Values that cannot be converted keep their raw value and units, get a
#' `yield_status`, and are reported in the assumptions table. Bushels are
#' converted with a standard test weight for the crop (`lb_per_bu`); crops
#' without one are left unconverted. Bushel-based results are at market
#' moisture, not dry matter, and each conversion is logged.
#'
#' @param crop Raw crop rows (after date parsing and exclusions).
#' @param rot_bounds Final rotation bounds (after overrides); yields dated
#'   outside them are dropped.
#' @return A list with `yield` (one row per harvest row with a yield) and
#'   `assumptions` (one row per unconverted value).
#' @keywords internal
#' @noRd
.prepare_yield <- function(crop, rot_bounds) {

  y <- crop %>%
    dplyr::filter(!is.na(CD_yield)) %>%
    dplyr::mutate(
      yield_date = dplyr::coalesce(CD_harv_date, CD_term_date, CD_plant_date),
      year       = lubridate::year(yield_date)
    ) %>%
    dplyr::inner_join(
      rot_bounds %>% dplyr::select(MGT_combo, rot_start, rot_end),
      by = "MGT_combo"
    ) %>%
    dplyr::filter(yield_date >= rot_start, yield_date <= rot_end)

  conv <- .convert_rate_kg_ha(y$CD_yield, y$CD_yield_units,
                              crop_name = y$CD_name)

  y <- y %>%
    dplyr::mutate(
      yield_kg_ha  = round(conv$value, 1),
      yield_status = conv$status,
      lb_per_bu    = conv$lb_per_bu
    ) %>%
    dplyr::select(MGT_combo, CD_cat, CD_name, yield_date, year,
                  CD_yield, CD_yield_units, yield_kg_ha, yield_status,
                  lb_per_bu)

  # Log unconverted values (checks) and bushel conversions (assumptions)
  flagged <- y %>%
    dplyr::mutate(type = dplyr::case_when(
      yield_status != "converted" ~ paste0("yield_", yield_status),
      !is.na(lb_per_bu)           ~ "yield_bushels_test_weight",
      TRUE                        ~ NA_character_
    )) %>%
    dplyr::filter(!is.na(type))

  assumptions <- tibble::tibble(
    MGT_combo  = flagged$MGT_combo,
    source     = "yield",
    name       = flagged$CD_name,
    date_start = flagged$yield_date,
    date_end   = flagged$yield_date,
    type       = flagged$type
  ) %>%
    .add_assumption_text()

  list(yield = y, assumptions = assumptions)
}
