#if defined _glowcolors_included
	#endinput
#endif
#define _glowcolors_included

native void Gl_SetRainbow(int client);
native void Gl_RemoveRainbow(int client);

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
	MarkNativeAsOptional("Gl_SetRainbow");
	MarkNativeAsOptional("Gl_RemoveRainbow");
}
#endif