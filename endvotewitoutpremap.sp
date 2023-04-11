#include <regex>
#include <sdktools>

ArrayList EndMatchMapGroupVoteList; // store and refresh mapgroup map list every map change and match end
StringMap EndMatchMapGroupVoteExcluded; // store previous maps at end of match

int excluded_amount = 5;

public void OnPluginStart()
{
    EndMatchMapGroupVoteExcluded = new StringMap();    
    HookEventEx("cs_win_panel_match", cs_win_panel_match); // Match totally ends
}

public OnConfigsExecuted()
{
    RequestFrame(frame);
}

public void frame(any data)
{
    // Need maplist for "nominate"
    CreateMapList();
}

public void cs_win_panel_match(Event event, const char[] name, bool dontBroadcast)
{
    // Collect map list end of match, if mapgroup have changed to another
    //Note: If server change mapgroup in the middle of the game, players still have previous mapgroup maps in vote.
    //        Players need reconnect to server to update they list of maps.
    CreateMapList();



    // Keep count previous maps and how many times have excluded from vote
    char buffer[PLATFORM_MAX_PATH];
    int value;
    StringMapSnapshot snapshot = EndMatchMapGroupVoteExcluded.Snapshot();

    for(int x = 0; x < snapshot.Length; x++)
    {
        snapshot.GetKey(x, buffer, sizeof(buffer));
        EndMatchMapGroupVoteExcluded.GetValue(buffer, value);
        EndMatchMapGroupVoteExcluded.SetValue(buffer, value+1, true);
        //PrintToServer("Excluded %i %s %i", x, buffer, value);

        if(value >= excluded_amount)
        {
            //PrintToServer("Remove %i %s %i", x, buffer, value);
            EndMatchMapGroupVoteExcluded.Remove(buffer);
        }
    }

    delete snapshot;

    // Exclude current map from vote
    GetCurrentMap(buffer, sizeof(buffer));
    EndMatchMapGroupVoteExcluded.SetValue(buffer, 1, true);
    //PrintToServer("exclude new map %s", buffer);



    int ent = FindEntityByClassname(-1, "cs_gamerules");

    if(ent != -1)
    {
        int VoteOptionArraySize = GetEntPropArraySize(ent, Prop_Send, "m_nEndMatchMapGroupVoteOptions");
        int[] VoteOptions = new int[VoteOptionArraySize];

        // save given map indexs
        for(int x = 0; x < VoteOptionArraySize; x++)
        {
            VoteOptions[x] = GameRules_GetProp("m_nEndMatchMapGroupVoteOptions", _, x);
        }

        bool VoteOptionAlready;

        for(int x = 0; x < VoteOptionArraySize; x++)
        {

            if(VoteOptions[x] == -1 || VoteOptions[x] >= EndMatchMapGroupVoteList.Length) return;

            EndMatchMapGroupVoteList.GetString(VoteOptions[x], buffer, sizeof(buffer));
            //PrintToServer("-option %i %s", x, buffer);

            // map have played newly
            if(EndMatchMapGroupVoteExcluded.GetValue(buffer, value))
            {
                //PrintToServer("-%i %s", VoteOptions[x], buffer);
                for(int i = 0; i < EndMatchMapGroupVoteList.Length; i++)
                {
                    EndMatchMapGroupVoteList.GetString(i, buffer, sizeof(buffer));
                    //PrintToServer("--%i %s", i, buffer);

                    if(!EndMatchMapGroupVoteExcluded.GetValue(buffer, value))
                    {
                        for(int l = 0; l < VoteOptionArraySize; l++)
                        {
                            if(VoteOptions[l] == i)
                            {
                                //PrintToServer("SAME!!");
                                VoteOptionAlready = true;
                            }
                        }

                        if(VoteOptionAlready)
                        {
                            GameRules_SetProp("m_nEndMatchMapGroupVoteOptions", -1, _, x, true);
                            VoteOptionAlready = false;
                            i++;
                            continue;
                        }


                        //PrintToServer("Change %i to %i", VoteOptions[x], i)
                        VoteOptions[x] = i;
                        GameRules_SetProp("m_nEndMatchMapGroupVoteOptions", i, _, x, true);
                        break;
                    }                    
                }
            }
        }

    }
}


CreateMapList()
{
    if(EndMatchMapGroupVoteList != null) delete EndMatchMapGroupVoteList;
    EndMatchMapGroupVoteList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

    // I really hate to do this way, grab map list:(
    char consoleoutput[5000];
    ServerCommandEx(consoleoutput, sizeof(consoleoutput), "print_mapgroup_sv");

    int skip;
    int sub;

    char buffer[PLATFORM_MAX_PATH];
    Regex regex = new Regex("^[[:blank:]]+(\\w.*)$", PCRE_MULTILINE);
    
    while( (sub = regex.Match(consoleoutput[skip])) > 0 )
    {
        if(!regex.GetSubString(0, buffer, sizeof(buffer)))
        {
            break;
        }

        skip += StrContains(consoleoutput[skip], buffer);
        skip += strlen(buffer);

        for(int x = 1; x < sub; x++)
        {
            if(!regex.GetSubString(x, buffer, sizeof(buffer)))
            {
                break;
            }
            EndMatchMapGroupVoteList.PushString(buffer); // Add also false maps to match vote indexs
        }
    
    }
    
    delete regex;
    
} 