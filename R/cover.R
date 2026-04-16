#' Compute the SHMI Cover Pillar (Season‑Weighted Plant Presence)
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
#' @param w_winter Numeric weight for winter cover (default 0.25).
#' @param w_spring Numeric weight for spring cover (default 0.25).
#' @param w_summer Numeric weight for summer cover (default 0.25).
#' @param w_fall   Numeric weight for fall cover (default 0.25).
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
                          w_winter = 0.25,
                          w_spring = 0.25,
                          w_summer = 0.25,
                          w_fall   = 0.25) {

  # 1. Assign season
  crop_season <- daily %>%
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

  # 2. Plant-days per event
  crop_days <- crop_season %>%
    group_by(MGT_combo, season) %>%
    dplyr::summarize(
      plant_days = sum(crop_present),
      .groups = "drop")

  # 3. Seasonal totals per rotation
  season_totals <- crop_days %>%
    tidyr::pivot_wider(
      names_from = season,
      values_from = plant_days,
      values_fill = 0,
      names_sort = TRUE
    )

  # 4. Rotation length
  rot_bounds <- rot_bounds %>%
    mutate(total_days = as.integer(rot_end - rot_start + 1))

  season_totals <- season_totals %>%
    left_join(rot_bounds, by = "MGT_combo") %>%
    mutate(
      prop_winter = winter / (total_days / 4),
      prop_spring = spring / (total_days / 4),
      prop_summer = summer / (total_days / 4),
      prop_fall   = fall   / (total_days / 4),
      w_sum = w_winter + w_spring + w_summer + w_fall,
      w_winter_n = w_winter / w_sum,
      w_spring_n = w_spring / w_sum,
      w_summer_n = w_summer / w_sum,
      w_fall_n   = w_fall   / w_sum,
      Cover = 100 * (
        w_winter_n * prop_winter +
          w_spring_n * prop_spring +
          w_summer_n * prop_summer +
          w_fall_n   * prop_fall
      )
    ) %>%
    select(MGT_combo, Cover)

}
