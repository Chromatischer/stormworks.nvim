# stormworks.nvim
A Neovim plugin making developing Code in Stormworks way easier

Install with lazyvim using
```
{ "Chromatischer/stormworks.nvim" }
```


This plugin is using large parts of code written by NameousChangey for the [Stormworks VSCode Extension](https://github.com/nameouschangey/Stormworks_VSCodeExtension.git) all these parts are clearly marked and all contained within [nameouschangey](./lua/common/nameouschangey/Common/LifeBoatAPI/Tools/Utils/Base.lua).

To use this start by marking your project as a Microcontroller project using:
```
:MicroProject mark
```
You can then add other folders, for example including utils using:
```
:MicroProject add <path_to_top_level_folder>
:MicroProject setup
```

## Building
To Compile for Stormworks use:
```
:MicroProject build
```
which will build the entire directory which you are currently in

Or:
```
:MicroProject here
```
If you are only interested in building the current file!
