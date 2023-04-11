#include <sourcemod>

bool g_isGodmode;

public void OnPluginStart()
{
    RegAdminCmd("sm_god", Command_Godmode, ADMFLAG_BAN, "");
}

public void OnMapStart()
{
    g_isGodmode = false;
}

Action Command_Godmode(int client, int args)
{
    if(g_isGodmode)
    {
        SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
        g_isGodmode = false;
    }
    else
    {
        SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
        g_isGodmode = true;
    }
}