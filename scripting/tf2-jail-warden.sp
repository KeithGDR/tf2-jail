/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Jail] Warden"
#define PLUGIN_DESCRIPTION "The Warden module for the Jail systems."
#define PLUGIN_VERSION "1.0.0"

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-tf>
#include <misc-colors>

/*****************************/
//ConVars

/*****************************/
//Globals
int g_Warden;
int g_MarkerCooldown = -1;

int iHalo;
int iLaserBeam;

/*****************************/
//Plugin Info
public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = "Drixevel", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	RegConsoleCmd("sm_w", Command_Warden);
	RegConsoleCmd("sm_warden", Command_Warden);
}

public void OnMapStart()
{
	PrecacheSound("weapons/buff_banner_horn_red.wav");
	PrecacheSound("weapons/buff_banner_horn_blue.wav");
	PrecacheSound("misc/rd_finale_beep01.wav");
	PrecacheSound("ui/hitsound.wav");
	PrecacheSound("ui/trade_ready.wav");

	iLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	iHalo = PrecacheModel("materials/sprites/glow01.vmt", true);
}

public Action Command_Warden(int client, int args)
{
	if (TF2_GetClientTeam(client) != TFTeam_Blue)
	{
		CPrintToChat(client, "You must be on the Guards(BLUE) team to use this command.");
		return Plugin_Handled;
	}
	
	if (IsWarden(client))
	{
		OpenWardenMenu(client);
		return Plugin_Handled;
	}
	
	if (IsWardenActive())
	{
		CPrintToChat(client, "%N is already Warden.", g_Warden);
		return Plugin_Handled;
	}
	
	SetWarden(client);
	return Plugin_Handled;
}

void SetWarden(int client)
{
	g_Warden = client;
	CPrintToChat(client, "%N is now the new Warden.", client);
	
	EmitSoundToAll(GetRandomInt(0, 1) == 0 ? "weapons/buff_banner_horn_red.wav" : "weapons/buff_banner_horn_blue.wav");
	
	ChangeClientTeam_Alive(client, 3);
	TF2_ResizePlayer(client, 1.2);

	g_MarkerCooldown = -1;
}

bool IsWarden(int client)
{
	return client == g_Warden;
}

bool IsWardenActive()
{
	return g_Warden > 0;
}

public void TF2_OnRoundStart(bool full_reset)
{
	g_Warden = 0;
	g_MarkerCooldown = -1;
}

public void OnClientDisconnect(int client)
{
	if (g_Warden == client)
	{
		g_Warden = 0;
		g_MarkerCooldown = -1;
		CPrintToChatAll("%N has disconnected as Warden, slot is now open.", client);
	}
}

void OpenWardenMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Warden);
	menu.SetTitle("Warden Menu");

	menu.AddItem("search", "Search Player");
	menu.AddItem("marker", "Place Marker");
	menu.AddItem("pointer", "Toggle Pointer");
	menu.AddItem("warrant", "Create Warrant");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Warden(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "search"))
				SearchTarget(param1);
			else if (StrEqual(sInfo, "marker"))
				ListMarkers(param1);
			else if (StrEqual(sInfo, "pointer"))
				CreatePointer(param1);
			else if (StrEqual(sInfo, "warrant"))
				SearchTarget(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

void SearchTarget(int client)
{
	int target = GetClientAimTarget(client, true);

	if (target == -1)
	{
		OpenWardenMenu(client);
		CPrintToChat(client, "No target found, please aim your crosshair at them.");
		return;
	}

	if (GetEntitiesDistance(client, target) > 100.0)
	{
		OpenWardenMenu(client);
		CPrintToChat(client, "Please step closer to the target to search them.");
		return;
	}

	if (GetPlayerSpeed(client) != 0.0 || GetPlayerSpeed(target) != 0.0)
	{
		OpenWardenMenu(client);
		CPrintToChat(client, "Both you and the target must stop moving.");
		return;
	}

	CPrintToChat(target, "%N is searching your pockets...");

	Menu menu = new Menu(MenuHandler_Search);
	menu.SetTitle("%N's results:\n \n", target);

	int primary = GetPlayerWeaponSlot(target, 0);
	int secondary = GetPlayerWeaponSlot(target, 1);
	int melee = GetPlayerWeaponSlot(target, 2);

	char buffer[64];
	
	FormatEx(buffer, sizeof(buffer), "Health: %i/%i", GetClientHealth(target), GetEntityMaxHealth(target));
	menu.AddItem("", buffer);

	char sPrimary[64];
	TF2_GetWeaponNameFromIndex(GetWeaponIndex(primary), sPrimary, sizeof(sPrimary));
	FormatEx(buffer, sizeof(buffer), "Primary Weapon: %s", sPrimary);
	menu.AddItem("", buffer);

	int primary_clip = GetClip(primary);
	int primary_ammo = GetAmmo(target, primary);
	FormatEx(buffer, sizeof(buffer), "Primary Clip: %i | Ammo: %i", primary_clip, primary_ammo);
	menu.AddItem("", buffer);

	char sSecondary[64];
	TF2_GetWeaponNameFromIndex(GetWeaponIndex(secondary), sSecondary, sizeof(sSecondary));
	FormatEx(buffer, sizeof(buffer), "Secondary Weapon: %s", sSecondary);
	menu.AddItem("", buffer);

	int secondary_clip = GetClip(secondary);
	int secondary_ammo = GetAmmo(target, secondary);
	FormatEx(buffer, sizeof(buffer), "Secondary Clip: %i | Ammo: %i", secondary_clip, secondary_ammo);
	menu.AddItem("", buffer);

	char sMelee[64];
	TF2_GetWeaponNameFromIndex(GetWeaponIndex(melee), sMelee, sizeof(sMelee));
	FormatEx(buffer, sizeof(buffer), "Melee Weapon: %s", sMelee);
	menu.AddItem("", buffer);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Search(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenWardenMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void ListMarkers(int client)
{
	Menu menu = new Menu(MenuHandler_ListMarkers);
	menu.SetTitle("Pick a Marker:");

	menu.AddItem("", "○ Move Here");
	menu.AddItem("", "○ Stay Put");
	menu.AddItem("", "○ Countdown");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ListMarkers(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32]; char sDisplay[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

			int time = GetTime();
			if (g_MarkerCooldown != -1 && g_MarkerCooldown > time)
			{
				CPrintToChat(param1, "Please wait %i seconds before creating another marker.", (g_MarkerCooldown - time));
				ListMarkers(param1);
				return;
			}

			g_MarkerCooldown = time + 5;

			if (StrEqual(sDisplay, "○ Countdown", false))
				StartCountdown(param1);
			else
				PlaceMarker(param1, sDisplay);
			
			ListMarkers(param1);
		}
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenWardenMenu(param1);
		case MenuAction_End:
			delete menu;
	}
}

void StartCountdown(int client)
{
	float vecPos[3];
	GetClientLookOrigin(client, vecPos);
	vecPos[2] += 20.0;

	CreateMarker(vecPos, "Ready?", "ui/trade_ready.wav");

	DataPack pack;
	CreateDataTimer(1.0, Timer_Countdown, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(3);
	pack.WriteFloat(vecPos[0]);
	pack.WriteFloat(vecPos[1]);
	pack.WriteFloat(vecPos[2]);
}

public Action Timer_Countdown(Handle timer, DataPack pack)
{
	pack.Reset();

	int countdown = pack.ReadCell();

	float vecPos[3];
	vecPos[0] = pack.ReadFloat();
	vecPos[1] = pack.ReadFloat();
	vecPos[2] = pack.ReadFloat();

	if (countdown > 0)
	{
		char buffer[64];
		FormatEx(buffer, sizeof(buffer), "Countdown in %i", countdown);
		CreateMarker(vecPos, buffer);
		countdown--;

		pack.Reset();
		pack.WriteCell(countdown);
		pack.WriteFloat(vecPos[0]);
		pack.WriteFloat(vecPos[1]);
		pack.WriteFloat(vecPos[2]);

		return Plugin_Continue;
	}

	CreateMarker(vecPos, "GO!", "ui/hitsound.wav");

	return Plugin_Stop;
}

void PlaceMarker(int client, const char[] text)
{
	float vecPos[3];
	GetClientLookOrigin(client, vecPos);
	vecPos[2] += 20.0;

	CreateMarker(vecPos, text);
}

void CreateMarker(float origin[3], const char[] text, const char[] sound = "misc/rd_finale_beep01.wav")
{
	TF2_CreateAnnotationToAll(origin, text, 10.0, sound);

	TE_SetupBeamRingPoint(origin, 300.0, 300.1, iLaserBeam, iHalo, 0, 10, 0.1, 2.0, 0.0, {255, 255, 255, 255}, 10, 0);
	TE_SendToAll();
}

void CreatePointer(int client)
{
	int time = GetTime();
	if (g_MarkerCooldown != -1 && g_MarkerCooldown > time)
	{
		CPrintToChat(client, "Please wait %i seconds before creating a pointer.", (g_MarkerCooldown - time));
		OpenWardenMenu(client);
		return;
	}

	g_MarkerCooldown = time + 5;

	float vecOrigin[3];
	GetClientEyePosition(client, vecOrigin);

	float vecPos[3];
	GetClientLookOrigin(client, vecPos);

	TE_SetupBeamPoints(vecOrigin, vecPos, iLaserBeam, iHalo, 5, 10, 10.0, 8.0, 8.0, 0, 0.0, {255, 255, 255, 255}, 10);
	TE_SendToAll();

	CPrintToChat(client, "Pointer has been created.");

	OpenWardenMenu(client);
}