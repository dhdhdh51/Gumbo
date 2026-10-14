"""Build assets/data/exercises.json.

Every instruction, mistake and safety note is written for this app in plain
language. Nothing is copied from a book, website or video, and no media files
are referenced, so the app hides the media area for every exercise.
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets/data/exercises.json"

# Default sets, reps and rest per goal. For loadType "timed" the rep numbers
# are seconds per set. Heavier compound lifts get longer rest and lower reps on
# a Gain goal; a Lose goal keeps reps higher and rest shorter to hold density up.
SCHEMES = {
    "compound_heavy": {
        "gain": (4, 6, 10, 120), "lose": (3, 10, 15, 60), "maintain": (3, 8, 12, 90)},
    "compound_med": {
        "gain": (4, 8, 12, 90), "lose": (3, 12, 15, 60), "maintain": (3, 10, 12, 75)},
    "bw_compound": {
        "gain": (4, 8, 15, 90), "lose": (3, 12, 20, 45), "maintain": (3, 10, 15, 60)},
    "bw_hard": {
        "gain": (4, 6, 10, 120), "lose": (3, 8, 12, 60), "maintain": (3, 6, 10, 90)},
    "isolation": {
        "gain": (3, 10, 12, 60), "lose": (3, 12, 20, 45), "maintain": (3, 10, 15, 60)},
    "isolation_light": {
        "gain": (3, 12, 15, 75), "lose": (3, 15, 20, 45), "maintain": (3, 12, 15, 60)},
    "core_timed": {
        "gain": (3, 30, 45, 45), "lose": (3, 30, 60, 30), "maintain": (3, 30, 45, 40)},
    "core_reps": {
        "gain": (3, 10, 15, 45), "lose": (3, 15, 25, 30), "maintain": (3, 12, 20, 40)},
    "conditioning": {
        "gain": (3, 30, 45, 60), "lose": (4, 40, 60, 30), "maintain": (3, 30, 60, 45)},
    "conditioning_reps": {
        "gain": (3, 12, 20, 60), "lose": (4, 15, 25, 45), "maintain": (3, 12, 20, 60)},
    "carry_timed": {
        "gain": (3, 30, 45, 60), "lose": (3, 40, 60, 45), "maintain": (3, 30, 60, 60)},
    "cardio_steady": {
        "gain": (1, 600, 1200, 0), "lose": (1, 1200, 1800, 0), "maintain": (1, 900, 1800, 0)},
    "balance_timed": {
        "gain": (3, 20, 30, 30), "lose": (3, 20, 30, 30), "maintain": (3, 20, 30, 30)},
}

# Schemes whose repsMin/repsMax are seconds per set rather than repetitions.
# This is independent of how the exercise is loaded: a farmer walk is both
# externally loaded and measured in seconds.
SECOND_BASED_SCHEMES = {
    "core_timed", "balance_timed", "conditioning", "carry_timed", "cardio_steady",
}

EX = []


def ex(eid, name, primary, secondary, equipment, detail, difficulty, pattern,
       compound, load, low_impact, scheme, steps, mistakes, safety):
    assert scheme in SCHEMES, scheme
    defaults = {}
    for goal, (s, lo, hi, rest) in SCHEMES[scheme].items():
        defaults[goal] = {"sets": s, "repsMin": lo, "repsMax": hi, "restSec": rest}
    EX.append({
        "id": eid,
        "repUnit": "seconds" if scheme in SECOND_BASED_SCHEMES else "reps",
        "name": name,
        "primaryMuscles": primary,
        "secondaryMuscles": secondary,
        "equipment": equipment,
        "equipmentDetail": detail,
        "difficulty": difficulty,
        "pattern": pattern,
        "isCompound": compound,
        "loadType": load,
        "lowImpact": low_impact,
        "defaults": defaults,
        "steps": steps,
        "mistakes": mistakes,
        "safety": safety,
    })


# ---------------------------------------------------------------- chest
ex("barbell_bench_press", "Barbell Bench Press", ["chest"], ["triceps", "shoulders"],
   "gym", "Barbell, flat bench and a rack", "intermediate", "horizontal_push",
   True, "external", False, "compound_heavy",
   ["Lie flat on the bench with your eyes roughly under the bar, feet planted and hips in contact with the bench.",
    "Grip the bar a little wider than your shoulders and squeeze your shoulder blades back and down into the bench.",
    "Unrack the bar, then lower it under control until it lightly touches the middle of your chest.",
    "Drive the bar back up until your elbows are straight, keeping your wrists stacked over your elbows."],
   ["Bouncing the bar off the chest instead of controlling the lowering phase.",
    "Letting the elbows flare straight out to the sides, which loads the shoulder joint heavily.",
    "Lifting the hips off the bench to push through a weight that is too heavy."],
   ["Always use safety pins or a spotter when you work close to your limit.",
    "Keep the bar path over your chest, never over your throat or face.",
    "Stop the set if you feel a pinch at the front of the shoulder."])

ex("incline_barbell_bench_press", "Incline Barbell Bench Press", ["chest"], ["shoulders", "triceps"],
   "gym", "Barbell and an incline bench", "intermediate", "horizontal_push",
   True, "external", False, "compound_heavy",
   ["Set the bench to a modest incline, roughly thirty degrees, and sit back with your shoulder blades pinned.",
    "Take a grip slightly wider than shoulder width and unrack the bar over your upper chest.",
    "Lower the bar to just below your collarbones, keeping your elbows under the bar.",
    "Press up and slightly back until your arms are straight, without shrugging towards your ears."],
   ["Setting the bench too upright, which turns the lift into a shoulder press.",
    "Letting the bar drift down towards the belly, which shortens the range the chest works through."],
   ["Keep the incline shallow if your shoulders feel tight.",
    "Use a spotter or safety pins for heavy sets."])

ex("dumbbell_bench_press", "Dumbbell Bench Press", ["chest"], ["triceps", "shoulders"],
   "home", "Pair of dumbbells and a flat bench, or the floor", "beginner", "horizontal_push",
   True, "external", False, "compound_med",
   ["Sit on the end of the bench with a dumbbell on each thigh, then lie back and bring them to your shoulders.",
    "Set your feet, press your shoulder blades into the bench and start with both dumbbells above your chest.",
    "Lower them out and down until your upper arms are about level with your torso.",
    "Press both dumbbells back up and slightly together without letting them clash."],
   ["Dropping the elbows far below the body, which stretches the shoulder joint more than the chest.",
    "Letting one arm lag behind the other through the set."],
   ["Lower the dumbbells to your thighs before sitting up at the end of a set, never drop them beside you.",
    "If you work on the floor instead of a bench the range is shorter, and that is fine."])

ex("incline_dumbbell_press", "Incline Dumbbell Press", ["chest"], ["shoulders", "triceps"],
   "home", "Pair of dumbbells and an adjustable bench", "beginner", "horizontal_push",
   True, "external", False, "compound_med",
   ["Set the bench to a shallow incline and sit back with a dumbbell in each hand at shoulder height.",
    "Keep your wrists firm and your elbows at roughly forty-five degrees from your body.",
    "Press both dumbbells up until your arms are straight above your upper chest.",
    "Lower them under control over two to three seconds and repeat."],
   ["Arching the lower back hard off the bench to get extra drive.",
    "Rushing the lowering phase, which wastes most of the work in the set."],
   ["Pick a weight you can control for the full set, not just the first rep.",
    "Keep the dumbbells over your chest rather than over your face."])

ex("dumbbell_fly", "Dumbbell Fly", ["chest"], ["shoulders"],
   "home", "Pair of light dumbbells and a bench", "intermediate", "horizontal_push",
   False, "external", False, "isolation",
   ["Lie on a flat bench holding a light dumbbell in each hand above your chest, palms facing each other.",
    "Keep a soft, fixed bend in your elbows throughout the movement.",
    "Open your arms out to the sides in a wide arc until you feel a gentle stretch across the chest.",
    "Bring the dumbbells back together along the same arc, squeezing your chest at the top."],
   ["Using heavy dumbbells and turning the fly into a sloppy press.",
    "Straightening and locking the elbows, which puts all the strain on the elbow joint."],
   ["This movement needs light weight and slow control, not load.",
    "Stop the stretch well before any sharp pull at the front of the shoulder."])

ex("cable_crossover", "Cable Crossover", ["chest"], ["shoulders"],
   "gym", "Dual cable stack with D-handles", "intermediate", "horizontal_push",
   False, "external", False, "isolation",
   ["Set both pulleys above head height and take a handle in each hand.",
    "Step forward into a staggered stance so there is tension on the cables before you start.",
    "With a soft bend in the elbows, bring both handles down and together in front of your hips.",
    "Let the cables draw your arms back out slowly until you feel the chest stretch, then repeat."],
   ["Standing too far back so the cables yank the shoulders at the start of each rep.",
    "Bending and straightening the elbows, which turns the movement into a pressdown."],
   ["Keep your torso upright and your ribs down rather than leaning further and further forward.",
    "Control the return; do not let the stack pull your arms back fast."])

ex("machine_chest_press", "Machine Chest Press", ["chest"], ["triceps", "shoulders"],
   "gym", "Seated chest press machine", "beginner", "horizontal_push",
   True, "external", True, "compound_med",
   ["Adjust the seat so the handles sit level with the middle of your chest.",
    "Sit back with your whole back against the pad and your feet flat on the floor.",
    "Press the handles forward until your arms are almost straight, keeping a slight bend at the elbow.",
    "Return slowly until your hands are back beside your chest."],
   ["Setting the seat too low or too high, which forces the shoulders into an awkward angle.",
    "Slamming the weight stack back down at the end of each rep."],
   ["A machine is a good choice when you are new, training alone, or coming back after a break.",
    "Keep your head and back against the pad rather than craning forward."])

ex("push_up", "Push-Up", ["chest"], ["triceps", "shoulders", "core"],
   "bodyweight", "None", "beginner", "horizontal_push",
   True, "bodyweight", False, "bw_compound",
   ["Start in a high plank with your hands under your shoulders and your body in one straight line.",
    "Brace your stomach and squeeze your glutes so your hips do not sag or pike up.",
    "Bend your elbows and lower your chest towards the floor, keeping your elbows at about forty-five degrees.",
    "Press the floor away until your arms are straight again."],
   ["Letting the hips drop so the lower back takes the load.",
    "Dipping only the head towards the floor while the chest barely moves.",
    "Flaring the elbows straight out to the sides."],
   ["If full push-ups are too hard, raise your hands onto a step or sturdy table rather than rushing them.",
    "Keep your neck in line with your spine, looking slightly ahead of your hands."])

ex("incline_push_up", "Incline Push-Up", ["chest"], ["triceps", "shoulders", "core"],
   "bodyweight", "A step, chair or sturdy table", "beginner", "horizontal_push",
   True, "bodyweight", True, "bw_compound",
   ["Place your hands on a stable raised surface, a little wider than your shoulders.",
    "Walk your feet back until your body forms one straight line from head to heels.",
    "Lower your chest towards the surface with your elbows tracking back and slightly out.",
    "Press back up to straight arms."],
   ["Using a surface that can slide or tip.",
    "Letting the hips sag as the set gets hard."],
   ["The higher the surface, the easier the exercise, so raise your hands further if form breaks down.",
    "This is a good starting point if you are new to training or returning after a break."])

ex("decline_push_up", "Decline Push-Up", ["chest"], ["shoulders", "triceps", "core"],
   "bodyweight", "A step or low chair for your feet", "intermediate", "horizontal_push",
   True, "bodyweight", False, "bw_hard",
   ["Put your feet on a step and your hands on the floor under your shoulders.",
    "Brace hard so your hips stay level with your shoulders and heels.",
    "Lower your chest to the floor with control.",
    "Press back up without letting your hips rise first."],
   ["Raising the feet so high that the movement becomes a shoulder press.",
    "Losing the brace so the lower back arches."],
   ["Build up from standard push-ups before adding a decline.",
    "Keep the step low and stable."])

ex("chest_dip", "Chest Dip", ["chest"], ["triceps", "shoulders"],
   "bodyweight", "Parallel bars or a dip station", "advanced", "horizontal_push",
   True, "bodyweight", False, "bw_hard",
   ["Grip the parallel bars and press up to support yourself with straight arms.",
    "Lean your torso forward slightly and let your feet stay behind you.",
    "Bend your elbows and lower until your upper arms are about level with the bars.",
    "Press back up to the start, keeping the forward lean."],
   ["Dropping far below a comfortable depth, which strains the front of the shoulder.",
    "Bouncing at the bottom instead of pausing briefly and pressing."],
   ["Skip this exercise if you have any shoulder pain and use a machine press instead.",
    "Use an assisted dip machine or a band under your knees while you build strength."])

ex("band_chest_press", "Resistance Band Chest Press", ["chest"], ["triceps", "shoulders"],
   "home", "Long resistance band and a fixed anchor behind you", "beginner", "horizontal_push",
   True, "external", True, "isolation_light",
   ["Anchor the band at chest height behind you and hold an end in each hand.",
    "Step forward until the band is already under light tension, in a staggered stance.",
    "Press both hands forward and slightly together until your arms are straight.",
    "Return slowly, resisting the pull of the band all the way back."],
   ["Letting the band snap your hands back instead of controlling the return.",
    "Anchoring the band to something that can come loose."],
   ["Check the band for nicks and tears before every session.",
    "Never let a stretched band point at your face."])

# ---------------------------------------------------------------- back
ex("conventional_deadlift", "Conventional Deadlift", ["back", "glutes", "hamstrings"],
   ["lower_back", "traps", "quads", "forearms"],
   "gym", "Barbell and plates", "advanced", "hinge",
   True, "external", False, "compound_heavy",
   ["Stand with the bar over your mid-foot, feet about hip width apart.",
    "Push your hips back, take a shoulder-width grip and let your shins come lightly to the bar.",
    "Set your chest tall, flatten your back and take the slack out of the bar before you pull.",
    "Drive through the floor with your legs and stand tall, then lower the bar along the same path."],
   ["Rounding the lower back as the bar leaves the floor.",
    "Jerking the bar off the floor instead of taking the slack out first.",
    "Leaning back and over-extending at the top."],
   ["Leave this lift out entirely if you have any back injury until a doctor clears you.",
    "Start light and add weight only while your back stays flat.",
    "Reset your position between reps rather than bouncing the plates."])

ex("rack_pull", "Rack Pull", ["back", "traps"], ["glutes", "hamstrings", "forearms"],
   "gym", "Barbell set on rack pins at knee height", "intermediate", "hinge",
   True, "external", False, "compound_heavy",
   ["Set the bar on the pins at about knee height and stand with it over your mid-foot.",
    "Hinge at the hips, grip the bar at shoulder width and set a flat back.",
    "Drive your hips forward and stand tall, pulling your shoulders back at the top.",
    "Lower the bar back to the pins under control."],
   ["Shrugging the bar up with the arms instead of driving the hips.",
    "Letting the bar drift away from the thighs."],
   ["This is a shorter-range option when a full deadlift bothers your back.",
    "Keep the pins at or just below knee height."])

ex("barbell_row", "Barbell Row", ["back", "lats"], ["biceps", "rear_delts", "lower_back"],
   "gym", "Barbell and plates", "intermediate", "horizontal_pull",
   True, "external", False, "compound_heavy",
   ["Hold the bar at shoulder width and hinge forward until your torso is at roughly forty-five degrees.",
    "Let the bar hang with straight arms and set a flat back with your core braced.",
    "Pull the bar towards your lower ribs, leading with your elbows.",
    "Lower it under control until your arms are straight again."],
   ["Standing up a little more on every rep until you are almost upright.",
    "Using the lower back to heave the bar instead of rowing with the back muscles.",
    "Pulling the bar to the chest, which turns the movement into an upright row."],
   ["Keep the torso angle fixed for the whole set.",
    "Drop the weight if your lower back starts to round."])

ex("dumbbell_row", "Single-Arm Dumbbell Row", ["back", "lats"], ["biceps", "rear_delts"],
   "home", "One dumbbell and a bench or chair", "beginner", "horizontal_pull",
   True, "external", True, "compound_med",
   ["Put one hand and the same-side knee on a bench so your back is flat and roughly horizontal.",
    "Hold the dumbbell in the other hand with your arm hanging straight down.",
    "Pull the dumbbell up towards your hip, keeping your elbow close to your side.",
    "Lower it all the way down and repeat, then change sides."],
   ["Twisting the torso to swing the weight up.",
    "Pulling with the arm only while the shoulder blade never moves."],
   ["Keep your neck relaxed and in line with your spine.",
    "Support yourself properly so the lower back is not holding you up."])

ex("t_bar_row", "T-Bar Row", ["back", "lats"], ["biceps", "rear_delts"],
   "gym", "T-bar row station or a barbell in a landmine", "intermediate", "horizontal_pull",
   True, "external", False, "compound_med",
   ["Straddle the bar and take the handles with a flat back and braced core.",
    "Hinge forward so your torso is around forty-five degrees.",
    "Row the handles into your lower ribs, squeezing your shoulder blades together.",
    "Lower slowly until your arms are straight."],
   ["Jerking the torso upright on each rep.",
    "Cutting the range short so the weight never reaches the body."],
   ["Keep the chest supported if the station has a pad.",
    "Stop if you feel strain in the lower back."])

ex("lat_pulldown", "Lat Pulldown", ["lats", "back"], ["biceps", "rear_delts"],
   "gym", "Cable pulldown machine", "beginner", "vertical_pull",
   True, "external", True, "compound_med",
   ["Set the thigh pad so you stay seated, and take a grip a little wider than your shoulders.",
    "Sit tall, lean back very slightly and pull your shoulder blades down.",
    "Draw the bar down to your upper chest, leading with the elbows.",
    "Let the bar rise back up slowly until your arms are straight and your shoulders lift a little."],
   ["Leaning far back and using body weight to swing the bar down.",
    "Pulling the bar behind the neck, which puts the shoulders in a vulnerable position."],
   ["Pull to the front of the chest, never behind the head.",
    "Keep the movement smooth in both directions."])

ex("seated_cable_row", "Seated Cable Row", ["back"], ["lats", "biceps", "rear_delts"],
   "gym", "Low cable row station", "beginner", "horizontal_pull",
   True, "external", True, "compound_med",
   ["Sit with your feet on the platform and a slight bend in the knees.",
    "Hold the handle with straight arms and sit tall with your chest up.",
    "Pull the handle to your stomach, bringing your shoulder blades together.",
    "Let your arms straighten slowly, keeping your torso upright."],
   ["Rocking the torso back and forth to move the weight.",
    "Rounding the back as the arms straighten at the end of the rep."],
   ["Keep a small knee bend so the hamstrings are not pulled tight.",
    "Move from the shoulder blades, not the lower back."])

ex("pull_up", "Pull-Up", ["lats", "back"], ["biceps", "forearms", "core"],
   "bodyweight", "A pull-up bar", "advanced", "vertical_pull",
   True, "bodyweight", False, "bw_hard",
   ["Hang from the bar with an overhand grip a little wider than your shoulders.",
    "Pull your shoulder blades down and brace your stomach so you do not swing.",
    "Pull yourself up until your chin clears the bar.",
    "Lower yourself all the way down under control."],
   ["Kicking the legs to generate momentum.",
    "Stopping halfway up rep after rep.",
    "Dropping fast from the top instead of lowering."],
   ["Use a band under your knees or an assisted machine while you build strength.",
    "If your shoulders or elbows hurt, switch to lat pulldowns or inverted rows."])

ex("chin_up", "Chin-Up", ["lats", "biceps"], ["back", "forearms", "core"],
   "bodyweight", "A pull-up bar", "advanced", "vertical_pull",
   True, "bodyweight", False, "bw_hard",
   ["Hang from the bar with an underhand grip at about shoulder width.",
    "Set your shoulder blades down and brace your core.",
    "Pull up until your chin passes the bar, keeping your elbows close to your body.",
    "Lower all the way back to a full hang."],
   ["Swinging the hips to help the pull.",
    "Shrugging the shoulders up towards the ears at the top."],
   ["Build up with band-assisted reps or slow lowering first.",
    "Stop if you feel elbow pain on the inside of the joint."])

ex("inverted_row", "Inverted Row", ["back"], ["lats", "biceps", "core"],
   "home", "A low bar, sturdy table edge or suspension straps", "beginner", "horizontal_pull",
   True, "bodyweight", True, "bw_compound",
   ["Set a bar at about hip height and lie underneath it.",
    "Take an overhand grip a little wider than your shoulders and hang with straight arms.",
    "Keep your body in one line from head to heels and pull your chest to the bar.",
    "Lower yourself slowly until your arms are straight."],
   ["Letting the hips sag so the body bends in the middle.",
    "Shortening the range so the chest never reaches the bar."],
   ["Walking your feet further forward makes it harder; bending your knees makes it easier.",
    "Make sure whatever you hang from cannot tip or slide."])

ex("straight_arm_pulldown", "Straight-Arm Pulldown", ["lats"], ["core", "triceps"],
   "gym", "Cable stack with a straight bar or rope", "intermediate", "vertical_pull",
   False, "external", True, "isolation",
   ["Stand facing a high pulley and hold the bar with straight arms at head height.",
    "Hinge forward very slightly and brace your stomach.",
    "Keeping your elbows straight, sweep the bar down in an arc to your thighs.",
    "Let the bar travel back up slowly to the start."],
   ["Bending the elbows and turning the movement into a pressdown.",
    "Using so much weight that the torso rocks on every rep."],
   ["Keep the weight light enough to feel the lats rather than the arms.",
    "Hold your ribs down so the lower back does not arch."])

ex("face_pull", "Face Pull", ["rear_delts"], ["traps", "back"],
   "gym", "Cable stack with a rope attachment", "beginner", "horizontal_pull",
   False, "external", True, "isolation_light",
   ["Set the pulley at around face height and hold the rope ends with your thumbs facing back.",
    "Step back until the cable is under tension and stand tall.",
    "Pull the rope towards your face, spreading your hands apart as you go.",
    "Return slowly, keeping your shoulders down."],
   ["Shrugging the shoulders up to the ears during the pull.",
    "Using heavy weight so the torso leans back on every rep."],
   ["This is a useful balance exercise if you do a lot of pressing.",
    "Keep it light and smooth."])

ex("band_row", "Resistance Band Row", ["back"], ["lats", "biceps", "rear_delts"],
   "home", "Resistance band anchored in front of you", "beginner", "horizontal_pull",
   True, "external", True, "isolation_light",
   ["Anchor the band at chest height and hold an end in each hand, arms straight.",
    "Step back until there is light tension and stand tall with a braced core.",
    "Pull both hands towards your lower ribs, squeezing your shoulder blades together.",
    "Straighten your arms slowly against the pull of the band."],
   ["Leaning back to create tension instead of stepping back first.",
    "Letting the band drag the arms forward quickly."],
   ["Inspect the band before use and keep the anchor secure.",
    "Keep your wrists in line with your forearms."])

ex("back_extension", "Back Extension", ["lower_back"], ["glutes", "hamstrings"],
   "gym", "Back extension bench", "beginner", "hinge",
   False, "bodyweight", True, "core_reps",
   ["Set the pad just below your hip bones and cross your arms over your chest.",
    "Hinge forward from the hips with a flat back until you feel a stretch in the hamstrings.",
    "Squeeze your glutes and raise your torso until it is in line with your legs.",
    "Pause briefly at the top and lower under control."],
   ["Swinging up past a straight line and over-arching the lower back.",
    "Rounding and unrolling the spine instead of hinging at the hips."],
   ["Stop at a straight body line; there is no benefit to going higher.",
    "Skip this if you have a back injury until a doctor clears you."])

ex("superman", "Superman Hold", ["lower_back"], ["glutes", "shoulders"],
   "bodyweight", "None", "beginner", "core",
   False, "bodyweight", True, "core_timed",
   ["Lie face down with your arms stretched out in front of you.",
    "Press your hips into the floor and lengthen through the spine.",
    "Lift your arms, chest and legs a small distance off the floor.",
    "Hold, breathing steadily, then lower slowly."],
   ["Lifting as high as possible and cranking the lower back.",
    "Holding the breath through the whole set."],
   ["A small lift is enough; height is not the goal.",
    "Stop if you feel any pinching in the lower back."])

# ---------------------------------------------------------------- shoulders
ex("overhead_barbell_press", "Overhead Barbell Press", ["shoulders"], ["triceps", "core", "traps"],
   "gym", "Barbell and a rack", "intermediate", "vertical_push",
   True, "external", False, "compound_heavy",
   ["Take the bar at shoulder width, resting on the front of your shoulders.",
    "Stand tall with your feet hip width apart, ribs down and core braced.",
    "Press the bar straight overhead, moving your head slightly back out of the way.",
    "Lock the arms out with the bar over the middle of your feet, then lower to the shoulders."],
   ["Leaning back so the lift becomes an incline press.",
    "Pressing the bar forward around the face instead of straight up.",
    "Letting the ribs flare and the lower back arch."],
   ["Use a rack so you do not have to clean the bar up each time.",
    "If overhead pressing pinches your shoulder, use dumbbells at a neutral grip instead."])

ex("seated_dumbbell_shoulder_press", "Seated Dumbbell Shoulder Press", ["shoulders"], ["triceps", "traps"],
   "home", "Pair of dumbbells and a bench or chair with a back", "beginner", "vertical_push",
   True, "external", True, "compound_med",
   ["Sit with your back supported and hold a dumbbell beside each shoulder.",
    "Point your elbows forward and slightly out rather than straight to the sides.",
    "Press both dumbbells up until your arms are straight overhead.",
    "Lower them back to shoulder height under control."],
   ["Arching the lower back off the pad to drive the weight up.",
    "Clashing the dumbbells together at the top."],
   ["A supported back makes this safer than standing if you are new.",
    "Keep the weight light enough to press without a hip drive."])

ex("arnold_press", "Arnold Press", ["shoulders"], ["triceps", "traps"],
   "home", "Pair of dumbbells and a bench with a back", "intermediate", "vertical_push",
   True, "external", False, "compound_med",
   ["Sit tall with a dumbbell in each hand at chest height, palms facing you.",
    "Press up while rotating your palms to face forward.",
    "Finish with your arms straight overhead and palms forward.",
    "Reverse the rotation as you lower back to the start."],
   ["Rotating the wrists too late so the shoulders twist under load.",
    "Using heavy dumbbells and losing the smooth rotation."],
   ["Keep the weight moderate; the rotation is the point of this exercise.",
    "Skip it if rotation causes shoulder discomfort."])

ex("lateral_raise", "Dumbbell Lateral Raise", ["shoulders"], [],
   "home", "Pair of light dumbbells", "beginner", "vertical_push",
   False, "external", True, "isolation_light",
   ["Stand with a light dumbbell in each hand beside your thighs.",
    "Keep a small bend in the elbows and your shoulders pulled down.",
    "Raise both arms out to the sides until your hands are about shoulder height.",
    "Lower them slowly all the way back to your sides."],
   ["Swinging the weights up with a hip bounce.",
    "Raising the arms far above shoulder height and shrugging."],
   ["This exercise needs light weight to work properly.",
    "Keep the thumbs level with the little fingers rather than pouring forward."])

ex("front_raise", "Dumbbell Front Raise", ["shoulders"], ["core"],
   "home", "Pair of light dumbbells", "beginner", "vertical_push",
   False, "external", True, "isolation_light",
   ["Stand with a dumbbell in each hand in front of your thighs, palms facing in.",
    "Brace your stomach so your torso does not rock.",
    "Raise one or both arms straight in front of you to about shoulder height.",
    "Lower under control to the start."],
   ["Leaning back to swing the weight up.",
    "Raising above shoulder height, which brings the traps in."],
   ["Keep the weight light and the tempo steady.",
    "If you already do a lot of pressing, you may not need much of this."])

ex("rear_delt_fly", "Bent-Over Rear Delt Fly", ["rear_delts"], ["back", "traps"],
   "home", "Pair of light dumbbells", "beginner", "horizontal_pull",
   False, "external", True, "isolation_light",
   ["Hinge forward at the hips until your torso is close to horizontal, with a flat back.",
    "Let the dumbbells hang below your chest with a slight elbow bend.",
    "Raise both arms out to the sides until they are level with your torso.",
    "Lower them slowly without letting the shoulders roll forward."],
   ["Using heavy dumbbells and rowing them instead of raising them.",
    "Standing up through the set so the torso ends up upright."],
   ["Support your head on a bench if your lower back tires quickly.",
    "Keep this light; the rear shoulder is a small muscle."])

ex("upright_row", "Upright Row", ["traps"], ["shoulders", "biceps"],
   "gym", "Barbell, dumbbells or a cable", "intermediate", "vertical_pull",
   False, "external", False, "isolation",
   ["Hold the bar at about shoulder width in front of your thighs.",
    "Stand tall with your core braced.",
    "Pull the bar up along your body, leading with the elbows, to roughly chest height.",
    "Lower it slowly back to your thighs."],
   ["Pulling right up to the chin, which can pinch the shoulder.",
    "Using a very narrow grip that forces the wrists into an awkward angle."],
   ["Stop the pull at chest height and keep the grip at shoulder width.",
    "Leave this out if you have any shoulder impingement; use a face pull instead."])

ex("barbell_shrug", "Barbell Shrug", ["traps"], ["forearms"],
   "gym", "Barbell and plates", "beginner", "vertical_pull",
   False, "external", True, "isolation",
   ["Hold the bar at shoulder width in front of your thighs, arms straight.",
    "Stand tall with your chin tucked slightly.",
    "Shrug your shoulders straight up towards your ears.",
    "Lower them fully and let the traps stretch before the next rep."],
   ["Rolling the shoulders in circles instead of shrugging straight up.",
    "Bending the elbows and turning it into a partial row."],
   ["Keep your neck relaxed throughout.",
    "Use a weight you can lift without jerking."])

ex("pike_push_up", "Pike Push-Up", ["shoulders"], ["triceps", "core"],
   "bodyweight", "None", "intermediate", "vertical_push",
   True, "bodyweight", False, "bw_compound",
   ["Start in a push-up position, then walk your feet in and lift your hips high.",
    "Your body should form an upside-down V with straight arms.",
    "Bend your elbows and lower the top of your head towards the floor between your hands.",
    "Press back up until your arms are straight."],
   ["Letting the hips drop so it becomes a normal push-up.",
    "Lowering the head onto the floor rather than stopping just above it."],
   ["Raise your feet onto a step to make it harder once this gets easy.",
    "Come out of the set if you feel pressure in your head or neck."])

ex("band_lateral_raise", "Resistance Band Lateral Raise", ["shoulders"], [],
   "home", "Light resistance band", "beginner", "vertical_push",
   False, "external", True, "isolation_light",
   ["Stand on the middle of the band and hold an end in each hand beside your thighs.",
    "Keep a small bend in the elbows and your shoulders down.",
    "Raise both arms out to the sides to about shoulder height.",
    "Lower slowly against the band tension."],
   ["Letting the band pull the arms down quickly.",
    "Using a band so heavy that you have to swing."],
   ["Check the band for damage before each set.",
    "Keep the movement in a smooth, controlled arc."])

# ---------------------------------------------------------------- biceps
ex("barbell_curl", "Barbell Curl", ["biceps"], ["forearms"],
   "gym", "Straight or EZ barbell", "beginner", "arm_curl",
   False, "external", True, "isolation",
   ["Stand holding the bar at shoulder width with your arms straight and palms forward.",
    "Tuck your elbows against your sides and brace your stomach.",
    "Curl the bar up towards your shoulders without letting the elbows drift forward.",
    "Lower the bar slowly until your arms are completely straight."],
   ["Swinging the torso back to throw the bar up.",
    "Stopping halfway down so the biceps never fully lengthen."],
   ["Use an EZ bar if a straight bar bothers your wrists.",
    "Keep the weight light enough to stay still from the waist down."])

ex("dumbbell_curl", "Dumbbell Curl", ["biceps"], ["forearms"],
   "home", "Pair of dumbbells", "beginner", "arm_curl",
   False, "external", True, "isolation",
   ["Stand with a dumbbell in each hand, arms straight and palms facing forward.",
    "Keep your elbows pinned to your sides.",
    "Curl both dumbbells up to shoulder height, or alternate arms.",
    "Lower them all the way down under control."],
   ["Rocking the body to start each rep.",
    "Letting the elbows travel forward so the shoulders take over."],
   ["Stand tall with your ribs down.",
    "Lower over two to three seconds for the most benefit."])

ex("hammer_curl", "Hammer Curl", ["biceps", "forearms"], [],
   "home", "Pair of dumbbells", "beginner", "arm_curl",
   False, "external", True, "isolation",
   ["Hold a dumbbell in each hand with your palms facing your thighs.",
    "Keep this neutral grip for the whole set.",
    "Curl the dumbbells up towards your shoulders, elbows tucked in.",
    "Lower slowly to straight arms."],
   ["Turning the palms up during the curl, which makes it a standard curl.",
    "Shrugging the shoulders at the top."],
   ["This grip is usually kinder to the wrists and elbows.",
    "Keep your torso steady throughout."])

ex("incline_dumbbell_curl", "Incline Dumbbell Curl", ["biceps"], ["forearms"],
   "home", "Pair of dumbbells and an incline bench", "intermediate", "arm_curl",
   False, "external", True, "isolation",
   ["Sit back on an incline bench with a dumbbell in each hand, arms hanging straight down.",
    "Let your upper arms stay back behind your torso.",
    "Curl the dumbbells up to shoulder height without lifting the elbows forward.",
    "Lower to a full stretch, controlling the last part of the movement."],
   ["Lifting the elbows forward to make the bottom of the rep easier.",
    "Using too much weight, which makes the stretched position risky."],
   ["Start lighter than you would for a standing curl.",
    "Stop if you feel a pull at the front of the shoulder."])

ex("preacher_curl", "Preacher Curl", ["biceps"], ["forearms"],
   "gym", "Preacher bench and an EZ bar or dumbbell", "intermediate", "arm_curl",
   False, "external", True, "isolation",
   ["Rest the back of your upper arms on the angled pad with your armpits at the top edge.",
    "Hold the bar with your arms almost straight.",
    "Curl the bar up to shoulder height, keeping your arms flat on the pad.",
    "Lower slowly until your arms are nearly straight again."],
   ["Lifting the elbows off the pad at the bottom.",
    "Dropping the weight quickly from the top."],
   ["Keep a slight bend at the bottom rather than hyperextending the elbow.",
    "Use moderate weight; the pad removes any chance of cheating."])

ex("concentration_curl", "Concentration Curl", ["biceps"], [],
   "home", "One dumbbell and a bench or chair", "beginner", "arm_curl",
   False, "external", True, "isolation",
   ["Sit on a bench with your legs apart and lean forward slightly.",
    "Rest the back of your working upper arm against the inside of the same-side thigh.",
    "Curl the dumbbell up towards your shoulder.",
    "Lower it slowly to a straight arm, then repeat and change sides."],
   ["Moving the upper arm instead of keeping it braced on the thigh.",
    "Rushing the lowering phase."],
   ["Keep your back flat rather than rounding over.",
    "Light weight works well here."])

ex("cable_curl", "Cable Curl", ["biceps"], ["forearms"],
   "gym", "Low cable pulley with a bar or rope", "beginner", "arm_curl",
   False, "external", True, "isolation",
   ["Set the pulley at the bottom and hold the bar with palms up.",
    "Step back slightly so there is tension at the start.",
    "Curl the bar to shoulder height with your elbows at your sides.",
    "Let the cable straighten your arms slowly."],
   ["Leaning back as the set gets hard.",
    "Letting the stack pull the arms down fast."],
   ["Cables keep tension across the whole range, so you can use less weight.",
    "Keep your wrists straight."])

ex("band_biceps_curl", "Resistance Band Curl", ["biceps"], ["forearms"],
   "home", "Resistance band", "beginner", "arm_curl",
   False, "external", True, "isolation_light",
   ["Stand on the middle of the band and hold an end in each hand, palms forward.",
    "Keep your elbows at your sides.",
    "Curl both hands up towards your shoulders.",
    "Lower slowly against the band."],
   ["Letting the band snap the arms back down.",
    "Stepping onto the band off-centre so one side is tighter."],
   ["Check the band for wear before each session.",
    "Stand on the band firmly with both feet."])

# ---------------------------------------------------------------- triceps
ex("close_grip_bench_press", "Close-Grip Bench Press", ["triceps"], ["chest", "shoulders"],
   "gym", "Barbell, flat bench and a rack", "intermediate", "horizontal_push",
   True, "external", False, "compound_med",
   ["Lie on the bench and take the bar at roughly shoulder width, not narrower.",
    "Unrack the bar and set your shoulder blades back.",
    "Lower the bar to your lower chest with your elbows tucked close to your sides.",
    "Press straight up until your arms are locked out."],
   ["Gripping so narrow that the wrists bend back painfully.",
    "Letting the elbows flare out, which shifts the work to the chest."],
   ["Keep the grip at shoulder width to protect the wrists.",
    "Use a spotter or safety pins for heavy sets."])

ex("bench_triceps_dip", "Bench Triceps Dip", ["triceps"], ["chest", "shoulders"],
   "bodyweight", "A bench, chair or step", "beginner", "horizontal_push",
   True, "bodyweight", False, "bw_compound",
   ["Sit on the edge of a bench and place your hands beside your hips, fingers forward.",
    "Slide your hips off the edge and support yourself with straight arms.",
    "Bend your elbows straight back and lower your hips towards the floor.",
    "Press back up until your arms are straight."],
   ["Letting the elbows flare out to the sides.",
    "Dropping so low that the shoulders roll forward."],
   ["Keep your hips close to the bench rather than drifting forward.",
    "Stop at a depth where your shoulders stay comfortable; bend your knees to make it easier."])

ex("overhead_triceps_extension", "Overhead Dumbbell Triceps Extension", ["triceps"], ["core"],
   "home", "One dumbbell", "beginner", "arm_extension",
   False, "external", True, "isolation",
   ["Hold one dumbbell overhead with both hands, arms straight.",
    "Keep your ribs down and your core braced so the back does not arch.",
    "Bend your elbows to lower the dumbbell behind your head.",
    "Press it back up to straight arms, keeping the elbows pointing forward."],
   ["Letting the elbows flare wide so the movement loses its direction.",
    "Arching the lower back as the weight goes behind the head."],
   ["Start light; this position is easy to overload.",
    "Stop if you feel any pinch at the elbow or shoulder."])

ex("triceps_rope_pushdown", "Triceps Rope Pushdown", ["triceps"], [],
   "gym", "Cable stack with a rope attachment", "beginner", "arm_extension",
   False, "external", True, "isolation",
   ["Set the pulley high and hold the rope ends with your elbows at your sides.",
    "Stand tall with a slight forward lean and a braced core.",
    "Straighten your arms down and slightly apart at the bottom.",
    "Let your forearms rise back to about ninety degrees under control."],
   ["Using the whole body to push the weight down.",
    "Letting the elbows drift forward and away from the body."],
   ["Keep your upper arms still; only the forearms move.",
    "Moderate weight gives the best result here."])

ex("skull_crusher", "Skull Crusher", ["triceps"], [],
   "gym", "EZ bar and a flat bench", "intermediate", "arm_extension",
   False, "external", False, "isolation",
   ["Lie on a bench holding an EZ bar above your chest with straight arms.",
    "Keep your upper arms vertical and your elbows pointing at the ceiling.",
    "Bend your elbows to lower the bar towards the top of your forehead.",
    "Press back up to straight arms without moving the upper arms."],
   ["Letting the upper arms swing back so it becomes a pullover.",
    "Lowering the bar fast towards the head."],
   ["Use an EZ bar to keep the wrists comfortable and use a controlled tempo.",
    "Have a spotter hand you the bar if it is heavy."])

ex("diamond_push_up", "Diamond Push-Up", ["triceps"], ["chest", "shoulders", "core"],
   "bodyweight", "None", "intermediate", "horizontal_push",
   True, "bodyweight", False, "bw_compound",
   ["Start in a push-up position with your hands together under your chest, index fingers and thumbs touching.",
    "Hold your body in one straight line and brace your stomach.",
    "Lower your chest towards your hands, keeping your elbows close to your body.",
    "Press back up to straight arms."],
   ["Letting the elbows flare out, which removes the triceps emphasis.",
    "Letting the hips sag as it gets hard."],
   ["Raise your hands onto a step if the wrist position is uncomfortable.",
    "Build up from standard push-ups first."])

ex("triceps_kickback", "Triceps Kickback", ["triceps"], [],
   "home", "One light dumbbell and a bench", "beginner", "arm_extension",
   False, "external", True, "isolation_light",
   ["Place one hand on a bench and hinge forward with a flat back.",
    "Hold a dumbbell in the other hand with your upper arm tight against your side.",
    "Straighten your elbow until your whole arm is in line with your torso.",
    "Bend the elbow back to ninety degrees under control, then change sides."],
   ["Swinging the arm to throw the weight back.",
    "Letting the upper arm drop towards the floor between reps."],
   ["This exercise is most effective with light weight and a brief squeeze at the top.",
    "Keep your neck in line with your spine."])

ex("band_triceps_pushdown", "Resistance Band Triceps Pushdown", ["triceps"], [],
   "home", "Resistance band anchored above head height", "beginner", "arm_extension",
   False, "external", True, "isolation_light",
   ["Anchor the band high and hold an end in each hand with your elbows at your sides.",
    "Stand tall with your core braced.",
    "Straighten your arms down against the band.",
    "Let your forearms rise back up slowly."],
   ["Letting the elbows travel forward.",
    "Allowing the band to snap the hands upward."],
   ["Check the band and the anchor before you start.",
    "Keep your wrists firm and straight."])

# ---------------------------------------------------------------- quads
ex("barbell_back_squat", "Barbell Back Squat", ["quads", "glutes"], ["hamstrings", "core", "lower_back"],
   "gym", "Barbell and a squat rack", "advanced", "squat",
   True, "external", False, "compound_heavy",
   ["Set the bar across your upper back, not your neck, and grip it firmly.",
    "Step back with your feet about shoulder width and your toes slightly out.",
    "Take a breath, brace your stomach and sit down and back, keeping your chest up.",
    "Descend to a depth you can control with a neutral spine, then drive up through your whole foot."],
   ["Letting the knees collapse inwards on the way up.",
    "Rounding the lower back at the bottom of the squat.",
    "Rising onto the toes instead of staying flat-footed."],
   ["Always set the safety bars in the rack at the right height.",
    "Build depth gradually; only go as low as you can keep a neutral spine.",
    "Skip heavy squats and use a machine or bodyweight version if you have a knee or back injury."])

ex("front_squat", "Front Squat", ["quads"], ["glutes", "core", "traps"],
   "gym", "Barbell and a squat rack", "advanced", "squat",
   True, "external", False, "compound_heavy",
   ["Rest the bar across the front of your shoulders and hold it in place with your fingertips or crossed arms.",
    "Keep your elbows high so the bar cannot roll forward.",
    "Brace your stomach and squat down with an upright torso.",
    "Drive up through your whole foot, keeping the elbows up."],
   ["Letting the elbows drop, which rolls the bar off the shoulders.",
    "Leaning forward so the bar drifts in front of the feet."],
   ["This lift needs good wrist and shoulder mobility; use a goblet squat instead if not.",
    "Set the rack safeties before you start."])

ex("leg_press", "Leg Press", ["quads", "glutes"], ["hamstrings"],
   "gym", "Leg press machine", "beginner", "squat",
   True, "external", True, "compound_med",
   ["Sit in the machine with your whole back against the pad and feet flat on the platform.",
    "Push the platform up and release the safety catches.",
    "Bend your knees to lower the platform until your knees are at about ninety degrees.",
    "Press back up without locking your knees hard at the top."],
   ["Lowering so far that the hips roll off the pad and the lower back rounds.",
    "Pushing the knees out straight and locking them aggressively."],
   ["Stop lowering before your lower back lifts away from the pad.",
    "Keep your hands on the handles, not on your knees."])

ex("leg_extension", "Leg Extension", ["quads"], [],
   "gym", "Leg extension machine", "beginner", "squat",
   False, "external", True, "isolation",
   ["Sit in the machine with the pad resting on your shins just above the ankles.",
    "Line the pivot of the machine up with your knee joint.",
    "Straighten your knees until your legs are almost straight, pausing briefly.",
    "Lower slowly to the start without letting the weight crash down."],
   ["Swinging the legs up and letting the weight drop back.",
    "Setting the pad too high on the shin, which pulls on the knee."],
   ["Use moderate weight and avoid snapping the knees straight.",
    "Reduce the range if you have knee pain, or leave this out and use a leg press."])

ex("bodyweight_squat", "Bodyweight Squat", ["quads", "glutes"], ["hamstrings", "core"],
   "bodyweight", "None", "beginner", "squat",
   True, "bodyweight", True, "bw_compound",
   ["Stand with your feet about shoulder width apart and your toes slightly turned out.",
    "Hold your arms out in front for balance and brace your stomach.",
    "Sit your hips down and back, keeping your chest up and your heels on the floor.",
    "Stand back up by driving through your whole foot and squeezing your glutes."],
   ["Letting the heels lift off the floor.",
    "Letting the knees fall inwards.",
    "Bending at the waist instead of sitting the hips down."],
   ["Hold a chair or wall lightly for balance while you learn the movement.",
    "Squat only as deep as feels comfortable for your knees."])

ex("goblet_squat", "Goblet Squat", ["quads", "glutes"], ["core", "hamstrings"],
   "home", "One dumbbell or kettlebell", "beginner", "squat",
   True, "external", True, "compound_med",
   ["Hold a single weight close against your chest with both hands.",
    "Stand with your feet about shoulder width and toes slightly out.",
    "Sit your hips down between your feet, keeping your chest tall and elbows inside your knees.",
    "Stand up by driving through your feet and squeezing your glutes."],
   ["Letting the weight drift away from the chest, which pulls you forward.",
    "Rounding the lower back at the bottom."],
   ["This is often the safest loaded squat to learn with.",
    "Keep the weight tight to your body throughout."])

ex("bulgarian_split_squat", "Bulgarian Split Squat", ["quads", "glutes"], ["hamstrings", "core"],
   "home", "A bench or chair, dumbbells optional", "intermediate", "lunge",
   True, "external", False, "compound_med",
   ["Stand about one stride in front of a bench and rest the top of one foot behind you on it.",
    "Keep your torso upright and your front foot flat.",
    "Bend the front knee and lower until your front thigh is close to parallel with the floor.",
    "Drive up through the front foot and repeat, then change legs."],
   ["Placing the front foot too close to the bench, which cramps the knee.",
    "Leaning far forward and losing balance."],
   ["Hold a wall or rail for balance while you learn this.",
    "Start with bodyweight before adding dumbbells."])

ex("walking_lunge", "Walking Lunge", ["quads", "glutes"], ["hamstrings", "core", "calves"],
   "bodyweight", "Clear floor space, dumbbells optional", "intermediate", "lunge",
   True, "bodyweight", False, "bw_compound",
   ["Stand tall with your feet together and your core braced.",
    "Step forward into a long stride and bend both knees to lower your back knee towards the floor.",
    "Push through the front foot to stand and bring the back foot through into the next stride.",
    "Keep alternating legs for the set."],
   ["Taking short steps so the front knee travels far past the toes.",
    "Letting the torso fall forward over the front leg."],
   ["Hold a wall for support if your balance is still developing.",
    "Switch to static split squats if lunging bothers your knees."])

ex("step_up", "Step-Up", ["quads", "glutes"], ["hamstrings", "calves", "core"],
   "home", "A sturdy step, bench or stair", "beginner", "lunge",
   True, "bodyweight", True, "bw_compound",
   ["Stand facing a step that is around knee height or lower.",
    "Place one whole foot on the step.",
    "Press through that foot to stand up on the step, bringing the other foot up.",
    "Step back down under control and repeat, then change the leading leg."],
   ["Pushing off hard with the bottom foot instead of using the top leg.",
    "Using a step so high that the knee is deeply bent at the start."],
   ["Use a lower step if your knee feels strained.",
    "Hold a rail for balance; this is a good choice for older beginners."])

ex("wall_sit", "Wall Sit", ["quads"], ["glutes", "core"],
   "bodyweight", "A clear wall", "beginner", "squat",
   False, "bodyweight", True, "core_timed",
   ["Stand with your back flat against a wall and walk your feet forward.",
    "Slide down until your knees are bent to roughly ninety degrees.",
    "Keep your whole back against the wall and your weight in your heels.",
    "Hold for the set time, breathing steadily, then push back up."],
   ["Letting the knees travel past the toes.",
    "Holding the breath through the hold."],
   ["Come up to a shallower angle if your knees complain.",
    "Stand up immediately if your legs start to shake uncontrollably."])

# ---------------------------------------------------------------- hamstrings and glutes
ex("romanian_deadlift", "Romanian Deadlift", ["hamstrings", "glutes"], ["lower_back", "back"],
   "gym", "Barbell or pair of dumbbells", "intermediate", "hinge",
   True, "external", False, "compound_heavy",
   ["Stand holding the bar at the top of a deadlift with a slight knee bend.",
    "Push your hips back and let the bar slide down the front of your thighs.",
    "Keep your back flat and go down only as far as your hamstrings allow without rounding.",
    "Drive your hips forward to stand tall again."],
   ["Turning the movement into a squat by bending the knees too much.",
    "Rounding the lower back to reach further down.",
    "Letting the bar drift away from the legs."],
   ["Range comes from your hamstrings, not from how low you can reach.",
    "Start light and keep the bar close to the body."])

ex("single_leg_romanian_deadlift", "Single-Leg Romanian Deadlift", ["hamstrings", "glutes"], ["core", "lower_back"],
   "home", "One dumbbell, optional", "intermediate", "hinge",
   True, "external", False, "isolation",
   ["Stand on one leg with a slight bend in that knee, holding a weight in the opposite hand.",
    "Hinge forward at the hip and let the free leg extend straight behind you.",
    "Keep your hips level and your back flat as your torso comes towards horizontal.",
    "Squeeze the glute to stand back up, then change sides."],
   ["Letting the hip of the free leg rotate open towards the ceiling.",
    "Rounding the back instead of hinging at the hip."],
   ["Hold a wall or chair with your free hand while you learn the balance.",
    "Start with no weight at all."])

ex("lying_leg_curl", "Lying Leg Curl", ["hamstrings"], ["calves"],
   "gym", "Lying leg curl machine", "beginner", "hinge",
   False, "external", True, "isolation",
   ["Lie face down with the pad resting just above your heels.",
    "Hold the handles and keep your hips pressed into the bench.",
    "Curl your heels towards your glutes as far as the machine allows.",
    "Lower slowly until your legs are almost straight."],
   ["Lifting the hips off the bench to get more range.",
    "Letting the weight drop quickly at the end of each rep."],
   ["Keep the hips down and the movement smooth.",
    "Reduce the weight if you feel cramping in the hamstrings."])

ex("seated_leg_curl", "Seated Leg Curl", ["hamstrings"], ["calves"],
   "gym", "Seated leg curl machine", "beginner", "hinge",
   False, "external", True, "isolation",
   ["Sit with your back against the pad and the leg pad just above your heels.",
    "Secure the thigh pad so your legs stay in place.",
    "Curl your heels down and back as far as comfortable.",
    "Return slowly to almost straight legs."],
   ["Sliding forward in the seat during the set.",
    "Using momentum rather than muscle."],
   ["Set the back pad so your knees line up with the machine pivot.",
    "Keep the tempo controlled in both directions."])

ex("hip_thrust", "Barbell Hip Thrust", ["glutes"], ["hamstrings", "core"],
   "gym", "Barbell, pad and a bench", "intermediate", "hinge",
   True, "external", True, "compound_med",
   ["Sit on the floor with your upper back against a bench and the padded bar across your hips.",
    "Plant your feet flat, about shoulder width, with your knees bent.",
    "Drive through your heels and lift your hips until your torso and thighs are in line.",
    "Squeeze your glutes at the top, then lower under control."],
   ["Over-extending at the top and arching the lower back.",
    "Pushing through the toes instead of the whole foot."],
   ["Always use a pad between the bar and your hips.",
    "Finish at a straight line from knees to shoulders, no higher."])

ex("glute_bridge", "Glute Bridge", ["glutes"], ["hamstrings", "core"],
   "bodyweight", "None", "beginner", "hinge",
   False, "bodyweight", True, "core_reps",
   ["Lie on your back with your knees bent and feet flat, about hip width apart.",
    "Press your lower back gently into the floor and brace your stomach.",
    "Push through your heels and lift your hips until your body is in a straight line from knees to shoulders.",
    "Pause, squeeze the glutes, then lower slowly."],
   ["Lifting so high that the movement comes from the lower back.",
    "Letting the knees fall apart or press together."],
   ["This is a safe starting point for most people, including older beginners.",
    "Stop if you feel it only in the lower back rather than the glutes."])

ex("good_morning", "Good Morning", ["hamstrings", "lower_back"], ["glutes", "core"],
   "gym", "Barbell and a rack", "advanced", "hinge",
   True, "external", False, "isolation",
   ["Set a light bar across your upper back as for a squat.",
    "Stand with your feet hip width and a soft bend in the knees.",
    "Push your hips back and lower your torso towards horizontal with a flat back.",
    "Drive your hips forward to stand tall again."],
   ["Using heavy weight, which puts large load on the lower back.",
    "Rounding the spine to get lower."],
   ["Use a very light bar and master the hinge first with a Romanian deadlift.",
    "Leave this exercise out if you have any back injury."])

ex("cable_pull_through", "Cable Pull-Through", ["glutes"], ["hamstrings", "lower_back"],
   "gym", "Low cable pulley with a rope", "beginner", "hinge",
   True, "external", True, "isolation",
   ["Face away from a low pulley and pass the rope between your legs.",
    "Step forward until the cable is under tension, feet hip width apart.",
    "Hinge your hips back, letting the rope travel between your legs with a flat back.",
    "Drive your hips forward to stand tall and squeeze the glutes."],
   ["Squatting down instead of hinging at the hips.",
    "Pulling the rope with the arms."],
   ["The arms just hold the rope; the hips do the work.",
    "This is a good way to learn the hinge pattern safely."])

ex("band_glute_kickback", "Resistance Band Glute Kickback", ["glutes"], ["hamstrings", "core"],
   "home", "Loop resistance band", "beginner", "hinge",
   False, "external", True, "core_reps",
   ["Loop the band around both ankles and stand holding a wall or chair for support.",
    "Brace your stomach and keep your hips square to the wall.",
    "Push one leg straight back against the band, squeezing the glute.",
    "Return slowly and repeat, then change legs."],
   ["Arching the lower back to push the leg further.",
    "Twisting the hips open to get more range."],
   ["Keep the movement small and controlled.",
    "Hold onto support so balance is not the limiting factor."])

ex("nordic_hamstring_lower", "Assisted Nordic Hamstring Lower", ["hamstrings"], ["glutes", "core"],
   "bodyweight", "A padded floor and something to anchor your ankles", "advanced", "hinge",
   False, "bodyweight", False, "core_reps",
   ["Kneel on a padded surface with your ankles held down securely behind you.",
    "Brace your stomach and squeeze your glutes so your hips stay straight.",
    "Lower your torso towards the floor as slowly as you can, resisting with the hamstrings.",
    "Catch yourself with your hands and push back up to the start."],
   ["Breaking at the hips so the body folds instead of staying straight.",
    "Dropping quickly rather than resisting on the way down."],
   ["This is a demanding exercise; use your hands to take load and only lower a short way at first.",
    "Skip it if you have any hamstring or knee injury."])

# ---------------------------------------------------------------- calves
ex("standing_calf_raise", "Standing Calf Raise", ["calves"], [],
   "gym", "Standing calf raise machine or a step with dumbbells", "beginner", "calf",
   False, "external", True, "isolation",
   ["Stand with the balls of your feet on the platform and your heels hanging off.",
    "Stand tall with your knees almost straight.",
    "Press up onto your toes as high as you can and pause.",
    "Lower your heels below the platform for a full stretch."],
   ["Bouncing quickly through a short range.",
    "Bending the knees to help push up."],
   ["Hold a support for balance if needed.",
    "Slow, full-range reps work far better than fast partial ones."])

ex("seated_calf_raise", "Seated Calf Raise", ["calves"], [],
   "gym", "Seated calf raise machine", "beginner", "calf",
   False, "external", True, "isolation",
   ["Sit with the balls of your feet on the platform and the pad over your thighs.",
    "Release the safety and let your heels drop for a stretch.",
    "Press up onto your toes as high as possible.",
    "Lower slowly back to a full stretch."],
   ["Using a very short range at the top of the movement.",
    "Letting the weight drop fast and bounce."],
   ["Set the thigh pad snugly but not painfully tight.",
    "Keep the tempo slow in both directions."])

ex("bodyweight_calf_raise", "Bodyweight Calf Raise", ["calves"], [],
   "bodyweight", "A step or flat floor", "beginner", "calf",
   False, "bodyweight", True, "core_reps",
   ["Stand with the balls of your feet on a step and your heels hanging off, holding a support.",
    "Press up onto your toes as high as you can.",
    "Pause briefly at the top.",
    "Lower your heels slowly below the level of the step."],
   ["Rushing through reps with a tiny range.",
    "Leaning on the support to take body weight off the calves."],
   ["Use a wall or rail only for balance.",
    "Work on flat floor instead of a step if your ankles feel stiff."])

ex("single_leg_calf_raise", "Single-Leg Calf Raise", ["calves"], ["core"],
   "bodyweight", "A step and a support to hold", "intermediate", "calf",
   False, "bodyweight", True, "core_reps",
   ["Stand on one foot with the ball of that foot on a step, holding a support.",
    "Let the heel drop below the step for a stretch.",
    "Press up onto the toes of that foot as high as you can.",
    "Lower slowly, then change legs."],
   ["Hopping up rather than pressing smoothly.",
    "Pulling hard on the support to assist the lift."],
   ["Hold a rail for balance only.",
    "Build up with both feet first."])

# ---------------------------------------------------------------- core
ex("plank", "Plank", ["core"], ["shoulders", "glutes"],
   "bodyweight", "None", "beginner", "core",
   False, "bodyweight", True, "core_timed",
   ["Rest on your forearms and toes with your elbows under your shoulders.",
    "Brace your stomach and squeeze your glutes so your body makes one straight line.",
    "Keep your hips level with your shoulders and your neck in line with your spine.",
    "Hold for the set time, breathing steadily throughout."],
   ["Letting the hips sag so the lower back takes the strain.",
    "Lifting the hips high into a tent shape, which makes the hold easy.",
    "Holding the breath."],
   ["Drop to your knees to shorten the lever if your hips start to sag.",
    "End the hold as soon as your form breaks; a shorter good hold beats a long sloppy one."])

ex("side_plank", "Side Plank", ["obliques", "core"], ["shoulders", "glutes"],
   "bodyweight", "None", "intermediate", "core",
   False, "bodyweight", True, "core_timed",
   ["Lie on one side with your elbow under your shoulder and your legs stacked.",
    "Push your hips up so your body forms a straight line from head to feet.",
    "Keep your top hip stacked above the bottom hip rather than rolling forward.",
    "Hold for the set time, then change sides."],
   ["Letting the hips drift backwards or sagging towards the floor.",
    "Letting the shoulder collapse towards the ear."],
   ["Bend the bottom knee and rest it on the floor to make the hold easier.",
    "Stop if you feel strain in the shoulder."])

ex("dead_bug", "Dead Bug", ["core"], ["hip_flexors"],
   "bodyweight", "None", "beginner", "core",
   False, "bodyweight", True, "core_reps",
   ["Lie on your back with your knees bent at ninety degrees and your arms straight up.",
    "Press your lower back gently towards the floor and keep it there.",
    "Slowly extend one arm overhead and the opposite leg straight out.",
    "Return to the start and repeat with the other pair."],
   ["Letting the lower back arch away from the floor as the limbs extend.",
    "Moving quickly instead of slowly and deliberately."],
   ["Reduce the range if your back lifts; keep the back flat at all costs.",
    "This is a safe starting point if you have had back trouble, once a doctor has cleared you."])

ex("bird_dog", "Bird Dog", ["core", "lower_back"], ["glutes", "shoulders"],
   "bodyweight", "None", "beginner", "core",
   False, "bodyweight", True, "core_reps",
   ["Start on all fours with your hands under your shoulders and knees under your hips.",
    "Brace your stomach and set your back flat and level.",
    "Extend one arm forward and the opposite leg back until both are in line with your torso.",
    "Hold briefly, return under control and repeat on the other side."],
   ["Lifting the arm and leg too high, which arches the lower back.",
    "Letting the hips twist to one side."],
   ["Imagine balancing a glass of water on your lower back and keep it level.",
    "Move slowly; speed removes the benefit."])

ex("crunch", "Crunch", ["core"], [],
   "bodyweight", "None", "beginner", "core",
   False, "bodyweight", True, "core_reps",
   ["Lie on your back with your knees bent and feet flat on the floor.",
    "Rest your hands lightly beside your head without pulling on your neck.",
    "Curl your upper back off the floor, bringing your ribs towards your hips.",
    "Lower slowly until your shoulders touch the floor."],
   ["Pulling the head forward with the hands.",
    "Using momentum to bounce up and down."],
   ["Keep your chin off your chest and your neck relaxed.",
    "If your neck tires first, place one hand behind the head for support."])

ex("bicycle_crunch", "Bicycle Crunch", ["obliques", "core"], ["hip_flexors"],
   "bodyweight", "None", "beginner", "core",
   False, "bodyweight", True, "core_reps",
   ["Lie on your back with your hands beside your head and your knees bent off the floor.",
    "Curl your upper back up and bring one knee towards your chest.",
    "Rotate so the opposite elbow turns towards that knee while the other leg extends.",
    "Alternate sides smoothly for the set."],
   ["Yanking the head around with the hands.",
    "Rushing so the rotation comes from the arms rather than the trunk."],
   ["Slow the tempo down and make each rotation deliberate.",
    "Keep your lower back close to the floor."])

ex("hanging_knee_raise", "Hanging Knee Raise", ["core"], ["hip_flexors", "forearms"],
   "bodyweight", "A pull-up bar", "intermediate", "core",
   False, "bodyweight", False, "core_reps",
   ["Hang from a bar with straight arms and your shoulder blades pulled down.",
    "Brace your stomach so your body does not swing.",
    "Raise both knees towards your chest, curling your hips up slightly at the top.",
    "Lower your legs slowly back to a full hang."],
   ["Swinging the body to get the knees up.",
    "Only moving at the hips with no curl of the pelvis."],
   ["Use a pull-up bar you can reach safely and step down rather than dropping.",
    "Switch to lying leg raises if your grip gives out first."])

ex("lying_leg_raise", "Lying Leg Raise", ["core"], ["hip_flexors"],
   "bodyweight", "None", "beginner", "core",
   False, "bodyweight", True, "core_reps",
   ["Lie on your back with your legs straight and your hands beside your hips.",
    "Press your lower back gently into the floor.",
    "Raise both legs until they are roughly vertical, keeping them straight.",
    "Lower them slowly, stopping before your back lifts off the floor."],
   ["Letting the lower back arch as the legs come down.",
    "Dropping the legs quickly."],
   ["Bend your knees to make it easier, and stop the lowering phase higher up.",
    "Place your hands under your hips for extra support if needed."])

ex("russian_twist", "Russian Twist", ["obliques"], ["core", "hip_flexors"],
   "bodyweight", "A light weight, optional", "beginner", "core",
   False, "bodyweight", True, "core_reps",
   ["Sit on the floor with your knees bent and your heels lightly touching down.",
    "Lean back slightly and keep your back flat, holding your hands or a light weight at your chest.",
    "Rotate your trunk to one side, keeping your chest tall.",
    "Rotate smoothly to the other side and continue alternating."],
   ["Swinging the arms while the trunk stays still.",
    "Rounding the lower back and collapsing backwards."],
   ["Keep it slow and controlled and use little or no weight.",
    "Place your feet on the floor if your back rounds."])

ex("mountain_climber", "Mountain Climber", ["core"], ["shoulders", "quads", "hip_flexors"],
   "bodyweight", "None", "beginner", "conditioning",
   True, "bodyweight", False, "conditioning",
   ["Start in a high plank with your hands under your shoulders.",
    "Brace your stomach so your hips stay level.",
    "Drive one knee towards your chest, then switch legs.",
    "Keep alternating at a steady pace for the set time."],
   ["Letting the hips bounce up and down with every switch.",
    "Going so fast that the feet barely move."],
   ["Slow the pace down to keep the hips quiet.",
    "Switch to standing marches if wrist pressure is uncomfortable."])

ex("cable_woodchop", "Cable Woodchop", ["obliques"], ["core", "shoulders"],
   "gym", "Cable stack with a single handle", "intermediate", "core",
   False, "external", True, "isolation",
   ["Set the pulley high and stand side-on, holding the handle with both hands.",
    "Step away so there is tension, with your feet about shoulder width.",
    "Pull the handle down and across your body towards the opposite hip, rotating your trunk.",
    "Return slowly along the same path, then do the other side."],
   ["Using the arms to pull while the trunk stays still.",
    "Letting the cable snap the arms back up."],
   ["Pivot the back foot so the knees are not twisted.",
    "Keep the weight moderate so the movement stays controlled."])

ex("ab_wheel_rollout", "Ab Wheel Rollout", ["core"], ["lats", "shoulders", "lower_back"],
   "home", "An ab wheel", "advanced", "core",
   False, "bodyweight", False, "core_reps",
   ["Kneel on a mat holding the wheel under your shoulders.",
    "Brace your stomach hard and tuck your hips slightly under.",
    "Roll the wheel forward only as far as you can keep your back flat.",
    "Pull with your stomach to bring the wheel back to the start."],
   ["Rolling out so far that the lower back sags into an arch.",
    "Pulling back with the arms instead of the stomach."],
   ["Begin with a very short roll-out and increase the range slowly over weeks.",
    "Stop immediately if you feel it in your lower back."])

# ---------------------------------------------------------------- conditioning and balance
ex("burpee", "Burpee", ["full_body"], ["chest", "quads", "core", "shoulders"],
   "bodyweight", "None", "intermediate", "conditioning",
   True, "bodyweight", False, "conditioning",
   ["Stand tall, then squat down and place your hands on the floor.",
    "Jump or step your feet back into a high plank and perform a push-up.",
    "Jump or step your feet back under your body.",
    "Stand or jump up to finish the repetition."],
   ["Letting the hips sag during the plank and push-up portion.",
    "Landing with locked knees after the jump."],
   ["Step the feet instead of jumping, and leave out the jump at the top, to lower the impact.",
    "Skip this exercise if you have knee, hip or back problems."])

ex("kettlebell_swing", "Kettlebell Swing", ["glutes", "hamstrings"], ["core", "back", "shoulders"],
   "gym", "One kettlebell", "intermediate", "hinge",
   True, "external", False, "conditioning_reps",
   ["Stand with the kettlebell on the floor about a foot in front of you.",
    "Hinge at the hips, grip the handle with both hands and hike it back between your legs.",
    "Snap your hips forward so the bell swings up to about chest height on its own.",
    "Let it swing back between your legs and repeat, hinging each time."],
   ["Squatting down and lifting the bell with the arms.",
    "Trying to raise the bell with the shoulders rather than the hips.",
    "Over-arching the lower back at the top."],
   ["Learn the hip hinge with a Romanian deadlift before you swing.",
    "Swing in a clear space, and set the bell down rather than dropping it."])

ex("dumbbell_thruster", "Dumbbell Thruster", ["full_body"], ["quads", "shoulders", "glutes", "core"],
   "home", "Pair of dumbbells", "intermediate", "conditioning",
   True, "external", False, "conditioning_reps",
   ["Hold a dumbbell at each shoulder with your feet about shoulder width.",
    "Squat down with an upright torso.",
    "Drive up out of the squat and use that momentum to press the dumbbells overhead.",
    "Lower the dumbbells to your shoulders as you begin the next squat."],
   ["Pressing before the legs have finished driving, which breaks the rhythm.",
    "Letting the lower back arch as the weights go overhead."],
   ["Use light dumbbells; this exercise raises the heart rate quickly.",
    "Stop the set if you feel dizzy or very breathless."])

ex("jumping_jack", "Jumping Jack", ["full_body"], ["calves", "shoulders"],
   "bodyweight", "None", "beginner", "conditioning",
   True, "bodyweight", False, "conditioning",
   ["Stand tall with your arms at your sides and your feet together.",
    "Jump your feet out to the sides while raising your arms overhead.",
    "Jump your feet back together and lower your arms.",
    "Keep a steady rhythm for the set time."],
   ["Landing heavily with straight knees.",
    "Only half raising the arms."],
   ["Step side to side instead of jumping to remove the impact.",
    "Wear supportive shoes on a hard floor."])

ex("high_knees", "High Knees", ["full_body"], ["quads", "core", "calves", "hip_flexors"],
   "bodyweight", "None", "beginner", "conditioning",
   True, "bodyweight", False, "conditioning",
   ["Stand tall with your core braced and your arms bent.",
    "Drive one knee up towards hip height.",
    "Switch legs quickly, staying on the balls of your feet.",
    "Keep your chest up and continue for the set time."],
   ["Leaning back as the pace increases.",
    "Barely lifting the knees."],
   ["March in place instead of running to lower the impact.",
    "Slow down if you cannot keep your breathing under control."])

ex("farmer_walk", "Farmer Walk", ["forearms", "traps"], ["core", "glutes", "quads"],
   "home", "Pair of dumbbells or kettlebells", "beginner", "carry",
   True, "external", True, "carry_timed",
   ["Hold a heavy weight in each hand at your sides.",
    "Stand tall with your shoulders pulled back and your core braced.",
    "Walk in a straight line with controlled steps for the set time or distance.",
    "Set the weights down carefully by hinging at the hips."],
   ["Leaning to one side when the weights are uneven.",
    "Letting the shoulders roll forward and the back round."],
   ["Walk in a clear path and set the weights down rather than dropping them.",
    "Reduce the weight if your grip fails before the time is up."])

ex("brisk_walk", "Brisk Walk", ["full_body"], ["quads", "glutes", "calves"],
   "bodyweight", "Comfortable shoes and a safe route", "beginner", "conditioning",
   True, "timed", True, "cardio_steady",
   ["Start with two or three minutes of easy walking to warm up.",
    "Pick up the pace until your breathing is faster but you can still talk.",
    "Hold that pace for the planned time, keeping your posture tall.",
    "Finish with a few minutes of easy walking to cool down."],
   ["Starting at full pace with no warm-up.",
    "Walking so fast that you cannot hold a short conversation."],
   ["This is a moderate-intensity activity and counts towards your weekly aerobic minutes.",
    "Slow down or stop if you feel chest pain, dizziness or unusual breathlessness."])

ex("stationary_cycling", "Stationary Cycling", ["quads"], ["hamstrings", "glutes", "calves"],
   "gym", "Exercise bike", "beginner", "conditioning",
   True, "timed", True, "cardio_steady",
   ["Set the saddle height so your knee stays slightly bent at the bottom of the pedal stroke.",
    "Begin with a few easy minutes at low resistance.",
    "Raise the resistance or cadence until your breathing is faster but talking is still possible.",
    "Hold that effort for the planned time, then pedal easy to cool down."],
   ["Setting the saddle too low, which strains the knees.",
    "Rocking the hips side to side at high resistance."],
   ["Cycling is low impact and a good option for sore knees or heavier body weight.",
    "Stop if you feel chest pain, dizziness or severe breathlessness."])

ex("chair_sit_to_stand", "Chair Sit-to-Stand", ["quads", "glutes"], ["core"],
   "home", "A sturdy chair without wheels", "beginner", "squat",
   True, "bodyweight", True, "core_reps",
   ["Sit towards the front of a sturdy chair with your feet flat and about hip width apart.",
    "Lean your chest forward slightly and press your feet into the floor.",
    "Stand up fully without using your hands if you can.",
    "Lower yourself back down slowly under control."],
   ["Dropping back into the chair instead of lowering with control.",
    "Pushing off the knees with the hands when it is not needed."],
   ["Use the armrests for support when you need them; safety comes first.",
    "This is a strength and functional balance exercise well suited to older adults."])

ex("heel_to_toe_walk", "Heel-to-Toe Walk", ["core"], ["calves", "quads", "glutes"],
   "bodyweight", "A clear wall or rail to hold", "beginner", "balance",
   False, "timed", True, "balance_timed",
   ["Stand next to a wall or rail you can touch for support.",
    "Place one foot directly in front of the other so the heel almost touches the toes.",
    "Walk forward slowly in this straight line, looking ahead rather than down.",
    "Continue for the set time, turn carefully, and walk back."],
   ["Looking down at the feet, which makes balancing harder.",
    "Rushing and taking wide steps."],
   ["Always stay within arm's reach of a wall or rail.",
    "This is functional balance work, recommended for older adults alongside strength training."])

ex("single_leg_stand", "Single-Leg Stand", ["core"], ["glutes", "calves"],
   "bodyweight", "A clear wall or chair to hold", "beginner", "balance",
   False, "timed", True, "balance_timed",
   ["Stand near a wall or sturdy chair you can touch.",
    "Shift your weight onto one foot and lift the other foot slightly off the floor.",
    "Stand tall and hold the position, breathing steadily.",
    "Hold for the set time, then change legs."],
   ["Holding the breath while concentrating.",
    "Leaning heavily on the support rather than balancing."],
   ["Keep a hand close to the support at all times.",
    "Balance work helps prevent falls and is recommended for older adults on three or more days a week."])

ex("standing_march", "Standing March", ["full_body"], ["core", "quads", "hip_flexors"],
   "bodyweight", "None", "beginner", "conditioning",
   True, "bodyweight", True, "conditioning",
   ["Stand tall with your core braced and your arms bent at your sides.",
    "Lift one knee to a comfortable height while swinging the opposite arm.",
    "Lower that foot and lift the other knee.",
    "Keep a steady, controlled rhythm for the set time."],
   ["Leaning back as the knees come up.",
    "Rushing so the movement becomes untidy."],
   ["This is a low-impact warm-up and conditioning option with both feet never leaving the ground at once.",
    "Hold a wall for support if your balance is unsteady."])

# ---------------------------------------------------------------- write out
def main() -> None:
    ids = [e["id"] for e in EX]
    assert len(ids) == len(set(ids)), "duplicate exercise id"
    payload = {
        "dataset": "exercises",
        "description": (
            "Exercise library for TrainerApp. Every instruction, common mistake and "
            "safety note here was written for this app in plain language; no text is "
            "reproduced from any book, website or video. No images or videos are "
            "bundled, so the app hides the media area for every exercise. General "
            "safety guidance follows ICMR-NIN Dietary Guidelines for Indians 2024, "
            "which advises increasing intensity and duration gradually and treating "
            "pain, breathlessness, nausea or headache as a signal to stop and rest."
        ),
        "safetySourceId": "icmr_dgi_2024",
        "equipmentLevels": {
            "bodyweight": "Needs no equipment at all.",
            "home": "Needs only basic home kit such as dumbbells, a resistance band, a chair or a sturdy bench.",
            "gym": "Needs a barbell, cable stack, machine or other gym equipment.",
        },
        "repSchemeNote": (
            "Default sets and reps are given per goal. For exercises with loadType "
            "\"timed\", repsMin and repsMax are seconds per set rather than repetitions."
        ),
        "count": len(EX),
        "exercises": EX,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    from collections import Counter
    print(f"wrote {OUT} with {len(EX)} exercises")
    print("equipment:", dict(Counter(e["equipment"] for e in EX)))
    print("difficulty:", dict(Counter(e["difficulty"] for e in EX)))
    print("low impact:", sum(1 for e in EX if e["lowImpact"]))
    prim = Counter(m for e in EX for m in e["primaryMuscles"])
    print("primary muscles:", dict(sorted(prim.items())))
    print("patterns:", dict(sorted(Counter(e["pattern"] for e in EX).items())))
    # Every goal must have a usable scheme for every exercise.
    for e in EX:
        for goal in ("gain", "lose", "maintain"):
            d = e["defaults"][goal]
            assert d["sets"] >= 1 and 0 < d["repsMin"] <= d["repsMax"], (e["id"], goal)


if __name__ == "__main__":
    main()
