#!/bin/bash
cd "$(dirname "$0")/.."
source venv/bin/activate
cd services/data_hub
python main.py
