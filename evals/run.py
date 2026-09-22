#!/usr/bin/env python3
"""Score kit configurations against the same task cases, then compare.

The agent runs are manual — you paste the prompt into a session and judge the result
against the case's pass criteria. This tool does the part humans do badly: holding the
case list steady, recording verdicts per configuration, and diffing two configurations
without letting you round the numbers in your favor.

    ./run.py cases                        # list the cases
    ./run.py score baseline               # walk the cases, record pass/fail
    ./run.py score no-caveman --area caveman
    ./run.py compare baseline no-caveman
"""
import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).parent
CASES = json.loads((HERE / "cases.json").read_text())["cases"]
RESULTS = HERE / "results.json"


def load():
    return json.loads(RESULTS.read_text()) if RESULTS.exists() else {}


def save(data):
    RESULTS.write_text(json.dumps(data, indent=2) + "\n")


def select(area):
    return [c for c in CASES if not area or c["area"] == area]


def cmd_cases(args):
    for c in select(args.area):
        print(f"{c['id']:<14} [{c['area']}]\n  prompt: {c['prompt']}\n  pass:   {c['pass']}\n")
    print(f"{len(select(args.area))} case(s)")


def cmd_score(args):
    cases = select(args.area)
    if not cases:
        sys.exit(f"no cases for area {args.area!r}")
    data = load()
    run = data.setdefault(args.config, {"scored_at": None, "verdicts": {}})
    print(f"Scoring config {args.config!r} over {len(cases)} case(s).")
    print("Verdict: [p]ass / [f]ail / [s]kip. Ctrl-C aborts without saving.\n")
    try:
        for i, c in enumerate(cases, 1):
            print(f"── {i}/{len(cases)}  {c['id']} [{c['area']}]")
            print(f"   PROMPT: {c['prompt']}")
            print(f"   PASS IF: {c['pass']}")
            prior = run["verdicts"].get(c["id"], {}).get("verdict")
            v = ""
            while v not in ("p", "f", "s"):
                v = input(f"   verdict{f' [prior: {prior}]' if prior else ''} (p/f/s): ").strip().lower()
            if v == "s":
                print()
                continue
            note = input("   note (optional): ").strip()
            run["verdicts"][c["id"]] = {"verdict": "pass" if v == "p" else "fail", "note": note}
            print()
    except (KeyboardInterrupt, EOFError):
        sys.exit("\naborted — nothing saved")
    run["scored_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    save(data)
    summarize(args.config, run)


def summarize(name, run):
    v = run["verdicts"]
    passed = sum(1 for r in v.values() if r["verdict"] == "pass")
    print(f"{name}: {passed}/{len(v)} passed ({passed / len(v):.0%})" if v else f"{name}: no verdicts")


def cmd_compare(args):
    data = load()
    for n in (args.a, args.b):
        if n not in data:
            sys.exit(f"no results for config {n!r} — run: ./run.py score {n}")
    a, b = data[args.a]["verdicts"], data[args.b]["verdicts"]
    shared = [c["id"] for c in CASES if c["id"] in a and c["id"] in b]
    if not shared:
        sys.exit("no cases scored in both configs — nothing comparable")

    regressions, fixes = [], []
    for cid in shared:
        if a[cid]["verdict"] == "pass" and b[cid]["verdict"] == "fail":
            regressions.append(cid)
        elif a[cid]["verdict"] == "fail" and b[cid]["verdict"] == "pass":
            fixes.append(cid)

    pa = sum(1 for c in shared if a[c]["verdict"] == "pass")
    pb = sum(1 for c in shared if b[c]["verdict"] == "pass")
    print(f"Comparing {len(shared)} case(s) scored in both.\n")
    print(f"  {args.a:<20} {pa}/{len(shared)}  ({pa / len(shared):.0%})")
    print(f"  {args.b:<20} {pb}/{len(shared)}  ({pb / len(shared):.0%})")
    print(f"\n  {args.b} fixes ({len(fixes)}):       {', '.join(fixes) or '—'}")
    print(f"  {args.b} regressions ({len(regressions)}): {', '.join(regressions) or '—'}")
    delta = pb - pa
    print(f"\n  net: {delta:+d} case(s)")
    if abs(delta) <= 1:
        print("  → inside noise for a 20-case harness. Not evidence. Add cases or accept 'no difference'.")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("cases", help="list cases")
    p.add_argument("--area")
    p.set_defaults(func=cmd_cases)

    p = sub.add_parser("score", help="record verdicts for one configuration")
    p.add_argument("config")
    p.add_argument("--area")
    p.set_defaults(func=cmd_score)

    p = sub.add_parser("compare", help="diff two scored configurations")
    p.add_argument("a")
    p.add_argument("b")
    p.set_defaults(func=cmd_compare)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
