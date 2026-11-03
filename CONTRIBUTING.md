# Contributing

Open the project with Godot 4.7.2. Keep the shared physical weapon rules, bot information boundary and replay version compatibility intact. Prefer focused changes with a reproducible example.

Before a pull request, import the project and run the source checks from README.md. Use the local two-client network test for multiplayer changes. Native Windows capture tools are optional maintainer utilities; they require a Windows/WSL desktop and local Godot/FFmpeg paths. Set GODOT to the command-line engine and GODOT_WINDOWS to the native Windows executable when using those tools. CTG_WINDOWS_LOCALAPPDATA can override the WSL path to Windows Local AppData.

For a bug report, include the build/version, map/rules, steps, expected and observed behavior, and a redacted log or recording if helpful. Do not post private invites, credentials, IP addresses or another person's recordings without permission. Report security issues privately using SECURITY.md.

Changes to game code and original assets are contributed under the project MIT license. Imported assets must keep their source, license and modification notes in CREDITS.md and the relevant asset directory.
