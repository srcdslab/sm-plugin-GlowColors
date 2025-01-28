#if defined _glowcolors_included
	#endinput
#endif
#define _glowcolors_included

#define GlowColors_V_MAJOR   "1"
#define GlowColors_V_MINOR   "3"
#define GlowColors_V_PATCH   "5"

#define GlowColors_VERSION   GlowColors_V_MAJOR..."."...GlowColors_V_MINOR..."."...GlowColors_V_PATCH
/**
 * Enables rainbow glow effect for a client.
 *
 * @param client    Client index
 * @noreturn
 * @error          Invalid client index or client not in game
 */
native void GlowColors_SetRainbow(int client);

/**
 * Disables rainbow glow effect for a client.
 *
 * @param client    Client index
 * @noreturn
 * @error          Invalid client index or client not in game
 */
native void GlowColors_RemoveRainbow(int client);

public SharedPlugin __pl_glowcolors = 
{
	name = "Glowcolors",
	file = "GlowColors.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_glowcolors_SetNTVOptional()
{
	MarkNativeAsOptional("GlowColors_SetRainbow");
	MarkNativeAsOptional("GlowColors_RemoveRainbow");
}
#endif
