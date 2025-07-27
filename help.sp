/**
 * [STATUS] Deprecated / WIP
 * [WARNING] This plugin contains coding smells and logic errors.
 *           It is not recommended for production use.
 *
 * [TODO]
 * - Requires full refactor.
 * - Fix logic errors (if needed).
 * - Recall my brain what the f is going on here.
 *
 * Use at your own risk.
 */

#pragma semicolon 1

#include <sourcemod>
#include <geoip>

public Plugin myinfo =
{
	name		= "My Helper",
	author		= "i.car",
	description = "Display useful message and command",
	version		= "1.0",
	url			= "none"
};

float g_fRandomTimeInterval = 60.0;
int	  g_PlayerFirstJoin[64];

public void OnPluginStart()
{
	HookEvent("player_team", OnPlayerChangeTeam);
	HookEvent("player_disconnect", OnPlayerDisconnect);

	RegConsoleCmd("sm_help", HelpCmd, "Display useful command");

	CreateTimer(g_fRandomTimeInterval, Timer_MessageSender, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	for (int i = 1; i < MaxClients; i++)
	{
		g_PlayerFirstJoin[i] = 0;
	}
}

public void OnClientAuthorized(int client)
{
	if (IsFakeClient(client)) return;
	char join_userid[MAX_NAME_LENGTH];
	char join_ip[MAX_NAME_LENGTH];
	char join_name[MAX_NAME_LENGTH];
	char join_country[MAX_NAME_LENGTH];
	char join_time[MAX_NAME_LENGTH];
	int	 unixTime;

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
	if (IsFakeClient(client)) return;
	char name[32];
	char ip[32];
	char country[32];

	GetClientName(client, name, sizeof(name));
	GetClientIP(client, ip, sizeof(ip));
	GeoipCountry(ip, country, sizeof(country));
	if (StrEqual(country, ""))
		country = "LAN";
	PrintToChatAll(" \x06Welcome \x03%s\x06! connected from \x0E%s\x06.", name, country);
}

Action OnPlayerChangeTeam(Event event, char[] name, bool dontBroadcast)
{
	int	 client = GetClientOfUserId(event.GetInt("userid"));
	char playerName[32];
	char hostname[32];

	GetClientName(client, playerName, sizeof(playerName));
	GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
	// PrintToChat(client, " \x06Please be friendly, remember: \x02admin's watching you fap!");

	if (!g_PlayerFirstJoin[client])
	{
		PrintToChat(client, " \x06Hello \x0E%s\x06! \x06Welcome to %s ^_^", playerName, hostname);
	}

	g_PlayerFirstJoin[client] = 1;

	return Plugin_Continue;
}

Action OnPlayerDisconnect(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsFakeClient(client)) return Plugin_Handled;

	char leaveReason[64];
	char playerName[64];
	char playerIP[64];
	char playerID[64];
	char leaveTime[64];
	int	 unixTime;

	g_PlayerFirstJoin[client] = 0;
	unixTime				  = GetTime();
	FormatTime(leaveTime, sizeof(leaveTime), "%H:%M:%S", unixTime);
	GetEventString(event, "reason", leaveReason, sizeof(leaveReason));
	GetClientName(client, playerName, sizeof(playerName));
	GetClientIP(client, playerIP, sizeof(playerIP));
	GetClientAuthId(client, AuthId_Steam2, playerID, sizeof(playerID));
	PrintToServer("%s %s (%s) - %s disconnected. (%s)", leaveTime, playerName, playerID, playerIP, leaveReason);
	LogMessage("%s (%s) - %s disconnected. (%s)", playerName, playerID, playerIP, leaveReason);
	if (!IsClientInGame(client))
		UnhookEvent(name, OnPlayerDisconnect);

	PrintToChatAll("%s left from the server Q_Q", playerName);

	return Plugin_Continue;
}

Action HelpCmd(int client, int args)
{
	PrintToChat(client, " \x06Server command: \x02!res\x06, \x02!luck");
	return Plugin_Continue;
}

Action Timer_MessageSender(Handle timer)
{
	g_fRandomTimeInterval = GetRandomFloat(60.0, 120.0);

	int randomSeed		  = GetRandomInt(0, 10);

	switch (randomSeed)
	{
		case 0:
			PrintToChatAll("Useful command: !res, !luck, !info");
		case 1:
			PrintToChatAll("Server has no host routine yet :<");
		case 2:
			PrintToChatAll("Server has no rule, have fun and be friendly ^_^");
		case 3:
			PrintToChatAll(" \x06Hint: you can cost \x09800$ \x06to revive once by typing \x02!res");
		case 4:
			PrintToChatAll(" \x06Hint: typing \x02!luck \x06can throw a dice once, it has 60 seconds cooldown.");
		case 5:
			PrintToChatAll("Server IP: caveman-cs.asuscomm.com:27087");
		default:
			PrintToChatAll("Server is on progress = unko bug saba :(");
	}

	return Plugin_Continue;
}