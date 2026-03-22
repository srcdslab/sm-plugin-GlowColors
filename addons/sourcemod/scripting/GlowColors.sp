#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <regex>
#include <multicolors>
#include <glowcolors>

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
	version = GlowColors_VERSION,
	url = "https://github.com/srcdslab/sm-plugin-GlowColors"
}

Menu g_GlowColorsMenu;
Cookie g_hClientCookie;
ConVar g_Cvar_PluginTimer;

ConVar g_Cvar_MinBrightness;
ConVar g_Cvar_MinRainbowFrequency;
ConVar g_Cvar_MaxRainbowFrequency;
Regex g_Regex_RGB;
Regex g_Regex_HEX;

int g_aGlowColor[MAXPLAYERS + 1][3];
float g_aRainbowFrequency[MAXPLAYERS + 1];
bool g_bLate = false;
bool g_bRainbowEnabled[MAXPLAYERS+1] = {false,...};
bool g_Plugin_ZR = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	CreateNative("GlowColors_SetRainbow", Native_SetRainbow);
	CreateNative("GlowColors_RemoveRainbow", Native_RemoveRainbow);

	RegPluginLibrary("glowcolors");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hClientCookie = new Cookie("glowcolor_data", "Player glowcolor data (RGB|Rainbow|Frequency)", CookieAccess_Protected);

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
	RegAdminCmd("sm_glowcolors_reload", Command_ReloadConfig, ADMFLAG_ROOT, "Reload the GlowColors configuration file.");

	HookEvent("player_spawn", Event_ApplyGlowcolor);
	HookEvent("player_team", Event_ApplyGlowcolor);

	g_Cvar_MinBrightness = CreateConVar("sm_glowcolor_minbrightness", "100", "Lowest brightness value for glowcolor.", 0, true, 0.0, true, 255.0);
	g_Cvar_PluginTimer = CreateConVar("sm_glowcolors_timer", "5.0", "When the colors should spawning again (in seconds)");
	g_Cvar_MinRainbowFrequency = CreateConVar("sm_glowcolors_minrainbowfrequency", "1.0", "Lowest frequency value for rainbow glowcolors before auto-clamp.", 0, true, 0.1);
	g_Cvar_MaxRainbowFrequency = CreateConVar("sm_glowcolors_maxrainbowfrequency", "10.0", "Highest frequency value for rainbow glowcolors before auto-clamp.", 0, true, 0.1);

	AutoExecConfig(true);

	LoadConfig();
	LoadTranslations("GlowColors.phrases");

	if (!g_bLate)
		return;

	for(int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && AreClientCookiesCached(client))
		{
			OnClientConnected(client);
			OnClientCookiesCached(client);
			ApplyGlowColor(client);
		}
	}

	g_bLate = false;
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

void LoadConfig()
{
	char sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/GlowColors.cfg");
	if (!FileExists(sConfigFile))
	{
		SetFailState("Could not find config: \"%s\"", sConfigFile);
	}

	KeyValues Config = new KeyValues("GlowColors");
	if (!Config.ImportFromFile(sConfigFile))
	{
		delete Config;
		SetFailState("ImportFromFile() failed!");
	}
	if (!Config.GotoFirstSubKey(false))
	{
		delete Config;
		SetFailState("GotoFirstSubKey() failed!");
	}

	delete g_GlowColorsMenu;

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
	while (Config.GotoNextKey(false));
	
	delete Config;
}

public Action Command_ReloadConfig(int client, int args)
{
	CReplyToCommand(client, "%s Attempting to reload configuration...", CHAT_PREFIX);
	LoadConfig();

	CReplyToCommand(client, "%s Configuration file reloaded successfully.", CHAT_PREFIX);
	return Plugin_Handled;
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
	ParseClientCookie(client, g_aGlowColor[client][0], g_aGlowColor[client][1], g_aGlowColor[client][2], g_bRainbowEnabled[client], g_aRainbowFrequency[client]);

	if (g_bRainbowEnabled[client] && !HasRainbowAccess(client))
	{
		g_bRainbowEnabled[client] = false;
		g_aRainbowFrequency[client] = 0.0;
		SaveClientCookies(client);
	}
}

void ParseClientCookie(int client, int &red, int &green, int &blue, bool &rainbowEnabled, float &rainbowFrequency)
{
	char sCookie[64];
	g_hClientCookie.Get(client, sCookie, sizeof(sCookie));

	// Parse the cookie data: "%d|%d|%d|%d|%0.1f" (R|G|B|Rainbow|Frequency)
	if (sCookie[0] != '\0')
	{
		char sParts[5][16];
		int parts = ExplodeString(sCookie, "|", sParts, sizeof(sParts), sizeof(sParts[]));

		if (parts >= 5)
		{
			red = StringToInt(sParts[0]);
			green = StringToInt(sParts[1]);
			blue = StringToInt(sParts[2]);
			rainbowEnabled = StringToInt(sParts[3]) == 1;
			rainbowFrequency = StringToFloat(sParts[4]);
			return;
		}
	}

	// Default values (used for empty cookie or invalid format)
	red = 255;
	green = 255;
	blue = 255;
	rainbowEnabled = false;
	rainbowFrequency = 0.0;
}

void SaveClientCookies(int client)
{
	// Read current cookie values
	int currentRed, currentGreen, currentBlue;
	bool currentRainbowEnabled;
	float currentRainbowFrequency;
	ParseClientCookie(client, currentRed, currentGreen, currentBlue, currentRainbowEnabled, currentRainbowFrequency);

	// Check if values have changed
	bool colorChanged = (g_aGlowColor[client][0] != currentRed || g_aGlowColor[client][1] != currentGreen || g_aGlowColor[client][2] != currentBlue);
	bool rainbowChanged = g_bRainbowEnabled[client] != currentRainbowEnabled;
	bool frequencyChanged = g_aRainbowFrequency[client] != currentRainbowFrequency;

	// If no values have changed, no need to save
	if (!colorChanged && !rainbowChanged && !frequencyChanged) {
		return;
	}

	// Otherwise, save the chain format
	char sCookie[64];
	FormatEx(sCookie, sizeof(sCookie), "%d|%d|%d|%d|%0.1f", 
		g_aGlowColor[client][0], 
		g_aGlowColor[client][1], 
		g_aGlowColor[client][2], 
		g_bRainbowEnabled[client] ? 1 : 0, 
		g_aRainbowFrequency[client]);
	g_hClientCookie.Set(client, sCookie);
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
	if (!client)
		return Plugin_Handled;
		
	if (args < 1)
	{
		DisplayGlowColorMenu(client);
		return Plugin_Handled;
	}

	int Color;

	if (args == 1)
	{
		char sColorString[32];
		GetCmdArgString(sColorString, sizeof(sColorString));

		if (!IsValidHex(sColorString))
		{
			CPrintToChat(client, "%s Invalid HEX color code supplied.", CHAT_PREFIX);
			return Plugin_Handled;
		}

		Color = StringToInt(sColorString, 16);

		g_aGlowColor[client][0] = (Color >> 16) & 0xFF;
		g_aGlowColor[client][1] = (Color >> 8) & 0xFF;
		g_aGlowColor[client][2] = (Color >> 0) & 0xFF;
	}
	else if (args == 3)
	{
		char sColorString[32];
		GetCmdArgString(sColorString, sizeof(sColorString));

		if (!IsValidRGBNum(sColorString))
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

	if (!ApplyGlowColor(client))
		return Plugin_Handled;

	SaveClientCookies(client);

	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		StopRainbow(client);
		CPrintToChat(client, "%s \x07%06X Set color to: %06X", CHAT_PREFIX, Color, Color);	
	}
	return Plugin_Handled;
}

public Action Command_Rainbow(int client, int args)
{
	if (!client)
		return Plugin_Handled;
		
	float Frequency = 1.0;
	if (args >= 1)
	{
		char sArg[32];
		GetCmdArg(1, sArg, sizeof(sArg));
		Frequency = StringToFloat(sArg);
	}

	if (!Frequency || (args < 1 && g_aRainbowFrequency[client]))
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
	
	SaveClientCookies(client);
	return Plugin_Handled;
}

void DisplayGlowColorMenu(int client)
{
	// We should not leave the command parameter empty, there can be an unexpected behavior
	bool bAccess = HasGlowColorsAccess(client);
	if (bAccess)
	{
		g_GlowColorsMenu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		if (!IsPlayerAlive(client))
		{		
			CPrintToChat(client, "%T", "NotAlive", client);
			return;
		}
#if defined _zr_included
		if (g_Plugin_ZR)
		{
			if (ZR_IsClientZombie(client))
			{
				CPrintToChat(client, "%T", "Zombie", client);
				return;
			}
			
			if (ZR_GetActiveClass(client) != ZR_GetClassByName("Master Chief"))
			{
				CPrintToChat(client, "%T", "WrongModel", client);
				return;
			}
		}
#endif
		g_GlowColorsMenu.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_GlowColorsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char aItem[16];
		menu.GetItem(param2, aItem, sizeof(aItem));

		ColorStringToArray(aItem, g_aGlowColor[param1]);
		int Color = (g_aGlowColor[param1][0] << 16) +
			(g_aGlowColor[param1][1] << 8) +
			(g_aGlowColor[param1][2] << 0);

		StopRainbow(param1);

		ApplyGlowColor(param1);
		SaveClientCookies(param1);
		CPrintToChat(param1, "%s \x07%06X Set color to: %06X", CHAT_PREFIX, Color, Color);
	}
	return 0;
}

public void Event_ApplyGlowcolor(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	CreateTimer(g_Cvar_PluginTimer.FloatValue, Timer_ApplyGlowColor, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ApplyGlowColor(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	if (!client)
		return Plugin_Continue;
	
	if (g_bRainbowEnabled[client] && HasRainbowAccess(client))
		StartRainbow(client, g_aRainbowFrequency[client]);
	else
	{
		if (g_bRainbowEnabled[client])
		{
			g_bRainbowEnabled[client] = false;
			g_aRainbowFrequency[client] = 0.0;
			SaveClientCookies(client);
		}

		ApplyGlowColor(client);
	}

	return Plugin_Continue;
}

bool HasRainbowAccess(int client)
{
	return CheckCommandAccess(client, "sm_rainbow", ADMFLAG_CUSTOM1, true) || CheckCommandAccess(client, "sm_root", ADMFLAG_ROOT, true);
}

bool HasGlowColorsAccess(int client)
{
	return CheckCommandAccess(client, "sm_glowcolors", ADMFLAG_CUSTOM2, true) || CheckCommandAccess(client, "sm_root", ADMFLAG_ROOT, true);
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
	int Brightness = ColorBrightness(g_aGlowColor[client][0], g_aGlowColor[client][1], g_aGlowColor[client][2]);
	if (Brightness < g_Cvar_MinBrightness.IntValue)
	{
		CPrintToChat(client, "%s Your glowcolor is too dark! (brightness = {red}%d{default}/255, allowed values are {green}> %d{default})", CHAT_PREFIX,
			Brightness, g_Cvar_MinBrightness.IntValue -1 );

		g_aGlowColor[client][0] = 255;
		g_aGlowColor[client][1] = 255;
		g_aGlowColor[client][2] = 255;
		SaveClientCookies(client);
		return false;
	}

	if (!IsPlayerAlive(client))
		return false;
		
	if (HasGlowColorsAccess(client))
	{
		ToolsSetEntityColor(client, g_aGlowColor[client][0], g_aGlowColor[client][1], g_aGlowColor[client][2]);
		return true;
	}

#if defined _zr_included
	if (g_Plugin_ZR && ZR_GetActiveClass(client) == ZR_GetClassByName("Master Chief"))
	{
		ToolsSetEntityColor(client, g_aGlowColor[client][0], g_aGlowColor[client][1], g_aGlowColor[client][2]);
		return true;
	}
	
	if (g_Plugin_ZR && ZR_IsClientZombie(client))
	{
		ToolsSetEntityColor(client, 255, 255, 255);
		return true;
	}
#else
	ToolsSetEntityColor(client, 255, 255, 255);
#endif

	return true;
}

stock void StopRainbow(int client)
{
	if (g_aRainbowFrequency[client])
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

	if (!s_GotConfig)
	{
		GameData GameConf = new GameData("core.games");
		bool Exists = GameConf.GetKeyValue("m_clrRender", s_sProp, sizeof(s_sProp));
		delete GameConf;

		if (!Exists)
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
	if (g_Regex_RGB.Match(sString) > 0)
		return true;
	return false;
}

stock bool IsValidHex(char[] sString)
{
	if (g_Regex_HEX.Match(sString) > 0)
		return true;
	return false;
}

stock int ColorBrightness(int Red, int Green, int Blue)
{
	// http://www.nbdtech.com/Blog/archive/2008/04/27/Calculating-the-Perceived-Brightness-of-a-Color.aspx
	return RoundToFloor(SquareRoot(
		Red * Red * 0.241 +
		Green * Green * 0.691 +
		Blue * Blue * 0.068));
}

public int Native_SetRainbow(Handle hPlugins, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);

	float frequency = 1.0;
	if (numParams >= 2)
		frequency = view_as<float>(GetNativeCell(2));

	StartRainbow(client, frequency);
	return 0;
}

public int Native_RemoveRainbow(Handle hPlugins, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);

	StopRainbow(client);
	ApplyGlowColor(client);
	return 0;
}
