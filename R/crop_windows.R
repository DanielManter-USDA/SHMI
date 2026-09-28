#' Build species-episode crop windows (internal)
#'
#' Converts raw Crop_Diversity rows into one row per *species episode*: a
#' continuous period during which one species is present in a management
#' unit. Mixtures, relays, and intercrops are simply overlapping episodes, so
#' no sequence number (`CD_seq_num`) or mixture flag (`CD_mix`) is needed.
#'
#' ## Row semantics
#' \itemize{
#'   \item \code{CD_plant_date} starts an episode.
#'   \item Non-perennials end at \code{CD_harv_date}. A \code{CD_term_date} is
#'         also accepted (guards against users putting annual kills in the
#'         wrong column); if both are present the earlier is used.
#'   \item Perennials end only at \code{CD_term_date}; harvests are cuttings.
#' }
#'
#' ## Attaching rows without a plant date
#' \itemize{
#'   \item Perennial: attached to the open (unterminated) stand of the same
#'         species, if any.
#'   \item Non-perennial: attached to the previous episode of the same species
#'         if it is within \code{max_multi_harvest_days} and no other species
#'         was planted in between (repeat harvests of one planting).
#'   \item Otherwise a new episode is created with an imputed start.
#' }
#'
#' ## Crop categories
#' \code{CD_cat} is matched case- and whitespace-insensitively. \code{perennial}
#' and \code{woody perennial} are perennial; \code{annual}, \code{cash} and
#' \code{cover} are annual; \code{fallow} is fallow. Missing or unrecognized
#' values are treated as annual and flagged as checks, so a typo such as
#' \code{"perenial"} is visible rather than silently changing how the crop
#' ends. Output \code{CD_cat} is one of \code{"Annual"}, \code{"Perennial"},
#' \code{"Fallow"}.
#'
#' ## Imputation rules (each logged in \code{assumptions})
#' \itemize{
#'   \item Missing start, some other crop ended before this one: start at the
#'         latest such end (\code{start_prev_end}).
#'   \item Missing start, nothing ended earlier (calendar-year truncation at
#'         the start of the record): \code{rot_start} (\code{start_rot_start}).
#'   \item Missing end, a later planting exists after the last date this crop
#'         was observed: end at that planting (\code{end_next_planting}).
#'   \item Missing end, no later planting (calendar-year truncation at the end
#'         of the record): \code{rot_end} (\code{end_rot_end}).
#' }
#'
#' @param crop Raw crop rows with \code{MGT_combo}, \code{CD_cat},
#'   \code{CD_name}, \code{CD_plant_date}, \code{CD_harv_date},
#'   \code{CD_term_date}. Yield is handled separately by
#'   \code{.prepare_yield()} from the raw rows.
#' @param rot_bounds Calendar-year rotation bounds with \code{MGT_combo},
#'   \code{rot_start}, \code{rot_end}.
#' @param perennial_cats Values of \code{CD_cat} treated as perennial
#'   (compared after lower-casing and trimming whitespace).
#' @param max_multi_harvest_days Maximum days from an annual planting to a
#'   later harvest row (without a plant date) for that row to be treated as a
#'   repeat harvest of the same planting.
#' @param max_annual_days Annual episodes longer than this (days, after
#'   imputation) are flagged as \code{annual_long_episode}. The default (400)
#'   leaves room for winter annuals planted in late summer and harvested the
#'   following summer.
#'
#' @return A list with \code{windows} (one row per species episode) and
#'   \code{assumptions} (one row per imputation or data check).
#' @keywords internal
#' @noRd
.build_crop_windows <- function(crop,
                                rot_bounds,
                                perennial_cats = c("perennial", "woody perennial"),
                                max_multi_harvest_days = 365,
                                max_annual_days = 400) {

  crop <- crop %>%
    dplyr::mutate(
      .cat     = .normalize_cat(CD_cat, perennial_cats),
      .per     = .cat %in% "Perennial",
      .row_end = dplyr::if_else(
        .per,
        CD_term_date,
        pmin(CD_harv_date, CD_term_date, na.rm = TRUE)
      )
    )

  # ------------------------------------------------------------------
  # Row-level data checks (do not change windows; logged only)
  # ------------------------------------------------------------------
  no_dates <- is.na(crop$CD_plant_date) & is.na(crop$CD_harv_date) &
    is.na(crop$CD_term_date)

  row_flags <- dplyr::bind_rows(
    crop[no_dates, ] %>%
      dplyr::mutate(type = "row_no_dates"),

    crop[!no_dates, ] %>%
      dplyr::filter(!.per, !is.na(CD_harv_date), !is.na(CD_term_date),
                    CD_harv_date != CD_term_date) %>%
      dplyr::mutate(type = "annual_harv_term_conflict"),

    crop[!no_dates, ] %>%
      dplyr::filter(tolower(CD_cat) == "cash",
                    is.na(CD_harv_date), !is.na(CD_term_date)) %>%
      dplyr::mutate(type = "annual_term_only"),

    crop[!no_dates, ] %>%
      dplyr::filter(!.per, .is_usually_perennial(CD_name)) %>%
      dplyr::distinct(MGT_combo, CD_name, .keep_all = TRUE) %>%
      dplyr::mutate(type = "check_category"),

    crop[!no_dates, ] %>%
      dplyr::filter(.per, .is_usually_annual(CD_name)) %>%
      dplyr::distinct(MGT_combo, CD_name, .keep_all = TRUE) %>%
      dplyr::mutate(type = "check_category_perennial"),

    crop[!no_dates, ] %>%
      dplyr::filter(is.na(CD_cat) | trimws(CD_cat) == "") %>%
      dplyr::distinct(MGT_combo, CD_name, .keep_all = TRUE) %>%
      dplyr::mutate(type = "missing_category"),

    crop[!no_dates, ] %>%
      dplyr::filter(!is.na(CD_cat), trimws(CD_cat) != "", is.na(.cat)) %>%
      dplyr::distinct(MGT_combo, CD_name, CD_cat, .keep_all = TRUE) %>%
      dplyr::mutate(type = "unknown_category"),

    crop[!no_dates, ] %>%
      dplyr::filter(.is_placeholder_name(CD_name)) %>%
      dplyr::distinct(MGT_combo, CD_name, .keep_all = TRUE) %>%
      dplyr::mutate(type = "placeholder_name")
  ) %>%
    dplyr::transmute(MGT_combo, CD_name,
                     crop_start = CD_plant_date, crop_end = .row_end, type)

  crop <- crop[!no_dates, ]

  # ------------------------------------------------------------------
  # Build episodes unit by unit
  # ------------------------------------------------------------------
  rb <- rot_bounds %>% dplyr::select(MGT_combo, rot_start, rot_end)

  units <- split(crop, crop$MGT_combo)

  res <- lapply(names(units), function(u) {
    b <- rb[rb$MGT_combo == u, ]
    out <- .unit_episodes(units[[u]], b$rot_start[1], b$rot_end[1],
                          max_multi_harvest_days)
    out$windows$MGT_combo <- rep(u, nrow(out$windows))
    out$flags$MGT_combo   <- rep(u, nrow(out$flags))
    out
  })

  windows <- dplyr::bind_rows(lapply(res, `[[`, "windows"))
  ep_flags <- dplyr::bind_rows(lapply(res, `[[`, "flags"))

  # ------------------------------------------------------------------
  # Harmonize category and finalize columns
  # ------------------------------------------------------------------
  # Missing/unrecognized categories were treated as annual (and flagged)
  windows <- windows %>%
    dplyr::mutate(
      CD_cat = dplyr::coalesce(.normalize_cat(CD_cat, perennial_cats), "Annual")
    ) %>%
    dplyr::arrange(MGT_combo, crop_start, CD_name) %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::mutate(episode_id = dplyr::row_number()) %>%
    dplyr::ungroup() %>%
    dplyr::select(MGT_combo, episode_id, CD_cat, CD_name,
                  crop_start, crop_end, start_imputed, end_imputed)

  # Annual episodes longer than max_annual_days (after imputation) usually
  # mean a missing end date or a perennial stand coded as annual
  long_flags <- windows %>%
    dplyr::filter(CD_cat == "Annual",
                  as.numeric(crop_end - crop_start) + 1 > max_annual_days) %>%
    dplyr::transmute(MGT_combo, CD_name, crop_start, crop_end,
                     type = "annual_long_episode")

  assumptions <- dplyr::bind_rows(ep_flags, row_flags, long_flags) %>%
    dplyr::transmute(MGT_combo, source = "crop", name = CD_name,
                     date_start = crop_start, date_end = crop_end, type) %>%
    .add_assumption_text()

  list(windows = windows, assumptions = assumptions)
}


# ----------------------------------------------------------------------
# Episode construction for one management unit
# ----------------------------------------------------------------------
.unit_episodes <- function(df, rot_start, rot_end, max_days) {

  eps   <- list()
  flags <- list()

  # Each flag records the index of the episode it refers to
  add_flag <- function(ep, type) {
    flags[[length(flags) + 1]] <<- list(ep = ep, type = type)
  }

  plants <- df[!is.na(df$CD_plant_date), c("CD_name", "CD_plant_date")]

  new_ep <- function(r, start) {
    list(CD_name = r$CD_name, CD_cat = r$CD_cat, per = r$.per,
         start = start, end = r$.row_end, last = .row_seen(r), n = 1L)
  }

  for (nm in unique(df$CD_name)) {

    g   <- df[df$CD_name == nm, ]
    key <- dplyr::coalesce(g$CD_plant_date, g$.row_end, g$CD_harv_date)
    g   <- g[order(key), ]
    last <- 0L   # index of this species' most recent episode in eps

    for (i in seq_len(nrow(g))) {
      r    <- g[i, ]
      p    <- r$CD_plant_date
      seen <- .row_seen(r)
      ref  <- if (!is.na(r$.row_end)) r$.row_end else seen

      # ---- Row with a plant date ----
      if (!is.na(p)) {
        # Duplicate rows for the same annual planting: merge
        if (last > 0 && !r$.per && !is.na(eps[[last]]$start) &&
            eps[[last]]$start == p) {
          eps[[last]]$end    <- .max_date(eps[[last]]$end, r$.row_end)
          eps[[last]]$last   <- .max_date(eps[[last]]$last, seen)
          next
        }
        eps[[length(eps) + 1]] <- new_ep(r, p)
        last <- length(eps)
        next
      }

      # ---- Row without a plant date: attach or create orphan ----
      attach <- FALSE
      if (last > 0) {
        if (r$.per) {
          attach <- is.na(eps[[last]]$end)          # stand still open
        } else {
          anchor <- if (!is.na(eps[[last]]$start)) eps[[last]]$start else eps[[last]]$last
          other  <- plants$CD_name != nm &
            plants$CD_plant_date > anchor &
            plants$CD_plant_date <= ref
          attach <- as.numeric(ref - anchor) < max_days && !any(other)
        }
      }

      if (attach) {
        eps[[last]]$n      <- eps[[last]]$n + 1L
        eps[[last]]$last   <- .max_date(eps[[last]]$last, seen)
        eps[[last]]$end    <- .max_date(eps[[last]]$end, r$.row_end)
        if (!r$.per) add_flag(last, "annual_multi_harvest")
      } else {
        eps[[length(eps) + 1]] <- new_ep(r, as.Date(NA))
        last <- length(eps)
      }
    }
  }

  E <- dplyr::bind_rows(lapply(eps, function(e) {
    tibble::tibble(
      CD_name = as.character(e$CD_name), CD_cat = as.character(e$CD_cat),
      per = e$per,
      start = e$start, end = e$end, last = e$last, n = e$n
    )
  }))

  E$start_rec     <- E$start
  E$start_imputed <- is.na(E$start)
  E$end_imputed   <- is.na(E$end)

  # ---- Impute missing starts ----
  for (i in which(is.na(E$start))) {
    ref   <- if (!is.na(E$end[i])) E$end[i] else E$last[i]
    prior <- E$end[-i]
    prior <- prior[!is.na(prior) & prior < ref]
    if (length(prior) > 0) {
      E$start[i] <- max(prior)
      add_flag(i, "start_prev_end")
    } else {
      E$start[i] <- rot_start
      add_flag(i, "start_rot_start")
    }
  }

  # ---- Impute missing ends ----
  for (i in which(is.na(E$end))) {
    after <- E$start_rec[-i]
    after <- after[!is.na(after) & after > max(E$last[i], E$start[i])]
    if (length(after) > 0) {
      E$end[i] <- min(after)
      add_flag(i, "end_next_planting")
    } else {
      E$end[i] <- as.Date(rot_end)
      add_flag(i, "end_rot_end")
    }
  }

  # ---- Impossible windows ----
  bad <- E$end < E$start
  for (i in which(bad)) add_flag(i, "end_before_start")
  E$end[bad] <- E$start[bad]

  for (i in which(E$per & E$n > 1)) add_flag(i, "perennial_rows_attached")

  # Attach the final window of the flagged episode to each flag
  ep   <- vapply(flags, function(f) as.integer(f$ep), integer(1))
  type <- vapply(flags, function(f) f$type, character(1))
  fl <- tibble::tibble(
    CD_name    = E$CD_name[ep],
    type       = type,
    crop_start = E$start[ep],
    crop_end   = E$end[ep]
  )

  list(
    windows = E %>%
      dplyr::transmute(CD_cat, CD_name, crop_start = start, crop_end = end,
                       start_imputed, end_imputed),
    flags = fl
  )
}


# ----------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------
.max_date <- function(...) {
  x <- c(...)
  if (all(is.na(x))) as.Date(NA) else max(x, na.rm = TRUE)
}

# Latest date on which a row shows the crop was present
.row_seen <- function(r) {
  .max_date(r$CD_plant_date, r$CD_harv_date, r$CD_term_date)
}

# Species commonly grown as perennials (used only for a data-quality check)
.is_usually_perennial <- function(x) {
  grepl("^(alfalfa|orchardgrass|timothy|bahiagrass|fescue|bermudagrass|switchgrass|bromegrass|bluegrass)",
        tolower(x))
}

# Standardize CD_cat: "Perennial", "Annual", "Fallow", or NA (missing/unknown)
.normalize_cat <- function(x, perennial_cats = c("perennial", "woody perennial")) {
  k <- tolower(trimws(as.character(x)))
  dplyr::case_when(
    k %in% tolower(trimws(perennial_cats))  ~ "Perennial",
    k %in% c("annual", "cash", "cover")      ~ "Annual",
    k %in% "fallow"                          ~ "Fallow",
    TRUE                                     ~ NA_character_
  )
}

# Species almost always grown as annuals (used only for a data-quality check).
# "rye" matches cereal rye but not ryegrass.
.is_usually_annual <- function(x) {
  grepl(paste0("^(corn|maize|soybeans?|wheat|oats?|barley|sorghum|cotton|",
               "peanuts?|canola|sunflowers?|triticale|millet|buckwheat|radish|",
               "turnip)\\b|^rye(?!grass)"),
        tolower(trimws(x)), perl = TRUE)
}

# Placeholder species names that should be replaced by real names; each
# distinct name counts as a separate species in Diversity
.is_placeholder_name <- function(x) {
  grepl("^(species|sp\\.?|spp\\.?|unknown|other|none given|tbd|n/?a)\\s*[0-9]*$",
        tolower(trimws(x)))
}

# Crop episodes whose end was imputed although soil disturbance is recorded
# between their start and the imputed end (a termination may be missing).
# Perennial stands are skipped: their harvest operations are recorded as
# disturbances. Returns an assumptions table (possibly empty).
.check_imputed_end_disturbance <- function(windows, dist) {
  empty <- .add_assumption_text(tibble::tibble(
    MGT_combo = character(), source = character(), name = character(),
    date_start = as.Date(character()), date_end = as.Date(character()),
    type = character()))
  if (is.null(dist) || nrow(dist) == 0) return(empty)

  w <- windows %>%
    dplyr::filter(end_imputed, CD_cat != "Perennial") %>%
    dplyr::select(MGT_combo, CD_name, crop_start, crop_end)
  if (nrow(w) == 0) return(empty)

  hits <- w %>%
    dplyr::inner_join(dist %>% dplyr::filter(!is.na(SD_date)) %>%
                        dplyr::select(MGT_combo, SD_date),
                      by = "MGT_combo", relationship = "many-to-many") %>%
    dplyr::filter(SD_date > crop_start, SD_date < crop_end) %>%
    dplyr::group_by(MGT_combo, CD_name, crop_start, crop_end) %>%
    dplyr::summarise(first_dist = min(SD_date), .groups = "drop")
  if (nrow(hits) == 0) return(empty)

  hits %>%
    dplyr::transmute(MGT_combo, source = "crop", name = CD_name,
                     date_start = crop_start, date_end = crop_end,
                     type = "end_imputed_after_disturbance",
                     first_dist) %>%
    .add_assumption_text(keep = "first_dist") %>%
    dplyr::mutate(message = paste0(message, " First disturbance after planting: ",
                                   format(first_dist, "%Y-%m-%d"), ".")) %>%
    dplyr::select(-first_dist)
}

# Days covered by the union of a set of date intervals (overlaps count once)
.union_days <- function(start, end) {
  ok <- !is.na(start) & !is.na(end)
  s  <- as.numeric(start[ok])
  e  <- as.numeric(end[ok])
  if (length(s) == 0) return(0L)
  o  <- order(s, e)
  s  <- s[o]
  e  <- e[o]
  run_end <- cummax(e)
  block   <- cumsum(c(TRUE, s[-1] > run_end[-length(run_end)]))
  as.integer(sum(tapply(e, block, max) - tapply(s, block, min) + 1))
}

.assumption_levels <- c(
  start_rot_start           = "assumption",
  start_prev_end            = "assumption",
  end_next_planting         = "assumption",
  end_rot_end               = "assumption",
  perennial_rows_attached   = "assumption",
  annual_multi_harvest      = "assumption",
  annual_harv_term_conflict = "check",
  annual_term_only          = "check",
  check_category            = "check",
  check_category_perennial  = "check",
  missing_category          = "check",
  unknown_category          = "check",
  placeholder_name          = "check",
  annual_long_episode       = "check",
  end_imputed_after_disturbance = "check",
  end_before_start          = "check",
  row_no_dates              = "check",
  yield_bushels_not_converted = "check",
  yield_bushels_test_weight   = "assumption",
  yield_unknown_units         = "check",
  yield_missing_units         = "check",
  yield_no_value              = "check",
  n_not_numeric               = "check",
  n_unknown_units             = "check",
  n_missing_units             = "check",
  n_rate_implausible          = "check"
)

.assumption_messages <- c(
  start_rot_start = paste(
    "No plant date and no earlier crop in the record; start set to rotation",
    "start (calendar-year truncation)."),
  start_prev_end = paste(
    "No plant date; start set to the end of the most recent earlier crop",
    "(assumes planting right after it)."),
  end_next_planting = paste(
    "No end date; ended at the next recorded planting. Add a harvest or",
    "termination date if this crop continued (relay or intercrop)."),
  end_rot_end = paste(
    "No end date and no later planting; end set to rotation end",
    "(calendar-year truncation)."),
  perennial_rows_attached = paste(
    "Rows without a plant date were attached to this perennial stand as",
    "harvests/cuttings."),
  annual_multi_harvest = paste(
    "A harvest row without a plant date was treated as a repeat harvest of",
    "the same annual planting."),
  annual_harv_term_conflict = paste(
    "Non-perennial has different harvest and termination dates; the earlier",
    "date was used as the end."),
  annual_term_only = paste(
    "Cash crop has a termination date but no harvest date; termination date",
    "used as the end."),
  check_category = paste(
    "Species is usually perennial but CD_cat is not perennial; harvests will",
    "end it as an annual. Check CD_cat."),
  check_category_perennial = paste(
    "Species is usually annual but CD_cat is perennial; it runs until a",
    "termination date and harvests do not end it. Check CD_cat (a nurse crop",
    "sown with a perennial forage is annual)."),
  missing_category = "CD_cat is missing; the crop was treated as annual. Check CD_cat.",
  unknown_category = paste(
    "CD_cat is not a recognized category (Annual, Cash, Cover, Perennial,",
    "Woody perennial, Fallow); the crop was treated as annual. Check CD_cat."),
  placeholder_name = paste(
    "Placeholder species name; each distinct name counts as a separate",
    "species in Diversity. Replace with the real species name."),
  annual_long_episode = paste(
    "Annual crop episode is longer than 400 days. Usually a missing",
    "harvest/termination date, or a stand kept for more than one growing",
    "season that should be coded perennial."),
  end_imputed_after_disturbance = paste(
    "End date was imputed, but soil disturbance is recorded before it. If",
    "that operation ended the crop (e.g. fall tillage), add a termination",
    "date; in-season cultivation needs no change."),
  end_before_start = "End date was before start date; window set to a single day. Check dates.",
  row_no_dates = "Row has no plant, harvest, or termination date and was ignored.",
  yield_bushels_not_converted = paste(
    "Yield is in bushels but this crop has no standard test weight in the",
    "lookup; not converted. Raw value kept in CD_yield."),
  yield_bushels_test_weight = paste(
    "Yield in bushels converted to kg/ha with a standard test weight",
    "(see yield$lb_per_bu); result is at market moisture, not dry matter."),
  yield_unknown_units = "Yield units not recognized; not converted. Raw value kept in CD_yield.",
  yield_missing_units = "Yield value has no units; not converted. Raw value kept in CD_yield.",
  yield_no_value = "Yield value is not numeric; not converted. Raw value kept in CD_yield.",
  n_not_numeric = "SA_N is not numeric; N not converted. The annual total for this year is incomplete.",
  n_unknown_units = paste(
    "SA_units not recognized for SA_N (e.g. volume or per-plot units);",
    "N not converted. The annual total for this year is incomplete."),
  n_missing_units = "SA_N has no units; N not converted. The annual total for this year is incomplete.",
  n_rate_implausible = paste(
    "Converted N rate exceeds 1,000 kg N/ha. Check SA_N and SA_units:",
    "SA_units may describe the product rate rather than the N amount.")
)

# Add level and message to an assumptions table and order its columns
.add_assumption_text <- function(df, keep = character(0)) {
  df %>%
    dplyr::mutate(
      level   = unname(.assumption_levels[type]),
      message = unname(.assumption_messages[type])
    ) %>%
    dplyr::select(MGT_combo, source, name, date_start, date_end,
                  level, type, message, dplyr::all_of(keep)) %>%
    dplyr::arrange(MGT_combo, date_start, name)
}
