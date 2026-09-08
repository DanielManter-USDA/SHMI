#' Compute Rotation‑Scale Crop Diversity (Entropy‑Based Hill Numbers)
#'
#' Computes the SHMI diversity sub‑index for each management unit
#' (`MGT_combo`) using rotation‑scale plant‑day totals for each species.
#' Diversity reflects the distribution of crop species across the entire
#' rotation and is calculated using Hill‑number metrics (richness, Shannon,
#' or Simpson). The final diversity score is scaled to 0–100.
#'
#'
#' ## Mixture expansion
#'
#' The input `crop` table contains one row per crop species. Mixtures therefore
#' appear as single rows whose `CD_name` contains multiple species (e.g.,
#' `"A + B + C"`) or placeholder mixture names (e.g., `"8-species"`).
#'
#' Mixtures are expanded into individual species using:
#'
#' \itemize{
#'   \item splitting real mixtures on `"+"`, and
#'   \item expanding placeholder mixtures into synthetic species
#'         (`species_1`, `species_2`, …).
#' }
#'
#' Each species inherits the same `crop_start` and `crop_end` interval.
#'
#'
#' ## Rotation‑scale plant‑days
#'
#' For each species, plant‑days are computed as:
#'
#' \deqn{
#'   \text{days} = (\text{crop\_end} - \text{crop\_start}) + 1
#' }
#'
#' Plant‑days are summed across all years of the rotation. Fallow contributes
#' zero plant‑days.
#'
#'
#' ## Hill‑number diversity
#'
#' Species proportions are:
#'
#' \deqn{
#'   p_i = \frac{\text{days}_i}{\sum_j \text{days}_j}
#' }
#'
#' Diversity is computed using Hill‑number entropy metrics:
#'
#' \itemize{
#'   \item Richness: \eqn{D = \sum I(p_i > 0)}
#'   \item Shannon entropy: \eqn{D = -\sum p_i \log p_i}
#'   \item Simpson entropy (entropy form): \eqn{D = -\log \sum p_i^2}
#' }
#'
#' The diversity value is capped at \code{max_div} and scaled to 0–100:
#'
#' \itemize{
#'   \item Richness: \eqn{D / max\_div}
#'   \item Entropy metrics: \eqn{D / \log(max\_div)}
#' }
#'
#'
#' @param crop A data frame containing one row per crop species with harmonized
#'   start/end dates, including:
#'   \itemize{
#'     \item \code{MGT_combo} — management unit identifier
#'     \item \code{CD_name} — crop or mixture name
#'     \item \code{crop_start}, \code{crop_end} — daily cover interval
#'   }
#'
#' @param hill Hill‑number order. Supported values:
#'   \itemize{
#'     \item \code{0}: species richness
#'     \item \code{1}: Shannon entropy
#'     \item \code{2}: Simpson entropy (entropy form)
#'   }
#'   Default is \code{2}.
#'
#' @param max_div The theoretical maximum diversity used for scaling the
#'   final index to 0–100. For richness, this is the maximum number of species.
#'   For entropy‑based metrics, scaling uses \code{log(max_div)}.
#'
#'
#' @return A data frame with:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{Diversity} — rotation‑scale diversity score (0–100)
#'   }
#'
#' @export
compute_diversity <- function(crop,
                              hill = 2,
                              max_div = 8) {

  # ---- 1. Expand mixtures into species ----
  expand_mixtures <- function(df) {

    # ---- CASE 1: Placeholder mixtures like "8-species" ----
    placeholder <- df %>%
      filter(str_detect(CD_name, "-species")) %>%
      mutate(
        mix_n = as.integer(str_extract(CD_name, "\\d+")),
        species = map(mix_n, ~ paste0("species_", seq_len(.x)))
      ) %>%
      unnest(species) %>%
      select(MGT_combo, species, crop_start, crop_end)

    # ---- CASE 2: Real mixtures like "A + B + C" ----
    realmix <- df %>%
      filter(!str_detect(CD_name, "-species")) %>%
      mutate(
        species = str_split(CD_name, "\\s*\\+\\s*")
      ) %>%
      unnest(species) %>%
      mutate(species = str_trim(species)) %>%
      select(MGT_combo, species, crop_start, crop_end)

    bind_rows(placeholder, realmix)
  }

  expanded <- expand_mixtures(crop)%>%
    filter(tolower(species) != "fallow")

  # ---- 2. Compute plant-days per species ----
  species_days <- expanded %>%
    mutate(
      days = as.integer(crop_end - crop_start) + 1L,
      days = if_else(species %in% c("Fallow", "fallow", "none", "bare"), 0L, days)
    ) %>%
    group_by(MGT_combo, species) %>%
    summarize(
      days = sum(days, na.rm = TRUE),
      .groups = "drop"
    )

  # ---- 3. Compute species proportions ----
  div_rot <- species_days %>%
    group_by(MGT_combo) %>%
    mutate(
      p = days / sum(days)
    ) %>%
    summarize(
      D = case_when(
        hill == 0 ~ sum(p > 0),                         # richness
        hill == 1 ~ -sum(p * log(p), na.rm = TRUE),     # Shannon entropy
        TRUE      ~ -log(sum(p^2, na.rm = TRUE))        # Simpson entropy (entropy form)
      ),
      .groups = "drop"
    ) %>%
    mutate(
      D = if_else(is.na(D), 0, D),
      D = pmin(D, max_div)
    )

  # ---- 4. Scale to 0–100 ----
  div_final <- div_rot %>%
    mutate(
      Diversity_raw = case_when(
        hill == 0 ~ D / max_div,
        TRUE      ~ D / log(max_div)
      ),
      Diversity = pmin(Diversity_raw, 1) * 100
    ) %>%
    select(MGT_combo, Diversity)

  div_final
}
