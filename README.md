# Bencher Examples

[Bencher](https://bencher.dev) is a suite of [continuous benchmarking](https://bencher.dev/docs/explanation/continuous-benchmarking/) tools.
The `.github` directory contains example workflows from [how to use Bencher in GitHub Actions](https://bencher.dev/docs/how-to/github-actions/).

- [Benchmark pushes to `main` branch](.github/workflows/benchmarks.yml)
- [Benchmark pull requests from branches](.github/workflows/pr_benchmarks.yml)
- [Benchmark fork pull requests with Required Reviewers](.github/workflows/pr_target_benchmarks.yml)
- Benchmark fork pull requests and upload from default branch
  - [Run benchmarks and cache](.github/workflows/pr_and_cache_benchmarks.yml)
  - [Track benchmarks](.github/workflows/pr_track_benchmarks.yml)
