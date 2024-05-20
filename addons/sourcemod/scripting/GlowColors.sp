#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <regex>
#include <multicolors>

#undef REQUIRE_PLUGIN
#tryinclude <zombiereloaded>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#define CHAT_PREFIX "{green}[SM]{default}"

public Plugin myinfo =
{
	name = "GlowColors & Master Chief colors",
	author = "BotoX, inGame, .Rushaway",
	description = "Change your clients colors.",
	version = "1.3.2",
	url = ""
}

Menu g_GlowColorsMenu;
Handle g_hClientCookie = INVALID_HANDLE;
Handle g_hClientCookieRainbow = INVALID_HANDLE;
Handle g_hClientFrequency = INVALID_HANDLE;
Handle g_Cvar_PluginTimer = INVALID_HANDLE;

ConVar g_Cvar_MinBrightness;
ConVar g_Cvar_MinRainbowFrequency;
ConVar g_Cvar_MaxRainbowFrequency;
Regex g_Regex_RGB;
Regex g_Regex_HEX;

int g_aGlowColor[MAXPLAYERS + 1][3];
float g_aRainbowFrequency[MAXPLAYERS + 1];
bool g_bRainbowEnabled[MAXPLAYERS+1] = {false,...};
bool g_Plugin_ZR = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("GlowColors_SetRainbow", Native_SetRainbow);
	CreateNative("GlowColors_RemoveRainbow", Native_RemoveRainbow);

	RegPluginLibrary("glowcolors");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hClientCookie = RegClientCookie("glowcolor", "Player glowcolor", CookieAccess_Protected);
	g_hClientCookieRainbow = RegClientCookie("rainbow", "Rainbow status", CookieAccess_Protected);
	g_hClientFrequency = RegClientCookie("rainbow_frequency", "Rainbow frequency", CookieAccess_Protected);

	g_Regex_RGB = CompileRegex("^(([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\\s+){2}([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$");
	g_Regex_HEX = CompileRegex("^(#?)([A-Fa-f0-9]{6})$");

	RegAdminCmd("sm_glowcolors", Command_GlowColors, ADMFLAG_CUSTOM2, "Change your players glowcolor. sm_glowcolors <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegAdminCmd("sm_glowcolours", Command_GlowColors, ADMFLAG_CUSTOM2, "Change your players glowcolor. sm_glowcolours <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegAdminCmd("sm_glowcolor", Command_GlowColors, ADMFLAG_CUSTOM2, "Change your players glowcolor. sm_glowcolor <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegAdminCmd("sm_glowcolour", Command_GlowColors, ADMFLAG_CUSTOM2, "Change your players glowcolor. sm_glowcolour <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegAdminCmd("sm_colors", Command_GlowColors, ADMFLAG_CUSTOM2, "Change your players glowcolor. sm_colors <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegAdminCmd("sm_colours", Command_GlowColors, ADMFLAG_CUSTOM2, "Change your players glowcolor. sm_colours <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegAdminCmd("sm_color", Command_GlowColors, ADMFLAG_CUSTOM2, "Change your players glowcolor. sm_color <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegAdminCmd("sm_colour", Command_GlowColors, ADMFLAG_CUSTOM2, "Change your players glowcolor. sm_colour <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegAdminCmd("sm_glow", Command_GlowColors, ADMFLAG_CUSTOM2, "Change your players glowcolor. sm_glow <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegConsoleCmd("sm_mccmenu", Command_GlowColors, "Change your MasterChief color.");

	RegAdminCmd("sm_rainbow", Command_Rainbow, ADMFLAG_CUSTOM1, "Enable rainbow glowcolors. sm_rainbow [frequency]");

	HookEvent("player_disconnect", Event_ClientDisconnect, EventHookMode_Pre);
	HookEvent("player_spawn", Event_ApplyGlowcolor, EventHookMode_Post);
	HookEvent("player_team", Event_ApplyGlowcolor, EventHookMode_Post);

	g_Cvar_MinBrightness = CreateConVar("sm_glowcolor_minbrightness", "100", "Lowest brightness value for glowcolor.", 0, true, 0.0, true, 255.0);
	g_Cvar_PluginTimer = CreateConVar("sm_glowcolors_timer", "5.0", "When the colors should spawning again (in seconds)");
	g_Cvar_MinRainbowFrequency = CreateConVar("sm_glowcolors_minrainbowfrequency", "1.0", "Lowest frequency value for rainbow glowcolors before auto-clamp.", 0, true, 0.1);
	g_Cvar_MaxRainbowFrequency = CreateConVar("sm_glowcolors_maxrainbowfrequency", "10.0", "Highest frequency value for rainbow glowcolors before auto-clamp.", 0, true, 0.1);

	LoadConfig();
	LoadTranslations("GlowColors.phrases");

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && AreClientCookiesCached(client))
		{
			ApplyGlowColor(client);
		}
	}

	AutoExecConfig(true);
}

public void OnAllPluginsLoaded()
{
	g_Plugin_ZR = LibraryExists("zombiereloaded");
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_ZR = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_ZR = false;
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && AreClientCookiesCached(client))
		{
			OnClientDisconnect(client);
		}
	}

	delete g_GlowColorsMenu;
	CloseHandle(g_hClientCookie);
	CloseHandle(g_hClientCookieRainbow);
	CloseHandle(g_hClientFrequency);
}

void LoadConfig()
{
	char sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/GlowColors.cfg");
	if(!FileExists(sConfigFile))
	{
		SetFailState("Could not find config: \"%s\"", sConfigFile);
	}

	KeyValues Config = new KeyValues("GlowColors");
	if(!Config.ImportFromFile(sConfigFile))
	{
		delete Config;
		SetFailState("ImportFromFile() failed!");
	}
	if(!Config.GotoFirstSubKey(false))
	{
		delete Config;
		SetFailState("GotoFirstSubKey() failed!");
	}

	g_GlowColorsMenu = new Menu(MenuHandler_GlowColorsMenu, MenuAction_Select);
	g_GlowColorsMenu.SetTitle("GlowColors");
	g_GlowColorsMenu.ExitButton = true;

	g_GlowColorsMenu.AddItem("255 255 255", "None");

	char sKey[32];
	char sValue[16];
	do
	{
		Config.GetSectionName(sKey, sizeof(sKey));
		Config.GetString(NULL_STRING, sValue, sizeof(sValue));

		g_GlowColorsMenu.AddItem(sValue, sKey);
	}
	while(Config.GotoNextKey(false));
}

public void OnClientConnected(int client)
{
	g_aGlowColor[client][0] = 255;
	g_aGlowColor[client][1] = 255;
	g_aGlowColor[client][2] = 255;
	g_aRainbowFrequency[client] = 0.0;
	g_bRainbowEnabled[client] = false;
}

public void OnClientCookiesCached(int client)
{
	if(IsClientAuthorized(client))
		ReadClientCookies(client);
}

public void OnClientPostAdminCheck(int client)
{
	if(AreClientCookiesCached(client))
		ReadClientCookies(client);
}

void ReadClientCookies(int client)
{
	if(!client || !IsClientInGame(client))
		return;
	
	char sCookie[16];
	GetClientCookie(client, g_hClientCookie, sCookie, sizeof(sCookie));
	ColorStringToArray(sCookie, g_aGlowColor[client]);

	GetClientCookie(client, g_hClientCookieRainbow, sCookie, sizeof(sCookie));
	g_bRainbowEnabled[client] = StringToInt(sCookie) == 1;

	GetClientCookie(client, g_hClientFrequency, sCookie, sizeof(sCookie));
	g_aRainbowFrequency[client] = StringToFloat(sCookie);
}

public void OnClientDisconnect(int client)
{
	if(!client || !IsClientInGame(client))
		return;

	char sCookie[16];

	/* GLOW COLOR */
	FormatEx(sCookie, sizeof(sCookie), "%d %d %d", g_aGlowColor[client][0], g_aGlowColor[client][1], g_aGlowColor[client][2]);
	SetClientCookie(client, g_hClientCookie, sCookie);

	// Restore player default glowcolor
	g_aGlowColor[client][0] = 255;
	g_aGlowColor[client][1] = 255;
	g_aGlowColor[client][2] = 255;
	ApplyGlowColor(client);

	/* RAINBOW */
	FormatEx(sCookie, sizeof(sCookie), "%d", g_bRainbowEnabled[client]);
	SetClientCookie(client, g_hClientCookieRainbow, sCookie);

	FormatEx(sCookie, sizeof(sCookie), "%0.1f", g_aRainbowFrequency[client]);
	SetClientCookie(client, g_hClientFrequency, sCookie);

	StopRainbow(client);
}

public void OnPostThinkPost(int client)
{
	float i = GetGameTime();
	float Frequency = g_aRainbowFrequency[client];

	int Red   = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	int Green = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	int Blue  = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);

	ToolsSetEntityColor(client, Red, Green, Blue);
}

public Action Command_GlowColors(int client, int args)
{
	if(args < 1)
	{
		DisplayGlowColorMenu(client);
		return Plugin_Handled;
	}

	int Color;

	if(args == 1)
	{
		char sColorString[32];
		GetCmdArgString(sColorString, sizeof(sColorString));

		if(!IsValidHex(sColorString))
		{
			CPrintToChat(client, "%s Invalid HEX color code supplied.", CHAT_PREFIX);
			return Plugin_Handled;
		}

		Color = StringToInt(sColorString, 16);

		g_aGlowColor[client][0] = (Color >> 16) & 0xFF;
		g_aGlowColor[client][1] = (Color >> 8) & 0xFF;
		g_aGlowColor[client][2] = (Color >> 0) & 0xFF;
	}
	else if(args == 3)
	{
		char sColorString[32];
		GetCmdArgString(sColorString, sizeof(sColorString));

		if(!IsValidRGBNum(sColorString))
		{
			CPrintToChat(client, "%s Invalid RGB color code supplied.", CHAT_PREFIX);
			return Plugin_Handled;
		}

		ColorStringToArray(sColorString, g_aGlowColor[client]);

		Color = (g_aGlowColor[client][0] << 16) +
				(g_aGlowColor[client][1] << 8) +
				(g_aGlowColor[client][2] << 0);
	}
	else
	{
		char sCommand[32];
		GetCmdArg(0, sCommand, sizeof(sCommand));
		CPrintToChat(client, "%s Usage: %s <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>", CHAT_PREFIX, sCommand);
		return Plugin_Handled;
	}

	if(!ApplyGlowColor(client))
		return Plugin_Handled;

	if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		StopRainbow(client);
		CPrintToChat(client, "%s \x07%06X Set color to: %06X", CHAT_PREFIX, Color, Color);	
	}
	return Plugin_Handled;
}

public Action Command_Rainbow(int client, int args)
{
	float Frequency = 1.0;
	if(args >= 1)
	{
		char sArg[32];
		GetCmdArg(1, sArg, sizeof(sArg));
		Frequency = StringToFloat(sArg);
	}

	if(!Frequency || (args < 1 && g_aRainbowFrequency[client]))
	{
		StopRainbow(client);
		CPrintToChat(client, "%s{olive} Disabled {default}rainbow glowcolors.", CHAT_PREFIX);
		ApplyGlowColor(client);
	}
	else
	{
		StartRainbow(client, Frequency);
		CPrintToChat(client, "%s{olive} Enabled {default}rainbow glowcolors. (Frequency = {olive}%0.1f{default})", CHAT_PREFIX, Frequency);
	}
	return Plugin_Handled;
}

void DisplayGlowColorMenu(int client)
{
	bool bAccess = CheckCommandAccess(client, "", ADMFLAG_CUSTOM2);
	if(bAccess)
	{
		g_GlowColorsMenu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		if(IsClientInGame(client) && !IsPlayerAlive(client))
		{		
			CPrintToChat(client, "%T", "NotAlive", client);
		}
#if defined _zr_included
		else if(g_Plugin_ZR && IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientZombie(client))
		{	
			CPrintToChat(client, "%T", "Zombie", client);
		}
		else if(g_Plugin_ZR && ZR_GetActiveClass(client) != ZR_GetClassByName("Master Chief") && !ZR_IsClientZombie(client))
		{	
			CPrintToChat(client, "%T", "WrongModel", client);
		}
#endif
		else
			g_GlowColorsMenu.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_GlowColorsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char aItem[16];
			menu.GetItem(param2, aItem, sizeof(aItem));

			ColorStringToArray(aItem, g_aGlowColor[param1]);
			int Color = (g_aGlowColor[param1][0] << 16) +
				(g_aGlowColor[param1][1] << 8) +
				(g_aGlowColor[param1][2] << 0);

			StopRainbow(param1);

			ApplyGlowColor(param1);
			CPrintToChat(param1, "%s \x07%06X Set color to: %06X", CHAT_PREFIX, Color, Color);
		}
	}
	return 0;
}

// We do that with Hook to prevent get this functions run during map change
public void Event_ClientDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client)
		return;

	g_bRainbowEnabled[client] = false;

	OnClientDisconnect(client);
}

public void Event_ApplyGlowcolor(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client)
		return;

	CreateTimer(GetConVarFloat(g_Cvar_PluginTimer), Timer_ApplyGlowColor, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ApplyGlowColor(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if(client)
	{
		if (g_bRainbowEnabled[client])
			StartRainbow(client, g_aRainbowFrequency[client]);
		else
			ApplyGlowColor(client);
	}
	return Plugin_Continue;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	ApplyGlowColor(client);
}

public void ZR_OnClientHumanPost(int client, bool respawn, bool protect)
{
	ApplyGlowColor(client);
}

bool ApplyGlowColor(int client)
{
	if(!IsClientInGame(client))
		return false;

	bool Ret = true;
	int Brightness = ColorBrightness(g_aGlowColor[client][0], g_aGlowColor[client][1], g_aGlowColor[client][2]);
	if(Brightness < g_Cvar_MinBrightness.IntValue)
	{
		CPrintToChat(client, "%s Your glowcolor is too dark! (brightness = {red}%d{default}/255, allowed values are {green}> %d{default})", CHAT_PREFIX,
			Brightness, g_Cvar_MinBrightness.IntValue -1 );

		g_aGlowColor[client][0] = 255;
		g_aGlowColor[client][1] = 255;
		g_aGlowColor[client][2] = 255;
		Ret = false;
	}


	if(IsPlayerAlive(client) && CheckCommandAccess(client, "", ADMFLAG_CUSTOM2) || CheckCommandAccess(client, "", ADMFLAG_ROOT))
		ToolsSetEntityColor(client, g_aGlowColor[client][0], g_aGlowColor[client][1], g_aGlowColor[client][2]);

#if defined _zr_included
	if(g_Plugin_ZR && IsPlayerAlive(client) && ZR_GetActiveClass(client) == ZR_GetClassByName("Master Chief"))
#else
	if(IsPlayerAlive(client))
#endif
		ToolsSetEntityColor(client, g_aGlowColor[client][0], g_aGlowColor[client][1], g_aGlowColor[client][2]);

#if defined _zr_included
	if(g_Plugin_ZR && IsPlayerAlive(client) && !CheckCommandAccess(client, "", ADMFLAG_CUSTOM2) && ZR_IsClientZombie(client))
#else
	if(IsPlayerAlive(client) && !CheckCommandAccess(client, "", ADMFLAG_CUSTOM2))
#endif
		ToolsSetEntityColor(client, 255, 255, 255);

	return Ret;
}

stock void StopRainbow(int client)
{
	if(g_aRainbowFrequency[client])
	{
		g_bRainbowEnabled[client] = false;
		SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
		g_aRainbowFrequency[client] = 0.0;
	}
}

stock void StartRainbow(int client, float Frequency)
{
	float MinFrequency = g_Cvar_MinRainbowFrequency.FloatValue;
	float MaxFrequency = g_Cvar_MaxRainbowFrequency.FloatValue;

	if (Frequency < MinFrequency)
		Frequency = MinFrequency;
	else if (Frequency > MaxFrequency)
		Frequency = MaxFrequency;

	g_aRainbowFrequency[client] = Frequency;
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);

	g_bRainbowEnabled[client] = true;
}
stock void ToolsGetEntityColor(int entity, int aColor[4])
{
	static bool s_GotConfig = false;
	static char s_sProp[32];

	if(!s_GotConfig)
	{
		Handle GameConf = LoadGameConfigFile("core.games");
		bool Exists = GameConfGetKeyValue(GameConf, "m_clrRender", s_sProp, sizeof(s_sProp));
		CloseHandle(GameConf);

		if(!Exists)
			strcopy(s_sProp, sizeof(s_sProp), "m_clrRender");

		s_GotConfig = true;
	}

	int Offset = GetEntSendPropOffs(entity, s_sProp);

	for(int i = 0; i < 4; i++)
		aColor[i] = GetEntData(entity, Offset + i, 1);
}

stock void ToolsSetEntityColor(int client, int Red, int Green, int Blue)
{
	int aColor[4];
	ToolsGetEntityColor(client, aColor);

	SetEntityRenderColor(client, Red, Green, Blue, aColor[3]);
}

stock void ColorStringToArray(const char[] sColorString, int aColor[3])
{
	char asColors[4][4];
	ExplodeString(sColorString, " ", asColors, sizeof(asColors), sizeof(asColors[]));

	aColor[0] = StringToInt(asColors[0]) & 0xFF;
	aColor[1] = StringToInt(asColors[1]) & 0xFF;
	aColor[2] = StringToInt(asColors[2]) & 0xFF;
}

stock bool IsValidRGBNum(char[] sString)
{
	if(g_Regex_RGB.Match(sString) > 0)
		return true;
	return false;
}

stock bool IsValidHex(char[] sString)
{
	if(g_Regex_HEX.Match(sString) > 0)
		return true;
	return false;
}

stock int ColorBrightness(int Red, int Green, int Blue)
{
	// http://www.nbdtech.com/Blog/archive/2008/04/27/Calculating-the-Perceived-Brightness-of-a-Color.aspx
	return RoundToFloor(SquareRoot(
		Red * Red * 0.241 +
		Green * Green + 0.691 +
		Blue * Blue + 0.068));
}

public int Native_SetRainbow(Handle hPlugins, int numParams) {
	int client = GetNativeCell(1);

	g_aRainbowFrequency[client] = 1.0;
	return 0;
}

public int Native_RemoveRainbow(Handle hPlugins, int numParams) {
	int client = GetNativeCell(1);

	g_aRainbowFrequency[client] = 0.0;
	return 0;
}
