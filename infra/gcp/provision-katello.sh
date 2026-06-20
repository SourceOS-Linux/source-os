#!/usr/bin/env bash
# provision-katello.sh — Create Foreman/Katello server VM on GCP
set -euo pipefail

PROJECT="socioprophet-platform"
ACCOUNT="michael@socioprophet.ai"
REGION="us-central1"
ZONE="us-central1-a"
INSTANCE_NAME="sourceos-katello"
MACHINE_TYPE="n2-standard-8"
DISK_SIZE="200"
DISK_TYPE="pd-ssd"
TAG="sourceos-katello"
STATIC_IP_NAME="sourceos-katello-ip"
FIREWALL_RULE_NAME="allow-katello-https"
FIREWALL_SSH_NAME="allow-katello-iap-ssh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== SourceOS Katello Provisioning ==="
echo "Project : $PROJECT"
echo "Account : $ACCOUNT"
echo "Zone    : $ZONE"
echo ""

# Ensure correct project + account
gcloud config set project "$PROJECT"
gcloud config set account "$ACCOUNT"

# --- Static IP ---
echo "[1/4] Reserving static IP: $STATIC_IP_NAME ..."
if gcloud compute addresses describe "$STATIC_IP_NAME" --region="$REGION" --project="$PROJECT" &>/dev/null; then
  echo "  Static IP already exists, skipping."
else
  gcloud compute addresses create "$STATIC_IP_NAME" \
    --project="$PROJECT" \
    --region="$REGION"
  echo "  Created."
fi

EXTERNAL_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" \
  --region="$REGION" \
  --project="$PROJECT" \
  --format="get(address)")
echo "  External IP: $EXTERNAL_IP"

# --- Firewall rule ---
echo "[2/4] Creating firewall rule: $FIREWALL_RULE_NAME ..."
if gcloud compute firewall-rules describe "$FIREWALL_RULE_NAME" --project="$PROJECT" &>/dev/null; then
  echo "  Firewall rule already exists, skipping."
else
  gcloud compute firewall-rules create "$FIREWALL_RULE_NAME" \
    --project="$PROJECT" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:443 \
    --source-ranges=0.0.0.0/0 \
    --target-tags="$TAG"
  echo "  Created."
fi

# --- IAP SSH firewall rule ---
echo "[2b/4] Creating IAP SSH firewall rule: $FIREWALL_SSH_NAME ..."
if gcloud compute firewall-rules describe "$FIREWALL_SSH_NAME" --project="$PROJECT" &>/dev/null; then
  echo "  IAP SSH rule already exists, skipping."
else
  gcloud compute firewall-rules create "$FIREWALL_SSH_NAME" \
    --project="$PROJECT" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --target-tags="$TAG"
  echo "  Created."
fi

# --- VM instance ---
echo "[3/4] Creating VM instance: $INSTANCE_NAME ..."
if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --project="$PROJECT" &>/dev/null; then
  echo "  Instance already exists, skipping creation."
else
  gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="rocky-linux-9" \
    --image-project="rocky-linux-cloud" \
    --boot-disk-size="${DISK_SIZE}GB" \
    --boot-disk-type="$DISK_TYPE" \
    --boot-disk-device-name="$INSTANCE_NAME" \
    --tags="$TAG" \
    --address="$EXTERNAL_IP" \
    --metadata-from-file="startup-script=${SCRIPT_DIR}/startup-katello.sh" \
    --no-service-account \
    --no-scopes
  echo "  Created."
fi

# --- Summary ---
echo ""
echo "[4/4] Done."
echo ""
echo "======================================"
echo " Katello VM ready"
echo "======================================"
echo " External IP : $EXTERNAL_IP"
echo " Instance    : $INSTANCE_NAME ($ZONE)"
echo ""
echo "Next steps:"
echo "  1. Set the Foreman admin password metadata:"
echo "       gcloud compute instances add-metadata $INSTANCE_NAME \\"
echo "         --zone=$ZONE \\"
echo "         --metadata foreman-admin-password=<your-password>"
echo ""
echo "  2. Wait ~5 min for startup script to complete, then check logs:"
echo "       gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --tunnel-through-iap -- \\"
echo "         tail -f /var/log/sourceos-katello-startup.log"
echo ""
echo "  3. Retrieve auto-generated password (if metadata not set):"
echo "       gcloud compute ssh $INSTANCE_NAME --zone=$ZONE -- \\"
echo "         cat /opt/sourceos-katello/.admin-password"
echo ""
echo "  4. Run Katello setup script:"
echo "       FOREMAN_URL=https://$EXTERNAL_IP \\"
echo "       FOREMAN_PASSWORD=<password> \\"
echo "       bash scripts/katello-sourceos-setup.sh"
echo "======================================"
