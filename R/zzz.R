utils::globalVariables(c(
  # compute_avg_annual_disturbance
  "MGT_combo", "SD_depth_cm", "SD_mixeff", "ME_times_depth", "cum_ME",
  "T_t", "T_t_norm", "T_t_annual", "T_t_inv", "InvDist",

  # compute_orginput
  "rot_start_yr", "rot_end_yr", "SA_cat", "SA_date", "AD_start_date",
  "amend_present", "ani_present", "rot_years", "weighted_input",
  "total_weighted", "events_per_year", "Animals",

  # compute_rot_diversity
  "CD_seq_num", "CD_name", "crop_present", "mix_n", "species", "D",
  "Diversity_raw",

  # compute_w.cover
  "season", "plant_days", "rot_end", "rot_start", "winter", "total_days",
  "spring", "summer", "fall", "w_sum", "w_winter_n", "prop_winter",
  "w_spring_n", "prop_spring", "w_summer_n", "prop_summer",
  "w_fall_n", "prop_fall", "Cover",

  # prepare_shmi_inputs + helpers
  "user_name", "CD_plant_date", "CD_harv_date", "CD_term_date",
  "CD_cat", "next_start", "n_seq", "SD_date", "AD_end_date",
  "start_raw", "end_raw", "CD_group", "is_first", "start_yr",
  "is_last", "end_yr", "crop_start", "crop_end", "start", "end",
  "SD_depth", "rot_end_date", "rot_start_date", "n_days",

  # build_daily_grid
  "crop_present",

  # stats functions R CMD check complains about
  "setNames"
))
