#' Compute Rotation-Scale Crop Diversity (Entropy-Based Hill Numbers)
#'
#' Calculates the SHMI diversity sub-index for each management unit (`MGT_combo`)
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
                              hill = 2,
                              max_div = 8) {

  # ---- 1. Expand mixtures into species ----
  expand_mixtures <- function(df) {

    placeholder <- df %>%
      dplyr::filter(stringr::str_detect(CD_name, "-species")) %>%
      dplyr::mutate(
        mix_n = as.integer(stringr::str_extract(CD_name, "\\d+")),
        species = purrr::map(mix_n, ~ paste0("species_", seq_len(.x)))
      ) %>%
      tidyr::unnest(species)

    realmix <- df %>%
      dplyr::filter(!stringr::str_detect(CD_name, "-species")) %>%
      dplyr::mutate(
        species = stringr::str_split(CD_name, "\\s*\\+\\s*")
      ) %>%
      tidyr::unnest(species) %>%
      dplyr::mutate(species = stringr::str_trim(species))

    dplyr::bind_rows(placeholder, realmix) %>%
      dplyr::select(MGT_combo, species, crop_start, crop_end)
  }

  expanded <- expand_mixtures(crop_harmonized)

  # ---- 2. Compute interval length per species ----
  species_days <- expanded %>%
    dplyr::mutate(
      days = as.integer(crop_end - crop_start) + 1L,
      days = dplyr::if_else(species == "fallow", 0L, days)
    ) %>%
    dplyr::group_by(MGT_combo, species) %>%
    dplyr::summarize(
      days = sum(days),
      .groups = "drop"
    )

  # ---- 3. Compute species proportions ----
  div_rot <- species_days %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::mutate(
      p = days / sum(days)
    ) %>%
    dplyr::summarize(
      D = dplyr::case_when(
        hill == 0 ~ sum(p > 0),                         # richness
        hill == 1 ~ -sum(p * log(p), na.rm = TRUE),     # Shannon entropy
        TRUE      ~ -log(sum(p^2, na.rm = TRUE))        # Simpson entropy (entropy form)
      ),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      D = dplyr::if_else(is.na(D), 0, D),
      D = pmin(D, max_div)
    )

  # ---- 4. Scale to 0–100 ----
  div_final <- div_rot %>%
    dplyr::mutate(
      Diversity_raw = dplyr::case_when(
        hill == 0 ~ D / max_div,
        TRUE      ~ D / log(max_div)
      ),
      Diversity = pmin(Diversity_raw, 1) * 100
    ) %>%
    dplyr::select(MGT_combo, Diversity)

  div_final
}
