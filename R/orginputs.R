#' Compute the Organic Inputs sub-index
#'
#' Share of years with an organic amendment or grazing animals, scaled 0-100.
#'
#' @details
#' For every calendar year from `rot_start_yr` to `rot_end_yr`, a year counts
#' if it has an amendment with `SA_cat == "Organic"`, or animals: every
#' calendar year overlapped by an animal period (`AD_start_date` to
#' `AD_end_date`; a period without an end date counts in its start year).
#' Only presence is scored, not amounts. A unit with no organic amendments or
#' animals scores 0.
#'
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start_yr` and
#'   `rot_end_yr`.
#' @param amend Amendment events with `MGT_combo`, `SA_date` and `SA_cat`.
#' @param animal Animal events with `MGT_combo`, `AD_start_date` and
#'   `AD_end_date`.
#'
#' @return A tibble with `MGT_combo` and `OrgInput` (0-100), one row per unit
#'   in `rot_bounds`.
#'
#' @seealso [build_shmi()]
#'
#' @examples
#' rot_bounds <- data.frame(MGT_combo = "field_1", rot_start_yr = 2019, rot_end_yr = 2020)
#' amend <- data.frame(MGT_combo = "field_1", SA_date = as.Date("2019-04-01"), SA_cat = "Organic")
#' animal <- data.frame(MGT_combo = character(), AD_start_date = as.Date(character()),
#'                      AD_end_date = as.Date(character()))
#' compute_orginput(rot_bounds, amend, animal)   # 50: one of two years
#'
#' @export
compute_orginput <- function(rot_bounds, amend, animal) {
  if (!"AD_end_date" %in% names(animal)) animal$AD_end_date <- as.Date(NA)
  comp <- compute_orginput_components(rot_bounds, amend, animal)
  tibble::tibble(MGT_combo = comp$MGT_combo, OrgInput = 100 * comp$p_any)
}
