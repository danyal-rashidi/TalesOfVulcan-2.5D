class_name VulcanMoves
# Vulcan's attacks. Unreal's (D:\TalesOfVulkan\TalesOfVulkan\Source\TalesOfVulkan): BossVulcan.cpp's FBossAttack list, its clip times
# turned into real seconds through each attack's RateKeys exactly as ABossVulcan::RealSeconds does (BossVulcanBrain.cpp), cm into m.
# windup: to the blow (StrikeStart); active: the blow (StrikeStart to StrikeEnd); recover: he stands open after it (to EndTime);
# commit: he stops turning after him (CommitAt); turn: deg/s while he does (TurnRate); range: he starts it from this close (StartRange);
# damage and push (m/s) of each blow (one fireball, one burn); poise: what the blow does to poise, damage x2 when heavy (HeavyPoiseScale).
# shake: px the camera shakes as it lands, in phase two only, more for a heavier blow. Claude's call.
# parry: Elvis can turn it aside (a sword or shoulder blow; fire, blasts and the burn can't be). Claude's call.
# A blow is heavy when its push is at least HEAVY_PUSH. Times are phase one's: phase two divides them by VulcanBrain.speed_scale().

const HEAVY_PUSH := 4.5    # FReactionClips::HeavyPush 450 cm/s (CombatReactions.h): this hard doubles him over and shakes the camera

const MOVES: Dictionary = {
	# Slam: arms up and held while the blade grows, the chop, the recovery
	&"slam": {"windup": 0.82, "active": 0.16, "recover": 0.79, "commit": 0.42, "turn": 110.0, "range": 4.2,
		"damage": 28.0, "push": 6.5, "poise": 56.0, "shake": 5, "anim": "slam"},
	# Spell: the arm goes up as the circle turns up; active is the volley: the first ball at 0.2 s, then one every SpellGap 0.3 s, 4 balls, 0.4 s after the last (TickSpell)
	&"spell": {"windup": 0.83, "active": 1.5, "recover": 0.64, "commit": 0.63, "turn": 100.0, "range": 15.0,
		"damage": 10.0, "push": 3.0, "poise": 10.0, "shake": 1, "anim": "spell"},
	# Breath: the clip is held for the breath, 1.2 s here (Fx breath, the plan's; Unreal BreathSeconds 2.4).
	# Claude's call: range 4.8, not Unreal's 6 (that went with its 7 m fire): the plan's 5 m fire from his mouth reaches 5.45 m
	&"breath": {"windup": 0.98, "active": 1.2, "recover": 1.04, "commit": 0.72, "turn": 70.0, "range": 4.8,
		"damage": 9.0, "push": 0.0, "poise": 9.0, "shake": 2, "anim": "breath"},
	# Dive: the held crouch, the leap (active: in the air), the one-knee landing and the rise
	&"dive": {"windup": 1.19, "active": 0.77, "recover": 1.37, "commit": 0.85, "turn": 70.0, "range": 15.0,
		"damage": 30.0, "push": 7.5, "poise": 60.0, "shake": 6, "anim": "dive"},
	# Charge: Unreal has none. Claude's call: a 7 m shoulder rush along his facing at Vulcan.CHARGE_SPEED, a heavy blow, begun from 8 m
	&"charge": {"windup": 0.6, "active": 0.7, "recover": 0.8, "commit": 0.45, "turn": 90.0, "range": 8.0,
		"damage": 20.0, "push": 6.0, "poise": 40.0, "shake": 4, "anim": "charge", "parry": true},
	# Slash: he sets his feet and coils, the sweep across at chest height, open about 0.4 s
	&"slash": {"windup": 0.50, "active": 0.25, "recover": 0.40, "commit": 0.40, "turn": 220.0, "range": 2.3,
		"damage": 13.0, "push": 3.5, "poise": 13.0, "shake": 2, "anim": "slash", "parry": true},
	# Backswing: only ever straight after a slash, cutting back across from where it ended
	&"backswing": {"windup": 0.26, "active": 0.10, "recover": 0.46, "commit": 0.18, "turn": 220.0, "range": 2.6,
		"damage": 13.0, "push": 3.5, "poise": 13.0, "shake": 2, "anim": "backswing", "parry": true},
}
