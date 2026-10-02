#' Compute the Inverse Disturbance sub-index
#'
#' Tillage intensity computed as in USDA's Tillage Disturbance Index for Soil
#' Carbon (T-DISC), scored 0-100 (100 = no tillage).
#'
#' @details
#' **Crop intervals.** Each cash crop (harvest records with category `"cash"`
#' or `"annual"`) defines a crop interval, from the day after the previous
#' cash crop's harvest to its own last harvest. Its planting date is the start
#' of the latest episode of the same crop beginning on or before the harvest.
#' Days outside every crop interval (years without a cash crop, or the end of
#' the record after the last harvest) form one interval per calendar year.
#'
#' **Tillage windows.** Within a cash-crop interval with planting date P,
#' a pass belongs to: *field preparation* (up to 56 days before P),
#' *before planting* (55-7 days before P), *planting* (6-0 days before P),
#' *after planting* (after P, outside harvest days) or *harvest* (a harvest
#' day). Intervals without a planting date, or outside cash crops, have a
#' single window.
#'
#' **Window intensity (EPA soil-mixing model).** Implements are applied from
#' shallowest to deepest (ties: least to most intensive); each mixes its share
#' of the soil still unmixed within its depth \eqn{d_k} (cm, capped at 30):
#' \deqn{S_k = S_{k-1} + m_k (d_k - S_{k-1})}
#' and the window's intensity is \eqn{S / 30}. With `dist_meth = "STIR"`, the
#' window's intensity is its summed STIR divided by `max_stir`, truncated to 1.
#'
#' **Interval rating and score.** An interval's rating is the maximum of its
#' window intensities (T-DISC's crop-interval rating). It is placed in an EPA
#' Tier-3 class and replaced by the class's upper bound (class Z: 0); the
#' interval scores \eqn{100 (1 - \text{class value})}. The unit's InvDist is
#' the mean over its intervals, weighted by interval length in days.
#'
#' **Implement values (EPA).** Each pass names its implement (`SD_equip`); its
#' mixing efficiency and depth come from `implements` (a user table that
#' replaces or adds entries) or else from [tdisc_implements()], directly or
#' through the operation names in [tdisc_mapping()]. An operation that maps to
#' several implements counts as several passes on the same day.
#'
#' `SD_mixeff` (0-1) and `SD_depth` (inches) are **overrides**: leave them blank
#' to use the implement's values, or enter either or both to replace them. A
#' pass with both values needs no implement. For an operation that maps to
#' several implements, enter both overrides or neither.
#'
#' Names are matched case- and whitespace-insensitively. Passes that cannot
#' be resolved stop with a list of the unknown implement names.
#'
#' @param dist Tillage passes with `MGT_combo`, `SD_date` and, for EPA,
#'   `SD_equip` and the optional overrides `SD_mixeff` and `SD_depth`; for STIR,
#'   `SD_stir` (or `SD_mixeff` in workbooks without an `SD_stir` column).
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start_yr`,
#'   `rot_end_yr` and, optionally, `rot_start` / `rot_end` (dates).
#' @param crop Crop episodes (`prepare_shmi_inputs()$crop`), for planting
#'   dates. If `NULL`, every calendar year is one interval with one window.
#' @param harvests Harvest records (`prepare_shmi_inputs()$harvests`) with
#'   `MGT_combo`, `CD_name`, `CD_cat` and `harv_date`. If `NULL`, as for `crop`.
#' @param dist_meth `"EPA"` (default; mixing efficiency and depth, from the
#'   implement or the pass's overrides) or `"STIR"` (STIR values in `SD_stir`).
#' @param implements Optional user implement table with `implement`,
#'   `mixing_efficiency` (0-1) and `depth_cm`; its entries take precedence over
#'   [tdisc_implements()] and [tdisc_mapping()].
#' @param max_stir For `"STIR"`: summed STIR in a window corresponding to an
#'   intensity of 1. The default (135) best matches T-DISC ratings on the
#'   NAPESHM data.
#' @param details If `TRUE`, the result carries an `"intervals"` attribute
#'   with each crop interval's dates, rating, class and designation.
#'
#' @return A tibble, one row per unit in `rot_bounds`: `MGT_combo`, `InvDist`
#'   (0-100), `TI` (length-weighted mean interval rating, 0-1), `designation`
#'   (T-DISC designation of `TI`: `"NT"` up to 0.075, `"RT"` up to 0.252,
#'   otherwise `"CT"`) and `n_intervals`. Units without passes score 100.
#'
#' @seealso [tdisc_implements()], [tdisc_mapping()], [build_shmi()]
#'
#' @examples
#' rot_bounds <- data.frame(MGT_combo = "field_1", rot_start_yr = 2020, rot_end_yr = 2020)
#' dist <- data.frame(MGT_combo = "field_1", SD_date = as.Date("2020-04-15"),
#'                    SD_equip = "HARROW, DISK, TANDEM, HEAVYDUTY")
#' compute_disturbance(dist, rot_bounds)    # T-DISC implement values
#'
#' # a user value for the same implement
#' mine <- data.frame(implement = "HARROW, DISK, TANDEM, HEAVYDUTY",
#'                    mixing_efficiency = 0.6, depth_cm = 10)
#' compute_disturbance(dist, rot_bounds, implements = mine)
#'
#' @export
compute_disturbance <- function(dist, rot_bounds, crop = NULL, harvests = NULL,
                                dist_meth = c("EPA", "STIR"), implements = NULL,
                                max_stir = SHMI_STIR_MAX, details = FALSE) {
  dist_meth <- match.arg(dist_meth)
  if (!is.numeric(max_stir) || length(max_stir) != 1 || max_stir <= 0)
    stop("max_stir must be a single positive number.", call. = FALSE)
  chk <- .check_dist_method(dist, dist_meth)
  if (length(chk$errors)) stop(paste(chk$errors, collapse = "\n"), call. = FALSE)

  rb <- .rot_windows(rot_bounds)
  ci <- .crop_intervals(rb, crop, harvests)
  ivs <- ci$intervals; hdays <- ci$harvest_days
  passes <- .tillage_passes(dist, dist_meth, implements)

  # assign passes to intervals and windows
  scored <- lapply(split(ivs, ivs$MGT_combo), function(iu) {
    pu <- passes[passes$MGT_combo == iu$MGT_combo[1], , drop = FALSE]
    iu$TI <- vapply(seq_len(nrow(iu)), function(k) {
      pk <- pu[pu$date >= iu$start[k] & pu$date <= iu$end[k], , drop = FALSE]
      if (!nrow(pk)) return(0)
      pk$window <- .tillage_window(pk$date, iu$plant[k], hdays$harv_date[hdays$iv_id == iu$iv_id[k]])
      max(vapply(split(pk, pk$window), function(w) {
        if (dist_meth == "STIR") return(min(sum(w$stir) / max_stir, 1))
        o <- order(w$depth_cm, w$me)
        min(.epa_day(w$me[o], w$depth_cm[o]) / 30, 1)
      }, numeric(1)))
    }, numeric(1))
    iu
  })
  ivs <- do.call(rbind, scored)
  ivs$class_value <- .ti_class_value(ivs$TI)
  ivs$score <- 100 * (1 - ivs$class_value)
  ivs$days <- as.numeric(ivs$end - ivs$start) + 1

  units <- lapply(split(ivs, ivs$MGT_combo), function(iu)
    tibble::tibble(MGT_combo = iu$MGT_combo[1],
                   InvDist = stats::weighted.mean(iu$score, iu$days),
                   TI = stats::weighted.mean(iu$TI, iu$days),
                   n_intervals = nrow(iu)))
  out <- dplyr::distinct(rot_bounds, .data$MGT_combo) %>%
    dplyr::left_join(dplyr::bind_rows(units), by = "MGT_combo") %>%
    dplyr::mutate(InvDist = tidyr::replace_na(.data$InvDist, 100),
                  TI = tidyr::replace_na(.data$TI, 0),
                  designation = .tdisc_designation(.data$TI))
  out <- out[, c("MGT_combo", "InvDist", "TI", "designation", "n_intervals")]
  if (details) attr(out, "intervals") <- tibble::as_tibble(
    transform(ivs[, c("MGT_combo", "start", "end", "plant", "TI", "class_value", "score", "days")],
              designation = .tdisc_designation(ivs$TI)))
  out
}

# Annual STIR in a tillage window corresponding to an intensity of 1; fitted so
# STIR ratings best match T-DISC ratings on the NAPESHM crop intervals
SHMI_STIR_MAX <- 135


#' T-DISC implement values
#'
#' The implements of USDA's Tillage Disturbance Index for Soil Carbon
#' (T-DISC, version 1.1.1, 9/4/2026) with their mixing efficiency and tillage
#' depth, used by [compute_disturbance()] when a pass gives an implement name
#' rather than its own values.
#'
#' @return A tibble with `implement`, `mixing_efficiency` (0-1) and
#'   `depth_cm`.
#' @source USDA Office of the Chief Economist, T-DISC Excel tool, "Implement
#'   List" tab. <https://www.usda.gov/t-disc>
#' @examples
#' head(tdisc_implements())
#' @export
tdisc_implements <- function() {
  f <- system.file("extdata", "tdisc_implements.csv", package = "SHMI", mustWork = TRUE)
  tibble::as_tibble(utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE))
}

#' Operation names translated to T-DISC implements
#'
#' Operation names (from T-DISC's "Implement Mapping" tab, and implement names
#' used in the NAPESHM records) with the T-DISC implement(s) that represent
#' each. An operation listed with several implements counts as several passes.
#'
#' @return A tibble with `operation`, `implement` and `source`
#'   (`"T-DISC 1.1.1"` or `"NAPESHM crosswalk"`).
#' @source USDA Office of the Chief Economist, T-DISC Excel tool, "Implement
#'   Mapping" tab. <https://www.usda.gov/t-disc>
#' @examples
#' subset(tdisc_mapping(), grepl("moldboard", operation, ignore.case = TRUE))
#' @export
tdisc_mapping <- function() {
  f <- system.file("extdata", "tdisc_mapping.csv", package = "SHMI", mustWork = TRUE)
  tibble::as_tibble(utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE))
}


# ---- helpers ------------------------------------------------------------------

.name_key <- function(x) toupper(gsub("\\s+", " ", trimws(as.character(x))))

# Evaluation window dates per unit (calendar years when no dates are given)
.rot_windows <- function(rot_bounds) {
  rb <- dplyr::distinct(rot_bounds, .data$MGT_combo, .keep_all = TRUE)
  if (!"rot_start" %in% names(rb)) rb$rot_start <- as.Date(paste0(rb$rot_start_yr, "-01-01"))
  if (!"rot_end" %in% names(rb))   rb$rot_end   <- as.Date(paste0(rb$rot_end_yr, "-12-31"))
  rb$rot_start <- as.Date(rb$rot_start); rb$rot_end <- as.Date(rb$rot_end)
  rb[, c("MGT_combo", "rot_start", "rot_end")]
}

# Crop intervals per unit: one per cash crop (planting date, harvest days), then
# the remaining days as calendar-year intervals with no planting date. Returns
# list(intervals = data frame, harvest_days = data frame of iv_id, harv_date).
.crop_intervals <- function(rb, crop, harvests) {
  cash <- NULL
  if (!is.null(harvests) && nrow(harvests))
    cash <- harvests[!is.na(harvests$harv_date) &
                       tolower(trimws(harvests$CD_cat)) %in% c("cash", "annual"), , drop = FALSE]
  ep <- if (!is.null(crop) && nrow(crop)) crop[!is.na(crop$crop_start), , drop = FALSE] else NULL
  ivl <- list(); hdl <- list(); id <- 0L
  add <- function(u, start, end, plant, hd) {
    id <<- id + 1L
    ivl[[id]] <<- data.frame(iv_id = id, MGT_combo = u, start = start, end = end, plant = plant,
                             stringsAsFactors = FALSE)
    if (length(hd)) hdl[[length(hdl) + 1]] <<- data.frame(iv_id = id, harv_date = hd)
  }
  for (i in seq_len(nrow(rb))) {
    u <- rb$MGT_combo[i]; ws <- rb$rot_start[i]; we <- rb$rot_end[i]; start <- ws
    cu <- if (!is.null(cash)) cash[cash$MGT_combo == u, , drop = FALSE] else NULL
    if (!is.null(cu) && nrow(cu)) {
      eu <- if (!is.null(ep)) ep[ep$MGT_combo == u, , drop = FALSE] else NULL
      cu$name <- .name_key(cu$CD_name)
      cu$plant <- as.Date(vapply(seq_len(nrow(cu)), function(k) {
        if (is.null(eu) || !nrow(eu)) return(NA_real_)
        st <- eu$crop_start[.name_key(eu$CD_name) == cu$name[k] & eu$crop_start <= cu$harv_date[k]]
        if (length(st)) as.numeric(max(st)) else NA_real_
      }, numeric(1)), origin = "1970-01-01")
      g <- split(cu, paste(cu$name, cu$plant))
      g <- g[order(vapply(g, function(x) as.numeric(max(x$harv_date)), numeric(1)))]
      for (x in g) {
        e <- max(x$harv_date)
        if (e < start || e > we) next
        add(u, start, e, x$plant[1], sort(unique(x$harv_date)))
        start <- e + 1
      }
    }
    while (start <= we) {                                   # remainder: calendar years
      e <- min(as.Date(paste0(format(start, "%Y"), "-12-31")), we)
      add(u, start, e, as.Date(NA), as.Date(character()))
      start <- e + 1
    }
  }
  intervals <- if (length(ivl)) do.call(rbind, ivl) else
    data.frame(iv_id = integer(), MGT_combo = character(), start = as.Date(character()),
               end = as.Date(character()), plant = as.Date(character()))
  harvest_days <- if (length(hdl)) do.call(rbind, hdl) else
    data.frame(iv_id = integer(), harv_date = as.Date(character()))
  list(intervals = intervals, harvest_days = harvest_days)
}

# T-DISC tillage window of each pass date in a crop interval
.tillage_window <- function(date, plant, harv_days) {
  if (is.na(plant)) return(rep("single", length(date)))
  k <- as.numeric(plant - date)
  w <- ifelse(date %in% harv_days, "harvest",
       ifelse(date > plant, "after_planting",
       ifelse(k <= 6, "planting", ifelse(k <= 55, "before_planting", "field_preparation"))))
  w
}

# STIR values of each pass: SD_stir, or SD_mixeff in workbooks from before
# SD_stir existed
.stir_values <- function(d) {
  st <- if ("SD_stir" %in% names(d)) suppressWarnings(as.numeric(d$SD_stir)) else rep(NA_real_, nrow(d))
  if (all(is.na(st)) && "SD_mixeff" %in% names(d)) st <- suppressWarnings(as.numeric(d$SD_mixeff))
  st
}

# Passes as rows of (MGT_combo, date, me, depth_cm, stir). EPA: a pass's own
# SD_mixeff and SD_depth (inches) override its implement's T-DISC values, either
# or both; an operation that maps to several implements needs both or neither.
# strict = FALSE drops unresolvable EPA passes silently.
.tillage_passes <- function(dist, dist_meth, implements = NULL, strict = TRUE) {
  empty <- data.frame(MGT_combo = character(), date = as.Date(character()),
                      me = numeric(), depth_cm = numeric(), stir = numeric())
  if (is.null(dist) || !nrow(dist)) return(empty)
  d <- dist[!is.na(dist$SD_date), , drop = FALSE]
  if (!nrow(d)) return(empty)
  for (k in c("SD_equip", "SD_mixeff", "SD_depth", "SD_stir")) if (!k %in% names(d)) d[[k]] <- NA
  if (dist_meth == "STIR") {
    st <- .stir_values(d); keep <- !is.na(st)
    return(data.frame(MGT_combo = d$MGT_combo[keep], date = as.Date(d$SD_date[keep]),
                      me = rep(NA_real_, sum(keep)), depth_cm = rep(NA_real_, sum(keep)), stir = st[keep]))
  }
  me_o  <- suppressWarnings(as.numeric(d$SD_mixeff))
  dep_o <- suppressWarnings(as.numeric(d$SD_depth)) * 2.54
  equip <- trimws(as.character(d$SD_equip))
  has_eq <- !is.na(equip) & equip != "" & toupper(equip) != "NA"

  lib <- tdisc_implements()
  if (!is.null(implements)) {
    need <- c("implement", "mixing_efficiency", "depth_cm")
    miss <- setdiff(need, names(implements))
    if (length(miss)) stop("`implements` lacks: ", paste(miss, collapse = ", "), call. = FALSE)
    lib <- rbind(as.data.frame(implements[, need]), as.data.frame(lib[, need]))
  }
  lib <- lib[!duplicated(.name_key(lib$implement)), , drop = FALSE]
  lk <- .name_key(lib$implement)
  mp <- tdisc_mapping(); mk <- .name_key(mp$operation)
  resolve <- function(nm) {
    key <- .name_key(nm)
    if (key %in% lk) return(lib[match(key, lk), , drop = FALSE])
    if (key %in% mk) {
      imp <- .name_key(mp$implement[mk == key])
      if (all(imp %in% lk)) return(lib[match(imp, lk), , drop = FALSE])
    }
    NULL
  }
  nm <- unique(equip[has_eq]); res <- lapply(nm, resolve); names(res) <- nm

  out <- vector("list", nrow(d)); problem <- character(nrow(d))
  for (k in seq_len(nrow(d))) {
    r <- if (has_eq[k]) res[[equip[k]]] else NULL
    both <- !is.na(me_o[k]) & !is.na(dep_o[k]); any_o <- !is.na(me_o[k]) | !is.na(dep_o[k])
    if (both) {
      me <- me_o[k]; dep <- dep_o[k]
    } else if (!is.null(r) && nrow(r) == 1) {
      me  <- if (!is.na(me_o[k]))  me_o[k]  else r$mixing_efficiency
      dep <- if (!is.na(dep_o[k])) dep_o[k] else r$depth_cm
    } else if (!is.null(r)) {
      if (any_o) { problem[k] <- "partial"; if (strict) next }
      me <- r$mixing_efficiency; dep <- r$depth_cm
    } else {
      problem[k] <- if (has_eq[k]) "unknown" else "blank"
      next
    }
    out[[k]] <- data.frame(MGT_combo = d$MGT_combo[k], date = as.Date(d$SD_date[k]),
                           me = me, depth_cm = pmin(dep, 30), stir = NA_real_)
  }
  if (strict) {
    first <- function(w) paste(utils::head(unique(paste(d$MGT_combo[w], d$SD_date[w])), 5), collapse = "; ")
    msg <- character()
    if (any(problem == "blank"))
      msg <- c(msg, paste0(sum(problem == "blank"), " tillage pass(es) have no implement (SD_equip) and not both ",
                           "SD_mixeff and SD_depth. First affected: ", first(problem == "blank")))
    if (any(problem == "unknown")) {
      u <- unique(equip[problem == "unknown"])
      msg <- c(msg, paste0("No T-DISC values for ", length(u), " implement name(s): ",
                           paste(utils::head(sQuote(u, FALSE), 10), collapse = ", "),
                           if (length(u) > 10) paste0(" (+", length(u) - 10, " more)") else "",
                           ". Use a name from tdisc_implements() / tdisc_mapping(), add it to `implements`, ",
                           "or enter both SD_mixeff and SD_depth on those passes."))
    }
    if (any(problem == "partial")) {
      u <- unique(equip[problem == "partial"])
      msg <- c(msg, paste0("Operation(s) ", paste(utils::head(sQuote(u, FALSE), 5), collapse = ", "),
                           " map to several T-DISC implements, so a single override is ambiguous: ",
                           "enter both SD_mixeff and SD_depth for the operation, or neither."))
    }
    if (length(msg)) stop(paste(msg, collapse = "\n"), call. = FALSE)
  }
  keep <- !vapply(out, is.null, logical(1))
  if (!any(keep)) return(empty)
  do.call(rbind, out[keep])
}

# EPA mixing recurrence for implements in order (depth in cm)
.epa_day <- function(me, depth) {
  S <- 0
  for (i in seq_along(me)) S <- S + me[i] * max(depth[i] - S, 0)
  S
}

# EPA Tier-3 class upper bound of each intensity (class Z: 0)
.ti_class_value <- function(ti) {
  ub <- c(0.001, 0.01, 0.04, 0.075, 0.111, 0.144, 0.162, 0.202, 0.252, 0.268, 0.449, 1)
  ti <- pmin(pmax(ti, 0), 1)
  idx <- findInterval(ti, c(0, ub[-length(ub)]), left.open = TRUE)
  idx[idx < 1] <- 1
  v <- ub[idx]
  v[ti < 0.001] <- 0
  v
}

.tdisc_designation <- function(ti) ifelse(ti <= 0.075, "NT", ifelse(ti <= 0.252, "RT", "CT"))

# Daily tillage intensity per unit, on the scale of the chosen method, for the
# rule that ends crops at intensive tillage:
#   STIR : sum of STIR values of the day's passes
#   EPA  : mixed depth / 30 cm, with implement values as in compute_disturbance()
.daily_tillage <- function(dist, method = c("STIR", "EPA")) {
  method <- match.arg(method)
  p <- .tillage_passes(dist, method, strict = FALSE)
  if (!nrow(p)) return(tibble::tibble(MGT_combo = character(), SD_date = as.Date(character()),
                                      intensity = numeric()))
  if (method == "STIR") {
    p %>% dplyr::group_by(MGT_combo, SD_date = date) %>%
      dplyr::summarise(intensity = sum(stir), .groups = "drop")
  } else {
    p %>% dplyr::arrange(MGT_combo, date, depth_cm, me) %>%
      dplyr::group_by(MGT_combo, SD_date = date) %>%
      dplyr::summarise(intensity = .epa_day(me, depth_cm) / 30, .groups = "drop")
  }
}

# Which scale to use for the intensive-tillage rule. "auto": STIR when STIR
# values are recorded (SD_stir, or STIR-like SD_mixeff in older workbooks);
# otherwise EPA when passes carry implement names or mixing efficiencies.
.tillage_method <- function(dist, tillage_end = c("auto", "STIR", "EPA", "none")) {
  tillage_end <- match.arg(tillage_end)
  if (tillage_end != "auto") return(tillage_end)
  if (is.null(dist) || nrow(dist) == 0) return("none")
  st <- if ("SD_stir" %in% names(dist)) suppressWarnings(as.numeric(dist$SD_stir)) else NA
  if (any(!is.na(st))) return("STIR")
  me <- suppressWarnings(as.numeric(dist$SD_mixeff))
  has_equip <- "SD_equip" %in% names(dist) && any(!is.na(dist$SD_equip) & trimws(dist$SD_equip) != "")
  if (any(me > 1, na.rm = TRUE)) return("STIR")       # older workbooks: STIR values in SD_mixeff
  if (has_equip || any(!is.na(me))) "EPA" else "none"
}
