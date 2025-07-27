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
#include <sdkhooks>

#pragma semicolon 1

public Plugin myinfo =
{
	name		= "Weapon Damage Multiplier",
	author		= "i.car",
	description = "Multiply weapon damage",
	version		= "Version",
	url			= "URL"
};

float g_fKnifeMultiplier = 3.0;
float g_fAWPMultiplier	 = 2.0;

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	char weapon_name[32];

	GetEntityClassname(weapon, weapon_name, sizeof(weapon_name));

	if ((StrContains(weapon_name, "knife", false) != -1) || StrEqual(weapon_name, "weapon_bayonet") || StrEqual(weapon_name, "weapon_melee") || StrEqual(weapon_name, "weapon_axe") || StrEqual(weapon_name, "weapon_hammer") || StrEqual(weapon_name, "weapon_spanner"))
	{
		damage *= g_fKnifeMultiplier;

		return Plugin_Changed;
	}

	if (StrEqual(weapon_name, "weapon_awp"))
	{
		damage *= g_fAWPMultiplier;

		return Plugin_Changed;
	}

	return Plugin_Continue;
}