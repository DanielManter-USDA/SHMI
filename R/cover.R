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
#' A unit in `rot_bounds` with no plant windows (for example a fallow
#' reference site) scores 0.
#'
#' @param crop Species episodes with `MGT_combo`, `CD_name`, `crop_start`,
#'   and `crop_end`, as in `prepare_shmi_inputs()$crop`.
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start`, and
#'   `rot_end`.
#' @param w_winter,w_spring,w_summer,w_fall Season weights. Defaults are the
#'   official values.
#'
#' @return A data frame with `MGT_combo` and `Cover` (0-100), one row per
#'   unit in `rot_bounds`.
#'
#' @seealso [build_shmi()], [compute_diversity()]
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
    w_fall   = 0.3726
) {

  # -------------------------------------------------------------------------
  # 1. Plant windows: all non-fallow species episodes
  #    Fallow episodes contribute no plant-days; they only matter for
  #    rotation bounds, which are already set in prepare_shmi_inputs().
  # -------------------------------------------------------------------------
  plant_windows <- crop %>%
    dplyr::filter(!tolower(CD_name) %in% c("fallow", "none", "bare"),
                  !is.na(crop_start), !is.na(crop_end)) %>%
    dplyr::select(MGT_combo, crop_start, crop_end)

  # -------------------------------------------------------------------------
  # 2-4. Union of overlapping windows, daily expansion, plant-days per season
  #    Mixtures, relays, and intercrops overlap; each covered day counts once.
  #    If there are no plant windows at all, every unit gets zero plant-days
  #    via the join in step 6 (skipping avoids min()/max() on empty input).
  # -------------------------------------------------------------------------
  if (nrow(plant_windows) == 0) {

    season_counts <- tibble::tibble(
      MGT_combo  = character(),
      season     = character(),
      plant_days = integer()
    )

  } else {

    merged <- plant_windows %>%
      dplyr::arrange(MGT_combo, crop_start, crop_end) %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::mutate(
        run_end = as.Date(cummax(as.numeric(crop_end)), origin = "1970-01-01"),
        block   = cumsum(c(TRUE, crop_start[-1] > run_end[-dplyr::n()]))
      ) %>%
      dplyr::group_by(MGT_combo, block) %>%
      dplyr::summarize(
        crop_start = min(crop_start),
        crop_end   = max(crop_end),
        .groups = "drop"
      )

    season_counts <- merged %>%
      dplyr::mutate(n_days = as.integer(crop_end - crop_start) + 1L) %>%
      tidyr::uncount(n_days, .id = "k") %>%
      dplyr::mutate(
        date   = crop_start + (k - 1L),
        season = .season(lubridate::month(date))
      ) %>%
      dplyr::count(MGT_combo, season, name = "plant_days")
  }

  # -------------------------------------------------------------------------
  # 5. Expand rotation bounds into daily rows
  # -------------------------------------------------------------------------
  rot_days <- rot_bounds %>%
    mutate(
      rot_start = as.Date(rot_start),
      rot_end   = as.Date(rot_end),
      n_days = as.integer(rot_end - rot_start) + 1L
    ) %>%
    tidyr::uncount(n_days) %>%
    group_by(MGT_combo) %>%
    mutate(date = rot_start + (row_number() - 1L)) %>%
    ungroup() %>%
    mutate(season = .season(lubridate::month(date))) %>%
    count(MGT_combo, season, name = "days_possible")

  # -------------------------------------------------------------------------
  # 6. Merge plant-days and possible-days
  # -------------------------------------------------------------------------
  season_totals <- full_join(
    season_counts,
    rot_days,
    by = c("MGT_combo", "season")
  ) %>%
    replace_na(list(plant_days = 0, days_possible = 0))

  # -------------------------------------------------------------------------
  # 7. Compute seasonal proportions
  # -------------------------------------------------------------------------
  season_totals <- season_totals %>%
    mutate(
      prop = if_else(days_possible > 0,
                     plant_days / days_possible,
                     0)
    )

  # -------------------------------------------------------------------------
  # 8. Normalize seasonal weights
  # -------------------------------------------------------------------------
  w_sum <- w_winter + w_spring + w_summer + w_fall
  w <- c(
    winter = w_winter / w_sum,
    spring = w_spring / w_sum,
    summer = w_summer / w_sum,
    fall   = w_fall   / w_sum
  )

  # -------------------------------------------------------------------------
  # 9. Weighted cover score
  # -------------------------------------------------------------------------
  cover <- season_totals %>%
    mutate(weight = w[season]) %>%
    group_by(MGT_combo) %>%
    summarize(
      Cover = 100 * sum(weight * prop),
      .groups = "drop"
    )

  cover
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
