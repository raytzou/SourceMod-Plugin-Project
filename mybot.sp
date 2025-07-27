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
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <map_workshop_functions>

int	   g_playerNum;
int	   g_roundNum;
int	   g_playerTeamIndex;
int	   g_winningStreak;
int	   g_loosingStreak;
int	   g_botRespawningTimes;
bool   g_notMissionMap;
bool   g_isRoundEnd;

char   g_mapName[32];

Handle Handle_HUD;
Handle Handle_HUDTimer;

public Plugin myinfo =
{
	name		= "MyBot",
	author		= "i.car",
	description = "My BOT controller.",
	version		= "0.0.8.7",
	url			= ""
};

public void OnPluginStart()
{
	Handle_HUD = CreateHudSynchronizer();
	RegConsoleCmd("sm_info", Command_Info, "information");
	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("bomb_planted", OnMissionGoing);
	HookEvent("hostage_follows", OnMissionGoing);
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
	AddCommandListener(CMD_BlockBotDropWpn, "drop");
	PrintToServer("BOT plugin on start");
}

public void OnMapStart()
{
	PrintToServer("BOT plugin on map start");
	char mapFile[32];

	g_roundNum = 0;
	GetCurrentMap(mapFile, 32);
	RemoveMapPath(mapFile, g_mapName, 32);
	g_playerTeamIndex	 = 0;
	g_winningStreak		 = 0;
	g_loosingStreak		 = 0;
	g_botRespawningTimes = 20;

	// ServerCommand("mp_randomspawn 0");
	// ServerCommand("bot_join_after_player 0");
	if (g_mapName[0] == 'd' && g_mapName[1] == 'e')
	{
		g_playerTeamIndex = CS_TEAM_T;
		g_notMissionMap	  = false;
		ServerCommand("mp_humanteam T");
		// ServerCommand("bot_join_team CT");
	}
	else if (g_mapName[0] == 'c' && g_mapName[1] == 's')
	{
		g_playerTeamIndex = CS_TEAM_CT;
		g_notMissionMap	  = false;
		ServerCommand("mp_humanteam CT");
		// ServerCommand("bot_join_team T");
	}
	else
	{
		g_notMissionMap		 = true;
		g_botRespawningTimes = 0;
		ServerCommand("mp_humanteam CT");
		// ServerCommand("bot_join_team T");
		LogMessage("NOT A STANDARD MISSION MAP!");
	}

	ServerCommand("bot_difficulty 0");
}

Action Command_Info(int client, int args)
{
	ConVar botDifficulty = FindConVar("bot_difficulty");
	int	   difficultyNum = GetConVarInt(botDifficulty);

	PrintToChat(client, "Map: %s", g_mapName);
	PrintToChat(client, "Player(s): %d", g_playerNum);
	PrintToChat(client, "Round: %d", g_roundNum);

	switch (difficultyNum)
	{
		case 0:
			PrintToChatAll("Difficulty: Easy (Level %d)", difficultyNum);
		case 1:
			PrintToChatAll("Difficulty: Normal (Level %d)", difficultyNum);
		case 2:
			PrintToChatAll("Difficulty: Hard (Level %d)", difficultyNum);
		case 3:
			PrintToChatAll("Difficulty: Expert (Level %d)", difficultyNum);
		default:
			PrintToChatAll("Difficulty: Unknown (Level %d)", difficultyNum);
	}

	return Plugin_Continue;
}

Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ConVar botDifficulty = FindConVar("bot_difficulty");

	// cheatToggler.Flags &= ~FCVAR_NOTIFY; // disable notify flag

	g_playerNum			 = 0;
	g_isRoundEnd		 = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i) && IsPlayerAlive(i))
			g_playerNum++;
	}

	if (g_playerNum == 0) return Plugin_Handled;

	PrintToServer("g_roundNum++ / %d", g_roundNum);

	if (g_notMissionMap)
	{
		g_botRespawningTimes = 0;
	}
	else
	{
		g_botRespawningTimes = 20;
	}

	if (GameRules_GetProp("m_bWarmupPeriod") == 1)
	{
		ServerCommand("bot_kick");
		InitSpecialBot();
		ServerCommand("sm_cvar bot_stop 1");

		/**
		 * I don't want everyone kills each other in warmup.
		 * by default, there is protection in the begin of warmup then goes dysfunction automatically
		 * so I use Timer here to make protection works again till next round, the game starts
		 */
		CreateTimer(3.0, Timer_WarmupProtection);
	}
	else
		g_roundNum++;

	if (g_roundNum > 0 && g_roundNum < 9)
	{
		int difficultyNum = GetConVarInt(botDifficulty);

		if (GetConVarInt(FindConVar("bot_stop")) == 1)
		{
			ServerCommand("sm_cvar bot_stop 0");
		}

		if (g_playerTeamIndex == CS_TEAM_CT)
		{
			for (int i = 0; i < 10; i++)
			{
				ServerCommand("bot_add_t");
			}
		}
		else if (g_playerTeamIndex == CS_TEAM_T)
		{
			for (int i = 0; i < 10; i++)
			{
				ServerCommand("bot_add_ct");
			}
		}
		for (int i = 1; i < MaxClients; i++)
		{
			if (IsClientInGame(i) && IsFakeClient(i))
			{
				Client_SetMoney(i, 0);
				if (!g_notMissionMap)
				{
					GiveBotWeapon(i);
				}
			}
		}

		switch (difficultyNum)
		{
			case 0:
				PrintToChatAll("Difficulty: Easy (Level %d)", difficultyNum);
			case 1:
				PrintToChatAll("Difficulty: Normal (Level %d)", difficultyNum);
			case 2:
				PrintToChatAll("Difficulty: Hard (Level %d)", difficultyNum);
			case 3:
				PrintToChatAll("Difficulty: Expert (Level %d)", difficultyNum);
			default:
				PrintToChatAll("Difficulty: Unknown (Level %d)", difficultyNum);
		}

		PrintToChatAll("Rounds: %d", g_roundNum);
		PrintToChatAll("Players: %d", g_playerNum);
		PrintToChatAll("BOT respawning times: \x02%d", g_botRespawningTimes);

		Handle_HUDTimer = CreateTimer(1.0, Timer_HUD, _, TIMER_REPEAT);
	}
	else if (g_roundNum == 9)
	{
		ServerCommand("sm_cvar bot_stop 1");

		/**
		 * this timing idk
		 */
		// int playerTeamScore = 0;

		// playerTeamScore = GetTeamScore(g_playerTeamIndex);
		// SetTeamScore(g_playerTeamIndex, playerTeamScore - 1);

		EndGame();
	}

	SetSpecialBotScore();

	return Plugin_Continue;
}

Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_roundNum == 0) return Plugin_Handled;

	ConVar botDifficulty = FindConVar("bot_difficulty");
	int	   winnerTeam	 = GetEventInt(event, "winner");
	int	   difficultyNum = GetConVarInt(botDifficulty);

	g_isRoundEnd		 = true;

	if (winnerTeam == g_playerTeamIndex)
	{
		g_winningStreak++;
		g_loosingStreak = 0;
	}
	else
	{
		g_loosingStreak++;
		g_winningStreak = 0;
	}

	if (Handle_HUDTimer != null)
	{
		KillTimer(Handle_HUDTimer);
		Handle_HUDTimer = null;
	}

	SetDifficulty(difficultyNum, botDifficulty);
	// ServerCommand("mp_randomspawn 0");

	return Plugin_Continue;
}

Action OnMissionGoing(Event event, char[] name, bool dontBroadcast)
{
	PrintToChatAll("BOT remaining: \x02%d", g_botRespawningTimes);
	// ServerCommand("mp_randomspawn 0");
	return Plugin_Continue;
}

Action OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int	 client = GetClientOfUserId(event.GetInt("userid"));
	char clientName[32];

	GetClientName(client, clientName, sizeof(clientName));

	/**
	 * ServerCommand("bot_add_t [ELITE]EagleEye");
		ServerCommand("bot_add_t [ELITE]mimic");
		ServerCommand("bot_add_t [EXPERT]Rush");
	 */
	//"models/weapons/t_arms_leet.mdl"
	//"models/weapons/ct_arms_st6.mdl"
	if (StrEqual(clientName, "[ELITE]EagleEye"))
	{
		SetEntityHealth(client, 150);
	}
	else if (StrEqual(clientName, "[ELITE]mimic"))
	{
		SetEntityHealth(client, 200);
	}
	else if (StrEqual(clientName, "[EXPERT]Rush"))
	{
		SetEntityHealth(client, 250);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 2.0);
	}

	return Plugin_Continue;
}

Action OnPlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	// GetClientTeam(client) != g_playerTeamIndex &&
	if (IsFakeClient(client) && !IsSpecialBot(client) && !IsHelper(client) && g_botRespawningTimes > 0 && !g_isRoundEnd)
	{
		CreateTimer(1.0, Timer_Respawn, client);
	}

	return Plugin_Continue;
}

void EndGame()	  // force end game will make end game vote won't be fired
{
	// https://developer.valvesoftware.com/wiki/Game_end
	// https://developer.valvesoftware.com/wiki/Game_round_end
	// int iGameEnd  = FindEntityByClassname(-1, "game_end");

	// ConVar roundTime = FindConVar("mp_roundtime");
	// ConVar gameTime = FindConVar("mp_timelimit");

	// SetConVarFloat(roundTime, (1.0 / 60.0), false, false);
	// SetConVarFloat(gameTime, (1.0 / 60.0), false, false);

	// if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1)
	// {
	//     LogError("Unable to create entity \"game_end\"!");
	// }
	// else
	// {
	//     AcceptEntityInput(iGameEnd, "EndGame");

	// }

	int teamScore = CS_GetTeamScore(g_playerTeamIndex);

	CS_SetTeamScore(g_playerTeamIndex, (teamScore - 1));

	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && !IsSpecialBot(i))
		{
			KickClient(i, "");
		}
	}
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientConnected(i) && IsFakeClient(i))
			ForcePlayerSuicide(i);
	}

	ServerCommand("sm_cvar bot_stop 1");
}

void SetDifficulty(int difficultyNum, ConVar botDifficulty)
{
	if (g_winningStreak > 2)
		SetConVarInt(botDifficulty, difficultyNum + 1);

	if (g_loosingStreak > 1 && difficultyNum - 1 >= 0)
		SetConVarInt(botDifficulty, difficultyNum - 1);

	ServerCommand("bot_kick");
	InitSpecialBot();
	// for(int i = 1; i < MaxClients; i++)
	// {
	//     if(IsClientInGame(i) && IsFakeClient(i) && !IsSpecialBot(i) && !IsHelper(i))
	//     {
	//         KickClient(i, "");
	//     }
	// }

	// ServerCommand("bot_quota 8");
}

Action Timer_Respawn(Handle timer, int client)
{
	CS_RespawnPlayer(client);
	if (g_roundNum > 1)
		GiveBotWeapon(client);
	g_botRespawningTimes--;

	return Plugin_Continue;
}

Action Timer_HUD(Handle timer)
{
	SetHudTextParams(-1.0, 0.1, 1.0, 0, 0, 0, 255, 2, 1.0, 0.1, 0.2);
	if (Handle_HUDTimer != timer)
	{
		Handle_HUDTimer = timer;
	}
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ShowSyncHudText(i, Handle_HUD, "BOTs remaining: %d", g_botRespawningTimes);
		}
	}

	return Plugin_Continue;
}

Action Timer_WarmupProtection(Handle timer)
{
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
		}
	}
	return Plugin_Continue;
}

void GiveBotWeapon(int client)
{
	if (g_roundNum < 2)
	{
		int secWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
		if (IsSpecialBot(client))
		{
			char botName[32];

			GetClientName(client, botName, sizeof(botName));

			if (StrEqual(botName, "[ELITE]EagleEye"))
			{
				if (secWeapon != -1)
				{
					CS_DropWeapon(client, secWeapon, true);
					GivePlayerItem(client, "weapon_deagle");
				}
				else
					GivePlayerItem(client, "weapon_deagle");
			}
		}
	}
	else if (g_roundNum < 9)
	{
		int mainWeapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
		if (IsSpecialBot(client))
		{
			char botName[32];

			GetClientName(client, botName, sizeof(botName));

			if (StrEqual(botName, "[ELITE]EagleEye"))
			{
				if (mainWeapon != -1)
				{
					char weaponName[32];

					GetClientWeapon(client, weaponName, sizeof(weaponName));
					if (!StrEqual(weaponName, "weapon_awp"))
					{
						CS_DropWeapon(client, mainWeapon, false);
						GivePlayerItem(client, "weapon_awp");
					}
				}
				else
					GivePlayerItem(client, "weapon_awp");
			}
			else if (StrEqual(botName, "[ELITE]mimic"))
			{
				if (GetClientTeam(client) == CS_TEAM_CT)
				{
					if (mainWeapon != -1)
					{
						char weaponName[32];

						GetClientWeapon(client, weaponName, sizeof(weaponName));
						if (!StrEqual(weaponName, "weapon_m4a1"))
						{
							CS_DropWeapon(client, mainWeapon, false);
							GivePlayerItem(client, "weapon_m4a1");
						}
					}
					else
						GivePlayerItem(client, "weapon_m4a1");
				}
				else if (GetClientTeam(client) == CS_TEAM_T)
				{
					if (mainWeapon != -1)
					{
						char weaponName[32];

						GetClientWeapon(client, weaponName, sizeof(weaponName));
						if (!StrEqual(weaponName, "weapon_ak47"))
						{
							CS_DropWeapon(client, mainWeapon, false);
							GivePlayerItem(client, "weapon_ak47");
						}
					}
					else
						GivePlayerItem(client, "weapon_ak47");
				}
			}
			else if (StrEqual(botName, "[EXPERT]Rush"))
			{
				if (mainWeapon != -1)
				{
					char weaponName[32];

					GetClientWeapon(client, weaponName, sizeof(weaponName));
					if (!StrEqual(weaponName, "weapon_p90"))
					{
						CS_DropWeapon(client, mainWeapon, false);
						GivePlayerItem(client, "weapon_p90");
					}
				}
				else
					GivePlayerItem(client, "weapon_p90");
			}
		}
		else
		{
			if (GetClientTeam(client) == CS_TEAM_CT)
			{
				if (mainWeapon != -1)
				{
					char weaponName[32];

					GetClientWeapon(client, weaponName, sizeof(weaponName));
					if (!StrEqual(weaponName, "weapon_famas"))
					{
						CS_DropWeapon(client, mainWeapon, false);
						GivePlayerItem(client, "weapon_famas");
					}
				}
				else
					GivePlayerItem(client, "weapon_famas");
			}
			else if (GetClientTeam(client) == CS_TEAM_T)
			{
				if (mainWeapon != -1)
				{
					char weaponName[32];

					GetClientWeapon(client, weaponName, sizeof(weaponName));
					if (!StrEqual(weaponName, "weapon_galilar"))
					{
						CS_DropWeapon(client, mainWeapon, false);
						GivePlayerItem(client, "weapon_galilar");
					}
				}
				else
					GivePlayerItem(client, "weapon_galilar");
			}
		}
	}
}

bool IsSpecialBot(int client)
{
	char names[3][] = { "[ELITE]EagleEye", "[ELITE]mimic", "[EXPERT]Rush" };
	char botName[32];

	GetClientName(client, botName, sizeof(botName));

	for (int i = 0; i < 3; i++)
	{
		if (StrEqual(botName, names[i]))
			return true;
	}

	return false;
}

bool IsHelper(int client)
{
	char helps[5][] = { "[ZAKO]Helper1", "[ZAKO]Helper2", "[ZAKO]Helper3", "[ZAKO]Helper4", "[ZAKO]Helper5" };
	char botName[32];

	GetClientName(client, botName, sizeof(botName));

	for (int i = 0; i < 5; i++)
	{
		if (StrEqual(botName, helps[i]))
			return true;
	}

	return false;
}

void InitSpecialBot()
{
	if (g_playerTeamIndex == CS_TEAM_CT)
	{
		ServerCommand("bot_add_t [ELITE]EagleEye");
		ServerCommand("bot_add_t [ELITE]mimic");
		ServerCommand("bot_add_t [EXPERT]Rush");
		ServerCommand("bot_add_ct [ZAKO]Helper1");
		ServerCommand("bot_add_ct [ZAKO]Helper2");
		ServerCommand("bot_add_ct [ZAKO]Helper3");
		ServerCommand("bot_add_ct [ZAKO]Helper4");
		ServerCommand("bot_add_ct [ZAKO]Helper5");
	}
	else if (g_playerTeamIndex == CS_TEAM_T)
	{
		ServerCommand("bot_add_ct [ELITE]EagleEye");
		ServerCommand("bot_add_ct [ELITE]mimic");
		ServerCommand("bot_add_ct [EXPERT]Rush");
		ServerCommand("bot_add_t [ZAKO]Helper1");
		ServerCommand("bot_add_t [ZAKO]Helper2");
		ServerCommand("bot_add_t [ZAKO]Helper3");
		ServerCommand("bot_add_t [ZAKO]Helper4");
		ServerCommand("bot_add_t [ZAKO]Helper5");
	}
}

void SetSpecialBotScore()
{
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && IsSpecialBot(i))
		{
			char botName[32];

			GetClientName(i, botName, sizeof(botName));

			if (StrEqual(botName, "[ELITE]mimic"))
			{
				// Client_SetScore(i, 9999); // this API is set kills lol
				CS_SetClientContributionScore(i, 9999);
			}
			else if (StrEqual(botName, "[ELITE]EagleEye"))
			{
				// Client_SetScore(i, 8888);
				CS_SetClientContributionScore(i, 8888);
			}
			else if (StrEqual(botName, "[EXPERT]Rush"))
			{
				// Client_SetScore(i, 7777);
				CS_SetClientContributionScore(i, 7777);
			}
		}
	}
}

public Action CMD_BlockBotDropWpn(int client, const char[] command, int argc)
{
	if (IsFakeClient(client))
		return Plugin_Handled;

	return Plugin_Continue;
}