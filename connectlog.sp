#pragma semicolon 1

#include <sourcemod>

public Plugin myinfo =
{
    name        = "Connection Logger",
    author      = "i.car",
    description = "Logs player connections and disconnections",
    version     = "1.0",
    url         = "https://likeIHaveUrl.com"
};

public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client)) return;

    char join_ip[MAX_NAME_LENGTH];
    GetClientIP(client, join_ip, sizeof(join_ip), true);

    char client_name[MAX_NAME_LENGTH];
    GetClientName(client, client_name, sizeof(client_name));

    char steam_id[MAX_NAME_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, steam_id, sizeof(steam_id));

    LogMessage("Player %s connected with IP: %s, SteamID: %s", client_name, join_ip, steam_id);
}

public void OnClientDisconnect(int client)
{
    if (IsFakeClient(client)) return;

    char leave_ip[MAX_NAME_LENGTH];
    GetClientIP(client, leave_ip, sizeof(leave_ip), true);

    char client_name[MAX_NAME_LENGTH];
    GetClientName(client, client_name, sizeof(client_name));

    char steam_id[MAX_NAME_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, steam_id, sizeof(steam_id));

    LogMessage("Player %s disconnected with IP: %s, SteamID: %s", client_name, leave_ip, steam_id);
}