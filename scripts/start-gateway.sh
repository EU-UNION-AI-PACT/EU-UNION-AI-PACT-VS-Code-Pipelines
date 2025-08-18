#!/bin/bash
cd "$(dirname "$0")/.."
source venv/bin/activate
cd nlp/services/gateway
python main.py
