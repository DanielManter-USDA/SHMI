#' @keywords internal
#' @noRd
.compute_tl_slopes <- function(yield_df,
                               crop = NULL,
                               group_var = NULL,
                               n_boot = 1000,
                               remove_outliers = FALSE,
                               outlier_method = c("zscore", "MAD")) {

  outlier_method <- match.arg(outlier_method)

  # ---- validation ----
  required_cols <- c("MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt",
                     "SHMI", "CD_name", "yield_kg_ha", "crop_year")
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

  # ---- optional outlier removal (within each MGT_combo) ----
  if (remove_outliers) {
    yield_df <- yield_df %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::mutate(
        n_years_original = dplyr::n(),
        is_outlier = dplyr::case_when(
          outlier_method == "zscore" ~ {
            z <- (yield_kg_ha - mean(yield_kg_ha, na.rm = TRUE)) /
              stats::sd(yield_kg_ha, na.rm = TRUE)
            abs(z) > 3
          },
          outlier_method == "MAD" ~ {
            med <- stats::median(yield_kg_ha, na.rm = TRUE)
            mad <- stats::mad(yield_kg_ha, na.rm = TRUE)
            abs(yield_kg_ha - med) > 3 * mad
          }
        )
      ) %>%
      dplyr::filter(!is_outlier) %>%
      dplyr::mutate(n_years_used = dplyr::n()) %>%
      dplyr::ungroup()
  } else {
    yield_df <- yield_df %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::mutate(
        n_years_original = dplyr::n(),
        n_years_used = dplyr::n()
      ) %>%
      dplyr::ungroup()
  }

  # ---- compute mean + variance across years per MGT_combo ----
  per_combo <- yield_df %>%
    dplyr::group_by(MGT_combo, CD_name, dplyr::across(all_of(group_var))) %>%
    dplyr::summarize(
      SHMI       = mean(.data$SHMI, na.rm = TRUE),
      SHMI_min   = min(.data$SHMI, na.rm = TRUE),
      SHMI_max   = max(.data$SHMI, na.rm = TRUE),
      mean_yield = mean(.data$yield_kg_ha, na.rm = TRUE),
      var_yield  = stats::var(.data$yield_kg_ha, na.rm = TRUE),
      log_mean   = log(mean_yield),
      log_var    = log(var_yield),
      n_years_original = max(n_years_original),
      n_years_used     = max(n_years_used),
      .groups    = "drop"
    ) %>%
    dplyr::filter(is.finite(log_mean), is.finite(log_var))

  # ---- fit TL separately for each treatment group ----
  slopes <- per_combo %>%
    dplyr::group_by(CD_name, dplyr::across(all_of(group_var))) %>%
    dplyr::group_modify(~{
      df <- .x

      # need at least 2 MGT_combos to fit TL
      if (nrow(df) < 2) {
        return(tibble::tibble(
          SHMI      = mean(df$SHMI, na.rm = TRUE),
          SHMI_min  = min(df$SHMI, na.rm = TRUE),
          SHMI_max  = max(df$SHMI, na.rm = TRUE),
          slope     = NA_real_,
          slope_se  = NA_real_,
          slope_p   = NA_real_,
          slope_boot_mean = NA_real_,
          slope_boot_lwr  = NA_real_,
          slope_boot_upr  = NA_real_,
          slope_sig       = NA,
          intercept = NA_real_,
          r2        = NA_real_,
          n_combos  = nrow(df),
          n_years_original = sum(df$n_years_original),
          n_years_used     = sum(df$n_years_used)
        ))
      }

      # ---- parametric fit ----
      fit <- stats::lm(log_var ~ log_mean, data = df)
      sm  <- summary(fit)

      slope_hat <- coef(fit)[["log_mean"]]
      slope_se  <- sm$coefficients["log_mean", "Std. Error"]
      slope_p   <- sm$coefficients["log_mean", "Pr(>|t|)"]

      # ---- bootstrap slopes ----
      combos <- unique(df$MGT_combo)
      boot_slopes <- numeric(n_boot)

      for (b in seq_len(n_boot)) {
        boot_ids <- sample(combos, replace = TRUE)
        boot_df  <- df[df$MGT_combo %in% boot_ids, ]

        boot_fit <- try(stats::lm(log_var ~ log_mean, data = boot_df), silent = TRUE)
        boot_slopes[b] <- if (inherits(boot_fit, "try-error")) NA_real_ else coef(boot_fit)[["log_mean"]]
      }

      boot_slopes <- boot_slopes[is.finite(boot_slopes)]

      slope_boot_mean <- mean(boot_slopes)
      slope_boot_lwr  <- quantile(boot_slopes, 0.025)
      slope_boot_upr  <- quantile(boot_slopes, 0.975)
      slope_sig       <- !(slope_boot_lwr <= 0 & slope_boot_upr >= 0)

      tibble::tibble(
        SHMI      = mean(df$SHMI, na.rm = TRUE),
        SHMI_min  = min(df$SHMI, na.rm = TRUE),
        SHMI_max  = max(df$SHMI, na.rm = TRUE),
        slope     = slope_hat,
        slope_se  = slope_se,
        slope_p   = slope_p,
        slope_boot_mean = slope_boot_mean,
        slope_boot_lwr  = slope_boot_lwr,
        slope_boot_upr  = slope_boot_upr,
        slope_sig       = slope_sig,
        intercept = coef(fit)[["(Intercept)"]],
        r2        = sm$r.squared,
        n_combos  = nrow(df),
        n_years_original = sum(df$n_years_original),
        n_years_used     = sum(df$n_years_used)
      )
    }) %>%
    dplyr::ungroup()

  slopes
}







