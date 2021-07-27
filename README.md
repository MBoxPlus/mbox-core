# MBox Core

MBoxCore is the core of MBox CLT built in MBox APP, which provides the basic models and environment for MBox.

## Files

- `MBoxCLI` - the executable file of command line.
- `MDevCLI` - the executable file of command line for debug.
- `repackage-dylibs.rb` - the script for packaging dylibs.

## Classes

- `MBSession` - The instance created when each command line process started.
- `MBCommander` - The base class of each specific command.
- `MBCMD` - The class of each executable command.
- `MBPluginManager` - The shared instance, which manages all MBox Plugins, including installing, upgrading, launching and loading.
- `MBLogger` - Class of logger for command line.

- `MBSetting` - The model class for `.mboxconfig` files.
- `MBPluginPackage` - The model class for each MBox plugin.


## Contributing
Please reference the section [Contributing](https://github.com/MBoxPlus/mbox#contributing)

## License
MBox is available under [GNU General Public License v2.0 or later](./LICENSE).