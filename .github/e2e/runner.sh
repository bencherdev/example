#!/usr/bin/env bash
# Host a dev runner for the scenarios' Jobs, after every submit job has finished:
#
#   runner.sh serve    serve `test-spec` as `test-runner` for 10 minutes
#   runner.sh cancel   serve `no-sandbox-spec` as `test-runner-no-sandbox`, and kill the runner
#                      once the cancel scenario's Job is running, so the server cancels that Job
#                      when its timeout and grace period pass
set -euo pipefail

now() {
	date -u +%Y-%m-%dT%H:%M:%SZ
}

rotate_key() {
	local key
	key="$(bencher runner key --token "$BENCHER_ADMIN_API_TOKEN" "$1" | jq -r '.key // empty')"
	if [ -z "$key" ]; then
		echo "::error::Rotating the key of $1 returned no key"
		return 1
	fi
	echo "::add-mask::$key"
	export BENCHER_RUNNER_KEY="$key"
}

serve() {
	rotate_key test-runner
	echo "Runner up at $(now)"
	local status=0
	timeout --kill-after 60s 10m runner up --runner test-runner --no-auto-update || status=$?
	# `timeout` exits 124 after it stops the runner, or 137 if the runner needed a SIGKILL.
	if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
		echo "Runner down at $(now)"
		return 0
	fi
	return "$status"
}

cancel() {
	rotate_key test-runner-no-sandbox
	local jobs count job
	jobs="$(bencher job list "$PAID_PROJECT" --status pending --sort created --direction desc --per-page 255)"
	count="$(jq '[.[] | select(.spec.slug == "no-sandbox-spec")] | length' <<< "$jobs")"
	job="$(jq -r '[.[] | select(.spec.slug == "no-sandbox-spec")][0].uuid // empty' <<< "$jobs")"
	if [ -z "$job" ]; then
		echo "::error::There is no pending no-sandbox-spec Job in $PAID_PROJECT to cancel"
		return 1
	fi
	if [ "$count" -gt 1 ]; then
		echo "::warning::$count no-sandbox-spec Jobs are pending in $PAID_PROJECT, and the runner may run older ones before $job"
	fi

	local log="$RUNNER_TEMP/runner.log"
	echo "Runner up at $(now), waiting for Job $job to start"
	runner up --runner test-runner-no-sandbox --danger-allow-no-sandbox --no-auto-update > "$log" 2>&1 &
	local pid=$!
	local deadline=$((SECONDS + 900))
	until grep -qF "Starting iteration 1/1 for job $job" "$log"; do
		if ! kill -0 "$pid" 2> /dev/null; then
			cat "$log"
			echo "::error::The runner exited before Job $job started"
			return 1
		fi
		if [ "$SECONDS" -ge "$deadline" ]; then
			kill -KILL "$pid"
			cat "$log"
			echo "::error::Job $job did not start within 15 minutes"
			return 1
		fi
		sleep 1
	done
	# A SIGTERM would let the runner finish the Job first, so the runner gets no chance to.
	kill -KILL "$pid"
	wait "$pid" || true
	cat "$log"
	echo "Killed the runner at $(now) while Job $job was running"
}

case "${1:-}" in
serve) serve ;;
cancel) cancel ;;
*)
	echo "usage: runner.sh serve | cancel" >&2
	exit 2
	;;
esac
