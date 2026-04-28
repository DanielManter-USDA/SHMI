# Plot yield stability using Taylor's Law

Creates a log-mean vs. log-variance plot of yield for each management
unit and crop, based on the output of \`prepare_shmi_yield()\`. This is
the canonical visualization of Taylor's Law and is useful for comparing
yield stability across crops and management units.

## Usage

``` r
plot_yield_stability(
  yield_df,
  crop = NULL,
  facet = TRUE,
  label = FALSE,
  add_lm = TRUE,
  point_size = 3,
  text_size = 3
)
```

## Arguments

- yield_df:

  A tibble returned by \`prepare_shmi_yield()\`, containing columns
  \`MGT_combo\`, \`crop\`, \`log_mean\`, and \`log_var\`.

- crop:

  Optional character string specifying a single crop to plot. If
  \`NULL\` (default), all crops are plotted.

- facet:

  Logical; if TRUE (default), facet by crop. Ignored when a single crop
  is selected.

- label:

  Logical; if TRUE, label points with \`MGT_combo\`. Default FALSE.

- add_lm:

  Logical; if TRUE, add a linear regression line. Default TRUE.

- point_size:

  Numeric; size of points. Default 3.

- text_size:

  Numeric; size of text labels (if \`label = TRUE\`). Default 3.

## Value

A ggplot2 object.

## Details

This version includes: \* explicit removal of non-finite log values
(e.g., zero variance) \* warnings about dropped rows \* correct
filtering when a single crop is selected \* consistent behavior between
faceted and filtered plots
