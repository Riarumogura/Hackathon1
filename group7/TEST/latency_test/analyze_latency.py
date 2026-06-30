"""
MA(BPM Tick送信)→SP(ピアノ再生)の遅延を計測・集計するスクリプト。

使い方:
  1. group7/TEST/MasterProcessing/ で生成された latency_log_master_ticks.csv と
     group7/TEST/SlaveProcessing/SP_Piano/ で生成された latency_log_piano.csv を
     このファイルと同じフォルダ（group7/TEST/latency_test/）にコピーする。
  2. python3 analyze_latency.py を実行する。

出力:
  - 標準出力に件数・平均・中央値・標準偏差・最小・最大（ms）を表示
  - latency_joined.csv に tick_id ごとの明細（MA送信ログ受信時刻・SP再生時刻・delay_ms）を書き出す

注意（系統誤差）:
  MA側の "[BPM Tick] Sent: ..." 行自体のシリアル送信時間（9600bpsで約20〜30ms）が
  delay_msに上乗せされている。行長はBPMが3桁固定・tick番号が1〜3桁可変なので
  この上乗せ分は±2ms程度変動する。絶対値を厳密に補正したい場合は
  「行の文字数 × 10 / 9600」秒を delay_ms から差し引くこと（本スクリプトでは未補正）。
"""

import csv
import statistics
from pathlib import Path

MASTER_LOG = Path(__file__).parent / "latency_log_master_ticks.csv"
PIANO_LOG = Path(__file__).parent / "latency_log_piano.csv"
JOINED_OUT = Path(__file__).parent / "latency_joined.csv"


def load_master_ticks(path):
    ticks = {}
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            ticks[int(row["tick_id"])] = int(row["send_log_recv_time_ms"])
    return ticks


def load_piano_events(path):
    events = []
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            if row["played"] != "1":
                continue
            events.append(
                {
                    "tick_id": int(row["tick_id"]),
                    "recv_time_ms": int(row["recv_time_ms"]),
                    "midi": row["midi"],
                    "freq_hz": row["freq_hz"],
                    "dur_sec": row["dur_sec"],
                }
            )
    return events


def main():
    if not MASTER_LOG.exists() or not PIANO_LOG.exists():
        raise SystemExit(
            f"必要なログが見つかりません。{MASTER_LOG.name} と {PIANO_LOG.name} を"
            f"このフォルダ（{MASTER_LOG.parent}）にコピーしてください。"
        )

    master_ticks = load_master_ticks(MASTER_LOG)
    piano_events = load_piano_events(PIANO_LOG)

    rows = []
    delays = []
    unmatched = []
    for ev in piano_events:
        send_t = master_ticks.get(ev["tick_id"])
        if send_t is None:
            unmatched.append(ev["tick_id"])
            continue
        delay_ms = ev["recv_time_ms"] - send_t
        delays.append(delay_ms)
        rows.append(
            {
                "tick_id": ev["tick_id"],
                "ma_send_log_recv_time_ms": send_t,
                "sp_recv_time_ms": ev["recv_time_ms"],
                "delay_ms": delay_ms,
                "midi": ev["midi"],
                "freq_hz": ev["freq_hz"],
                "dur_sec": ev["dur_sec"],
            }
        )

    rows.sort(key=lambda r: r["tick_id"])
    with open(JOINED_OUT, "w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "tick_id",
                "ma_send_log_recv_time_ms",
                "sp_recv_time_ms",
                "delay_ms",
                "midi",
                "freq_hz",
                "dur_sec",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    if not delays:
        print("マッチした音発生イベントがありませんでした。")
        return

    print(f"音発生イベント数: {len(delays)}")
    print(f"対応するTickが見つからなかった件数: {len(unmatched)}")
    print(f"平均delay: {statistics.mean(delays):.1f} ms")
    print(f"中央値delay: {statistics.median(delays):.1f} ms")
    if len(delays) > 1:
        print(f"標準偏差: {statistics.stdev(delays):.1f} ms")
    print(f"最小delay: {min(delays)} ms")
    print(f"最大delay: {max(delays)} ms")
    print(f"明細を {JOINED_OUT} に書き出しました。")


if __name__ == "__main__":
    main()
