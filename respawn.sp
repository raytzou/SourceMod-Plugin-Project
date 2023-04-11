#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <smlib>

#pragma semicolon 1

int g_respawnTimes[MAXPLAYERS];
char g_mainWeapon[MAXPLAYERS][MAX_NAME_LENGTH];
char g_secWeapon[MAXPLAYERS][MAX_NAME_LENGTH];

public void OnPluginStart()
{
    // RegAdminCmd("sm_res", Command_Respawn, ADMFLAG_BAN, "respawn");
    RegConsoleCmd("sm_res", Command_Respawn, "Paying money for respawn per round.");
    HookEvent("player_spawn", OnPlayerSpawn);
    HookEvent("round_start", OnRoundStart);
}

public Action Command_Respawn(int client, int args)
{
    if(IsPlayerAlive(client))
    {
        ReplyToCommand(client, "You are already alive, how do I revive alive person?");
        return Plugin_Continue;
    }
    if(g_respawnTimes[client] != 0)
    {
        ReplyToCommand(client, "You can only respawn once per round!");
        return Plugin_Continue;
    }

    Menu menu = new Menu(RespawnMenu);
    menu.SetTitle("Pay US800$ for respawning once per round?");
    menu.AddItem("yes", "Yes");
    menu.AddItem("no", "No");
    menu.Display(client, 30);
    menu.ExitBackButton = false;
    
    return Plugin_Continue;
}

public int RespawnMenu(Menu menu, MenuAction action, int client, int item)
{
    if(action == MenuAction_Select)
    {
        if(item == 0)
        {
            int clientMoney = Client_GetMoney(client);
            if(clientMoney < 800)
            {
                PrintToChat(client, "Sorry, you need at least 800$ to respawn :(");
                delete menu;
            }
            else
            {
                CS_RespawnPlayer(client);
                Client_SetMoney(client, (clientMoney - 800));
                g_respawnTimes[client]++;

                // get current weapon entity index after respawning
                int mainWeapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
                int secWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

                if(mainWeapon != -1)
                {
                    char weaponName[32];
                
                    GetClientWeapon(client, weaponName, sizeof(weaponName));
                    if(!StrEqual(weaponName, g_mainWeapon[client]))
                    {
                        CS_DropWeapon(client, mainWeapon, false);
                        GivePlayerItem(client, g_mainWeapon[client]);
                    }
                }
                else
                    GivePlayerItem(client, g_mainWeapon[client]);
                if(secWeapon != -1)
                {
                    CS_DropWeapon(client, secWeapon, false);
                    GivePlayerItem(client, g_secWeapon[client]);
                }
                else
                    GivePlayerItem(client, g_secWeapon[client]);

                ReplyToCommand(client, "You've been revived, good luck!");
                SetEntProp(client, Prop_Data, "m_takedamage", 0, 1); // respawn protection
                CreateTimer(10.0, Timer_RespawnProtection, client);
                delete menu;
            }
        }
        else
        {
            delete menu;
        }
    }
    // else
    //     delete menu;
}

Action OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(IsClientInGame(client) && !IsFakeClient(client))
        CreateTimer(1.0, Timer_WeaponRecord, client, TIMER_REPEAT);
}

Action OnRoundStart(Event event, char[] name, bool dontBroadcast)
{
    for(int i = 0; i < sizeof(g_respawnTimes); i++)
        g_respawnTimes[i] = 0;
}

Action Timer_WeaponRecord(Handle timer, int client)
{
    if(!IsClientInGame(client))
        return Plugin_Stop;
    if(!IsPlayerAlive(client))
        return Plugin_Continue;

    char firstWeapon[MAX_NAME_LENGTH];
    char secondWeapon[MAX_NAME_LENGTH];
    int primaryWeapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    int secondaryWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
    
    if(IsValidEdict(primaryWeapon))
        GetEdictClassname(primaryWeapon, firstWeapon, sizeof(firstWeapon));
    if(IsValidEdict(secondaryWeapon))
        GetEdictClassname(secondaryWeapon, secondWeapon, sizeof(secondWeapon));

    g_mainWeapon[client] = firstWeapon;
    g_secWeapon[client] = secondWeapon;
    return Plugin_Continue;
}

Action Timer_RespawnProtection(Handle timer, int client)
{
    PrintToChat(client, "Respawn protection is end!");
    SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
}