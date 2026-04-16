# Plot SHMI gauge panels (Cover, Diversity, Inverse Disturbance, Animals, Overall SHMI)

Creates a five horizontal gauge-style plot for SHMI and each sub-index.
Each panel shows a 0–100 scale divided into five qualitative score bins
("very low" → "very high") with a pointer and numeric label for the SHMI
component.

## Usage

``` r
plot_shmi_gauge(shmi, MGT_combo = NULL, row = 1)
```

## Arguments

- shmi:

  A data frame containing SHMI component scores with columns: -
  \`MGT_combo\` - \`SHMI\` - \`Cover\` - \`Diversity\` - \`InvDist\` -
  \`Animals\`

- MGT_combo:

  Optional. Character value specifying which management unit to plot. If
  supplied, this overrides \`row\`.

- row:

  Integer row number to plot if \`MGT_combo\` is not provided.

## Value

A 1×5 panel of ggplot gauge charts.
