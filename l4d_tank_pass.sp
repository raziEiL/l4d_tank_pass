#define PLUGIN_VERSION "2.0"

#pragma semicolon 1
/*
|--------------------------------------------------------------------------
| INCLUDES
|--------------------------------------------------------------------------
*/
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#pragma newdecls required
/*
|--------------------------------------------------------------------------
| MACROS
|--------------------------------------------------------------------------
*/
#define SZF(%0) 	%0, sizeof(%0)
#define MPS 33 // l4d max players + 1
#define CID(%0) 	GetClientOfUserId(%0)
#define UID(%0) 	GetClientUserId(%0)
/*
|--------------------------------------------------------------------------
| VARIABLES
|--------------------------------------------------------------------------
*/
enum
{
	Validate_Default,
	Validate_NotiyfyTarget,
	Validate_SkipTarget
}

int g_iTankId;
bool g_bLockMenu;
GlobalForward g_fwdOnTankPass;
char g_sCvarCmd[32];

public Plugin myinfo =
{
	name = "[L4D & L4D2] Tank Pass",
	author = "Scratchy [Laika] & raziEiL [disawar1]",
	description = "Allows Tank to pass control to another player",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/raziEiL/"
}

public void OnPluginStart()
{
	// forward TP_OnTankPass(int old_tank, int new_tank);
	g_fwdOnTankPass = new GlobalForward("TP_OnTankPass", ET_Ignore, Param_Cell, Param_Cell);

	LoadTranslations("l4d_tank_pass.phrases");
	LoadTranslations("common.phrases");

	ConVar cVar = CreateConVar("l4d_tank_pass_exec", "sm_tankhud", "Execute command on client to close 3d party HUD", FCVAR_NOTIFY);
	cVar.GetString(SZF(g_sCvarCmd));
	cVar.AddChangeHook(OnCvarChanged_Button);

	HookEvent("tank_spawn", EventTankSpawn);

	RegConsoleCmd("sm_tankpass", CmdTankPass);
	RegAdminCmd("sm_tankfpass", CmdTankFPass, ADMFLAG_ROOT, "sm_tankfpass <#userid|name> - Force to pass control of the Tank to target player");
}

public Action CmdTankPass(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	if (g_bLockMenu){
		PrintToChat(client, "%t", "phrase7");
		return Plugin_Handled;
	}
	if (ValidateOffer(Validate_SkipTarget, client))
		TankPassMenu(client);
	return Plugin_Handled;
}

public Action CmdTankFPass(int client, int args)
{
	if (client && args){

		char sArg[32], sName[MAX_TARGET_LENGTH];
		int iTargetList[MPS], iCount;
		bool bIsML;
		GetCmdArg(1, SZF(sArg));

		if ((iCount = ProcessTargetString(
			sArg,
			client,
			iTargetList,
			MPS,
			COMMAND_FILTER_ALIVE,
			SZF(sName),
			bIsML)) <= 0){
			ReplyToTargetError(client, iCount);
			return Plugin_Handled;
		}

		int tank = GetTank();

		if (ValidateOffer(Validate_Default, tank, iTargetList[0], client))
			TankPass(tank, iTargetList[0], true);
	}
	else
		ReplyToCommand(client, "sm_tankfpass <#userid|name>");

	return Plugin_Handled;
}

public Action EventTankSpawn(Event h_Event, char[] s_Name, bool b_DontBroadcast)
{
	int userId = h_Event.GetInt("userid");
	int tank = CID(userId);

	PrintToChatAll("tank spawn %N, pass %d", tank, L4D2Direct_GetTankPassedCount());

	if (!IsFakeClient(tank))
		CreateTimer(1.5, hTimer, userId);
}

public Action hTimer(Handle timer, any client)
{
	client = CID(client);
	if (!IsValidTank(client) || L4D2Direct_GetTankPassedCount() != 1) return;

	g_bLockMenu = false;
	PrintToChat(client, "%t", "phrase1");
}

void TankPassMenu(int client)
{
	bool hasTarget;
	Menu menu = new Menu(MenuHandler);
	menu.SetTitle("%T", "phrase4", client);
	char sName[MAX_NAME_LENGTH], sId[12];
	for (int i; i <= MaxClients; i++){

		if (client == i || !IsInfected(i) || IsFakeClient(i)) continue;

		hasTarget = true;
		GetClientName(i, SZF(sName));
		IntToString(UID(i), SZF(sId));
		menu.AddItem(sId, sName);
	}
	if (!hasTarget){

		g_bLockMenu = false;
		delete menu;
		return;
	}
	g_bLockMenu = true;
	ExecCmd(client);
	menu.ExitButton = true;
	menu.Display(client, 10);
}

public int MenuHandler(Menu menu, MenuAction action, int tank, int index)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sId[12];
			menu.GetItem(index, SZF(sId));
			int target = CID(StringToInt(sId));

			if (ValidateOffer(Validate_Default, tank, target))
				OfferMenu(tank, target);
			else
				g_bLockMenu = false;
		}
		case MenuAction_Cancel:
		{
			g_bLockMenu = false;
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

void OfferMenu(int tank, int target)
{
	g_iTankId = UID(tank);
	ExecCmd(target);
	char sTemp[64];
	Menu menu = new Menu(OfferMenuHandler);
	FormatEx(SZF(sTemp), "%T", "phrase5", target);
	menu.SetTitle(sTemp);
	FormatEx(SZF(sTemp), "%T", "Yes", target);
	FormatEx(SZF(sTemp), "%T", "No", target);
	menu.AddItem("", sTemp);
	menu.ExitButton = true;
	menu.Display(target, 10);
}

public int OfferMenuHandler(Menu menu, MenuAction action, int target, int index)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			int tank = CID(g_iTankId);

			if (index == 0){
				if (ValidateOffer(Validate_NotiyfyTarget, tank, target))
					TankPass(tank, target);
			}
			else if (IsValidTank(tank))
				PrintToChat(tank, "%t", "phrase6");
		}
		case MenuAction_Cancel:
		{
			int tank = CID(g_iTankId);
			if (IsValidTank(tank))
				PrintToChat(tank, "%t", "phrase6");
		}
		case MenuAction_End:
		{
			g_bLockMenu = false;
			delete menu;
		}
	}
}

void TankPass(int tank, int target, bool byAdmin = false)
{
	if (byAdmin)
		PrintToTeam(3, 1, "%t", "phrase9", target);
	else
		PrintToTeam(3, 1, "%t", "phrase3", tank, target);

	if (IsInfectedAlive(target))
		ForcePlayerSuicide(target);

	// bugfix
	float vPos[3], vAng[3];
	GetClientAbsOrigin(tank, vPos);
	GetClientAbsAngles(tank, vAng);
	TeleportEntity(target, vPos, vAng, NULL_VECTOR);

	L4D_ReplaceTank(tank, target);
	L4D2Direct_SetTankPassedCount(2);

	Call_StartForward(g_fwdOnTankPass);
	Call_PushCell(tank);
	Call_PushCell(target);
	Call_Finish();
}

void ExecCmd(int client)
{
	if (g_sCvarCmd[0] && GetClientMenu(client) == MenuSource_Normal)
		FakeClientCommand(client, g_sCvarCmd);
}

int GetTank()
{
	for (int i; i <= MaxClients; i++){
		if (IsValidTank(i))
			return i;
	}
	return 0;
}

bool ValidateOffer(int validate = Validate_Default, int tank, int target = 0, int client = 0)
{
	bool hasTarget = validate == Validate_SkipTarget ? true : IsValidTarget(target);
	bool hasTank = IsValidTank(tank);
	tank = tank ? tank : client;

	if (!hasTank){
		if (client)
			PrintToChat(client, "%t", "phrase7");
		if (validate == Validate_NotiyfyTarget && hasTarget)
			PrintToChat(target, "%t", "phrase7");
		return false;
	}
	if (L4D2Direct_GetTankPassedCount() != 1){
		if (hasTank)
			PrintToChat(tank, "%t", "phrase2");
		if (validate == Validate_NotiyfyTarget && hasTarget)
			PrintToChat(target, "%t", "phrase2");
		return false;
	}
	if (!hasTarget){
		PrintToChat(tank, "%t", "Player no longer available");
		return false;
	}
	if (IsClientOnFire(tank)){
		PrintToChat(tank, "%t", "phrase8");
		if (validate == Validate_NotiyfyTarget)
			PrintToChat(target, "%t", "phrase8");
		return false;
	}
	return true;
}

bool IsClientOnFire(int client)
{
	return  (GetEntityFlags(client) & FL_ONFIRE) == FL_ONFIRE;
}

bool IsValidTarget(int target)
{
	return IsValid(target) && !IsPlayerTank(target);
}

bool IsValidTank(int tank)
{
	return IsValid(tank) && IsPlayerTank(tank) && IsInfectedAlive(tank) && !IsIncapacitated(tank);
}

bool IsValid(int client)
{
	return IsClient(client) && IsInfected(client) && !IsFakeClient(client);
}

public void OnCvarChanged_Button(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(oldValue, newValue))
		convar.GetString(SZF(g_sCvarCmd));
}