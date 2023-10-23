#if defined _glowcolors_included
	#endinput
#endif
#define _glowcolors_included

native void GlowColors_SetRainbow(int client);
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