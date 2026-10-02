#' Compute the Diversity sub-index
#'
#' Average annual plant species richness, scaled 0-100.
#'
#' @details
#' For each calendar year in a unit's evaluation window, Diversity counts the
#' plant species present at any time that year, then averages the counts over
#' the years. A cover crop or a seed mix therefore raises Diversity in the
#' years it grows; a rotation of single crops (corn, then soybean) counts one
#' species per year.
#'
#' **Species.** Each distinct `CD_name` is a species (whitespace tidied).
#' Count-first placeholder mixtures such as `"8-species"`, `"8 spp"` or
#' `"8-species mix"` count as that many species. Names joined by `"+"` are
#' split. Rows named `"fallow"`, `"none"` or `"bare"` are not plants.
#'
#' **Score.** \deqn{Diversity = 100 \min\left(\frac{R - 1}{R_{max} - 1}, 1\right)}
#' where \eqn{R} is the average annual richness: one species a year scores 0,
#' and \eqn{R_{max}} (8) or more species a year scores 100.
#'
#' @param crop Species episodes with `MGT_combo`, `CD_name`, `crop_start` and
#'   `crop_end`, as in `prepare_shmi_inputs()$crop`.
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start` and
#'   `rot_end`. Episodes are clipped to this window.
#' @param max_richness Average species per year that scores 100.
#'
#' @return A tibble with `MGT_combo`, `Diversity` (0-100) and `Richness`
#'   (average species per year), one row per unit in `rot_bounds`.
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
#' compute_diversity(crop, rot_bounds)   # 2 species in 2020 and 2021
#'
#' @export
compute_diversity <- function(crop, rot_bounds, max_richness = 8) {
  if (!is.numeric(max_richness) || length(max_richness) != 1 || max_richness <= 1)
    stop("max_richness must be a single number greater than 1.", call. = FALSE)
  rb <- dplyr::distinct(rot_bounds, .data$MGT_combo, .data$rot_start, .data$rot_end)
  rb$rot_start <- as.Date(rb$rot_start); rb$rot_end <- as.Date(rb$rot_end)
  yr <- function(d) as.integer(format(as.Date(d), "%Y"))
  ex <- .expand_species(clip_crop_to_rotation(crop, rot_bounds))
  ex_by <- split(ex, ex$MGT_combo)

  R <- vapply(seq_len(nrow(rb)), function(i) {
    ei  <- ex_by[[rb$MGT_combo[i]]]
    yrs <- seq(yr(rb$rot_start[i]), yr(rb$rot_end[i]))
    mean(vapply(yrs, function(y) {
      if (is.null(ei)) return(0)
      ys <- as.Date(sprintf("%d-01-01", y)); ye <- as.Date(sprintf("%d-12-31", y))
      length(unique(ei$species[as.Date(ei$crop_start) <= ye & as.Date(ei$crop_end) >= ys]))
    }, numeric(1)))
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
