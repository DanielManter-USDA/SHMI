# Crop Diversity Subindex

Rotation‑Scale, Entropy‑Based Hill Diversity

## **Overview**

The SHMI Diversity subindex quantifies the diversity of crops grown
across an entire rotation, accounting for both **species identity** and
**time in the field**. Diversity is computed using **entropy‑based Hill
numbers**, which generalize richness, Shannon entropy, and Simpson
entropy into a unified framework.

The algorithm expands crop mixtures, sums plant‑days across all years of
the rotation, computes species proportions, and applies the selected
Hill‑number order (default: **Simpson entropy**, $`q = 2`$).  
The final score is scaled to **0–100** using a user‑specified
theoretical maximum (default: **max_div = 8**).

------------------------------------------------------------------------

## **1. Daily Plant‑Days**

Daily crop presence is summarized for each management unit $`i`$, crop
sequence number, crop name, and year:

``` math

\text{days}_{i,j,y} = \sum_{d} \text{crop_present}_{i,j,y,d}
```

where:

- $`i`$ = management unit  
- $`j`$ = crop or mixture  
- $`y`$ = year  
- $`d`$ = day

Records with missing crop sequence numbers are excluded.

------------------------------------------------------------------------

## **2. Mixture Expansion**

Crop mixtures are expanded into individual species:

- Mixtures like `"A + B"` become species A and B  
- Placeholder mixtures like `"3-species"` become  
  $`\text{species}_1, \text{species}_2, \text{species}_3`$

After expansion, each species inherits the plant‑days of the mixture.

Fallow is treated as zero diversity:

``` math

\text{days} = 0 \quad \text{if species = "fallow"}
```

------------------------------------------------------------------------

## **3. Rotation‑Scale Plant‑Days**

Plant‑days are summed across all years of the rotation:

``` math

\text{days}_{i,s} = \sum_{y} \text{days}_{i,s,y}
```

Species proportions are then computed:

``` math

p_{i,s} = \frac{\text{days}_{i,s}}{\sum_{s'} \text{days}_{i,s'}}
```

------------------------------------------------------------------------

## **4. Entropy‑Based Hill Diversity**

The diversity metric $`D`$ depends on the Hill‑number order $`q`$:

### **Richness (q = 0)**

``` math

D = \sum I(p_s > 0)
```

### **Shannon entropy (q = 1)**

``` math

D = -\sum p_s \log p_s
```

### **Simpson entropy (q = 2, default)**

``` math

D = -\log \left( \sum p_s^2 \right)
```

The result is capped at the theoretical maximum:

``` math

D \leftarrow \min(D, \text{max_div})
```

------------------------------------------------------------------------

## **5. Scaling to 0–100**

Richness is scaled linearly:

``` math

\text{Diversity}_{\text{raw}} = \frac{D}{\text{max_div}}
```

Entropy‑based metrics are scaled by the log of the maximum:

``` math

\text{Diversity}_{\text{raw}} = \frac{D}{\log(\text{max_div})}
```

Final score:

``` math

\text{Diversity} = 100 \times \min(\text{Diversity}_{\text{raw}}, 1)
```

------------------------------------------------------------------------

## **Interpretation**

- **0** → Monoculture rotation (or fallow‑only)  
- **100** → Maximum theoretical diversity (e.g., 8 equally represented
  species)  
- Entropy‑based metrics reward both **richness** and **evenness**  
- Mixture crops contribute proportionally to diversity

------------------------------------------------------------------------

## **Output**

A data frame with one row per management unit:

| MGT_combo | Diversity |
|-----------|-----------|
| …         | 0–100     |

------------------------------------------------------------------------
