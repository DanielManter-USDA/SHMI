# Download a blank SHMI Excel template

Saves the official SHMI Excel template to a user-specified file path.
The template contains the required sheets and column names needed to
enter management data for SHMI computation.

## Usage

``` r
download_shmi_template(path = "SHMI_template.xlsx", overwrite = TRUE)
```

## Arguments

- path:

  Full file path where the template should be saved. Defaults to
  \`"SHMI_template.xlsx"\` in the current working directory.

- overwrite:

  Logical. Overwrite the file if it already exists?

## Value

The path to the saved file (invisibly).

## Details

This function copies the internal SHMI template (stored in
\`inst/extdata/\`) to a local file path. The template is intentionally
blank and must be filled in by the user before running
\[\`prepare_shmi_inputs()\`\]. It includes the required structure for
crop diversity, disturbance, organic inputs, and management units.

## See also

\[download_shmi_example()\], \[get_shmi_example()\],
\[prepare_shmi_inputs()\], \[build_shmi()\]

Other SHMI helper functions:
[`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Save template to working directory
download_shmi_template("SHMI_template.xlsx")

# Save to a specific folder
download_shmi_template(path = "~/Desktop/SHMI_template.xlsx")

# After filling in the Excel file:
inputs <- prepare_shmi_inputs("my_filled_template.xlsx")
result <- build_shmi(inputs)
} # }
```
