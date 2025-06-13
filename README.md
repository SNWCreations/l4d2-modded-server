# Left 4 Dead 2 (L4D2) Modded Server

## About

A modded Left 4 Dead 2 (L4D2) server which includes some mods that enhances the gameplay.

Designed to be run on Microsoft Windows, Linux support is not planned yet (PRs are welcome).

## Installation

Make sure you have **10GB** free space at least.

If you have git installed; it is recommended to use git and clone the repo (`git clone https://github.com/SNWCreations/l4d2-modded-server.git`) and run your server from inside of it. This way you can simply run `git pull` to get updates (or run `update.bat`, it will start the server after updating if no file conflicts).

Alternatively you can Download this repo and extract it to where you want your server (i.e. C:\Server\l4d2-modded-server) but you will manually have to handle updates.

All the following instructions will use the repo folder location as the root.

- Open server.ini

- Set STEAM_USER to the name of a Steam user that you owns and have access to L4D2.

- If setting up internet server:

    Set LAN to 0

    Make sure you port forward on your router UDP: 27015 so players can connect from the internet.

    **You must connect to the server from the public IP, not the LAN IP even if you are on the same network.**

- If setting up LAN server:

    Set LAN to 1

- Add admins (instruction [here](#setting-admins))

- Accept both Private and Public connections on Windows Firewall.

# Run the server

- Run `server.bat`

- If running for the first time

    To check everything is working correctly run the following commands in the server console:

    `meta list`

    and you should see SourceMod in the output

    `sm plugins list`
    
    and you should see a set of plugins in the output

If you see content in both; everything is working.

After the first run you can stop using anonymous login for server startup, but it is still necessary for workshop downloads.

Just use `quit` or `exit` in server console if you want to stop the server.

## Included Mods

| Mod                             | Version        | Description                                                                                                                                                                                | Source                                                                        |
| ------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| SourceMod                       | 1.12.0-git7207 | SourceMod is server modification for any game that runs on the Half-Life 2 engine. It is a powerful, highly optimized platform for scripting plugins and handling server administration.   | https://www.sourcemod.net/                                                    |
| MetaMod:Source                  | 2.0.0-git1350  | Metamod:Source is a C++ plugin environment for Half-Life 2. It acts as a "metamod" which sits in between the Game and the Engine, and allows plugins to intercept calls that flow between. | https://www.metamodsource.net/                                                |
| L4DToolZ                        | 2.4.1          | A source plugin to unlock the maximum player and tickrate limit on L4D2.                                                                                                                   | https://github.com/lakwsh/l4dtoolz                                            |
| Left4DHooks                     | 1.158          | An all-in-one port to DHooks with many additions.                                                                                                                                          | https://forums.alliedmods.net/showthread.php?t=321696                         |
| SM Respawn Improved             | 3.9            | Adds ability to respawn player without losing statistics.                                                                                                                                  | https://forums.alliedmods.net/showthread.php?p=2693455                        |
| MultiColor                      |                | A summary of Colors and More Colors                                                                                                                                                        | https://github.com/Bara/Multi-Colors                                          |
| Unlimited Chainsaw              |                | Chainsaw fuels always at 100%                                                                                                                                                              | https://forums.alliedmods.net/showthread.php?p=2687346                        |
| All4Dead 2                      | 3.9            | Enables admins to have control over the AI Director and spawn all weapons, melee, items, special infected, and Uncommon Infected without using sv_cheats 1                                 | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/all4dead2              |
| Spawn Infected NoLimit          | 1.3h           | Spawn special infected without the director limits!                                                                                                                                        | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/spawn_infected_nolimit |
| Drop Secondary                  | 2.6            | Survivor players will drop their secondary weapon when they die                                                                                                                            | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/drop_secondary         |
| Unreserve Lobby                 | 1.7h           | Removes lobby reservation when server is full or empty                                                                                                                                     | https://github.com/fbef0102/L4D1_2-Plugins/tree/master/l4d_unreservelobby     |
| SourceMod Detailed Plugins List | 1.0            |                                                                                                                                                                                            | https://forums.alliedmods.net/showthread.php?t=347326                         |
| Infinite Ammo                   | 1.5.6          | Give players infinite ammo                                                                                                                                                                 | https://github.com/wyxls/SourceModPlugins-L4D2/tree/master/l4d2_infiniteammo  |
| No Friendly Fire                | 10.0           | Disables friendly-fire.                                                                                                                                                                    | https://forums.alliedmods.net/showthread.php?t=302822                         |
| Game Mode Config Loader         | 1.6            | Executes a cfg file based on the games current settings at map load.                                                                                                                       | https://forums.alliedmods.net/showthread.php?p=834731                         |

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

[kus](https://github.com/kus) - [His CS2 modded server repository](https://github.com/kus/cs2-modded-server) inspired me to make this,
 also used some code from it to make the startup script in this repository.

## License & Usage Requirements

This project uses GNU LGPL v3 License, which inherits from kus' CS2 Modded Server repository.

Feel free to use this server pack anywhere you'd like, and you can modify it to fit your gameplay requirements.

Give a link to this repository is not required while advertising your server which is based on this pack, but will be highly appreciated.
