#' Compute the Organic Inputs sub-index
#'
#' Proportion of rotation years with organic amendments and with animals,
#' weighted and scaled 0-100.
#'
#' @details
#' For every calendar year from `rot_start_yr` to `rot_end_yr`, a year counts
#' as having an amendment if any amendment with `SA_cat == "Organic"` is
#' dated in that year, and as having animals if any animal period starts in
#' that year (`AD_start_date`). Only presence is scored; amounts are not
#' used. With \eqn{p} the proportion of years with each input,
#' \deqn{OrgInput = 100 \frac{w_{amend} p_{amend} + w_{animal} p_{animal}}{w_{amend} + w_{animal}}}
#'
#' A missing record means no input: a unit with no organic amendments or
#' animals scores 0.
#'
#' With `animal_presence = "span"`, every calendar year overlapped by an
#' animal period (`AD_start_date` to `AD_end_date`) counts, so continuous
#' multi-year grazing is scored in every year rather than only its first.
#'
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start_yr`, and
#'   `rot_end_yr`.
#' @param amend Amendment events with `MGT_combo`, `SA_date`, and `SA_cat`.
#' @param animal Animal events with `MGT_combo` and `AD_start_date`.
#' @param w_amend,w_animal Weights for amendments and animals. Defaults are
#'   the official values.
#' @param animal_presence `"start"` (SHMI <= 1.1.0) or `"span"`; see
#'   [compute_orginput_components()].
#'
#' @return A data frame with `MGT_combo` and `OrgInput` (0-100), one row per
#'   unit in `rot_bounds`.
#'
#' @seealso [compute_orginput_components()], [build_shmi()]
#'
#' @examples
#' rot_bounds <- data.frame(MGT_combo = "field_1",
#'                          rot_start_yr = 2019, rot_end_yr = 2020)
#' amend <- data.frame(MGT_combo = "field_1",
#'                     SA_date = as.Date("2019-04-01"), SA_cat = "Organic")
#' animal <- data.frame(MGT_combo = character(),
#'                      AD_start_date = as.Date(character()))
#' compute_orginput(rot_bounds, amend, animal)
#'
#' @export
compute_orginput <- function(rot_bounds,
                             amend,
                             animal,
                             w_amend = 0.6615,
                             w_animal = 0.3385,
                             animal_presence = c("start", "span")) {
  animal_presence <- match.arg(animal_presence)
  w <- c(w_amend, w_animal)
  if (any(!is.finite(w)) || any(w < 0) || sum(w) <= 0) {
    stop("w_amend and w_animal must be finite, non-negative, and not both zero.")
  }

  comp <- compute_orginput_components(rot_bounds, amend, animal,
                                      animal_presence = animal_presence)

  tibble::tibble(
    MGT_combo = comp$MGT_combo,
    OrgInput  = 100 * (w_amend * comp$p_amend + w_animal * comp$p_animal) / sum(w)
  )
}
