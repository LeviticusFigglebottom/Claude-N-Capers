# CAPERWORKS (working title)

An original first-person co-op heist game (1–4 players, solo with AI crew). It is built in Godot
4.7.2 and heavily inspired by Payday 2's mechanics. Every asset is self-made by script.

- Game design: [docs/design/game_overview.md](docs/design/game_overview.md), [PD2 fidelity contract](docs/design/pd2_fidelity.md)
- Architecture: [docs/architecture.md](docs/architecture.md)
- Roadmap and phase gates: [docs/roadmap.md](docs/roadmap.md)
- Team process (lead + 3 environments): [docs/process/communication.md](docs/process/communication.md)
- Contracts: [docs/contracts/](docs/contracts/README.md)
- Decisions: [docs/decisions.md](docs/decisions.md)

Quick start:
```
bash tools/setup/install_godot.sh
pip install -r tools/requirements.txt
tools/ci/check_all.sh
/opt/godot/godot --path game                         # editor/game
/opt/godot/godot --path game -- --heist=glasshouse   # direct heist launch (once it exists)
```
