#pragma semicolon 1

#include <sourcemod>

Handle g_hTimer       = null;
Handle g_hHudSync     = null;

int    g_iC4Timer     = 0;
bool   g_bIsCSGO      = false;
bool   g_bBombPlanted = false;

public Plugin myinfo =
{
    name        = "C4 Countdown Timer",
    author      = "i.car",
    description = "Shows C4 countdown timer with HUD",
    version     = "1.1",
    url         = ""
};

public void OnPluginStart()
{
    // Initialize HUD synchronizer
    g_hHudSync = CreateHudSynchronizer();
    if (g_hHudSync == null)
    {
        SetFailState("Failed to create HUD synchronizer");
    }

    // Hook all necessary events
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("bomb_planted", Event_BombPlanted);
    HookEvent("bomb_begindefuse", Event_BombBeginDefuse);
    HookEvent("bomb_abortdefuse", Event_BombAbortDefuse);
    HookEvent("bomb_defused", Event_BombDefused);
    HookEvent("bomb_exploded", Event_BombExploded);

    // Check game mode
    CheckGameMode();
}

public void OnPluginEnd()
{
    // Clean up resources when plugin ends
    CleanupTimer();
    ClearAllHud();

    if (g_hHudSync != null)
    {
        delete g_hHudSync;
        g_hHudSync = null;
    }
}

public void OnMapStart()
{
    // Reset state when map starts
    ResetPluginState();
    CheckGameMode();
}

public void OnMapEnd()
{
    // Clean up when map ends
    CleanupTimer();
    ClearAllHud();
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Reset state when round starts
    ResetPluginState();
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // Clean up all resources when round ends
    CleanupTimer();
    ClearAllHud();
    ResetPluginState();
    return Plugin_Continue;
}

public Action Event_BombPlanted(Event event, const char[] name, bool dontBroadcast)
{
    // Ensure previous timer is cleaned up
    CleanupTimer();

    // Get C4 countdown time
    ConVar cvar = FindConVar("mp_c4timer");
    if (cvar == null)
    {
        LogError("Failed to find mp_c4timer ConVar");
        return Plugin_Continue;
    }

    g_iC4Timer     = cvar.IntValue;
    g_bBombPlanted = true;

    // Create new timer
    g_hTimer       = CreateTimer(1.0, Timer_BombCounting, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Continue;
}

public Action Event_BombBeginDefuse(Event event, const char[] name, bool dontBroadcast)
{
    if (g_hHudSync == null) return Plugin_Continue;

    // Show defuse notification
    SetHudTextParams(-1.0, 0.2, 10.0, 255, 0, 0, 255, 0);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            ShowSyncHudText(i, g_hHudSync, "Someone is defusing the bomb!");
        }
    }

    return Plugin_Continue;
}

public Action Event_BombAbortDefuse(Event event, const char[] name, bool dontBroadcast)
{
    if (g_hHudSync == null) return Plugin_Continue;

    // Clear defuse notification
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            ClearSyncHud(i, g_hHudSync);
        }
    }

    return Plugin_Continue;
}

public Action Event_BombDefused(Event event, const char[] name, bool dontBroadcast)
{
    // Clean up timer and HUD
    CleanupTimer();
    ClearAllHud();

    // Show defuse success message
    PrintHintTextToAll("Bomb has been defused!");

    g_bBombPlanted = false;
    return Plugin_Continue;
}

public Action Event_BombExploded(Event event, const char[] name, bool dontBroadcast)
{
    // Clean up timer and HUD
    CleanupTimer();
    ClearAllHud();

    // Show explosion message
    PrintHintTextToAll("Bomb exploded!");

    g_bBombPlanted = false;
    return Plugin_Continue;
}

public Action Timer_BombCounting(Handle timer)
{
    // Check if timer is still valid
    if (timer != g_hTimer)
    {
        LogError("Timer mismatch detected, stopping timer");
        return Plugin_Stop;
    }

    // If bomb no longer exists, stop timer
    if (!g_bBombPlanted)
    {
        // LogMessage("Bomb no longer planted, stopping timer");
        return Plugin_Stop;
    }

    // If time is up, stop timer
    if (g_iC4Timer <= 0)
    {
        // LogMessage("Timer reached zero, stopping");
        return Plugin_Stop;
    }

    // Display countdown
    if (g_bIsCSGO)
    {
        PrintHintTextToAll("C4 Timer: <font color='#ff0000'>%d</font>", g_iC4Timer);
    }
    else
    {
        PrintHintTextToAll("C4 Timer: %d", g_iC4Timer);
    }

    g_iC4Timer--;
    return Plugin_Continue;
}

// Function to clean up timer
void CleanupTimer()
{
    if (g_hTimer != null)
    {
        KillTimer(g_hTimer);
        g_hTimer = null;
        // LogMessage("Timer cleaned up");
    }
}

// Function to clear all player HUDs
void ClearAllHud()
{
    if (g_hHudSync == null) return;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            ClearSyncHud(i, g_hHudSync);
        }
    }
}

// Reset plugin state
void ResetPluginState()
{
    g_iC4Timer     = 0;
    g_bBombPlanted = false;
}

// Check game mode
void CheckGameMode()
{
    EngineVersion engine = GetEngineVersion();
    g_bIsCSGO            = false;

    if (engine == Engine_CSGO)
    {
        // Check if it's CS:GO (by checking for specific ConVar)
        ConVar cvar = FindConVar("mp_flashlight");
        if (cvar == null)
        {
            g_bIsCSGO = true;
            LogMessage("Detected CS:GO engine");
        }
        else
        {
            LogMessage("Detected CS:S engine");
        }
    }
    else if (engine == Engine_CSS)
    {
        LogMessage("Detected Counter-Strike: Source");
    }
    else
    {
        LogError("Unsupported game engine: %d", engine);
        SetFailState("This plugin only supports Counter-Strike games");
    }
}
