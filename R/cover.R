#' Compute the Cover sub-index
#'
#' Share of days with living plants in the growing and non-growing seasons,
#' weighted and scaled 0-100.
#'
#' @details
#' **Plant days.** Every crop episode is a window of living cover, except
#' rows named `"fallow"`, `"none"` or `"bare"`. Overlapping windows (mixtures,
#' relays, cover crops) are merged, so each day counts once.
#'
#' **Seasons.** A calendar month is in the growing season at a unit when its
#' long-term mean temperature is at least `grow_temp` (5 C) and, unless the
#' unit is irrigated, it is not dry: precipitation (mm) at least twice the
#' mean temperature (C), the Bagnouls-Gaussen dry-month rule. Other months
#' form the non-growing season. If a unit has no months in one season, that
#' season takes the other's value.
#'
#' **Score.** With \eqn{G} and \eqn{N} the percentage of growing- and
#' non-growing-season days with living plants,
#' \deqn{Cover = s G + (1 - s) N}
#' where \eqn{s} is `growing_share` (0.860, from the SHMI calibration).
#'
#' @param crop Species episodes with `MGT_combo`, `CD_name`, `crop_start` and
#'   `crop_end`, as in `prepare_shmi_inputs()$crop`.
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start` and
#'   `rot_end`.
#' @param climate Monthly climate normals, one row per `MGT_combo`, with
#'   `tavg_01` ... `tavg_12` (mean temperature, C), `prec_01` ... `prec_12`
#'   (precipitation, mm) and optionally `irrigated` (logical). See
#'   [get_shmi_climate()].
#' @param grow_temp Minimum monthly mean temperature (C) of a growing month.
#' @param growing_share Weight of the growing season within Cover.
#'
#' @return A tibble with `MGT_combo`, `Cover`, `Cover_growing` and
#'   `Cover_nongrowing` (all 0-100), one row per unit in `rot_bounds`.
#'
#' @seealso [get_shmi_climate()], [build_shmi()]
#'
#' @examples
#' crop <- data.frame(MGT_combo = "field_1", CD_name = c("Corn", "Rye"),
#'                    crop_start = as.Date(c("2020-05-01", "2020-10-15")),
#'                    crop_end   = as.Date(c("2020-09-30", "2020-12-31")))
#' rot_bounds <- data.frame(MGT_combo = "field_1",
#'                          rot_start = as.Date("2020-01-01"),
#'                          rot_end   = as.Date("2020-12-31"))
#' climate <- data.frame(MGT_combo = "field_1")
#' climate[sprintf("tavg_%02d", 1:12)] <- as.list(c(-5, -3, 3, 10, 16, 21, 24, 23, 18, 11, 4, -2))
#' climate[sprintf("prec_%02d", 1:12)] <- as.list(c(30, 30, 50, 80, 100, 110, 100, 90, 80, 60, 50, 35))
#' compute_cover(crop, rot_bounds, climate)
#'
#' @export
compute_cover <- function(crop, rot_bounds, climate, grow_temp = 5, growing_share = 0.860) {
  if (!is.numeric(growing_share) || length(growing_share) != 1 || growing_share < 0 || growing_share > 1)
    stop("growing_share must be a single number between 0 and 1.", call. = FALSE)
  mc  <- compute_cover_monthly(crop, rot_bounds)
  act <- growing_months(climate, grow_temp)
  miss <- setdiff(mc$MGT_combo, rownames(act))
  if (length(miss))
    stop("No climate for ", length(miss), " unit(s): ", paste(utils::head(miss, 5), collapse = ", "),
         ". Supply a row per MGT_combo in `climate`.", call. = FALSE)
  act <- act[mc$MGT_combo, , drop = FALSE]
  P <- as.matrix(mc[, sprintf("plant_%02d", 1:12)]); D <- as.matrix(mc[, sprintf("days_%02d", 1:12)])
  share <- function(keep) { den <- rowSums(D * keep); ifelse(den > 0, 100 * rowSums(P * keep) / den, NA_real_) }
  G <- share(act); N <- share(!act)
  G <- ifelse(is.na(G), N, G); N <- ifelse(is.na(N), G, N)
  G[is.na(G)] <- 0; N[is.na(N)] <- 0
  tibble::tibble(MGT_combo = mc$MGT_combo,
                 Cover = growing_share * G + (1 - growing_share) * N,
                 Cover_growing = G, Cover_nongrowing = N)
}


#' Growing-season months from monthly climate normals
#'
#' A month is in the growing season when its mean temperature is at least
#' `grow_temp` and, unless the unit is irrigated, precipitation (mm) is at
#' least twice the mean temperature (C).
#'
#' @inheritParams compute_cover
#' @return A logical matrix, one row per `MGT_combo` (row names) and one
#'   column per month; `TRUE` = growing season.
#' @export
growing_months <- function(climate, grow_temp = 5) {
  need <- c("MGT_combo", sprintf("tavg_%02d", 1:12), sprintf("prec_%02d", 1:12))
  miss <- setdiff(need, names(climate))
  if (length(miss)) stop("`climate` lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  if (anyDuplicated(climate$MGT_combo)) stop("`climate` has more than one row per MGT_combo.", call. = FALSE)
  Tm <- as.matrix(climate[, sprintf("tavg_%02d", 1:12)]); Pm <- as.matrix(climate[, sprintf("prec_%02d", 1:12)])
  if (anyNA(Tm) || anyNA(Pm)) stop("`climate` has missing monthly values.", call. = FALSE)
  irr <- if ("irrigated" %in% names(climate)) as.logical(climate$irrigated) else rep(FALSE, nrow(climate))
  irr[is.na(irr)] <- FALSE
  act <- (Tm >= grow_temp) & (irr | Pm >= 2 * Tm)
  dimnames(act) <- list(as.character(climate$MGT_combo), month.abb)
  act
}
