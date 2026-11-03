# Vision Trainer CI / release checklist (mirrors Apprentice hygiene).
#
# Offline gate (no CE needed):
#   python -m pytest vision_trainer/tests/ -q -m "not live"
#
# Opt-in live gate (needs harness + CE bridge + attached offline game):
#   python -m pytest vision_trainer/tests/test_harness_live.py -m live -q
#
# Build:
#   pip install pyinstaller
#   pyinstaller vision_trainer.spec
#   python vision_trainer/harness/sha256sums.py dist/VisionTrainer
#
# Clean-VM smoke (CE + local LLM at http://localhost:20128/v1, no Python):
#   1. Full loop: setup -> process -> capture -> extract -> adjust x100
#      -> verify -> Yes -> RUNBOOK + profile + draft artifacts on disk.
#   2. Restart game -> anchor re-locates without rescan.
#   3. Freeze holds across value decay; normal quit restores.
#   4. No admin required. Unsigned binary: expect SmartScreen warning.
#
# PR convention (Apprentice-style): state which game + build you validated
# in-game, and which cheats are proven vs unproven.
