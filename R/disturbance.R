#' Compute Inverse Disturbance Using EPA Mechanistic or STIR Methods
#'
#' Computes the SHMI disturbance sub-index for each management unit
#' (`MGT_combo`) using either:
#'
#' \itemize{
#'   \item **EPA mechanistic soil-mixing model** (profile penetration–based), or
#'   \item **STIR disturbance intensity** (daily summed mixing efficiency).
#' }
#'
#' Both methods produce an annual tillage-intensity (TI) value for each
#' rotation year. Annual TI values are then classified into a **modified Tier 3
#' tillage-intensity scheme (Z–K)** derived from the EPA Soil-Mixing Report.
#'
#' ## Modified Tier 3 Classification (Z–K)
#'
#' The published Tier 3 ranges (A–K) contain gaps and do not include a
#' zero-disturbance class. To ensure complete coverage of the \code{[0, 1]}
#' domain:
#'
#' \itemize{
#'   \item A new class **Z** is added for \code{TI = 0}.
#'   \item All class boundaries are converted to **closed–open intervals**
#'         (e.g., \code{[0.01, 0.04)}), ensuring each TI maps to exactly one class.
#'   \item The midpoint for class Z is explicitly set to **0**.
#' }
#'
#' Each annual TI is replaced by the midpoint of its class:
#'
#' \deqn{ T_{t}^{mid} = (TI_{min} + TI_{max}) / 2 }
#'
#' with \code{T_{t}^{mid} = 0} for class Z.
#'
#' The inverse-disturbance score rescales midpoints so that:
#'
#' \itemize{
#'   \item **0 disturbance → 100**, and
#'   \item **midpoint of class K → 0**.
#' }
#'
#' \deqn{
#'   T_{t}^{inv} = 100 \times \left(1 - \frac{T_{t}^{mid}}{T_{K}^{mid}}\right)
#' }
#'
#' Rotation-level disturbance is the mean of annual inverse-disturbance values.
#' Units with no disturbance events receive a score of 100.
#'
#'
#' ## EPA Mechanistic Method
#'
#' The EPA method computes mechanistic profile penetration for each tillage
#' pass using mixing efficiency and tillage depth. Passes occurring on the same
#' date are treated as sequential operations, producing a *daily* TI value.
#' Daily TI values are summed to annual TI.
#'
#' Required columns in `dist`:
#'
#' \itemize{
#'   \item \code{MGT_combo} — management unit identifier
#'   \item \code{SD_date} — date of tillage pass
#'   \item \code{SD_mixeff} — mixing efficiency (0–1)
#'   \item \code{SD_depth} — tillage depth (in inches; converted internally)
#' }
#'
#'
#' ## STIR Method
#'
#' The STIR method computes daily disturbance intensity as:
#'
#' \deqn{ SDsum = \sum SD\_mixeff }
#'
#' summed across all passes on a given date. Annual STIR is the sum of daily
#' SDsum values. Annual STIR is normalized to \code{TI = STIR\_raw / max\_stir}
#' and classified using the same Z–K scheme.
#'
#' Required columns in `dist`:
#'
#' \itemize{
#'   \item \code{MGT_combo}
#'   \item \code{SD_date}
#'   \item \code{SD_mixeff}
#' }
#'
#'
#' ## Rotation Bounds
#'
#' A data frame containing rotation-year boundaries:
#'
#' \itemize{
#'   \item \code{MGT_combo}
#'   \item \code{rot_start}
#'   \item \code{rot_end}
#'   \item \code{rot_start_yr}
#'   \item \code{rot_end_yr}
#' }
#'
#'
#' @param dist Disturbance-event table (EPA or STIR inputs).
#' @param rot_bounds Rotation-year boundaries for each management unit.
#' @param dist_meth Character string: `"EPA"` or `"STIR"`.
#' @param max_stir Maximum annual STIR value used for normalization (default 190).
#'
#' @return A data frame with:
#' \itemize{
#'   \item \code{MGT_combo}
#'   \item \code{InvDist} — inverse disturbance score (0–100)
#' }
#'
#' @export
compute_disturbance <- function(dist,
                                rot_bounds,
                                dist_meth = c("EPA", "STIR"),
                                max_stir = 190) {

  dist_meth <- match.arg(dist_meth)
  all_mgts  <- rot_bounds %>% dplyr::select(MGT_combo)

  # ---- Tier-3 classes (shared by both methods) ----
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
    dplyr::mutate(
      ti_mid = (ti_min + ti_max) / 2,
      ti_mid = dplyr::if_else(class == "Z", 0, ti_mid)
    )

  max_mid <- max(ti_classes$ti_mid)

  # ---- EPA mechanistic method ----
  if (dist_meth == "EPA") {

    dist_epa <- dist %>%
      dplyr::mutate(
        SD_depth_cm = SD_depth * 2.54,
        SD_depth_cm = pmin(SD_depth_cm, 30),
        year        = lubridate::year(SD_date)
      ) %>%
      dplyr::filter(!is.na(SD_mixeff), !is.na(SD_depth_cm))

    daily <- dist_epa %>%
      dplyr::arrange(MGT_combo, year, SD_date, SD_depth_cm, SD_mixeff) %>%
      dplyr::group_by(MGT_combo, year, SD_date) %>%
      dplyr::mutate(
        ME_times_depth = SD_mixeff * SD_depth_cm,
        cum_ME         = cumsum(dplyr::lag(ME_times_depth, default = 0)),
        T_t            = SD_mixeff * pmax(SD_depth_cm - cum_ME, 0),
        T_t_norm       = T_t / 30
      ) %>%
      dplyr::summarize(
        T_t_daily = sum(T_t_norm, na.rm = TRUE),
        .groups   = "drop"
      )

    annual <- daily %>%
      dplyr::group_by(MGT_combo, year) %>%
      dplyr::summarize(
        T_t_annual = sum(T_t_daily, na.rm = TRUE),
        .groups    = "drop"
      )

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
      dplyr::mutate(
        T_t_inv = 100 * (1 - (T_t_mid / max_mid))
      )

    rot <- annual %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::summarize(
        InvDist = mean(T_t_inv, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(InvDist = dplyr::if_else(is.na(InvDist), 100, InvDist))

    return(
      all_mgts %>%
        dplyr::left_join(rot, by = "MGT_combo") %>%
        dplyr::mutate(InvDist = tidyr::replace_na(InvDist, 100))
    )
  }

  # ---- STIR-based method ----
  if (dist_meth == "STIR") {

    # 1. Full year grid from rotation bounds
    full_years <- rot_bounds %>%
      dplyr::mutate(year = purrr::map2(rot_start_yr, rot_end_yr, seq)) %>%
      tidyr::unnest(year) %>%
      dplyr::select(MGT_combo, year)

    # 2. Annual STIR from daily disturbance
    daily <- dist %>%
      group_by(MGT_combo, SD_date) %>%
      summarise(SDsum = sum(SD_mixeff),
                .groups = "drop")

    stir_years <- daily %>%
      dplyr::arrange(MGT_combo, SD_date) %>%
      dplyr::mutate(year = lubridate::year(SD_date)) %>%
      dplyr::group_by(MGT_combo, year) %>%
      dplyr::summarise(
        STIR_raw = sum(SDsum, na.rm = TRUE),
        .groups  = "drop"
      )

    # 3. Join + normalize TI in [0, 1]
    annual <- full_years %>%
      dplyr::left_join(stir_years, by = c("MGT_combo", "year")) %>%
      dplyr::mutate(
        STIR_raw = tidyr::replace_na(STIR_raw, 0),
        STIR_raw = pmin(STIR_raw, max_stir),
        TI       = pmin(STIR_raw / max_stir, 1)
      )

    # 4. Vectorized interval matching
    idx <- sapply(annual$TI, function(x) {
      which(x >= ti_classes$ti_min & x < ti_classes$ti_max)
    })

    idx_fixed <- sapply(seq_along(idx), function(i) {
      if (length(idx[[i]]) == 1) {
        idx[[i]]
      } else if (length(idx[[i]]) > 1) {
        idx[[i]][1]
      } else {
        which.min(abs(annual$TI[i] - ti_classes$ti_mid))
      }
    })

    annual$class  <- ti_classes$class[idx_fixed]
    annual$TI_mid <- ti_classes$ti_mid[idx_fixed]

    max_mid <- max(ti_classes$ti_mid)
    annual$T_t_inv <- 100 * (1 - (annual$TI_mid / max_mid))

    rot <- annual %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::summarise(
        InvDist = mean(T_t_inv, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(InvDist = dplyr::if_else(is.na(InvDist), 100, InvDist))

    return(
      all_mgts %>%
        dplyr::left_join(rot, by = "MGT_combo") %>%
        dplyr::mutate(InvDist = tidyr::replace_na(InvDist, 100))
    )
  }
}
