#' Clip crop episodes to each unit's rotation window
#'
#' Truncates `crop_start` / `crop_end` to `rot_start` / `rot_end` and drops
#' episodes entirely outside the window. Calling this once in
#' [build_shmi()], before [compute_cover()] and [compute_diversity()], makes
#' both sub-indices use the same evaluation window as [compute_orginput()]
#' and [compute_disturbance()].
#'
#' @param crop Species episodes with `MGT_combo`, `crop_start`, `crop_end`.
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start`, `rot_end`.
#' @return `crop`, clipped. Units absent from `rot_bounds` are dropped.
#' @export
clip_crop_to_rotation <- function(crop, rot_bounds) {
  rb <- dplyr::distinct(rot_bounds, .data$MGT_combo, .data$rot_start, .data$rot_end)
  crop %>%
    dplyr::inner_join(rb, by = "MGT_combo") %>%
    dplyr::mutate(
      crop_start = pmax(as.Date(.data$crop_start), as.Date(.data$rot_start)),
      crop_end   = pmin(as.Date(.data$crop_end),   as.Date(.data$rot_end))
    ) %>%
    dplyr::filter(is.na(.data$crop_start) | is.na(.data$crop_end) |
                    .data$crop_start <= .data$crop_end) %>%
    dplyr::select(-"rot_start", -"rot_end")
}


#' Seasonal components of the Cover sub-index
#'
#' Returns \eqn{p_s}, the proportion of days of season \eqn{s} in the
#' rotation that carry living plant cover. [compute_cover()] is
#' \eqn{100 \sum_s w_s p_s} with the weights rescaled to sum to 1, so any
#' set of season weights can be evaluated or estimated from this table.
#'
#' Plant windows are all episodes except those named "fallow", "none" or
#' "bare" (case- and whitespace-insensitive); overlapping windows are merged
#' so each day counts once; seasons follow calendar months (winter Dec-Feb,
#' spring Mar-May, summer Jun-Aug, fall Sep-Nov).
#'
#' @param crop Species episodes with `MGT_combo`, `CD_name`, `crop_start`,
#'   `crop_end`.
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start`, `rot_end`.
#' @param clip_to_rotation Logical. If `TRUE` (recommended), only plant days
#'   inside `rot_start`-`rot_end` count, so \eqn{0 \le p_s \le 1}. `FALSE`
#'   reproduces SHMI <= 1.1.0, which counted every plant day of an episode,
#'   including days outside the rotation, against the rotation's season
#'   lengths (so \eqn{p_s} could exceed 1).
#'
#' @return A tibble with `MGT_combo`, `p_winter`, `p_spring`, `p_summer`,
#'   `p_fall`, `days_winter` ... `days_fall` (days of each season in the
#'   rotation) and `outside_days` (plant days outside the rotation window),
#'   one row per unit in `rot_bounds`.
#' @export
compute_cover_components <- function(crop, rot_bounds, clip_to_rotation = TRUE) {
  seasons <- c("winter", "spring", "summer", "fall")
  month_to_season <- c(1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 1)   # Jan..Dec

  rb <- dplyr::distinct(rot_bounds, .data$MGT_combo, .data$rot_start, .data$rot_end)
  if (anyDuplicated(rb$MGT_combo)) stop("rot_bounds has more than one window per MGT_combo.")
  rb$rot_start <- as.Date(rb$rot_start)
  rb$rot_end   <- as.Date(rb$rot_end)

  keep <- !(tolower(trimws(crop$CD_name)) %in% c("fallow", "none", "bare")) &
    !is.na(crop$crop_start) & !is.na(crop$crop_end)
  cr <- crop[keep, c("MGT_combo", "crop_start", "crop_end")]
  cr$crop_start <- as.Date(cr$crop_start)
  cr$crop_end   <- as.Date(cr$crop_end)
  cr_by_unit <- split(cr, cr$MGT_combo)

  season_of <- function(d) month_to_season[as.integer(format(d, "%m"))]

  rows <- lapply(seq_len(nrow(rb)), function(i) {
    rot_days <- seq(rb$rot_start[i], rb$rot_end[i], by = "day")
    n_s <- tabulate(season_of(rot_days), nbins = 4)

    ci <- cr_by_unit[[rb$MGT_combo[i]]]
    plant <- if (is.null(ci) || nrow(ci) == 0) as.Date(character()) else
      unique(do.call(c, Map(seq, ci$crop_start, ci$crop_end, MoreArgs = list(by = "day"))))
    inside <- plant >= rb$rot_start[i] & plant <= rb$rot_end[i]
    counted <- if (clip_to_rotation) plant[inside] else plant
    live_s <- tabulate(season_of(counted), nbins = 4)

    c(ifelse(n_s > 0, live_s / n_s, 0), n_s, sum(!inside))
  })

  m <- do.call(rbind, rows)
  out <- tibble::tibble(MGT_combo = rb$MGT_combo)
  out[paste0("p_", seasons)]    <- as.data.frame(m[, 1:4, drop = FALSE])
  out[paste0("days_", seasons)] <- as.data.frame(m[, 5:8, drop = FALSE])
  out$outside_days <- m[, 9]
  out
}


#' Components of the Organic Inputs sub-index
#'
#' Returns the proportion of rotation years with an organic amendment and
#' with animals. [compute_orginput()] is
#' \eqn{100 (w_a p_{amend} + w_n p_{animal}) / (w_a + w_n)}.
#'
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start_yr`,
#'   `rot_end_yr`.
#' @param amend Amendment events with `MGT_combo`, `SA_date`, `SA_cat`.
#' @param animal Animal events with `MGT_combo`, `AD_start_date` and, for
#'   `animal_presence = "span"`, `AD_end_date`.
#' @param animal_presence `"start"` (SHMI <= 1.1.0): a year has animals only
#'   if an animal period *starts* in it, so a grazing period spanning several
#'   years counts once. `"span"`: every calendar year overlapped by
#'   `AD_start_date`-`AD_end_date` counts; periods without an end date count
#'   in their start year only.
#'
#' @return A tibble with `MGT_combo`, `p_amend`, `p_animal`, `n_years`, one
#'   row per unit in `rot_bounds`.
#' @export
compute_orginput_components <- function(rot_bounds, amend, animal,
                                        animal_presence = c("start", "span")) {
  animal_presence <- match.arg(animal_presence)
  rb <- dplyr::distinct(rot_bounds, .data$MGT_combo, .data$rot_start_yr, .data$rot_end_yr)
  if (anyDuplicated(rb$MGT_combo)) stop("rot_bounds has more than one window per MGT_combo.")
  year_of <- function(d) as.integer(format(as.Date(d), "%Y"))

  am <- amend[!is.na(amend$SA_date) & amend$SA_cat %in% "Organic", , drop = FALSE]
  am_years <- split(year_of(am$SA_date), am$MGT_combo)

  an <- animal[!is.na(animal$AD_start_date), , drop = FALSE]
  if (animal_presence == "span") {
    if (!"AD_end_date" %in% names(an)) stop("animal_presence = 'span' needs AD_end_date.")
    y0 <- year_of(an$AD_start_date)
    y1 <- ifelse(is.na(an$AD_end_date), y0, year_of(an$AD_end_date))
    y1 <- pmax(y0, y1)
    an_years <- split(unlist(Map(seq, y0, y1)), rep(an$MGT_combo, y1 - y0 + 1))
  } else {
    an_years <- split(year_of(an$AD_start_date), an$MGT_combo)
  }

  res <- lapply(seq_len(nrow(rb)), function(i) {
    yrs <- seq(rb$rot_start_yr[i], rb$rot_end_yr[i])
    u   <- rb$MGT_combo[i]
    c(mean(yrs %in% am_years[[u]]), mean(yrs %in% an_years[[u]]), length(yrs))
  })
  m <- do.call(rbind, res)
  tibble::tibble(MGT_combo = rb$MGT_combo, p_amend = m[, 1], p_animal = m[, 2],
                 n_years = as.integer(m[, 3]))
}


#' All linear components needed to calibrate SHMI weights
#'
#' For fixed nonlinear settings (`hill`, `max_div`, `dist_meth`, `max_stir`,
#' `ti_rep`), SHMI is linear in `C_winter`, `C_spring`, `C_summer`, `C_fall`,
#' `Diversity`, `InvDist`, `O_amend`, `O_animal` (all 0-100):
#' \deqn{SHMI = w_{cov} \sum_s w_s C_s + w_{div} Diversity + w_{inv} InvDist
#'   + w_{org} (w_a O_{amend} + w_n O_{animal})}
#'
#' @param shmi_inputs A list returned by [prepare_shmi_inputs()].
#' @param settings Optional named list of nonlinear settings (expert mode).
#' @param clip_to_rotation,animal_presence Leave `NULL` to use the values
#'   [build_shmi()] applied (from `settings_used`), which keeps the
#'   components consistent with the package scores.
#' @param check Logical. Verify that the components reproduce
#'   [build_shmi()]'s Cover and OrgInput under the official weights.
#' @export
compute_shmi_components <- function(shmi_inputs, settings = NULL,
                                    clip_to_rotation = NULL,
                                    animal_presence = NULL,
                                    check = TRUE) {
  res <- if (is.null(settings)) build_shmi(shmi_inputs) else
    build_shmi(shmi_inputs, settings = settings, expert_mode = TRUE)
  if (is.null(clip_to_rotation)) clip_to_rotation <- isTRUE(res$settings_used$clip_to_rotation)
  if (is.null(animal_presence)) {
    animal_presence <- if (is.null(res$settings_used$animal_presence)) "start" else
      res$settings_used$animal_presence
  }

  cc <- compute_cover_components(shmi_inputs$crop, shmi_inputs$rot_bounds, clip_to_rotation)
  oc <- compute_orginput_components(shmi_inputs$rot_bounds, shmi_inputs$amend,
                                    shmi_inputs$animal, animal_presence)

  out <- tibble::tibble(
    MGT_combo = cc$MGT_combo,
    C_winter = 100 * cc$p_winter, C_spring = 100 * cc$p_spring,
    C_summer = 100 * cc$p_summer, C_fall   = 100 * cc$p_fall,
    outside_days = cc$outside_days
  ) %>%
    dplyr::left_join(dplyr::transmute(oc, .data$MGT_combo,
                                      O_amend  = 100 * .data$p_amend,
                                      O_animal = 100 * .data$p_animal),
                     by = "MGT_combo") %>%
    dplyr::left_join(res$indicator_df[, c("MGT_combo", "Cover", "Diversity",
                                          "InvDist", "OrgInput")],
                     by = "MGT_combo")

  if (check) {
    su <- res$settings_used
    ws <- unlist(su[c("w_winter", "w_spring", "w_summer", "w_fall")]); ws <- ws / sum(ws)
    wo <- unlist(su[c("w_amend", "w_animal")]);                       wo <- wo / sum(wo)
    d_cov <- abs(as.vector(as.matrix(out[, c("C_winter", "C_spring", "C_summer", "C_fall")]) %*% ws) - out$Cover)
    d_org <- abs(as.vector(as.matrix(out[, c("O_amend", "O_animal")]) %*% wo) - out$OrgInput)
    bad <- out$MGT_combo[d_cov > 1e-6 | d_org > 1e-6]
    if (length(bad)) {
      stop(sprintf(paste0("Components differ from build_shmi() for %d unit(s), e.g. %s. ",
                          "If these units have outside_days > 0, build_shmi() is not ",
                          "clipping crops to the rotation window; set clip_to_rotation ",
                          "to match."), length(bad), paste(utils::head(bad, 3), collapse = ", ")))
    }
  }
  out
}


#' Report records that fall outside, or straddle, the evaluation window
#'
#' Run on the calibration data before and after adopting
#' `clip_to_rotation = TRUE` / `animal_presence = "span"` to see how many
#' units the definitional changes affect.
#'
#' @param shmi_inputs A list returned by [prepare_shmi_inputs()].
#' @return A tibble with one row per unit and counts of affected records.
#' @export
shmi_window_report <- function(shmi_inputs) {
  cc <- compute_cover_components(shmi_inputs$crop, shmi_inputs$rot_bounds, TRUE)
  cc_legacy <- compute_cover_components(shmi_inputs$crop, shmi_inputs$rot_bounds, FALSE)
  p_cols <- c("p_winter", "p_spring", "p_summer", "p_fall")

  out <- tibble::tibble(
    MGT_combo          = cc$MGT_combo,
    crop_days_outside  = cc$outside_days,
    max_p_legacy       = apply(as.matrix(cc_legacy[, p_cols]), 1, max),
    cover_shift_equalw = 25 * rowSums(as.matrix(cc_legacy[, p_cols]) - as.matrix(cc[, p_cols]))
  )

  an <- shmi_inputs$animal
  if ("AD_end_date" %in% names(an)) {
    yr <- function(d) as.integer(format(as.Date(d), "%Y"))
    multi <- an %>%
      dplyr::filter(!is.na(.data$AD_start_date), !is.na(.data$AD_end_date),
                    yr(.data$AD_end_date) > yr(.data$AD_start_date)) %>%
      dplyr::count(.data$MGT_combo, name = "multi_year_animal_periods")
    out <- dplyr::left_join(out, multi, by = "MGT_combo") %>%
      dplyr::mutate(multi_year_animal_periods =
                      tidyr::replace_na(.data$multi_year_animal_periods, 0L))
  }
  out
}
