class TelekineticGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;
var Actor tkItem;
var EPhysics oldPhysics;
var ECollisionType oldCollisionType;
var PrimitiveComponent oldCollisionComponent;
var SoundCue itsNoUse;
var SoundCue takeThis;
var SoundCue howAboutThis;
var bool play_sound;
var Material mAngelMaterial;
var bool mIsBackPressed;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		gMe.bCanBeBaseForPawns=true;
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if(localInput.IsKeyIsPressed( "GBA_FreeLook", string( newKey ) ))
		{
			ActivateTelekinesis();
		}

		if(localInput.IsKeyIsPressed( "GBA_AbilityAuto", string( newKey ) ))
		{
			if(GGLocalPlayer(PCOwner.Player).mIsUsingGamePad)
			{
				mIsBackPressed=(PCOwner.PlayerInput.aBaseY < -0.8f);
			}
			if(mIsBackPressed)// Back attack
			{
				ThrowItem(vect(0, 0, 1));
			}
			else // Forward attack
			{
				if(ThrowItem(vect(1, 0, 0)) && play_sound)
				{
					myMut.PlaySound(howAboutThis);
				}
			}

		}

		if(localInput.IsKeyIsPressed( "GBA_Back", string( newKey ) ))
		{
			mIsBackPressed=true;
		}
	}
	else if( keyState == KS_Up )
	{
		if(localInput.IsKeyIsPressed( "GBA_Back", string( newKey ) ))
		{
			mIsBackPressed=false;
		}
	}
}

/**
 * Main loop
 */
event TickMutatorComponent( float deltaTime )
{
	local vector tkLocation;
	local GGNpc npc;
	local GGGoat goat;

	super.TickMutatorComponent(deltaTime);

	//You can't transport items when you ragdoll
	if(gMe.mIsRagdoll && tkItem != none)
	{
		DropItem();
	}

	//If you hold another player and he ragdoll, you drop him
	goat=GGGoat(tkItem);
	if(goat != none && goat.mIsRagdoll)
	{
		DropItem();
	}

	//Force movement
	gMe.mesh.GetSocketWorldLocationAndRotation('Demonic', tkLocation);
	if(IsZero(tkLocation))
	{
		tkLocation=gMe.Location + (Normal(vector(gMe.Rotation)) * (gMe.GetCollisionRadius() + 30.f));
	}
	if(tkItem != none && tkItem.Location != tkLocation)
	{
		AttachItem();
	}

	//Force unragdoll NPCs
	npc = GGNpc(tkItem);
	if(npc != none)
	{
		npc.mIsRagdollAllowed=false;
	}

	//Activate sonic easter egg
	if(!play_sound)
	{
		if(MaterialInstanceConstant(gMe.mesh.GetMaterial(0)) != none)
		{
			play_sound=true;
		}
	}
}

/**
 * Activate Telekinetic powers when you right click
 */
function ActivateTelekinesis()
{
	local bool item_found;

	//WorldInfo.Game.Broadcast(self, "right click");
	if(tkItem == none)
	{
		item_found=TakeItem();
		if(play_sound && item_found)
		{
			myMut.PlaySound(itsNoUse);
		}
	}
	else
	{
		ThrowItem(vect(1, 0, 1));
		if(play_sound)
		{
			myMut.PlaySound(takeThis);
		}
	}
}

/*
 * Try to take the first item aligned with the goat or the item you are licking
 */
function bool TakeItem()
{
	local vector traceStart, traceEnd, hitLocation, hitNormal;
	local Actor hitActor;
	local bool validActorFound;
	local bool baseOk;

	if(gMe.mIsRagdoll || tkItem != none)
		return false;

	//If licking somthing, this object is captured
	if(gMe.mGrabbedItem != none)
	{
		hitActor=gMe.mGrabbedItem;
		validActorFound=true;
	}
	//Else we take the closed item in front of the goat
	else
	{
		traceStart = gMe.Location;
		traceEnd = traceStart + Normal(vector(gMe.Rotation))*600;
		//DrawDebugLine (traceStart, traceEnd, 0, 0, 0, true);

		validActorFound=false;
		foreach myMut.TraceActors (class'Actor', hitActor, hitLocation, hitNormal, traceEnd, traceStart, gMe.GetCollisionExtent())
		{
			if(GGGoat(hitActor) == gMe)
				continue;

			if(IsValidActor(hitActor))
			{
				validActorFound=true;
				break;
			}
		}
		//WorldInfo.Game.Broadcast(self, "Trace : " $ hitActor);
	}

	//If actor based, we take the base instead
	if(validActorFound)
	{
		baseOk=false;
		while(hitActor.Base != none && !baseOk)
		{
			if(GGGoat(hitActor.Base) != gMe)
			{
				if(IsValidActor(hitActor.Base))
				{
					hitActor=hitActor.Base;
				}
				else
				{
					baseOk=true;
				}
			}
			else
			{
				baseOk=true;
			}
		}
	}

	//Grab the actor
	if(validActorFound)
	{
		if(GGNpc(hitActor) != none) GGNpc(hitActor).StandUp();
		if(GGGoat(hitActor) != none) GGGoat(hitActor).StandUp();

		tkItem=hitActor;
		oldPhysics=tkItem.Physics;
		//WorldInfo.Game.Broadcast(self, "oldPhysics : " $ oldPhysics);
		if(GGInterpActor(hitActor) != none)
		{
			tkItem.SetPhysics(PHYS_RigidBody);
		}
		else
		{
			tkItem.SetPhysics(PHYS_None);
		}
		tkItem.SetHardAttach(true);
		AttachItem();
	}

	return validActorFound;
}

function AttachItem()
{
	local vector tkLocation;
	local bool noSocket;

	if(GGInterpActor(tkItem) != none)
		return;

	gMe.mesh.GetSocketWorldLocationAndRotation('Demonic', tkLocation);
	if(IsZero(tkLocation))
	{
		tkLocation=gMe.Location + (Normal(vector(gMe.Rotation)) * (gMe.GetCollisionRadius() + 30.f));
		noSocket=true;
	}

	if(GGPawn(tkItem) != none)
	{
		tkItem.SetLocation(tkLocation);
		tkItem.SetRotation(gMe.Rotation);
	}
	else
	{
		tkItem.CollisionComponent.SetRBPosition(tkLocation);
		tkItem.CollisionComponent.SetRBRotation(gMe.Rotation);
	}

	if(noSocket)
	{
		tkItem.SetBase(gMe);
	}
	else
	{
		tkItem.SetBase(gMe,, gMe.mesh, 'Demonic');
	}
}

function bool IsValidActor(Actor act)
{
	return GGKactor(act) != none || GGPawn(act) != none || GGSVehicle(act) != none || GGInterpActor(act) != none;
}

/*
 * Throw the levitating item in the air
 */
function bool ThrowItem(vector direction)
{
	local Actor oldTkItem;
	local GGKactor kActor;
	local GGPawn gpawn;
	local GGSVehicle vehicle;
	local GGInterpActor interpActor;
	local float mass;

	if(tkItem == none)
		return false;

	oldTkItem=tkItem;

	DropItem();

	kActor = GGKActor( oldTkItem );
	gpawn = GGPawn(oldTkItem);
	interpActor = GGInterpActor( oldTkItem );
	vehicle = GGSVehicle(oldTkItem);
	if(kActor != none)
	{
		mass=kActor.StaticMeshComponent.BodyInstance.GetBodyMass();
		//WorldInfo.Game.Broadcast(self, "Mass : " $ mass);
		kActor.ApplyImpulse( direction >> gMe.Rotation,  mass*2000*gMe.mAttackMomentumMultiplier,  (-direction) >> gMe.Rotation );
	}
	else if(gpawn != none)
	{
		gpawn.AddVelocity((direction >> gMe.Rotation)*2000.0*gMe.mAttackMomentumMultiplier, gpawn.Location, class'GGDamageType');
	}
	else if(interpActor != none)
	{
		//The interp actor just come back to it's animation
	}
	else if(vehicle != none)
	{
		mass=vehicle.Mass;
		vehicle.AddForce((direction >> gMe.Rotation)*mass*2000.0*gMe.mAttackMomentumMultiplier);
	}

	return true;
}

/*
 * Drop the levitating item on the ground
 */
function DropItem()
{
	local vector tkLocation;
	local GGKactor kActor;
	local GGNpc npc;
	local GGSVehicle vehicle;
	local GGGoat goat;
	local GGInterpActor interpActor;
	local GGAIController AIC;

	if(tkItem == none)
		return;

	kActor = GGKActor( tkItem );
	npc = GGNpc(tkItem);
	interpActor = GGInterpActor( tkItem );
	vehicle = GGSVehicle(tkItem);
	goat = GGGoat(tkItem);


	tkItem.SetHardAttach(false);
	tkItem.SetBase(none);
	if(interpActor == none)
	{
		gMe.mesh.GetSocketWorldLocationAndRotation('Demonic', tkLocation);
		if(IsZero(tkLocation))
		{
			tkLocation=gMe.Location + (Normal(vector(gMe.Rotation)) * (gMe.GetCollisionRadius() + 30.f));
		}
		tkItem.SetLocation(tkLocation);
	}

	if(kActor != none)
	{
		kActor.SetPhysics(PHYS_RigidBody);
	}
	else if(npc != none)
	{
		npc.mIsRagdollAllowed=true;
		npc.SetPhysics(PHYS_Falling);
		AIC=GGAIController(npc.Controller);
		AIC.mOriginalPosition=npc.Location;
		if(AIC.IsInState('StartPanic'))
		{
			AIC.ReturnToOriginalPosition();
		}
		AIC.Possess(npc, false);
	}
	else if(interpActor != none)
	{
		tkItem.SetPhysics(oldPhysics);
	}
	else if(vehicle != none)
	{
		vehicle.SetPhysics(PHYS_RigidBody);
	}
	else if(goat != none)
	{
		if(!goat.mIsRagdoll)
		{
			goat.SetPhysics(PHYS_Falling);
		}
	}
	else
	{
		//WorldInfo.Game.Broadcast(self, "WTF : " $ tkItem);
	}
	tkItem=none;
}

defaultproperties
{
	mAngelMaterial=Material'goat.Materials.Goat_Mat_03'
	itsNoUse=SoundCue'TelekineticGoatSounds.ItsNoUseCue'
	takeThis=SoundCue'TelekineticGoatSounds.TakeThisCue'
	howAboutThis=SoundCue'TelekineticGoatSounds.HowAboutThisCue'
}