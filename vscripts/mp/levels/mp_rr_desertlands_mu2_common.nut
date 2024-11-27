global function Desertlands_MapInit_Common
global function CodeCallback_PlayerEnterUpdraftTrigger
global function CodeCallback_PlayerLeaveUpdraftTrigger
global function CodeCallback_PreMapInit

const string HARVESTER_BEAM_MDL = $"mdl/fx/harvester_beam_mu1.rmdl"

const string SILO_PANEL_SCRIPTNAME = "silo_doors_panel"
const string SILO_PANEL_MDL = $"mdl/beacon/crane_room_monitor_console.rmdl"
const string SILO_MOVER_SCRIPTNAME = "silo_platform_mover"
const string SILO_PATH_SCRIPTNAME = "silo_platform_mover_path_end"
const string SILO_DOOR_FLAG_END = "drillsite_bunker_1_complete"
const string SILO_DOOR_LEFT_SCRIPTNAME = "silo_door_left"
const string SILO_DOOR_LEFT_MOVER_SCRIPTNAME = "silo_door_left_mover"
const string SILO_DOOR_RIGHT_SCRIPTNAME = "silo_door_right"
const string SILO_DOOR_RIGHT_MOVER_SCRIPTNAME = "silo_door_right_mover"
const string SILO_PLATFORM_SCRIPTNAME = "silo_rising_platform"
const string WAYPOINTTYPE_SILO_DOORS = "desertlands_silo_doors_waypoint"

const string SILO_PANEL_ACTIVATE_SFX = "Desertlands_MU2_Silo_Open"
const string SILO_DOORS_OPEN_SFX = "Desertlands_Fortress_Interactive_Panel"
const string SILO_ELEVATOR_LOOP_SFX = "Desertlands_MU2_Silo_Ascend_LP"
const string SILO_ELEVATOR_STOP_SFX = "Desertlands_MU2_Silo_Ascend_End"

#if SERVER
global function Desertlands_MU1_MapInit_Common
global function Desertlands_MU1_EntitiesLoaded_Common
global function Desertlands_MU1_UpdraftInit_Common
#endif


#if SERVER
//Copied from _jump_pads. This is being hacked for the geysers.
const float JUMP_PAD_PUSH_RADIUS = 256.0
const float JUMP_PAD_PUSH_PROJECTILE_RADIUS = 32.0//98.0
const float JUMP_PAD_PUSH_VELOCITY = 2000.0
const float JUMP_PAD_VIEW_PUNCH_SOFT = 25.0
const float JUMP_PAD_VIEW_PUNCH_HARD = 4.0
const float JUMP_PAD_VIEW_PUNCH_RAND = 4.0
const float JUMP_PAD_VIEW_PUNCH_SOFT_TITAN = 120.0
const float JUMP_PAD_VIEW_PUNCH_HARD_TITAN = 20.0
const float JUMP_PAD_VIEW_PUNCH_RAND_TITAN = 20.0

const asset JUMP_PAD_MODEL = $"mdl/props/octane_jump_pad/octane_jump_pad.rmdl"

const float JUMP_PAD_ANGLE_LIMIT = 0.70
const float JUMP_PAD_ICON_HEIGHT_OFFSET = 48.0
const float JUMP_PAD_ACTIVATION_TIME = 0.5
const asset JUMP_PAD_LAUNCH_FX = $"P_grndpnd_launch"
const JUMP_PAD_DESTRUCTION = "jump_pad_destruction"

// Loot drones
const int NUM_LOOT_DRONES_TO_SPAWN = 12
const int NUM_LOOT_DRONES_WITH_VAULT_KEYS = 4
#endif

struct
{
	bool siloDoorHasBeenActivated = false
	#if SERVER
	array<LootData> weapons
	array<LootData> items
	array<LootData> ordnance
	#endif

} file

void function CodeCallback_PreMapInit()
{
}

void function Desertlands_MapInit_Common()
{
	printt( "Desertlands_MapInit_Common" )

	MapZones_RegisterDataTable( $"datatable/map_zones/zones_mp_rr_desertlands_64k_x_64k.rpak" )

	FlagInit( "PlayConveyerStartFX", true )
	FlagInit( "PlayConveyerEndFX", true )

	SetVictorySequencePlatformModel( $"mdl/rocks/desertlands_victory_platform.rmdl", < 0, 0, -10 >, < 0, 0, 0 > )

	#if SERVER
		PrecacheModel( SILO_PANEL_MDL )
		PrecacheModel( HARVESTER_BEAM_MDL )		

		AddCallback_EntitiesDidLoad( EntitiesDidLoad )
		SURVIVAL_SetPlaneHeight( 15250 )
		SURVIVAL_SetAirburstHeight( 2500 )
		SURVIVAL_SetMapCenter( <0, 0, 0> )
		// Survival_SetMapFloorZ( -8000 )

		RegisterSignal( "ReachedPathEnd" )
		AddSpawnCallback_ScriptName( "conveyor_rotator_mover", OnSpawnConveyorRotatorMover )
	#endif

	#if CLIENT
		Freefall_SetPlaneHeight( 15250 )
		Freefall_SetDisplaySeaHeightForLevel( -8961.0 )

		SetVictorySequenceLocation( <11092.6162, -20878.0684, 1561.52222>, <0, 267.894653, 0> )
		SetVictorySequenceSunSkyIntensity( 1.0, 0.5 )
		SetMinimapBackgroundTileImage( $"overviews/mp_rr_canyonlands_bg" )
	#endif
}

#if SERVER
void function SetupSiloPanels()
{
	array<string> flagsToSet
	array<entity> newPanels
	foreach ( entity oldPanel in GetEntArrayByScriptName( SILO_PANEL_SCRIPTNAME ) )
	{
		entity panel = CreatePropDynamic( SILO_PANEL_MDL, oldPanel.GetOrigin(), oldPanel.GetAngles(), SOLID_VPHYSICS )
		newPanels.append( panel )

		if ( oldPanel.HasKey( "scr_flagToggle" ) )
		{
			string flagRequired = expect string( oldPanel.kv.scr_flagToggle )
			flagsToSet.append( flagRequired )
		}

		oldPanel.Destroy()
	}

	foreach ( string flagToSet in flagsToSet )
	{
		if ( !FlagExists( flagToSet ) )
			FlagInit( flagToSet )
	}

	foreach ( entity panel in newPanels )
	{
		panel.AllowMantle()
		panel.SetForceVisibleInPhaseShift( true )
		panel.SetUsable()
		panel.AddUsableValue( USABLE_CUSTOM_HINTS | USABLE_BY_OWNER | USABLE_BY_PILOTS | USABLE_BY_ENEMIES )
		panel.SetUsablePriority( USABLE_PRIORITY_LOW )
		panel.SetSkin( 1 )
		panel.SetUsePrompts( "#SILO_DOOR_PANEL_HINT", "#SILO_DOOR_PANEL_HINT" )
		AddCallback_OnUseEntity( panel, CreateSiloPanelFunc( flagsToSet, newPanels ) )
	}

	// Make sure panels exist before trying to set up doors
	// TODO: MegC: this is temporary fix to allow art team to compile Desertlands without Zone 1
	/*if ( newPanels.len() > 0 )
	{
		// character abilities on the doors
		array<entity> siloDoors
		siloDoors.append( GetEntByScriptName( SILO_DOOR_LEFT_SCRIPTNAME ) )
		siloDoors.append( GetEntByScriptName( SILO_DOOR_RIGHT_SCRIPTNAME ) )

		array<entity> siloDoorMovers
		siloDoorMovers.append( GetEntByScriptName( SILO_DOOR_LEFT_MOVER_SCRIPTNAME ) )
		siloDoorMovers.append( GetEntByScriptName( SILO_DOOR_RIGHT_MOVER_SCRIPTNAME ) )

		foreach ( entity mover in siloDoorMovers )
			thread WaitForLootInitFinishedAndSetupDoors( mover )
	}*/
}


void function WaitForLootInitFinishedAndSetupDoors( entity mover )
{
	FlagWait( "Survival_LootSpawned" )

	if ( IsValid( mover ) )
	{
		mover.AllowZiplines()
	}
}

void functionref( entity activePanel, entity player, int useInputFlags ) function CreateSiloPanelFunc( array<string> flagsToSet, array<entity> allPanels )
{
	return void function( entity activePanel, entity player, int useInputFlags ) : ( flagsToSet, allPanels )
	{
		thread OnSiloPanelActivate( activePanel, allPanels, flagsToSet )
	}
}

void function OnSiloPanelActivate( entity activePanel, array<entity> allPanels, array<string> flagsToSet )
{
	if ( file.siloDoorHasBeenActivated )
		return

	file.siloDoorHasBeenActivated = true

	//entity siloPlatform = GetEntByScriptName( SILO_PLATFORM_SCRIPTNAME )
	entity platformMover   = GetEntByScriptName( SILO_MOVER_SCRIPTNAME )
	entity pathEnd = GetEntByScriptName( SILO_PATH_SCRIPTNAME )

	/*array<entity> siloDoors
	siloDoors.append( GetEntByScriptName( SILO_DOOR_LEFT_SCRIPTNAME ) )
	siloDoors.append( GetEntByScriptName( SILO_DOOR_RIGHT_SCRIPTNAME ) )*/

	/*array<entity> siloDoorMovers
	siloDoorMovers.append( GetEntByScriptName( SILO_DOOR_LEFT_MOVER_SCRIPTNAME ) )
	siloDoorMovers.append( GetEntByScriptName( SILO_DOOR_RIGHT_MOVER_SCRIPTNAME ) )*/

	// panels
	foreach ( entity panel in allPanels )
	{
		if ( IsValid( panel ) )
		{
			panel.UnsetUsable()
			panel.SetSkin( 2 )
		}
	}

	// handle objects on the doors and lift
	platformMover.SetPusher( true )
	platformMover.DisallowZiplines()

	/*foreach ( entity doorMover in siloDoorMovers )
	{
		doorMover.SetPusher( true )
		doorMover.DisallowZiplines()
		//doorMover.DisallowObjectPlacement()
	}*/

	//entity wp = CreateWaypoint_Custom( WAYPOINTTYPE_SILO_DOORS )

	/*foreach ( entity door in siloDoors )
	{
		CleanUpPermanentsParentedToDynamicEnt( door )
		AddEntToInvalidEntsForPlacingPermanentsOnto( door )
		AddEntityDestroyedCallback( door,
			void function( entity ent ) : ( door )
			{
				RemoveEntFromInvalidEntsForPlacingPermanentsOnto( ent )
			}
		)
	}*/

	// move the doors and lift
	foreach	( string flagToSet in flagsToSet )
		FlagSet( flagToSet )

	EmitSoundAtPosition( TEAM_ANY, activePanel.GetOrigin(), SILO_PANEL_ACTIVATE_SFX, activePanel )
	EmitSoundAtPosition( TEAM_ANY, pathEnd.GetOrigin(), SILO_DOORS_OPEN_SFX, pathEnd )
	EmitSoundOnEntity( platformMover, SILO_ELEVATOR_LOOP_SFX )

	FlagWait( SILO_DOOR_FLAG_END )

	EmitSoundOnEntity( platformMover, SILO_ELEVATOR_STOP_SFX )

	// handle abilities on lift
	//wp.SetWaypointInt( 0, 1 )

	platformMover.AllowZiplines()
	//AddToAllowedAirdropDynamicEntities( siloPlatform )
}

#endif
#if SERVER

void function EntitiesDidLoad()
{
	
	if( GetCurrentPlaylistVarBool( "firingrange_aimtrainerbycolombia", false ) )
		return

	SetupSiloPanels()
	Desertlands_MU1_EntitiesLoaded_Common()

	GeyserInit()
	//Updrafts_Init()

	FillLootTable()
	
	if( Gamemode() == eGamemodes.SURVIVAL && MapName() != eMaps.mp_rr_desertlands_64k_x_64k_tt ) 
	{
		thread function () : ()
		{
			InitLootDrones()
			InitLootDronePaths()
			InitLootRollers()
			SpawnLootDrones( 12 )
		}()
	}
	
	FS_SetupMemorial()
}
#endif

#if SERVER
void function FS_SetupMemorial()
{
	vector origin = <-23564.7637, 36239.0664, -3189.44995>
	
	entity trigger = CreateEntity( "trigger_cylinder" )
	trigger.SetRadius( 200 )
	trigger.SetAboveHeight( 100 )
	trigger.SetBelowHeight( 50 )
	trigger.SetOrigin( origin )
	trigger.SetEnterCallback(  FSMemorialEnter )

	DispatchSpawn( trigger )
}

void function FSMemorialEnter( entity trigger , entity ent )
{
	if( !IsValid(ent) ) return
	
	printt( "memorial enter" )
	Message( ent, "FLOWSTATE MEMORIAL", "Gracias por darme la vida, gracias por las enseñanzas.\n Gracias por darme las fuerzas para seguir adelante.\n Gracias por darme las fuerzas para desarrollar Flowstate.\n                  Por CafeFPS." )
}

#endif

//=================================================================================================
//=================================================================================================
//
//  ##     ## ##     ##    ##       ######   #######  ##     ## ##     ##  #######  ##    ##
//  ###   ### ##     ##  ####      ##    ## ##     ## ###   ### ###   ### ##     ## ###   ##
//  #### #### ##     ##    ##      ##       ##     ## #### #### #### #### ##     ## ####  ##
//  ## ### ## ##     ##    ##      ##       ##     ## ## ### ## ## ### ## ##     ## ## ## ##
//  ##     ## ##     ##    ##      ##       ##     ## ##     ## ##     ## ##     ## ##  ####
//  ##     ## ##     ##    ##      ##    ## ##     ## ##     ## ##     ## ##     ## ##   ###
//  ##     ##  #######   ######     ######   #######  ##     ## ##     ##  #######  ##    ##
//
//=================================================================================================
//=================================================================================================

#if SERVER
void function Desertlands_MU1_MapInit_Common()
{
	AddSpawnCallback_ScriptName( "conveyor_rotator_mover", OnSpawnConveyorRotatorMover )

	Desertlands_MapInit_Common()
	PrecacheParticleSystem( JUMP_PAD_LAUNCH_FX )

	//SURVIVAL_SetDefaultLootZone( "zone_medium" )

	//LaserMesh_Init()
	FlagSet( "DisableDropships" )

	AddDamageCallbackSourceID( eDamageSourceId.burn, OnBurnDamage )

	svGlobal.evacEnabled = false //Need to disable this on a map level if it doesn't support it at all
}

void function OnBurnDamage( entity player, var damageInfo )
{
	if ( !player.IsPlayer() )
		return

	// sky laser shouldn't hurt players in plane
	if ( player.GetPlayerNetBool( "playerInPlane" ) )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
	}
}

void function OnSpawnConveyorRotatorMover( entity mover )
{
	thread ConveyorRotatorMoverThink( mover )
}

void function ConveyorRotatorMoverThink( entity mover )
{
	mover.EndSignal( "OnDestroy" )

	entity rotator = GetEntByScriptName( "conveyor_rotator" )
	entity startNode
	entity endNode

	array<entity> links = rotator.GetLinkEntArray()
	foreach ( l in links )
	{
		if ( l.GetValueForKey( "script_noteworthy" ) == "end" )
			endNode = l
		if ( l.GetValueForKey( "script_noteworthy" ) == "start" )
			startNode = l
	}


	float angle1 = VectorToAngles( startNode.GetOrigin() - rotator.GetOrigin() ).y
	float angle2 = VectorToAngles( endNode.GetOrigin() - rotator.GetOrigin() ).y

	float angleDiff = angle1 - angle2
	angleDiff = (angleDiff + 180) % 360 - 180

	float rotatorSpeed = float( rotator.GetValueForKey( "rotate_forever_speed" ) )
	float waitTime     = fabs( angleDiff ) / rotatorSpeed

	Assert( IsValid( endNode ) )

	while ( true )
	{
		mover.WaitSignal( "ReachedPathEnd" )

		mover.SetParent( rotator, "", true )

		wait waitTime

		mover.ClearParent()
		mover.SetOrigin( endNode.GetOrigin() )
		mover.SetAngles( endNode.GetAngles() )

		thread MoverThink( mover, [ endNode ] )
	}
}

void function Desertlands_MU1_UpdraftInit_Common( entity player )
{
	//ApplyUpdraftModUntilTouchingGround( player )
	//thread PlayerSkydiveFromCurrentPosition( player )
	//thread BurnPlayerOverTime( player )
}

void function Desertlands_MU1_EntitiesLoaded_Common()
{
	entity HarvestFX = CreatePropDynamic( HARVESTER_BEAM_MDL, <-2541, -11265, -6243>, <0, 0, 0> )
	entity HarvestFX2 = CreatePropDynamic( HARVESTER_BEAM_MDL, <-2541, -11265, 24820>, <0, 0, 0> )
	entity HarvestFX3 = CreatePropDynamic( HARVESTER_BEAM_MDL, <-2541, -11265, 55642>, <0, 0, 0> )
}

//Geyster stuff
void function GeyserInit()
{
	array<entity> geyserTargets = GetEntArrayByScriptName( "geyser_jump" )
	foreach ( target in geyserTargets )
	{
		thread GeyersJumpTriggerArea( target )
		//target.Destroy()
	}
}

void function GeyersJumpTriggerArea( entity jumpPad )
{
	Assert ( IsNewThread(), "Must be threaded off" )
	jumpPad.EndSignal( "OnDestroy" )

	vector origin = OriginToGround( jumpPad.GetOrigin() )
	vector angles = jumpPad.GetAngles()

	entity trigger = CreateEntity( "trigger_cylinder_heavy" )
	SetTargetName( trigger, "geyser_trigger" )
	trigger.SetOwner( jumpPad )
	trigger.SetRadius( JUMP_PAD_PUSH_RADIUS )
	trigger.SetAboveHeight( 32 )
	trigger.SetBelowHeight( 16 ) //need this because the player or jump pad can sink into the ground a tiny bit and we check player feet not half height
	trigger.SetOrigin( origin )
	trigger.SetAngles( angles )
	trigger.SetTriggerType( TT_JUMP_PAD )
	trigger.SetLaunchScaleValues( JUMP_PAD_PUSH_VELOCITY, 1.25 )
	trigger.SetViewPunchValues( JUMP_PAD_VIEW_PUNCH_SOFT, JUMP_PAD_VIEW_PUNCH_HARD, JUMP_PAD_VIEW_PUNCH_RAND )
	trigger.SetLaunchDir( <0.0, 0.0, 1.0> )
	trigger.UsePointCollision()
	trigger.kv.triggerFilterNonCharacter = "0"
	DispatchSpawn( trigger )
	trigger.SetEnterCallback( Geyser_OnJumpPadAreaEnter )

	entity traceBlocker = CreateTraceBlockerVolume( trigger.GetOrigin(), 24.0, true, CONTENTS_BLOCK_PING | CONTENTS_NOGRAPPLE, TEAM_MILITIA, GEYSER_PING_SCRIPT_NAME )
	traceBlocker.SetBox( <-192, -192, -16>, <192, 192, 3000> )

	//DebugDrawCylinder( origin, < -90, 0, 0 >, JUMP_PAD_PUSH_RADIUS, trigger.GetAboveHeight(), 255, 0, 255, true, 9999.9 )
	//DebugDrawCylinder( origin, < -90, 0, 0 >, JUMP_PAD_PUSH_RADIUS, -trigger.GetBelowHeight(), 255, 0, 255, true, 9999.9 )

	OnThreadEnd(
		function() : ( trigger )
		{
			trigger.Destroy()
		} )

	WaitForever()
}


void function Geyser_OnJumpPadAreaEnter( entity trigger, entity ent )
{
	Geyser_JumpPadPushEnt( trigger, ent, trigger.GetOrigin(), trigger.GetAngles() )
}


void function Geyser_JumpPadPushEnt( entity trigger, entity ent, vector origin, vector angles )
{
	if ( Geyser_JumpPad_ShouldPushPlayerOrNPC( ent ) )
	{
		if ( ent.IsPlayer() )
		{
			entity jumpPad = trigger.GetOwner()
			if ( IsValid( jumpPad ) )
			{
				int fxId = GetParticleSystemIndex( JUMP_PAD_LAUNCH_FX )
				StartParticleEffectOnEntity( jumpPad, fxId, FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
			}
			thread Geyser_JumpJetsWhileAirborne( ent )
		}
		else
		{
			EmitSoundOnEntity( ent, "JumpPad_LaunchPlayer_3p" )
			EmitSoundOnEntity( ent, "JumpPad_AirborneMvmt_3p" )
		}
	}
}


void function Geyser_JumpJetsWhileAirborne( entity player )
{
	if ( !IsPilot( player ) )
		return
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.Signal( "JumpPadStart" )
	player.EndSignal( "JumpPadStart" )
	player.EnableSlowMo()
	player.DisableMantle()

	EmitSoundOnEntityExceptToPlayer( player, player, "JumpPad_LaunchPlayer_3p" )
	EmitSoundOnEntityExceptToPlayer( player, player, "JumpPad_AirborneMvmt_3p" )

	array<entity> jumpJetFXs
	array<string> attachments = [ "vent_left", "vent_right" ]
	int team                  = player.GetTeam()
	foreach ( attachment in attachments )
	{
		int friendlyID    = GetParticleSystemIndex( TEAM_JUMPJET_DBL )
		entity friendlyFX = StartParticleEffectOnEntity_ReturnEntity( player, friendlyID, FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( attachment ) )
		friendlyFX.SetOwner( player )
		SetTeam( friendlyFX, team )
		friendlyFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY
		jumpJetFXs.append( friendlyFX )

		int enemyID    = GetParticleSystemIndex( ENEMY_JUMPJET_DBL )
		entity enemyFX = StartParticleEffectOnEntity_ReturnEntity( player, enemyID, FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( attachment ) )
		SetTeam( enemyFX, team )
		enemyFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_ENEMY
		jumpJetFXs.append( enemyFX )
	}

	OnThreadEnd(
		function() : ( jumpJetFXs, player )
		{
			foreach ( fx in jumpJetFXs )
			{
				if ( IsValid( fx ) )
					fx.Destroy()
			}

			if ( IsValid( player ) )
			{
				player.DisableSlowMo()
				player.EnableMantle()
				StopSoundOnEntity( player, "JumpPad_AirborneMvmt_3p" )
			}
		}
	)

	WaitFrame()

	wait 0.1

	while( IsValid( player ) && !player.IsOnGround() )
	{
		WaitFrame()
	}
}


bool function Geyser_JumpPad_ShouldPushPlayerOrNPC( entity target )
{
	if ( target.IsTitan() )
		return false

	if ( IsSuperSpectre( target ) )
		return false

	if ( IsTurret( target ) )
		return false

	if ( IsDropship( target ) )
		return false

	return true
}


///////////////////////
///////////////////////
//// Updrafts

const string UPDRAFT_TRIGGER_SCRIPT_NAME = "skydive_dust_devil"
void function Updrafts_Init()
{
	/*return
	array<entity> triggers = GetEntArrayByScriptName( UPDRAFT_TRIGGER_SCRIPT_NAME )
	foreach ( entity trigger in triggers )
	{
		if ( trigger.GetClassName() != "trigger_updraft" )
		{
			entity newTrigger = CreateEntity( "trigger_cylinder" )
			newTrigger.SetOrigin( trigger.GetOrigin() )
			newTrigger.SetAngles( trigger.GetAngles() )
			newTrigger.SetModel( trigger.GetModelName() )
			newTrigger.SetScriptName( UPDRAFT_TRIGGER_SCRIPT_NAME )
			newTrigger.kv.triggerFilterTeamBeast = 1
			newTrigger.kv.triggerFilterTeamNeutral = 1
			newTrigger.kv.triggerFilterTeamOther = 1
			newTrigger.kv.triggerFilterUseNew = 1
			DispatchSpawn( newTrigger )
			trigger.Destroy()
			DebugDrawCylinder( newTrigger.GetOrigin(), < -90, 0, 0 >, JUMP_PAD_PUSH_RADIUS, newTrigger.GetAboveHeight(), 255, 0, 255, true, 9999.9 )
		}
	}*/
}

void function BurnPlayerOverTime( entity player )
{
	/*Assert( IsValid( player ) )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	player.EndSignal( "DeathTotem_PreRecallPlayer" )
	for ( int i = 0; i < 8; ++i )
	{
		//if ( !player.Player_IsInsideUpdraftTrigger() )
			//break

		if ( !player.IsPhaseShifted() )
		{
			player.TakeDamage( 5, null, null, { damageSourceId = eDamageSourceId.burn, damageType = DMG_BURN } )
		}

		wait 0.5
	}*/
}
#endif

void function CodeCallback_PlayerEnterUpdraftTrigger( entity trigger, entity player )
{
	/*float entZ = player.GetOrigin().z
	OnEnterUpdraftTrigger( trigger, player, max( -5750.0, entZ - 400.0 ) )
	#if SERVER
		PIN_Interact ( player, "desertlands_updraft_enter" )
	#endif*/
}

void function CodeCallback_PlayerLeaveUpdraftTrigger( entity trigger, entity player )
{
	//OnLeaveUpdraftTrigger( trigger, player )
}



                           // 888                                .d888                            888    d8b
                           // 888                               d88P"                             888    Y8P
                           // 888                               888                               888
 // .d8888b 888  888 .d8888b  888888 .d88b.  88888b.d88b.       888888 888  888 88888b.   .d8888b 888888 888  .d88b.  88888b.  .d8888b
// d88P"    888  888 88K      888   d88""88b 888 "888 "88b      888    888  888 888 "88b d88P"    888    888 d88""88b 888 "88b 88K
// 888      888  888 "Y8888b. 888   888  888 888  888  888      888    888  888 888  888 888      888    888 888  888 888  888 "Y8888b.
// Y88b.    Y88b 888      X88 Y88b. Y88..88P 888  888  888      888    Y88b 888 888  888 Y88b.    Y88b.  888 Y88..88P 888  888      X88
 // "Y8888P  "Y88888  88888P'  "Y888 "Y88P"  888  888  888      888     "Y88888 888  888  "Y8888P  "Y888 888  "Y88P"  888  888  88888P'

#if SERVER
void function RespawnItem(entity item, string ref, int amount = 1, int wait_time=6)
//By @CafeFPS CafeFPS. Tomado del firing range.

{
	vector pos = item.GetOrigin()
	vector angles = item.GetAngles()
	item.WaitSignal("OnItemPickup")

	wait wait_time
	StartParticleEffectInWorld( GetParticleSystemIndex( $"P_impact_shieldbreaker_sparks" ), pos, angles )
	thread RespawnItem(SpawnGenericLoot(ref, pos, angles, amount), ref, amount)
}
#endif

#if SERVER
void function FillLootTable()
//By @CafeFPS CafeFPS. Adaptado del firing range.
{
	file.ordnance.extend(SURVIVAL_Loot_GetByType( eLootType.ORDNANCE ))
	file.weapons.extend(SURVIVAL_Loot_GetByType( eLootType.MAINWEAPON ))
}
#endif

#if SERVER
void function SpawnGrenades(vector pos, vector ang, int wait_time = 6, array which_nades = ["thermite", "frag", "arc"], int num_rows = 1)
//By michae\l/#1125 & @CafeFPS
{
    vector posfixed = pos
	int i;
    for (i = 0; i < num_rows; i++)
    {
        if(i != 0) {posfixed += <30, 0 - which_nades.len() * 30, 0>}
            foreach(nade in which_nades)
        {
            LootData item
			posfixed = posfixed + <0, 30, 0>
            if(nade == "thermite") {
                item = file.ordnance[0]
            }
            else if(nade == "frag") {
                item = file.ordnance[1]
			}
            else if(nade == "arc") {
                item = file.ordnance[2]
        }
		entity loot = SpawnGenericLoot(item.ref, posfixed, ang, 1)
		thread RespawnItem(loot, item.ref, 1, wait_time)
	}}}
#endif

#if SERVER
entity function CreateEditorPropLobby(asset a, vector pos, vector ang, bool mantle = false, float fade = 2000, int realm = -1)
{
    entity e = CreatePropDynamic(a,pos,ang,SOLID_VPHYSICS,fade)
    e.kv.fadedist = fade
    if(mantle) e.AllowMantle()

    if (realm > -1) {
        e.RemoveFromAllRealms()
        e.AddToRealm(realm)
    }

    string positionSerialized = pos.x.tostring() + "," + pos.y.tostring() + "," + pos.z.tostring()
    string anglesSerialized = ang.x.tostring() + "," + ang.y.tostring() + "," + ang.z.tostring()

    e.SetScriptName("editor_placed_prop")
    e.e.gameModeId = realm
   // printl("[editor]" + string(a) + ";" + positionSerialized + ";" + anglesSerialized + ";" + realm)

    return e
}

#endif
