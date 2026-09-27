#' Compute the Diversity sub-index
#'
#' Rotation-scale crop diversity based on the number of days each species is
#' present, scaled 0-100.
#'
#' @details
#' **Species.** Each distinct `CD_name` is a species. Full names are used, so
#' `"Rye"` and `"Rye, Cereal"` are different species; extra whitespace is
#' ignored. Count-first placeholder mixtures such as `"8-species"`,
#' `"8 species"`, or `"8-spp"` are expanded into synthetic species
#' `species_1`, ..., `species_8`. Placeholders in the same unit share these
#' names, so a mix repeated in several years counts as the same species.
#' Names such as `"Species 1"` are ordinary named species. Legacy names
#' joined by `"+"` (`"A + B"`) are split. Fallow rows are excluded.
#'
#' **Plant-days.** For each species, plant-days are the union of its
#' episodes, so overlapping episodes of the same species count once, while
#' different species present on the same day each count. Species proportions
#' are \eqn{p_i = days_i / \sum_j days_j}.
#'
#' **Order** (`hill`):
#' * `0`: richness, the number of species, divided by `max_div`.
#' * `1`: Shannon entropy \eqn{-\sum_i p_i \log p_i}, divided by
#'   `log(max_div)`.
#' * `2`: Simpson (order-2 Renyi) entropy \eqn{-\log \sum_i p_i^2}, divided
#'   by `log(max_div)`.
#'
#' Orders 1 and 2 are logarithms of the corresponding Hill numbers, so the
#' score reaches 100 when the effective number of species reaches `max_div`.
#' Scores are capped at 100. Under orders 1 and 2 a single species scores 0.
#'
#' @param crop Species episodes with `MGT_combo`, `CD_name`, `crop_start`,
#'   and `crop_end`, as in `prepare_shmi_inputs()$crop`.
#' @param hill Diversity order: `0` (richness), `1` (Shannon, official), or
#'   `2` (Simpson).
#' @param max_div Number of species (or effective species) that scores 100.
#'
#' @return A data frame with `MGT_combo` and `Diversity` (0-100). Units with
#'   no non-fallow species are omitted; [build_shmi()] scores them 0.
#'
#' @seealso [build_shmi()], [compute_cover()]
#'
#' @examples
#' crop <- data.frame(
#'   MGT_combo  = "field_1",
#'   CD_name    = c("Corn", "Soybean", "8-species"),
#'   crop_start = as.Date(c("2019-05-01", "2020-05-10", "2020-10-15")),
#'   crop_end   = as.Date(c("2019-09-30", "2020-09-25", "2021-04-01"))
#' )
#' compute_diversity(crop)            # Shannon (official)
#' compute_diversity(crop, hill = 0)  # richness
#'
#' @export
compute_diversity <- function(crop,
                              hill = 1,
                              max_div = 10) {

  # ---- 1. Expand mixtures into species ----
  # Species are identified by their full CD_name (whitespace tidied), so
  # "Rye" and "Rye, Cereal" are different species.
  expand_mixtures <- function(df) {

    df <- df %>%
      mutate(CD_name = gsub("\\s+", " ", trimws(as.character(CD_name))))

    n_mix <- .placeholder_n(df$CD_name)

    # ---- CASE 1: Placeholder mixtures like "8-species" ----
    # Expanded into synthetic species species_1 ... species_n. Placeholders
    # in the same unit share these names, so an "8-species" mix repeated in
    # several years counts as the same 8 species (a conservative choice).
    placeholder <- df[!is.na(n_mix), ] %>%
      mutate(
        mix_n   = n_mix[!is.na(n_mix)],
        species = lapply(mix_n, function(n) paste0("species_", seq_len(n)))
      ) %>%
      tidyr::unnest(species) %>%
      select(MGT_combo, species, crop_start, crop_end)

    # ---- CASE 2: Named species, including legacy "A + B + C" names ----
    realmix <- df[is.na(n_mix), ] %>%
      mutate(species = strsplit(CD_name, "\\s*\\+\\s*")) %>%
      tidyr::unnest(species) %>%
      mutate(species = trimws(species)) %>%
      filter(species != "") %>%
      select(MGT_combo, species, crop_start, crop_end)

    bind_rows(placeholder, realmix)
  }

  expanded <- expand_mixtures(crop)

  # ---- 2. Compute plant-days per species ----
  # Union within each species so the same species is never counted twice on
  # one day (duplicate or overlapping episodes). Different species that
  # overlap (mixtures, relays, intercrops) each keep their full days.
  species_days <- expanded %>%
    filter(!tolower(species) %in% c("fallow", "none", "bare")) %>%
    group_by(MGT_combo, species) %>%
    summarize(
      days = .union_days(crop_start, crop_end),
      .groups = "drop"
    ) %>%
    filter(days > 0)

  # ---- 3. Compute species proportions and entropy ----
  # hill is a single value, so choose the formula with if/else rather than
  # case_when() (which evaluates every branch and warns in dplyr >= 1.2).
  entropy <- function(p) {
    if (hill == 0) {
      sum(p > 0)                          # richness
    } else if (hill == 1) {
      -sum(p * log(p), na.rm = TRUE)      # Shannon entropy
    } else {
      -log(sum(p^2, na.rm = TRUE))        # Simpson entropy (entropy form)
    }
  }

  div_rot <- species_days %>%
    group_by(MGT_combo) %>%
    mutate(
      p = days / sum(days)
    ) %>%
    summarize(
      D = entropy(p),
      .groups = "drop"
    ) %>%
    mutate(
      D = if_else(is.na(D), 0, D)
    )

  # ---- 4. Scale to 0-100 ----
  # Richness is scaled by max_div (a species count); entropies by
  # log(max_div). The cap at 100 is applied once, after scaling, so it is
  # correct for every Hill order.
  D_scale <- if (hill == 0) max_div else log(max_div)

  div_final <- div_rot %>%
    mutate(
      Diversity_raw = D / D_scale,
      Diversity     = pmin(Diversity_raw, 1) * 100
    ) %>%
    select(MGT_combo, Diversity)

  div_final
}


#' Number of species in a placeholder mixture name (internal)
#'
#' Recognizes count-first placeholders such as "8-species", "8 species",
#' "8species", "8-spp", and "8-species mix" (case-insensitive) and returns the
#' count. Anything else returns NA and is treated as a named species. Names
#' such as "Species 1" or "Multi-species" are therefore *not* expanded:
#' "Species 1" / "Species 2" label individual unnamed species in a mix.
#'
#' @param x Character vector of crop names.
#' @return Integer vector of species counts (NA when not a placeholder).
#' @keywords internal
#' @noRd
.placeholder_n <- function(x) {
  x   <- tolower(trimws(as.character(x)))
  pat <- "^([0-9]+)\\s*-?\\s*(species|spp\\.?)(\\s+(mix|mixture|blend))?$"
  hit <- !is.na(x) & grepl(pat, x)
  n   <- rep(NA_integer_, length(x))
  n[hit] <- as.integer(sub(pat, "\\1", x[hit]))
  n[!is.na(n) & n < 1] <- NA_integer_
  n
}
