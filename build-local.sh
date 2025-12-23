#!/bin/bash
set -e

# Local build script for testing Kong configuration
# Usage: ./build-local.sh [dev|uat|stg|prod]

ENVIRONMENT=${1:-dev}
REPO_NAME=$(basename $(git rev-parse --show-toplevel) 2>/dev/null || echo "my-pipeline-k-konnect-oas-v1")
MANAGED_TAG="cicd"

echo "🚀 Building Kong configuration for environment: $ENVIRONMENT"
echo "📦 Repository name: $REPO_NAME"
echo ""

# Check if deck is installed
if ! command -v deck &> /dev/null; then
    echo "❌ Error: decK is not installed. Please install it first:"
    echo "   https://docs.konghq.com/deck/latest/installation/"
    exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "❌ Error: yq is not installed. Please install it first:"
    echo "   https://github.com/mikefarah/yq#install"
    exit 1
fi

# Check if envsubst is installed
if ! command -v envsubst &> /dev/null; then
    echo "❌ Error: envsubst is not installed (usually comes with gettext)"
    exit 1
fi

# Create generated directory
mkdir -p .generated

# Step 1: Generate Kong base configuration from OpenAPI
echo "📝 Step 1: Generating Kong base configuration from OpenAPI spec..."
deck file openapi2kong \
  --spec spec/openapi.yaml \
  --output-file .generated/kong.yaml

if [ ! -f ".generated/kong.yaml" ]; then
    echo "❌ Error: Failed to generate Kong configuration"
    exit 1
fi

# Step 2: Load environment config
CONFIG_FILE="config/vars/${ENVIRONMENT}-envs.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Missing env config $CONFIG_FILE"
    exit 1
fi

echo "📋 Step 2: Loading environment configuration..."
export REPO_NAME
envsubst < "$CONFIG_FILE" > .generated/envs.json

echo "=== Environment config ==="
cat .generated/envs.json
echo ""

# Step 3: Split Horizon - Create external and internal routes
echo "🔀 Step 3: Splitting routes (Split-Horizon)..."
echo "=== Initial routes from OpenAPI ==="
yq eval '.services[0].routes[].name' .generated/kong.yaml || echo "No routes found"
echo ""

# Create external routes
yq eval-all '
  (select(fileIndex == 1).route_external) as $extHost |
  (select(fileIndex == 1)) as $env |
  select(fileIndex == 0) |
  .services[0] *= $env |
  .services[0].routes = [
    .services[0].routes[] | 
    . as $r |
    ($r | del(.id) | .name = $r.name + "-external" | .hosts = [$extHost] | .tags = ["external","cicd"])
  ] |
  del(.services[0].route_external) |
  del(.services[0].route_internal) |
  del(.services[0].enabled)
' .generated/kong.yaml .generated/envs.json > .generated/kong-ext.yaml

# Create internal routes  
yq eval-all '
  (select(fileIndex == 1).route_internal) as $intHost |
  (select(fileIndex == 1)) as $env |
  select(fileIndex == 0) |
  .services[0] *= $env |
  .services[0].routes = [
    .services[0].routes[] | 
    . as $r |
    ($r | del(.id) | .name = $r.name + "-internal" | .hosts = [$intHost] | .tags = ["internal","cicd"])
  ] |
  del(.services[0].route_external) |
  del(.services[0].route_internal) |
  del(.services[0].enabled)
' .generated/kong.yaml .generated/envs.json > .generated/kong-int.yaml

# Merge external and internal routes
yq eval-all '
  (select(fileIndex == 0).services[0].routes) as $extRoutes |
  (select(fileIndex == 1).services[0].routes) as $intRoutes |
  select(fileIndex == 0) |
  .services[0].routes = ($extRoutes + $intRoutes) |
  .services[0] *= (select(fileIndex == 1).services[0] | del(.routes))
' .generated/kong-ext.yaml .generated/kong-int.yaml > .generated/kong.tmp.yaml

mv .generated/kong.tmp.yaml .generated/kong.yaml

echo "=== Routes after split horizon ==="
yq eval '.services[0].routes[] | .name + " - tags: " + (.tags | join(",")) + " - hosts: " + (.hosts | join(","))' .generated/kong.yaml
echo ""

# Step 4: Apply public template to external routes
echo "🔐 Step 4: Applying public security template to external routes..."
yq eval-all '
  (select(fileIndex == 1).plugins) as $p |
  (select(fileIndex == 1).ca_certificates) as $certs |
  select(fileIndex == 0) |
  .services[0].routes[] |= (
    (select(.tags | contains(["external"])) | .plugins += $p) // .
  )
' .generated/kong.yaml config/templates/public.yaml > .generated/kong.tmp.yaml

# Merge CA certificates separately if they exist
if yq eval '.ca_certificates' config/templates/public.yaml > /dev/null 2>&1; then
  yq eval-all '
    (select(fileIndex == 1).ca_certificates) as $certs |
    select(fileIndex == 0) |
    .ca_certificates = $certs
  ' .generated/kong.tmp.yaml config/templates/public.yaml > .generated/kong.ext.yaml
else
  mv .generated/kong.tmp.yaml .generated/kong.ext.yaml
fi

# Step 5: Apply private template to internal routes
echo "🔒 Step 5: Applying private security template to internal routes..."
yq eval-all '
  (select(fileIndex == 1).plugins) as $p |
  select(fileIndex == 0) |
  .services[0].routes[] |= (
    (select(.tags | contains(["internal"])) | .plugins += $p) // .
  )
' .generated/kong.ext.yaml config/templates/private.yaml > .generated/kong.final.yaml

mv .generated/kong.final.yaml .generated/kong.yaml

# Step 6: Tag managed resources
echo "🏷️  Step 6: Tagging managed resources..."
yq eval '.services[].tags += ["cicd"] | .services[].tags |= unique' -i .generated/kong.yaml

# Step 7: Verify routes generation
echo "✅ Step 7: Verifying generated routes..."
EXTERNAL_COUNT=$(yq eval '.services[0].routes[] | select(.tags | contains(["external"])) | .name' .generated/kong.yaml | wc -l | tr -d ' ')
INTERNAL_COUNT=$(yq eval '.services[0].routes[] | select(.tags | contains(["internal"])) | .name' .generated/kong.yaml | wc -l | tr -d ' ')
TOTAL=$((EXTERNAL_COUNT + INTERNAL_COUNT))

echo "External routes: $EXTERNAL_COUNT"
echo "Internal routes: $INTERNAL_COUNT"
echo "Total routes: $TOTAL"
echo ""

if [ "$EXTERNAL_COUNT" -eq 0 ] || [ "$INTERNAL_COUNT" -eq 0 ]; then
    echo "❌ Error: Missing routes! Expected both external and internal routes."
    exit 1
fi

echo "=== Route names ==="
yq eval '.services[0].routes[].name' .generated/kong.yaml
echo ""

echo "=== Route details ==="
echo "External routes:"
yq eval '.services[0].routes[] | select(.tags | contains(["external"])) | .name' .generated/kong.yaml
echo ""
echo "Internal routes:"
yq eval '.services[0].routes[] | select(.tags | contains(["internal"])) | .name' .generated/kong.yaml
echo ""

# Step 8: Display final configuration
echo "📄 Final Kong configuration saved to: .generated/kong.yaml"
echo ""
echo "=== Summary ==="
echo "✅ Configuration built successfully!"
echo "📁 Output file: .generated/kong.yaml"
echo ""
echo "To deploy to a local Kong Gateway (Docker), use:"
echo "  deck sync .generated/kong.yaml --kong-addr http://localhost:8001"
echo ""
echo "Or to deploy to Kong Konnect, use:"
echo "  deck sync .generated/kong.yaml \\"
echo "    --konnect-token <YOUR_TOKEN> \\"
echo "    --konnect-addr <KONNECT_URL> \\"
echo "    --konnect-control-plane-name <CP_NAME> \\"
echo "    --select-tag $MANAGED_TAG"
echo ""

