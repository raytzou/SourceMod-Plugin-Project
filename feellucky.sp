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

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <smlib>

#pragma semicolon 1

Handle Handle_Cooldown;	   // handler for killing timer
Handle Handle_Godmode;
Handle Handle_Noclip;
Handle Handle_Infinite;
Handle Handle_Speedup;
Handle Handle_Speeddown;
Handle Handle_Regenerate;
Handle Handle_God;

ConVar cvar_countdown;	  // ConVar
ConVar cvar_costmoney;
ConVar cvar_godmode;
ConVar cvar_noclip;
ConVar cvar_infinite;
ConVar cvar_speedup;
ConVar cvar_speeddown;
ConVar cvar_noclipspeed;
ConVar cvar_regenerate;
ConVar cvar_regenerate_amount;
ConVar cvar_god;

int	   cooldown[MAXPLAYERS + 1];
int	   roller			   = 0;
int	   counter_rolled	   = 0;
int	   godmode_duration	   = 0;
int	   noclip_duration	   = 0;
int	   infinite_duration   = 0;
int	   speedup_duration	   = 0;
int	   speeddown_duration  = 0;
int	   regenerate_duration = 0;
int	   god_duration		   = 0;
int	   noclip_speed		   = 0;

bool   g_isNoclip[MAXPLAYERS];
bool   g_freeChance[MAXPLAYERS];
bool   g_isAdmin;
bool   isBusy;

public Plugin myinfo =
{
	name		= "My Roll The Dice",
	author		= "i.car",
	description = "A plugin to try your luck",
	version		= "0.0",
	url			= ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_luck", Command_Lucky, "When you feel lucky");
	RegAdminCmd("sm_dice", Command_Lucky_Admin, ADMFLAG_GENERIC, "Roll dice to what point you want");

	cvar_countdown		   = CreateConVar("sm_luck_cooldown_seconds", "60", "Cooldown after trying luck. (Seconds)");
	cvar_costmoney		   = CreateConVar("sm_luck_money_cost", "1000", "Every time you try luck, how much it costs. (Money)");
	cvar_godmode		   = CreateConVar("sm_luck_godmode_second", "10", "Godmode duration. (Seconds)");
	cvar_noclip			   = CreateConVar("sm_luck_godmode_second", "10", "Noclip duration. (Seconds)");
	cvar_infinite		   = CreateConVar("sm_luck_infinite_second", "10", "Infinite ammo duration. (Seconds)");
	cvar_speedup		   = CreateConVar("sm_luck_speedup_second", "10", "Speedup duration. (Seconds)");
	cvar_speeddown		   = CreateConVar("sm_luck_speeddown_second", "10", "Speed down duration. (Seconds)");
	cvar_regenerate		   = CreateConVar("sm_luck_regenerate_second", "20", "HP regeneration duration. (Seconds)");
	cvar_god			   = CreateConVar("sm_luck_god_second", "5", "God duration. (Seconds)");
	cvar_regenerate_amount = CreateConVar("sm_luck_regenerate_amount", "5", "How many HP has been regenerated per second. (Amount)");

	cvar_noclipspeed	   = FindConVar("sv_noclipspeed");
	cvar_noclipspeed.Flags &= ~FCVAR_NOTIFY;
	noclip_speed = GetConVarInt(cvar_noclipspeed);
	// HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public void OnMapStart()
{
	counter_rolled = 0;
	isBusy		   = false;

	for (int i = 1; i <= MaxClients; i++)
	{
		cooldown[i]		= 0;
		g_freeChance[i] = false;
	}
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		TimerKiller(i);
	}
}

public void OnClientConnected(int client)
{
	if (!IsFakeClient(client) && IsClientInGame(client))
		g_isNoclip[client] = false;
}

public void OnClientDisconnect_Post(int client)
{
	cooldown[client] = 0;

	TimerKiller(client);
}

public Action Command_Lucky_Admin(int client, int args)
{
	g_isAdmin = true;

	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_dice <first dice> <second dice>");

		return Plugin_Continue;
	}

	char arg1[32];
	char arg2[32];

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	TimerKiller(client);

	OnDicing(client, g_isAdmin, StringToInt(arg1), StringToInt(arg2));

	return Plugin_Continue;
}

public Action Command_Lucky(int client, int args)
{
	int money	   = Client_GetMoney(client);
	int cost_money = GetConVarInt(cvar_costmoney);

	g_isAdmin	   = false;

	if (cooldown[client] > 0)
	{
		PrintToChat(client, "Sorry, you have to wait cooldown for %d seconds.", cooldown[client]);

		return Plugin_Continue;
	}
	if (money < GetConVarInt(cvar_costmoney))
	{
		PrintToChat(client, "Sorry, you don't have enough money to play dice :(");

		return Plugin_Continue;
	}
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "Just lie down, sleep tight okay?");

		return Plugin_Continue;
	}
	if (isBusy)
	{
		PrintToChat(client, "Please wait other's dice effect over.");

		return Plugin_Continue;
	}
	if (g_freeChance[client])
	{
		PrintToChat(client, "You use a pass for free rolling, good luck!");
		g_freeChance[client] = false;
		cost_money			 = 0;
	}
	Client_SetMoney(client, (money - cost_money));
	OnDicing(client, g_isAdmin, 0, 0);

	return Plugin_Continue;
}

public Action Timer_Cooldown(Handle timer, int client)
{
	--cooldown[client];
	if (Handle_Cooldown != timer) Handle_Cooldown = timer;

	if (cooldown[client] <= 0 && IsClientInGame(client))
	{
		PrintHintText(client, "You can try your luck again!");
		TimerKiller(client);
	}

	return Plugin_Continue;
}

public Action Timer_Godmode(Handle timer, int client)
{
	if (Handle_Godmode != timer) Handle_Godmode = timer;
	char name[32];

	GetClientName(client, name, sizeof(name));
	// SetHudTextParams(-1.0, 0.7, 1.0, 255, 0, 0, 255, 1, 1.0, 0.1, 0.1);

	Client_PrintHintTextToAll("%s is invincible for %d seconds", name, godmode_duration);

	if (godmode_duration <= 0 || !IsPlayerAlive(client) || !IsClientInGame(client))
	{
		PrintToChatAll("%s is not invincible anymore.", name);
		isBusy = false;
		Client_PrintHintTextToAll("%s is not invincible anymore", name);
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		KillTimer(Handle_Godmode);
		Handle_Godmode = null;
	}

	--godmode_duration;
	return Plugin_Continue;
}

public Action Timer_Noclip(Handle timer, int client)
{
	if (Handle_Noclip != timer) Handle_Noclip = timer;
	char name[32];

	GetClientName(client, name, sizeof(name));
	Client_PrintHintTextToAll("%s noclip expired in %d seconds", name, noclip_duration);

	if (noclip_duration <= 0 || !IsPlayerAlive(client) || !IsClientInGame(client))
	{
		g_isNoclip[client] = false;
		PrintToChatAll("%s's noclip is expired.", name);
		isBusy = false;
		Client_PrintHintTextToAll("%s's noclip is expired.", name);
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetConVarInt(cvar_noclipspeed, noclip_speed, true, false);

		if (CheckIfPlayerIsStuck(client))
		{
			PrintToChat(client, "You couldn't breath in wall, then stuck in wall and died.");
			ForcePlayerSuicide(client);
		}
		KillTimer(Handle_Noclip);
		Handle_Noclip = null;
	}

	--noclip_duration;
	return Plugin_Continue;
}

public Action Timer_Infinite(Handle timer, int client)
{
	if (Handle_Infinite != timer) Handle_Infinite = timer;
	char name[32];

	GetClientName(client, name, sizeof(name));
	PrintHintTextToAll("%s still has infinite ammo for %d seconds.", name, infinite_duration);

	if (infinite_duration <= 0 || !IsPlayerAlive(client) || !IsClientInGame(client))
	{
		PrintHintTextToAll("%s has no infinite ammo anymore.", name);
		isBusy = false;
		UnhookEvent("weapon_fire", Event_WeaponFire);
		KillTimer(Handle_Infinite);
		Handle_Infinite = null;
	}

	--infinite_duration;
	return Plugin_Continue;
}

public Action Timer_Speedup(Handle timer, int client)
{
	if (Handle_Speedup != timer) Handle_Speedup = timer;
	char name[32];

	GetClientName(client, name, sizeof(name));
	PrintHintTextToAll("%s speed up for %d seconds.", name, speedup_duration);

	if (speedup_duration <= 0 || !IsPlayerAlive(client) || !IsClientInGame(client))
	{
		PrintHintTextToAll("%s's speed return to normal.", name);
		isBusy = false;
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
		KillTimer(Handle_Speedup);
		Handle_Speedup = null;
	}

	--speedup_duration;
	return Plugin_Continue;
}

public Action Timer_Speeddown(Handle timer, int client)
{
	if (Handle_Speeddown != timer) Handle_Speeddown = timer;
	char name[32];

	GetClientName(client, name, sizeof(name));
	PrintHintTextToAll("%s moves slowly for %d seconds.", name, speeddown_duration);

	if (speeddown_duration <= 0 || !IsPlayerAlive(client) || !IsClientInGame(client))
	{
		PrintHintTextToAll("%s's speed return to normal.", name);
		isBusy = false;
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
		KillTimer(Handle_Speeddown);
		Handle_Speeddown = null;
	}

	--speeddown_duration;
	return Plugin_Continue;
}

public Action Timer_Regenerate(Handle timer, int client)
{
	if (Handle_Regenerate != timer) Handle_Regenerate = timer;
	char name[32];
	int	 player_health = GetClientHealth(client);
	int	 health		   = GetConVarInt(cvar_regenerate_amount);

	GetClientName(client, name, sizeof(name));
	SetEntityHealth(client, (health + player_health));
	PrintHintTextToAll("%s still can regenerate his HP for %d seconds.", name, regenerate_duration);

	if (regenerate_duration <= 0 || !IsPlayerAlive(client) || !IsClientInGame(client))
	{
		PrintHintTextToAll("%s's HP regeneration is over.", name);
		isBusy = false;
		KillTimer(Handle_Regenerate);
		Handle_Regenerate = null;
	}

	--regenerate_duration;
	return Plugin_Continue;
}

public Action Timer_God(Handle timer, int client)
{
	if (Handle_God != timer) Handle_God = timer;
	char name[32];

	GetClientName(client, name, sizeof(name));
	PrintHintTextToAll("%s is God for %d seconds.", name, god_duration);

	if (god_duration <= 0 || !IsPlayerAlive(client) || !IsClientInGame(client))
	{
		PrintHintTextToAll("%s is not God anymore.", name);
		isBusy = false;
		SetEntityMoveType(client, MOVETYPE_WALK);

		if (CheckIfPlayerIsStuck(client))
		{
			PrintToChat(client, "You couldn't breath in wall, then stuck in wall and died.");
			ForcePlayerSuicide(client);
		}

		KillTimer(Handle_God);
		Handle_God = null;
	}

	--god_duration;
	return Plugin_Continue;
}

public Action Hook_OnDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsPlayerAlive(victim) && GetEntityMoveType(victim) == MOVETYPE_NOCLIP && g_isNoclip[victim])
	{
		SetEntityMoveType(victim, MOVETYPE_WALK);
	}
	return Plugin_Changed;
}

public Action Hook_OnDamagePost(int victim, int attacker)
{
	if (IsPlayerAlive(victim) && GetEntityMoveType(victim) != MOVETYPE_NOCLIP && g_isNoclip[victim])
	{
		SetEntityMoveType(victim, MOVETYPE_NOCLIP);
	}
	return Plugin_Changed;
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int current_weapon = GetEntPropEnt(roller, Prop_Send, "m_hActiveWeapon");
	int ammo		   = GetEntProp(current_weapon, Prop_Data, "m_iClip1") + 1;

	SetEntProp(current_weapon, Prop_Data, "m_iClip1", ammo);
	return Plugin_Continue;
}

stock bool CheckIfPlayerIsStuck(client)
{
	float vecMin[3], vecMax[3], vecOrigin[3];

	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	GetClientAbsOrigin(client, vecOrigin);

	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceEntityFilterSolid);
	return TR_DidHit();	   // head in wall ?
}

public bool TraceEntityFilterSolid(entity, contentsMask)
{
	return entity > 1;
}

public void TimerKiller(int client)
{
	if (Handle_Cooldown != null)
	{
		cooldown[client] = 0;
		KillTimer(Handle_Cooldown);
		Handle_Cooldown = null;
	}

	if (Handle_Godmode != null)
	{
		KillTimer(Handle_Godmode);
		Handle_Godmode = null;
	}

	if (Handle_Noclip != null)
	{
		KillTimer(Handle_Noclip);
		Handle_Noclip = null;
	}

	if (Handle_Infinite != null)
	{
		KillTimer(Handle_Infinite);
		Handle_Infinite = null;
	}

	if (Handle_Speedup != null)
	{
		KillTimer(Handle_Speedup);
		Handle_Speedup = null;
	}

	if (Handle_Speeddown != null)
	{
		KillTimer(Handle_Speeddown);
		Handle_Speeddown = null;
	}

	if (Handle_Regenerate != null)
	{
		KillTimer(Handle_Regenerate);
		Handle_Regenerate = null;
	}

	if (Handle_God != null)
	{
		KillTimer(Handle_God);
		Handle_God = null;
	}
}

void OnDicing(int client, bool isAdmin, int arg1, int arg2)
{
	char name[32];
	int	 first_dice = GetRandomInt(1, 6), second_dice = GetRandomInt(1, 6);

	GetClientName(client, name, sizeof(name));
	cooldown[client] = GetConVarInt(cvar_countdown);
	roller			 = client;
	counter_rolled++;

	if (isAdmin)
	{
		first_dice	= arg1;
		second_dice = arg2;
	}

	PrintToChatAll("%s feel lucky now. Roll (%d) (%d)", name, first_dice, second_dice);

	if (first_dice == 1 && second_dice == 1)
	{
		SetEntityHealth(client, 1);
		SlapPlayer(client, 0);
		PrintToChatAll("LOL, %s now has only 1 hp.", name);
	}
	else if (first_dice == 1 && second_dice == 2)
	{
		int player_health = GetClientHealth(client);
		int random_chance = GetRandomInt(1, 2);

		if (random_chance == 1)
		{
			SetEntityHealth(client, (player_health + 25));
			PrintToChatAll("Wow, %s won 25% hp.", name);
		}
		else
		{
			SetEntityHealth(client, (player_health + 50));
			PrintToChatAll("Wow, %s won 50% hp.", name);
		}
	}
	else if (first_dice == 1 && second_dice == 3)
	{
		int player_health = GetClientHealth(client);
		int random_chance = GetRandomInt(1, 2);

		if (random_chance == 1)
		{
			SlapPlayer(client, (player_health * 25 / 100));
			PrintToChatAll("Haha, %s loss current 25% hp.", name);
		}
		else
		{
			SlapPlayer(client, (player_health * 50 / 100));
			PrintToChatAll("Haha, %s loss the current 50% hp.", name);
		}
	}
	else if (first_dice == 1 && second_dice == 4)
	{
		ForcePlayerSuicide(client);
		PrintToChatAll("%s lose his(her) life, RIP.", name);
	}
	else if (first_dice == 1 && second_dice == 6)
	{
		PrintToChatAll("%s won a pass, next rolling is FREE!", name);
		g_freeChance[client] = true;
	}
	else if (first_dice == 2 && second_dice == 1)
	{
		int player_armor  = GetClientArmor(client);
		int random_chance = GetRandomInt(1, 3);

		if (random_chance == 1)
		{
			SetEntProp(client, Prop_Send, "m_ArmorValue", (player_armor + 25));
			PrintToChatAll("%s recovered 25% armor.", name);
		}
		if (random_chance == 2)
		{
			SetEntProp(client, Prop_Send, "m_ArmorValue", (player_armor + 50));
			PrintToChatAll("%s recovered 50% armor.", name);
		}
		if (random_chance == 3)
		{
			SetEntProp(client, Prop_Send, "m_ArmorValue", (player_armor + 75));
			PrintToChatAll("%s recovered 75% armor.", name);
		}
	}
	else if (first_dice == 2 && second_dice == 2)
	{
		int player_armor  = GetClientArmor(client);
		int random_chance = GetRandomInt(1, 3);

		if (random_chance == 1)
		{
			if ((player_armor - 25) <= 0)
			{
				SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_ArmorValue", (player_armor - 25));
			}
			PrintToChatAll("%s reduced 25% armor.", name);
		}
		if (random_chance == 2)
		{
			if ((player_armor - 25) <= 0)
			{
				SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_ArmorValue", (player_armor - 50));
			}
			PrintToChatAll("%s reduced 50% armor.", name);
		}
		if (random_chance == 3)
		{
			if ((player_armor - 25) <= 0)
			{
				SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_ArmorValue", (player_armor - 75));
			}
			PrintToChatAll("%s reduced 75% armor.", name);
		}
	}
	else if (first_dice == 2 && second_dice == 3)
	{
		int player_health = GetClientHealth(client);
		int player_armor  = GetClientArmor(client);

		PrintToChatAll("Wow, %s recovered his health and won new armor.", name);
		if (player_health < 100)
			SetEntityHealth(client, 100);

		if (player_armor < 100)
			SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
	}
	else if (first_dice == 2 && second_dice == 4)
	{
		regenerate_duration = GetConVarInt(cvar_regenerate);
		PrintToChatAll("%s now knows how to regenerate his HP.", name);
		isBusy			  = true;
		Handle_Regenerate = CreateTimer(1.0, Timer_Regenerate, client, TIMER_REPEAT);
	}
	else if (first_dice == 2 && second_dice == 6)
	{
		PrintToChatAll("%s won a pass, next rolling is FREE!", name);
		g_freeChance[client] = true;
	}
	else if (first_dice == 3 && second_dice == 1)
	{
		int main_weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

		PrintToChatAll("Oops, seems %s lose his(her) weapon.", name);
		if (main_weapon != -1)
			Client_DetachWeapon(client, main_weapon);
		else
			PrintToChat(client, "Looks like you don't have primary weapon.");
	}
	else if (first_dice == 3 && second_dice == 2)
	{
		speedup_duration = GetConVarInt(cvar_speedup);
		PrintToChatAll("%s has more speed now.", name);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 2.0);
		Handle_Speedup = CreateTimer(1.0, Timer_Speedup, client, TIMER_REPEAT);
		isBusy		   = true;
	}
	else if (first_dice == 3 && second_dice == 3)
	{
		speeddown_duration = GetConVarInt(cvar_speeddown);
		PrintToChatAll("%s's speed slow down", name);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.5);
		Handle_Speeddown = CreateTimer(1.0, Timer_Speeddown, client, TIMER_REPEAT);
		isBusy			 = true;
	}
	else if (first_dice == 3 && second_dice == 6)
	{
		PrintToChatAll("%s won a pass, next rolling is FREE!", name);
		g_freeChance[client] = true;
	}
	else if (first_dice == 4 && second_dice == 1)
	{
		godmode_duration = GetConVarInt(cvar_godmode);
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
		PrintToChatAll("%s is invincible for %d seconds.", name, GetConVarInt(cvar_godmode));
		Handle_Godmode = CreateTimer(1.0, Timer_Godmode, client, TIMER_REPEAT);
		isBusy		   = true;
	}
	else if (first_dice == 4 && second_dice == 2)
	{
		noclip_duration	   = GetConVarInt(cvar_noclip);
		g_isNoclip[client] = true;
		SetConVarFloat(cvar_noclipspeed, 1.5, false, false);
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnDamage);
		SDKHook(client, SDKHook_OnTakeDamagePost, Hook_OnDamagePost);
		PrintToChatAll("%s wins noclip.", name);
		Handle_Noclip = CreateTimer(1.0, Timer_Noclip, client, TIMER_REPEAT);
		isBusy		  = true;
	}
	else if (first_dice == 4 && second_dice == 3)
	{
		infinite_duration = GetConVarInt(cvar_infinite);
		PrintToChatAll("%s has infinite ammo for %d seconds.", name, infinite_duration);
		Handle_Infinite = CreateTimer(1.0, Timer_Infinite, client, TIMER_REPEAT);
		isBusy			= true;
		HookEvent("weapon_fire", Event_WeaponFire);
	}
	else if (first_dice == 4 && second_dice == 6)
	{
		PrintToChatAll("%s won a pass, next rolling is FREE!", name);
		g_freeChance[client] = true;
	}
	else if (first_dice == 5 && second_dice == 1)	 // rifle
	{
		char weapon[][]	   = { "weapon_ak47", "weapon_aug", "weapon_famas", "weapon_galilar",
							   "weapon_m4a1", "weapon_m4a1_silencer", "weapon_sg556" };
		int	 random_chance = GetRandomInt(0, (sizeof(weapon) - 1));

		if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == -1)
		{
			GivePlayerItem(client, weapon[random_chance]);
		}
		else
		{
			int weapon_slot = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

			CS_DropWeapon(client, weapon_slot, true);
			GivePlayerItem(client, weapon[random_chance]);
		}

		PrintToChatAll("%s wins a random rifle weapon.", name);
	}
	else if (first_dice == 5 && second_dice == 2)	 // sniper
	{
		char weapon[][]	   = { "weapon_awp", "weapon_g3sg1", "weapon_scar20", "weapon_ssg08" };
		int	 random_chance = GetRandomInt(0, (sizeof(weapon) - 1));

		if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == -1)
		{
			GivePlayerItem(client, weapon[random_chance]);
		}
		else
		{
			int weapon_slot = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

			CS_DropWeapon(client, weapon_slot, true);
			GivePlayerItem(client, weapon[random_chance]);
		}

		PrintToChatAll("%s wins a random sniper rifle.", name);
	}
	else if (first_dice == 5 && second_dice == 3)	 // sub-machine gun
	{
		char weapon[][]	   = { "weapon_bizon", "weapon_mac10", "weapon_mp7", "weapon_mp5sd",
							   "weapon_mp9", "weapon_p90", "weapon_ump45" };
		int	 random_chance = GetRandomInt(0, (sizeof(weapon) - 1));

		if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == -1)
		{
			GivePlayerItem(client, weapon[random_chance]);
		}
		else
		{
			int weapon_slot = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

			CS_DropWeapon(client, weapon_slot, true);
			GivePlayerItem(client, weapon[random_chance]);
		}

		PrintToChatAll("%s wins a random sub-machine gun.", name);
	}
	else if (first_dice == 5 && second_dice == 4)	 // heavy weapon & shotgun
	{
		char weapon[][]	   = { "weapon_m249", "weapon_mag7", "weapon_negev", "weapon_nova", "weapon_sawedoff", "weapon_xm1014" };
		int	 random_chance = GetRandomInt(0, (sizeof(weapon) - 1));

		if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == -1)
		{
			GivePlayerItem(client, weapon[random_chance]);
		}
		else
		{
			int weapon_slot = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

			CS_DropWeapon(client, weapon_slot, true);
			GivePlayerItem(client, weapon[random_chance]);
		}

		PrintToChatAll("%s wins a random shotgun or heavy weapon.", name);
	}
	else if (first_dice == 5 && second_dice == 5)	 // pistol
	{
		char weapon[][]	   = { "weapon_cz75a", "weapon_deagle", "weapon_elite", "weapon_fiveseven", "weapon_tec9" };
		int	 random_chance = GetRandomInt(0, (sizeof(weapon) - 1));

		if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == -1)
		{
			GivePlayerItem(client, weapon[random_chance]);
		}
		else
		{
			int weapon_slot = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

			CS_DropWeapon(client, weapon_slot, true);
			GivePlayerItem(client, weapon[random_chance]);
		}

		PrintToChatAll("%s wins a random pistol.", name);
	}
	else if (first_dice == 5 && second_dice == 6)	 // items
	{
		char weapon[][]	   = { "weapon_decoy", "weapon_flashbang", "weapon_healthshot", "weapon_hegrenade", "weapon_incgrenade", "weapon_taser",
							   "weapon_molotov", "weapon_tagrenade", "weapon_smokegrenade", "weapon_snowball", "weapon_breachcharge", "weapon_bumpmine" };
		int	 random_chance = GetRandomInt(0, (sizeof(weapon) - 1));
		// int random_chance = 5;

		if (StrEqual(weapon[random_chance], "weapon_breachcharge") || StrEqual(weapon[random_chance], "weapon_bumpmine"))
		{
			int giveIndex = GivePlayerItem(client, weapon[random_chance]);
			EquipPlayerWeapon(client, giveIndex);
		}
		else
			GivePlayerItem(client, weapon[random_chance]);

		PrintToChatAll("%s wins a random item.", name);
	}
	else if (first_dice == 6 && second_dice == 1)
	{
		int current_money = Client_GetMoney(client);
		int new_money	  = GetRandomInt(300, 3000);
		int max_money	  = GetConVarInt(FindConVar("mp_maxmoney"));

		if ((current_money + new_money) > max_money)
			Client_SetMoney(client, max_money);
		else
			Client_SetMoney(client, (current_money + new_money));

		PrintToChatAll("Cheer! %s won %d$.", name, new_money);
	}

	else if (first_dice == 6 && second_dice == 2)
	{
		int current_money = Client_GetMoney(client);
		int new_money	  = GetRandomInt(100, 5000);

		if ((current_money - new_money) <= 0)
			Client_SetMoney(client, 0);
		else
			Client_SetMoney(client, (current_money - new_money));

		PrintToChatAll("Ha! %s lose his money, %d$ !", name, new_money);
	}
	// else if(first_dice == 6 && second_dice == 3)
	// {
	//     PrintToChatAll("%s learns how to bunny hop!", name);

	//     bhop_duration = GetConVarInt(cvar_bhop);
	//     g_isBhop[client] = true;
	//     SetConVarFloat(cvar_noclipspeed, 1.5, false, false);
	//     SetEntityMoveType(client, MOVETYPE_NOCLIP);
	//     //SetEntProp(client, Prop_Data, "m_takedamage", 2, 1); // disable noclip with godmode
	//     SDKHook(client, SDKHook_OnTakeDamage, Hook_OnDamage);
	//     SDKHook(client, SDKHook_OnTakeDamagePost, Hook_OnDamagePost);
	//     PrintToChatAll("%s wins noclip.", name);
	//     Handle_Noclip = CreateTimer(1.0, Timer_Noclip, client, TIMER_REPEAT);
	// }
	else if (first_dice == 6 && second_dice == 4)
	{
		int current_money = Client_GetMoney(client);
		int max_money	  = GetConVarInt(FindConVar("mp_maxmoney"));
		int win_money	  = (counter_rolled * GetConVarInt(cvar_costmoney));

		PrintToChatAll("%s wins money from everyone who spent on dice!", name);
		PrintToChatAll("Dices have been rolled %d times, there are $%d!", counter_rolled, win_money);
		PrintToChat(client, "You won $%d", win_money);

		if ((current_money + win_money) > max_money)
			Client_SetMoney(client, max_money);
		else
			Client_SetMoney(client, (current_money + win_money));

		counter_rolled = 0;
	}
	else if (first_dice == 6 && second_dice == 5)	 // melee, shield
	{
		char weapon[][]	   = { "weapon_shield", "weapon_axe", "weapon_hammer", "weapon_spanner", "weapon_knifegg", "weapon_knife" };
		int	 random_chance = GetRandomInt(0, (sizeof(weapon) - 1));
		int	 index		   = GivePlayerItem(client, weapon[random_chance]);

		EquipPlayerWeapon(client, index);
		PrintToChatAll("%s wins a random melee.", name);
	}
	else if (first_dice == 6 && second_dice == 6)
	{
		PrintToChatAll("%s became the God!", name);
		SetEntityMoveType(client, MOVETYPE_NOCLIP);
		god_duration = GetConVarInt(cvar_god);
		Handle_God	 = CreateTimer(1.0, Timer_God, client, TIMER_REPEAT);
		isBusy		 = true;
	}
	else
	{
		PrintToChatAll("%s rolled dices, but nothing happened.", name);
	}
	Handle_Cooldown = CreateTimer(1.0, Timer_Cooldown, client, TIMER_REPEAT);	 // repeat every seconds till cooldown is over
}