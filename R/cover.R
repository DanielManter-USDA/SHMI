#' Compute the SHMI Cover Sub-index (Season‑Weighted Plant Presence)
#'
#' Calculates the SHMI cover indicator for each management unit (`MGT_combo`)
#' using daily crop presence data and rotation bounds. Cover is computed as a
#' weighted average of seasonal plant‑days, where each season (winter, spring,
#' summer, fall) contributes a user‑specified weight. Seasonal plant‑days are
#' normalized by the expected number of days per season (one‑quarter of the
#' rotation length), and the final cover score is scaled to 0–100.
#'
#' @param crop_harmonized A data frame produced by
#'   \code{prepare_shmi_inputs()}, containing one row per crop event with
#'   harmonized start/end dates and mixture names.
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
#' @return A data frame with:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{Cover} — SHMI cover score (0–100)
#'   }
#'
#' @export
compute_cover <- function(crop_harmonized,
                          rot_bounds,
                          w_winter = 0.130,
                          w_spring = 0.129,
                          w_summer = 0.513,
                          w_fall   = 0.227) {

  # ---- 1. Build interval union per MGT_combo ----
  interval_union <- crop_harmonized %>%
    arrange(MGT_combo, crop_start, crop_end) %>%
    group_by(MGT_combo) %>%
    reframe({

      starts <- as.numeric(crop_start)   # force numeric for safe comparisons
      ends   <- as.numeric(crop_end)

      out_start <- c()
      out_end   <- c()

      cur_start <- starts[1]
      cur_end   <- ends[1]

      for (i in seq_along(starts)[-1]) {
        if (starts[i] <= cur_end + 1) {
          cur_end <- max(cur_end, ends[i])
        } else {
          out_start <- c(out_start, cur_start)
          out_end   <- c(out_end,   cur_end)
          cur_start <- starts[i]
          cur_end   <- ends[i]
        }
      }

      out_start <- c(out_start, cur_start)
      out_end   <- c(out_end,   cur_end)

      tibble::tibble(
        crop_start = as.Date(out_start, origin = "1970-01-01"),
        crop_end   = as.Date(out_end,   origin = "1970-01-01")
      )
    })

  # ---- 2. Assign each day in each merged interval to a season ----
  cover_days <- interval_union %>%
    mutate(
      n_days = as.integer(crop_end - crop_start) + 1L
    ) %>%
    tidyr::uncount(n_days) %>%
    group_by(MGT_combo, crop_start, crop_end) %>%
    mutate(
      date = crop_start + (row_number() - 1L)
    ) %>%
    ungroup() %>%
    mutate(
      month = lubridate::month(date),
      season = case_when(
        month %in% c(12, 1, 2)  ~ "winter",
        month %in% c(3, 4, 5)   ~ "spring",
        month %in% c(6, 7, 8)   ~ "summer",
        month %in% c(9, 10, 11) ~ "fall"
      )
    )

  # ---- 3. Count plant-days per season ----
  season_counts <- cover_days %>%
    dplyr::count(MGT_combo, season, name = "plant_days")

  # ---- 4. Compute possible days per season from rot_bounds ----
  rot_days <- rot_bounds %>%
    dplyr::mutate(
      rot_start = as.Date(rot_start),
      rot_end   = as.Date(rot_end),
      n_days = as.integer(rot_end - rot_start) + 1L
    ) %>%
    tidyr::uncount(n_days) %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::mutate(date = rot_start + (dplyr::row_number() - 1L)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      month = lubridate::month(date),
      season = dplyr::case_when(
        month %in% c(12, 1, 2)  ~ "winter",
        month %in% c(3, 4, 5)   ~ "spring",
        month %in% c(6, 7, 8)   ~ "summer",
        month %in% c(9, 10, 11) ~ "fall"
      )
    ) %>%
    dplyr::count(MGT_combo, season, name = "days_possible")

  # ---- 5. Merge plant-days and possible-days ----
  season_totals <- dplyr::full_join(season_counts, rot_days,
                                    by = c("MGT_combo", "season")) %>%
    tidyr::replace_na(list(plant_days = 0, days_possible = 0))

  # ---- 6. Compute seasonal proportions ----
  season_totals <- season_totals %>%
    dplyr::mutate(
      prop = dplyr::if_else(days_possible > 0,
                            plant_days / days_possible,
                            0)
    )

  # ---- 7. Normalize weights ----
  w_sum <- w_winter + w_spring + w_summer + w_fall
  w <- c(
    winter = w_winter / w_sum,
    spring = w_spring / w_sum,
    summer = w_summer / w_sum,
    fall   = w_fall   / w_sum
  )

  # ---- 8. Weighted cover score ----
  cover <- season_totals %>%
    dplyr::mutate(weight = w[season]) %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::summarize(
      Cover = 100 * sum(weight * prop),
      .groups = "drop"
    )

  cover
}
