#' Compute the Diversity sub-index
#'
#' Plant species richness over a rotation window, scaled 0-100.
#'
#' @details
#' Diversity counts the distinct plant species (cash crops, forages and cover
#' crops alike) grown in each `window`-year span of a unit's evaluation window,
#' sliding one calendar year at a time, and averages the counts. A record of
#' `window` years or fewer is a single span. With the default 4-year window a
#' corn-soybean rotation counts 2 species, corn-soybean-wheat 3, and a rye cover
#' grown in the rotation adds 1; a long stand of a single perennial counts 1
#' except in the spans where it meets the next crop. `window = 1` counts species
#' per calendar year (the SHMI 1.0 definition).
#'
#' **Species.** Each distinct `CD_name` is a species (whitespace tidied).
#' Count-first placeholder mixtures such as `"8-species"`, `"8 spp"` or
#' `"8-species mix"` count as that many species. Names joined by `"+"` are
#' split. Rows named `"fallow"`, `"none"` or `"bare"` are not plants.
#'
#' **Score.** \deqn{Diversity = 100 \min\left(\frac{R - 1}{R_{max} - 1}, 1\right)}
#' where \eqn{R} is the average richness per window: one species scores 0, and
#' \eqn{R_{max}} (8) or more scores 100. Corn-soybean scores 14,
#' corn-soybean-wheat 29, corn-soybean-wheat with a rye cover 43.
#'
#' @param crop Species episodes with `MGT_combo`, `CD_name`, `crop_start` and
#'   `crop_end`, as in `prepare_shmi_inputs()$crop`.
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start` and
#'   `rot_end`. Episodes are clipped to this window.
#' @param max_richness Species per window that scores 100.
#' @param window Window length in years (default 4; 1 = calendar years, as in
#'   SHMI 1.0). Can be set for a session with `options(SHMI.diversity_window = )`,
#'   which also changes [build_shmi()] and [shmi_components()].
#'
#' @return A tibble with `MGT_combo`, `Diversity` (0-100) and `Richness`
#'   (average species per window), one row per unit in `rot_bounds`.
#'
#' @seealso [build_shmi()]
#'
#' @examples
#' crop <- data.frame(
#'   MGT_combo  = "field_1",
#'   CD_name    = c("Corn", "Rye", "Soybean"),
#'   crop_start = as.Date(c("2020-05-01", "2020-10-15", "2021-05-10")),
#'   crop_end   = as.Date(c("2020-09-30", "2021-04-20", "2021-09-25"))
#' )
#' rot_bounds <- data.frame(MGT_combo = "field_1",
#'                          rot_start = as.Date("2020-01-01"),
#'                          rot_end   = as.Date("2021-12-31"))
#' compute_diversity(crop, rot_bounds)              # 3 species in the rotation: 29
#' compute_diversity(crop, rot_bounds, window = 1)  # 2 a year (SHMI 1.0): 14
#'
#' @export
compute_diversity <- function(crop, rot_bounds, max_richness = 8,
                              window = getOption("SHMI.diversity_window", 4)) {
  if (!is.numeric(max_richness) || length(max_richness) != 1 || max_richness <= 1)
    stop("max_richness must be a single number greater than 1.", call. = FALSE)
  if (!is.numeric(window) || length(window) != 1 || window < 1 || window != round(window))
    stop("window must be a whole number of years, 1 or more.", call. = FALSE)
  rb <- dplyr::distinct(rot_bounds, .data$MGT_combo, .data$rot_start, .data$rot_end)
  rb$rot_start <- as.Date(rb$rot_start); rb$rot_end <- as.Date(rb$rot_end)
  yr <- function(d) as.integer(format(as.Date(d), "%Y"))
  ex <- .expand_species(clip_crop_to_rotation(crop, rot_bounds))
  ex_by <- split(ex, ex$MGT_combo)

  # species present between two dates
  n_species <- function(ei, from, to) {
    if (is.null(ei)) return(0)
    length(unique(ei$species[as.Date(ei$crop_start) <= to & as.Date(ei$crop_end) >= from]))
  }

  R <- vapply(seq_len(nrow(rb)), function(i) {
    ei <- ex_by[[rb$MGT_combo[i]]]
    y0 <- yr(rb$rot_start[i]); y1 <- yr(rb$rot_end[i])
    if (window > 1 && (y1 - y0 + 1) <= window)               # short record: one window
      return(n_species(ei, rb$rot_start[i], rb$rot_end[i]))
    starts <- seq(y0, y1 - window + 1)
    mean(vapply(starts, function(s)
      n_species(ei, max(rb$rot_start[i], as.Date(sprintf("%d-01-01", s))),
                    min(rb$rot_end[i], as.Date(sprintf("%d-12-31", s + window - 1)))),
      numeric(1)))
  }, numeric(1))

  tibble::tibble(MGT_combo = rb$MGT_combo,
                 Diversity = 100 * pmin(pmax(R - 1, 0) / (max_richness - 1), 1),
                 Richness  = R)
}


# Species in a crop table: placeholder mixtures ("8-species") become that many
# synthetic species, names joined by "+" are split, fallow is dropped.
.expand_species <- function(crop) {
  crop <- crop[!is.na(crop$crop_start) & !is.na(crop$crop_end), , drop = FALSE]
  crop$CD_name <- gsub("\\s+", " ", trimws(as.character(crop$CD_name)))
  n_mix <- .placeholder_n(crop$CD_name)
  ph <- crop[!is.na(n_mix), , drop = FALSE]
  ph <- if (nrow(ph)) {
    ph$species <- lapply(n_mix[!is.na(n_mix)], function(n) paste0("species_", seq_len(n)))
    tidyr::unnest(ph, "species")
  } else { ph$species <- character(0); ph }
  nm <- crop[is.na(n_mix), , drop = FALSE]
  nm$species <- strsplit(nm$CD_name, "\\s*\\+\\s*")
  nm <- tidyr::unnest(nm, "species")
  out <- dplyr::bind_rows(ph, nm)
  out$species <- trimws(out$species)
  out <- out[out$species != "" & !(tolower(out$species) %in% c("fallow", "none", "bare")), ]
  out[, c("MGT_combo", "species", "crop_start", "crop_end")]
}


# Number of species in a count-first placeholder name ("8-species", "8 spp",
# "8-species mix"); NA otherwise. "Species 1" or "Multi-species" are not
# placeholders.
.placeholder_n <- function(x) {
  x   <- tolower(trimws(as.character(x)))
  pat <- "^([0-9]+)\\s*-?\\s*(species|spp\\.?)(\\s+(mix|mixture|blend))?$"
  hit <- !is.na(x) & grepl(pat, x)
  n   <- rep(NA_integer_, length(x))
  n[hit] <- as.integer(sub(pat, "\\1", x[hit]))
  n[!is.na(n) & n < 1] <- NA_integer_
  n
}
