#' Compute the Cover sub-index
#'
#' Season-weighted proportion of days in the rotation with living plant
#' cover, scaled 0-100.
#'
#' @details
#' **Plant windows.** Every row of `crop` (one row per species episode) is a
#' window of living cover, except rows named `"fallow"`, `"none"`, or
#' `"bare"`. Overlapping windows (mixtures, relays, intercrops) are merged, so
#' each day counts once however many species are present.
#'
#' **Seasons.** Each day is assigned to a season by calendar month: winter
#' (Dec-Feb), spring (Mar-May), summer (Jun-Aug), and fall (Sep-Nov). For each
#' season \eqn{s}, \eqn{p_s} is the number of plant days divided by the number
#' of days of that season in the rotation; seasons with no days in the
#' rotation contribute 0.
#'
#' **Score.** The season weights are rescaled to sum to 1, and
#' \deqn{Cover = 100 \sum_s w_s p_s}
#'
#' **Rotation window.** Days in the rotation run from `rot_start` to
#' `rot_end`. In [prepare_shmi_inputs()] these span the first to the last
#' recorded event, or the window set by `start_date_override` and
#' `end_date_override`, which is how a fixed evaluation period is imposed.
#'
#' Only plant days inside `rot_start`-`rot_end` count
#' when `clip_to_rotation = TRUE` (the default from 1.2.0). SHMI <= 1.1.0
#' counted every day of an episode, including days outside the rotation,
#' against the rotation's season lengths, so a season's proportion could
#' exceed 1 when episodes extended past the evaluation window.
#'
#' A unit in `rot_bounds` with no plant windows (for example a fallow
#' reference site) scores 0.
#'
#' @param crop Species episodes with `MGT_combo`, `CD_name`, `crop_start`,
#'   and `crop_end`, as in `prepare_shmi_inputs()$crop`.
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start`, and
#'   `rot_end`.
#' @param w_winter,w_spring,w_summer,w_fall Season weights. Defaults are the
#'   official values.
#' @param clip_to_rotation Logical; see *Rotation window*. `FALSE` reproduces
#'   SHMI <= 1.1.0.
#'
#' @return A data frame with `MGT_combo` and `Cover` (0-100), one row per
#'   unit in `rot_bounds`.
#'
#' @seealso [compute_cover_components()], [build_shmi()], [compute_diversity()]
#'
#' @examples
#' crop <- data.frame(
#'   MGT_combo  = "field_1",
#'   CD_name    = c("Corn", "Rye"),
#'   crop_start = as.Date(c("2020-05-01", "2020-10-15")),
#'   crop_end   = as.Date(c("2020-09-30", "2020-12-31"))
#' )
#' rot_bounds <- data.frame(
#'   MGT_combo = "field_1",
#'   rot_start = as.Date("2020-01-01"),
#'   rot_end   = as.Date("2020-12-31")
#' )
#' compute_cover(crop, rot_bounds)
#'
#' @export
compute_cover <- function(
    crop,
    rot_bounds,
    w_winter = 0.1259,
    w_spring = 0.1260,
    w_summer = 0.3755,
    w_fall   = 0.3726,
    clip_to_rotation = TRUE
) {
  w <- c(w_winter, w_spring, w_summer, w_fall)
  if (any(!is.finite(w)) || any(w < 0) || sum(w) <= 0) {
    stop("Season weights must be finite, non-negative, and not all zero.")
  }
  w <- w / sum(w)

  comp <- compute_cover_components(crop, rot_bounds, clip_to_rotation = clip_to_rotation)
  P <- as.matrix(comp[, c("p_winter", "p_spring", "p_summer", "p_fall")])

  tibble::tibble(MGT_combo = comp$MGT_combo, Cover = 100 * as.vector(P %*% w))
}


# Map month number to season (Dec-Feb winter, Mar-May spring, etc.)
.season <- function(month) {
  dplyr::case_when(
    month %in% c(12, 1, 2)  ~ "winter",
    month %in% c(3, 4, 5)   ~ "spring",
    month %in% c(6, 7, 8)   ~ "summer",
    month %in% c(9, 10, 11) ~ "fall"
  )
}
