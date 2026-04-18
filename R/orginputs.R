#' Compute the Organic Inputs Sub-index (Amendments + Animals)
#'
#' Calculates the SHMI organic-inputs indicator for each management unit
#' (`MGT_combo`) by combining amendment events and animal events across the
#' rotation. Each year of the rotation is assigned a weighted organic-input
#' presence based on user-specified weights for amendments and animals. The
#' final score is scaled to 0–100.
#'
#' @param rot_bounds A data frame from \code{prepare_shmi_inputs()} containing
#'   rotation-year bounds for each management unit, with columns:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{rot_start_yr}
#'     \item \code{rot_end_yr}
#'   }
#'
#' @param amend A data frame of amendment events (from the
#'   \code{Amendment_Diversity} sheet), containing:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{SA_date} — amendment date
#'     \item \code{SA_cat} — amendment category (e.g., "Organic")
#'   }
#'   Only rows with \code{SA_cat == "Organic"} contribute to the index.
#'
#' @param animal A data frame of animal events (from the
#'   \code{Animal_Diversity} sheet), containing:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{AD_start_date} — start of animal presence
#'   }
#'
#' @param w_amend Numeric weight applied to amendment events (default 1).
#' @param w_animal Numeric weight applied to animal events (default 1).
#'
#' @details
#' The algorithm proceeds in six steps:
#'
#' \enumerate{
#'   \item \strong{Rotation-year grid}:
#'     For each \code{MGT_combo}, construct a sequence of years from
#'     \code{rot_start_yr} to \code{rot_end_yr}.
#'
#'   \item \strong{Amendment events}:
#'     Identify years with organic amendments and mark them as
#'     \code{amend_present = 1}.
#'
#'   \item \strong{Animal events}:
#'     Identify years with animal presence and mark them as
#'     \code{ani_present = 1}.
#'
#'   \item \strong{Weighted presence}:
#'     For each year of the rotation:
#'     \deqn{ \text{weighted\_input} = w_{\text{amend}} \cdot \text{amend\_present}
#'            + w_{\text{animal}} \cdot \text{ani\_present} }
#'
#'   \item \strong{Rotation-average}:
#'     Weighted inputs are summed across the rotation and divided by the number
#'     of rotation years.
#'
#'   \item \strong{Scaling}:
#'     The rotation-average is rescaled to 0–100 using
#'     \code{scales::rescale()}.
#' }
#'
#' @return A data frame with:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{events_per_year} — weighted organic-input frequency
#'     \item \code{Animals} — final SHMI organic-input score (0–100)
#'   }
#'
#' @export
compute_orginput <- function(rot_bounds,
                             amend,
                             animal,
                             w_amend = 1,
                             w_animal = 1) {

  # --- Normalize empty inputs -------------------------------------------------
  if (is.null(amend) || nrow(amend) == 0) {
    amend <- tibble::tibble(
      MGT_combo = character(),
      SA_cat    = character(),
      SA_date   = as.Date(character())
    )
  }

  if (is.null(animal) || nrow(animal) == 0) {
    animal <- tibble::tibble(
      MGT_combo     = character(),
      AD_start_date = as.Date(character())
    )
  }

  # --- 1. Build year grid -----------------------------------------------------
  rot_grid <- rot_bounds %>%
    dplyr::mutate(year = purrr::map2(rot_start_yr, rot_end_yr, seq)) %>%
    tidyr::unnest(year) %>%
    dplyr::select(MGT_combo, year)

  # --- 2. Amendment events ----------------------------------------------------
  amend_events <- amend %>%
    dplyr::filter(SA_cat == "Organic") %>%
    dplyr::mutate(year = lubridate::year(SA_date)) %>%
    dplyr::distinct(MGT_combo, year) %>%
    dplyr::mutate(amend_present = 1)

  # --- 3. Animal events -------------------------------------------------------
  ani_events <- animal %>%
    dplyr::mutate(year = lubridate::year(AD_start_date)) %>%
    dplyr::distinct(MGT_combo, year) %>%
    dplyr::mutate(ani_present = 1)

  # --- 4. Join + weighted presence -------------------------------------------
  bio_events <- rot_grid %>%
    dplyr::left_join(amend_events, by = c("MGT_combo", "year")) %>%
    dplyr::left_join(ani_events,   by = c("MGT_combo", "year")) %>%
    dplyr::mutate(
      amend_present = tidyr::replace_na(amend_present, 0),
      ani_present   = tidyr::replace_na(ani_present, 0),
      weighted_input = w_amend * amend_present +
        w_animal * ani_present
    )

  # --- 5. Rotation length -----------------------------------------------------
  rot_meta <- rot_bounds %>%
    dplyr::mutate(rot_years = rot_end_yr - rot_start_yr + 1) %>%
    dplyr::select(MGT_combo, rot_years)

  # --- 6. Weighted events per year -------------------------------------------
  animals_rate <- bio_events %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::summarise(total_weighted = sum(weighted_input), .groups = "drop") %>%
    dplyr::left_join(rot_meta, by = "MGT_combo") %>%
    dplyr::mutate(
      events_per_year = ifelse(rot_years > 0,
                               total_weighted / rot_years,
                               0)
    )

  # --- 7. Scale to 0–100 ------------------------------------------------------
  if (all(animals_rate$events_per_year == 0, na.rm = TRUE)) {
    animals_scaled <- animals_rate %>%
      dplyr::mutate(Animals = 0) %>%
      dplyr::select(MGT_combo, Animals)
  } else {
    animals_scaled <- animals_rate %>%
      dplyr::mutate(
        OrgInputs = scales::rescale(events_per_year, to = c(0, 100))
      ) %>%
      dplyr::select(MGT_combo, OrgInputs)
  }

  animals_scaled
}
