#' Compute Mechanistic Inverse Disturbance (EPA Soil-Mixing Model + Modified Tier 3 TI)
#'
#' Calculates the SHMI disturbance sub-index for each management unit
#' (`MGT_combo`) using the EPA mechanistic soil-mixing model based on mixing
#' efficiency and tillage depth. Each tillage pass contributes a mechanistic
#' profile-penetration value. Passes occurring on the same date are treated as
#' sequential operations, and their contributions are summed to produce a
#' single *daily* tillage intensity (TI). Daily TI values are aggregated to an
#' annual TI, which is then classified into a **modified Tier 3 tillage-intensity
#' scheme (Z–K)** derived from the EPA Soil-Mixing Report.
#'
#' The published Tier 3 ranges (A–K) contain small gaps between categories and
#' do not include a zero-disturbance class. To ensure complete coverage of the
#' [0, 1] TI domain and to correctly represent no-disturbance conditions, the
#' ranges are modified as follows:
#'
#' \itemize{
#'   \item A new class **Z** is added for \code{TI = 0}, representing true
#'         zero-disturbance conditions.
#'   \item All class boundaries are adjusted to form **closed–open intervals**
#'         (e.g., \code{[0.01, 0.04)}) so that every TI value maps to exactly
#'         one class with no gaps or overlaps.
#'   \item The midpoint for class Z is explicitly set to **0**, rather than the
#'         numerical midpoint of its interval, to reflect the conceptual meaning
#'         of no disturbance.
#' }
#'
#' Each annual TI is assigned to one of the Z–K classes, and each class is
#' replaced by the midpoint of its intensity range:
#' \deqn{ T_{t}^{mid} = (TI_{min} + TI_{max}) / 2 }
#' with the exception that \code{T_{t}^{mid} = 0} for class Z.
#'
#' The inverse-disturbance value for each year is then computed by rescaling
#' the midpoint so that the midpoint of class K corresponds to 0 and no
#' disturbance corresponds to 100:
#' \deqn{
#'   T_{t}^{inv} = 100 \times \left(1 - \frac{T_{t}^{mid}}{T_{K}^{mid}}\right)
#' }
#'
#' Rotation-level disturbance is the mean of annual inverse-disturbance values.
#' Units with no disturbance events receive an inverse-disturbance score of 100.
#'
#' @param dist A disturbance-event table containing one row per tillage pass,
#'   with columns:
#'   \itemize{
#'     \item \code{MGT_combo} — management unit identifier
#'     \item \code{SD_date} — date of tillage pass
#'     \item \code{SD_mixeff} — mixing efficiency (0–1)
#'     \item \code{SD_depth} — tillage depth (in inches; converted internally)
#'   }
#'   Multiple passes on the same date are treated as sequential operations.
#'
#' @param rot_bounds A data frame containing rotation bounds for each
#'   management unit, with columns:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{rot_start}
#'     \item \code{rot_end}
#'   }
#'
#' @return A data frame with:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{InvDist} — inverse disturbance score (0–100)
#'   }
#'
#' @export
compute_disturbance <- function(dist, rot_bounds) {

  all_mgts <- rot_bounds %>% select(MGT_combo)

  # Preprocess disturbance table
  dist <- dist %>%
    mutate(
      SD_depth_cm = SD_depth * 2.54,
      SD_depth_cm = pmin(SD_depth_cm, 30),
      year        = lubridate::year(SD_date)
    ) %>%
    filter(!is.na(SD_mixeff), !is.na(SD_depth_cm))

  # Daily mechanistic TI
  daily <- dist %>%
    arrange(MGT_combo, year, SD_date, SD_depth_cm, SD_mixeff) %>%
    group_by(MGT_combo, year, SD_date) %>%
    mutate(
      ME_times_depth = SD_mixeff * SD_depth_cm,
      cum_ME         = cumsum(lag(ME_times_depth, default = 0)),
      T_t            = SD_mixeff * pmax(SD_depth_cm - cum_ME, 0),
      T_t_norm       = T_t / 30
    ) %>%
    summarize(
      T_t_daily = sum(T_t_norm, na.rm = TRUE),
      .groups   = "drop"
    )

  # Updated Tier 3 classes (Z–K, no gaps)
  ti_classes <- tibble::tribble(
    ~class, ~ti_min, ~ti_max,
    "Z",    0.000,   0.001,
    "A",    0.001,   0.01,
    "B",    0.01,    0.04,
    "C",    0.04,    0.075,
    "D",    0.075,   0.111,
    "E",    0.111,   0.144,
    "F",    0.144,   0.162,
    "G",    0.162,   0.202,
    "H",    0.202,   0.252,
    "I",    0.252,   0.268,
    "J",    0.268,   0.449,
    "K",    0.449,   1.00
  ) %>%
    mutate(
      ti_mid = (ti_min + ti_max) / 2,
      ti_mid = ifelse(class == "Z", 0, ti_mid)   # override midpoint for Z
    )

  max_mid <- max(ti_classes$ti_mid)  # midpoint of K

  # Annual TI
  annual <- daily %>%
    group_by(MGT_combo, year) %>%
    summarize(
      T_t_annual = sum(T_t_daily, na.rm = TRUE),
      .groups    = "drop"
    )

  # Vectorized Tier 3 classification
  idx <- sapply(annual$T_t_annual, function(x) {
    which(x >= ti_classes$ti_min & x < ti_classes$ti_max)
  })

  idx_fixed <- sapply(seq_along(idx), function(i) {
    if (length(idx[[i]]) == 1) {
      idx[[i]]
    } else if (length(idx[[i]]) > 1) {
      idx[[i]][1]
    } else {
      which.min(abs(annual$T_t_annual[i] - ti_classes$ti_mid))
    }
  })

  annual$class   <- ti_classes$class[idx_fixed]
  annual$T_t_mid <- ti_classes$ti_mid[idx_fixed]

  annual <- annual %>%
    mutate(
      T_t_inv = 100 * (1 - (T_t_mid / max_mid))
    )

  # Rotation average
  rot <- annual %>%
    group_by(MGT_combo) %>%
    summarize(
      InvDist = mean(T_t_inv, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(InvDist = ifelse(is.na(InvDist), 100, InvDist))

  all_mgts %>%
    left_join(rot, by = "MGT_combo") %>%
    mutate(InvDist = tidyr::replace_na(InvDist, 100))
}
