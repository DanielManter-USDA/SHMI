#' Compute Rotation-Scale Crop Diversity (Entropy-Based Hill Numbers)
#'
#' Calculates the SHMI diversity pillar for each management unit (`MGT_combo`)
#' using daily crop presence data and harmonized crop windows. Diversity is
#' computed at the *rotation scale* by expanding species mixtures, summing
#' plant-days across years, and applying Hill-number diversity metrics in
#' entropy form (Shannon or Simpson). The final diversity score is scaled to
#' 0–100 using a user-specified theoretical maximum.
#'
#' @param crop_harmonized A data frame produced by
#'   \code{prepare_shmi_inputs()}, containing one row per crop event with
#'   harmonized start/end dates and mixture names.
#'
#' @param daily A daily data frame from \code{prepare_shmi_inputs()},
#'   containing:
#'   \itemize{
#'     \item \code{MGT_combo} — management unit identifier
#'     \item \code{date} — calendar date
#'     \item \code{CD_seq_num} — crop sequence number
#'     \item \code{CD_name} — crop or mixture name
#'     \item \code{crop_present} — 1 if crop present, 0 otherwise
#'   }
#'
#' @param hill Hill-number order. Supported values:
#'   \itemize{
#'     \item \code{0}: species richness
#'     \item \code{1}: Shannon entropy
#'     \item \code{2}: Simpson entropy (entropy form)
#'   }
#'   Default is \code{2}.
#'
#' @param max_div The theoretical maximum diversity used for scaling the
#'   final index to 0–100. For richness (\code{hill = 0}), this is the maximum
#'   number of species. For entropy-based metrics, scaling uses
#'   \code{log(max_div)}.
#'
#' @details
#' The algorithm proceeds in four stages:
#'
#' \enumerate{
#'   \item \strong{Daily plant-days}: Sum daily crop presence by
#'     \code{MGT_combo × CD_seq_num × CD_name × year}.
#'
#'   \item \strong{Mixture expansion}:
#'     Mixtures such as \code{"A + B"} are split into individual species.
#'     Placeholder mixtures like \code{"3-species"} are expanded into
#'     \code{species_1}, \code{species_2}, \code{species_3}.
#'
#'   \item \strong{Rotation-scale plant-days}:
#'     Plant-days are summed across all years of the rotation for each species.
#'
#'   \item \strong{Entropy-based diversity}:
#'     Species proportions \eqn{p_i} are computed and diversity is calculated as:
#'     \itemize{
#'       \item Richness: \eqn{D = \sum I(p_i > 0)}
#'       \item Shannon entropy: \eqn{D = -\sum p_i \log p_i}
#'       \item Simpson entropy: \eqn{D = -\log \sum p_i^2}
#'     }
#'     The result is capped at \code{max_div} and scaled to 0–100.
#' }
#'
#' @return A data frame with:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{Diversity} — rotation-scale diversity score (0–100)
#'   }
#'
#' @export
compute_diversity <- function(crop_harmonized,
                              daily,
                              hill = 2,
                              max_div = 8) {

  # 1. Daily plant-days summary
  daily_sum <- daily %>%
    ungroup() %>%
    mutate(year = lubridate::year(date)) %>%
    group_by(MGT_combo, CD_seq_num, CD_name, year) %>%
    summarise(days = sum(crop_present), .groups = "drop") %>%
    filter(!is.na(CD_seq_num))

  # 2. Expand mixtures
  expand_mixtures <- function(df) {
    placeholder <- df %>%
      filter(str_detect(CD_name, "-species")) %>%
      mutate(
        mix_n = as.integer(str_extract(CD_name, "\\d+")),
        species = map(mix_n, ~ paste0("species_", seq_len(.x)))
      ) %>%
      unnest(species)

    realmix <- df %>%
      filter(!str_detect(CD_name, "-species")) %>%
      mutate(species = str_split(CD_name, "\\s*\\+\\s*")) %>%
      unnest(species) %>%
      mutate(species = str_trim(species))

    bind_rows(placeholder, realmix) %>%
      select(MGT_combo, species, year, days)
  }

  species_expanded <- expand_mixtures(daily_sum)

  # 3. Compute annual plant-days
  plant_days <- species_expanded %>%
    mutate(days = ifelse(species == "fallow", 0, days)) %>%
    group_by(MGT_combo, species, year) %>%
    summarise(days = sum(days), .groups = "drop")

  # 4. Rotation diversity (now entropy-based)
  div_rot <- plant_days %>%
    group_by(MGT_combo, species) %>%
    summarise(days = sum(days), .groups = "drop") %>%
    group_by(MGT_combo) %>%
    mutate(p = days / sum(days)) %>%
    summarise(
      D = case_when(
        hill == 0 ~ sum(p > 0),                         # richness
        hill == 1 ~ -sum(p * log(p), na.rm = TRUE),     # Shannon entropy
        TRUE      ~ -log(sum(p^2, na.rm = TRUE))        # Simpson entropy (entropy form)
      ),
      .groups = "drop"
    ) %>%
    mutate(
      D = ifelse(is.na(D), 0, D),
      D = pmin(D, max_div)
    )

  # 7. Final scaling (0–100)
  div_final <- div_rot %>%
    mutate(
      Diversity_raw = case_when(
        hill == 0 ~ D / max_div,          # richness scaled by max_div
        TRUE      ~ D / log(max_div)      # entropies scaled by log(max_div)
      ),
      Diversity = pmin(Diversity_raw, 1) * 100
    )

  return(div_final)
}
