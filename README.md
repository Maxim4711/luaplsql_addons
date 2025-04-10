# luaplsql_addons

addons for [plsql developer](https://www.allroundautomations.com/products/pl-sql-developer/) (by Allround Automations) 
based on exciting [luaplsql plugin](https://github.com/tnodir/luaplsql.git) by Nodir Temirkhodjaev 
# Addons
* some text editing functions (in folder lua\Custom
  - selection uppercase
  - selection lowercase
  - selection single line comment
  - selection single line uncomment
  - selection single line toggle comment
* Snippets (in folder lua\SQLSnippets)
* Unwrapper (in folder lua\Tools)

Selection uppercase/lowercase are strictly seen not required, as it is already included in core plsql developer functionality - but from my perspective it was a nice exercise to gain some practice in lua text processing capabilities. Selection single line comment/uncomment/toggle comment is already provided by the commentline plugin from the [bar solutions](https://www.bar-solutions.com/plugins.php) - though, toggle comment is only available in the registered version. Snippets is the plugin i use a lot in the daily work, it is basically reimplementation of already available [NamedSQL plugin](https://www.allroundautomations.com/products/pl-sql-developer/plug-ins/) - the main motivation behind this addon - the NamedSQL plugin is only available as 32 bit version and in my setup 64 bit is deployed. Besides that - the snippet delimiter was changed from `@@` to `--@@ @@--` - thus, the snippets file could be formatted as just regular sql file (presumed - the snippets are complete sql statements or plsql blocks) using formatter of choice. This addon is implemented using [IUP toolkit](https://www.tecgraf.puc-rio.br/iup/) (which i was not aware before, so thanks again for the hint, Nodir Temirkhodjaev) and this required to include into the original plugin a lua5.1.dll proxy - fortunately the [source code](https://github.com/tnodir/luajit-windows.git) for it is available by the author of luaplsql plugin, i just created some patches to reflect current state of luajit distribution.
[Unwrapper](https://github.com/Trivadis/plsql-unwrapper-sqldev.git) is already available for sqldeveloper - but i haven't seen similar functionality for plsql developer, thus, ported the original [Niels Teusink](https://github.com/DarkAngelStrike/UnwrapperPLSQL.git) unwrap.py script mirrored to the github - in lua it would require lua-zlib and luasocket modules (which i used initially) - but manual build would be slightly more complex, if somebody is not using lua and luarocks ecosystem regularly, so i decided to use pure lua module [LibDeflate](https://github.com/SafeteeWoW/LibDeflate.git) instead, which supports all current versions of lua and luajit. This addon works in two modes - from the object explorer view (via right click menu item - View unwrapped) and if the wrapped source is loaded into sql window - then via menu item Lua / Utilities / View Unwrapped - however, due to some issue with plsql developer - if object explorer right click menu item like View/Edit/View Spec & Body etc. is used to load wrapped source into program window - it loads incomplete wrapped source for large program units, then unwrapped text is either incomplete. If instead object explorer right click menu item View Unwrapped is used directly - then it showing properly whole source code.

# Build
Some prerequisites have to be met - first one is [Buildtools für Visual Studio](https://visualstudio.microsoft.com/de/downloads/?q=build+tools). Alternatively - [Portable Build Tools](https://github.com/Data-Oriented-House/PortableBuildTools.git) can be used. Theoretically - mingw should do the job as well, but i haven't tested it. Next - utilities like `patch`, `wget`,`zip`,`unzip` - which are probably easiest to install with some of package manager, my preference is scoop. All commands below related to build scripts should be executed in `Developer Command Prompt for VS`

```batch
scoop install patch wget unzip zip git
git clone https://github.com/Maxim4711/luaplsql_addons.git
cd luaplsql_addons
mkdir build
cd build

git clone https://github.com/tnodir/luaplsql.git
git clone https://github.com/tnodir/luasys.git
git clone https://github.com/tnodir/luajit-windows.git
git clone https://github.com/LuaJIT/LuaJIT.git luajit-2.0

patch -u -b luajit-windows\src\lua5.1.c -i %cd%\..\patches\lua5.1.c.patch
patch -u -b luajit-2.0\src\msvcbuild.bat -i %cd%\..\patches\luajit-msvcbuild.bat.patch

copy luajit-windows\src\lua5.1.c luajit-2.0\src
copy luajit-windows\src\wluajit.c luajit-2.0\src

cd luajit-2.0\src\
msvcbuild.bat
cd ..\..

cd luasys\src
msvcbuild.bat
cd ..\..

cd luaplsql\src\
msvcbuild.bat
cd ..\..

copy luajit-2.0\src\lua5*.dll luaplsql\PlugIns\lua\clibs
copy luasys\src\sys.dll luaplsql\PlugIns\lua\clibs

wget https://master.dl.sourceforge.net/project/iup/3.32/Windows%20Libraries/Dynamic/Lua51/iup-3.32-Lua51_Win64_dll17_lib.zip
wget https://master.dl.sourceforge.net/project/iup/3.32/Windows%20Libraries/Dynamic/iup-3.32_Win64_dll17_lib.zip
mkdir luaplsql\PlugIns\lua\clibs\iup
unzip iup-3.32-Lua51_Win64_dll17_lib.zip  iuplua51.dll iupluacontrols51.dll iupluaimglib51.dll -d luaplsql\PlugIns\lua\clibs\iup
unzip iup-3.32_Win64_dll17_lib.zip iup.dll iupcontrols.dll iupimglib.dll -d luaplsql\PlugIns\lua\clibs\iup

git clone https://github.com/SafeteeWoW/LibDeflate.git
copy LibDeflate\LibDeflate.lua luaplsql\PlugIns\lua\Tools

xcopy ..\lua\* luaplsql\PlugIns\lua /s /i
```
After that copy content of luasql\Plugins folder into corresponding Plugins folder of plsql developer. This setup produces 64 bit libraries, to build 32 bit - one needs just set corresponding variables for visual studio command prompt and download 32 bit IUP libraries instead of 64 bit.
