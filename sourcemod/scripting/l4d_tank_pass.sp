#define PLUGIN_VERSION "2.2"

#pragma semicolon 1
#pragma newdecls required
/*
|--------------------------------------------------------------------------
| INCLUDES
|--------------------------------------------------------------------------
*/
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <l4d_lib>
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

enum
{
	Menu_Pass,
	Menu_ForcePass,
	Menu_Take
}

int g_iCvarTankHealth, g_iPassedCount, g_iTankId;
GlobalForward g_fwdOnTankPass;
char g_sCvarCmd[32];
TopMenu g_hTopMenu;
bool g_bCvarDamage, g_bCvarFire, g_bCvarReplace, g_bCvarExtinguish, g_bCvarNotify, g_bIsFinal;
ConVar g_hCvarTankHealth, g_hCvarTankBonusHealth;

public Plugin myinfo =
{
	name = "[L4D & L4D2] Tank Pass",
	author = "Scratchy [Laika] & raziEiL [disawar1]",
	description = "Allows the Tank to pass control to another player.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/raziEiL/"
}

public void OnPluginStart()
{
	// forward void TP_OnTankPass(int old_tank, int new_tank);
	g_fwdOnTankPass = new GlobalForward("TP_OnTankPass", ET_Ignore, Param_Cell, Param_Cell);

	LoadTranslations("l4d_tank_pass.phrases");
	LoadTranslations("common.phrases");

	g_hCvarTankHealth = FindConVar("z_tank_health");
	g_hCvarTankBonusHealth = FindConVar("versus_tank_bonus_health");
	g_iCvarTankHealth = CalcTankHealth();

	if (g_hCvarTankBonusHealth)
		g_hCvarTankBonusHealth.AddChangeHook(OnCvarChange_TankHealth);
	g_hCvarTankHealth.AddChangeHook(OnCvarChange_TankHealth);

	CreateConVar("l4d_tank_pass_version", PLUGIN_VERSION, "Tank Pass plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	ConVar cVar = CreateConVar("l4d_tank_pass_command", "sm_tankhud", "Execute command according convar value on old_tank and new_tank to close 3d party HUD.", FCVAR_NOTIFY);
	cVar.GetString(SZF(g_sCvarCmd));
	cVar.AddChangeHook(OnCvarChange_Exec);

	cVar = CreateConVar("l4d_tank_pass_replace", "1", "0=Kill the alive player before the Tank pass, 1=Replace the alive player with an infected bot before the Tank pass.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarReplace = cVar.BoolValue;
	cVar.AddChangeHook(OnCvarChange_Replace);

	cVar = CreateConVar("l4d_tank_pass_damage", "0", "0=Allow to pass the Tank when taking any damage, 1=Prevent to pass the Tank when taking any damage.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarDamage = cVar.BoolValue;
	cVar.AddChangeHook(OnCvarChange_Damage);

	cVar = CreateConVar("l4d_tank_pass_fire", "1", "0=Allow to pass the Tank when on fire, 1=Prevent to pass the Tank when on fire.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarFire = cVar.BoolValue;
	cVar.AddChangeHook(OnCvarChange_Fire);

	cVar = CreateConVar("l4d_tank_pass_extinguish", "0", "If \"l4d_tank_pass_fire\" convar set to 0: 0=Ignite the new Tank when passed, 1=Extinguish the new Tank when passed.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarExtinguish = cVar.BoolValue;
	cVar.AddChangeHook(OnCvarChange_Extinguish);

	cVar = CreateConVar("l4d_tank_pass_takeover", "1", "Sets the Tank passed count according convar value when taking control of the Tank AI. If >1 the tank will be replaced with a bot when the his frustration reaches 0.", FCVAR_NOTIFY, true, 1.0, true, 2.0);
	g_iPassedCount = cVar.IntValue;
	cVar.AddChangeHook(OnCvarChange_TakeOver);

	cVar = CreateConVar("l4d_tank_pass_notify", "1", "0=Off, 1=Display pass command info to the Tank through chat messages.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarNotify = cVar.BoolValue;
	cVar.AddChangeHook(OnCvarChange_Notify);

	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("finale_start", Event_FinalStart, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_pass", Command_TankPass, "Pass the Tank control to another player.");
	RegConsoleCmd("sm_tankpass", Command_TankPass, "Pass the Tank control to another player.");
	RegAdminCmd("sm_forcepass", Command_ForcePass, ADMFLAG_KICK, "sm_forcepass <#userid|name> - Force to pass the Tank to target player.");
	RegAdminCmd("sm_taketank", Command_TakeTank, ADMFLAG_KICK, "sm_taketank <#userid|name> - Take control of the Tank AI.");

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);

	AutoExecConfig(true, "l4d_tank_pass");
}
/*
|--------------------------------------------------------------------------
| ADM MENU
|--------------------------------------------------------------------------
*/
public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == g_hTopMenu)
		return;

	g_hTopMenu = topmenu;

	TopMenuObject player_commands = g_hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT){
		g_hTopMenu.AddItem("sm_forcepass", AdminMenu_ForcePass, player_commands, "sm_forcepass", ADMFLAG_KICK);
		g_hTopMenu.AddItem("sm_taketank", AdminMenu_TakeTank, player_commands, "sm_taketank", ADMFLAG_KICK);
	}
}

public void AdminMenu_ForcePass(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "%T", "phrase10", param);
		}
		case TopMenuAction_SelectOption:
		{
			if (GetTank())
				TankPassMenu(param, Menu_ForcePass);
			else {
				PrintToChat(param, "%t", "phrase7");
				if (g_hTopMenu != null)
					g_hTopMenu.Display(param, TopMenuPosition_LastCategory);
			}
		}
	}
}

public int MenuForceAdmHandler(Menu menu, MenuAction action, int admin, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sId[12];
			menu.GetItem(param2, SZF(sId));
			int target = CID(StringToInt(sId));
			int tank = GetTank();

			if (ValidateOffer(Validate_Default, tank, target, admin))
				TankPass(tank, target, admin);

			if (g_hTopMenu != null)
				g_hTopMenu.Display(admin, TopMenuPosition_LastCategory);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(admin, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void AdminMenu_TakeTank(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "%T", "phrase12", param);
		}
		case TopMenuAction_SelectOption:
		{
			if (GetTankBot())
				TankPassMenu(param, Menu_Take);
			else {
				PrintToChat(param, "%t", "phrase7");
				if (g_hTopMenu != null)
					g_hTopMenu.Display(param, TopMenuPosition_LastCategory);
			}
		}
	}
}

public int MenuTakeAdmHandler(Menu menu, MenuAction action, int admin, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sId[12];
			menu.GetItem(param2, SZF(sId));
			TakeTank(CID(StringToInt(sId)), admin);

			if (g_hTopMenu != null)
				g_hTopMenu.Display(admin, TopMenuPosition_LastCategory);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack && g_hTopMenu != null)
				g_hTopMenu.Display(admin, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}
/*
|--------------------------------------------------------------------------
| COMMANDS
|--------------------------------------------------------------------------
*/
public Action Command_TankPass(int client, int args)
{
	if (client && ValidateOffer(Validate_SkipTarget, client))
		TankPassMenu(client);
	return Plugin_Handled;
}

public Action Command_ForcePass(int client, int args)
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
			COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_BOTS,
			SZF(sName),
			bIsML)) <= 0){
			ReplyToTargetError(client, iCount);
			return Plugin_Handled;
		}

		int tank = GetTank();

		if (ValidateOffer(Validate_Default, tank, iTargetList[0], client))
			TankPass(tank, iTargetList[0], client);
	}
	else
		ReplyToCommand(client, "sm_forcepass <#userid|name>");

	return Plugin_Handled;
}

public Action Command_TakeTank(int client, int args)
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
			COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_BOTS,
			SZF(sName),
			bIsML)) <= 0){
			ReplyToTargetError(client, iCount);
			return Plugin_Handled;
		}

		TakeTank(client, iTargetList[0]);
	}
	else
		ReplyToCommand(client, "sm_taketank <#userid|name>");

	return Plugin_Handled;
}
/*
|--------------------------------------------------------------------------
| EVENTS
|--------------------------------------------------------------------------
*/
public Action Event_RoundStart(Event h_Event, char[] s_Name, bool b_DontBroadcast)
{
	g_bIsFinal = false;
}

public Action Event_FinalStart(Event h_Event, char[] s_Name, bool b_DontBroadcast)
{
	g_bIsFinal = true;
}

public Action Event_TankSpawn(Event h_Event, char[] s_Name, bool b_DontBroadcast)
{
	if (!g_bCvarNotify || g_bIsFinal) return;
	int userId = h_Event.GetInt("userid");
	int tank = CID(userId);

	if (!IsFakeClient(tank))
		CreateTimer(1.5, Timer_TankSpawn, userId);
}

public Action Timer_TankSpawn(Handle timer, any client)
{
	client = CID(client);
	if (!IsValidTank(client) || L4D2Direct_GetTankPassedCount() != 1) return;

	PrintToChat(client, "%t", "phrase1");
}
/*
|--------------------------------------------------------------------------
| MENU
|--------------------------------------------------------------------------
*/
void TankPassMenu(int client, int menuType = Menu_Pass)
{
	bool hasTarget;
	Menu menu;

	switch (menuType)
	{
		case Menu_Pass:
			menu = new Menu(MenuPassHandler);
		case Menu_ForcePass:
			menu = new Menu(MenuForceAdmHandler);
		case Menu_Take:
			menu = new Menu(MenuTakeAdmHandler);
	}

	menu.SetTitle("%T", "phrase4", client);
	char sName[MAX_NAME_LENGTH], sId[12];
	for (int i = 1; i <= MaxClients; i++){

		if (!IsInfected(i) || IsFakeClient(i) || IsPlayerTank(i)) continue;

		hasTarget = true;
		GetClientName(i, SZF(sName));
		IntToString(UID(i), SZF(sId));
		menu.AddItem(sId, sName);
	}
	if (!hasTarget){

		PrintToChat(client, "%t", "phrase7");
		delete menu;
		return;
	}
	if (menuType == Menu_Pass){
		ExecCmd(client);
		menu.ExitButton = true;
		menu.Display(client, 10);
	}
	else {
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuPassHandler(Menu menu, MenuAction action, int tank, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sId[12];
			menu.GetItem(param2, SZF(sId));
			int target = CID(StringToInt(sId));

			if (ValidateOffer(Validate_Default, tank, target))
				OfferMenu(tank, target);
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
	menu.AddItem("", sTemp);
	FormatEx(SZF(sTemp), "%T", "No", target);
	menu.AddItem("", sTemp);
	menu.ExitButton = true;
	menu.Display(target, 10);
}

public int OfferMenuHandler(Menu menu, MenuAction action, int target, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			int tank = CID(g_iTankId);

			if (param2 == 0){
				if (ValidateOffer(Validate_NotiyfyTarget, tank, target))
					TankPass(tank, target);
			}
			else if (IsValidTank(tank))
				PrintToChat(tank, "%t", "phrase6", target);
		}
		case MenuAction_Cancel:
		{
			int tank = CID(g_iTankId);
			if (IsValidTank(tank))
				PrintToChat(tank, "%t", "phrase6", target);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}
/*
|--------------------------------------------------------------------------
| FUNCTIONS
|--------------------------------------------------------------------------
*/
void TankPass(int tank, int target, int admin = 0)
{
	if (admin){
		PrintToTeam(3, 0, "%t", "phrase9", target);
		LogAction(admin, target, "\"%L\" has passed the Tank from \"%L\" to \"%L\"", admin, tank, target);
	}
	else
		PrintToTeam(3, 0, "%t", "phrase3", tank, target);

	if (IsInfectedAlive(target) && !IsPlayerGhost(target)){

		if (g_bCvarReplace)
			L4D_ReplaceWithBot(target);

		ForcePlayerSuicide(target);
	}

	// bugfix
	float vPos[3], vAng[3];
	GetClientAbsOrigin(tank, vPos);
	GetClientAbsAngles(tank, vAng);
	TeleportEntity(target, vPos, vAng, NULL_VECTOR);

	bool isOnFire = IsOnFire(tank);

	L4D_ReplaceTank(tank, target);
	L4D2Direct_SetTankPassedCount(2);

	if (isOnFire && !g_bCvarFire && !g_bCvarExtinguish)
		IgniteEntity(target, 99999.0);

	Call_StartForward(g_fwdOnTankPass);
	Call_PushCell(tank);
	Call_PushCell(target);
	Call_Finish();
}

void TakeTank(int admin, int target)
{
	int tank = GetTankBot();

	if (tank && IsValidTarget(target)){
		L4D_TakeOverZombieBot(target, tank);
		L4D2Direct_SetTankPassedCount(g_iPassedCount);
	}
	else
		PrintToChat(admin, "%t", "Player no longer available");
}

void ExecCmd(int client)
{
	if (g_sCvarCmd[0] && GetClientMenu(client) == MenuSource_Normal)
		FakeClientCommand(client, g_sCvarCmd);
}

int GetTank()
{
	for (int i = 1; i <= MaxClients; i++){
		if (IsValidTank(i))
			return i;
	}
	return 0;
}

int GetTankBot()
{
	for (int i = 1; i <= MaxClients; i++){
		if (IsValidTankBot(i))
			return i;
	}
	return 0;
}

bool ValidateOffer(int validate = Validate_Default, int tank, int target = 0, int admin = 0)
{
	bool hasTarget = validate == Validate_SkipTarget ? true : IsValidTarget(target);
	bool hasTank = IsValidTank(tank);
	int client = admin ? admin : tank;

	if (!hasTank || g_bIsFinal){
		if (IsClientAndInGame(client))
			PrintToChat(client, "%t", "phrase7");
		if (validate == Validate_NotiyfyTarget && hasTarget)
			PrintToChat(target, "%t", "phrase7");
		return false;
	}
	if (L4D2Direct_GetTankPassedCount() != 1){
		if (hasTank)
			PrintToChat(client, "%t", "phrase2");
		if (validate == Validate_NotiyfyTarget && hasTarget)
			PrintToChat(target, "%t", "phrase2");
		return false;
	}
	if (!hasTarget){
		PrintToChat(client, "%t", "Player no longer available");
		return false;
	}
	if (g_bCvarFire && IsOnFire(tank)){
		PrintToChat(client, "%t", "phrase8");
		if (validate == Validate_NotiyfyTarget)
			PrintToChat(target, "%t", "phrase8");
		return false;
	}
	if (g_bCvarDamage && GetClientHealth(tank) != g_iCvarTankHealth){
		PrintToChat(client, "%t", "phrase11");
		if (validate == Validate_NotiyfyTarget)
			PrintToChat(target, "%t", "phrase11");
		return false;
	}
	return true;
}

bool IsValidTarget(int target)
{
	return IsValid(target) && !IsPlayerTank(target);
}

bool IsValidTank(int tank)
{
	return IsValid(tank) && IsAliveTank(tank);
}

bool IsValidTankBot(int tank)
{
	return IsInfected(tank) && IsFakeClient(tank) && IsAliveTank(tank);
}

bool IsAliveTank(int tank)
{
	return IsPlayerTank(tank) && IsInfectedAlive(tank) && !IsIncapacitated(tank);
}

bool IsValid(int client)
{
	return IsClient(client) && IsInfected(client) && !IsFakeClient(client);
}
/*
|--------------------------------------------------------------------------
| CVARS
|--------------------------------------------------------------------------
*/
public void OnCvarChange_Exec(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(oldValue, newValue))
		convar.GetString(SZF(g_sCvarCmd));
}

public void OnCvarChange_Replace(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarReplace = convar.BoolValue;
}

public void OnCvarChange_Damage(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarDamage = convar.BoolValue;
}

public void OnCvarChange_Fire(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarFire = convar.BoolValue;
}

public void OnCvarChange_Extinguish(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarExtinguish = convar.BoolValue;
}

public void OnCvarChange_TakeOver(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(oldValue, newValue))
		g_iPassedCount = convar.IntValue;
}

public void OnCvarChange_TankHealth(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(oldValue, newValue))
		g_iCvarTankHealth = CalcTankHealth();
}

int CalcTankHealth()
{
	return RoundToNearest(g_hCvarTankHealth.FloatValue * (g_hCvarTankBonusHealth ? g_hCvarTankBonusHealth.FloatValue : 1.5));
}

public void OnCvarChange_Notify(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarNotify = convar.BoolValue;
}