#!/usr/bin/env python
"""
Fetch the latest GitHub-Actions build for a workflow and explain why it failed.
"""
import os, sys, requests, textwrap
from rich.console import Console
from rich.syntax import Syntax
from rich.panel import Panel

REPO      = "your-org/your-repo"            #   <-- ⇦ edit
WORKFLOW  = "docker-publish.yml"            #   <-- ⇦ edit (file name or workflow-id)
BRANCH    = "main"                          # optional branch filter

GH_TOKEN  = os.getenv("GH_TOKEN") or sys.exit("❌  Set GH_TOKEN env-var")

API       = "https://api.github.com"
HEADERS   = {"Authorization": f"Bearer {GH_TOKEN}",
             "Accept": "application/vnd.github+json"}

console = Console()

def gh(url, **params):
    r = requests.get(url, headers=HEADERS, params=params)
    r.raise_for_status()
    return r.json()

# 1) latest run --------------------------------------------
runs_url = f"{API}/repos/{REPO}/actions/workflows/{WORKFLOW}/runs"
runs = gh(runs_url, branch=BRANCH, per_page=1)
if not runs["workflow_runs"]:
    console.print(f"[bold red]No runs found for {WORKFLOW}[/]")
    sys.exit(1)

run = runs["workflow_runs"][0]
status, conclusion, run_id = run["status"], run["conclusion"], run["id"]
console.print(f"Latest run: [cyan]{run_id}[/] status=[yellow]{status}[/] "
              f"conclusion=[yellow]{conclusion}[/]")

if conclusion != "failure":
    console.print("[green]✅  Latest run did not fail.[/]")
    sys.exit(0)

# 2) failed jobs (matrix) -----------------------------------
jobs = gh(f"{API}/repos/{REPO}/actions/runs/{run_id}/jobs")["jobs"]
failed_jobs = [j for j in jobs if j["conclusion"] == "failure"]

for job in failed_jobs:
    console.rule(f"[bold red]❌ Job: {job['name']}[/]")
    # 3) raw logs
    log_url = f"{API}/repos/{REPO}/actions/jobs/{job['id']}/logs"
    log     = requests.get(log_url, headers=HEADERS).text

    # truncate to last ~150 lines
    tail = "\n".join(log.splitlines()[-150:])
    console.print(Panel.fit(Syntax(tail, "bash", theme="ansi_dark"),
                            title="tail-150.log", border_style="grey50"))

    # 4) naive explanation (look for ERROR lines)
    errors = [l for l in tail.splitlines()
              if any(tag in l for tag in ("ERROR", "Error", "error", "No matching"))]
    bullets = "\n".join(f"• {e.strip()}" for e in errors[:10] or ["(no obvious error msg)"])
    console.print(Panel(textwrap.dedent(bullets), title="Likely cause", style="bold red"))
