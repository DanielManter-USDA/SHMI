#' Compute Mechanistic Inverse Disturbance (Mixing-Efficiency × Depth Metric)
#'
#' Calculates the SHMI disturbance pillar for each management unit
#' (`MGT_combo`) using a mechanistic soil-mixing model based on mixing
#' efficiency and tillage depth. Disturbance is computed at the *annual* scale
#' and then averaged across the rotation. The final inverse-disturbance score
#' is scaled to 0–100.
#'
#' @param daily_dist A daily disturbance table produced by
#'   \code{prepare_shmi_inputs()}, containing:
#'   \itemize{
#'     \item \code{MGT_combo} — management unit identifier
#'     \item \code{date} — calendar date
#'     \item \code{SD_mixeff} — mixing efficiency (0–1)
#'     \item \code{SD_depth_cm} — tillage depth in cm (already capped at 30)
#'   }
#'
#' @param rot_bounds A data frame with rotation bounds for each management
#'   unit, containing:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{rot_start}
#'     \item \code{rot_end}
#'   }
#'
#' @details
#' Disturbance is computed using a mechanistic soil-mixing model:
#'
#' \enumerate{
#'   \item \strong{Depth normalization}:
#'     Tillage depth is converted to cm and capped at 30 cm.
#'
#'   \item \strong{Annual ordering}:
#'     Within each year, disturbance events are ordered by depth and mixing
#'     efficiency.
#'
#'   \item \strong{Cumulative mechanical energy}:
#'     \deqn{ ME_i = SD\_mixeff_i \times SD\_depth\_cm_i }
#'     \deqn{ cumME_i = \sum_{j < i} ME_j }
#'
#'   \item \strong{Profile penetration (T_t)}:
#'     \deqn{ T_{t,i} = SD\_mixeff_i \times \max(0, SD\_depth\_cm_i - cumME_i) }
#'     \deqn{ T_{t,i}^{norm} = T_{t,i} / 30 }
#'
#'   \item \strong{Annual disturbance}:
#'     \deqn{ T_t^{annual} = \sum_i T_{t,i}^{norm} }
#'
#'   \item \strong{Inverse disturbance}:
#'     \deqn{ T_t^{inv} = 1 - T_t^{annual} }
#'
#'   \item \strong{Rotation average}:
#'     Annual inverse disturbance is averaged across all rotation years and
#'     scaled to 0–100.
#' }
#'
#' If a management unit has no disturbance events, its inverse disturbance is
#' defined as 100 (no disturbance).
#'
#' @return A data frame with:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{InvDist} — inverse disturbance score (0–100)
#'   }
#'
#' @export
compute_disturbance <- function(daily_dist,
                                rot_bounds) {

  # get full list of mgt units
  all_mgts <- rot_bounds %>% select(MGT_combo)

  # Convert depth to cm and cap at 30
  dist <- daily_dist %>%
    mutate(
      SD_depth_cm = pmin(SD_depth_cm, 30),
      year = lubridate::year(date)
    ) %>%
    filter(!is.na(SD_mixeff), !is.na(SD_depth_cm))

  # Mechanistic T_t calculation per year
  annual <- dist %>%
    arrange(MGT_combo, year, SD_depth_cm, SD_mixeff) %>%
    group_by(MGT_combo, year) %>%
    mutate(
      ME_times_depth = SD_mixeff * SD_depth_cm,
      cum_ME         = cumsum(dplyr::lag(ME_times_depth, default = 0)),
      T_t            = SD_mixeff * pmax(SD_depth_cm - cum_ME, 0),
      T_t_norm       = T_t / 30
    ) %>%
    summarize(
      T_t_annual = sum(T_t_norm, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      T_t_inv = 1 - T_t_annual
    )

  # Rotation-average
  rot <- annual %>%
    group_by(MGT_combo) %>%
    summarize(
      InvDist = 100 * mean(T_t_inv, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      InvDist = ifelse(is.na(InvDist), 100, InvDist)
    )

  dist_full <- all_mgts %>%
    left_join(rot, by = "MGT_combo") %>%
    mutate(
      InvDist = tidyr::replace_na(InvDist, 100)
    )

  dist_full
}
