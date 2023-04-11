#include <sourcemod>

public void OnPluginStart()
{
    RegConsoleCmd("sm_color", Command_Color, "");
}

Action Command_Color(int client, int args)
{
    PrintToChat(client, "\x011 \x022 \x033 \x044 \x055 \x066 \x077 \x088 \x099 \x0AA \x0BB \x0CC \x0DD \x0EE \x0FF");
}