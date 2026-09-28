# Frozen copies of the SHMI 1.1.0 implementations. Regression tests compare
# the refactored functions against these, so behavior changes are deliberate
# and visible. Do not edit.
`%>%` <- magrittr::`%>%`

legacy_compute_cover_v110 <- function(
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
    dplyr::mutate(
      rot_start = as.Date(rot_start),
      rot_end   = as.Date(rot_end),
      n_days = as.integer(rot_end - rot_start) + 1L
    ) %>%
    tidyr::uncount(n_days) %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::mutate(date = rot_start + (dplyr::row_number() - 1L)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(season = .season(lubridate::month(date))) %>%
    dplyr::count(MGT_combo, season, name = "days_possible")

  # -------------------------------------------------------------------------
  # 6. Merge plant-days and possible-days
  # -------------------------------------------------------------------------
  season_totals <- dplyr::full_join(
    season_counts,
    rot_days,
    by = c("MGT_combo", "season")
  ) %>%
    tidyr::replace_na(list(plant_days = 0, days_possible = 0))

  # -------------------------------------------------------------------------
  # 7. Compute seasonal proportions
  # -------------------------------------------------------------------------
  season_totals <- season_totals %>%
    dplyr::mutate(
      prop = dplyr::if_else(days_possible > 0,
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
    dplyr::mutate(weight = w[season]) %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::summarize(
      Cover = 100 * sum(weight * prop),
      .groups = "drop"
    )

  cover
}

legacy_compute_orginput_v110 <- function(rot_bounds,
                             amend,
                             animal,
                             w_amend = 0.6615,
                             w_animal = 0.3385) {

  # 1. Build rotation-year grid
  rot_grid <- rot_bounds %>%
    dplyr::mutate(year = purrr::map2(rot_start_yr, rot_end_yr, seq)) %>%
    tidyr::unnest(year) %>%
    dplyr::select(MGT_combo, year)

  # 2. Amendment presence (binary per year)
  amend_events <- amend %>%
    dplyr::filter(SA_cat == "Organic") %>%
    dplyr::mutate(year = lubridate::year(SA_date)) %>%
    dplyr::distinct(MGT_combo, year) %>%
    dplyr::mutate(amend_present = 1)

  # 3. Animal presence (binary per year)
  ani_events <- animal %>%
    dplyr::mutate(year = lubridate::year(AD_start_date)) %>%
    dplyr::distinct(MGT_combo, year) %>%
    dplyr::mutate(ani_present = 1)

  # 4. Join + binary presence flags
  bio_events <- rot_grid %>%
    dplyr::left_join(amend_events, by = c("MGT_combo", "year")) %>%
    dplyr::left_join(ani_events,   by = c("MGT_combo", "year")) %>%
    dplyr::mutate(
      amend_present = tidyr::replace_na(amend_present, 0),
      ani_present   = tidyr::replace_na(ani_present, 0)
    )

  # 5. Compute proportions per rotation
  org_props <- bio_events %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::summarise(
      p_amend  = mean(amend_present),
      p_animal = mean(ani_present),
      .groups = "drop"
    )

  # 6. Weighted combination + 0-100 scaling
  org_final <- org_props %>%
    dplyr::mutate(
      raw_score = w_amend * p_amend + w_animal * p_animal,
      OrgInput  = 100 * raw_score / (w_amend + w_animal)
    ) %>%
    dplyr::select(MGT_combo, OrgInput)

  return(org_final)
}

legacy_compute_disturbance_v110 <- function(dist,
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
