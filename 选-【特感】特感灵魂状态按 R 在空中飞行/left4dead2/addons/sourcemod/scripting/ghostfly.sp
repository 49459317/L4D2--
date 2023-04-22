#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define MOVETYPE_WALK 2
#define MOVETYPE_FLYGRAVITY 5
#define MOVECOLLIDE_DEFAULT 0
#define MOVECOLLIDE_FLY_BOUNCE 1

#define TEAM_INFECTED 3
#define CVAR_FLAGS FCVAR_PLUGIN

#define IS_VALID_CLIENT(%1) (%1 > 0 && %1 <= MaxClients)
#define IS_CONNECTED_INGAME(%1) (IsClientConnected(%1) && IsClientInGame(%1))
#define IS_SURVIVOR(%1) (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1) (GetClientTeam(%1) == 3)

#define IS_VALID_INGAME(%1) (IS_VALID_CLIENT(%1) && IS_CONNECTED_INGAME(%1))
#define IS_VALID_SURVIVOR(%1) (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1) (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_SURVIVOR_ALIVE(%1) (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1) (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

Handle GhostFly, FlySpeed, MaxSpeed;
bool g_bEnabled = false;
bool g_bMustTouchGround = true;
bool Flying[MAXPLAYERS+1], BlockSpawn[MAXPLAYERS+1];

float g_fFlySpeed = 50.0, g_fMaxSpeed = 500.0;

#define PLUGIN_VERSION "2.0.0"

public Plugin myinfo =
{
	name = "ghostfly",
	author = "Madcap (modified by dcx2)",
	description = "Fly as a ghost.",
	version = PLUGIN_VERSION,
	url = "http://maats.org"
}

public void OnPluginStart()
{
	GhostFly = CreateConVar("l4d_ghost_fly", "1", "幽灵飞行能力. 0=关闭, 1=开启, 2=在空中不可以灵魂状态生成", FCVAR_NOTIFY,true, 0.0, true, 2.0);
	FlySpeed = CreateConVar("l4d_ghost_fly_speed", "50", "幽灵飞行速度", FCVAR_NOTIFY, true, 0.0);
	MaxSpeed = CreateConVar("l4d_ghost_max_speed", "500", "幽灵飞行最高速度", FCVAR_NOTIFY, true, 300.0);

	HookConVarChange(GhostFly, OnGhostFlyChanged);
	HookConVarChange(FlySpeed, OnFlySpeedChanged);
	HookConVarChange(MaxSpeed, OnMaxSpeedChanged);

	//AutoExecConfig(true, "ghostfly");

	g_bEnabled = GetConVarInt(GhostFly) > 0;
	g_bMustTouchGround = GetConVarInt(GhostFly) < 2;
	g_fFlySpeed = GetConVarFloat(FlySpeed);
	g_fMaxSpeed = GetConVarFloat(MaxSpeed);
	
	CreateConVar("l4d_ghost_fly_version", PLUGIN_VERSION, "Ghost Fly Plugin Version", FCVAR_REPLICATED|FCVAR_NOTIFY);

	HookEvent("ghost_spawn_time", EventGhostNotify2);
	HookEvent("player_first_spawn", EventGhostNotify1);
}

public void OnGhostFlyChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	g_bEnabled = StringToInt(newVal) > 0;
	g_bMustTouchGround = StringToInt(newVal) == 1;
}

public void OnFlySpeedChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	g_fFlySpeed = StringToFloat(newVal);
}

public void OnMaxSpeedChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	g_fMaxSpeed = StringToFloat(newVal);
}

public void OnClientConnected(int client)
{
	Flying[client] = false;
	BlockSpawn[client] = false;
}

// moving this outside of to save initialization
bool elig;

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (g_bEnabled)
	{
		elig = IS_VALID_INFECTED(client) && IsPlayerGhost(client);
		
		// If we are spawn blocking, and we are either not eligible or we're on the ground, unblock spawn
		if (BlockSpawn[client] && (!elig || GetEntProp(client, Prop_Send, "m_fFlags") & FL_ONGROUND))
		{
			BlockSpawn[client] = false;
		}
		
		if (g_bMustTouchGround && elig && BlockSpawn[client])
		{
			buttons &= ~IN_ATTACK;
		}
		
		if (elig && buttons & IN_RELOAD)
		{
			if (Flying[client]) KeepFlying(client);
			else StartFlying(client);
		}
		else if (Flying[client]) StopFlying(client);
	}
	return Plugin_Continue;
}

stock bool IsPlayerGhost(int client)
{
	return (GetEntProp(client, Prop_Send, "m_isGhost", 1) > 0);
}

public Action StartFlying(int client)
{
	Flying[client]=true;
	if (g_bMustTouchGround && !GetAdminFlag(GetUserAdmin(client), Admin_Root)) BlockSpawn[client] = true;
	SetMoveType(client, MOVETYPE_FLYGRAVITY, MOVECOLLIDE_FLY_BOUNCE);
	AddVelocity(client, g_fFlySpeed);
	return Plugin_Continue;
}

public Action KeepFlying(int client)
{
	AddVelocity(client, g_fFlySpeed);
	return Plugin_Continue;
}

public Action StopFlying(int client)
{
	Flying[client]=false;
	SetMoveType(client, MOVETYPE_WALK, MOVECOLLIDE_DEFAULT);
	return Plugin_Continue;
}

void AddVelocity(int client, float speed)
{
	float vecVelocity[3];
	GetEntityVelocity(client, vecVelocity);
	vecVelocity[2] += speed;
	if ((vecVelocity[2]) > g_fMaxSpeed) vecVelocity[2] = g_fMaxSpeed;

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}

stock void GetEntityVelocity(int entity, float fVelocity[3])
{
    GetEntPropVector(entity, Prop_Data, "m_vecVelocity", fVelocity);
}  

void SetMoveType(int client, int movetype, int movecollide)
{
	SetEntProp(client, Prop_Send, "movecollide", movecollide);
	SetEntProp(client, Prop_Send, "movetype", movetype);
}

void EventGhostNotify1(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	Notify(client, 0);
}

void EventGhostNotify2(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	Notify(client,GetEventInt(event, "spawntime"));
}

void Notify(int client, int time)
{
	CreateTimer((3.0 + time), NotifyClient, client);
}

Action NotifyClient(Handle timer, any client)
{
	if (IS_VALID_INFECTED(client) && IsPlayerGhost(client))
	{
		PrintToChat(client, "\x04[提示]\x05灵魂状态按\x03R\x05可以飞行.");
	}
	return Plugin_Handled;
}