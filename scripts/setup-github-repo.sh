#!/bin/bash
# GitHub Repository Setup Script für EU-UNION-AI-PACT

set -e

cd "/home/shinehealthcare/Schreibtisch/EU-UNION-AI-PACT-VS-Code Pipelines"

echo "🇪🇺 EU-UNION-AI-PACT - GitHub Repository Setup"
echo "=============================================="
echo ""

# Step 1: GitHub CLI Authentication
echo "🔐 Step 1: GitHub Authentifizierung"
echo "Bitte authentifizieren Sie sich mit GitHub..."
echo "Wählen Sie: HTTPS"
echo "Wählen Sie: Yes (für Git credential helper)"
echo "Wählen Sie: Login with a web browser"
echo ""

gh auth login

# Step 2: Repository erstellen
echo ""
echo "🏗️ Step 2: Privates Repository erstellen..."

REPO_NAME="EU-UNION-AI-PACT-VS-Code-Pipelines"
DESCRIPTION="🇪🇺 Complete DevSecOps/AI Pipeline with local NLP/IP stack, Vault integration, invisible hosting, and production-ready security. 100% free and open source."

gh repo create "$REPO_NAME" \
    --private \
    --description "$DESCRIPTION" \
    --add-readme=false \
    --clone=false

echo "✅ Repository erstellt: $REPO_NAME (privat)"

# Step 3: Remote hinzufügen
echo ""
echo "🔗 Step 3: Remote Repository verknüpfen..."

# Remote hinzufügen (falls noch nicht vorhanden)
if ! git remote get-url origin >/dev/null 2>&1; then
    gh repo set-default
    git remote add origin "https://github.com/$(gh auth status 2>&1 | grep 'Logged in' | sed 's/.*as \([^[:space:]]*\).*/\1/')/$REPO_NAME.git"
fi

# Push zum Repository
echo ""
echo "🚀 Step 4: Code pushen..."
git branch -M main
git push -u origin main

echo ""
echo "🎉 SUCCESS: Repository erfolgreich erstellt und gepusht!"
echo ""
echo "📋 Repository Details:"
echo "   Name: $REPO_NAME"
echo "   Typ: Privat"
echo "   URL: https://github.com/$(gh auth status 2>&1 | grep 'Logged in' | sed 's/.*as \([^[:space:]]*\).*/\1/')/$REPO_NAME"
echo ""
echo "🛠️ Nächste Schritte:"
echo "   1. Repository auf GitHub ansehen"
echo "   2. Collaborators hinzufügen (falls gewünscht)"
echo "   3. Branch Protection Rules einrichten"
echo "   4. Issues & Projects aktivieren"
echo ""
echo "✅ Das Repository ist bereit für weitere Projekte!"
