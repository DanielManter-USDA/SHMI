#' Compute the Organic Inputs Sub-index (Amendments + Animals)
#'
#' Calculates the SHMI organic-inputs indicator for each management unit
#' (`MGT_combo`) by determining the proportion of rotation years in which
#' organic amendments and animal inputs occurred. Each component is treated
#' independently:
#'
#' \itemize{
#'   \item \strong{Amendment proportion} — fraction of rotation years with at
#'         least one organic amendment event.
#'   \item \strong{Animal proportion} — fraction of rotation years with at
#'         least one animal event.
#' }
#'
#' User-specified weights (\code{w_amend}, \code{w_animal}) determine the
#' relative importance of amendments versus animals in the final score.
#' Weighted proportions are combined and rescaled to a 0–100 SHMI-compatible
#' index:
#'
#' \deqn{
#'   \mathrm{OrgInput} =
#'   100 \times
#'   \frac{
#'     w_{\mathrm{amend}} \cdot p_{\mathrm{amend}} +
#'     w_{\mathrm{animal}} \cdot p_{\mathrm{animal}}
#'   }{
#'     w_{\mathrm{amend}} + w_{\mathrm{animal}}
#'   }
#' }
#'
#' Units with no organic inputs receive a score of 0.
#'
#'
#' ## Required Inputs
#'
#' ### Rotation bounds
#' A data frame containing rotation-year boundaries:
#' \itemize{
#'   \item \code{MGT_combo}
#'   \item \code{rot_start_yr}
#'   \item \code{rot_end_yr}
#' }
#'
#' ### Amendment events
#' A data frame containing:
#' \itemize{
#'   \item \code{MGT_combo}
#'   \item \code{SA_date} — amendment date
#'   \item \code{SA_cat} — amendment category (only \code{"Organic"} counted)
#' }
#'
#' ### Animal events
#' A data frame containing:
#' \itemize{
#'   \item \code{MGT_combo}
#'   \item \code{AD_start_date} — start date of animal presence
#' }
#'
#'
#' @param rot_bounds Rotation-year boundaries for each management unit.
#' @param amend Amendment event table.
#' @param animal Animal event table.
#' @param w_amend Weight for amendment presence (default 0.6615).
#' @param w_animal Weight for animal presence (default 0.3385).
#'
#' @return A data frame with:
#' \itemize{
#'   \item \code{MGT_combo}
#'   \item \code{OrgInput} — organic-input score (0–100)
#' }
#'
#' @export
compute_orginput <- function(rot_bounds,
                             amend,
                             animal,
                             w_amend = 0.6615,
                             w_animal = 0.3385) {

  # 1. Build rotation-year grid
  rot_grid <- rot_bounds %>%
    mutate(year = purrr::map2(rot_start_yr, rot_end_yr, seq)) %>%
    tidyr::unnest(year) %>%
    select(MGT_combo, year)

  # 2. Amendment presence (binary per year)
  amend_events <- amend %>%
    filter(SA_cat == "Organic") %>%
    mutate(year = lubridate::year(SA_date)) %>%
    distinct(MGT_combo, year) %>%
    mutate(amend_present = 1)

  # 3. Animal presence (binary per year)
  ani_events <- animal %>%
    mutate(year = lubridate::year(AD_start_date)) %>%
    distinct(MGT_combo, year) %>%
    mutate(ani_present = 1)

  # 4. Join + binary presence flags
  bio_events <- rot_grid %>%
    left_join(amend_events, by = c("MGT_combo", "year")) %>%
    left_join(ani_events,   by = c("MGT_combo", "year")) %>%
    mutate(
      amend_present = tidyr::replace_na(amend_present, 0),
      ani_present   = tidyr::replace_na(ani_present, 0)
    )

  # 5. Compute proportions per rotation
  org_props <- bio_events %>%
    group_by(MGT_combo) %>%
    summarise(
      p_amend  = mean(amend_present),
      p_animal = mean(ani_present),
      .groups = "drop"
    )

  # 6. Weighted combination + 0–100 scaling
  org_final <- org_props %>%
    mutate(
      raw_score = w_amend * p_amend + w_animal * p_animal,
      OrgInput  = 100 * raw_score / (w_amend + w_animal)
    ) %>%
    select(MGT_combo, OrgInput)

  return(org_final)
}
