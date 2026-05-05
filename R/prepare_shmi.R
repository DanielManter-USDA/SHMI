#' Prepare and Validate SHMI Input Data from an Excel Workbook
#'
#' Reads, validates, harmonizes, and expands all input sheets required to
#' compute the Soil Health Management Index (SHMI). This function is the
#' official entry point for SHMI data preparation and produces a standardized
#' list of objects used directly by \code{build_shmi()}.
#'
#' The function performs:
#' \itemize{
#'   \item robust Excel ingestion with sheet‑level validation
#'   \item management‑unit filtering
#'   \item crop‑level biological validation (chronology, annual/perennial rules)
#'   \item harmonization of crop windows across mixtures
#'   \item construction of rotation bounds (full‑year expansion)
#'   \item daily grid expansion (fast vectorized implementation)
#'   \item mechanistic daily disturbance processing (mixing efficiency × depth)
#'   \item assembly of amendment and animal event tables
#'   \item optional extraction of yield and nitrogen‑rate data
#' }
#'
#' @param path Path to the SHMI Excel workbook. Must contain the standard SHMI
#'   sheets: \code{Mgt_Unit}, \code{Crop_Diversity}, \code{Soil_Disturbance},
#'   \code{Amendment_Diversity}, and \code{Animal_Diversity}. Sheets may be
#'   empty; empty sheets are safely ignored.
#'
#' @param exclude Optional character vector of \code{MGT_combo} identifiers to
#'   exclude from processing. Default is \code{NULL}.
#'
#' @param verbose Logical; if \code{TRUE} (default), prints progress messages
#'   describing sheet ingestion, validation steps, and grid construction.
#'
#' @param start_date_override Optional \code{Date} or date‑coercible value.
#'   If supplied, all crop, disturbance, amendment, animal, yield, and N‑rate
#'   events occurring before this date are removed, and rotation bounds are
#'   clipped accordingly.
#'
#' @param end_date_override Optional \code{Date} or date‑coercible value.
#'   If supplied, all events occurring after this date are removed, and rotation
#'   bounds are clipped accordingly.
#'
#' @param calc_yield Logical, default = FALSE.
#'   If \code{TRUE}, yield (kg/ha) is extracted from \code{Crop_Diversity},
#'   clipped by date overrides, unit‑standardized, and returned for each
#'   \code{MGT_combo × crop event}. If \code{FALSE}, yield is not processed and
#'   the returned list contains \code{yield = NULL}.
#'
#' @param calc_n_rate Logical, default = FALSE.
#'   If \code{TRUE}, nitrogen rate (kg N/ha) is extracted from
#'   \code{Amendment_Diversity}, clipped by date overrides, unit‑standardized,
#'   and summarized for each \code{MGT_combo × year}. If \code{FALSE}, N‑rate is
#'   not processed and the returned list contains \code{n_rate = NULL}.
#'
#' @details
#' The function enforces biologically realistic crop windows, including:
#' \itemize{
#'   \item annual crops must terminate within the same year
#'   \item perennials may span years but must follow valid chronology
#'   \item mixtures are collapsed to event‑level windows
#' }
#'
#' Rotation bounds are computed from all available event types (crop,
#' disturbance, amendment, animal) and expanded to full calendar years to ensure
#' consistent SHMI computation. Date overrides further restrict all event types,
#' including optional yield and N‑rate extraction.
#'
#' Daily grids are generated using a fully vectorized expansion, ensuring
#' extremely fast performance even for large datasets.
#'
#' Yield extraction (if enabled) preserves one row per crop event, applies
#' override‑aware clipping, and converts all supported units to kg/ha. Missing
#' yield or missing units are retained as \code{NA}.
#'
#' Nitrogen‑rate extraction (if enabled) uses the \code{SA_N} field as the
#' authoritative N applied, converts units to kg N/ha, clips by overrides, and
#' returns one row per \code{MGT_combo × year}. Missing \code{SA_N} values are
#' retained as \code{NA}.
#'
#' Additionally, this function automatically performs front‑end validation of
#' the Excel input file using \code{validate_excel_input()}. The validator checks
#' for required sheets, required columns, valid date formats, consistent
#' \code{MGT_combo} values, and malformed entries before any ingestion or
#' harmonization occurs.
#'
#' If validation fails, execution stops immediately with clear, actionable error
#' messages. Users must correct the Excel file before re‑running
#' \code{prepare_shmi_inputs()}.
#'
#' @return A named list containing:
#' \describe{
#'   \item{\code{rot_bounds}}{Rotation start/end dates for each \code{MGT_combo}.}
#'   \item{\code{crop_harmonized}}{One row per crop event with harmonized
#'         start/end dates.}
#'   \item{\code{daily}}{Daily crop‑presence grid (one row per day).}
#'   \item{\code{daily_dist}}{Daily disturbance table with mixing efficiency and
#'         depth (cm).}
#'   \item{\code{mgt}}{Management‑unit metadata.}
#'   \item{\code{crop}}{Validated crop event table.}
#'   \item{\code{dist}}{Disturbance event table.}
#'   \item{\code{amend}}{Amendment event table.}
#'   \item{\code{animal}}{Animal event table.}
#'   \item{\code{yield}}{(Optional) Crop‑event‑level yield table (kg/ha), or
#'         \code{NULL} if \code{calc_yield = FALSE}.}
#'   \item{\code{n_rate}}{(Optional) Year‑level nitrogen‑rate table (kg N/ha),
#'         or \code{NULL} if \code{calc_n_rate = FALSE}.}
#' }
#'
#' @section Error Handling:
#' The function stops with informative errors if:
#' \itemize{
#'   \item required sheets are missing
#'   \item required columns are missing
#'   \item crop chronology is biologically impossible
#'   \item date overrides produce empty rotations
#' }
#'
#' @seealso
#'   \code{\link{build_shmi}} for computing SHMI scores and optional rotation‑level
#'   summaries of yield and nitrogen rate.
#'
#' @export
prepare_shmi_inputs <- function(path,
                                exclude = NULL,
                                verbose = TRUE,
                                start_date_override = NULL,
                                end_date_override   = NULL,
                                calc_yield  = FALSE,
                                calc_n_rate = FALSE) {

  # ------------------------------------------------------------
  # 1. Validating inputs
  # ------------------------------------------------------------
  cli::cli_progress_step("Validating inputs...")

  # Validate Excel file before ingestion
  val <- validate_excel_input(path)

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
  # 2. Helper to read + filter sheets
  # ------------------------------------------------------------
  safe_select <- function(df, cols) {
    cols <- intersect(cols, names(df))
    dplyr::select(df, all_of(cols))
  }

  # ------------------------------------------------------------
  # 3. Load MGT first (needed for joins)
  # ------------------------------------------------------------
  cli::cli_progress_step("Reading Excel file...")

  mgt <- .safe_read(
    path,
    required_cols = c("MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt"),
    "Mgt_Unit",
    skip = 3,
  ) %>%
    select(user_name, MGT_combo, MGT_study, MGT_farm, MGT_field, MGT_trt) %>%
    janitor::remove_empty("rows") %>%
    filter(!(MGT_combo %in% exclude))

  # ------------------------------------------------------------
  # 4. Load all sheets
  # ------------------------------------------------------------
  #   ---- Load Crop_Diversity ----
  crop <- .safe_read(
    path,
    "Crop_Diversity",
    required_cols = c("MGT_combo", "CD_seq_num", "CD_plant_date", "CD_term_date"),
    skip = 3
  )

  if (!"CD_harv_date" %in% names(crop)) crop$CD_harv_date <- NA
  if (!"CD_cat" %in% names(crop))       crop$CD_cat       <- NA_character_

  crop <- crop %>%
    mutate(
      CD_plant_date = as.Date(unname(.parse_shmi_date(CD_plant_date))),
      CD_harv_date  = as.Date(unname(.parse_shmi_date(CD_harv_date))),
      CD_term_date  = as.Date(unname(.parse_shmi_date(CD_term_date)))
    )

  #   ---- Load Soil_Disturbance ----
  dist <- .safe_read(
    path,
    "Soil_Disturbance",
    required_cols = c("MGT_combo", "SD_date", "SD_mixeff"),
    skip = 3
  )

  dist <- dist %>%
    mutate(SD_date = as.Date(unname(.parse_shmi_date(SD_date))))

  #   ---- Apply year overrides BEFORE inference ----
  if (!is.null(start_date_override)) {
    S <- as.Date(start_date_override)
    crop <- crop %>% filter(is.na(CD_term_date) | CD_term_date >= S) %>%
      mutate(CD_plant_date = if_else(CD_plant_date < S, S, CD_plant_date))
    dist <- dist %>% filter(SD_date >= S)
  }

  if (!is.null(end_date_override)) {
    E <- as.Date(end_date_override)
    crop <- crop %>% filter(CD_plant_date <= E) %>%
      mutate(CD_term_date = if_else(!is.na(CD_term_date) & CD_term_date > E, E, CD_term_date))
    dist <- dist %>% filter(SD_date <= E)
  }

  #   ---- INFER TERMINATION DATES (planting + disturbance) ----
  # 1. Next planting date
  seq_dates <- crop %>%
    group_by(MGT_combo, CD_seq_num) %>%
    summarize(
      seq_plant = min(CD_plant_date, na.rm = TRUE),
      .groups   = "drop"
    ) %>%
    arrange(MGT_combo, CD_seq_num) %>%
    group_by(MGT_combo) %>%
    mutate(next_seq_plant = dplyr::lead(seq_plant)) %>%
    ungroup()

  crop <- crop %>%
    left_join(seq_dates, by = c("MGT_combo", "CD_seq_num")) %>%
    mutate(next_plant = next_seq_plant)

  # 2. Next disturbance date
  dist2 <- dist %>%
    arrange(MGT_combo, SD_date) %>%
    group_by(MGT_combo) %>%
    mutate(next_dist = lead(SD_date)) %>%
    ungroup()

  # Join disturbance info to crops
  safe_min_after <- function(x, threshold) {
    vals <- x[x > threshold]
    if (length(vals) == 0) return(as.Date(NA))  # NA_Date_
    as.Date(min(vals))                          # ensure Date class
  }

  crop <- crop %>%
    left_join(dist2, by = "MGT_combo") %>%
    group_by(MGT_combo, CD_seq_num, CD_name) %>%
    summarize(
      CD_plant_date = {
        min(CD_plant_date, na.rm = TRUE)
      },

      CD_harv_date = {
        if (all(is.na(CD_harv_date))) {
          NA_Date_
        } else {
          min(CD_harv_date, na.rm = TRUE)
        }
      },

      CD_term_date = {
        if (all(is.na(CD_term_date))) {
          NA_Date_
        } else {
          min(CD_term_date, na.rm = TRUE)
        }
      },

      next_plant = {
        if (all(is.na(next_plant))) {
          NA_Date_
        } else {
          min(next_plant, na.rm = TRUE)
        }
      },

      next_dist_after = {
        plant_date_for_group <- min(CD_plant_date, na.rm = TRUE)
        safe_min_after(SD_date, plant_date_for_group)
      },

      .groups = "drop"
    )

  # For each crop, find the earliest disturbance AFTER planting
  crop$inferred_end <- pmin(
    crop$next_plant - 1,
    crop$next_dist_after - 1,
    na.rm = TRUE
  )

  # 4. Final crop_end hierarchy
  crop$crop_end <- dplyr::coalesce(
    crop$CD_term_date,
    crop$CD_harv_date,
    crop$inferred_end
  )

  # ---- Load Soil_Amendments ----
  amend <- .safe_read(
    path,
    "Soil_Amendments",
    required_cols = c("MGT_combo", "SA_date"),
    skip = 3
  )
  amend <- amend %>%
    mutate(
      SA_date = as.Date(unname(.parse_shmi_date(SA_date)))
    )

  if (!is.null(start_date_override)) {
    amend <- amend %>%
      filter(SA_date >= S)
  }

  if (!is.null(end_date_override)) {
    amend <- amend %>% filter(SA_date <= E)
  }

  # ---- Load Animal_Diversity ----
  animal <- .safe_read(
    path,
    "Animal_Diversity",
    required_cols = c("MGT_combo", "AD_start_date", "AD_end_date"),
    skip = 3
  )

  animal <- animal %>%
    mutate(
      AD_start_date = as.Date(unname(.parse_shmi_date(AD_start_date))),
      AD_end_date   = as.Date(unname(.parse_shmi_date(AD_end_date)))
    )

  if (!is.null(start_date_override)) {
    S <- as.Date(start_date_override)

    animal <- animal %>%
      # 1. Drop windows that end before S
      filter(AD_end_date >= S) %>%
      # 2. Clip windows that overlap S
      mutate(
        AD_start_date = if_else(AD_start_date < S, S, AD_start_date)
      )
  }

  if (!is.null(end_date_override)) {
    E <- as.Date(end_date_override)

    animal <- animal %>%
      # 1. Drop windows that start after E
      filter(AD_start_date <= E) %>%
      # 2. Clip windows that overlap E
      mutate(
        AD_end_date = if_else(AD_end_date > E, E, AD_end_date)
      )
  }

  # ------------------------------------------------------------
  # 5. Harmonize crop windows
  # ------------------------------------------------------------
  cli::cli_progress_step("Evaluating crop windows...")

  harmonize_crop_windows <- function(crop) {

    crop %>%
      mutate(
        CD_plant_date = as.Date(CD_plant_date),
        crop_end      = as.Date(crop_end)
      ) %>%
      group_by(MGT_combo) %>%
      # rotation-level bounds
      mutate(
        start_yr = min(lubridate::year(CD_plant_date), na.rm = TRUE),
        end_yr   = max(lubridate::year(crop_end),      na.rm = TRUE),
        min_seq  = min(CD_seq_num, na.rm = TRUE),
        max_seq  = max(CD_seq_num, na.rm = TRUE)
      ) %>%
      ungroup() %>%
      group_by(MGT_combo, CD_seq_num, CD_name) %>%
      summarize(
        # raw windows for this species × seq
        start_raw = suppressWarnings(min(CD_plant_date, na.rm = TRUE)),
        end_raw   = suppressWarnings(max(crop_end,      na.rm = TRUE)),
        start_yr  = first(start_yr),
        end_yr    = first(end_yr),
        min_seq   = first(min_seq),
        max_seq   = first(max_seq),
        .groups   = "drop"
      ) %>%
      mutate(
        # handle Inf → NA
        start_raw = dplyr::if_else(is.infinite(start_raw), as.Date(NA), start_raw),
        end_raw   = dplyr::if_else(is.infinite(end_raw),   as.Date(NA), end_raw),

        is_first = CD_seq_num == min_seq,
        is_last  = CD_seq_num == max_seq,

        crop_start = dplyr::if_else(
          is_first & is.na(start_raw),
          as.Date(paste0(start_yr, "-01-01")),
          start_raw
        ),

        crop_end = dplyr::if_else(
          is_last & is.na(end_raw),
          as.Date(paste0(end_yr, "-12-31")),
          end_raw
        )
      ) %>%
      select(MGT_combo, CD_seq_num, CD_name, crop_start, crop_end)
  }

  crop_harmonized <- harmonize_crop_windows(crop)

  # ------------------------------------------------------------
  # 6. Bounds helper
  # ------------------------------------------------------------
  cli::cli_progress_step("Computing rotation bounds...")

  compute_bounds <- function(crop_harmonized, dist, amend, animal,
                             start_date_override = NULL,
                             end_date_override   = NULL) {

    # Helper: drop NULL or empty data frames
    clean_df <- function(df, date_cols) {
      if (is.null(df)) return(NULL)
      if (nrow(df) == 0) return(NULL)

      df <- df %>% filter(!is.na(MGT_combo))

      # Keep only rows with at least one non-NA date
      df <- df %>%
        filter(rowSums(!is.na(across(all_of(date_cols)))) > 0)

      if (nrow(df) == 0) return(NULL)
      df
    }

    crop_h   <- clean_df(crop_harmonized, c("crop_start", "crop_end"))
    dist_h   <- clean_df(dist,           c("SD_date"))
    amend_h  <- clean_df(amend,          c("SA_date"))
    animal_h <- clean_df(animal,         c("AD_start_date", "AD_end_date"))

    dfs <- list(crop_h, dist_h, amend_h, animal_h)
    dfs <- dfs[!vapply(dfs, is.null, logical(1))]

    if (length(dfs) == 0) {
      stop("No valid crop, disturbance, amendment, or animal data found.", call. = FALSE)
    }

    # Summaries
    summarize_bounds <- function(df, start_col, end_col) {
      df %>%
        group_by(MGT_combo) %>%
        summarize(
          start = min(.data[[start_col]], na.rm = TRUE),
          end   = max(.data[[end_col]],   na.rm = TRUE),
          .groups = "drop"
        )
    }

    df_list <- list()

    if (!is.null(crop_h))   df_list[[length(df_list)+1]] <- summarize_bounds(crop_h,   "crop_start",    "crop_end")
    if (!is.null(dist_h))   df_list[[length(df_list)+1]] <- summarize_bounds(dist_h,   "SD_date",       "SD_date")
    if (!is.null(amend_h))  df_list[[length(df_list)+1]] <- summarize_bounds(amend_h,  "SA_date",       "SA_date")
    if (!is.null(animal_h)) df_list[[length(df_list)+1]] <- summarize_bounds(animal_h, "AD_start_date", "AD_end_date")

    df_all <- bind_rows(df_list)

    # ---- FULL-YEAR LOGIC ----
    rot_bounds <- df_all %>%
      group_by(MGT_combo) %>%
      summarize(
        # Determine calendar-year bounds from actual data
        yr_min = min(lubridate::year(start), na.rm = TRUE),
        yr_max = max(lubridate::year(end),   na.rm = TRUE),

        # Full-year defaults
        rot_start_default = as.Date(paste0(yr_min, "-01-01")),
        rot_end_default   = as.Date(paste0(yr_max, "-12-31")),

        # Apply overrides if present
        rot_start = if (!is.null(start_date_override))
          as.Date(start_date_override)
        else
          rot_start_default,

        rot_end   = if (!is.null(end_date_override))
          as.Date(end_date_override)
        else
          rot_end_default,

        .groups = "drop"
      ) %>%
      select(MGT_combo, rot_start, rot_end)

    rot_bounds
  }

  rot_bounds <- compute_bounds(crop_harmonized, dist, amend, animal)

  rot_bounds <- rot_bounds %>%
    dplyr::mutate(
      rot_start_yr = lubridate::year(as.Date(rot_start)),
      rot_end_yr   = lubridate::year(as.Date(rot_end))
    )

  # ------------------------------------------------------------
  # 7. VALIDATION
  # ------------------------------------------------------------
  # ---- VALIDATION (AFTER harmonization and bounds) ----

  ch <- crop_harmonized

  # 1. Every crop must have an end date
  missing_end <- ch %>% filter(is.na(crop_end))
  if (nrow(missing_end) > 0) {
    stop(
      "Error: Some crops still have no end date even after inference:\n",
      paste0("  - ", missing_end$MGT_combo, " seq ", missing_end$CD_seq_num),
      call. = FALSE
    )
  }

  # 2. crop_end must be >= crop_start
  bad_order <- ch %>% filter(crop_end < crop_start)
  if (nrow(bad_order) > 0) {
    stop(
      "Error: crop_end is before crop_start:\n",
      paste0("  - ", bad_order$MGT_combo, " seq ", bad_order$CD_seq_num),
      call. = FALSE
    )
  }

  # 3. CD_seq_num chronological
  bad_seq <- ch %>%
    group_by(MGT_combo) %>%
    arrange(CD_seq_num) %>%
    mutate(
      next_start = lead(crop_start),
      next_seq   = lead(CD_seq_num)
    ) %>%
    filter(!is.na(next_start) & crop_start > next_start)

  if (nrow(bad_seq) > 0) {
    stop(
      "Error: CD_seq_num is not chronological:\n",
      paste0("  - ", bad_seq$MGT_combo, " seq ", bad_seq$CD_seq_num,
             " (", bad_seq$crop_start, ") > seq ", bad_seq$next_seq,
             " (", bad_seq$next_start, ")", collapse = "\n"),
      call. = FALSE
    )
  }

  # 4. Same-day planting must share same CD_seq_num
  bad_same_date <- ch %>%
    group_by(MGT_combo, crop_start) %>%
    filter(n() > 1) %>%
    summarize(n_seq = n_distinct(CD_seq_num), .groups = "drop") %>%
    filter(n_seq > 1)

  if (nrow(bad_same_date) > 0) {
    stop(
      "Error: Multiple crops with the same planting date have different CD_seq_num values:\n",
      paste0("  - ", bad_same_date$MGT_combo, " on ", bad_same_date$crop_start,
             " has ", bad_same_date$n_seq, " different sequence numbers."),
      call. = FALSE
    )
  }

  # ------------------------------------------------------------
  # 8. Daily disturbance summary
  # ------------------------------------------------------------
  cli::cli_progress_step("Computing daily disturbance grid...")

  daily_dist <- dist %>%
    filter(!is.na(SD_date)) %>%
    mutate(
      date = as.Date(SD_date),
      SD_depth_cm = pmin(SD_depth * 2.54, 30)
    ) %>%
    group_by(MGT_combo, date) %>%
    summarize(
      SD_mixeff = sum(SD_mixeff, na.rm = TRUE),
      SD_depth_cm = max(SD_depth_cm, na.rm = TRUE),
      .groups = "drop"
    )

  # ------------------------------------------------------------
  # Get yield data
  # ------------------------------------------------------------
  if (calc_yield) {
    cli::cli_progress_step("Computing crop yields...")

    yield <- .prepare_yield(path,
                            start_date_override = start_date_override,
                            end_date_override = end_date_override
    )
  } else {
    yield <- NULL
  }

  if (calc_n_rate) {
    cli::cli_progress_step("Computing N rates...")

    n_rate <- .prepare_n_rate(path,
                              start_date_override = start_date_override,
                              end_date_override   = end_date_override)
  } else {
    n_rate <- NULL
  }

  cli::cli_progress_done()
  cli::cli_progress_cleanup()
  # ------------------------------------------------------------
  # 12. Return everything in one clean list
  # ------------------------------------------------------------
  list(
    rot_bounds      = rot_bounds,
    crop_harmonized = crop_harmonized,
    daily_dist      = daily_dist,
    mgt             = mgt,
    crop            = crop,
    dist            = dist,
    amend           = amend,
    animal          = animal,
    yield           = yield,
    n_rate          = n_rate
  )
}
