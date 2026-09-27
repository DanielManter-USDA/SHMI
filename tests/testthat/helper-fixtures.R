# Shared builders for SHMI tests. testthat sources helper-*.R files before
# running tests, and tests run inside the package namespace, so internal
# functions such as .build_crop_windows() can be called directly.

# Raw Crop_Diversity rows (vectorized over crops)
crop_rows <- function(CD_cat, CD_name, plant = NA, harv = NA, term = NA,
                      MGT_combo = "U1",
                      yield = NA_real_, yield_units = NA_character_) {
  tibble::tibble(
    MGT_combo      = MGT_combo,
    CD_cat         = CD_cat,
    CD_name        = CD_name,
    CD_plant_date  = as.Date(plant),
    CD_harv_date   = as.Date(harv),
    CD_term_date   = as.Date(term),
    CD_yield       = yield,
    CD_yield_units = yield_units
  )
}

# Rotation bounds
rot <- function(start, end, MGT_combo = "U1") {
  s <- as.Date(start)
  e <- as.Date(end)
  tibble::tibble(
    MGT_combo    = MGT_combo,
    rot_start    = s,
    rot_end      = e,
    rot_start_yr = as.integer(format(s, "%Y")),
    rot_end_yr   = as.integer(format(e, "%Y"))
  )
}

# Ready-made crop windows (input to compute_cover / compute_diversity)
win <- function(CD_name, start, end, MGT_combo = "U1") {
  tibble::tibble(
    MGT_combo  = MGT_combo,
    CD_name    = CD_name,
    crop_start = as.Date(start),
    crop_end   = as.Date(end)
  )
}

# Episode rows for one species
ep <- function(res, name) dplyr::filter(res$windows, CD_name == name)

# Was a given assumption/check logged for a species?
has_flag <- function(res, name, type) {
  any(res$assumptions$name == name & res$assumptions$type == type)
}

# Disturbance passes
passes <- function(date, mixeff, depth = NA_real_, MGT_combo = "U1") {
  tibble::tibble(
    MGT_combo = MGT_combo,
    SD_date   = as.Date(date),
    SD_mixeff = mixeff,
    SD_depth  = depth
  )
}

# Canonical ordering so tables can be compared regardless of row order
canon <- function(df) {
  df <- as.data.frame(df)
  df[do.call(order, unname(as.list(df))), , drop = FALSE] |>
    `rownames<-`(NULL)
}
