#include "VehicleCommon.as"
#include "Hitters.as"
#include "ThrowCommon.as"

// Boat logic

void onInit(CBlob@ this)
{
	Vehicle_Setup(this,
	              47.0f, // move speed
	              0.19f,  // turn speed
	              Vec2f(0.0f, -5.0f), // jump out velocity
	              true  // inventory access
	             );
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;
	
	Vehicle_SetupAirship(this, v, -350.0f);

	this.SetLight(true);
	this.SetLightRadius(48.0f);
	this.SetLightColor(SColor(255, 255, 240, 171));

	this.set_f32("map dmg modifier", 35.0f);

	//this.getShape().SetOffset(Vec2f(0,0));
	//this.getShape().getConsts().bullet = true;
	//this.getShape().getConsts().transports = true;
}

void onTick(CBlob@ this)
{
	if (this.hasAttached() || this.getTickSinceCreated() < 30)
	{
		if (this.getHealth() > 1.0f)
		{
			HandleBombing(this);

			VehicleInfo@ v;
			if (!this.get("VehicleInfo", @v)) return;
			
			Vehicle_StandardControls(this, v);

			//TODO: move to atmosphere damage script
			/*f32 y = this.getPosition().y;
			if (y < 100)
			{
				if (getGameTime() % 15 == 0)
					this.server_Hit(this, this.getPosition(), Vec2f(0, 0), y < 50 ? (y < 0 ? 2.0f : 1.0f) : 0.25f, 0, true);
			}*/
		}
		else
		{
			this.server_DetachAll();
			this.setAngleDegrees(this.getAngleDegrees() + (this.isFacingLeft() ? 1 : -1));
			if (this.isOnGround() || this.isInWater())
			{
				this.server_SetHealth(-1.0f);
				this.server_Die();
			}
			else
			{
				//TODO: effects
				if (getGameTime() % 30 == 0)
					this.server_Hit(this, this.getPosition(), Vec2f(0, 0), 0.05f, 0, true);
			}
		}
	}
}

void HandleBombing(CBlob@ this)
{
	AttachmentPoint@ driverSeat = this.getAttachments().getAttachmentPointByName("FLYER");
	if (driverSeat is null) return;
	
	CBlob@ flyer = driverSeat.getOccupied();
	if (flyer is null) return;

	if (driverSeat.isKeyPressed(key_action3) && this.get_u32("lastDropTime") < getGameTime())
	{
		CInventory@ inv = this.getInventory();
		if (inv !is null && inv.getItemsCount() > 0)
		{
			this.getSprite().PlaySound("bridge_open", 1.0f, 1.0f);

			if (isServer())
			{
				CBlob@ item = inv.getItem(0);
				if (item.getName() == "mat_bombs")
				{
					CBlob@ blob = server_CreateBlob("bomb", this.getTeamNum(), this.getPosition() + Vec2f(0, 12));
					if (blob !is null)
					{
						item.server_Die();
					}
				}
				else
				{
					this.server_PutOutInventory(item);
					item.setPosition(this.getPosition() + Vec2f(0, 12));
					if (item.hasTag("activatable"))
					{
						server_ActivateCommand(this, item);
					}
				}
			}

			this.set_u32("lastDropTime", getGameTime() + 30);
		}
	}
}

void Vehicle_onFire(CBlob@ this, VehicleInfo@ v, CBlob@ bullet, const u8 charge) {}
bool Vehicle_canFire(CBlob@ this, VehicleInfo@ v, bool isActionPressed, bool wasActionPressed, u8 &out chargeValue) {return false;}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return Vehicle_doesCollideWithBlob_ground(this, blob);
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint @attachedPoint)
{
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;
	
	Vehicle_onAttach(this, v, attached, attachedPoint);
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ attachedPoint)
{
	VehicleInfo@ v;
	if (!this.get("VehicleInfo", @v)) return;
	
	Vehicle_onDetach(this, v, detached, attachedPoint);
}


// SPRITE

void onInit(CSprite@ this)
{
	this.SetZ(-50.0f);
	this.getCurrentScript().tickFrequency = 5;
	
	// add balloon

	CSpriteLayer@ balloon = this.addSpriteLayer("balloon", "Balloon.png", 48, 64);
	if (balloon !is null)
	{
		balloon.addAnimation("default", 0, false);
		int[] frames = { 0, 2, 3 };
		balloon.animation.AddFrames(frames);
		balloon.SetRelativeZ(1.0f);
		balloon.SetOffset(Vec2f(0.0f, -26.0f));
	}

	CSpriteLayer@ background = this.addSpriteLayer("background", "Balloon.png", 32, 16);
	if (background !is null)
	{
		background.addAnimation("default", 0, false);
		int[] frames = { 3 };
		background.animation.AddFrames(frames);
		background.SetRelativeZ(-5.0f);
		background.SetOffset(Vec2f(0.0f, -5.0f));
	}

	CSpriteLayer@ burner = this.addSpriteLayer("burner", "Balloon.png", 8, 16);
	if (burner !is null)
	{
		{
			Animation@ a = burner.addAnimation("default", 3, true);
			int[] frames = { 41, 42, 43 };
			a.AddFrames(frames);
		}
		{
			Animation@ a = burner.addAnimation("up", 3, true);
			int[] frames = { 38, 39, 40 };
			a.AddFrames(frames);
		}
		{
			Animation@ a = burner.addAnimation("down", 3, true);
			int[] frames = { 44, 45, 44, 46 };
			a.AddFrames(frames);
		}
		burner.SetRelativeZ(1.5f);
		burner.SetOffset(Vec2f(0.0f, -26.0f));
	}
}

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();
	f32 ratio = 1.0f - (blob.getHealth() / blob.getInitialHealth());
	this.animation.setFrameFromRatio(ratio);

	CSpriteLayer@ balloon = this.getSpriteLayer("balloon");
	if (balloon !is null)
	{
		if (blob.getHealth() > 1.0f)
			balloon.animation.frame = Maths::Min((ratio) * 3, 1.0f);
		else
			balloon.animation.frame = 2;
	}

	CSpriteLayer@ burner = this.getSpriteLayer("burner");
	if (burner !is null)
	{
		burner.SetOffset(Vec2f(0.0f, -14.0f));
		s8 dir = blob.get_s8("move_direction");
		if (dir == 0)
		{
			blob.SetLightColor(SColor(255, 255, 240, 171));
			burner.SetAnimation("default");
		}
		else if (dir < 0)
		{
			blob.SetLightColor(SColor(255, 255, 240, 200));
			burner.SetAnimation("up");
		}
		else if (dir > 0)
		{
			blob.SetLightColor(SColor(255, 255, 200, 171));
			burner.SetAnimation("down");
		}
	}
}
