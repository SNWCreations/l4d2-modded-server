#include <sourcemod>

public Plugin myinfo =
{
    name = "Chat Exec",
    author = "SNWCreations",
    description = "Executes .cfg files through chat commands",
    version = "1.0.1",
    url = "https://github.com/SNWCreations/ChatExec"
};

public void OnPluginStart()
{
    LoadTranslations("chat_exec.phrases");

    // Register the command /exec as a chat command
    RegAdminCmd("sm_exec", Command_ChatExec, ADMFLAG_ROOT, "Executes a configuration file from the server's cfg directory");
}

public Action Command_ChatExec(int client, int args)
{
    if (args < 1)
    {
        if (client != 0)
        {
            PrintToChat(client, "%t: /exec <cfg_path>", "Usage");
            PrintToChat(client, "%t: /exec myconfig", "Example");
        }
        return Plugin_Handled;
    }

    char cfgPath[256];
    GetCmdArg(1, cfgPath, sizeof(cfgPath));
    ServerCommand("exec %s", cfgPath);

    // Log the command execution, and the user name who executed it
    char userName[64];
    if (client != 0)
    {
        GetClientName(client, userName, sizeof(userName));
    }
    else
    {
        strcopy(userName, sizeof(userName), "Console");
    }
    char logMessage[256];
    Format(logMessage, sizeof(logMessage), "User '%s' executed config file: %s", userName, cfgPath);
    PrintToServer(logMessage);

    // Notify the client that the command was sent
    if (client != 0)
    {
        PrintToChat(client, "%t", "Command Sent");
    }

    return Plugin_Handled;
}