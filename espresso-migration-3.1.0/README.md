# Espresso Migration v3

This folder is a self-contained Foundry workspace dedicated to building and testing the Espresso-compatible Sequencer Inbox migration using Nitro v3 artifacts. It isolates the v3 migration code and its dependencies from the root project so we can compile and iterate without impacting the main repo’s compiler settings, remappings, or dependency graph.

## How to build

Build this workspace (without impacting the root):

```cmd
forge build --root ./espresso-migration-3.1.0
```
