#' Compute the SHMI Cover Sub-index (Season‑Weighted Plant Presence)
#'
#' Calculates the SHMI cover indicator for each management unit (`MGT_combo`)
#' using daily crop presence data and rotation bounds. Cover is computed as a
#' weighted average of seasonal plant‑days, where each season (winter, spring,
#' summer, fall) contributes a user‑specified weight. Seasonal plant‑days are
#' normalized by the expected number of days per season (one‑quarter of the
#' rotation length), and the final cover score is scaled to 0–100.
#'
#' @param daily A daily data frame produced by \code{prepare_shmi_inputs()},
#'   containing at least:
#'   \itemize{
#'     \item \code{MGT_combo} — management unit identifier
#'     \item \code{date} — calendar date
#'     \item \code{crop_present} — 1 if a crop is present, 0 otherwise
#'     \item \code{CD_name} — crop name (used to treat "fallow" as 0 cover)
#'   }
#'
#' @param rot_bounds A data frame with rotation start and end dates for each
#'   \code{MGT_combo}, containing:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{rot_start}
#'     \item \code{rot_end}
#'   }
#'
#' @param w_winter Numeric weight for winter cover (default 0.130).
#' @param w_spring Numeric weight for spring cover (default 0.129).
#' @param w_summer Numeric weight for summer cover (default 0.513).
#' @param w_fall   Numeric weight for fall cover (default 0.227).
#'
#' @details
#' The algorithm proceeds in four steps:
#' \enumerate{
#'   \item Assign each daily record to a season based on calendar month.
#'   \item Sum plant‑days within each season for each \code{MGT_combo}.
#'   \item Normalize seasonal totals by one‑quarter of the rotation length.
#'   \item Apply seasonal weights and scale the final cover score to 0–100.
#' }
#'
#' Days where \code{CD_name == "fallow"} are treated as zero cover.
#'
#' @return A data frame with one row per \code{MGT_combo} and a single column:
#'   \itemize{
#'     \item \code{Cover} — SHMI cover score (0–100)
#'   }
#'
#' @export
compute_cover <- function(daily,
                          rot_bounds,
                          w_winter = 0.130,
                          w_spring = 0.129,
                          w_summer = 0.513,
                          w_fall   = 0.227) {

  # 1. Collapse to one row per day per field
  crop_season <- daily %>%
    dplyr::mutate(
      crop_present = dplyr::coalesce(crop_present, 0L)  # convert NA → 0
    ) %>%
    dplyr::group_by(MGT_combo, date) %>%
    dplyr::summarize(
      crop_present = as.integer(any(crop_present == 1L)),  # TRUE if ANY crop present
      CD_name = dplyr::first(CD_name),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      month = lubridate::month(date),
      season = dplyr::case_when(
        month %in% c(12, 1, 2)  ~ "winter",
        month %in% c(3, 4, 5)   ~ "spring",
        month %in% c(6, 7, 8)   ~ "summer",
        month %in% c(9, 10, 11) ~ "fall"
      ),
      crop_present = dplyr::case_when(
        CD_name == "fallow" ~ 0L,
        TRUE ~ crop_present
      )
    )


  # 2. Compute plant-days and possible days per season
  crop_days <- crop_season %>%
    dplyr::group_by(MGT_combo, season) %>%
    dplyr::summarize(
      plant_days = sum(crop_present),
      days_possible = dplyr::n(),
      .groups = "drop"
    )

  # 3. Pivot to wide format
  season_totals <- crop_days %>%
    tidyr::pivot_wider(
      names_from = season,
      values_from = c(plant_days, days_possible),
      values_fill = 0,
      names_sort = TRUE
    )

  # 4. Compute seasonal proportions (bounded 0–1)
  season_totals <- season_totals %>%
    dplyr::mutate(
      prop_winter = plant_days_winter / days_possible_winter,
      prop_spring = plant_days_spring / days_possible_spring,
      prop_summer = plant_days_summer / days_possible_summer,
      prop_fall   = plant_days_fall   / days_possible_fall
    ) %>%
    dplyr::mutate(
      prop_winter = dplyr::if_else(is.nan(prop_winter), 0, prop_winter),
      prop_spring = dplyr::if_else(is.nan(prop_spring), 0, prop_spring),
      prop_summer = dplyr::if_else(is.nan(prop_summer), 0, prop_summer),
      prop_fall   = dplyr::if_else(is.nan(prop_fall),   0, prop_fall)
    )

  # 5. Normalize weights
  w_sum <- w_winter + w_spring + w_summer + w_fall
  w_winter_n <- w_winter / w_sum
  w_spring_n <- w_spring / w_sum
  w_summer_n <- w_summer / w_sum
  w_fall_n   <- w_fall   / w_sum

  # 6. Weighted cover score (guaranteed 0–100)
  season_totals <- season_totals %>%
    dplyr::mutate(
      Cover = 100 * (
        w_winter_n * prop_winter +
          w_spring_n * prop_spring +
          w_summer_n * prop_summer +
          w_fall_n   * prop_fall
      )
    ) %>%
    dplyr::select(MGT_combo, Cover)

  season_totals
}
