#' Read, validate, and prepare SHMI inputs from an Excel workbook
#'
#' Reads a completed SHMI workbook, validates it, converts crop records into
#' species episodes, and returns the rotation-scale tables used by
#' [build_shmi()], together with a table of every assumption made along the
#' way.
#'
#' @section Workbook:
#' The workbook follows the SHMI template (see [download_shmi_template()]).
#' Sheets `Mgt_Unit`, `Crop_Diversity`, `Soil_Disturbance`,
#' `Soil_Amendments`, and `Animal_Diversity` are read, each with column names
#' on the fourth row. The disturbance, amendment, and animal sheets may be
#' empty. The workbook is first checked by [validate_excel_input()], and
#' execution stops with a list of errors if it fails.
#'
#' @section Crop episodes:
#' Crop rows become species episodes: one row per species per continuous
#' period of presence. Mixtures, relays, and intercrops are simply
#' overlapping episodes; `CD_seq_num` and `CD_mix` are not used. A plant date
#' starts an episode. Non-perennials end at harvest (a termination date is
#' also accepted; if both are given, the earlier is used). Perennials end
#' only at termination, and harvest rows without a plant date are attached to
#' the standing crop as cuttings. Missing dates are filled as follows:
#' * a crop with no plant date starts at the end of the most recent earlier
#'   crop, or at the rotation start if nothing ended earlier (records cut off
#'   at the start of a calendar year);
#' * a crop with no end date ends at the next recorded planting, or at the
#'   rotation end if there is none (records cut off at the end of a calendar
#'   year).
#'
#' Every such imputation and data-quality check is recorded in
#' `assumptions`.
#'
#' @section Crops without an end date:
#' A crop with no harvest or termination record is first given an imputed
#' end: the next recorded planting or, if none, the end of the evaluation
#' window. It then ends earlier if intensive tillage is recorded after its
#' planting: the first day whose passes sum to STIR >= 80, or whose EPA
#' tillage intensity (mixed depth / 30 cm) is >= 0.252. Both thresholds are
#' the lower bound of the conventional-tillage class (TI 0.252). Each such
#' change is logged as `end_intensive_tillage`. Crops that still run to the
#' end of the window although lighter disturbance is recorded are flagged
#' (`end_window_light_tillage`).
#'
#' @section Rotation window and overrides:
#' The rotation window is the denominator of every sub-index, so it must not
#' depend on management. With `rotation_window = "calendar"` (default from
#' 1.2.0) it runs from 1 January of the first year with a record to
#' 31 December of the last. Bare periods before the first and after the last
#' recorded event are therefore scored as bare, and all four sub-indices
#' share the same window. `rotation_window = "events"` reproduces
#' SHMI <= 1.1.0, where the window ran from the first to the last recorded
#' event; that excluded leading and trailing bare periods from the Cover
#' denominator and so inflated Cover, most strongly in winter and spring.
#'
#' To evaluate a fixed period, set `start_date_override` and/or
#' `end_date_override`: events outside the window are removed, crop and
#' animal periods are clipped to it, and the window boundaries are exactly
#' the override dates (under `"calendar"`). A unit whose records begin after
#' the start override is scored as having no cover, tillage, or inputs
#' before its first record, following the missing-record rule. Because
#' Organic Inputs and Inverse Disturbance are scored by calendar year,
#' overrides are best placed on year boundaries; other dates trigger a
#' message. With `end_at_sample_date = TRUE`, each unit is cut off at its
#' `MGT_sample_date` (from the `Mgt_Unit` sheet); units without a sample
#' date are kept uncut and reported.
#'
#' @section Yield and nitrogen rate:
#' With `calc_yield = TRUE`, each harvest row with a yield is converted to
#' kg/ha. Bushels are converted with a standard test weight for the crop
#' (results at market moisture); other units are kept unconverted and
#' reported. With `calc_n_rate = TRUE`, `SA_N` is converted to kg N/ha using
#' `SA_units` and summed by unit and year; years whose N cannot be converted
#' are `NA`, not zero. Unconverted values are listed in `assumptions`.
#'
#' @param path Path to the SHMI Excel workbook.
#' @param exclude Optional character vector of `MGT_combo` values to leave
#'   out.
#' @param verbose Logical. Print progress and a summary of assumptions.
#' @param start_date_override,end_date_override Optional start and end of the
#'   evaluation window (a `Date` or a string such as `"2018-01-01"`).
#' @param end_at_sample_date Logical. Cut each unit's records off at its
#'   `MGT_sample_date`.
#' @param rotation_window `"calendar"` (default) or `"events"` (SHMI
#'   <= 1.1.0 behaviour); see *Rotation window and overrides*.
#' @param tillage_end Scale for the intensive-tillage end rule: `"auto"`
#'   (default; EPA when every disturbance pass has a depth and mixing
#'   efficiencies are <= 1, otherwise STIR), `"STIR"`, `"EPA"`, or `"none"`
#'   to switch the rule off. See *Crops without an end date*.
#' @param max_rot_range Maximum plausible rotation length in years; longer
#'   spans stop with an error, since they usually indicate a mistyped date.
#' @param calc_yield Logical. Also return converted yields.
#' @param calc_n_rate Logical. Also return annual nitrogen rates.
#'
#' @return A named list:
#' * `rot_bounds`: rotation start and end dates and years for each unit.
#' * `mgt`: management-unit metadata for units with at least one dated
#'   record.
#' * `crop`: species episodes (`MGT_combo`, `episode_id`, `CD_cat`,
#'   `CD_name`, `crop_start`, `crop_end`, `start_imputed`, `end_imputed`).
#'   `CD_cat` is standardized to `"Annual"` (Annual, Cash, Cover),
#'   `"Perennial"` (Perennial, Woody perennial) or `"Fallow"`, matched
#'   case-insensitively; missing or unrecognized values are treated as annual
#'   and flagged in `assumptions`.
#' * `dist`, `amend`, `animal`: disturbance, amendment, and animal events
#'   within the rotation window.
#' * `yield`: one row per harvest with a yield (`CD_yield`, `CD_yield_units`,
#'   `yield_kg_ha`, `yield_status`, `lb_per_bu`), or `NULL`.
#' * `n_rate`: one row per unit and year (`N_kg_ha_yr`, `n_events`,
#'   `n_unconverted`), or `NULL`.
#' * `assumptions`: one row per imputation or data check, with `MGT_combo`,
#'   `source` (`"crop"`, `"yield"`, or `"n_rate"`), `name`, `date_start`,
#'   `date_end`, `level` (`"assumption"` or `"check"`), `type`, and
#'   `message`.
#'
#' @seealso [build_shmi()], [validate_excel_input()],
#'   [download_shmi_template()], [get_shmi_example()]
#'
#' @examples
#' inputs <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
#'
#' # What was assumed, and what should be reviewed?
#' table(inputs$assumptions$type)
#' subset(inputs$assumptions, level == "check")
#'
#' # Evaluate a fixed period
#' inputs_2022_23 <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE,
#'                                       start_date_override = "2022-01-01",
#'                                       end_date_override   = "2023-12-31")
#' inputs_2022_23$rot_bounds
#'
#' @export
prepare_shmi_inputs <- function(path,
                                exclude = NULL,
                                verbose = TRUE,
                                start_date_override = NULL,
                                end_date_override   = NULL,
                                end_at_sample_date = FALSE,
                                max_rot_range = 200,
                                calc_yield  = FALSE,
                                calc_n_rate = FALSE,
                                rotation_window = c("calendar", "events"),
                                tillage_end = c("auto", "STIR", "EPA", "none")) {

  rotation_window <- match.arg(rotation_window)
  tillage_end     <- match.arg(tillage_end)

  # ------------------------------------------------------------
  # 1. Validate inputs
  # ------------------------------------------------------------
  cli::cli_progress_step("Validating inputs...")

  val <- validate_excel_input(path, verbose)

  if (!val$ok) {
    message("Excel input validation failed.\n")
    message("Errors:\n", paste0(" - ", val$errors, collapse = "\n"))
    stop("Fix the errors above and re-run prepare_shmi_inputs().")
  }

  if (length(val$warnings) > 0) {
    message("\nWarnings:")
    message(paste0(" - ", val$warnings, collapse = "\n"))
  }

  if (!is.null(start_date_override)) {
    start_date_override <- as.Date(start_date_override)
    if (is.na(start_date_override)) {
      stop("start_date_override must be a valid date (YYYY-MM-DD).", call. = FALSE)
    }
  }

  if (!is.null(end_date_override)) {
    end_date_override <- as.Date(end_date_override)
    if (is.na(end_date_override)) {
      stop("end_date_override must be a valid date (YYYY-MM-DD).", call. = FALSE)
    }
  }

  if (!is.null(start_date_override) && !is.null(end_date_override) &&
      start_date_override > end_date_override) {
    stop("start_date_override is after end_date_override.", call. = FALSE)
  }

  if ((!is.null(start_date_override) && format(start_date_override, "%m-%d") != "01-01") ||
      (!is.null(end_date_override)   && format(end_date_override,   "%m-%d") != "12-31")) {
    message("Note: date overrides not on calendar-year boundaries. Organic Inputs ",
            "and Inverse Disturbance count partial years as whole years.")
  }

  # ------------------------------------------------------------
  # 2. Read all sheets
  # ------------------------------------------------------------
  cli::cli_progress_step("Reading Excel file...")

  mgt <- .safe_read(
    path,
    sheet = "Mgt_Unit",
    required_cols = c("MGT_combo", "MGT_study", "MGT_field", "MGT_trt"),
    skip = 3,
    verbose = verbose
  ) %>%
    janitor::remove_empty("rows") %>%
    dplyr::filter(!(MGT_combo %in% exclude))

  if (end_at_sample_date) {
    if (!"MGT_sample_date" %in% names(mgt)) {
      stop("end_at_sample_date = TRUE requires an MGT_sample_date column in Mgt_Unit.",
           call. = FALSE)
    }
    mgt_dates <- mgt %>%
      select(MGT_combo, MGT_sample_date) %>%
      mutate(MGT_sample_date = as.Date(unname(.parse_shmi_date(MGT_sample_date))))

    no_date <- mgt_dates$MGT_combo[is.na(mgt_dates$MGT_sample_date)]
    if (length(no_date) > 0) {
      cli::cli_warn(c(
        "{length(no_date)} unit{?s} ha{?s/ve} no MGT_sample_date and will not be cut off.",
        "i" = "First affected: {.val {utils::head(no_date, 5)}}"
      ))
    }
  }

  crop <- .safe_read(
    path,
    sheet = "Crop_Diversity",
    required_cols = c("MGT_combo", "CD_plant_date", "CD_term_date"),
    skip = 3,
    verbose = verbose
  ) %>%
    dplyr::filter(!(MGT_combo %in% exclude))

  if (!"CD_harv_date" %in% names(crop))   crop$CD_harv_date   <- NA
  if (!"CD_yield" %in% names(crop))       crop$CD_yield       <- NA
  if (!"CD_yield_units" %in% names(crop)) crop$CD_yield_units <- NA_character_
  if (!"CD_cat" %in% names(crop))         crop$CD_cat         <- NA_character_
  if (!"CD_per_res" %in% names(crop))     crop$CD_per_res     <- NA

  crop <- crop %>%
    dplyr::mutate(
      CD_plant_date = as.Date(unname(.parse_shmi_date(CD_plant_date))),
      CD_harv_date  = as.Date(unname(.parse_shmi_date(CD_harv_date))),
      CD_term_date  = as.Date(unname(.parse_shmi_date(CD_term_date)))
    )

  # Irrigation per management unit: MGT_irr_cat on Mgt_Unit (any method other
  # than blank or "None"). Older workbooks recorded it per crop (CD_irr_cat,
  # CD_irr_amt); there, any irrigated crop marks its unit as irrigated.
  if ("MGT_irr_cat" %in% names(mgt)) {
    mgt$irrigated <- .is_irrigated(mgt$MGT_irr_cat)
  } else {
    irr_crop <- rep(FALSE, nrow(crop))
    if ("CD_irr_cat" %in% names(crop)) irr_crop <- irr_crop | .is_irrigated(crop$CD_irr_cat)
    if ("CD_irr_amt" %in% names(crop)) irr_crop <- irr_crop | ((suppressWarnings(as.numeric(crop$CD_irr_amt)) > 0) %in% TRUE)
    mgt$irrigated <- mgt$MGT_combo %in% crop$MGT_combo[irr_crop]
  }
  for (k in c("MGT_lat", "MGT_lon")) if (k %in% names(mgt)) mgt[[k]] <- suppressWarnings(as.numeric(mgt[[k]]))

  # Cash-crop ends (harvest, or termination when a cash crop has no harvest
  # date): they end T-DISC's crop intervals. Other harvests are kept too.
  harvests <- crop %>%
    dplyr::mutate(.cat = tolower(trimws(as.character(.data$CD_cat))),
                  .end = dplyr::if_else(is.na(.data$CD_harv_date) & .data$.cat %in% c("cash", "annual"),
                                        .data$CD_term_date, .data$CD_harv_date)) %>%
    dplyr::filter(!is.na(.data$.end)) %>%
    dplyr::transmute(MGT_combo = .data$MGT_combo,
                     CD_name   = trimws(as.character(.data$CD_name)),
                     CD_cat    = .data$.cat,
                     harv_date = .data$.end,
                     per_res   = suppressWarnings(as.numeric(.data$CD_per_res)))

  dist <- .safe_read(
    path,
    sheet = "Soil_Disturbance",
    required_cols = c("MGT_combo", "SD_date"),
    skip = 3,
    verbose = verbose
  ) %>%
    janitor::remove_empty("rows") %>%
    dplyr::filter(!(MGT_combo %in% exclude)) %>%
    dplyr::mutate(SD_date = as.Date(unname(.parse_shmi_date(SD_date))))
  # implement name, the override values (mixing efficiency, depth) and STIR are each optional
  for (k in c("SD_equip", "SD_mixeff", "SD_depth", "SD_stir")) if (!k %in% names(dist)) dist[[k]] <- NA
  dist$SD_stir   <- suppressWarnings(as.numeric(dist$SD_stir))
  dist$SD_mixeff <- suppressWarnings(as.numeric(dist$SD_mixeff))
  dist$SD_depth  <- suppressWarnings(as.numeric(dist$SD_depth))
  dist$SD_equip  <- as.character(dist$SD_equip)

  amend <- .safe_read(
    path,
    sheet = "Soil_Amendments",
    required_cols = NULL,
    skip = 3,
    verbose = verbose
  )

  if (is.null(amend) || !("SA_date" %in% names(amend)) ||
      all(is.na(.parse_shmi_date(amend$SA_date)))) {

    amend <- tibble::tibble(
      MGT_combo = character(),
      SA_date   = as.Date(character()),
      SA_cat    = character(),
      SA_N      = numeric()
    )

  } else {

    amend <- amend %>%
      dplyr::mutate(
        SA_date = as.Date(unname(.parse_shmi_date(SA_date)))
      ) %>%
      janitor::remove_empty("rows") %>%
      dplyr::filter(!(MGT_combo %in% exclude))
  }

  if (!"SA_date" %in% names(amend))  amend$SA_date  <- NA
  if (!"SA_N" %in% names(amend))     amend$SA_N     <- NA
  if (!"SA_units" %in% names(amend)) amend$SA_units <- NA_character_

  animal <- .safe_read(
    path,
    sheet = "Animal_Diversity",
    required_cols = NULL,
    skip = 3,
    verbose = verbose
  )

  if (is.null(animal) ||
      !all(c("AD_start_date", "AD_end_date") %in% names(animal)) ||
      (
        all(is.na(.parse_shmi_date(animal$AD_start_date))) &&
        all(is.na(.parse_shmi_date(animal$AD_end_date)))
      )) {

    animal <- tibble::tibble(
      MGT_combo     = character(),
      AD_start_date = as.Date(character()),
      AD_end_date   = as.Date(character()),
      AD_type       = character()
    )

  } else {

    animal <- animal %>%
      dplyr::mutate(
        AD_start_date = as.Date(unname(.parse_shmi_date(AD_start_date))),
        AD_end_date   = as.Date(unname(.parse_shmi_date(AD_end_date)))
      ) %>%
      janitor::remove_empty("rows") %>%
      dplyr::filter(!(MGT_combo %in% exclude))
  }

  # ------------------------------------------------------------
  # 3. Identify rotation-wide min/max years per MGT_combo
  # ------------------------------------------------------------
  cli::cli_progress_step("Calculating rotation lengths...")

  all_dates <- bind_rows(
    crop %>% select(MGT_combo, date = CD_plant_date),
    crop %>% select(MGT_combo, date = CD_harv_date),
    crop %>% select(MGT_combo, date = CD_term_date),
    dist %>% select(MGT_combo, date = SD_date),
    amend %>% select(MGT_combo, date = SA_date),
    animal %>% select(MGT_combo, date = AD_start_date),
    animal %>% select(MGT_combo, date = AD_end_date)
  ) %>%
    filter(!is.na(date))

  rot_bounds <- all_dates %>%
    mutate(yr = lubridate::year(date)) %>%
    group_by(MGT_combo) %>%
    summarize(
      rot_start_yr = min(yr),
      rot_end_yr   = max(yr),
      .groups = "drop"
    ) %>%
    mutate(
      rot_start = as.Date(paste0(rot_start_yr, "-01-01")),
      rot_end   = as.Date(paste0(rot_end_yr,   "-12-31"))
    )

  rot_bounds <- rot_bounds %>%
    mutate(
      year_range = rot_end_yr - rot_start_yr,
      is_outlier = year_range > max_rot_range
    )

  if (any(rot_bounds$is_outlier)) {
    bad <- rot_bounds %>% filter(is_outlier)
    cli::cli_abort(c(
      "Detected implausible rotation length.",
      "x" = paste0(
        "MGT_combo ", bad$MGT_combo,
        " spans ", bad$rot_start_yr, "-", bad$rot_end_yr,
        " (", bad$year_range, " years), exceeding max_rot_range = ", max_rot_range, "."
      ),
      "i" = "Check for typos in crop, disturbance, amendment, or animal dates."
    ))
  }

  # ------------------------------------------------------------
  # 4. Build species-episode crop windows
  #    One row per species per continuous period of presence. Mixtures,
  #    relays, and intercrops are overlapping episodes; CD_seq_num and
  #    CD_mix are not used. Every imputation is logged in `assumptions`.
  # ------------------------------------------------------------
  cli::cli_progress_step("Calculating crop start/end dates...")

  cw <- .build_crop_windows(crop, rot_bounds)
  crop_windows <- cw$windows
  assumptions  <- cw$assumptions

  # Intensive-tillage end for crops without a harvest or termination record
  tillage_method <- .tillage_method(dist, tillage_end)
  te <- .end_at_intensive_tillage(crop_windows, dist, tillage_method)
  crop_windows <- te$windows
  assumptions  <- dplyr::bind_rows(assumptions, te$assumptions)

  # ------------------------------------------------------------
  # 7. Apply date overrides
  # ------------------------------------------------------------
  cli::cli_progress_step("Applying overrides...")

  if (!is.null(start_date_override) || !is.null(end_date_override)) {

    if (!is.null(start_date_override)) {
      crop_windows <- crop_windows %>%
        filter(crop_end >= as.Date(start_date_override)) %>%
        mutate(crop_start = pmax(crop_start, as.Date(start_date_override)))

      dist <- dist %>%
        filter(SD_date >= as.Date(start_date_override))

      amend <- amend %>%
        filter(SA_date >= as.Date(start_date_override))

      # periods without an end date are treated as single-day events
      animal <- animal %>%
        filter(dplyr::coalesce(AD_end_date, AD_start_date) >= as.Date(start_date_override)) %>%
        mutate(AD_start_date = pmax(AD_start_date, as.Date(start_date_override)))
    }

    if (!is.null(end_date_override)) {
      crop_windows <- crop_windows %>%
        filter(crop_start <= as.Date(end_date_override)) %>%
        mutate(crop_end = pmin(crop_end, as.Date(end_date_override)))

      dist <- dist %>%
        filter(SD_date <= as.Date(end_date_override))

      amend <- amend %>%
        filter(SA_date <= as.Date(end_date_override))

      animal <- animal %>%
        filter(AD_start_date <= as.Date(end_date_override)) %>%
        mutate(AD_end_date = dplyr::if_else(is.na(AD_end_date), AD_end_date,
                                            pmin(AD_end_date, as.Date(end_date_override))))
    }
  }

  # ------------------------------------------------------------
  # 8. Apply sample date override
  # ------------------------------------------------------------

  if (end_at_sample_date) {

    keep_by <- function(date, cut) is.na(cut) | (!is.na(date) & date <= cut)
    cut_at  <- function(date, cut) dplyr::if_else(is.na(cut) | is.na(date), date, pmin(date, cut))

    crop_windows <- crop_windows %>%
      left_join(mgt_dates, by = "MGT_combo") %>%
      filter(keep_by(crop_start, MGT_sample_date)) %>%
      mutate(crop_end = cut_at(crop_end, MGT_sample_date)) %>%
      select(-MGT_sample_date)

    dist <- dist %>%
      left_join(mgt_dates, by = "MGT_combo") %>%
      filter(keep_by(SD_date, MGT_sample_date)) %>%
      select(-MGT_sample_date)

    amend <- amend %>%
      left_join(mgt_dates, by = "MGT_combo") %>%
      filter(keep_by(SA_date, MGT_sample_date)) %>%
      select(-MGT_sample_date)

    animal <- animal %>%
      left_join(mgt_dates, by = "MGT_combo") %>%
      filter(keep_by(AD_start_date, MGT_sample_date)) %>%
      mutate(AD_end_date = cut_at(AD_end_date, MGT_sample_date)) %>%
      select(-MGT_sample_date)
  }

  cli::cli_progress_step("Re-calculating rotation lengths...")

  all_dates <- bind_rows(
    crop_windows %>% select(MGT_combo, date = crop_start),
    crop_windows %>% select(MGT_combo, date = crop_end),
    dist %>% select(MGT_combo, date = SD_date),
    amend %>% select(MGT_combo, date = SA_date),
    animal %>% select(MGT_combo, date = AD_start_date),
    animal %>% select(MGT_combo, date = AD_end_date)
  ) %>%
    filter(!is.na(date))

  event_span <- all_dates %>%
    group_by(MGT_combo) %>%
    summarize(first_event = min(date), last_event = max(date), .groups = "drop")

  if (rotation_window == "events") {
    # SHMI <= 1.1.0: window = first to last recorded event
    rot_bounds <- event_span %>%
      dplyr::transmute(MGT_combo, rot_start = first_event, rot_end = last_event)
  } else {
    # calendar-year window, or exactly the override / sample dates
    rot_bounds <- event_span %>%
      mutate(
        rot_start = if (!is.null(start_date_override)) start_date_override else
          as.Date(paste0(lubridate::year(first_event), "-01-01")),
        rot_end   = if (!is.null(end_date_override)) end_date_override else
          as.Date(paste0(lubridate::year(last_event), "-12-31"))
      )
    if (end_at_sample_date) {
      rot_bounds <- rot_bounds %>%
        left_join(mgt_dates, by = "MGT_combo") %>%
        mutate(rot_end = dplyr::if_else(is.na(MGT_sample_date), rot_end,
                                        pmin(rot_end, MGT_sample_date))) %>%
        select(-MGT_sample_date)
    }
    rot_bounds <- rot_bounds %>% select(MGT_combo, rot_start, rot_end)
  }

  rot_bounds <- rot_bounds %>%
    mutate(
      rot_start_yr = lubridate::year(rot_start),
      rot_end_yr   = lubridate::year(rot_end)
    )

  # Every episode must lie inside its unit's window (guaranteed by the
  # construction above; checked so later changes cannot break it silently)
  outside <- crop_windows %>%
    dplyr::inner_join(rot_bounds, by = "MGT_combo") %>%
    dplyr::filter(crop_start < rot_start | crop_end > rot_end)
  if (nrow(outside) > 0) {
    cli::cli_abort(c(
      "Internal error: {nrow(outside)} crop episode{?s} extend{?s/} beyond the rotation window.",
      "i" = "First affected: {.val {utils::head(unique(outside$MGT_combo), 5)}}"
    ))
  }

  mgt_combos <- unique(rot_bounds$MGT_combo)
  mgt <- mgt %>%
    filter(MGT_combo %in% mgt_combos)

  # ------------------------------------------------------------
  # Data checks on the final windows (change no scores):
  #   crops still running to the window end despite lighter tillage,
  #   annual crops with an imputed planting date (candidate dates listed),
  #   units with management records but no crops
  # ------------------------------------------------------------
  assumptions <- dplyr::bind_rows(
    assumptions,
    .check_light_tillage_end(crop_windows, dist, rot_bounds),
    .check_imputed_start(crop_windows, dist),
    .check_no_crops(rot_bounds, crop_windows)
  )

  # ------------------------------------------------------------
  # 6. Yield / N-rate
  # ------------------------------------------------------------
  if (calc_yield) {
    cli::cli_progress_step("Computing crop yields...")
    yield_out   <- .prepare_yield(crop, rot_bounds)
    yield       <- yield_out$yield
    assumptions <- dplyr::bind_rows(assumptions, yield_out$assumptions)
  } else {
    yield <- NULL
  }

  if (calc_n_rate) {
    cli::cli_progress_step("Computing N rates...")
    n_out       <- .prepare_n_rate(amend)
    n_rate      <- n_out$n_rate
    assumptions <- dplyr::bind_rows(assumptions, n_out$assumptions)
  } else {
    n_rate <- NULL
  }

  # Keep assumptions only for units that remain after overrides/exclusions
  assumptions <- assumptions %>%
    dplyr::filter(MGT_combo %in% mgt_combos)

  cli::cli_progress_done()
  cli::cli_progress_cleanup()

  if (verbose && nrow(assumptions) > 0) {
    n_chk <- sum(assumptions$level == "check")
    message(
      "\n", nrow(assumptions), " assumptions/checks recorded in ",
      "`$assumptions` (", n_chk, " flagged for review). ",
      "See table($assumptions$type)."
    )
  }

  # ------------------------------------------------------------
  # 7. Return updated inputs list
  # ------------------------------------------------------------
  inputs <- list(
    rot_bounds = rot_bounds,
    mgt        = mgt,
    crop       = crop_windows,
    harvests   = harvests,
    dist       = dist,
    amend      = amend,
    animal     = animal,
    yield       = yield,
    n_rate      = n_rate,
    assumptions = assumptions
  )
  attr(inputs, "rotation_window") <- rotation_window
  attr(inputs, "tillage_end")     <- tillage_method

  return(inputs)
}


# TRUE where an irrigation entry names a method (not blank, "None" or "No")
.is_irrigated <- function(x) {
  x <- tolower(trimws(as.character(x)))
  !is.na(x) & !(x %in% c("", "none", "no", "na", "n/a", "false", "0", "rainfed", "rain-fed", "dryland"))
}
