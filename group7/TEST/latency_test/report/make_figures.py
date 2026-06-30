import csv
import statistics
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

plt.rcParams["font.size"] = 11
plt.rcParams["font.family"] = "Hiragino Sans"
plt.rcParams["axes.unicode_minus"] = False

DATA_DIR = Path(__file__).parent.parent
OUT_DIR = Path(__file__).parent

CONDITIONS = [
    ("9600bps_BPM120", "latency_joined_bpm120.csv", 125.0),
    ("9600bps_BPM180", "latency_joined_bpm180.csv", 83.3),
    ("115200bps_BPM120", "latency_joined_bpm120_115200baud.csv", 125.0),
    ("115200bps_BPM180", "latency_joined_bpm180_115200baud.csv", 83.3),
]


def load_delays(filename):
    delays = []
    tick_ids = []
    with open(DATA_DIR / filename, newline="") as f:
        for row in csv.DictReader(f):
            delays.append(int(row["delay_ms"]))
            tick_ids.append(int(row["tick_id"]))
    return tick_ids, delays


stats = {}
all_data = {}
for label, filename, tick_interval in CONDITIONS:
    tick_ids, delays = load_delays(filename)
    all_data[label] = (tick_ids, delays, tick_interval)
    stats[label] = {
        "mean": statistics.mean(delays),
        "stdev": statistics.stdev(delays),
        "median": statistics.median(delays),
        "min": min(delays),
        "max": max(delays),
        "tick_interval": tick_interval,
    }

# ------------------------------------------------------------
# Figure 1: bar chart, mean delay +/- stdev for the 4 conditions
# ------------------------------------------------------------
labels = [c[0] for c in CONDITIONS]
means = [stats[l]["mean"] for l in labels]
stdevs = [stats[l]["stdev"] for l in labels]
display_labels = ["9600bps\nBPM120", "9600bps\nBPM180", "115200bps\nBPM120", "115200bps\nBPM180"]

fig, ax = plt.subplots(figsize=(6.5, 4.2))
colors = ["#4C72B0", "#4C72B0", "#DD8452", "#DD8452"]
bars = ax.bar(display_labels, means, yerr=stdevs, capsize=6, color=colors, alpha=0.85)
ax.axhline(0, color="black", linewidth=0.8)
ax.set_ylabel("平均 delay [ms] (誤差棒 = 標準偏差)")
ax.set_title("MA Tick送信 → SP再生 遅延（条件別比較）")
for bar, m in zip(bars, means):
    ax.text(bar.get_x() + bar.get_width() / 2, m + (1.5 if m >= 0 else -2.5),
            f"{m:.1f}", ha="center", fontsize=10)
fig.tight_layout()
fig.savefig(OUT_DIR / "fig_bar_comparison.png", dpi=200)
plt.close(fig)

# ------------------------------------------------------------
# Figure 2: histogram, 9600bps BPM120 vs 115200bps BPM120
# ------------------------------------------------------------
fig, ax = plt.subplots(figsize=(6.5, 4.2))
_, d_9600, _ = all_data["9600bps_BPM120"]
_, d_115200, _ = all_data["115200bps_BPM120"]
bins = range(-6, 18)
ax.hist(d_9600, bins=bins, alpha=0.6, label="9600bps", color="#4C72B0")
ax.hist(d_115200, bins=bins, alpha=0.6, label="115200bps", color="#DD8452")
ax.set_xlabel("delay [ms]")
ax.set_ylabel("件数")
ax.set_title("delay分布（BPM=120, ボーレート別）")
ax.legend()
fig.tight_layout()
fig.savefig(OUT_DIR / "fig_histogram.png", dpi=200)
plt.close(fig)

# ------------------------------------------------------------
# Figure 3: delay vs tick_id (time-series stability), BPM120
# ------------------------------------------------------------
fig, ax = plt.subplots(figsize=(6.5, 4.2))
t_9600, d_9600, _ = all_data["9600bps_BPM120"]
t_115200, d_115200, _ = all_data["115200bps_BPM120"]
ax.scatter(t_9600, d_9600, s=10, alpha=0.6, label="9600bps", color="#4C72B0")
ax.scatter(t_115200, d_115200, s=10, alpha=0.6, label="115200bps", color="#DD8452")
ax.axhline(0, color="black", linewidth=0.8)
ax.set_xlabel("Tick番号")
ax.set_ylabel("delay [ms]")
ax.set_title("delayの時間的安定性（BPM=120, ボーレート別）")
ax.legend()
fig.tight_layout()
fig.savefig(OUT_DIR / "fig_timeseries.png", dpi=200)
plt.close(fig)

# ------------------------------------------------------------
# Figure 4: relative ratio to tick interval, bar chart
# ------------------------------------------------------------
fig, ax = plt.subplots(figsize=(6.5, 4.2))
ratios = [stats[l]["mean"] / stats[l]["tick_interval"] * 100 for l in labels]
bars = ax.bar(display_labels, ratios, color=colors, alpha=0.85)
ax.axhline(0, color="black", linewidth=0.8)
ax.set_ylabel("平均delay / Tick間隔 [%]")
ax.set_title("Tick間隔に対する相対遅延比率")
for bar, r in zip(bars, ratios):
    ax.text(bar.get_x() + bar.get_width() / 2, r + (0.3 if r >= 0 else -0.6),
            f"{r:.1f}%", ha="center", fontsize=10)
fig.tight_layout()
fig.savefig(OUT_DIR / "fig_ratio.png", dpi=200)
plt.close(fig)

# ------------------------------------------------------------
# Write stats as a LaTeX-includable table fragment (for reference) + print
# ------------------------------------------------------------
with open(OUT_DIR / "stats_summary.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["condition", "mean", "median", "stdev", "min", "max", "tick_interval_ms", "ratio_percent"])
    for l in labels:
        s = stats[l]
        writer.writerow([l, f"{s['mean']:.1f}", f"{s['median']:.1f}", f"{s['stdev']:.1f}",
                          s["min"], s["max"], s["tick_interval"], f"{s['mean']/s['tick_interval']*100:.1f}"])

for l in labels:
    print(l, stats[l])

print("Figures written to", OUT_DIR)
