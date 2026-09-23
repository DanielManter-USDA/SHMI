#' Prepare and Validate SHMI Input Data from an Excel Workbook
#'
#' Reads, validates, harmonizes, and expands all input sheets required to
#' compute the Soil Health Management Index (SHMI). This function is the
#' official entry point for SHMI data preparation and produces a standardized
#' list of rotation‑scale objects used directly by \code{build_shmi()}.
#'
#' ## Overview
#'
#' The function performs:
#' \itemize{
#'   \item robust Excel ingestion with sheet‑level validation
#'   \item management‑unit filtering
#'   \item biological validation of crop chronology (annual/perennial rules)
#'   \item mixture‑aware harmonization of crop windows
#'   \item construction of rotation bounds (start/end dates and rotation years)
#'   \item assembly of disturbance, amendment, and animal event tables
#'   \item optional extraction of yield and nitrogen‑rate data
#'   \item override‑aware clipping of all event types
#' }
#'
#' The result is a clean, rotation‑scale dataset suitable for SHMI pillar
#' computation: cover, diversity, inverse disturbance, and organic inputs.
#'
#'
#' ## Required workbook structure
#'
#' The Excel file must contain the standard SHMI sheets:
#'
#' \itemize{
#'   \item \code{Mgt_Unit}
#'   \item \code{Crop_Diversity}
#'   \item \code{Soil_Disturbance}
#'   \item \code{Amendment_Diversity}
#'   \item \code{Animal_Diversity}
#' }
#'
#' Sheets may be empty; empty sheets are safely ignored.
#'
#'
#' ## Date overrides
#'
#' If \code{start_date_override} or \code{end_date_override} are supplied,
#' all event types (crop, disturbance, amendment, animal, yield, N‑rate)
#' occurring outside the override window are removed, and rotation bounds are
#' clipped accordingly.
#'
#'
#' ## Crop harmonization
#'
#' Crop windows are validated for biological realism:
#'
#' \itemize{
#'   \item annual crops must terminate within the same year
#'   \item perennials may span years but must follow valid chronology
#'   \item mixtures are collapsed to event‑level windows (min start, max end)
#' }
#'
#' The returned \code{crop} table contains one row per species with harmonized
#' start/end dates suitable for cover and diversity scoring.
#'
#'
#' ## Disturbance, amendments, and animals
#'
#' Disturbance events are returned in EPA/STIR‑ready format:
#'
#' \itemize{
#'   \item \code{SD_date}
#'   \item \code{SD_mixeff}
#'   \item \code{SD_depth}
#' }
#'
#' Amendment and animal events are clipped by overrides and returned in
#' rotation‑scale format for \code{compute_orginput()}.
#'
#'
#' ## Optional yield and nitrogen‑rate extraction
#'
#' If enabled:
#'
#' \itemize{
#'   \item Yield is extracted per crop event, unit‑standardized to kg/ha,
#'         and clipped by overrides.
#'   \item Nitrogen rate is extracted from amendment events, converted to
#'         kg N/ha, summarized per \code{MGT_combo × year}, and clipped by
#'         overrides.
#' }
#'
#' Missing values are retained as \code{NA}.
#'
#'
#' ## Front‑end validation
#'
#' The function automatically runs \code{validate_excel_input()} to check:
#'
#' \itemize{
#'   \item required sheets and columns
#'   \item valid date formats
#'   \item consistent \code{MGT_combo} values
#'   \item malformed entries
#' }
#'
#' If validation fails, execution stops with clear, actionable error messages.
#'
#'
#' @param path Path to the SHMI Excel workbook.
#'
#' @param exclude Optional character vector of \code{MGT_combo} identifiers to
#'   exclude from processing.
#'
#' @param verbose Logical; if \code{TRUE}, prints progress messages.
#'
#' @param start_date_override Optional \code{Date} or date‑coercible value.
#'
#' @param end_date_override Optional \code{Date} or date‑coercible value.
#'
#' @param calc_yield Logical; if \code{TRUE}, extract and standardize yield.
#'
#' @param calc_n_rate Logical; if \code{TRUE}, extract and standardize N‑rate.
#'
#'
#' @return A named list containing:
#' \describe{
#'   \item{\code{rot_bounds}}{Rotation start/end dates and rotation years.}
#'   \item{\code{crop}}{Mixture‑aware crop windows (one row per species).}
#'   \item{\code{dist}}{Disturbance event table (EPA/STIR‑ready).}
#'   \item{\code{amend}}{Amendment event table.}
#'   \item{\code{animal}}{Animal event table.}
#'   \item{\code{mgt}}{Management‑unit metadata.}
#'   \item{\code{yield}}{Optional crop‑event‑level yield table (kg/ha).}
#'   \item{\code{n_rate}}{Optional year‑level nitrogen‑rate table (kg N/ha).}
#' }
#'
#' @section Error Handling:
#' The function stops with informative errors if:
#' \itemize{
#'   \item required sheets or columns are missing
#'   \item crop chronology is biologically impossible
#'   \item date overrides produce empty rotations
#' }
#'
#' @seealso
#'   \code{\link{build_shmi}} for computing SHMI scores from prepared inputs.
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
                                calc_n_rate = FALSE) {

  # ------------------------------------------------------------
  # 1. Validate inputs
  # ------------------------------------------------------------
  cli::cli_progress_step("Validating inputs...")

  val <- validate_excel_input(path, verbose)

  if (!val$ok) {
    message("❌ Excel input validation failed.\n")
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
    mgt_dates <- mgt %>%
      select(MGT_combo, MGT_sample_date) %>%
      mutate(MGT_sample_date = as.Date(MGT_sample_date))
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

  crop <- crop %>%
    dplyr::mutate(
      CD_plant_date = as.Date(unname(.parse_shmi_date(CD_plant_date))),
      CD_harv_date  = as.Date(unname(.parse_shmi_date(CD_harv_date))),
      CD_term_date  = as.Date(unname(.parse_shmi_date(CD_term_date)))
    )

  dist <- .safe_read(
    path,
    sheet = "Soil_Disturbance",
    required_cols = c("MGT_combo", "SD_date", "SD_mixeff"),
    skip = 3,
    verbose = verbose
  ) %>%
    janitor::remove_empty("rows") %>%
    dplyr::filter(!(MGT_combo %in% exclude)) %>%
    dplyr::mutate(SD_date = as.Date(unname(.parse_shmi_date(SD_date))))

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
    rowwise() %>%
    mutate(
      year_range = rot_end_yr - rot_start_yr,
      is_outlier = year_range > max_rot_range
    ) %>%
    ungroup()

  if (any(rot_bounds$is_outlier)) {
    bad <- rot_bounds %>% filter(is_outlier)
    cli::cli_abort(c(
      "Detected implausible rotation length.",
      "x" = paste0(
        "MGT_combo ", bad$MGT_combo,
        " spans ", bad$rot_start_yr, "–", bad$rot_end_yr,
        " (", bad$year_range, " years), exceeding max_rot_range = ", max_rot_range, "."
      ),
      "i" = "Check for typos in crop, disturbance, amendment, or animal dates."
    ))
  }

  # ------------------------------------------------------------
  # 4. Infer next planting (for crop_end logic)
  # ------------------------------------------------------------
  safe_min_date <- function(x) {
    x2 <- x[!is.na(x)]
    if (length(x2) == 0) return(as.Date(NA))
    as.Date(min(x2))
  }

  safe_max_date <- function(x) {
    if (all(is.na(x))) return(NA_Date_)
    as.Date(max(x, na.rm = TRUE))
  }

  # get one row for each crop species
  crop <- crop %>%
    group_by(MGT_combo, CD_seq_num, CD_cat, CD_name) %>%
    summarize(
      CD_plant_date  = safe_min_date(CD_plant_date),
      CD_harv_date   = safe_max_date(CD_harv_date),
      CD_term_date   = safe_max_date(CD_term_date),
      CD_yield       = mean(CD_yield, na.rm = TRUE),
      CD_yield_units = first(CD_yield_units),
      .groups = "drop"
    ) %>%
    mutate(
      # annual vs perennial end
      raw_crop_end = case_when(
        CD_cat %in% c("annual", "Annual", "cash", "Cash") ~
          coalesce(CD_term_date, CD_harv_date),

        CD_cat %in% c("perennial", "Perennial", "woody perennial") ~
          coalesce(CD_term_date, CD_harv_date, CD_plant_date),

        TRUE ~
          coalesce(CD_term_date, CD_harv_date, CD_plant_date)
      )
    )

  # infer CD_seq_num
  crop <- crop %>%
    arrange(MGT_combo, CD_plant_date) %>%   # chronological order
    group_by(MGT_combo) %>%
    mutate(
      # If plant date is missing, use raw_crop_end as a proxy start
      crop_start_eff = coalesce(CD_plant_date, raw_crop_end),

      # Biological overlap: crop starts before previous crop ends
      overlaps_prev = crop_start_eff <= lag(raw_crop_end),

      # A new sequence begins only when there is NO overlap
      seq_break = case_when(
        row_number() == 1 ~ TRUE,          # first crop always starts seq 1
        overlaps_prev      ~ FALSE,         # overlap → same sequence
        TRUE               ~ TRUE           # no overlap → new sequence
      ),

      # Assign sequence numbers
      CD_seq_num = cumsum(seq_break)
    ) %>%
    ungroup() %>%
    select(-crop_start_eff, -overlaps_prev, -seq_break)

  seq_dates <- crop %>%
    group_by(MGT_combo, CD_seq_num) %>%
    summarize(
      seq_plant = safe_min_date(CD_plant_date),
      .groups = "drop"
    ) %>%
    arrange(MGT_combo, CD_seq_num) %>%
    group_by(MGT_combo) %>%
    mutate(next_seq_start = lead(seq_plant)) %>%
    ungroup()

  crop <- crop %>%
    left_join(seq_dates, by = c("MGT_combo", "CD_seq_num")) %>%
    mutate(
      crop_end = case_when(
        CD_cat == "Perennial" ~ next_seq_start,
        TRUE ~ raw_crop_end
      )
    )

  seq_info <- crop %>%
    group_by(MGT_combo, CD_seq_num) %>%
    summarize(
      seq_any_plant = any(!is.na(CD_plant_date)),
      seq_min_plant = safe_min_date(CD_plant_date),
      seq_max_harv  = safe_max_date(CD_harv_date),
      seq_max_term  = safe_max_date(CD_term_date),
      .groups = "drop"
    ) %>%
    arrange(MGT_combo, CD_seq_num) %>%
    group_by(MGT_combo) %>%
    mutate(
      prev_seq_end = lag(pmax(seq_max_harv, seq_max_term, na.rm = TRUE))
    ) %>%
    ungroup()

  # ------------------------------------------------------------
  # 5. Category harmonization (Annual / Perennial)
  # ------------------------------------------------------------
  crop <- crop %>%
    left_join(seq_info,  by = c("MGT_combo", "CD_seq_num")) %>%
    dplyr::mutate(
      CD_cat = dplyr::case_when(
        CD_cat %in% c("annual", "cash", "cover", "fallow", "Cash", "Cover", "Fallow") ~ "Annual",
        CD_cat %in% c("perennial", "woody perennial") ~ "Perennial",
        TRUE ~ CD_cat
      )
    )

  # ------------------------------------------------------------
  # 6. Infer crop_start and crop_end
  # ------------------------------------------------------------
  cli::cli_progress_step("Calculating crop start/end dates...")

  crop_windows <- crop %>%
    left_join(rot_bounds, by = "MGT_combo") %>%
    group_by(MGT_combo, CD_seq_num, CD_cat, CD_name) %>%
    mutate(
      # crop-level planted-into-previous
      crop_planted_into_prev = (
        !is.na(CD_plant_date) &
          !is.na(prev_seq_end) &
          CD_plant_date < prev_seq_end
      ),

      crop_start = case_when(
        CD_seq_num == min(CD_seq_num) & !is.na(CD_plant_date) ~ CD_plant_date,
        CD_seq_num == min(CD_seq_num) ~ rot_start,
        !is.na(CD_plant_date) ~ CD_plant_date,
        TRUE ~ coalesce(prev_seq_end, rot_start)
      ),

      max_harv_name = CD_harv_date,
      max_term_name = CD_term_date,

      annual_end = coalesce(
        max_term_name,
        max_harv_name,
        if_else(crop_planted_into_prev, NA_Date_, next_seq_start),
        as.Date(rot_end)
      ),

      perennial_end = coalesce(
        max_term_name,
        if_else(crop_planted_into_prev, NA_Date_, next_seq_start),
        as.Date(rot_end)
      ),

      crop_end = case_when(
        CD_cat == "Annual"    ~ annual_end,
        CD_cat == "Perennial" ~ perennial_end,
        TRUE                  ~ perennial_end
      ),

      crop_end = if_else(crop_end < crop_start, crop_start, crop_end)
    ) %>%
    ungroup() %>%
    select(MGT_combo, CD_seq_num, CD_cat, CD_name,
           crop_start, crop_end, CD_yield, CD_yield_units)

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

      animal <- animal %>%
        filter(AD_end_date >= as.Date(start_date_override)) %>%
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
        mutate(AD_end_date = pmin(AD_end_date, as.Date(end_date_override)))
    }
  }

  # ------------------------------------------------------------
  # 8. Apply sample date override
  # ------------------------------------------------------------

  if (end_at_sample_date) {

    # Crop windows
    crop_windows <- crop_windows %>%
      left_join(mgt_dates, by = "MGT_combo") %>%
      filter(crop_start <= MGT_sample_date) %>%
      mutate(
        crop_end = pmin(crop_end, MGT_sample_date)
      )

    # Disturbance
    dist <- dist %>%
      left_join(mgt_dates, by = "MGT_combo") %>%
      filter(SD_date <= MGT_sample_date)

    # Amendments
    amend <- amend %>%
      left_join(mgt_dates, by = "MGT_combo") %>%
      filter(SA_date <= MGT_sample_date)

    # Animal
    animal <- animal %>%
      left_join(mgt_dates, by = "MGT_combo") %>%
      filter(AD_start_date <= MGT_sample_date) %>%
      mutate(
        AD_end_date = pmin(AD_end_date, MGT_sample_date)
      )
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

  rot_bounds <- all_dates %>%
    group_by(MGT_combo) %>%
    summarize(
      rot_start = min(date),
      rot_end   = max(date),
      .groups = "drop"
    ) %>%
    mutate(
      rot_start_yr = lubridate::year(rot_start),
      rot_end_yr   = lubridate::year(rot_end)
    )

  mgt_combos <- unique(rot_bounds$MGT_combo)
  mgt <- mgt %>%
    filter(MGT_combo %in% mgt_combos)

  # ------------------------------------------------------------
  # 6. Yield / N-rate
  # ------------------------------------------------------------
  if (calc_yield) {
    cli::cli_progress_step("Computing crop yields...")
    yield <- .prepare_yield(crop_windows)
  } else {
    yield <- NULL
  }

  if (calc_n_rate) {
    cli::cli_progress_step("Computing N rates...")
    n_rate <- .prepare_n_rate(amend)
  } else {
    n_rate <- NULL
  }

  cli::cli_progress_done()
  cli::cli_progress_cleanup()

  # ------------------------------------------------------------
  # 7. Return updated inputs list
  # ------------------------------------------------------------
  inputs <- list(
    rot_bounds = rot_bounds,
    mgt        = mgt,
    crop       = crop_windows %>% select(-CD_yield, -CD_yield_units),
    dist       = dist,
    amend      = amend,
    animal     = animal,
    yield      = yield,
    n_rate     = n_rate
  )

  return(inputs)
}
