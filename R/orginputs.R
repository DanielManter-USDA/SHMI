#' Compute the Organic Inputs Sub-index (Amendments + Animals)
#'
#' Calculates the SHMI organic-inputs indicator for each management unit
#' (`MGT_combo`) by identifying rotation years in which *any* organic input
#' occurred—either an organic amendment or an animal event. Presence is treated
#' as binary within each year: a year receives a value of 1 if at least one
#' qualifying event occurred, regardless of the number of applications or
#' events. User-specified weights determine whether amendments and/or animals
#' contribute to presence, but do not affect magnitude. The final score is the
#' percentage of rotation years with organic inputs (0–100), without min–max
#' scaling.
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
#' @param w_amend Numeric weight controlling whether organic amendments
#'   contribute to presence (default 1; values > 0 include amendments).
#'
#' @param w_animal Numeric weight controlling whether animal events contribute
#'   to presence (default 1; values > 0 include animals).
#'
#' @details
#' The algorithm proceeds in five steps:
#'
#' \enumerate{
#'
#'   \item \strong{Rotation-year grid}:
#'     Construct a sequence of rotation years for each \code{MGT_combo}.
#'
#'   \item \strong{Amendment presence}:
#'     Identify rotation years with organic amendments and mark them as
#'     \code{amend_present = 1}.
#'
#'   \item \strong{Animal presence}:
#'     Identify rotation years with animal events and mark them as
#'     \code{ani_present = 1}.
#'
#'   \item \strong{Binary organic-input presence}:
#'     A rotation year receives \code{org_present = 1} if either
#'     \code{amend_present == 1} and \code{w_amend > 0}, or
#'     \code{ani_present == 1} and \code{w_animal > 0}.
#'     Multiple events within a year do not increase the score.
#'
#'   \item \strong{Final score}:
#'     The organic-inputs indicator is returned as
#'     \deqn{ \mathrm{OrgInputs} = 100 \times \mathrm{mean}(org\_present) }
#'     representing the percentage of rotation years with organic inputs.
#'     Units with no organic inputs receive a score of 0.
#'
#' }
#'
#' @return A data frame with:
#'   \itemize{
#'     \item \code{MGT_combo}
#'     \item \code{OrgInputs} — organic-input score (0–100)
#'   }
#'
#' @export
compute_orginput <- function(rot_bounds,
                             amend,
                             animal,
                             w_amend = 1,
                             w_animal = 1) {

  # 1. Build year grid
  rot_grid <- rot_bounds %>%
    mutate(year = map2(rot_start_yr, rot_end_yr, seq)) %>%
    unnest(year) %>%
    select(MGT_combo, year)

  # 2. Amendment presence (binary)
  amend_events <- amend %>%
    filter(SA_cat == "Organic") %>%
    mutate(year = year(SA_date)) %>%
    distinct(MGT_combo, year) %>%
    mutate(amend_present = 1)

  # 3. Animal presence (binary)
  ani_events <- animal %>%
    mutate(year = year(AD_start_date)) %>%
    distinct(MGT_combo, year) %>%
    mutate(ani_present = 1)

  # 4. Weighted binary presence
  bio_events <- rot_grid %>%
    left_join(amend_events, by = c("MGT_combo", "year")) %>%
    left_join(ani_events,   by = c("MGT_combo", "year")) %>%
    mutate(
      amend_present = replace_na(amend_present, 0),
      ani_present   = replace_na(ani_present, 0),
      org_present   = if_else(
        (w_amend > 0 & amend_present == 1) |
          (w_animal > 0 & ani_present == 1),
        1, 0
      )
    )

  # 5. Frequency across rotation
  org_freq <- bio_events %>%
    group_by(MGT_combo) %>%
    summarise(
      freq = mean(org_present),
      .groups = "drop"
    )

  # 6. Final 0–100 score
  org_final <- org_freq %>%
    mutate(OrgInput = 100 * freq)

  return(org_final)
}
