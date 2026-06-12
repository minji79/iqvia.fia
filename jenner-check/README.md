# Jenner compatibility bundles

This directory was added by a pull request from the
[Jenner](https://jenneranalytics.com) project. Each `tNNN_*` subdirectory
is a small, self-contained SAS program adapted from code in this
repository. Running one sends the program to the Jenner API and shows you
the log, listing, datasets, and any graphics it produced — so you can see
your own analysis patterns run on Jenner without touching your real data.

## What's in here

```
jenner-check/
├── README.md          # this file
├── run_jenner.sh      # mac / Linux runner (curl)
├── run_jenner.bat     # Windows runner (curl.exe, single-file mode)
├── run_jenner.sas     # run from Base SAS (PROC HTTP; SAS 9.4 M5+)
└── tNNN_<slug>/
    ├── script.sas     # the program under test (adapted from your code)
    ├── autoexec.sas   # options + the small sample data the script reads
    ├── expected.json  # the stable fields captured from a passing run
    ├── expected/      # a snapshot of that run: log.txt, output.txt, files.md
    └── meta.json      # which file it came from + what was adapted
```

Each bundle runs against a tiny inline sample built in `autoexec.sas`, so
nothing here reaches the IQVIA FIA extracts on your cluster — the bundles
are entirely standalone.

## How to run it

From inside `jenner-check/` on mac or Linux:

```bash
./run_jenner.sh --all          # run every bundle, print a pass/fail summary
./run_jenner.sh t001_glp1_area_plot   # run just one
```

From Base SAS (any platform with SAS 9.4 M5+):

```sas
%include 'run_jenner.sas';
%jenner_check_all();           /* walk every bundle, summarize */
```

Or, if you just want to see one run without the helpers, POST a single
file with curl:

```bash
curl -sS -X POST https://api.jenneranalytics.com/v1/run \
  -F "script=@t001_glp1_area_plot/script.sas" \
  -F "deterministic=1" -F "timeout=60"
```

The runner concatenates `autoexec.sas` and `script.sas`, submits them, and
compares the response against the bundle's `expected.json`.

## Optional: Jenner Compatible badge

If you'd like to show this on your README, it's entirely optional:

```markdown
[![Jenner Compatible](https://jenneranalytics.com/badges/jenner-compatible.svg)](https://jenneranalytics.com)
```

## Don't want future PRs from us?

Reply to this PR with `no-more-prs` (case-insensitive) anywhere in a
comment, or open an issue titled `jenner-check: opt out`, and we'll stop.

## About this project

Jenner is a SAS-compatible engine you can reach over an API, in a
collaborative workspace, or as a native app. Full context is at
[jenneranalytics.com](https://jenneranalytics.com).
