#' Compute the SHMI Cover Sub‑index (Season‑Weighted Plant Presence)
#'
#' Computes the SHMI cover indicator for each management unit (`MGT_combo`)
#' using crop start/end dates and rotation bounds. Cover represents the
#' proportion of the rotation during which living plant cover is present,
#' weighted by season to reflect differential ecological importance.
#'
#' ## Mixture‑aware cover windows
#'
#' The input `crop` table contains one row per crop species. Mixtures therefore
#' appear as multiple rows with identical `CD_seq_num` values. For cover
#' scoring, mixtures must be treated as a *single* planting event. The function
#' collapses mixtures by grouping on:
#'
#' \itemize{
#'   \item \code{MGT_combo}
#'   \item \code{CD_seq_num}
#' }
#'
#' and computing:
#'
#' \itemize{
#'   \item earliest \code{crop_start}
#'   \item latest   \code{crop_end}
#' }
#'
#' This produces one cover window per planting event, regardless of mixture
#' complexity.
#'
#'
#' ## Daily plant‑presence expansion
#'
#' Each cover window is expanded into daily records. Each day is assigned to a
#' season based on calendar month:
#'
#' \itemize{
#'   \item Winter: December–February
#'   \item Spring: March–May
#'   \item Summer: June–August
#'   \item Fall:   September–November
#' }
#'
#' Seasonal plant‑days are counted for each management unit.
#'
#'
#' ## Rotation‑based normalization
#'
#' Rotation bounds (`rot_start`, `rot_end`) are expanded into daily records to
#' compute the number of *possible* days in each season. Seasonal cover
#' proportion is:
#'
#' \deqn{
#'   p_{season} = \frac{\text{plant-days}}{\text{possible-days}}
#' }
#'
#' Seasons with zero possible days contribute zero.
#'
#'
#' ## Seasonal weighting and scaling
#'
#' Seasonal proportions are combined using user‑specified weights:
#'
#' \itemize{
#'   \item \code{w_winter}
#'   \item \code{w_spring}
#'   \item \code{w_summer}
#'   \item \code{w_fall}
#' }
#'
#' Weights are normalized to sum to 1. The final cover score is:
#'
#' \deqn{
#'   \text{Cover} = 100 \times \sum_{season} w_{season} \, p_{season}
#' }
#'
#' yielding a value in \code{[0, 100]}.
#'
#'
#' @param crop A data frame containing one row per crop species with harmonized
#'   start/end dates, including:
#'   \itemize{
#'     \item \code{MGT_combo} — management unit identifier
#'     \item \code{CD_seq_num} — planting event identifier
#'     \item \code{crop_start}, \code{crop_end} — daily cover interval
#'   }
#'
#' @param rot_bounds A data frame containing rotation bounds for each
#'   management unit, with:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{rot_start}
#'     \item \code{rot_end}
#'   }
#'
#' @param w_winter Weight for winter cover (default 0.130).
#' @param w_spring Weight for spring cover (default 0.129).
#' @param w_summer Weight for summer cover (default 0.513).
#' @param w_fall   Weight for fall cover   (default 0.227).
#'
#' @return A data frame with:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{Cover} — SHMI cover score (0–100)
#'   }
#'
#' @export
compute_cover <- function(
    crop,
    rot_bounds,
    w_winter = 0.130,
    w_spring = 0.129,
    w_summer = 0.513,
    w_fall   = 0.227
) {

  # -------------------------------------------------------------------------
  # 0. Tag fallow rows in the original crop table
  # -------------------------------------------------------------------------
  crop <- crop %>%
    mutate(is_fallow = tolower(CD_name) %in% c("fallow", "none", "bare"))

  # -------------------------------------------------------------------------
  # 1. Collapse mixtures into cover windows (preserve fallow flag)
  # -------------------------------------------------------------------------
  cover_windows <- crop %>%
    group_by(MGT_combo, CD_seq_num) %>%
    summarize(
      crop_start = min(crop_start, na.rm = TRUE),
      crop_end   = max(crop_end,   na.rm = TRUE),
      is_fallow  = any(is_fallow),
      .groups = "drop"
    )

  # -------------------------------------------------------------------------
  # 2. Add synthetic fallow windows for sites with no crop rows
  # -------------------------------------------------------------------------
  all_sites <- rot_bounds %>% distinct(MGT_combo)
  sites_with_crop <- cover_windows %>% distinct(MGT_combo)
  sites_missing <- anti_join(all_sites, sites_with_crop, by = "MGT_combo")

  synthetic_fallow <- rot_bounds %>%
    semi_join(sites_missing, by = "MGT_combo") %>%
    mutate(
      CD_seq_num = -1L,
      crop_start = rot_start,
      crop_end   = rot_end,
      is_fallow  = TRUE
    ) %>%
    select(MGT_combo, CD_seq_num, crop_start, crop_end, is_fallow)

  cover_windows <- bind_rows(cover_windows, synthetic_fallow)

  # -------------------------------------------------------------------------
  # 3. Expand windows into daily rows
  #    - fallow windows get ONE placeholder day
  #    - non-fallow windows expand normally
  # -------------------------------------------------------------------------
  cover_days <- cover_windows %>%
    mutate(
      n_days = as.integer(crop_end - crop_start) + 1L,
      n_days = if_else(is_fallow, 1L, n_days)   # placeholder row for fallow
    ) %>%
    tidyr::uncount(n_days) %>%
    group_by(MGT_combo, crop_start, crop_end, is_fallow) %>%
    mutate(
      date = if_else(
        is_fallow,
        crop_start,   # placeholder date
        crop_start + (row_number() - 1L)
      )
    ) %>%
    ungroup() %>%
    mutate(
      month = lubridate::month(date),
      season = case_when(
        month %in% c(12, 1, 2)  ~ "winter",
        month %in% c(3, 4, 5)   ~ "spring",
        month %in% c(6, 7, 8)   ~ "summer",
        month %in% c(9, 10, 11) ~ "fall"
      ),
      plant_days = if_else(is_fallow, 0L, 1L)
    )

  # -------------------------------------------------------------------------
  # 4. Count plant-days per season
  # -------------------------------------------------------------------------
  season_counts <- cover_days %>%
    group_by(MGT_combo, season) %>%
    summarize(plant_days = sum(plant_days), .groups = "drop")

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
    mutate(
      month = lubridate::month(date),
      season = case_when(
        month %in% c(12, 1, 2)  ~ "winter",
        month %in% c(3, 4, 5)   ~ "spring",
        month %in% c(6, 7, 8)   ~ "summer",
        month %in% c(9, 10, 11) ~ "fall"
      )
    ) %>%
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
