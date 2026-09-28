# SHMI 1.2.0

## Scoring changes (national scores change; re-run `prepare_shmi_inputs()`)

* **Calendar-year rotation window.** `prepare_shmi_inputs()` now sets the
  rotation window from 1 January of the first year with a record to
  31 December of the last (`rotation_window = "calendar"`), or exactly to
  the override / sample dates. SHMI <= 1.1.0 used the first and last
  recorded events, which dropped the bare periods before the first planting
  or tillage and after the last harvest from the Cover denominator. That
  made the denominator depend on management and inflated Cover, most in
  winter and spring. `rotation_window = "events"` reproduces the old
  behaviour. All four sub-indices now share one window.

* **Animal presence spans the grazing period.** `compute_orginput()` gains
  `animal_presence`. The official value is now `"span"`: every calendar
  year overlapped by `AD_start_date`-`AD_end_date` counts. SHMI <= 1.1.0
  (`"start"`) counted a multi-year grazing period only in its first year.

* **Crop episodes are clipped to the rotation window** before Cover and
  Diversity are computed (`clip_crop_to_rotation()`, setting
  `clip_to_rotation`). Inputs from `prepare_shmi_inputs()` already satisfy
  this; the change protects hand-built inputs.

* **Official weights are provisional.** The season, amendment/animal and
  pillar weights shown for 1.2.0 are the 1.1.0 values, which were
  calibrated under the old definitions. They will be re-estimated under the
  1.2.0 definitions before release.

* **Intensive-tillage end for crops without an end date.** A crop with no
  harvest or termination record now ends on the first day after planting
  with intensive tillage (the day's passes sum to STIR >= 80, or EPA daily
  tillage intensity >= 0.252, the conventional-tillage class boundary)
  whenever that comes before its imputed end (next planting or end of the
  window). New argument `tillage_end` in `prepare_shmi_inputs()`
  (`"auto"`, `"STIR"`, `"EPA"`, `"none"`); logged as `end_intensive_tillage`.

## New functions

* `compute_cover_components()`, `compute_orginput_components()` and
  `compute_shmi_components()` return the seasonal cover proportions and the
  amendment/animal year proportions. Cover and OrgInput are weighted means
  of these, so weights can be evaluated or estimated without recomputing
  the sub-indices. `compute_cover()` and `compute_orginput()` are now
  implemented on top of them (one implementation for scoring and
  calibration).
* `clip_crop_to_rotation()`.
* `shmi_window_report()` lists units affected by the window and animal
  definitions.

## Bug fixes and robustness

* `build_shmi()` stops on unknown setting names (a misspelled weight used to
  be ignored silently) and on invalid values (e.g. `hill = 3`,
  `max_div <= 1`, negative weights, all-zero weight groups).
* `build_shmi()` requires `shmi_inputs$mgt` and stops on duplicated
  `MGT_combo`; results record `rotation_window`.
* `compute_cover()` and `compute_orginput()` reject negative weights; zero
  weights are allowed.
* `compute_cover()` treats fallow names case- and whitespace-insensitively,
  as `compute_diversity()` already did.
* `compute_disturbance()` caps annual TI at 1 explicitly (EPA sums could
  exceed 1 and relied on a nearest-midpoint fallback) and classifies years
  with a vectorized `findInterval()`. Class assignments are unchanged.
* `prepare_shmi_inputs()`:
  * animal periods without an end date are no longer dropped by
    `start_date_override`;
  * `end_at_sample_date = TRUE` keeps (and reports) units with no
    `MGT_sample_date` instead of silently removing all their records, and
    parses the date with the package date parser;
  * stops if `start_date_override` is after `end_date_override`, and notes
    overrides not on calendar-year boundaries;
  * checks that every crop episode lies inside its rotation window.

* New data checks in `prepare_shmi_inputs()` (no score change):
  `end_window_light_tillage` (crop runs to the end of the window although
  lighter tillage is recorded after planting), `start_imputed_candidates`
  (imputed planting date, with the disturbance dates that may be the
  planting), and `no_crop_records` (unit scored as bare soil because it has
  no crop records).
* The `end_imputed_after_disturbance` check was removed: it mostly flagged
  in-season cultivation, and crops ended by intensive tillage are now
  handled by the scoring rule above.

## Tests

* Frozen copies of the 1.1.0 `compute_cover()`, `compute_orginput()` and
  `compute_disturbance()` are kept in `tests/testthat/helper-legacy-v110.R`;
  the refactored functions must reproduce them exactly in legacy mode.
