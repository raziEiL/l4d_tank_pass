#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d_direct>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

static IsTankInGame, bool:g_bLockMenu, Handle:g_fwdOnTankPass;

public Plugin:myinfo =
{
	name = "[L4D] Tank pass",
	author = "Scratchy [Laika] & raziEiL [disawar1]",
	description = "Allows Tank to pass control to another player",
	version = "1.0",
	url = ""
}

public OnPluginStart()
{
	// forward TP_OnTankPass(old_tank, new_tank);
	g_fwdOnTankPass = CreateGlobalForward("TP_OnTankPass", ET_Ignore, Param_Cell, Param_Cell);

	HookEvent("tank_spawn", EventTankSpawn);
	HookEvent("player_death", EventPlayerDeath);
	RegConsoleCmd("sm_tankpass", Command_TankPass);
	LoadTranslations("l4d_tank_pass.phrases");
}

public Action:Command_TankPass(client, args)
{
	if (IsTankInGame == client)
		TV_StartTankPass(client);
}

public OnClientDisconnect(client)
{
	if (IsTankInGame == client)
		IsTankInGame = 0;
}

public Action:EventPlayerDeath(Handle:h_Event, String:s_Name[], bool:b_DontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(h_Event, "userid"));
	if (IsTankInGame == tank) IsTankInGame = 0;
}

public Action:EventTankSpawn(Handle:h_Event, String:s_Name[], bool:b_DontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(h_Event, "userid"));
	if (IsFakeClient(tank))
	{
		IsTankInGame = 0;
		return;
	}
	else IsTankInGame = tank;
	if (L4DDirect_GetTankPassedCount() != 1) return;
	CreateTimer(2.0, hTimer, tank);
}

public Action:hTimer(Handle:timer, any:client)
{
	PrintHintText(client, "%t", "phrase1");
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if (IsTankInGame && IsTankInGame == client && buttons & IN_ZOOM && !g_bLockMenu){

		if (GetClientTeam(client) != 3 || !IsPlayerTank(client)){

			IsTankInGame = 0;
			return Plugin_Continue;
		}

		if (L4DDirect_GetTankPassedCount() != 1)
		{
			IsTankInGame = 0;
			PrintToChat(client, "%t", "phrase2");
			return Plugin_Continue;
		}

		g_bLockMenu = true;
//		FakeClientCommand(client, "tankhud");
		CreateTimer(5.0, timer);
//		if (GetClientMenu(client) == MenuSource_Normal)
//		FakeClientCommand(client, "tankhud");
		TV_StartTankPass(client);
	}
	return Plugin_Continue;
}

public Action:timer(Handle:timer)
{
	g_bLockMenu = false;
}

TV_StartTankPass(client)
{
	new Handle:hTankVoteMenu = CreateMenu(TV_VoteCallBack), bool:bAnyTarget;
	SetMenuTitle(hTankVoteMenu, "%T", "phrase4", client);
	new String:sName[MAX_NAME_LENGTH], String:sIndex[8];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidEntity(i) || client == i || !IsClientInGame(i) || GetClientTeam(i) != 3 || IsFakeClient(i)) continue;

		bAnyTarget = true;
		GetClientName(i, sName, MAX_NAME_LENGTH);
		IntToString(i, sIndex, 8);
		AddMenuItem(hTankVoteMenu, sIndex, sName);
	}
	if (!bAnyTarget){

		CloseHandle(hTankVoteMenu);
		return;
	}
	SetMenuExitButton(hTankVoteMenu, true);
	DisplayMenu(hTankVoteMenu, client, 10);
}

public TV_VoteCallBack(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (IsTankInGame && L4DDirect_GetTankPassedCount() == 1){

				decl String:sIndex[8], String:sName[MAX_NAME_LENGTH];
				GetMenuItem(menu, param2, sIndex, 8, _, sName, MAX_NAME_LENGTH);
				new index = StringToInt(sIndex);

				if (index && param1 && IsClientInGame(index) && GetClientTeam(index) == 3 && !IsFakeClient(index) &&
					IsClientInGame(param1) && GetClientTeam(param1) == 3 && !IsFakeClient(param1) && IsPlayerTank(param1) && IsInfectedAlive(param1) && !IsIncapacitated(param1)){

					if (IsInfectedAlive(index))
						ForcePlayerSuicide(index);

					PrintToChat(index, "%t", "phrase3", param1);
					L4DDirect_ReplaceTank(param1, index);
					L4DDirect_SetTankPassedCount(L4DDirect_GetTankPassedCount() + 1);
					IsTankInGame = 0;

					Call_StartForward(g_fwdOnTankPass);
					Call_PushCell(param1);
					Call_PushCell(index);
					Call_Finish();
				}
			}
		}
	}
}