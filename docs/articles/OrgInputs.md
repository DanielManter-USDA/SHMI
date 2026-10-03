# Organic Inputs Subindex

Share of Years with an Organic Amendment or Grazing Animals

## **Overview**

The Organic Inputs subindex measures how often organic matter is
returned to the soil from outside the crop: manure, compost or similar
amendments, or grazing animals. The score is the share of years with
either, from 0 to 100.

------------------------------------------------------------------------

## **1. Rotation years**

For each management unit $`i`$, the years of the evaluation window are

``` math

y \in \{\text{rot\_start\_yr}_i, \ldots, \text{rot\_end\_yr}_i\}
```

------------------------------------------------------------------------

## **2. Years with an input**

- **Amendment years**: years with at least one amendment of category
  `"Organic"` (`SA_cat`), dated by `SA_date`.
- **Animal years**: every calendar year overlapped by a grazing period,
  from `AD_start_date` to `AD_end_date`. A period without an end date
  counts in its start year only.

A year counts if it has an amendment **or** animals (or both):

``` math

\text{input}_{i,y} =
\begin{cases}
1 & \text{if year } y \text{ has an organic amendment or animals} \\
0 & \text{otherwise}
\end{cases}
```

Only presence is scored, not amounts.

------------------------------------------------------------------------

## **3. Score**

``` math

\text{OrgInput}_i = 100 \times \frac{1}{Y_i} \sum_{y} \text{input}_{i,y}
```

A unit with no organic amendments or animals scores 0.

------------------------------------------------------------------------

## **Interpretation**

- **0**: no organic amendments or grazing in any year.
- **50**: inputs in half of the years.
- **100**: an amendment or grazing every year.
- Amendments and animals count equally: a grazed but unamended system
  and an amended but ungrazed one can both reach 100. In the
  calibration, Organic Inputs carried the largest share of soil-health
  signal unique to any one sub-index.

------------------------------------------------------------------------

## **Output**

[`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)
returns one row per management unit:

| MGT_combo | OrgInput |
|-----------|----------|
| …         | 0–100    |

[`compute_orginput_components()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput_components.md)
also returns the share of years with amendments, with animals, and with
either.
