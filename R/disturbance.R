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
#' rotation year. Annual TI values are then classified into a **Tier 3
#' tillage-intensity scheme (Z–K)** derived from the EPA Soil-Mixing Report.
#'
#'
#' ## Tier 3 Classification (Z–K)
#'
#' The Tier 3 scheme partitions the \code{[0, 1]} disturbance domain into
#' nonlinear classes (Z–K). Each class has a lower and upper TI bound
#' (\code{ti_min}, \code{ti_max}). Class Z is added to represent
#' \code{TI = 0}. All classes use closed–open intervals
#' (e.g., \code{[0.01, 0.04)}) to ensure each TI maps to exactly one class.
#'
#' After classification, each TI is replaced by a **class representative**:
#'
#' \itemize{
#'   \item \code{"min"} — lower class boundary (\code{ti_min})
#'   \item \code{"mid"} — class midpoint (\code{(ti_min + ti_max)/2})
#'   \item \code{"max"} — upper class boundary (\code{ti_max})
#' }
#'
#' The default representative is \code{"mid"}, which corresponds to the
#' midpoint-based EPA Tier 3 interpretation used in the national SHMI.
#'
#'
#' ## Inverse Disturbance
#'
#' The inverse-disturbance score is computed as:
#'
#' \deqn{
#'   T_{t}^{inv} = 100 \times (1 - TI_{\text{used}})
#' }
#'
#' where \code{TI_used} is the class representative selected by
#' \code{ti_rep}. This formulation ensures:
#'
#' \itemize{
#'   \item \code{TI_used = 0} → \code{InvDist = 100} (no disturbance)
#'   \item \code{TI_used = 1} → \code{InvDist = 0} (maximum disturbance)
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
#' Daily TI values are summed to annual TI. EPA TI values are naturally bounded
#' in \code{[0, 1]} and require no additional normalization.
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
#' SDsum values. Because STIR is unbounded, annual STIR is normalized to:
#'
#' \deqn{
#'   TI = \frac{STIR_{\text{raw}}}{\text{max\_stir}}
#' }
#'
#' and truncated to \code{[0, 1]} before Tier 3 classification.
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
#' @param max_stir Maximum annual STIR value used for normalization (default 342).
#' @param ti_rep Class representative to use: `"max"` (default), `"min"`, or `"mid"`.
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
                                max_stir = 342,
                                ti_rep = c("max", "min", "mid")) {

  dist_meth <- match.arg(dist_meth)
  ti_rep    <- match.arg(ti_rep)

  # ------------------------------------------------------------
  # REQUIRED CHECK: STIR needs SD_depth
  # ------------------------------------------------------------
  if (dist_meth == "EPA") {

    # Column missing entirely
    if (!"SD_depth" %in% names(dist) || all(is.na(dist$SD_depth))) {
      stop("dist_meth = 'EPA' requires SD_depth, but it is missing or blank.")
    }

    # Column present but all values blank/NA
    if (!is.numeric(dist$SD_depth)) {
      stop("SD_depth must be numeric for EPA disturbance calculations.")
    }
  }

  # -------------------------------------------------------------------------
  # 0. All MGT combos
  # -------------------------------------------------------------------------
  all_mgts <- rot_bounds %>% dplyr::select(MGT_combo)

  # -------------------------------------------------------------------------
  # 1. Expand rotation years
  # -------------------------------------------------------------------------
  full_years <- rot_bounds %>%
    dplyr::mutate(year = purrr::map2(rot_start_yr, rot_end_yr, seq)) %>%
    tidyr::unnest(year) %>%
    dplyr::select(MGT_combo, year)

  # -------------------------------------------------------------------------
  # 2. Tier‑3 class table (left‑closed, right‑open)
  # -------------------------------------------------------------------------
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

  rep_col <- dplyr::case_when(
    ti_rep == "mid" ~ ti_classes$ti_mid,
    ti_rep == "min" ~ ti_classes$ti_min,
    ti_rep == "max" ~ ti_classes$ti_max
  )

  # -------------------------------------------------------------------------
  # Helper: classify TI_raw using left‑closed, right‑open intervals
  # -------------------------------------------------------------------------
  classify_TI <- function(TI_raw) {
    idx <- which(TI_raw >= ti_classes$ti_min & TI_raw < ti_classes$ti_max)
    if (length(idx) == 1) {
      return(idx)
    }
    if (length(idx) == 0) {
      # fallback: nearest midpoint
      return(which.min(abs(TI_raw - ti_classes$ti_mid)))
    }
    # multiple matches → pick the correct interval by left‑closed rule
    return(idx[length(idx)])  # highest interval that matches
  }

  # -------------------------------------------------------------------------
  # ============================
  # EPA METHOD
  # ============================
  # -------------------------------------------------------------------------
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
      dplyr::summarize(T_t_daily = sum(T_t_norm, na.rm = TRUE), .groups = "drop")

    annual <- daily %>%
      dplyr::group_by(MGT_combo, year) %>%
      dplyr::summarize(TI_raw = sum(T_t_daily, na.rm = TRUE), .groups = "drop")

    annual <- full_years %>%
      dplyr::left_join(annual, by = c("MGT_combo", "year")) %>%
      dplyr::mutate(TI_raw = tidyr::replace_na(TI_raw, 0))

    annual <- annual %>%
      dplyr::rowwise() %>%
      dplyr::mutate(
        idx = classify_TI(TI_raw),
        class = ti_classes$class[idx],
        TI_used = rep_col[idx],
        TI_used = dplyr::if_else(class == "Z", 0, TI_used),
        InvDist_year = 100 * (1 - TI_used)
      ) %>%
      dplyr::ungroup()

    rot <- annual %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::summarize(InvDist = mean(InvDist_year), .groups = "drop")

    return(all_mgts %>%
             dplyr::left_join(rot, by = "MGT_combo") %>%
             dplyr::mutate(InvDist = tidyr::replace_na(InvDist, 100)))
  }

  # -------------------------------------------------------------------------
  # ============================
  # STIR METHOD
  # ============================
  # -------------------------------------------------------------------------
  if (dist_meth == "STIR") {

    # SD_mixeff contains actual STIR values
    daily <- dist %>%
      dplyr::group_by(MGT_combo, SD_date) %>%
      dplyr::summarize(STIR_raw = sum(SD_mixeff, na.rm = TRUE), .groups = "drop")

    stir_years <- daily %>%
      dplyr::mutate(year = lubridate::year(SD_date)) %>%
      dplyr::group_by(MGT_combo, year) %>%
      dplyr::summarize(STIR_raw = sum(STIR_raw), .groups = "drop")

    annual <- full_years %>%
      dplyr::left_join(stir_years, by = c("MGT_combo", "year")) %>%
      dplyr::mutate(
        STIR_raw = tidyr::replace_na(STIR_raw, 0),
        TI_raw = pmin(STIR_raw / max_stir, 1)
      )

    annual <- annual %>%
      dplyr::rowwise() %>%
      dplyr::mutate(
        idx = classify_TI(TI_raw),
        class = ti_classes$class[idx],
        TI_used = rep_col[idx],
        TI_used = dplyr::if_else(class == "Z", 0, TI_used),
        InvDist_year = 100 * (1 - TI_used)
      ) %>%
      dplyr::ungroup()

    rot <- annual %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::summarize(InvDist = mean(InvDist_year), .groups = "drop")

    return(all_mgts %>%
             dplyr::left_join(rot, by = "MGT_combo") %>%
             dplyr::mutate(InvDist = tidyr::replace_na(InvDist, 100)))
  }
}
