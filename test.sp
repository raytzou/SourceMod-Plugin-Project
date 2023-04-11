#pragma semicolon 1
#pragma newdecls required

#include <dhooks>

Handle h_GetPlayerMaxSpeed = INVALID_HANDLE;

public void OnPluginStart() {
	if (LibraryExists("dhooks")) {
		Handle hGameData = LoadGameConfigFile("test_plugin.games");

		if (hGameData != null) {
			int iOffset = GameConfGetOffset(hGameData, "GetPlayerMaxSpeed");
			if (iOffset != -1)
				h_GetPlayerMaxSpeed = DHookCreate(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, DHook_GetPlayerMaxSpeed);
			delete hGameData;
		}
	}

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i)) {
			HookClient(i);
		}
}

public void OnClientPutInServer(int client) {
	HookClient(client);
}

void HookClient(int client) {
	DHookEntity(h_GetPlayerMaxSpeed, true, client);
}


public MRESReturn DHook_GetPlayerMaxSpeed(int client, Handle hReturn) {
    if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
        return MRES_Ignored;

    float fSpeed = 500.4;
    DHookSetReturn(hReturn, fSpeed);
    return MRES_Override;
}