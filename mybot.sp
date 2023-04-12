#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <map_workshop_functions>

int g_playerNum;
int g_roundNum;
int g_playerTeamIndex;
int g_winningStreak;
int g_loosingStreak;
int g_botRespawningTimes;
bool g_notMissionMap;
bool g_isRoundEnd;

char g_mapName[32];

Handle Handle_HUD;
Handle Handle_HUDTimer;


public Plugin myinfo =
{
    name = "MyBot",
    author = "i.car",
    description = "My BOT controller.",
    version = "0.0.8.7",
    url = ""
};

public void OnPluginStart()
{
    g_playerNum = 0;
    RegConsoleCmd("sm_info", Command_Info, "information");
    HookEvent("round_start", OnRoundStart);
    HookEvent("round_end", OnRoundEnd);
    HookEvent("bomb_planted", OnMissionGoing);
    HookEvent("hostage_follows", OnMissionGoing);
    HookEvent("player_death", OnPlayerDeath);

    AddCommandListener(CMD_BlockBotDropWpn, "drop");

    Handle_HUD = CreateHudSynchronizer();
}

public void OnMapStart()
{
    char mapFile[32];

    GetCurrentMap(mapFile, 32);
    RemoveMapPath(mapFile, g_mapName, 32);
    g_roundNum = 0;
    g_playerTeamIndex = 0;
    g_winningStreak = 0;
    g_loosingStreak = 0;
    g_botRespawningTimes = 20;
    
    ServerCommand("bot_join_after_player 1");
    // ServerCommand("mp_randomspawn 0");

    if(g_mapName[0] == 'd' && g_mapName[1] == 'e')
    {
        g_playerTeamIndex = CS_TEAM_T;
        g_notMissionMap = false;
        ServerCommand("mp_humanteam T");
        ServerCommand("bot_join_team CT");
    }
    else if(g_mapName[0] == 'c' && g_mapName[1] == 's')
    {
        g_playerTeamIndex = CS_TEAM_CT;
        g_notMissionMap = false;
        ServerCommand("mp_humanteam CT");
        ServerCommand("bot_join_team T");
    }
    else
    {
        g_notMissionMap = true;
        g_botRespawningTimes = 0;
        ServerCommand("mp_humanteam CT");
        ServerCommand("bot_join_team T");
        LogMessage("NOT A STANDARD MISSION MAP!");
    }
    ServerCommand("bot_difficulty 0");
    ServerCommand("bot_quota 15");
}


Action Command_Info(int client, int args)
{
    ConVar botDifficulty = FindConVar("bot_difficulty");
    int difficultyNum = GetConVarInt(botDifficulty);

    PrintToChat(client, "Map: %s", g_mapName);
    PrintToChat(client, "Players: %d", g_playerNum);
    
    switch(difficultyNum)
    {
        case 0:
            PrintToChatAll("Difficulty: Noob (Level %d)", difficultyNum);
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
    
    g_playerNum = 0;
    g_isRoundEnd = false;

    if(g_notMissionMap)
        g_botRespawningTimes = 0;
    else
        g_botRespawningTimes = 20;

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientConnected(i) && !IsFakeClient(i) && IsPlayerAlive(i))
            g_playerNum++;
    }

    if(g_roundNum == 0)
    {
        ServerCommand("mp_warmuptime 60");
        ServerCommand("sm_cvar bot_stop 1");

        for(int i = 1; i < MAXPLAYERS; i++)
        {
            if(IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i))
                SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
        }
    }
    else if(g_roundNum > 0 && g_roundNum < 9)
    {
        int difficultyNum = GetConVarInt(botDifficulty);

        ServerCommand("sm_cvar bot_stop 0");

        for(int i = 1; i < MAXPLAYERS; i++)
        {
            if(IsClientInGame(i) && IsFakeClient(i))
            {
                Client_SetMoney(i, 0);
                if(!g_notMissionMap)
                    GiveBotWeapon(i);
            }
        }

        switch(difficultyNum)
        {
            case 0:
                PrintToChatAll("Difficulty: Easy (Level %d)", difficultyNum); // easy
            case 1:
                PrintToChatAll("Difficulty: Normal (Level %d)", difficultyNum); // fair
            case 2:
                PrintToChatAll("Difficulty: Hard (Level %d)", difficultyNum); // normal
            case 3:
                PrintToChatAll("Difficulty: Expert (Level %d)", difficultyNum); // tough
            default:
                PrintToChatAll("Difficulty: Unknown (Level %d)", difficultyNum); // hard
        }

        PrintToChatAll("Rounds: %d", g_roundNum);
        PrintToChatAll("Players: %d", g_playerNum);
        PrintToChatAll("BOT respawning times: \x02%d", g_botRespawningTimes);
        
        Handle_HUDTimer = CreateTimer(0.5, Timer_HUD, _, TIMER_REPEAT);
    }
    
    if(g_roundNum == 9)
    {
        ServerCommand("sm_cvar bot_stop 1");
        EndGame();
    }

    g_roundNum++;

    return Plugin_Continue;
}


Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if(g_roundNum == 0) return Plugin_Handled;

    ConVar botDifficulty = FindConVar("bot_difficulty");
    int winnerTeam = GetEventInt(event, "winner");
    int difficultyNum = GetConVarInt(botDifficulty);

    g_isRoundEnd = true;

    if(winnerTeam == g_playerTeamIndex)
    {
        g_winningStreak++;
        g_loosingStreak = 0;
    }
    else
    {
        g_loosingStreak++;
        g_winningStreak = 0;
    }

    if(Handle_HUDTimer != null)
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

Action OnPlayerDeath(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(IsFakeClient(client) && GetClientTeam(client) != g_playerTeamIndex && g_botRespawningTimes > 0 && !g_isRoundEnd)
        CreateTimer(1.0, Timer_Respawn, client);
    
    return Plugin_Continue;
}

void EndGame() // force end game will make end game vote won't be fired
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
    // int playerScore = 0;

    // playerScore = GetTeamScore(g_playerTeamIndex);
    
    for(int i = 1; i < MaxClients; i++)
    {
        if(IsClientInGame(i) && IsClientConnected(i) && IsFakeClient(i))
            ForcePlayerSuicide(i);
    }
    
    //SetTeamScore(g_playerTeamIndex, playerScore - 1);
    ServerCommand("sm_cvar bot_stop 1");
}

void SetDifficulty(int difficultyNum, ConVar botDifficulty)
{
    if(g_winningStreak > 2)
        SetConVarInt(botDifficulty, difficultyNum + 1);
    
    if(g_loosingStreak > 1 && difficultyNum - 1 >= 0)
        SetConVarInt(botDifficulty, difficultyNum - 1);

    //ServerCommand("bot_kick");
    for(int i = 1; i < MaxClients; i++)
    {
        if(IsClientInGame(i) && IsFakeClient(i) && !IsSpecialBot(i))
        {
            KickClient(i, "");
        }
    }
    
    ServerCommand("bot_quota 15");
}

Action Timer_Respawn(Handle timer, int client)
{
    CS_RespawnPlayer(client);
    if(g_roundNum > 2)
        GiveBotWeapon(client);
    g_botRespawningTimes--;

    return Plugin_Continue;
}

Action Timer_HUD(Handle timer)
{
    SetHudTextParams(-1.0, 0.1, 0.1, 0, 0, 0, 255, 2, 6.0, 0.1, 0.2);
    for(int i = 1; i < MAXPLAYERS; i++)
    {
        ShowSyncHudText(i, Handle_HUD, "BOTs remaining: %d", g_botRespawningTimes);
    }

    return Plugin_Continue;
}


void GiveBotWeapon(int client)
{
    int mainWeapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

    if(g_roundNum < 2)
    {
        if(IsSpecialBot(client))
        {
            char botName[32];

            GetClientName(client, botName, sizeof(botName));

            if(StrEqual(botName, "[ELITE]EagleEye"))
            {
                if(mainWeapon != -1)
                    {
                        char weaponName[32];
                        
                        GetClientWeapon(client, weaponName, sizeof(weaponName));
                        if(!StrEqual(weaponName, "weapon_deagle"))
                        {
                            CS_DropWeapon(client, mainWeapon, false);
                            GivePlayerItem(client, "weapon_deagle");
                        }
                    }
                    else
                        GivePlayerItem(client, "weapon_deagle");
            }
        }
    }
    else
    {
        if(IsSpecialBot(client))
        {
            char botName[32];

            GetClientName(client, botName, sizeof(botName));

            if(StrEqual(botName, "[ELITE]EagleEye"))
            {
                if(mainWeapon != -1)
                    {
                        char weaponName[32];
                        
                        GetClientWeapon(client, weaponName, sizeof(weaponName));
                        if(!StrEqual(weaponName, "weapon_awp"))
                        {
                            CS_DropWeapon(client, mainWeapon, false);
                            GivePlayerItem(client, "weapon_awp");
                        }
                    }
                    else
                        GivePlayerItem(client, "weapon_awp");
            }
            else if(StrEqual(botName, "[ELITE]mimic"))
            {
                if(GetClientTeam(client) == CS_TEAM_CT)
                {
                    if(mainWeapon != -1)
                    {
                        char weaponName[32];
                        
                        GetClientWeapon(client, weaponName, sizeof(weaponName));
                        if(!StrEqual(weaponName, "weapon_m4a1"))
                        {
                            CS_DropWeapon(client, mainWeapon, false);
                            GivePlayerItem(client, "weapon_m4a1");
                        }
                    }
                    else
                        GivePlayerItem(client, "weapon_m4a1");
                }
                else if(GetClientTeam(client) == CS_TEAM_T)
                {
                    if(mainWeapon != -1)
                    {
                        char weaponName[32];
                        
                        GetClientWeapon(client, weaponName, sizeof(weaponName));
                        if(!StrEqual(weaponName, "weapon_ak47"))
                        {
                            CS_DropWeapon(client, mainWeapon, false);
                            GivePlayerItem(client, "weapon_ak47");
                        }
                    }
                    else
                        GivePlayerItem(client, "weapon_ak47");
                }
            }
            else if(StrEqual(botName, "[★★★]Rush"))
            {
                if(mainWeapon != -1)
                    {
                        char weaponName[32];
                        
                        GetClientWeapon(client, weaponName, sizeof(weaponName));
                        if(!StrEqual(weaponName, "weapon_p90"))
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
            if(GetClientTeam(client) == CS_TEAM_CT)
            {
                if(mainWeapon != -1)
                {
                    char weaponName[32];
                    
                    GetClientWeapon(client, weaponName, sizeof(weaponName));
                    if(!StrEqual(weaponName, "weapon_m4a1"))
                    {
                        CS_DropWeapon(client, mainWeapon, false);
                        GivePlayerItem(client, "weapon_m4a1");
                    }
                }
                else
                    GivePlayerItem(client, "weapon_m4a1");
            }
            else if(GetClientTeam(client) == CS_TEAM_T)
            {
                if(mainWeapon != -1)
                {
                    char weaponName[32];
                    
                    GetClientWeapon(client, weaponName, sizeof(weaponName));
                    if(!StrEqual(weaponName, "weapon_ak47"))
                    {
                        CS_DropWeapon(client, mainWeapon, false);
                        GivePlayerItem(client, "weapon_ak47");
                    }
                }
                else
                    GivePlayerItem(client, "weapon_ak47");
            }
        }
    }
}

bool IsSpecialBot(int client)
{
    char names[3][] = {"[ELITE]EagleEye", "[ELITE]mimic", "[★★★]Rush"};
    char botName[32];
    
    GetClientName(client, botName, sizeof(botName));

    for(int i = 0; i < 3; i++)
    {
        if(StrEqual(botName, names[i]))
            return true;
    }

    return false;
}

public Action CMD_BlockBotDropWpn(int client, const char[] command, int argc)
{
    if(IsFakeClient(client))
        return Plugin_Handled;
    
    return Plugin_Continue;
}