#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION   "1.0.0"
#define MIN_SPAWN_POINTS 16

public Plugin myinfo =
{
    name        = "Fix Spawn Point",
    author      = "i.car",
    description = "Ensures each team has enough spawn points",
    version     = PLUGIN_VERSION,
    url         = ""
};

// Spawn point position storage structure
ArrayList g_hCTSpawnPoints;
ArrayList g_hTSpawnPoints;

public void OnPluginStart()
{
    // Create dynamic arrays to store spawn point positions
    g_hCTSpawnPoints = new ArrayList(3);    // Store Vector (x, y, z)
    g_hTSpawnPoints  = new ArrayList(3);

    PrintToServer("[FixSpawnPoint] Plugin loaded v%s", PLUGIN_VERSION);
}

public void OnPluginEnd()
{
    // Clean up resources
    delete g_hCTSpawnPoints;
    delete g_hTSpawnPoints;
}

public void OnMapStart()
{
    // Clear previous spawn point data
    g_hCTSpawnPoints.Clear();
    g_hTSpawnPoints.Clear();

    // Delay execution to ensure map is fully loaded
    CreateTimer(3.0, Timer_FixSpawnPoints, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FixSpawnPoints(Handle timer)
{
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    PrintToServer("[FixSpawnPoint] Checking spawn points for map: %s", mapName);

    int ctCount = CountAndStoreSpawnPoints("info_player_counterterrorist", g_hCTSpawnPoints);
    int tCount  = CountAndStoreSpawnPoints("info_player_terrorist", g_hTSpawnPoints);

    PrintToServer("[FixSpawnPoint] Found %d CT spawn points, %d T spawn points", ctCount, tCount);

    // Check if CT spawn points need to be added
    if (ctCount < MIN_SPAWN_POINTS && ctCount > 0)
    {
        int needed = MIN_SPAWN_POINTS - ctCount;
        PrintToServer("[FixSpawnPoint] CT spawn points insufficient, need to add %d more", needed);
        CreateAdditionalSpawnPoints("info_player_counterterrorist", g_hCTSpawnPoints, needed);
    }
    else if (ctCount == 0)
    {
        LogError("[FixSpawnPoint] No CT spawn points found! %s", mapName);
        return Plugin_Stop;
    }

    // Check if T spawn points need to be added
    if (tCount < MIN_SPAWN_POINTS && tCount > 0)
    {
        int needed = MIN_SPAWN_POINTS - tCount;
        PrintToServer("[FixSpawnPoint] T spawn points insufficient, need to add %d more", needed);
        CreateAdditionalSpawnPoints("info_player_terrorist", g_hTSpawnPoints, needed);
    }
    else if (tCount == 0)
    {
        LogError("[FixSpawnPoint] No T spawn points found! %s", mapName);
        return Plugin_Stop;
    }

    // Recalculate final spawn point counts
    int finalCTCount = CountSpawnPoints("info_player_counterterrorist");
    int finalTCount  = CountSpawnPoints("info_player_terrorist");

    PrintToServer("[FixSpawnPoint] Fix completed! Final spawn point counts: CT=%d, T=%d", finalCTCount, finalTCount);

    return Plugin_Stop;
}

int CountAndStoreSpawnPoints(const char[] classname, ArrayList storage)
{
    int   count  = 0;
    int   entity = -1;
    float pos[3], angles[3];

    // Iterate through all entities of the specified class
    while ((entity = FindEntityByClassname(entity, classname)) != -1)
    {
        if (IsValidEntity(entity))
        {
            // Get entity position and angles
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
            GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);

            // Store position information (x, y, z, pitch, yaw, roll)
            storage.PushArray(pos, 3);
            storage.PushArray(angles, 3);

            count++;
        }
    }

    return count;
}

int CountSpawnPoints(const char[] classname)
{
    int count  = 0;
    int entity = -1;

    while ((entity = FindEntityByClassname(entity, classname)) != -1)
    {
        if (IsValidEntity(entity))
        {
            count++;
        }
    }

    return count;
}

void CreateAdditionalSpawnPoints(const char[] classname, ArrayList storage, int needed)
{
    int originalCount = storage.Length / 2;    // Each spawn point stores position and angles, so divide by 2

    if (originalCount <= 0)
    {
        PrintToServer("[FixSpawnPoint] Error: Cannot find original spawn points to copy");
        return;
    }

    for (int i = 0; i < needed; i++)
    {
        // Randomly select an original spawn point to copy
        int   randomIndex = GetRandomInt(0, originalCount - 1);

        float pos[3], angles[3];
        storage.GetArray(randomIndex * 2, pos, 3);           // Position
        storage.GetArray(randomIndex * 2 + 1, angles, 3);    // Angles

        // Create new spawn point entity
        int newEntity = CreateEntityByName(classname);

        if (newEntity != -1)
        {
            // Slightly adjust position to avoid overlap
            pos[0] += GetRandomFloat(-50.0, 50.0);
            pos[1] += GetRandomFloat(-50.0, 50.0);
            pos[2] += GetRandomFloat(0.0, 10.0);

            // Set entity position and angles
            TeleportEntity(newEntity, pos, angles, NULL_VECTOR);

            // Spawn entity
            DispatchSpawn(newEntity);

            PrintToServer("[FixSpawnPoint] Created new %s spawn point at position (%.1f, %.1f, %.1f)",
                          classname, pos[0], pos[1], pos[2]);
        }
        else
        {
            PrintToServer("[FixSpawnPoint] Error: Unable to create new %s entity", classname);
        }
    }
}