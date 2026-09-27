#' Compute the Organic Inputs sub-index
#'
#' Proportion of rotation years with organic amendments and with animals,
#' weighted and scaled 0-100.
#'
#' @details
#' For every calendar year from `rot_start_yr` to `rot_end_yr`, a year counts
#' as having an amendment if any amendment with `SA_cat == "Organic"` is
#' dated in that year, and as having animals if any animal period starts in
#' that year (`AD_start_date`). Only presence is scored; amounts are not
#' used. With \eqn{p} the proportion of years with each input,
#' \deqn{OrgInput = 100 \frac{w_{amend} p_{amend} + w_{animal} p_{animal}}{w_{amend} + w_{animal}}}
#'
#' A missing record means no input: a unit with no organic amendments or
#' animals scores 0.
#'
#' @param rot_bounds Rotation bounds with `MGT_combo`, `rot_start_yr`, and
#'   `rot_end_yr`.
#' @param amend Amendment events with `MGT_combo`, `SA_date`, and `SA_cat`.
#' @param animal Animal events with `MGT_combo` and `AD_start_date`.
#' @param w_amend,w_animal Weights for amendments and animals. Defaults are
#'   the official values.
#'
#' @return A data frame with `MGT_combo` and `OrgInput` (0-100), one row per
#'   unit in `rot_bounds`.
#'
#' @seealso [build_shmi()]
#'
#' @examples
#' rot_bounds <- data.frame(MGT_combo = "field_1",
#'                          rot_start_yr = 2019, rot_end_yr = 2020)
#' amend <- data.frame(MGT_combo = "field_1",
#'                     SA_date = as.Date("2019-04-01"), SA_cat = "Organic")
#' animal <- data.frame(MGT_combo = character(),
#'                      AD_start_date = as.Date(character()))
#' compute_orginput(rot_bounds, amend, animal)
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

  # 6. Weighted combination + 0-100 scaling
  org_final <- org_props %>%
    mutate(
      raw_score = w_amend * p_amend + w_animal * p_animal,
      OrgInput  = 100 * raw_score / (w_amend + w_animal)
    ) %>%
    select(MGT_combo, OrgInput)

  return(org_final)
}
