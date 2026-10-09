#' Prepare nitrogen rates by crop (internal)
#'
#' Converts each amendment's `SA_N` to kg N/ha using `SA_units` and assigns it
#' to the crop it was applied for: the first harvest after the application.
#'
#' \itemize{
#'   \item A crop's window runs from the previous harvest (exclusive) to its own
#'         harvest (inclusive). The first window in a unit starts at
#'         `rot_start`. Harvests are cash and perennial crops (each cutting is a
#'         harvest); cover crops and fallow are not, so N applied before a cover
#'         crop counts toward the next cash crop.
#'   \item The harvest date is `CD_harv_date`, or `CD_term_date` when there is
#'         no harvest date (as for yields). `crop_year` is the calendar year of
#'         that harvest, so it matches `yield$year`.
#'   \item Amendments before `rot_start` are left out; amendments after the
#'         unit's last harvest have no crop yet and are reported.
#'   \item Amendments without an `SA_N` value are not included, so a crop with
#'         amendments but no N information is absent (unknown), not zero.
#'   \item If no amendment for a crop could be converted, `N_kg_ha` is NA; if
#'         only some could be converted, the total is a lower bound and
#'         `n_unconverted` counts the rest.
#'   \item A unit without any harvest dates falls back to calendar years
#'         (`crop_year` = year of application) and is reported.
#'   \item The first crop in a unit's record has no previous harvest, so its
#'         window opens at `rot_start` and N applied before the record began
#'         (for example the previous fall) is missing; `first_in_record` marks
#'         it and it is reported, so analyses can set it aside.
#' }
#'
#' The calendar-year totals of earlier versions are kept as `n_rate_calendar`.
#'
#' @param amend Amendment events (after overrides).
#' @param crop Raw crop rows (after date parsing and exclusions), with
#'   `CD_cat`, `CD_name`, `CD_harv_date`, `CD_term_date`.
#' @param rot_bounds Final rotation bounds (after overrides).
#' @param max_plausible_kg_ha Converted N rates above this are flagged.
#' @return A list with `n_rate` (one row per unit and harvest: `crop_year`,
#'   `harvest_date`, `crop`, `window_start`, `first_in_record`, `N_kg_ha`,
#'   `n_events`, `n_unconverted`),
#'   `n_rate_calendar` (one row per unit and calendar year, as before:
#'   `year`, `N_kg_ha_yr`, `n_events`, `n_unconverted`), `n_applications`
#'   (one row per amendment with N: `SA_date`, `year`, `crop_year`,
#'   `harvest_date`, `N_kg_ha`) and `assumptions`.
#' @keywords internal
#' @noRd
.prepare_n_rate <- function(amend, crop, rot_bounds, max_plausible_kg_ha = 1000) {

  rb <- rot_bounds %>% dplyr::select(MGT_combo, rot_start, rot_end)

  a <- amend %>%
    dplyr::filter(!is.na(SA_N)) %>%
    dplyr::mutate(.id = dplyr::row_number())

  conv <- .convert_rate_kg_ha(a$SA_N, a$SA_units)

  a <- a %>%
    dplyr::mutate(
      N_kg_ha  = conv$value,
      n_status = conv$status,
      year     = lubridate::year(SA_date)
    )

  # ---- harvests that end a crop window ------------------------------------------
  harv <- crop %>%
    dplyr::mutate(
      cat          = tolower(trimws(as.character(CD_cat))),
      harvest_date = dplyr::coalesce(CD_harv_date, CD_term_date)
    ) %>%
    dplyr::filter(!is.na(harvest_date), !(cat %in% c("cover", "fallow"))) %>%
    dplyr::inner_join(rb, by = "MGT_combo") %>%
    dplyr::filter(harvest_date >= rot_start, harvest_date <= rot_end) %>%
    dplyr::group_by(MGT_combo, harvest_date) %>%
    dplyr::summarize(
      crop      = paste(sort(unique(trimws(as.character(CD_name)))), collapse = " + "),
      rot_start = dplyr::first(rot_start),
      .groups = "drop"
    ) %>%
    dplyr::arrange(MGT_combo, harvest_date) %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::mutate(
      window_start   = dplyr::coalesce(dplyr::lag(harvest_date), rot_start),   # N on a harvest day goes to the next crop
      first_in_record = dplyr::row_number() == 1        # window opens at rot_start
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(-rot_start)

  # ---- assign each application to the first harvest after it -------------------
  a <- a %>%
    dplyr::inner_join(rb, by = "MGT_combo") %>%
    dplyr::filter(SA_date >= rot_start, SA_date <= rot_end)

  nxt <- a %>%
    dplyr::select(.id, MGT_combo, SA_date) %>%
    dplyr::inner_join(harv, by = "MGT_combo", relationship = "many-to-many") %>%
    dplyr::filter(harvest_date > SA_date) %>%
    dplyr::group_by(.id) %>%
    dplyr::slice_min(harvest_date, n = 1, with_ties = FALSE) %>%
    dplyr::ungroup() %>%
    dplyr::select(.id, harvest_date, crop, window_start, first_in_record)

  no_harv_units <- setdiff(unique(a$MGT_combo), unique(harv$MGT_combo))

  a <- a %>%
    dplyr::left_join(nxt, by = ".id") %>%
    dplyr::mutate(
      crop_year = dplyr::case_when(
        MGT_combo %in% no_harv_units ~ year,            # no harvest dates: calendar year
        !is.na(harvest_date)         ~ lubridate::year(harvest_date),
        TRUE                         ~ NA_real_          # after the last harvest
      ),
      crop_year = as.integer(crop_year)
    )

  # ---- totals ---------------------------------------------------------------------
  sum_n <- function(x) if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE)

  n_rate <- a %>%
    dplyr::filter(!is.na(crop_year)) %>%
    dplyr::group_by(MGT_combo, crop_year, harvest_date, crop, window_start, first_in_record) %>%
    dplyr::summarize(
      N_kg_ha       = sum_n(N_kg_ha),
      n_events      = dplyr::n(),
      n_unconverted = sum(n_status != "converted"),
      .groups = "drop"
    ) %>%
    dplyr::arrange(MGT_combo, crop_year, harvest_date)

  n_rate_calendar <- a %>%
    dplyr::group_by(MGT_combo, year) %>%
    dplyr::summarize(
      N_kg_ha_yr    = sum_n(N_kg_ha),
      n_events      = dplyr::n(),
      n_unconverted = sum(n_status != "converted"),
      .groups = "drop"
    )

  n_applications <- a %>%
    dplyr::select(MGT_combo, SA_date, dplyr::any_of(c("SA_cat", "SA_source")),
                  year, crop_year, harvest_date, crop, N_kg_ha, n_status) %>%
    dplyr::arrange(MGT_combo, SA_date)

  # ---- assumptions ------------------------------------------------------------------
  src <- if ("SA_source" %in% names(a)) as.character(a$SA_source) else rep(NA_character_, nrow(a))

  flags_n <- tibble::tibble(
    MGT_combo  = a$MGT_combo,
    source     = "n_rate",
    name       = src,
    date_start = a$SA_date,
    date_end   = a$SA_date,
    type       = dplyr::case_when(
      a$n_status == "no_value"                       ~ "n_not_numeric",
      a$n_status == "missing_units"                  ~ "n_missing_units",
      a$n_status %in% c("unknown_units",
                        "bushels_not_converted")     ~ "n_unknown_units",
      a$n_status == "converted" &
        a$N_kg_ha > max_plausible_kg_ha              ~ "n_rate_implausible",
      a$MGT_combo %in% no_harv_units                 ~ "n_no_harvest_dates",
      is.na(a$crop_year)                             ~ "n_after_last_harvest",
      TRUE                                           ~ NA_character_
    )
  ) %>%
    dplyr::filter(!is.na(type))

  # first crop in each unit's record: N applied before the record began (for
  # example the previous fall) is not in the data, so its total may be low
  first_crop <- n_rate %>%
    dplyr::filter(first_in_record %in% TRUE) %>%
    dplyr::transmute(MGT_combo, source = "n_rate", name = crop,
                     date_start = window_start, date_end = harvest_date,
                     type = "n_first_crop_in_record")

  flags <- dplyr::bind_rows(flags_n, first_crop) %>%
    .add_assumption_text()

  list(n_rate = n_rate, n_rate_calendar = n_rate_calendar,
       n_applications = n_applications, assumptions = flags)
}
