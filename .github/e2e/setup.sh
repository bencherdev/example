#!/usr/bin/env bash
# Make sure dev has what the scenarios need. Every step is idempotent,
# so it runs as is after every deploy wipes the dev database.
set -euo pipefail

ensure_project() {
	local organization="$1" slug="$2" name="$3"
	if bencher project view "$slug" > /dev/null 2>&1; then
		echo "Project $slug exists"
	else
		bencher project create "$organization" --name "$name" --slug "$slug" > /dev/null
		echo "Created project $slug in $organization"
	fi
}

# The seed recreates the paid organization on every deploy, and only a plan makes it paid.
bencher organization view "$PAID_ORGANIZATION" > /dev/null
if bencher plan view --attempts 3 "$PAID_ORGANIZATION" > /dev/null 2>&1; then
	echo "Organization $PAID_ORGANIZATION has a plan"
elif [ -z "${BENCHER_DEV_SUBSCRIPTION:-}" ]; then
	echo "::warning::The BENCHER_DEV_SUBSCRIPTION repository variable is not set, so $PAID_ORGANIZATION has no plan and every callback is skipped"
else
	# The level only matters to a licensed plan: a metered plan reads its level from the subscription.
	bencher plan create "$PAID_ORGANIZATION" \
		--checkout "$BENCHER_DEV_SUBSCRIPTION" \
		--level "${BENCHER_DEV_PLAN_LEVEL:-team}" \
		--skip-remote > /dev/null
	echo "Attached the subscription to $PAID_ORGANIZATION"
fi
ensure_project "$PAID_ORGANIZATION" "$PAID_PROJECT" "Callback E2E"

if bencher organization view "$FREE_ORGANIZATION" > /dev/null 2>&1; then
	echo "Organization $FREE_ORGANIZATION exists"
else
	bencher organization create --name "Callback E2E Free" --slug "$FREE_ORGANIZATION" > /dev/null
	echo "Created organization $FREE_ORGANIZATION"
fi
if bencher plan view --attempts 3 "$FREE_ORGANIZATION" > /dev/null 2>&1; then
	echo "::error::Organization $FREE_ORGANIZATION has a plan, but the no plan scenario needs one without"
	exit 1
fi
ensure_project "$FREE_ORGANIZATION" "$FREE_PROJECT" "Callback E2E Free"

docker build --tag e2e-bench "$(dirname "$0")/image"
printf '%s' "$BENCHER_API_TOKEN" | docker login "$BENCHER_REGISTRY" --username "$DEV_USER_EMAIL" --password-stdin
for project in "$PAID_PROJECT" "$FREE_PROJECT"; do
	docker tag e2e-bench "$BENCHER_REGISTRY/$project:$IMAGE_TAG"
	docker push "$BENCHER_REGISTRY/$project:$IMAGE_TAG"
done
docker logout "$BENCHER_REGISTRY"
