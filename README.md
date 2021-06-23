# MBox Core

MBoxCore is the core of MBox CLT built in MBox APP, which provides support to the basic environment of running command line for MBox.

Provides support for working with the following models:

- `MBSession` - An instance created when each command line process started.
- `MBCommander` - Base class of each specific command.
- `MBPluginManager` - A shared instance, which manages all MBox Plugins, including installing, upgrading, launching and loading.
- `MBAccount` - A model of user's infomation.
-  `Tea` - Utils for data recording.
-  `MBLogger` - Logger of command line.
