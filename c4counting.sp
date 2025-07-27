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

Handle Timer_Handler;
Handle Handle_HUD;

int	   g_c4Counting = 0;

public OnPluginStart()
{
	Handle_HUD = CreateHudSynchronizer();
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("bomb_planted", Event_BombPlanted);
	HookEvent("bomb_begindefuse", Event_BombBeginDefuse);
	HookEvent("bomb_abortdefuse", Event_BombAbortDefuse);
	HookEvent("bomb_defused", Event_BombDefused);
	HookEvent("bomb_exploded", Event_BombExploded);
}

public Action Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	TimerKiller();
	return Plugin_Continue;
}

public Action Event_BombPlanted(Event event, char[] name, bool dontBroadcast)
{
	g_c4Counting  = GetConVarInt(FindConVar("mp_c4timer"));
	Timer_Handler = CreateTimer(1.0, Timer_BombCounting, _, TIMER_REPEAT);
	return Plugin_Continue;
}

public Action Event_BombBeginDefuse(Event event, char[] name, bool dontBroadcast)
{
	SetHudTextParams(-1.0, 0.2, 10.0, 255, 0, 0, 255, 0);
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ShowSyncHudText(i, Handle_HUD, "Bomb is being defused!");
		}
	}
	return Plugin_Continue;
}

public Action Event_BombAbortDefuse(Event event, char[] name, bool dontBroadcast)
{
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ClearSyncHud(i, Handle_HUD);
		}
	}
	return Plugin_Continue;
}

public Action Event_BombDefused(Event event, char[] name, bool dontBroadcast)
{
	TimerKiller();
	PrintHintTextToAll("Bomb has been defused!");
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ClearSyncHud(i, Handle_HUD);
		}
	}
	// PrintToChatAll("Bomb has been defused!");
	return Plugin_Continue;
}

public Action Event_BombExploded(Event event, char[] name, bool dontBroadcast)
{
	TimerKiller();
	PrintHintTextToAll("Bomb exploded!");
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ClearSyncHud(i, Handle_HUD);
		}
	}
	// PrintToChatAll("Bomb exploded!");
	return Plugin_Continue;
}

public Action Timer_BombCounting(Handle timer)
{
	PrintHintTextToAll("C4 counting: <font color='#ff0000'>%d</font>", g_c4Counting);
	g_c4Counting--;
	if (Timer_Handler != timer)
	{
		g_c4Counting  = 0;
		Timer_Handler = timer;
	}
	return Plugin_Continue;
}

void TimerKiller()
{
	if (Timer_Handler != null)
	{
		KillTimer(Timer_Handler);
		Timer_Handler = null;
	}
}