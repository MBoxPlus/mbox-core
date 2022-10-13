# MBox Core

MBoxCore is the core of MBox CLT built in MBox APP, which provides the basic models and environment for MBox.

## Files

- `MBoxCLI` - the executable file of command line.
- `MDevCLI` - the executable file of command line for debug.

## Classes

- `MBThread` - The instance created when each command line thread started.
- `MBCommander` - The base class of each specific command.
- `MBCMD` - The class of each executable command.
- `MBLogger` - Class of logger for command line.
- `MBSetting` - The model class for `.mboxconfig` files.
- `MBPluginManager` - The shared instance, which manages all MBox Plugins, including installing, upgrading, launching and loading.
- `MBPluginPackage` - The model class for each MBox plugin.
- `MBPluginModule` - The model class for each MBox module in a plugin.


## Contributing
Please reference the section [Contributing](https://github.com/MBoxPlus/mbox#contributing)

## License
MBox is available under [GNU General Public License v2.0 or later](./LICENSE).