#' The four SHMI sub-indices for each management unit
#'
#' Computes Cover, Diversity, InvDist and OrgInput (all 0-100) from prepared
#' inputs. [build_shmi()] combines them with the official weights; calling
#' this function directly is useful for calibration or for inspecting the
#' parts of Cover.
#'
#' @param shmi_inputs A list returned by [prepare_shmi_inputs()].
#' @param climate Monthly climate normals per `MGT_combo`; see
#'   [compute_cover()] and [get_shmi_climate()]. Its `irrigated` column, if
#'   present, overrides the irrigation recorded on Mgt_Unit (`MGT_irr_cat`).
#' @param dist_meth Tillage scale: `"EPA"` (default), `"STIR"`, or `"auto"`
#'   (EPA when passes name implements or give mixing efficiencies; STIR when
#'   only STIR values are recorded).
#' @param implements Optional user implement table (`implement`,
#'   `mixing_efficiency`, `depth_cm`) overriding T-DISC's values; see
#'   [compute_disturbance()].
#'
#' @return A tibble with `MGT_combo`, `Cover`, `Cover_growing`,
#'   `Cover_nongrowing`, `Diversity`, `Richness`, `InvDist`, `TI_tillage`,
#'   `tillage_designation` (T-DISC: NT, RT or CT) and `OrgInput`,
#'   one row per unit in `shmi_inputs$mgt`. Missing records mean the practice
#'   did not happen: no crops gives Cover and Diversity 0, no disturbance
#'   InvDist 100, no organic inputs OrgInput 0.
#' @export
shmi_components <- function(shmi_inputs, climate, dist_meth = c("EPA", "STIR", "auto"),
                            implements = NULL) {
  dist_meth <- .resolve_dist_meth(shmi_inputs$dist, match.arg(dist_meth))
  need <- c("mgt", "rot_bounds", "crop", "dist", "amend", "animal")
  miss <- setdiff(need, names(shmi_inputs))
  if (length(miss)) stop("shmi_inputs lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  mgt <- shmi_inputs$mgt
  if (anyDuplicated(mgt$MGT_combo)) stop("Duplicated MGT_combo in shmi_inputs$mgt.", call. = FALSE)
  rb   <- shmi_inputs$rot_bounds
  crop <- clip_crop_to_rotation(shmi_inputs$crop, rb)

  # irrigation from the workbook (Mgt_Unit) unless the climate table gives its own
  if (!"irrigated" %in% names(climate) && "irrigated" %in% names(mgt))
    climate <- dplyr::left_join(climate, mgt[, c("MGT_combo", "irrigated")], by = "MGT_combo")
  cover <- compute_cover(crop, rb, climate)
  div   <- compute_diversity(crop, rb)
  inv   <- compute_disturbance(shmi_inputs$dist, rb, crop = crop, harvests = shmi_inputs$harvests,
                               dist_meth = dist_meth, implements = implements) %>%
    dplyr::select("MGT_combo", "InvDist", TI_tillage = "TI", tillage_designation = "designation")
  org   <- compute_orginput(rb, shmi_inputs$amend, shmi_inputs$animal)

  dplyr::distinct(mgt, .data$MGT_combo) %>%
    dplyr::left_join(cover, by = "MGT_combo") %>%
    dplyr::left_join(div,   by = "MGT_combo") %>%
    dplyr::left_join(inv,   by = "MGT_combo") %>%
    dplyr::left_join(org,   by = "MGT_combo") %>%
    dplyr::mutate(dplyr::across(c("Cover", "Cover_growing", "Cover_nongrowing", "Diversity",
                                  "Richness", "OrgInput"), ~ tidyr::replace_na(.x, 0)),
                  InvDist = tidyr::replace_na(.data$InvDist, 100),
                  TI_tillage = tidyr::replace_na(.data$TI_tillage, 0),
                  tillage_designation = tidyr::replace_na(.data$tillage_designation, "NT"))
}

# Tillage scale for "auto": EPA when passes name implements or carry mixing
# efficiencies; STIR when only STIR values are recorded (SD_stir, or STIR-like
# SD_mixeff in older workbooks)
.resolve_dist_meth <- function(dist, dist_meth) {
  if (dist_meth != "auto") return(dist_meth)
  if (is.null(dist) || !nrow(dist)) return("EPA")
  has_equip <- "SD_equip" %in% names(dist) && any(!is.na(dist$SD_equip) & trimws(dist$SD_equip) != "")
  if (has_equip) return("EPA")
  st <- .stir_values(dist); me <- suppressWarnings(as.numeric(dist$SD_mixeff))
  if (any(!is.na(st)) && !(any(!is.na(me)) && all(me <= 1, na.rm = TRUE))) "STIR" else "EPA"
}


#' Clip crop episodes to each unit's rotation window
#'
#' Truncates `crop_start` / `crop_end` to `rot_start` / `rot_end` and drops
#' episodes entirely outside the window, so every sub-index uses the same
#' evaluation window.
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


#' Years with organic amendments and animals
#'
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start_yr`,
#'   `rot_end_yr`.
#' @param amend Amendment events with `MGT_combo`, `SA_date`, `SA_cat`.
#' @param animal Animal events with `MGT_combo`, `AD_start_date`,
#'   `AD_end_date`. Every calendar year overlapped by an animal period counts;
#'   periods without an end date count in their start year only.
#' @return A tibble with `MGT_combo`, `p_amend`, `p_animal`, `p_any` (share of
#'   years with an organic amendment or animals, or both) and `n_years`.
#' @export
compute_orginput_components <- function(rot_bounds, amend, animal) {
  rb <- dplyr::distinct(rot_bounds, .data$MGT_combo, .data$rot_start_yr, .data$rot_end_yr)
  if (anyDuplicated(rb$MGT_combo)) stop("rot_bounds has more than one window per MGT_combo.")
  year_of <- function(d) as.integer(format(as.Date(d), "%Y"))
  safe_split <- function(x, f) if (length(x) == 0) list() else split(x, f)

  am <- amend[!is.na(amend$SA_date) & amend$SA_cat %in% "Organic", , drop = FALSE]
  am_years <- safe_split(year_of(am$SA_date), am$MGT_combo)

  an <- animal[!is.na(animal$AD_start_date), , drop = FALSE]
  y0 <- year_of(an$AD_start_date)
  y1 <- if ("AD_end_date" %in% names(an)) ifelse(is.na(an$AD_end_date), y0, year_of(an$AD_end_date)) else y0
  y1 <- pmax(y0, y1)
  an_years <- safe_split(unlist(Map(seq, y0, y1)), rep(an$MGT_combo, y1 - y0 + 1))

  res <- lapply(seq_len(nrow(rb)), function(i) {
    yrs <- seq(rb$rot_start_yr[i], rb$rot_end_yr[i]); u <- rb$MGT_combo[i]
    c(mean(yrs %in% am_years[[u]]), mean(yrs %in% an_years[[u]]),
      mean(yrs %in% c(am_years[[u]], an_years[[u]])), length(yrs))
  })
  m <- do.call(rbind, res)
  if (is.null(m)) m <- matrix(numeric(0), 0, 4)
  tibble::tibble(MGT_combo = rb$MGT_combo, p_amend = m[, 1], p_animal = m[, 2],
                 p_any = m[, 3], n_years = as.integer(m[, 4]))
}


#' Plant days and window days by calendar month
#'
#' Plant days and days in the evaluation window for each calendar month,
#' pooled across years, per management unit. Cover's growing and
#' non-growing seasons are sums over these months.
#'
#' @inheritParams compute_cover
#' @return A tibble with `MGT_combo`, `plant_01` ... `plant_12` (plant days)
#'   and `days_01` ... `days_12` (days of each month inside the window).
#' @export
compute_cover_monthly <- function(crop, rot_bounds) {
  rb <- dplyr::distinct(rot_bounds, .data$MGT_combo, .data$rot_start, .data$rot_end)
  if (anyDuplicated(rb$MGT_combo)) stop("rot_bounds has more than one window per MGT_combo.")
  rb$rot_start <- as.Date(rb$rot_start); rb$rot_end <- as.Date(rb$rot_end)

  keep <- !(tolower(trimws(crop$CD_name)) %in% c("fallow", "none", "bare")) &
    !is.na(crop$crop_start) & !is.na(crop$crop_end)
  cr <- crop[keep, c("MGT_combo", "crop_start", "crop_end")]
  cr$crop_start <- as.Date(cr$crop_start); cr$crop_end <- as.Date(cr$crop_end)
  cr_by_unit <- split(cr, cr$MGT_combo)
  month_of <- function(d) as.integer(format(d, "%m"))

  m <- do.call(rbind, lapply(seq_len(nrow(rb)), function(i) {
    rot_days <- seq(rb$rot_start[i], rb$rot_end[i], by = "day")
    ci <- cr_by_unit[[rb$MGT_combo[i]]]
    plant <- if (is.null(ci) || nrow(ci) == 0) as.Date(character()) else
      unique(do.call(c, Map(seq, ci$crop_start, ci$crop_end, MoreArgs = list(by = "day"))))
    plant <- plant[plant >= rb$rot_start[i] & plant <= rb$rot_end[i]]
    c(tabulate(month_of(plant), nbins = 12), tabulate(month_of(rot_days), nbins = 12))
  }))
  if (is.null(m)) m <- matrix(integer(0), 0, 24)
  out <- tibble::tibble(MGT_combo = rb$MGT_combo)
  out[sprintf("plant_%02d", 1:12)] <- as.data.frame(m[, 1:12, drop = FALSE])
  out[sprintf("days_%02d", 1:12)]  <- as.data.frame(m[, 13:24, drop = FALSE])
  out
}
