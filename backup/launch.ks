//================ Launch Script ===================
//
//  This script launches a rocket from the Kerbal Space Center to a circular orbit of the desired height and inclination:
//
//  Suggested first stage atmospheric TWR and second stage vacuum TWR of around 1.25.
//
//  Parameters:
//		targetaltitude	- altitude of target orbit (km)
// 		targetincl 		- inclination of target orbit (deg)
//
//  To run: e.g. runpath("0:/launch.ks,100,0"). to launch to altitude of 100 km in 0 deg orbit.
//
//==================================================

// Define Parameters
parameter targetaltitude.
parameter targetincl.

set targetaltitude to targetaltitude*1000.

//Define Initial Conditions
SAS off.
RCS off.
lights off.
set throttle to 0.
gear off.

// Define Constants
set launchlatitude to LATITUDE.
set launchlongitude to LONGITUDE.
set MUkerbin to BODY:MU/(1000*1000*1000). //km^3/s^2
set Rkerbin to BODY:RADIUS/1000. //km
set Vlaunchsite to VELOCITY:ORBIT:MAG/1000. //kilometers per second

// Set initial values for loops
set apoapsischeck to 0.
set circburnflag to 0.
set gamma to 90.
set steeringlock to 0.
set ejected to 0.

// Reset inclination
if abs(launchlatitude)>abs(targetincl) {set targetincl to launchlatitude.}

// Calculate Launch Azimuth
if targetincl>=0 {set betaI to arcsin(cos(targetincl)/cos(launchlatitude)).}
else if targetincl<0 {set betaI to 180-arcsin(cos(targetincl)/cos(launchlatitude)).}
set Vtargetorbit to sqrt(MUkerbin/(Rkerbin+targetaltitude/1000)). //kilometers per second
if targetincl>=0 {lock beta to arctan((Vtargetorbit*sin(betaI)-Vlaunchsite*cos(launchlatitude))/(Vtargetorbit*abs(cos(betaI)))).}
else if targetincl<0 {lock beta to 180-arctan((Vtargetorbit*sin(betaI)-Vlaunchsite*cos(launchlatitude))/(Vtargetorbit*abs(cos(betaI)))).}
lock flightpathang to 90-VANG(UP:VECTOR,SHIP:PROGRADE:VECTOR).

//Launch Countdown
CLEARSCREEN.
FROM {local countdown is 5.} UNTIL countdown=0 STEP {SET countdown to countdown-1.} DO {
	print "Launch Countdown Initiated" at (0,1).
	print "T-"+countdown.
	wait 1.
	CLEARSCREEN.
}

//Begin Launch Process
print "Launch Process Initiated" at (0,1).
set runmode to 1.
set throt to 1.
lock throttle to throt.
until verticalspeed>1 { //stage through any prelaunch stages
	stage.
	wait 1.
}
print "Launch Status: Liftoff!" at (0,1).

// Initiate Runmode Loop
UNTIL runmode=0 {


	// -------------------- Repeated Code --------------------

	wait 0.1.

	// Telemetry Display
	print "Launching to a " + targetaltitude/1000 + " km circular orbit" at (0,3).
	print "with inclination of " + round(targetincl,3) + " degrees." at (0,4).
	print "Runmode: " + runmode + "  " at (0,6).
	print "Commanded Azimuth (degrees):           " + round(beta,4) at (0,7).
	print "Commanded Flight Path Angle (degrees): " + round(gamma,4) + "      " at (0,8).
	print "Orbital Flight Path Angle (degrees):   " + round(flightpathang,4) at (0,9).
	print "Time to Apoapsis:                      " + round(ETA:APOAPSIS,2) + "s" at (0,11).

	// Lock steering
	if runmode=1 {
		SAS on.
		print " Vertical Lock Active  " at (10,13).
		}
	else if runmode = 2 {
		SAS off.
		lock steering to heading(beta,gamma).
		print " Vertical Lock Active  " at (10,13).
	}
	else if SHIP:altitude > 15000 and abs(ORBIT:inclination-abs(targetincl))<0.01 and steeringlock = 0 {
		lock steering to SHIP:PROGRADE*R(flightpathang-gamma,0,0):VECTOR.
		print "Inclination Lock Active" at (10,13).
		set steeringlock to 1.
	}
	else if steeringlock = 0 {
		lock steering to heading(beta,gamma).
		print "  Azimuth Lock Active  " at (10,13).
	}
	else if steeringlock = 1 {
		lock steering to SHIP:PROGRADE*R(flightpathang-gamma,0,0):VECTOR.
		print "Inclination Lock Active" at (10,13).
	}

	// Automatic Staging
	set should_stage to false.
	set should_stage to (ship:maxthrust = 0).

	list engines in englist.
	for eng in englist {
	  if eng:flameout {
	    set should_stage to true.
	  }
	}

	if should_stage {
	  stage.
		// Wait is needed when using collapsable bell CE-10 and CE-60 cryogenic rocket engines
		wait 5.
	}

	// Run Apoapsis Check
	if ALT:APOAPSIS > targetaltitude*0.95 and apoapsischeck=0 {
		set runmode to 5.
		print "Launch Status: Apoapsis Approach   " at (0,1).
		set apoapsischeck to 1.
	}


	// -------------------- Runmodes -------------------------

	// Leaving the Launchpad
	if runmode=1 {
		set gamma to 90.
		set throt to 1.
		wait 4.
		set runmode to 2.
		print "Launch Status: Vertical Ascent" at (0,1).
	}

	// Vertical Ascent to 500m
	else if runmode=2 {
		set gamma to 90.
		set throt to 1.
		if SHIP:ALTITUDE >500{
			set runmode to 3.
			print "Launch Status: Gravity Turn   " at (0,1).
		}
	}

	// Gravity Turn from 500m to 65km
	else if runmode=3 {
		set gamma to 8.75513e-9*(SHIP:ALTITUDE)^2-0.0019223*(SHIP:ALTITUDE)+90.95896.
		set TWR to 2.5. // Default 1.6
		set throt to (MASS*9.81*TWR)/max(0.01,MAXTHRUST).
		if SHIP:ALTITUDE>65000{
			RCS on.
			set runmode to 4.
			print "Launch Status: Thrust to Apoapsis" at (0,1).
		}
	}

	// Prograde Thrust to Raise Apoapsis
	else if runmode=4 {
		set gamma to 3.
		set TWR to 2.5. // default 1.5
		set throt to (MASS*9.81*TWR)/max(0.01,MAXTHRUST).
	}

	// Apoapsis Approach
	else if runmode=5 {
		set gamma to 1.
		set TWR to 0.75.
		set throt to min(1,(MASS*9.81*TWR)/max(0.01,MAXTHRUST)).
		if ALT:APOAPSIS > targetaltitude*0.990 {
			set runmode to 10.
			print "Launch Status: Circularization     " at (0,1).
		}
	}

	// Circularization Burn
	else if runmode=6 {
		RCS on.
		set gamma to 0.

		// First circularization burn increases periapsis above sea level
		if circburnflag = 0 {
			if ALT:PERIAPSIS > 0 { //cut throttle and wait when periapsis increases above sea level
				set circburnflag to 1.
				set runmode to 10.
			}
			else {
//			set TWR to 1.
			set throt to 1. //min(1,(MASS*9.81*TWR)/max(0.01,MAXTHRUST)).
			}
		}

		// Second circularization burn fully circularizes orbit
		else if circburnflag = 1 {
			RCS on.
			if ALT:PERIAPSIS >= targetaltitude - 1 { //*0.999 or ALT:APOAPSIS > 1.01*targetaltitude {
				set circburnflag to 3.
				set throt to 0.
				set pilotmainthrottle to 0.
				set runmode to 0.
			}
			else {
			set TWR to 0.75.
			set throt to min(1,(MASS*9.81*TWR)/max(0.01,MAXTHRUST)).
			}
		}
	}

	// Wait call with warping
	else if runmode=10 {
		set throt to 0.
		if SHIP:ALTITUDE > 70000 and ejected = 0 {
			AG5 on. // Activate Action Group 5: Deploy fairings, and fire off escape launch tower.
			LIGHTS on. // Activate vessel lights
			wait 5.
			set ejected to 1.
		}
		if SHIP:ALTITUDE > 70000 and ETA:APOAPSIS > 30 {
				WARPTO(TIME:SECONDS + ETA:APOAPSIS - 30).
		}
		if VERTICALSPEED < 0 {
			set runmode to 6.
		}
		else if circburnflag = 0 and ETA:APOAPSIS < 30 {
			RCS off.
			set warp to 0.
			set runmode to 6.
		}
		else if circburnflag = 1 and ETA:APOAPSIS < 5 {
			RCS off.
			set warp to 0.
			set runmode to 6.
		}
	}
}

// Enable RSC and SCS and AG1.
RCS off.
SAS on.
AG1 on. // Custom Action group call (open Universal Storage 2 adapter with solar cell)
AG2 on. // Custom Action group call -  Extend/unfold antenna's

// Completion dialog and countdown to unlock program
CLEARSCREEN.

print "Launch Complete!" at (0,1).
print "Stability Assist System activated." at (0,3).
print "Reaction Control System is disabled." at (0,4).
print "Welcome to orbit at " + targetaltitude / 1000 + " Km." at (0,6).
print "Thank you for using this Rhysode Space Initiative product!" at (0, 12).

FROM {local countdownrelease is 5.} UNTIL countdownrelease=0 STEP {SET countdownrelease to countdownrelease-1.} DO {
	print "Releasing command in T- " + countdownrelease + " seconds..." at (0,10).
	wait 1.
}

UNLOCK ALL.

// End script
