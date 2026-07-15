AddCSLuaFile()

SWEP.Base = "arc9_snow_halo_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.PrintName = "BR75 - Desert"
SWEP.Category = "ARC9 - Snowy's Halo Extras"
SWEP.SubCategory = "Battle Rifles"
SWEP.Class = "Battle Rifle"
SWEP.Description = "Straight ARC9 conversion of BR75 - Desert. Reuses the original mounted model, material, sound, and HUD assets; no Draconic weapon-base dependency."
SWEP.Slot = 2
SWEP.ViewModel = "models/snowysnowtime/drc/adorabirb/c_desert_rifle.mdl"
SWEP.WorldModel = "models/snowysnowtime/drc/adorabirb/w_br75.mdl"
SWEP.ViewModelFOVBase = 60
SWEP.ViewModelFOV = 60
SWEP.UseHands = true
SWEP.HoldType = "ar2"
SWEP.ActivePos = Vector(0.5, -1, -1)
SWEP.ActiveAng = Angle(2.5, 0, 0)
SWEP.DamageMax = 9
SWEP.DamageMin = 6.3
SWEP.RangeMin = 15
SWEP.RangeMax = 220
SWEP.Penetration = 8
SWEP.Num = 1
SWEP.ClipSize = 36
SWEP.ChamberSize = 1
SWEP.Ammo = "AR2"
SWEP.RPM = 900
SWEP.Firemodes = {{Mode = 3, PrintName = "3-BURST", RunawayBurst = true, PostBurstDelay = 0.18}, {Mode = 1, PrintName = "SEMI"}, {Mode = 0}}
SWEP.ShotgunReload = false
SWEP.Spread = 0.0002
SWEP.SpreadAddHipFire = 0.001
SWEP.SpreadAddMove = 0.0004
SWEP.SpreadAddMidAir = 0.0016
SWEP.SpreadAddRecoil = 0.0002
SWEP.Recoil = 0.36
SWEP.RecoilUp = 0.2
SWEP.RecoilSide = 0.1
SWEP.ShootSound = "weapons/ar2/fire1.wav"
SWEP.DryFireSound = "drc.halo_mag_empty"
SWEP.TracerEffect = "effect_arc9_halo2_tracer_br"
SWEP.TracerColor = Color(255, 210, 120)
SWEP.TracerNum = 1
SWEP.MuzzleParticle = "muzzleflash_1"
SWEP.MuzzleEffectAttachment = 1
SWEP.CaseEffectAttachment = 2
SWEP.BashDamage = 25
SWEP.ShellModel = "models/shells/shell_556.mdl"
SWEP.HasSights = true
SWEP.IronSights = {
    Pos = Vector(2, -5, 0),
    Ang = Angle(0, 0, 0),
    Magnification = 1.4,
    ViewModelFOV = 60,
    CrosshairInSights = false,
    FlatScope = false,
    RTScope = false
}
SWEP.EnterSightsSound = "vuthakral/halo/weapons/br55hb/zoom_in.wav"
SWEP.ExitSightsSound = "vuthakral/halo/weapons/br55hb/zoom_out.wav"
SWEP.Animations = {
    ["idle"] = {Source = ACT_VM_IDLE},
    ["idle_sprint"] = {Source = ACT_VM_IDLE_LOWERED},
    ["draw"] = {Source = ACT_VM_DRAW},
    ["ready"] = {Source = ACT_VM_DRAW},
    ["fire"] = {Source = ACT_VM_PRIMARYATTACK, MinProgress = 0, ShellEjectAt = 0.03},
    ["fire_iron"] = {Source = ACT_VM_PRIMARYATTACK, MinProgress = 0, ShellEjectAt = 0.03},
    ["reload"] = {Source = ACT_VM_RELOAD, MagSwapTime = 0.55},
    ["reload_empty"] = {Source = ACT_VM_RELOAD_EMPTY, MagSwapTime = 0.55},
    ["bash"] = {Source = ACT_VM_HITCENTER}
}

SWEP.HaloCrosshairMaterial = "models/vuthakral/halo/HUD/reticles/ret_br"
SWEP.HaloCrosshairSize = 80.00
SWEP.HaloCrosshairColor = Color(127, 220, 255, 255)
SWEP.HaloOriginalScopeMaterial = "models/vuthakral/halo/HUD/scope_rifle"
SWEP.HaloScoped = true
SWEP.HaloScopeScale = 0.65
SWEP.HaloScopeWidth = 1
SWEP.HaloScopeHeight = 1
