#!/bin/bash
# Script to set IAM permissions for Firebase Functions v2 (Cloud Run)
# This allows authenticated users to invoke the callable functions

PROJECT_ID="arc-epi"
REGION="us-central1"

echo "Setting IAM permissions for Firebase Functions..."
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed."
    echo ""
    echo "Please set IAM permissions manually through the Google Cloud Console:"
    echo ""
    echo "1. Go to: https://console.cloud.google.com/run?project=$PROJECT_ID"
    echo "2. For each function (getUserSubscription, getAssemblyAIToken):"
    echo "   a. Click on the function name"
    echo "   b. Go to the 'Permissions' tab"
    echo "   c. Click 'Add Principal'"
    echo "   d. Enter 'allUsers' in the 'New principals' field"
    echo "   e. Select 'Cloud Run Invoker' role"
    echo "   f. Click 'Save'"
    echo ""
    echo "Alternatively, install gcloud CLI and run this script again."
    exit 1
fi

# Set IAM policy for getUserSubscription
echo "Setting IAM policy for getUserSubscription..."
gcloud run services add-iam-policy-binding getUserSubscription \
  --region=$REGION \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --project=$PROJECT_ID

# Set IAM policy for getAssemblyAIToken
echo ""
echo "Setting IAM policy for getAssemblyAIToken..."
gcloud run services add-iam-policy-binding getAssemblyAIToken \
  --region=$REGION \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --project=$PROJECT_ID

echo ""
echo "✅ IAM permissions set successfully!"
echo ""
echo "Note: This allows allUsers to invoke the functions. The functions themselves"
echo "still check Firebase Authentication via request.auth, so only authenticated"
echo "users will be able to use the functions."
