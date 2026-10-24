#!/usr/bin/env python3

import re
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.spatial.distance import pdist, squareform
from sklearn.decomposition import PCA

#input
tsv, out = sys.argv[1], sys.argv[2]
label = sys.argv[3] if len(sys.argv) > 3 else ""
df = pd.read_csv(tsv, sep="\t", index_col=0)
expr = df.drop(columns=[c for c in ["gene_name"] if c in df.columns])
logx = np.log2(expr + 1)

#declaring conditions
cond = pd.Series({s: re.sub(r"[_\-.](?:rep|replicate|r)?\d+$", "", s, flags=re.IGNORECASE)
                  for s in logx.columns})
conds = list(dict.fromkeys(cond))                       # order of appearance
palette = dict(zip(conds, sns.color_palette("colorblind" if len(conds) <= 10 else "husl", len(conds))))
colors = [palette[cond[s]] for s in logx.columns]

#for the titles, to have one main and then the smaller ones for the profiles if one is used (making the plots more distingushible when having multiple runs)
def set_titles(ax, title):
    if label:
        ax.set_title(title, pad=16)
        ax.text(0.5, 1.02, f"Profile: {label}", transform=ax.transAxes,
                ha="center", va="bottom", fontsize=7, color="dimgray")
    else:
        ax.set_title(title)

# PCA to see if samples are differentiable
fig, ax = plt.subplots(figsize=(6.5, 5.5))
x = logx.loc[logx.var(axis=1) > 0]
pca = PCA(n_components=2)
pcs = pca.fit_transform(x.T)
for name, (px, py), c in zip(x.columns, pcs, colors):
    ax.scatter(px, py, color=c, s=60)
    ax.annotate(name, (px, py), fontsize=7, xytext=(4, 4), textcoords="offset points")
ax.set_xlabel(f"PC1 ({pca.explained_variance_ratio_[0]:.0%})")
ax.set_ylabel(f"PC2 ({pca.explained_variance_ratio_[1]:.0%})")
set_titles(ax, "PCA")
ax.legend(handles=[plt.Line2D([], [], marker="o", ls="", color=c, label=k) for k, c in palette.items()],
          fontsize=7)
fig.tight_layout()
fig.savefig(out + "_pca.png", dpi=300)
plt.close(fig)
 
# sample-to-sample with the Euclidean distances
fig, ax = plt.subplots(figsize=(6.5, 5.5))
dist = pd.DataFrame(squareform(pdist(logx.T.values, metric="euclidean")),
                    index=logx.columns, columns=logx.columns)
sns.heatmap(dist, ax=ax, cmap="RdYlBu", annot=True, fmt=".1f", annot_kws={"size": 6},
            cbar_kws={"label": "Euclidean distance"}, square=True)
set_titles(ax, "Sample-to-sample distances")
ax.tick_params(labelsize=7)
fig.tight_layout()
fig.savefig(out + "_distance.png", dpi=300)
plt.close(fig)