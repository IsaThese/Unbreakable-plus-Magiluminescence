local SpawnPrefab = GLOBAL.SpawnPrefab
local ACTIONS = GLOBAL.ACTIONS

local UNBREAKABLE = GetModConfigData("UNBREAKABLE")
local DURABILITY_LOSS = GetModConfigData("DURABILITY_LOSS")
local TOGGLEABLE = GetModConfigData("TOGGLEABLE")

local SPEED_MULT = 1.2
local TOGGLE_TAG = "toggleable_magiluminescence"

local function RemoveLight(inst)
	if inst._light ~= nil then
		if inst._light:IsValid() then
			inst._light:Remove()
		end
		inst._light = nil
	end
end

local function ClearBloom(inst, owner)
	if owner == nil then
		return
	end
	if owner.components.bloomer ~= nil then
		owner.components.bloomer:PopBloom(inst)
	else
		owner.AnimState:ClearBloomEffectHandle()
	end
end

local function PushBloom(inst, owner)
	if owner.components.bloomer ~= nil then
		owner.components.bloomer:PushBloom(inst, "shaders/anim.ksh", 1)
	else
		owner.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	end
end

local function ShowAmulet(inst, owner)
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("equipskinneditem", inst:GetSkinName())
		owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "torso_amulets")
	else
		owner.AnimState:OverrideSymbol("swap_body", "torso_amulets", "yellowamulet")
	end
end

local function HideAmulet(inst, owner)
	owner.AnimState:ClearOverrideSymbol("swap_body")
	local skin_build = inst:GetSkinBuild()
	if skin_build ~= nil then
		owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	end
end

local function HasFuel(inst)
	return inst.components.fueled == nil or not inst.components.fueled:IsEmpty()
end

local function EnableEffects(inst, owner)
	if owner == nil or not HasFuel(inst) then
		return
	end

	if inst._light == nil or not inst._light:IsValid() then
		inst._light = SpawnPrefab("yellowamuletlight")
	end
	inst._light.entity:SetParent(owner.entity)

	PushBloom(inst, owner)
	inst.components.equippable.walkspeedmult = SPEED_MULT

	if DURABILITY_LOSS and inst.components.fueled ~= nil then
		inst.components.fueled:StartConsuming()
	end
end

local function DisableEffects(inst, owner)
	ClearBloom(inst, owner)
	RemoveLight(inst)

	if inst.components.equippable ~= nil then
		inst.components.equippable.walkspeedmult = nil
	end

	if inst.components.fueled ~= nil then
		inst.components.fueled:StopConsuming()
	end
end

local function IsPoweredOn(inst)
	if not TOGGLEABLE or inst.components.machine == nil then
		return true
	end
	return inst.components.machine:IsOn()
end

local function turnon(inst)
	local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
	if owner ~= nil and inst.components.equippable:IsEquipped() then
		EnableEffects(inst, owner)
	end
	if inst.components.machine ~= nil then
		inst.components.machine.ison = true
	end
end

local function turnoff(inst)
	local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
	DisableEffects(inst, owner)
	if inst.components.machine ~= nil then
		inst.components.machine.ison = false
	end
end

local function onequip(inst, owner)
	ShowAmulet(inst, owner)

	if inst.skin_equip_sound and owner.SoundEmitter then
		owner.SoundEmitter:PlaySound(inst.skin_equip_sound)
	end

	if IsPoweredOn(inst) and HasFuel(inst) then
		EnableEffects(inst, owner)
		if inst.components.machine ~= nil then
			inst.components.machine.ison = true
		end
	else
		DisableEffects(inst, owner)
	end
end

local function onunequip(inst, owner)
	HideAmulet(inst, owner)
	-- Keep machine on/off preference; only clear active effects.
	DisableEffects(inst, owner)
end

local function onequiptomodel(inst, owner, from_ground)
	DisableEffects(inst, owner)
end

-- Original "Unbreakable Magiluminescence": still drains, but does not Remove at 0%.
local function OnDepleted(inst)
	local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
	DisableEffects(inst, owner)

	if owner ~= nil and inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
		owner:PushEvent("torchranout", {
			prefab = inst.prefab,
			equipslot = inst.components.equippable.equipslot,
		})
	end
end

local function OnTakeFuel(inst)
	local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
	if owner ~= nil and inst.components.equippable:IsEquipped() and IsPoweredOn(inst) then
		EnableEffects(inst, owner)
	end
end

local function MakeUnbreakable(inst)
	local fueled = inst.components.fueled
	if fueled == nil then
		return
	end

	fueled:SetDepletedFn(OnDepleted)

	local old_takefuel = fueled.takefuelfn
	fueled:SetTakeFuelFn(function(item)
		if old_takefuel ~= nil then
			old_takefuel(item)
		end
		OnTakeFuel(item)
	end)
end

-- Optional: never consume fuel while active (separate from unbreakable-at-0%).
local function MakeNoDurabilityLoss(inst)
	local fueled = inst.components.fueled
	if fueled == nil then
		return
	end

	fueled.rate_modifiers:SetModifier(modname, 0)
	fueled:StopConsuming()
end

local function MakeToggleable(inst)
	inst:AddTag(TOGGLE_TAG)

	local machine = inst:AddComponent("machine")
	machine.turnonfn = turnon
	machine.turnofffn = turnoff
	machine.cooldowntime = 0
	machine.ison = true
	-- Ensure action UI can see this (machine normally sets these via property setters).
	inst:AddTag("enabled")
	inst:AddTag("turnedon")
end

-- Magician's Top Hat always offers USEMAGICTOOL while equipped (click / Ctrl / RMB).
-- Vanilla machine only offers Turn On/Off on right-click, so the toggle is easy to miss.
-- Register on "machine" so it attaches when we AddComponent("machine") in PostInit.
if TOGGLEABLE then
	AddComponentAction("INVENTORY", "machine", function(inst, doer, actions, right)
		if not inst:HasTag(TOGGLE_TAG) then
			return
		end
		if inst:HasAnyTag("cooldown", "fueldepleted") or not inst:HasTag("enabled") then
			return
		end

		local equippable = inst.replica.equippable
		if equippable == nil or not equippable:IsEquipped() then
			return
		end

		-- RMB is already handled by vanilla machine; avoid duplicate verbs.
		if right then
			return
		end

		-- Left-click / Ctrl hover: always show Turn On or Turn Off while equipped.
		table.insert(actions, inst:HasTag("turnedon") and ACTIONS.TURNOFF or ACTIONS.TURNON)
	end)
end

AddPrefabPostInit("yellowamulet", function(inst)
	if not GLOBAL.TheWorld.ismastersim then
		return
	end

	if UNBREAKABLE then
		MakeUnbreakable(inst)
	end

	if not DURABILITY_LOSS then
		MakeNoDurabilityLoss(inst)
	end

	if TOGGLEABLE then
		MakeToggleable(inst)
	end

	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)
	inst.components.equippable:SetOnEquipToModel(onequiptomodel)
	inst.components.inventoryitem:SetOnDroppedFn(RemoveLight)
	inst.OnRemoveEntity = RemoveLight

	-- Default powered-on when wearing, matching vanilla equip behavior.
	inst.components.equippable.walkspeedmult = SPEED_MULT
end)
