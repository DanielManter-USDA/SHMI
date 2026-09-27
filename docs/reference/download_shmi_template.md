# Download a blank SHMI Excel template

Saves the official, blank SHMI Excel template to a file.

## Usage

``` r
download_shmi_template(path = "SHMI_template.xlsx", overwrite = TRUE)
```

## Arguments

- path:

  File path for the template. Defaults to `"SHMI_template.xlsx"` in the
  working directory.

- overwrite:

  Logical. Overwrite an existing file?

## Value

The path of the saved file, invisibly.

## Details

The template contains the sheets and columns that
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
expects: management units, crop diversity, soil disturbance, soil
amendments, and animal diversity. Fill it in, then pass the file to
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).

## See also

[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

Other SHMI helper functions:
[`download_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_example.md),
[`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.md)

## Examples

``` r
if (FALSE) { # \dontrun{
download_shmi_template("SHMI_template.xlsx")

# After filling in the template:
inputs <- prepare_shmi_inputs("SHMI_template.xlsx")
result <- build_shmi(inputs)
} # }
```
