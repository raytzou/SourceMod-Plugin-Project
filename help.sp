#pragma semicolon 1

#include <sourcemod>
#include <geoip>

public Plugin myinfo =
{
    name = "My Helper",
    author = "i.car",
    description = "Display useful message and command",
    version = "1.0",
    url = "none"
};

int g_spawnTimes[MAXPLAYERS];

public void OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("player_disconnect", OnPlayerDisconnect);

    RegConsoleCmd("sm_help", HelpCmd, "Display useful command");

    for(int i = 0; i < MAXPLAYERS; i++)
        g_spawnTimes[i] = 0;
}

public void OnClientAuthorized(int client)
{
    if(IsFakeClient(client)) return;
    char join_userid[MAX_NAME_LENGTH];
    char join_ip[MAX_NAME_LENGTH];
    char join_name[MAX_NAME_LENGTH];
    char join_country[MAX_NAME_LENGTH];
    char join_time[MAX_NAME_LENGTH];
    int unixTime;

    unixTime = GetTime();
    FormatTime(join_time, sizeof(join_time), "%H:%M:%S", unixTime);
    GetClientAuthId(client, AuthId_Steam2, join_userid, sizeof(join_userid));
    GetClientIP(client, join_ip, sizeof(join_ip), true);
    GetClientName(client, join_name, sizeof(join_name));
    GeoipCountry(join_ip, join_country, sizeof(join_country));
    LogMessage("%s (%s) - %s connected to server.", join_name, join_userid, join_ip);
    PrintToServer("%s %s (%s) - %s connected to server.", join_time, join_name, join_userid, join_ip);
}

public void OnClientPutInServer(int client)
{
    if(IsFakeClient(client)) return;
    char name[32];
    char ip[32];
    char country[32];

    GetClientName(client, name, sizeof(name));
    GetClientIP(client, ip, sizeof(ip));
    GeoipCountry(ip, country, sizeof(country));
    if(StrEqual(country, ""))
        country = "LAN";
    PrintToChatAll(" \x06Welcome \x03%s\x06! connected from \x0E%s\x06.", name, country);
}

public void OnClientDisconnect(int client)
{
    if(IsFakeClient(client)) return;

    char leaveName[MAX_NAME_LENGTH];

    GetClientName(client, leaveName, sizeof(leaveName));
    PrintToChatAll("%s left from the server Q_Q", leaveName);

    g_spawnTimes[client] = 0;
}

Action OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(IsFakeClient(client)) return;

    g_spawnTimes[client]++;

    if(g_spawnTimes[client] == 1)
    {
        CreateTimer(2.0, Timer_Respawn, client);
    }
    // else
    //     UnhookEvent(name, OnPlayerSpawn, EventHookMode_Post);
}

Action OnPlayerDisconnect(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(IsFakeClient(client)) return;

    char leaveReason[64];
    char playerName[64];
    char playerIP[64];
    char playerID[64];
    char leaveTime[64];
    int unixTime;

    g_spawnTimes[client] = 0;
    unixTime = GetTime();
    FormatTime(leaveTime, sizeof(leaveTime), "%H:%M:%S", unixTime);
    GetEventString(event, "reason", leaveReason, sizeof(leaveReason));
    GetClientName(client, playerName, sizeof(playerName));
    GetClientIP(client, playerIP, sizeof(playerIP));
    GetClientAuthId(client, AuthId_Steam2, playerID, sizeof(playerID));
    PrintToServer("%s %s (%s) - %s disconnected. (%s)", leaveTime, playerName, playerID, playerIP, leaveReason);
    LogMessage("%s (%s) - %s disconnected. (%s)", playerName, playerID, playerIP, leaveReason);
    if(!IsClientInGame(client))
        UnhookEvent(name, OnPlayerDisconnect);
}

Action HelpCmd(int client, int args)
{
    int randomSeed = GetRandomFloat()
    return Plugin_Continue;
}

Action Timer_Respawn(Handle timer, int client)
{
    char playerName[32];
    char hostname[32];

    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
    
    GetClientName(client, playerName, sizeof(playerName));
    PrintToChat(client, " \x06Hello \x0E%s! \x06Welcome to %s ^_^", playerName, hostname);
    PrintToChat(client, " \x06Please be friendly, remember: \x02admin's watching you fap!");
}
