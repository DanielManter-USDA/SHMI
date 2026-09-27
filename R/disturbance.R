#' Compute the inverse-disturbance sub-index
#'
#' Scores soil disturbance for each calendar year of the rotation and
#' averages the years, so that 100 means no disturbance and 0 means maximum
#' disturbance.
#'
#' @details
#' **Methods.**
#' * `"EPA"` (official): mechanistic soil-mixing model. `SD_mixeff` is the
#'   mixing efficiency (a proportion, 0-1) and `SD_depth` the tillage depth
#'   in inches, converted to cm and capped at 30 cm. Passes on the same day
#'   are processed from shallowest to deepest, and each disturbs fraction
#'   \eqn{m} of the soil still undisturbed within its depth \eqn{d}, so
#'   overlapping passes are not double-counted:
#'   \eqn{S_k = S_{k-1} + m_k (d_k - S_{k-1})}. The daily value is
#'   \eqn{S / 30}, and daily values are summed within each calendar year.
#' * `"STIR"`: `SD_mixeff` holds STIR values. They are summed within each
#'   calendar year, divided by `max_stir`, and truncated to 1.
#'
#' **Classes.** Each annual tillage intensity (TI) is placed in a Tier-3
#' class (left-closed, right-open intervals):
#'
#' | Class | TI range | Class | TI range |
#' |---|---|---|---|
#' | Z | `0 - 0.001` | F | `0.144 - 0.162` |
#' | A | `0.001 - 0.01` | G | `0.162 - 0.202` |
#' | B | `0.01 - 0.04` | H | `0.202 - 0.252` |
#' | C | `0.04 - 0.075` | I | `0.252 - 0.268` |
#' | D | `0.075 - 0.111` | J | `0.268 - 0.449` |
#' | E | `0.111 - 0.144` | K | `0.449 - 1` |
#'
#' TI is then replaced by a class representative chosen by `ti_rep`: the
#' lower bound (`"min"`), midpoint (`"mid"`), or upper bound (`"max"`, the
#' official choice). Class Z always uses 0. The annual score is
#' \eqn{100 (1 - TI_{used})}, and the rotation score is the mean over all
#' calendar years from `rot_start_yr` to `rot_end_yr`.
#'
#' **Missing records.** A missing record means no disturbance occurred (for
#' example, continuous no-till): years without passes score 100, and a unit
#' with no passes at all scores 100.
#'
#' **Checks.** Inputs are checked for the chosen method. Under `"EPA"`, every
#' pass with `SD_mixeff > 0` needs `SD_depth`, `SD_mixeff` must lie within
#' 0-1 (larger values look like STIR), and depths above 20 inches give a
#' warning because they may have been entered in cm.
#'
#' @param dist Disturbance passes with `MGT_combo`, `SD_date`, `SD_mixeff`,
#'   and, for `"EPA"`, `SD_depth` (inches).
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start_yr`, and
#'   `rot_end_yr`.
#' @param dist_meth Disturbance method, `"EPA"` or `"STIR"`.
#' @param max_stir Annual STIR value that corresponds to TI = 1 (`"STIR"`
#'   only).
#' @param ti_rep Class representative: `"max"`, `"min"`, or `"mid"`.
#'
#' @return A data frame with `MGT_combo` and `InvDist` (0-100), one row per
#'   unit in `rot_bounds`.
#'
#' @seealso [build_shmi()], [validate_shmi_input()]
#'
#' @examples
#' dist <- data.frame(
#'   MGT_combo = "field_1",
#'   SD_date   = as.Date(c("2020-04-15", "2020-05-01")),
#'   SD_mixeff = c(39, 2.4)   # STIR values: disk harrow, planter
#' )
#' rot_bounds <- data.frame(MGT_combo = "field_1",
#'                          rot_start_yr = 2020, rot_end_yr = 2021)
#' compute_disturbance(dist, rot_bounds, dist_meth = "STIR")
#'
#' @export
compute_disturbance <- function(dist,
                                rot_bounds,
                                dist_meth = c("EPA", "STIR"),
                                max_stir = 342,
                                ti_rep = c("max", "min", "mid")) {

  dist_meth <- match.arg(dist_meth)
  ti_rep    <- match.arg(ti_rep)

  chk <- .check_dist_method(dist, dist_meth)
  if (length(chk$errors) > 0) {
    stop(paste(chk$errors, collapse = "\n"), call. = FALSE)
  }

  # ------------------------------------------------------------
  # REQUIRED CHECK: EPA needs SD_depth
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
  # 2. Tier-3 class table (left-closed, right-open)
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

  rep_col <- switch(ti_rep,
                    mid = ti_classes$ti_mid,
                    min = ti_classes$ti_min,
                    max = ti_classes$ti_max
  )

  # -------------------------------------------------------------------------
  # Helper: classify TI_raw using left-closed, right-open intervals
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
    # multiple matches -> pick the correct interval by left-closed rule
    return(idx[length(idx)])  # highest interval that matches
  }

  # -------------------------------------------------------------------------
  # ============================
  # EPA METHOD
  # ============================
  # -------------------------------------------------------------------------
  if (dist_meth == "EPA") {

    if (any(dist$SD_mixeff < 0 | dist$SD_mixeff > 1, na.rm = TRUE)) {
      stop("dist_meth = 'EPA' expects SD_mixeff in [0, 1]; values > 1 look like STIR. ",
           "Use dist_meth = 'STIR' or convert to mixing efficiencies.", call. = FALSE)
    }

    bad <- dist %>%
      dplyr::filter(!is.na(SD_mixeff), SD_mixeff > 0, is.na(SD_depth))

    if (nrow(bad) > 0) {
      cli::cli_abort(c(
        "dist_meth = 'EPA' requires SD_depth for every disturbance pass.",
        "x" = "{nrow(bad)} pass{?es} ha{?s/ve} SD_mixeff but no SD_depth.",
        "i" = "First affected: {.val {utils::head(unique(paste(bad$MGT_combo, bad$SD_date)), 5)}}"
      ))
    }
    if (!is.numeric(dist$SD_depth)) {
      cli::cli_abort("SD_depth must be numeric for EPA disturbance calculations.")
    }

    # Plausibility check on depth units (template expects inches)
    max_plausible_in <- 20   # ~51 cm; deeper than normal tillage

    if (any(dist$SD_depth < 0, na.rm = TRUE)) {
      cli::cli_abort("SD_depth contains negative values; depths must be >= 0 inches.")
    }

    deep <- dist %>%
      dplyr::filter(!is.na(SD_depth), SD_depth > max_plausible_in)

    if (nrow(deep) > 0) {
      cli::cli_warn(c(
        "{nrow(deep)} disturbance pass{?es} ha{?s/ve} SD_depth > {max_plausible_in} inches.",
        "!" = "SD_depth is expected in inches; values this large may have been entered in cm.",
        "i" = "Depths are capped at 30 cm (~11.8 in), so unit errors are otherwise absorbed silently.",
        "i" = "First affected: {.val {utils::head(unique(paste(deep$MGT_combo, deep$SD_date, deep$SD_depth)), 5)}}"
      ))
    }

    dist_epa <- dist %>%
      dplyr::mutate(
        SD_depth_cm = SD_depth * 2.54,
        SD_depth_cm = pmin(SD_depth_cm, 30),
        year        = lubridate::year(SD_date)
      ) %>%
      dplyr::filter(!is.na(SD_mixeff), !is.na(SD_depth_cm))

    epa_day <- function(me, depth) {
      S <- 0
      for (i in seq_along(me)) S <- S + me[i] * max(depth[i] - S, 0)
      S
    }

    daily <- dist_epa %>%
      dplyr::arrange(MGT_combo, SD_date, SD_depth_cm) %>%
      dplyr::group_by(MGT_combo, year, SD_date) %>%
      dplyr::summarize(T_t_daily = epa_day(SD_mixeff, SD_depth_cm) / 30,
                       .groups = "drop")

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
