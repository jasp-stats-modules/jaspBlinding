# jaspBlinding

A [JASP](https://jasp-stats.org) module for **analysis blinding** — hiding the real result from yourself while you build your analysis, so your analytical decisions can't be influenced by knowing the outcome.

## Why would I want this?

When you can see your data, decisions that should be made *before* knowing the results tend to drift toward what you want to find. A few classic examples:

- **Outlier removal** — an observation gets dropped when it hurts your hypothesis but kept when it helps.
- **Covariate selection** — you add or drop predictors until the result looks cleaner.
- **Transformations** — you try log, square root, or no transform, and settle on whichever gives the "nicest" p-value.
- **Subgroup analyses** — you explore which subgroups tell the story you expected.

Analysis blinding forces you to separate *how* you analyze the data from *what* you find. You develop and debug your entire pipeline on a blinded version of the dataset — where the true result is hidden — then run it once on the real data and report whatever comes out.

## How it works

The module creates a blinded copy of your dataset using one of two strategies:

### Scrambling

Shuffles the order of values in the selected columns. Each variable keeps its distribution (same mean, same variance, same histogram) but the pairing of values to rows is randomized — so the relationship *between* variables is broken.

Options:

- **Grouping variables** — constrain the shuffle so values only move within the same group (e.g., within the same experimental condition or country). This preserves the group structure while breaking individual-level relationships, keeping the blinded data realistic.
- **Keep rows together** — scramble the selected variables as a block: the within-row pairing *among* the selected variables is preserved, but the rows themselves are permuted.
- **By row** — for each row, shuffle the values across the selected columns horizontally. Requires compatible column types.

### Masking

Replaces categorical values with anonymous labels — for example, `treatment` becomes `masked_group_01`, `control` becomes `masked_group_02`. You can no longer see what the original categories were, but the structure (number of levels, group sizes) is preserved.

Options:

- **Same mapping across variables** — use a single shared set of anonymous labels across all selected variables, rather than an independent set per variable.
- **Prefix** — customize the label prefix (default: `masked_group_`).

Numeric columns are not affected by masking; they pass through unchanged.

## Using the module

1. Open your dataset in JASP and launch **Analysis Blinding** (under the **Blinding** menu).
2. Select the variables you want to blind.
3. Choose a method (Scrambling or Masking) and set any options.
4. Optionally set a file path under **Save blinded data** to export the blinded dataset as a CSV.
5. Load the exported CSV back into JASP and build your analysis on the blinded data.
6. Once your pipeline is finalized, swap in the real data and run the analysis once.

The results table shows a preview of the blinded data (limited to the number of rows you specify — default 50). The exported CSV always contains the full dataset.

## References

- MacCoun, R., & Perlmutter, S. (2015). Blind analysis: Hide results to seek the truth. *Nature*, 526(7572), 187–189.
- Dutilh, G., Sarafoglou, A., & Wagenmakers, E.-J. (2019). Flexible yet fair: Blinding analyses in experimental psychology. *Synthese*.

The module wraps the R package [**vazul**](https://cran.r-project.org/package=vazul) (Nagy, Kovács & Sarafoglou).

## Development

1. Fork and clone this repository.
2. Open JASP and add it as a development module (*Preferences → Advanced → Developer mode* → enable *renv* → set *libpath* → module name `jaspBlinding`; then `+` → *Install Developer Module*).
3. Rebuild with `R CMD INSTALL . --preclean --no-multiarch --with-keep.source` and refresh JASP after each rebuild.

Full design notes are in [`docs/IMPLEMENTATION-PLAN.md`](docs/IMPLEMENTATION-PLAN.md).
