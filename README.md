# Bencher Examples

[Bencher](https://bencher.dev) is a suite of [continuous benchmarking](https://bencher.dev/docs/explanation/continuous-benchmarking/) tools.
The `.github` directory contains example workflows from [how to use Bencher in GitHub Actions](https://bencher.dev/docs/how-to/github-actions/).

- [Benchmark pushes to `main` branch](.github/workflows/base_benchmarks.yml)
- Benchmark pull requests
  - [Run and track benchmarks](.github/workflows/pr_benchmarks.yml)
  - [Archive branches for closed pull requests](.github/workflows/pr_benchmarks_closed.yml)
- Benchmark pull requests from forks
  - [Run benchmarks](.github/workflows/fork_pr_benchmarks_run.yml)
  - [Track benchmarks](.github/workflows/fork_pr_benchmarks_track.yml)
  - [Archive branches for closed pull requests from forks](.github/workflows/fork_pr_benchmarks_closed.yml)
