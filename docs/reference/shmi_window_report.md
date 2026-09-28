# Report records that fall outside, or straddle, the evaluation window

Run on the calibration data before and after adopting
`clip_to_rotation = TRUE` / `animal_presence = "span"` to see how many
units the definitional changes affect.

## Usage

``` r
shmi_window_report(shmi_inputs)
```

## Arguments

- shmi_inputs:

  A list returned by
  [`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).

## Value

A tibble with one row per unit and counts of affected records.
