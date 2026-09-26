#!/usr/bin/env bash
# Run a detached `bencher run` and check its raw output, before GitHub masks the log:
#
#   submit.sh <scenario> bencher run ...
#
# REDACTED lists the environment variables whose values must never be printed,
# and EXPECT_SKIPPED says whether the server should skip the callback for want of a plan.
set -euo pipefail

scenario="$1"
shift

out="$RUNNER_TEMP/bencher-run.stdout"
err="$RUNNER_TEMP/bencher-run.stderr"
status=0
"$@" > "$out" 2> "$err" || status=$?
cat "$out"
cat "$err" >&2

failed=0
fail() {
	echo "::error title=$scenario::$1"
	failed=1
}

for name in $REDACTED; do
	value="${!name:-}"
	if [ -z "$value" ]; then
		fail "$name is empty, so there is nothing to check its redaction against"
	elif grep -qF -- "$value" "$out" "$err"; then
		fail "the CLI printed the raw value of $name"
	fi
done
if ! grep -qF '"authorization": "************"' "$out"; then
	fail "the Bencher New Report echo does not show the CLI's mask for the authorization header"
fi
if grep -qF '/dispatches' "$out" "$err"; then
	fail "the CLI printed the callback URL past its origin"
fi

skipped=false
if grep -qxF 'callback skipped: requires a Bencher Plus plan' "$err"; then
	skipped=true
fi
if [ "$skipped" != "$EXPECT_SKIPPED" ]; then
	fail "expected a skipped callback to be $EXPECT_SKIPPED, but it was $skipped"
fi

job="$(sed -n 's/^Remote job submitted successfully: //p' "$err" | head -n 1)"
check="$(grep -oE '"check": [0-9]+' "$out" | head -n 1 | grep -oE '[0-9]+' || true)"
if [ -z "$job" ]; then
	fail "the CLI did not print the submitted Job"
fi
echo "::notice title=$scenario::Job ${job:-none}, check run ${check:-none}, commit $HEAD_SHA"
{
	echo "| Scenario | Job | Check run | Commit |"
	echo "| --- | --- | --- | --- |"
	echo "| $scenario | ${job:-none} | ${check:-none} | $HEAD_SHA |"
} >> "$GITHUB_STEP_SUMMARY"

if [ "$status" -ne 0 ]; then
	exit "$status"
fi
exit "$failed"
