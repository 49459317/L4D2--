#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.1.0"

public Plugin myinfo = {
	name		= "Double Jump",
	author		= "Paegus & StrikerTheHedgefox",
	description	= "Allows double-jumping.",
	version		= PLUGIN_VERSION,
	url			= ""
}

ConVar g_cvJumpEnable, g_cvJumpBoost, g_cvJumpMax;
	
int g_fLastButtons[MAXPLAYERS+1];
int g_iJumps[MAXPLAYERS+1];

int g_iJumpMax;
int g_bDoubleJump;

float g_flBoost;
	
public void OnPluginStart()
{
	CreateConVar("sm_doublejump_version", PLUGIN_VERSION, "多段跳插件的版本", FCVAR_NOTIFY);
	
	RegAdminCmd("sm_ddt", Command_doublejump, ADMFLAG_KICK, "管理员开关多段跳");
	RegAdminCmd("sm_ddtcs", Command_JumpMax, ADMFLAG_KICK, "管理员设置多段跳次数");
	
	g_cvJumpEnable = CreateConVar("l4d2_doublejump_Enabled", "0", "启用多段跳(指令!ddt关闭或开启多段跳) 0=禁用, 1=启用", FCVAR_NOTIFY);
	g_cvJumpBoost = CreateConVar("l4d2_doublejump_boost", "320.0", "设置额外跳跃时的高度(不包括第一次跳跃)", FCVAR_NOTIFY);
	g_cvJumpMax = CreateConVar("l4d2_doublejump_Max", "2", "设置额外的跳跃次数", FCVAR_NOTIFY);
	
	//AutoExecConfig(true, "l4d2_doublejump");
	
	g_cvJumpEnable.AddChangeHook(ConVarChangedcvJump);
	g_cvJumpBoost.AddChangeHook(ConVarChangedcvJump);
	g_cvJumpMax.AddChangeHook(ConVarChangedcvJump);
}

public Action Command_doublejump(int client, int args)
{
	if (g_bDoubleJump)
	{
		g_cvJumpEnable.IntValue = 0;
		PrintToChat(client, "\x04[提示]\x05多段跳已\x03关闭\x05.");
	}
	else
	{
		g_cvJumpEnable.IntValue = 1;
		PrintToChat(client, "\x04[提示]\x05多段跳已\x03开启\x05.");
	}
	return Plugin_Handled;
}

public Action Command_JumpMax(int client, int args)
{
	if (g_bDoubleJump == 0)
	{
		PrintToChat(client, "\x04[提示]\x05多段跳没有\x03启用\x05,聊天窗口输入\x03!ddt\x05启用功能.");
		return Plugin_Handled;
	}
	if (args != 1)
	{
		PrintToChat(client, "\x04[提示]\x05你必须设置跳跃多少次数,举例\x04:\x03!ddtcs \x05次数.");
		return Plugin_Handled;
	}
	args = GetCmdArgInt(1);
	g_cvJumpMax.IntValue = args;
	PrintToChat(client, "\x04[提示]\x05跳跃次数已设置为\x03%d\x05.", args);
	return Plugin_Handled;
}

public void ConVarChangedcvJump(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2doublejump();
}

public void OnMapStart()
{
	l4d2doublejump();
}

void l4d2doublejump()
{
	g_bDoubleJump = g_cvJumpEnable.IntValue;
	g_flBoost = g_cvJumpBoost.FloatValue;
	g_iJumpMax = g_cvJumpMax.IntValue;
}

public void OnConfigsExecuted()
{
	l4d2doublejump();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (g_bDoubleJump == 1)
	{
			int fCurFlags = GetEntityFlags(client);
			if (fCurFlags & FL_ONGROUND)
			{
				Landed(client);
			}
			else if (!(g_fLastButtons[client] & IN_JUMP) && (buttons & IN_JUMP) && !(fCurFlags & FL_ONGROUND))
			{
				ReJump(client);
			}
			g_fLastButtons[client] = buttons;
	}
	return Plugin_Stop;
}

void Landed(int client)
{
	g_iJumps[client] = 0;
}

void ReJump(int client)
{
	if (g_iJumps[client] < g_iJumpMax)
	{						
		g_iJumps[client]++;
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);

		vVel[2] = g_flBoost;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}