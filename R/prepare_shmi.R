prepare_shmi_inputs <- function(path,
                                exclude = NULL,
                                verbose = TRUE,
                                start_year_override = NULL,
                                end_year_override = NULL) {

  # ------------------------------------------------------------
  # 1. Exclusion lists
  # ------------------------------------------------------------
  EXCLUDE_WOODY      <- c("NAPESHM_USMI04_306", "NAPESHM_USNC03_368", "NAPESHM_USNC03_369",
                          "NAPESHM_USNC03_370", "NAPESHM_USNC03_371", "NAPESHM_USNC03_372")
  EXCLUDE_BENCHMARK  <- c("NAPESHM_USNY01_395", "NAPESHM_USNY02_400",
                          "NAPESHM_USNY03_403", "NAPESHM_USNY04_406")
  EXCLUDE_NOINF      <- c("NAPESHM_USOK01_429", "NAPESHM_USOK01_430",
                          "NAPESHM_USOK01_431", "NAPESHM_USOK01_432")
  default_exclude <- c(EXCLUDE_WOODY, EXCLUDE_BENCHMARK, EXCLUDE_NOINF)

  # If user supplies exclusions, combine them; otherwise use defaults
  exclude <- unique(c(default_exclude, exclude))

  if (verbose) {
    message("Excluding ", length(exclude), " management units:")
    message(paste("  -", exclude, collapse = "\n"))
  }

  # ------------------------------------------------------------
  # 2. Helper to read + filter sheets
  # ------------------------------------------------------------
  read_sheet <- function(sheet, skip=3, range=NULL, drop_cols = NULL) {
    df <- read_xlsx(path, sheet = sheet, skip = skip, range = range) %>%
      left_join(mgt, by = c("user_name", "MGT_combo")) %>%
      select(-user_name, -MGT_id, all_of(drop_cols)) %>%
      janitor::remove_empty("rows") %>%
      filter(!(MGT_combo %in% exclude))

    if (verbose) {
      # Print included combos for this sheet
      included <- unique(df$MGT_combo)
      message("\nIncluded ", length(included), " management units for sheet '", sheet, "':")
      message(paste("  -", included, collapse = "\n"))

    }
    df
  }

  # ------------------------------------------------------------
  # 3. Load MGT first (needed for joins)
  # ------------------------------------------------------------
  mgt <- read_xlsx(path, sheet = "Mgt_Unit", skip = 3, range = NULL) %>%
    select(user_name, MGT_combo) %>%
    janitor::remove_empty("rows") %>%
    filter(!(MGT_combo %in% exclude))

  if (verbose) {
    included <- unique(mgt$MGT_combo)
    message("\nIncluded ", length(included), " management units for sheet Mgt_Unit:")
    message(paste("  -", included, collapse = "\n"))
  }

  # ------------------------------------------------------------
  # 4. Load all sheets
  # ------------------------------------------------------------
  parse_date_safe <- function(x) {
    suppressWarnings({
      # Try ymd first
      d <- lubridate::ymd(x, quiet = TRUE)

      # If still NA, try mdy
      d[is.na(d)] <- lubridate::mdy(x[is.na(d)], quiet = TRUE)

      # If still NA, try dmy
      d[is.na(d)] <- lubridate::dmy(x[is.na(d)], quiet = TRUE)

      # If still NA, try Excel serial numbers
      suppressWarnings({
        nums <- suppressWarnings(as.numeric(x))
        d[is.na(d) & !is.na(nums)] <- as.Date(nums[is.na(d) & !is.na(nums)], origin = "1899-12-30")
      })

      # Final: return Date or NA
      d
    })
  }

  crop <- read_sheet("Crop_Diversity", skip = 3, drop_cols = c("CD_id")) %>%
    janitor::remove_empty("rows") %>%
    mutate(across(c(CD_plant_date, CD_harv_date, CD_term_date), parse_date_safe))

  if (!is.null(start_year_override)) {
    crop <- crop %>%
      filter(
        lubridate::year(CD_plant_date) >= start_year_override |
          lubridate::year(CD_harv_date)  >= start_year_override |
          lubridate::year(CD_term_date)  >= start_year_override
      )
  }

  if (!is.null(end_year_override)) {
    crop <- crop %>%
      filter(
        lubridate::year(CD_plant_date) <= end_year_override |
          lubridate::year(CD_harv_date)  <= end_year_override |
          lubridate::year(CD_term_date)  <= end_year_override
      )
  }

  dist <- read_sheet("Soil_Disturbance", skip = 3) %>%
    janitor::remove_empty("rows") %>%
    mutate(across(c(SD_date), parse_date_safe))

  if (!is.null(start_year_override)) {
    dist <- dist %>%
      filter(lubridate::year(SD_date) >= start_year_override)
  }

  if (!is.null(end_year_override)) {
    dist <- dist %>% filter(lubridate::year(SD_date) <= end_year_override)
  }

  amend <- read_sheet("Soil_Amendments", skip = 3) %>%
    janitor::remove_empty("rows") %>%
    mutate(across(c(SA_date), parse_date_safe))

  if (!is.null(start_year_override)) {
    amend <- amend %>%
      filter(lubridate::year(SA_date) >= start_year_override)
  }

  if (!is.null(end_year_override)) {
    amend <- amend %>% filter(lubridate::year(SA_date) <= end_year_override)
  }

  animal <- read_sheet("Animal_Diversity", skip = 3) %>%
    janitor::remove_empty("rows") %>%
    mutate(across(c(AD_start_date, AD_end_date), parse_date_safe))

  if (!is.null(start_year_override)) {
    animal <- animal %>%
      filter(
        lubridate::year(AD_start_date) >= start_year_override |
          lubridate::year(AD_end_date)   >= start_year_override
      )
  }

  if (!is.null(end_year_override)) {
    animal <- animal %>%
      filter(
        lubridate::year(AD_start_date) <= end_year_override |
          lubridate::year(AD_end_date)   <= end_year_override
      )
  }

  # ------------------------------------------------------------
  # 5. Harmonize crop windows
  # ------------------------------------------------------------
  harmonize_crop_windows <- function(crop) {

    crop %>%
      mutate(
        # ensure dates are Date
        CD_plant_date = as.Date(CD_plant_date),
        CD_harv_date  = as.Date(CD_harv_date),
        CD_term_date  = as.Date(CD_term_date),
      ) %>%
      group_by(MGT_combo) %>%
      # need a start and end year for each MGT_combo
      mutate(
        start_yr = suppressWarnings(
          min(
            lubridate::year(CD_plant_date),
            lubridate::year(CD_harv_date),
            lubridate::year(CD_term_date),
            na.rm = TRUE
          )
        ),
        end_yr = suppressWarnings(
          max(
            lubridate::year(CD_plant_date),
            lubridate::year(CD_harv_date),
            lubridate::year(CD_term_date),
            na.rm = TRUE
          )
        )
      ) %>%
      ungroup() %>%
      # now fill in missing planting/termination dates
      # for first and last crop in each MGT_combo
      group_by(MGT_combo, CD_seq_num) %>%
      mutate(
        # identify first/last crop in rotation
        is_first = CD_seq_num == min(CD_seq_num),
        is_last  = CD_seq_num == max(CD_seq_num),

        # raw crop windows across all species in the mixture
        # date may be missing (to be filled in later)
        start_raw = suppressWarnings(
          min(CD_plant_date, na.rm = TRUE)
        ),
        end_raw = suppressWarnings(
          max(CD_harv_date, CD_term_date, na.rm = TRUE)
        ),
        start_raw = dplyr::if_else(is.infinite(start_raw), NA_Date_, start_raw),
        end_raw   = dplyr::if_else(is.infinite(end_raw),   NA_Date_, end_raw)
      ) %>%
      # collapse to one row per event (mixture → event)
      summarize(
        CD_group = paste(unique(CD_group), collapse = " + "),
        CD_name  = paste(unique(CD_name), collapse = " + "),
        crop_start = dplyr::first(
          dplyr::if_else(
            is_first & is.na(start_raw),
            as.Date(paste0(start_yr, "-01-01")),   # fallback
            start_raw
          )
        ),
        crop_end = dplyr::first(
          dplyr::if_else(
            is_last & is.na(end_raw),
            as.Date(paste0(end_yr, "-12-31")),   # fallback
            end_raw
          )
        ),
        .groups = "drop"
      )
  }

  crop_harmonized <- harmonize_crop_windows(crop)

  if (!is.null(start_year_override)) {
    start_cut <- as.Date(paste0(start_year_override, "-01-01"))
    crop_harmonized <- crop_harmonized %>%
      mutate(
        crop_start = pmax(crop_start, start_cut)
      )
  }

  if (!is.null(end_year_override)) {
    end_cut <- as.Date(paste0(end_year_override, "-12-31"))
    crop_harmonized <- crop_harmonized %>%
      mutate(
        crop_end = pmin(crop_end, end_cut)
      )
  }

  # ------------------------------------------------------------
  # 6. Bounds helper
  # ------------------------------------------------------------
  compute_bounds <- function(crop_harmonized, dist, amend, animal) {
    df1 <- crop_harmonized %>%
      select(MGT_combo, crop_start, crop_end) %>%
      group_by(MGT_combo) %>%
      summarize(start_year = min(lubridate::year(crop_start), na.rm = TRUE),
                end_year = max(lubridate::year(crop_end), na.rm = TRUE))
    df2 <- dist %>%
      select(MGT_combo, SD_date) %>%
      group_by(MGT_combo) %>%
      summarize(start_year = min(lubridate::year(SD_date), na.rm = TRUE),
                end_year = max(lubridate::year(SD_date), na.rm = TRUE))

    df3 <- amend %>%
      select(MGT_combo, SA_date) %>%
      group_by(MGT_combo) %>%
      summarize(start_year = min(lubridate::year(SA_date), na.rm = TRUE),
                end_year = max(lubridate::year(SA_date), na.rm = TRUE))

    df4 <- animal %>%
      select(MGT_combo, AD_start_date, AD_end_date) %>%
      group_by(MGT_combo) %>%
      summarize(start_year = min(lubridate::year(AD_start_date), na.rm = TRUE),
                end_year = max(lubridate::year(AD_end_date), na.rm = TRUE))

    df5 <- rbind(df1, df2, df3, df4) %>%
      group_by(MGT_combo) %>%
      summarize(
        rot_start_yr = min(start_year, na.rm = TRUE),
        rot_end_yr = max(end_year, na.rm = TRUE)) %>%
      mutate(rot_start = as.Date(paste0(rot_start_yr, "-01-01")),
             rot_end = as.Date(paste0(rot_end_yr, "-12-31")))

    df5

  }

  rot_bounds <- compute_bounds(crop_harmonized, dist, amend, animal)

  if (!is.null(start_year_override)) {
    rot_bounds$rot_start_yr <- pmax(rot_bounds$rot_start_yr, start_year_override)
    rot_bounds$rot_start <- as.Date(paste0(rot_bounds$rot_start_yr, "-01-01"))
  }

  if (!is.null(end_year_override)) {
    rot_bounds$rot_end_yr <- pmin(rot_bounds$rot_end_yr, end_year_override)
    rot_bounds$rot_end <- as.Date(paste0(rot_bounds$rot_end_yr, "-12-31"))
  }

  # ------------------------------------------------------------
  # 10. Daily disturbance summary
  # ------------------------------------------------------------
  daily_dist <- dist %>%
    select(MGT_combo, SD_date, SD_mixeff) %>%
    group_by(MGT_combo, SD_date) %>%
    summarize(
      SDmax = max(SD_mixeff, na.rm = TRUE),
      SDsum = sum(SD_mixeff, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    rename(date = SD_date)


  # ------------------------------------------------------------
  # 11. Build daily grid
  # ------------------------------------------------------------

  build_daily_grid <- function(crop_harmonized, rot_bounds, daily_dist) {

    if (verbose) {
      message("Building the rotation grid...")
    }

    rot_grid <- rot_bounds %>%
      rowwise() %>%
      mutate(date = list(seq.Date(rot_start, rot_end, by = "day"))) %>%
      unnest(date) %>%
      ungroup()

    if (verbose) {
      message("Building the crop grid...")
    }

    crop_grid <- crop_harmonized %>%
      rowwise() %>%
      mutate(date = list(seq.Date(crop_start, crop_end, by = "day"))) %>%
      unnest(date) %>%
      ungroup() %>%
      mutate(crop_present = 1L)

    if (verbose) {
      message("Combining grids...")
    }

    daily_crop <- rot_grid %>%
      left_join(crop_grid, by = c("MGT_combo", "date"), relationship = "many-to-many") %>%
      mutate(crop_present = replace_na(crop_present, 0L))

    temp <- daily_crop %>%
      left_join(daily_dist, by = c("MGT_combo", "date")) %>%
      mutate(
        SDmax = replace_na(SDmax, 0),
        SDsum = replace_na(SDsum, 0)
      )
  }

  daily <- build_daily_grid(crop_harmonized, rot_bounds, daily_dist)

  # ------------------------------------------------------------
  # 12. Return everything in one clean list
  # ------------------------------------------------------------
  list(
    rot_bounds      = rot_bounds,
    crop_harmonized = crop_harmonized,
    daily           = daily,
    daily_dist      = daily_dist,
    mgt             = mgt,
    crop            = crop,
    dist            = dist,
    amend           = amend,
    animal          = animal
  )
}
