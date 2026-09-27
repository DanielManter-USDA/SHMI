#' Prepare annual nitrogen rates (internal)
#'
#' Converts each amendment's `SA_N` to kg N/ha using `SA_units`, then sums per
#' `MGT_combo` x year.
#'
#' \itemize{
#'   \item Amendments without an `SA_N` value are not included, so a year with
#'         amendments but no N information is absent (unknown), not zero.
#'   \item If no amendment in a year could be converted, `N_kg_ha_yr` is NA.
#'   \item If only some could be converted, the total is a lower bound;
#'         `n_unconverted` counts the rest.
#' }
#'
#' Unconverted values and implausibly high rates are reported in the
#' assumptions table.
#'
#' @param amend Amendment events (after overrides).
#' @param max_plausible_kg_ha Converted N rates above this are flagged.
#' @return A list with `n_rate` (one row per unit-year) and `assumptions`.
#' @keywords internal
#' @noRd
.prepare_n_rate <- function(amend, max_plausible_kg_ha = 1000) {

  a <- amend %>%
    dplyr::filter(!is.na(SA_N))

  conv <- .convert_rate_kg_ha(a$SA_N, a$SA_units)

  a <- a %>%
    dplyr::mutate(
      N_kg_ha  = conv$value,
      n_status = conv$status,
      year     = lubridate::year(SA_date)
    )

  n_rate <- a %>%
    dplyr::group_by(MGT_combo, year) %>%
    dplyr::summarize(
      N_kg_ha_yr    = if (all(is.na(N_kg_ha))) NA_real_ else sum(N_kg_ha, na.rm = TRUE),
      n_events      = dplyr::n(),
      n_unconverted = sum(n_status != "converted"),
      .groups = "drop"
    )

  src <- if ("SA_source" %in% names(a)) as.character(a$SA_source) else rep(NA_character_, nrow(a))

  flags <- tibble::tibble(
    MGT_combo  = a$MGT_combo,
    source     = "n_rate",
    name       = src,
    date_start = a$SA_date,
    date_end   = a$SA_date,
    type       = dplyr::case_when(
      a$n_status == "no_value"                       ~ "n_not_numeric",
      a$n_status == "missing_units"                  ~ "n_missing_units",
      a$n_status %in% c("unknown_units",
                        "bushels_not_converted")     ~ "n_unknown_units",
      a$n_status == "converted" &
        a$N_kg_ha > max_plausible_kg_ha              ~ "n_rate_implausible",
      TRUE                                           ~ NA_character_
    )
  ) %>%
    dplyr::filter(!is.na(type)) %>%
    .add_assumption_text()

  list(n_rate = n_rate, assumptions = flags)
}
