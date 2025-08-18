#!/bin/bash
cd "$(dirname "$0")/.."
source venv/bin/activate
cd services/code_doctor
python main.py
