#pragma semicolon 1

#include <sourcemod>

Handle Timer_Handler;

int g_c4Counting = 0;

public OnPluginStart()
{
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("bomb_planted", Event_BombPlanted);
    HookEvent("bomb_defused", Event_BombDefused);
    HookEvent("bomb_exploded", Event_BombExploded);
}

public Action Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
    TimerKiller();
}

public Action Event_BombPlanted(Event event, char[] name, bool dontBroadcast)
{
    g_c4Counting = GetConVarInt(FindConVar("mp_c4timer"));
    Timer_Handler = CreateTimer(1.0, Timer_BombCounting, _, TIMER_REPEAT);
}

public Action Event_BombDefused(Event event, char[] name, bool dontBroadcast)
{
    TimerKiller();
    PrintHintTextToAll("Bomb has been defused!");
    //PrintToChatAll("Bomb has been defused!");
}

public Action Event_BombExploded(Event event, char[] name, bool dontBroadcast)
{
    TimerKiller();
    PrintHintTextToAll("Bomb exploded!");
    //PrintToChatAll("Bomb exploded!");
}

public Action Timer_BombCounting(Handle timer)
{
    PrintHintTextToAll("C4 counting: <font color='#ff0000'>%d</font>", g_c4Counting);
    g_c4Counting--;
}

void TimerKiller()
{
    KillTimer(Timer_Handler);
    Timer_Handler = null;
}