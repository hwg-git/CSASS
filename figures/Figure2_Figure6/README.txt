Figures 2 and 6
==============

Run draw_figures.py with Python, NumPy, Matplotlib and Pillow. The data folder
contains the saved input records used by the script. No optimizer is executed.
PNG output dimensions and resolution metadata match the replaced manuscript
images: Figure 2 is 4351 x 2725 pixels; Figure 6 is 3900 x 1744 pixels. Both have
300 dpi metadata (299.9994 as represented by PNG pixels/metre). PDF and SVG
versions are also saved for editing. PNGs are intended for the current LaTeX
source, whose figure widths remain unchanged.

Figure 2
--------
CF2, D=10. Each algorithm is represented by the run ranked 15th after sorting
its 30 runs by IGD and then seed. These are actual lower-middle runs, not sets
pooled across runs. The exact saved final objective sets are plotted. The six
sets contain 7, 11, 11, 10, 8 and 11 points, respectively (58 total).
All panels use the same 0-4.5 limits on both axes. No normalization is applied.
Red points are the obtained solutions; black segments show the benchmark
reference front. The front requested 10,000 points and returned 6,251 points;
disconnected portions are plotted separately, without joining across gaps.

Figure 6
--------
CF7, D=10, initial N=100, FE=500, 30 seeds per setting. The left panel varies
Pmax while K=10; the right varies K while Pmax=20. The common default group
is shown in both panels, giving 270 distinct records across nine settings.
All saved IGD10000 records are finite and included. Quartiles use linear
interpolation (type 7) and match the saved group_summary table. Box centers
are medians; whiskers end at the most extreme observations within 1.5 IQR;
observations outside the whiskers are shown as open circles. Both panels use
the same 0-10 IGD limits. No normalization, smoothing, or outlier removal is
applied. The default mean is 3.20262001818 and median is 2.68450768038.

figure_manifest.json records checks, input hashes, dimensions and statistics.
original_image_metadata.json identifies the replaced source images.
