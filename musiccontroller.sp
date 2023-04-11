#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <emitsoundany>

int g_roundNum = -1;
int g_musicIndex = 0;
int g_warmupLen = 0;
int g_roundLen = 0;
int g_endLooseLen = 0;
int g_endWinLen = 0;
int g_gameEndLen = 0;
int g_songPicker = 0;
int g_playerIndex = 0;

float g_clientVolume[MAXPLAYERS];

char g_cfgPath[PLATFORM_MAX_PATH];
char g_warmpupMusic[32][MAX_NAME_LENGTH];
char g_warmupPath[32][PLATFORM_MAX_PATH];
char g_roundMusic[32][MAX_NAME_LENGTH];
char g_roundPath[32][PLATFORM_MAX_PATH];
char g_roundEndWinMusic[32][MAX_NAME_LENGTH];
char g_roundEndWinPath[32][PLATFORM_MAX_PATH];
char g_roundEndLooseMusic[32][MAX_NAME_LENGTH];
char g_roundEndLoosePath[32][PLATFORM_MAX_PATH];
char g_gameEndMusic[32][MAX_NAME_LENGTH];
char g_gameEndPath[32][PLATFORM_MAX_PATH];

public Plugin myinfo =
{
    name = "Round Music Controller",
    author = "i.car",
    description = "A controller for every rounds' sound",
    version = "0.0",
    url = ""
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_volume", Command_Volume, "Volume of BGM, range: 0 - 100");
    BuildPath(Path_SM, g_cfgPath, sizeof(g_cfgPath), "configs/music.cfg");

    if(!FileExists(g_cfgPath))
        SetFailState("music cfg file %s is not found.", g_cfgPath);

    GetMusic();
    HookEvent("round_start", OnRoundStart);
    // HookEvent("round_end", OnRoundEnd);
    HookEvent("cs_win_panel_match", OnGameEnd);

    for(int i = 0; i < MAXPLAYERS; i++)
        g_clientVolume[i] = 0.4;
}

public void OnMapStart()
{
    char map[MAX_NAME_LENGTH];

    GetCurrentMap(map, sizeof(map));
    g_roundNum = -1;
    DownloadAndPrecache();

    if(map[0] == 'd' && map[1] == 'e')
        g_playerIndex = CS_TEAM_T;
    else
        g_playerIndex = CS_TEAM_CT;
    // PrintToServer("Len: %d %d %d %d %d", g_warmupLen, g_roundLen, g_endWinLen, g_endLooseLen, g_gameEndLen);
}



Action Command_Volume(int client, int args)
{
    if(args < 1)
    {
        ReplyToCommand(client, "BGM volume: %d\%, usage: sm_volume <0 - 100>", RoundToZero(g_clientVolume[client] * 100.0));
        return;
    }

    char arg[32]; //string
    int volume = 0;

    GetCmdArg(1, arg, sizeof(arg));
    volume = StringToInt(arg);

    if(volume > 100 || volume < 0)
    {
        ReplyToCommand(client, "Usage: sm_volume <0 - 100>.");
        return;
    }

    g_clientVolume[client] = volume / 100.0;
    PrintToChat(client, "BGM volume set to %d\%, will change in next round.", RoundToZero(g_clientVolume[client] * 100.0));
}

Action OnRoundStart(Event event, char[] name, bool dontBroadcast)
{
    g_roundNum++;

    //emit sound from sound folder
    if(g_roundNum == 0)
    {
        // g_songPicker = GetRandomInt(0, g_warmupLen - 1);
        CreateTimer(3.0, Timer_WarmupMusic);
    }
    else if(g_roundNum < 9)
    {
        float freezeTime = GetConVarFloat(FindConVar("mp_freezetime"));

        g_songPicker = GetRandomInt(g_warmupLen, g_warmupLen + g_roundLen - 1);
        CreateTimer(freezeTime, Timer_RoundMusic, g_songPicker);
    }

}

// Action OnRoundEnd(Event event, char[] name, bool dontBroadcast)
// {
    // int endPicker = 0;
    
    // for(int i = 1; i < MAXPLAYERS; i++)
    // {
    //     if(IsClientConnected(i) && IsClientInGame(i))
    //         StopSound(i, SNDCHAN_AUTO, g_roundPath[g_songPicker]);
    // }

    // if(event.GetInt("winner") == g_playerIndex)
    // {
    //     endPicker = GetRandomInt(g_warmupLen + g_roundLen, g_endWinLen - 1);
    //     EmitSoundToAll(g_roundEndWinPath[endPicker]);
    // }
    // else
    // {
    //     endPicker = GetRandomInt(g_warmupLen + g_roundLen + g_endWinLen, g_endLooseLen - 1);
    //     EmitSoundToAll(g_roundEndLoosePath[endPicker]);
    // }
// }

Action OnGameEnd(Event event, char[] name, bool dontbroadcast)
{
        CreateTimer(2.0, Timer_GameEnd, TIMER_REPEAT);
}

// Action OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
// {
    
//     int client = GetClientOfUserId(event.GetInt("userid"));

//     if(g_roundNum == 0)
        
// }

void GetMusic()
{
    int songNum = 0;
    KeyValues kv = new KeyValues("Music"); // start in Music section

    if(!kv.ImportFromFile(g_cfgPath))
        SetFailState("%s not a KeyValues file or not KeyValues format.", g_cfgPath);


/* Warmup */
    if(!kv.JumpToKey("Warmup"))
        SetFailState("Unable to find \"Warmup\" section in %s.", g_cfgPath);
    kv.GotoFirstSubKey(false);
    do
    {
        char songName[MAX_NAME_LENGTH];
        
        kv.GetSectionName(songName, sizeof(songName));
        g_warmpupMusic[g_musicIndex] = songName;
        g_musicIndex++;
        g_warmupLen++;
        songNum = g_musicIndex;
    }
    while(kv.GotoNextKey(false));

    g_musicIndex -= songNum;

    kv.Rewind();

    do
    {
        char songPath[MAX_NAME_LENGTH];
        kv.GotoFirstSubKey();
        kv.GetString(g_warmpupMusic[g_musicIndex], songPath, sizeof(songPath), "Load warmup path failed");
        g_warmupPath[g_musicIndex] = songPath;
        g_musicIndex++;
    }
    while(g_musicIndex != songNum);

    // songNum = 0;
    kv.Rewind();
    // return;

    int garbage = 0;

/* Round */
    if(!kv.JumpToKey("Round"))
        SetFailState("Unable to find \"Round\" section in %s.", g_cfgPath);
    kv.GotoFirstSubKey(false);
    do
    {
        char songName[MAX_NAME_LENGTH];
        
        kv.GetSectionName(songName, sizeof(songName));
        g_roundMusic[g_musicIndex] = songName;
        //PrintToServer("%s %d", g_roundMusic[g_musicIndex], g_musicIndex);
        g_musicIndex++;
        g_roundLen++;
        songNum++;
        garbage++;
    }
    while(kv.GotoNextKey(false));

    g_musicIndex -= garbage;

    kv.Rewind();
    kv.JumpToKey("Round");
    do
    {
        char songPath[MAX_NAME_LENGTH];
        kv.GotoFirstSubKey();
        kv.GetString(g_roundMusic[g_musicIndex], songPath, sizeof(songPath), "Load round path failed");
        g_roundPath[g_musicIndex] = songPath;
        g_musicIndex++;
    }
    while(g_musicIndex != songNum);

    garbage = 0;
    kv.Rewind();

/* RoundEnd */
    if(!kv.JumpToKey("RoundEnd"))
        SetFailState("Unable to find \"RoundEnd\" section in %s.", g_cfgPath);
    if(!kv.GotoFirstSubKey(false))
        SetFailState("Unable to find \"Win\" or \"Loose\" section(s) in %s.", g_cfgPath);
    int winSongNum = 0, looseSongNum = 0;
    kv.GotoFirstSubKey(false);

    do//win?
    {
        char songName[MAX_NAME_LENGTH];
        
        kv.GetSectionName(songName, sizeof(songName));
        g_roundEndWinMusic[g_musicIndex] = songName;
        // PrintToServer("%s %d", g_roundEndWinMusic[g_musicIndex], g_musicIndex);
        g_musicIndex++;
        g_endWinLen++;
        songNum++;
        winSongNum++;
        garbage++;
    }
    while(kv.GotoNextKey(false));

    kv.GoBack();
    kv.GotoNextKey();
    kv.GotoFirstSubKey(false);

    do//loose?
    {
        char songName[MAX_NAME_LENGTH];
        
        kv.GetSectionName(songName, sizeof(songName));
        g_roundEndLooseMusic[g_musicIndex] = songName;
        // PrintToServer("%s %d", g_roundEndLooseMusic[g_musicIndex], g_musicIndex);
        g_musicIndex++;
        songNum++;
        looseSongNum++;
        g_endLooseLen++;
        garbage++;
    }
    while(kv.GotoNextKey(false));

    g_musicIndex -= (looseSongNum + winSongNum);

    kv.Rewind();
    kv.JumpToKey("RoundEnd");
    kv.GotoFirstSubKey(false);
    do
    {
        char songPath[MAX_NAME_LENGTH];
        kv.GotoFirstSubKey();
        kv.GetString(g_roundEndWinMusic[g_musicIndex], songPath, sizeof(songPath), "Load end win path failed");
        g_roundEndWinPath[g_musicIndex] = songPath;
        // PrintToServer("%s %s %d", g_roundEndWinMusic[g_musicIndex], g_roundEndWinPath[g_musicIndex], g_musicIndex);
        g_musicIndex++;
    }
    while(g_musicIndex != (songNum - looseSongNum));

    kv.Rewind();
    kv.JumpToKey("RoundEnd");
    kv.GotoFirstSubKey(false);
    kv.GotoNextKey(false);
    do
    {
        char songPath[MAX_NAME_LENGTH];
        kv.GotoFirstSubKey();
        kv.GetString(g_roundEndLooseMusic[g_musicIndex], songPath, sizeof(songPath), "Load end loose path failed");
        g_roundEndLoosePath[g_musicIndex] = songPath;
        // PrintToServer("%s %s %d", g_roundEndLooseMusic[g_musicIndex], g_roundEndLoosePath[g_musicIndex], g_musicIndex);
        g_musicIndex++;
    }
    while(g_musicIndex != songNum);

    garbage = 0;
    kv.Rewind();

/* GameEnd */
    if(!kv.JumpToKey("GameEnd"))
        SetFailState("Unable to find \"GameEnd\" section in %s.", g_cfgPath);
    kv.GotoFirstSubKey(false);
    do
    {
        char songName[MAX_NAME_LENGTH];
        
        kv.GetSectionName(songName, sizeof(songName));
        g_gameEndMusic[g_musicIndex] = songName;
        g_musicIndex++;
        songNum++;
        g_gameEndLen++;
        garbage++;
    }
    while(kv.GotoNextKey(false));

    g_musicIndex -= garbage;

    kv.Rewind();
    kv.JumpToKey("GameEnd");
    do
    {
        char songPath[MAX_NAME_LENGTH];
        kv.GotoFirstSubKey();
        kv.GetString(g_gameEndMusic[g_musicIndex], songPath, sizeof(songPath), "Load end game path failed");
        g_gameEndPath[g_musicIndex] = songPath;
        // PrintToServer("%s %s %d", g_gameEndMusic[g_musicIndex], g_gameEndPath[g_musicIndex], g_musicIndex);
        g_musicIndex++;
    }
    while(g_musicIndex != songNum);

    garbage = 0;
    delete kv;
}

void DownloadAndPrecache()
{
    // download table is from root folder, so start position need to be sound/misc
    // precaching is from sound folder
    for(int i = 0; i < g_warmupLen; i++)
    {
        char filePath[PLATFORM_MAX_PATH];
        char precache[PLATFORM_MAX_PATH];

        Format(filePath, sizeof(filePath), "sound/%s", g_warmupPath[i]);
        Format(precache, sizeof(precache), "%s", g_warmupPath[i]);

        if(!FileExists(filePath)) // file doesn't exist, search from root folder
        {
            LogMessage("%s doesn't exist, cannot add to download table(warmup)", filePath);
            continue;
        }
        
        AddFileToDownloadsTable(filePath);
        PrecacheSoundAny(precache, true);
        // PrintToServer("%s", g_warmupPath[i]);
        // PrintToServer("add: warmup %s", filePath);
    }

    for(int i = 0; i < g_roundLen; i++)
    {
        char filePath[PLATFORM_MAX_PATH];
        char precache[PLATFORM_MAX_PATH];

        Format(filePath, sizeof(filePath), "sound/%s", g_roundPath[i + g_warmupLen]);
        Format(precache, sizeof(precache), "%s", g_roundPath[i + g_warmupLen]);

        if(!FileExists(filePath))
        {
            LogMessage("%s doesn't exist, cannot add to download table(round)", filePath);
            continue;
        }

        AddFileToDownloadsTable(filePath);
        PrecacheSoundAny(precache, true);

        // PrintToServer("%s", g_roundPath[i + g_warmupLen]);
        // PrintToServer("add round : %s", filePath);
    }

    for(int i = 0; i < g_endWinLen; i++)
    {
        char filePath[PLATFORM_MAX_PATH];
        char precache[PLATFORM_MAX_PATH];

        Format(filePath, sizeof(filePath), "sound/%s", g_roundEndWinPath[i + g_warmupLen + g_roundLen]);
        Format(precache, sizeof(precache), "%s", g_roundEndWinPath[i + g_warmupLen + g_roundLen]);

        if(!FileExists(filePath))
        {
            LogMessage("%s doesn't exist, cannot add to download table(win round)", filePath);
            continue;
        }

        AddFileToDownloadsTable(filePath);
        PrecacheSoundAny(precache, true);
    }

    for(int i = 0; i < g_endLooseLen; i++)
    {
        char filePath[PLATFORM_MAX_PATH];
        char precache[PLATFORM_MAX_PATH];

        Format(filePath, sizeof(filePath), "sound/%s", g_roundEndLoosePath[i + g_warmupLen + g_roundLen + g_endWinLen]);
        Format(precache, sizeof(precache), "%s", g_roundEndLoosePath[i + g_warmupLen + g_roundLen + g_endWinLen]);

        if(!FileExists(filePath))
        {
            LogMessage("%s doesn't exist, cannot add to download table(loose round)", filePath);
            continue;
        }

        AddFileToDownloadsTable(filePath);
        PrecacheSoundAny(precache, true);
    }

    for(int i = 0; i < g_gameEndLen; i++)
    {
        char filePath[PLATFORM_MAX_PATH];
        char precache[PLATFORM_MAX_PATH];

        Format(filePath, sizeof(filePath), "sound/%s", g_gameEndPath[i + g_warmupLen + g_roundLen + g_endWinLen + g_endLooseLen]);
        Format(precache, sizeof(precache), "%s", g_gameEndPath[i + g_warmupLen + g_roundLen + g_endWinLen + g_endLooseLen]);

        if(!FileExists(filePath))
        {
            LogMessage("%s doesn't exist, cannot add to download table(end game)", filePath);
            continue;
        }

        AddFileToDownloadsTable(filePath);
        PrecacheSoundAny(precache, true);
    }
}

Action Timer_RoundMusic(Handle tiemr, int songPicker)
{
    char filePath[PLATFORM_MAX_PATH];

    Format(filePath, sizeof(filePath), "%s", g_roundPath[songPicker]);

    for(int i = 1; i < MAXPLAYERS; i++)
    {
        if(Client_IsValid(i) && !IsFakeClient(i))
        {   
            EmitSoundToClientAny(i, filePath, _, _, SNDLEVEL_NONE, _, g_clientVolume[i]);
            // entity: default = from player, world = no sound, local player = no sound
            // channel: default = auto, body = move to stop sound, voice = die to stop sound, stream & static & voice_base  & user_base = auto
            // level: default = notmal, rocket = no sound, home = normal, NONE = best without attenuation
        }
    }

    PrintToChatAll("Now is playing: %s", g_roundMusic[songPicker], songPicker);
}

Action Timer_GameEnd(Handle timer)
{
    for(int i = 1; i < MAXPLAYERS; i++)
    {
        if(Client_IsValid(i) && !IsFakeClient(i))
        {   
            EmitSoundToClientAny(i, g_gameEndPath[g_warmupLen + g_roundLen + g_endWinLen + g_endLooseLen], _, _, SNDLEVEL_NONE);
            // entity: default = from player, world = no sound, local player = no sound
            // channel: default = auto, body = move to stop sound, voice = die to stop sound, stream & static & voice_base  & user_base = auto
            // level: default = notmal, rocket = no sound, home = normal, NONE = best without attenuation
        }
    }
    PrintToChatAll("Game is over~");
}

Action Timer_WarmupMusic(Handle timer, int client)
{       
    for(int i = 1; i < MAXPLAYERS; i++)
    {
        if(Client_IsValid(i) && !IsFakeClient(i))
            EmitSoundToClientAny(i, g_warmupPath[g_warmupLen - 1], _, _, SNDLEVEL_NONE);
    }
}