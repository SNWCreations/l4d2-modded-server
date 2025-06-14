# Left 4 Dead 2 (L4D2) Modded Server

## About

A modded Left 4 Dead 2 (L4D2) server which includes some mods that enhances the gameplay.

## Installation

Make sure you have **10GB** free space at least.

If you have git installed; it is recommended to use git and clone the repo (`git clone https://github.com/SNWCreations/l4d2-modded-server.git`) and run your server from inside of it. This way you can simply run `git pull` to get updates (or run `update.bat`, it will start the server after updating if no file conflicts).

Alternatively you can Download this repo and extract it to where you want your server (i.e. C:\Server\l4d2-modded-server) but you will manually have to handle updates.

All the following instructions will use the repo folder location as the root.

### Common setup (Windows & Linux)

- Open `server.ini`
- Set `STEAM_USER` to the name of a Steam user that you own and have access to L4D2.
- If setting up an internet server:
    - Set `LAN` to `0`
    - Make sure you port forward UDP: 27015 on your router so players can connect from the internet.
    - **You must connect to the server from the public IP, not the LAN IP even if you are on the same network.**
- If setting up a LAN server:
    - Set `LAN` to `1`
- Add admins (see [Setting admins](#setting-admins))
- Accept both Private and Public connections in your firewall.

### Windows

- Run `server.bat`

### Linux

- Make sure you have `curl` and `rsync` installed. The provided scripts will attempt to install them automatically using `install-linux-tools.sh` if missing.
- Make sure you have **PowerShell 7+** installed. If not, the provided scripts will attempt to install it automatically using Microsoft's official installer.
- Make sure you have `git` installed (`sudo apt install git` on Debian/Ubuntu).
- Clone the repo or extract it to your desired location.
- Run `./start.sh` from the root of the repository.
- On first run, the script will download and install SteamCMD and all required files.

### First Run (All Platforms)

To check everything is working correctly run the following commands in the server console:

First, run `meta list`

and you should see SourceMod in the output

Then run `sm plugins list`

and you should see a set of plugins in the output

If you see content in both; everything is working.

Just use `quit` or `exit` in server console if you want to stop the server.

## Included Mods

| Mod                                       | Version        | Description                                                                                                                                                                                | Source                                                                                                       |
| ----------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| SourceMod                                 | 1.12.0-git7207 | SourceMod is server modification for any game that runs on the Half-Life 2 engine. It is a powerful, highly optimized platform for scripting plugins and handling server administration.   | https://www.sourcemod.net/                                                                                   |
| MetaMod:Source                            | 2.0.0-git1350  | Metamod:Source is a C++ plugin environment for Half-Life 2. It acts as a "metamod" which sits in between the Game and the Engine, and allows plugins to intercept calls that flow between. | https://www.metamodsource.net/                                                                               |
| L4DToolZ                                  | 2.4.1          | A source plugin to unlock the maximum player and tickrate limit on L4D2.                                                                                                                   | https://github.com/lakwsh/l4dtoolz                                                                           |
| Left4DHooks                               | 1.158          | An all-in-one port to DHooks with many additions.                                                                                                                                          | https://forums.alliedmods.net/showthread.php?t=321696                                                        |
| SM Respawn Improved                       | 3.9            | Adds ability to respawn player without losing statistics.                                                                                                                                  | https://forums.alliedmods.net/showthread.php?p=2693455                                                       |
| MultiColor                                | 2.1.2          | A summary of Colors and More Colors                                                                                                                                                        | https://github.com/Bara/Multi-Colors                                                                         |
| All4Dead 2                                | 3.9            | Enables admins to have control over the AI Director and spawn all weapons, melee, items, special infected, and Uncommon Infected without using sv_cheats 1                                 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/all4dead2                                             |
| Spawn Infected NoLimit                    | 1.3h           | Spawn special infected without the director limits!                                                                                                                                        | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/spawn_infected_nolimit                                |
| Drop Secondary                            | 2.6            | Survivor players will drop their secondary weapon when they die                                                                                                                            | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/drop_secondary                                        |
| Unreserve Lobby                           | 1.7h           | Removes lobby reservation when server is full or empty                                                                                                                                     | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d_unreservelobby                                    |
| SourceMod Detailed Plugins List           | 1.0            |                                                                                                                                                                                            | https://forums.alliedmods.net/showthread.php?t=347326                                                        |
| Infinite Ammo                             | 1.5.6          | Give players infinite ammo                                                                                                                                                                 | https://github.com/wyxls/SourceModPlugins-L4D2/tree/master/l4d2_infiniteammo                                 |
| No Friendly Fire                          | 10.0           | Disables friendly-fire.                                                                                                                                                                    | https://forums.alliedmods.net/showthread.php?t=302822                                                        |
| Game Mode Config Loader                   | 1.6            | Executes a cfg file based on the games current settings at map load.                                                                                                                       | https://forums.alliedmods.net/showthread.php?p=834731                                                        |
| Stripper: Source                          | 1.2.2-git141   | A small but flexible plugin which lets you filter and add entities to a map before it loads                                                                                                | https://www.bailopan.net/stripper                                                                            |
| MultiSlots Improved                       | 6.9            | Allows additional survivor players in server when 5+ player joins the server                                                                                                               | https://github.com/fbef0102/L4D1_2-Plugins/blob/master/l4dmultislots                                         |
| Defib Fix                                 | 2.0.1          | Fixes valve's defib not defibbing correct survivor, sometimes even reviving an alive player                                                                                                | https://forums.alliedmods.net/showthread.php?t=315483                                                        |
| Survivor Identitfy Fix (Shadowysn Fork)   | 1.7b           | Fix bug where a survivor will change identity when a player connects/disconnects if there are 5+ survivors                                                                                 | https://forums.alliedmods.net/showpost.php?p=2718792                                                         |
| Survivor AFK Fix                          | 1.0.4          | Fixes survivor going AFK game function.                                                                                                                                                    | https://forums.alliedmods.net/showthread.php?t=326742                                                        |
| AFK Fix for Dead Bot                      | 1.0h           | Fixes issue when a bot die, his IDLE player become fully spectator rather than take over dead bot in 4+ survivors games                                                                    | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4dafkfix_deadbot                                     |
| Upgrade Pack Fix                          | 1.0h           | Fixes upgrade packs pickup bug when using survivor model change + remove upgrade pack                                                                                                      | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/lfd_both_fixUpgradePack                               |
| Source Scramble Manager                   | 1.2.0          | Helper plugin to load simple assembly patches from a configuration file.                                                                                                                   | https://forums.alliedmods.net/showthread.php?p=2657347                                                       |
| Charger Collision Patch                   | 2.0            | Fixes crappy charger.                                                                                                                                                                      | https://forums.alliedmods.net/showthread.php?t=315482                                                        |
| Witch Target Patch                        | 1.4            | Fix witch targets wrong person                                                                                                                                                             | https://github.com/LuxLuma/Left-4-fix/tree/master/left%204%20fix/witch/witch_target_patch                    |
| Survivor Set Flow Fix                     | 2.1            | Fix oddities when playing with an unintended survivor set in campaigns.                                                                                                                    | https://forums.alliedmods.net/showthread.php?t=339155                                                        |
| Fix ChangeLevel                           | 1.1            | Fix issues due to forced changelevel (i.e. No gascans in scavenge, incorrect behavior of "OnGameplayStart").                                                                               | https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d2_fix_changelevel |
| Transition Info Fix                       | 1.2.0          | Fix the transition info bug                                                                                                                                                                | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_transition_info_fix                              |
| InputKill Kick Prevention                 | 1.0            | Stops clients from getting kicked via the Kill input                                                                                                                                       | https://forums.alliedmods.net/showthread.php?t=332860                                                        |
| Command and ConVVar Buffer Overflow Fixer | 2.9a           | Fixes the 'Cbuf_AddText: buffer overflow' console error on servers, which causes ConVars to use their default value.                                                                       | https://forums.alliedmods.net/showthread.php?t=309656                                                        |
| Map Tank Fix                              | 1.5            | Fix the spawning of tank entities in third-party maps, preventing broken game process                                                                                                      | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_maptankfix                                       |
| Rescue Vehicle Multi                      | 1.0h           | Try to fix extra 5+ survivors bug after finale rescue leaving, such as: die, fall down, not count as alive, versus score bug                                                               | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d2_rescue_vehicle_multi                             |
| Left4Fix                                  | 2.1.0          | Extension for Left 4 Dead 2 servers with extra player slots.                                                                                                                               | https://forums.alliedmods.net/showthread.php?t=219774                                                        |
| Ladder Server Crash - Patch Fix           | 1.1            | Fixes the "CNavLadder::GetPosAtHeight" crash that occurs randomly sometimes multiple times a day.                                                                                          | https://forums.alliedmods.net/showthread.php?t=336298                                                        |
| The Passing Character Fix                 | 1.0            | Prevent extra players become NPCs in c6m1_riverbank and c6m3_port.                                                                                                                         | https://forums.alliedmods.net/showthread.php?t=348949                                                        |
| Block No Steam Logon                      | 1.2.3          | Attempts to bypass server's 'no steam logon' disconnection.                                                                                                                                | https://github.com/blueblur0730/modified-plugins/tree/main/source/l4d2_block_no_steam_logon                  |
| 5+ Survivor Friendly Fire Quote Fix       | 1.1.5d         | Fixes friendly fire quotes not playing for the 5th survivor or higher.                                                                                                                     | https://forums.alliedmods.net/showthread.php?t=321127                                                        |
| 5+ Survivor Rescue Closet                 | 1.0.0b         | Allows a single rescue entity to rescue all eligible survivors.                                                                                                                            | https://forums.alliedmods.net/showthread.php?t=340659                                                        |
| Chat Exec                                 | 1.0            | Executes .cfg files through chat commands                                                                                                                                                  | https://github.com/SNWCreations/ChatExec                                                                     |

## Custom files

Any changes you have made to the files in this mod will be overwritten when the startup scripts are ran.

I have created a folder /custom_files/ in the root of the project, where you mirror the contents of the `left4dead2` folder in the `server` folder, and any files you want to tweak, you put in there in the same spot and they will always overwrite the mods default files.

So this can be used to set the server hostname to something you want, set the RCON or the admins of the server.

Annoyed with recreating the folder structure? You can simply copy the file you want by running `custom_file <file>` in your Command Prompt or `.\custom_file.ps1 <file>` in PowerShell at the root of this repository folder, the script will recreate the path structure for you.

Wanted to install Steam workshop files? Just checkout `workshop.bat` script (wraps `workshop.ps1` PowerShell script), it will handle Steam Workshop downloads for you, just need your Steam account name so SteamCMD will ask for your password (or lookup cached credentials) later.

### Setting admins

There are two ways to configure the admin list, I prefer `admin_simple.ini` from `addons/sourcemod/configs` folder, `admins.cfg` is also available though.

Just copy it to the `custom_files/addons/sourcemod/configs` and edit it by following the instructions inside it, then start your server, and it will be applied.

## Credits

- [kus](https://github.com/kus) - [His CS2 modded server repository](https://github.com/kus/cs2-modded-server) inspired me to make this,
 also used some code from it to make the startup script in this repository.
- [fbef0102 (aka. Harry)](https://github.com/fef0102) - His tutorial about how to setup a L4D2 server which supports 4+ players helped me
 to introduce the 4+ player support update.
- Authors of the plugins used in this project, big thanks to you all for bringing these great plugins to the community!

## License & Usage Requirements

This project uses GNU LGPL v3 License, which inherits from kus' CS2 Modded Server repository.

Feel free to use this server pack anywhere you'd like, and you can modify it to fit your gameplay requirements.

Give a link to this repository is not required while advertising your server which is based on this pack, but will be highly appreciated.
