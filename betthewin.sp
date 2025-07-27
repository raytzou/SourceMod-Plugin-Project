#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

bool   g_Is1v1 = false;
int	   g_Bets[MAXPLAYERS + 1];
int	   g_LastCT, g_LastT;
int	   g_BetAmount[MAXPLAYERS + 1];
Handle g_PlayerMenus[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name		= "BetTheWin",
	author		= "i.car",
	description = "A simple betting plugin for 1v1 matches.",
	version		= "1.0",
	url			= "https://likeIHaveUrl.com"
};

public OnPluginStart()
{
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsValidClient(victim))
		return Plugin_Continue;

	int ctCount = 0, tCount = 0;
	g_LastCT = 0;
	g_LastT	 = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsPlayerAlive(i))
			continue;

		if (GetClientTeam(i) == CS_TEAM_CT)
		{
			ctCount++;
			g_LastCT = i;
		}
		else if (GetClientTeam(i) == CS_TEAM_T)
		{
			tCount++;
			g_LastT = i;
		}
	}

	if (ctCount == 1 && tCount == 1 && !g_Is1v1)
	{
		g_Is1v1 = true;
		ResetBets();
		ShowBetMenuToDeadPlayers();
	}

	return Plugin_Continue;
}

public void ShowBetMenuToDeadPlayers()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsPlayerAlive(i))
			continue;

		int money = GetEntProp(i, Prop_Send, "m_iAccount");
		if (money < 1000)
		{
			PrintToChat(i, "You don't have enough money to participate in this bet.");
			continue;
		}

		if (g_PlayerMenus[i] != INVALID_HANDLE)
		{
			CloseHandle(g_PlayerMenus[i]);
			g_PlayerMenus[i] = INVALID_HANDLE;
		}

		g_PlayerMenus[i] = CreateMenu(BetMenuHandler);
		if (g_PlayerMenus[i] == INVALID_HANDLE)
		{
			PrintToServer("Failed to create menu for player %d.", i);
			continue;
		}

		SetMenuTitle(g_PlayerMenus[i], "Place Your Bet!");
		SetMenuExitBackButton(g_PlayerMenus[i], true);

		char ctName[64], tName[64];
		GetClientName(g_LastCT, ctName, sizeof(ctName));
		GetClientName(g_LastT, tName, sizeof(tName));

		AddMenuItem(g_PlayerMenus[i], "ct", ctName, ITEMDRAW_DEFAULT);
		AddMenuItem(g_PlayerMenus[i], "t", tName, ITEMDRAW_DEFAULT);
		AddMenuItem(g_PlayerMenus[i], "raise", "Raise Bet 1000$", ITEMDRAW_DEFAULT);
		AddMenuItem(g_PlayerMenus[i], "reduce", "Reduce Bet 1000$", ITEMDRAW_DEFAULT);

		char betAmountText[64];
		Format(betAmountText, sizeof(betAmountText), "Your bet amount: $%d", g_BetAmount[i]);
		AddMenuItem(g_PlayerMenus[i], "amount", betAmountText, ITEMDRAW_DISABLED);

		DisplayMenu(g_PlayerMenus[i], i, MENU_TIME_FOREVER);
	}
}

public int BetMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[10];
		GetMenuItem(menu, item, info, sizeof(info));

		if (StrEqual(info, "ct"))
		{
			g_Bets[client] = g_LastCT;
			PrintToChat(client, "You bet on CT!");
		}
		else if (StrEqual(info, "t"))
		{
			g_Bets[client] = g_LastT;
			PrintToChat(client, "You bet on T!");
		}
		else if (StrEqual(info, "raise"))
		{
			int money = GetEntProp(client, Prop_Send, "m_iAccount");
			if (g_BetAmount[client] + 1000 > money)
			{
				PrintToChat(client, "You don't have enough money to raise your bet.");
			}
			else
			{
				g_BetAmount[client] += 1000;
				PrintToChat(client, "You raised your bet to $%d.", g_BetAmount[client]);
			}
			ShowBetMenuToDeadPlayers();
		}
		else if (StrEqual(info, "reduce"))
		{
			if (g_BetAmount[client] - 1000 < 1000)
			{
				PrintToChat(client, "You cannot reduce your bet below $1000.");
			}
			else
			{
				g_BetAmount[client] -= 1000;
				PrintToChat(client, "You reduced your bet to $%d.", g_BetAmount[client]);
			}
			ShowBetMenuToDeadPlayers();
		}
	}

	return 0;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_PlayerMenus[i] != INVALID_HANDLE)
		{
			CloseHandle(g_PlayerMenus[i]);
			g_PlayerMenus[i] = INVALID_HANDLE;
		}
	}

	if (!g_Is1v1)
		return Plugin_Continue;

	g_Is1v1			  = false;

	int winnerTeam	  = GetEventInt(event, "winner");
	int winnerPlayer  = (winnerTeam == CS_TEAM_CT) ? g_LastCT : g_LastT;

	int highestBet	  = 0;
	int highestBetter = 0;
	int totalLost	  = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || g_Bets[i] == 0)
			continue;
		int money = GetEntProp(i, Prop_Send, "m_iAccount");

		if (g_Bets[i] == winnerPlayer)
		{
			SetEntProp(i, Prop_Send, "m_iAccount", money + g_BetAmount[i]);
			PrintToChat(i, "You won the bet! You received $%d.", g_BetAmount[i]);

			if (g_BetAmount[i] > highestBet)
			{
				highestBet	  = g_BetAmount[i];
				highestBetter = i;
			}
		}
		else
		{
			PrintToChat(i, "You lost the bet. You lost $%d.", g_BetAmount[i]);
			SetEntProp(i, Prop_Send, "m_iAccount", money - g_BetAmount[i]);
			totalLost += g_BetAmount[i];
		}
	}

	if (highestBetter > 0)
	{
		int money = GetEntProp(highestBetter, Prop_Send, "m_iAccount");
		SetEntProp(highestBetter, Prop_Send, "m_iAccount", money + totalLost);
		PrintToChatAll("%N won the highest bet and received an additional $%d from all lost bets!", highestBetter, totalLost);
	}

	return Plugin_Continue;
}

public void ResetBets()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_Bets[i]	   = 0;
		g_BetAmount[i] = 1000;	  // Reset bet amount to default
	}
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}