#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

Handle g_BetMenu;
bool   g_Is1v1 = false;
int	   g_Bets[MAXPLAYERS + 1];
int	   g_LastCT, g_LastT;
int	   g_BetAmount[MAXPLAYERS + 1];

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
	CreateBetMenu();
}

public void CreateBetMenu()
{
	g_BetMenu = CreateMenu(BetMenuHandler);
	SetMenuTitle(g_BetMenu, "Place Your Bet!");
	SetMenuExitBackButton(g_BetMenu, true);
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim	 = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsValidClient(attacker) || !IsValidClient(victim))
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

		Handle playerMenu = CreateMenu(BetMenuHandler);
		SetMenuTitle(playerMenu, "Place Your Bet!");
		SetMenuExitBackButton(playerMenu, true);

		char ctName[64], tName[64];
		GetClientName(g_LastCT, ctName, sizeof(ctName));
		GetClientName(g_LastT, tName, sizeof(tName));

		AddMenuItem(playerMenu, "t", tName, ITEMDRAW_DEFAULT);
		AddMenuItem(playerMenu, "ct", ctName, ITEMDRAW_DEFAULT);

		AddMenuItem(playerMenu, "raise", "Raise Bet 1000$", ITEMDRAW_DEFAULT);
		AddMenuItem(playerMenu, "reduce", "Reduce Bet 1000$", ITEMDRAW_DEFAULT);

		char betAmountText[64];
		Format(betAmountText, sizeof(betAmountText), "Your bet amount: $%d", g_BetAmount[i]);
		AddMenuItem(playerMenu, "amount", betAmountText, ITEMDRAW_DISABLED);

		DisplayMenu(playerMenu, i, MENU_TIME_FOREVER);
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
	CancelMenu(g_BetMenu);
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
		if (g_Bets[i] == winnerPlayer)
		{
			int money = GetEntProp(i, Prop_Send, "m_iAccount");
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