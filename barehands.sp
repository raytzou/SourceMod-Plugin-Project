#include <sourcemod>
#include <smlib>
#include <cstrike>
#include <sdktools>

#pragma semicolon 1

public void OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn);
}

public Action OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(IsFakeClient(client)) return Plugin_Continue;
    
    // CreateTimer(1.0, Timer_DetachWeapon, client);
    int weapon;
	while((weapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE)) != -1)
	{
	    RemovePlayerItem(client, weapon);
	    AcceptEntityInput(weapon, "Kill");
	}
    
    int iMelee = GivePlayerItem(client, "weapon_fists");
    EquipPlayerWeapon(client, iMelee);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    // Check if the player is attacking (+attack)
    if ((buttons & IN_ATTACK2) == IN_ATTACK2)
    {
        char weaponName[32];

        GetClientWeapon(client, weaponName, sizeof(weaponName));

        if(StrEqual(weaponName, "weapon_fists"))
            buttons &= ~IN_ATTACK2;
    }
    
    // We must return Plugin_Continue to let the changes be processed.
    // Otherwise, we can return Plugin_Handled to block the commands
    //return Plugin_Continue;
    return Plugin_Continue;
}