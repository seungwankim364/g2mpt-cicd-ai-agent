#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/analysis-orchestrator"
ZIP_FILE="$ROOT_DIR/build/analysis-orchestrator.zip"
LAMBDA_DIR="$ROOT_DIR/lambda/analysis-orchestrator"
SLACK_HANDLER_BUILD_DIR="$ROOT_DIR/build/slack-approval-handler"
SLACK_HANDLER_ZIP_FILE="$ROOT_DIR/build/slack-approval-handler.zip"
ACTION_EXECUTOR_BUILD_DIR="$ROOT_DIR/build/deployment-action-executor"
ACTION_EXECUTOR_ZIP_FILE="$ROOT_DIR/build/deployment-action-executor.zip"

rm -rf "$BUILD_DIR" "$ZIP_FILE" "$SLACK_HANDLER_BUILD_DIR" "$SLACK_HANDLER_ZIP_FILE" "$ACTION_EXECUTOR_BUILD_DIR" "$ACTION_EXECUTOR_ZIP_FILE"
mkdir -p "$BUILD_DIR"

cp "$LAMBDA_DIR/app.py" "$BUILD_DIR/app.py"
cp "$LAMBDA_DIR/ai_agent_adapter.py" "$BUILD_DIR/ai_agent_adapter.py"
cp "$LAMBDA_DIR/bedrock_agent.py" "$BUILD_DIR/bedrock_agent.py"

mkdir -p "$BUILD_DIR/ai_agent"
cp "$ROOT_DIR/ai-agent/app/analyzer.py" "$BUILD_DIR/ai_agent/analyzer.py"
cp "$ROOT_DIR/ai-agent/app/runbook_loader.py" "$BUILD_DIR/ai_agent/runbook_loader.py"
cp "$ROOT_DIR/ai-agent/app/slack_message_builder.py" "$BUILD_DIR/ai_agent/slack_message_builder.py"
touch "$BUILD_DIR/ai_agent/__init__.py"

mkdir -p "$BUILD_DIR/athena"
cp -R "$ROOT_DIR/athena/queries" "$BUILD_DIR/athena/queries"
cp -R "$ROOT_DIR/athena/templates" "$BUILD_DIR/athena/templates"

mkdir -p "$BUILD_DIR/scripts"
cp -R "$ROOT_DIR/scripts/runbooks" "$BUILD_DIR/scripts/runbooks"

find "$BUILD_DIR" -type d -name "__pycache__" -prune -exec rm -rf {} +
find "$BUILD_DIR" -type f -name "*.pyc" -delete

(
  cd "$BUILD_DIR"
  zip -qr "$ZIP_FILE" .
)

python3 -m py_compile \
  "$BUILD_DIR/app.py" \
  "$BUILD_DIR/ai_agent_adapter.py" \
  "$BUILD_DIR/bedrock_agent.py" \
  "$BUILD_DIR/ai_agent/analyzer.py" \
  "$BUILD_DIR/ai_agent/runbook_loader.py" \
  "$BUILD_DIR/ai_agent/slack_message_builder.py"

echo "Created $ZIP_FILE"

mkdir -p "$SLACK_HANDLER_BUILD_DIR"
cp "$ROOT_DIR/lambda/slack-approval-handler/app.py" "$SLACK_HANDLER_BUILD_DIR/app.py"
(
  cd "$SLACK_HANDLER_BUILD_DIR"
  zip -qr "$SLACK_HANDLER_ZIP_FILE" .
)
python3 -m py_compile "$SLACK_HANDLER_BUILD_DIR/app.py"
echo "Created $SLACK_HANDLER_ZIP_FILE"

mkdir -p "$ACTION_EXECUTOR_BUILD_DIR"
cp "$ROOT_DIR/lambda/deployment-action-executor/app.py" "$ACTION_EXECUTOR_BUILD_DIR/app.py"
(
  cd "$ACTION_EXECUTOR_BUILD_DIR"
  zip -qr "$ACTION_EXECUTOR_ZIP_FILE" .
)
python3 -m py_compile "$ACTION_EXECUTOR_BUILD_DIR/app.py"
echo "Created $ACTION_EXECUTOR_ZIP_FILE"
