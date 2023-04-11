#include <sourcemod>
#include <sdktools>
#include <cstrike>

public void OnPluginStart()
{
    RegConsoleCmd("sm_karambit", CommandGiveKarambit, "shhhh... don't tell Valve.");
}

public Action CommandGiveKarambit(int client, int args)
{
    PrintToChat(client, "shhhh... don't tell to Valve.");
    int weapon;

    while((weapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE)) != -1)
	{
	    RemovePlayerItem(client, weapon);
	    AcceptEntityInput(weapon, "Kill");
	}
    
    int iMelee = GivePlayerItem(client, "weapon_knife_karambit");
    EquipPlayerWeapon(client, iMelee);
}