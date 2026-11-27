"""Generate synthetic subscription data for the dbt seed `raw_subscriptions`.

Usage:
    python scripts/generate_raw_subscriptions.py [n_rows] [output_path]

Standard library only; the default (50,000 rows, seed 42) reproduces the
committed seed file byte-for-byte.

Patterns produced (mirroring the hand-written sample):
  * customers with a single open or churned subscription
  * churn followed by reactivation after a gap
  * plan changes (old sub ends the day before the new one starts)
  * expansions (a second subscription overlapping an open one)
  * churned subscriptions end on a month end
"""

import random
import sys
from datetime import date, timedelta
from pathlib import Path

N_ROWS = int(sys.argv[1]) if len(sys.argv) > 1 else 50_000
OUT = Path(
    sys.argv[2]
    if len(sys.argv) > 2
    else Path(__file__).resolve().parents[1] / "seeds/raw_subscriptions.csv"
)
SEED = 42

FIRST_DAY = date(2023, 1, 1)
LAST_DAY = date(2026, 11, 30)  # latest possible start / end date

PLANS = [  # (plan_name, mrr_amount, weight)
    ("starter", "29.00", 50),
    ("professional", "79.00", 35),
    ("enterprise", "199.00", 11),
    ("enterprise", "249.00", 4),
]
SUBS_PER_CUSTOMER = ([1, 2, 3, 4], [60, 28, 9, 3])
P_CHURN = 0.40  # an (otherwise open) subscription gets an end_date
P_PLAN_CHANGE = 0.70  # follow-up on an open sub replaces it (vs. overlaps it)

# --- precomputed calendar lookups (dates as ordinals for speed) -------------
first_ord, last_ord = FIRST_DAY.toordinal(), LAST_DAY.toordinal()
date_str = {o: date.fromordinal(o).isoformat() for o in range(first_ord, last_ord + 1)}

month_starts, month_ends, month_of = [], [], {}
d = FIRST_DAY
while d <= LAST_DAY:
    nxt = date(d.year + (d.month == 12), d.month % 12 + 1, 1)
    month_starts.append(d.toordinal())
    month_ends.append((nxt - timedelta(days=1)).toordinal())
    d = nxt
for i, (s, e) in enumerate(zip(month_starts, month_ends)):
    for o in range(s, e + 1):
        month_of[o] = i
N_MONTHS = len(month_starts)


def main() -> None:
    rng = random.Random(SEED)
    plan_choices = [(p[0], p[1]) for p in PLANS]
    plan_weights = [p[2] for p in PLANS]
    width = len(str(N_ROWS))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sub_n = cust_n = 0
    buf: list[str] = []

    with OUT.open("w", newline="") as f:
        f.write("subscription_id,customer_id,plan_name,mrr_amount,start_date,end_date\n")

        while sub_n < N_ROWS:
            cust_n += 1
            cust = f"cust_{cust_n:0{width}d}"
            n_subs = rng.choices(*SUBS_PER_CUSTOMER)[0]

            # first subscription starts on any day in the window (leave room for follow-ups)
            start = rng.randint(first_ord, month_ends[N_MONTHS - 7])
            subs: list[list] = []  # [plan, mrr, start_ord, end_ord|None]

            for k in range(n_subs):
                plan, mrr = rng.choices(plan_choices, plan_weights)[0]
                sub = [plan, mrr, start, None]
                subs.append(sub)

                if k == n_subs - 1:
                    # last sub for this customer: maybe churn on a month end
                    if rng.random() < P_CHURN:
                        m = month_of[start] + rng.randint(0, 18)
                        if m < N_MONTHS:
                            sub[3] = month_ends[m]
                    break

                # decide how the next subscription follows this one
                m_start = month_of[start]
                if rng.random() < P_CHURN:
                    # churn, then reactivate after a gap
                    m_end = m_start + rng.randint(0, 12)
                    m_next = m_end + rng.randint(1, 6)
                    if m_next >= N_MONTHS:
                        if m_end < N_MONTHS:
                            sub[3] = month_ends[m_end]
                        break
                    sub[3] = month_ends[m_end]
                    start = month_starts[m_next]
                else:
                    m_next = m_start + rng.randint(1, 12)
                    if m_next >= N_MONTHS:
                        break
                    start = month_starts[m_next]
                    if rng.random() < P_PLAN_CHANGE:
                        sub[3] = start - 1  # upgrade/downgrade: old one ends the day before
                    # else: expansion, the old subscription stays open

            for plan, mrr, s, e in subs:
                if sub_n >= N_ROWS:
                    break
                sub_n += 1
                buf.append(
                    f"sub_{sub_n:0{width}d},{cust},{plan},{mrr},{date_str[s]},"
                    f"{date_str[e] if e is not None else ''}\n"
                )

            if len(buf) >= 200_000:
                f.writelines(buf)
                buf.clear()

        f.writelines(buf)

    print(f"wrote {sub_n:,} subscriptions for {cust_n:,} customers -> {OUT}")


if __name__ == "__main__":
    main()
