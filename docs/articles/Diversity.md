# Crop Diversity Subindex

Plant Species Richness over 4-Year Spans, with a Grazing Credit

## **Overview**

The Diversity subindex counts how many plant species grow in a field
over each 4-year span of the record, and averages the counts. Crop
rotation, cover crops and seed mixes all raise it. Grazing animals raise
it further. The score runs from 0 to 100.

------------------------------------------------------------------------

## **1. Species**

Each distinct crop name is a species (extra whitespace ignored). Before
counting:

- placeholder mixtures such as `"8-species"`, `"8 spp"` or
  `"8-species mix"` count as that many species;
- names joined by `"+"` (`"A + B"`) are split into separate species;
- rows named `"fallow"`, `"none"` or `"bare"` are not plants.

------------------------------------------------------------------------

## **2. Richness per span**

For management unit $`i`$, each 4-year span of the evaluation window,
starting in each calendar year in turn, has a richness: the number of
species present on any day of it. A record of 4 years or fewer is one
span. The richness $`\bar{R}_i`$ is the average over spans.

`compute_diversity(window = 1)` counts species per calendar year instead
(the SHMI 1.0 definition); `options(SHMI.diversity_window = )` changes
the window for a session.

------------------------------------------------------------------------

## **3. Scaling to 0–100**

``` math

D_{plants,i} = 100 \times \min\left(\frac{\bar{R}_i - 1}{8 - 1},\; 1\right)
```

One species scores 0, and eight or more score 100. A span without any
plants counts as zero species, so a bare fallow scores 0.

------------------------------------------------------------------------

## **4. Grazing credit**

Animals grazing in a share $`p_{animal}`$ of years close a quarter of
that share of the gap to 100:

``` math

\text{Diversity}_i = D_{plants,i} + 0.25\,p_{animal,i}\,(100 - D_{plants,i})
```

Every calendar year overlapped by a grazing period counts. Grazing every
year raises a corn–soybean rotation from 14 to 36, and a diverse pasture
already at 80 to 85. The credit cannot push Diversity past 100.

------------------------------------------------------------------------

## **Interpretation**

- **0**: one species, such as continuous corn.
- **14**: two species, such as a corn–soybean rotation.
- **29**: three, such as corn–soybean–wheat; **43** with a rye cover
  crop added.
- **100**: eight or more species, such as a diverse cover-crop mix or a
  species-rich perennial stand.

------------------------------------------------------------------------

## **Output**

[`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md)
returns plant-only Diversity, one row per management unit:

| MGT_combo | Diversity | Richness                |
|-----------|-----------|-------------------------|
| …         | 0–100     | species per 4-year span |

[`shmi_components()`](https://danielmanter-usda.github.io/SHMI/reference/shmi_components.md)
and
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)
return `Diversity` with the grazing credit, `Diversity_plants` without
it, and `p_animal`.
