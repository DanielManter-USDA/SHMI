#' @keywords internal
#' @noRd
.compute_tl_slopes <- function(yield_df,
                               crop = NULL,
                               group_var = NULL) {

  # ---- validation ----
  required_cols <- c("MGT_combo", "CD_name", "yield_kg_ha", "crop_year")
  missing <- setdiff(required_cols, names(yield_df))
  if (length(missing) > 0) {
    stop("yield_df is missing required columns: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  if (!is.null(group_var)) {
    missing_gv <- setdiff(group_var, names(yield_df))
    if (length(missing_gv) > 0) {
      stop("group_var not found in data: ",
           paste(missing_gv, collapse = ", "), call. = FALSE)
    }
  }

  # ---- crop filtering ----
  if (!is.null(crop)) {
    yield_df <- yield_df %>% dplyr::filter(CD_name == crop)
  }

  # ---- compute mean + variance across years per MGT_combo ----
  per_combo <- yield_df %>%
    dplyr::group_by(MGT_combo, CD_name, dplyr::across(all_of(group_var))) %>%
    dplyr::summarize(
      mean_yield = mean(yield_kg_ha, na.rm = TRUE),
      var_yield  = stats::var(yield_kg_ha, na.rm = TRUE),
      log_mean   = log(mean_yield),
      log_var    = log(var_yield),
      n_years    = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::filter(is.finite(log_mean), is.finite(log_var))

  # ---- fit TL separately for each treatment group ----
  slopes <- per_combo %>%
    dplyr::group_by(dplyr::across(all_of(group_var))) %>%
    dplyr::group_modify(~{
      df <- .x

      # need at least 2 MGT_combos to fit TL
      if (nrow(df) < 2) {
        return(tibble(
          slope = NA_real_,
          intercept = NA_real_,
          r2 = NA_real_,
          n_combos = nrow(df)
        ))
      }

      fit <- lm(log_var ~ log_mean, data = df)

      tibble(
        slope = coef(fit)[["log_mean"]],
        intercept = coef(fit)[["(Intercept)"]],
        r2 = summary(fit)$r.squared,
        n_combos = nrow(df)
      )
    }) %>%
    dplyr::ungroup()

  return(slopes)
}



