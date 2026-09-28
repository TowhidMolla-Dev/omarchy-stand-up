// Rotating stretch library for the Stand Up plugin.
//
// Each routine is three moves. `seconds` is the default hold time and gets
// replaced by the service's `moveSeconds` setting when the user picks a
// length, so the library only supplies the relative shape of a routine.
//
// Guidance is intentionally conservative: slow, pain-free, desk-friendly
// movements. Nothing here is a substitute for professional medical advice,
// and no move should ever be forced into pain.

var ROUTINES = [
  {
    id: "neck-shoulders",
    title: "Neck & Shoulders",
    focus: "Unwind the hunch from the keyboard",
    moves: [
      {
        name: "Chin Tucks",
        how: "Sit tall. Draw your chin straight back, as if making a double chin. Hold, keeping your gaze level. Release slowly.",
        seconds: 25
      },
      {
        name: "Ear to Shoulder",
        how: "Drop your right ear toward your right shoulder. Let the left shoulder sink. Breathe out. Switch sides halfway.",
        seconds: 30
      },
      {
        name: "Shoulder Rolls",
        how: "Roll both shoulders up, back and down in a slow circle. Reverse direction halfway through.",
        seconds: 30
      }
    ]
  },
  {
    id: "chest-upper-back",
    title: "Chest & Upper Back",
    focus: "Open up after hours of reaching forward",
    moves: [
      {
        name: "Doorway Chest Opener",
        how: "Stand and clasp your hands behind your lower back. Straighten your arms, lift your chest, and lean back a little. Breathe into your chest.",
        seconds: 35
      },
      {
        name: "Thoracic Twist",
        how: "Stand tall, feet hip-width. Put your right hand on your left shoulder and rotate gently to the right, keeping your hips facing forward. Switch halfway.",
        seconds: 30
      },
      {
        name: "Wall Angels",
        how: "Stand with your back near a wall, arms bent in a goalpost. Slowly slide your arms up and down the wall, keeping ribs down.",
        seconds: 30
      }
    ]
  },
  {
    id: "spine-posture",
    title: "Spine & Posture",
    focus: "Give your back a reset",
    moves: [
      {
        name: "Standing Forward Fold",
        how: "Stand and soften your knees. Hinge from the hips and let your upper body hang heavy. Let your head and arms be completely relaxed.",
        seconds: 30
      },
      {
        name: "Cat-Cow",
        how: "On all fours or standing hands-on-desk. Round your spine up toward the ceiling, then let it sag. Move with your breath.",
        seconds: 30
      },
      {
        name: "Side Bend",
        how: "Stand tall with arms overhead. Lean gently to one side, keeping both hips level. Switch halfway.",
        seconds: 25
      }
    ]
  },
  {
    id: "hips-legs",
    title: "Hips & Legs",
    focus: "Get the blood moving again",
    moves: [
      {
        name: "Standing Hip Flexor",
        how: "Take a half step forward with your right foot, back heel down, and tuck your pelvis under. You should feel a stretch at the front of the hip. Switch sides halfway.",
        seconds: 30
      },
      {
        name: "Calf Raises",
        how: "Stand tall, fingertips on the desk for balance. Rise onto your toes, pause at the top, lower slowly.",
        seconds: 30
      },
      {
        name: "Bodyweight Squats",
        how: "Stand with feet shoulder-width. Sit your hips back as if to an invisible chair, keep your chest up, and stand back up.",
        seconds: 30
      }
    ]
  },
  {
    id: "wrists-hands",
    title: "Wrists & Hands",
    focus: "Ease tension after long typing",
    moves: [
      {
        name: "Wrist Flexor Stretch",
        how: "Extend one arm forward, palm up. With the other hand, gently draw the fingers down and back. Keep the elbow soft. Switch halfway.",
        seconds: 25
      },
      {
        name: "Prayer Stretch",
        how: "Press your palms together at chest height, fingers up. Slowly lower your hands until you feel a stretch in your forearms.",
        seconds: 25
      },
      {
        name: "Finger Fans",
        how: "Spread your fingers wide and hold. Then slowly make a fist, one hand at a time, opening fully between each.",
        seconds: 25
      }
    ]
  },
  {
    id: "eyes-face",
    title: "Eyes & Face",
    focus: "A companion break to your 20-20-20 rule",
    moves: [
      {
        name: "Palming",
        how: "Rub your palms together until warm, then cup them over closed eyes without pressing on the eyeballs. Rest in the dark.",
        seconds: 30
      },
      {
        name: "Near-Far Focus",
        how: "Look at something an arm's length away for a few seconds, then at something across the room. Keep your head still and only move your eyes.",
        seconds: 30
      },
      {
        name: "Slow Blinks",
        how: "Close your eyes fully and open them slowly, one at a time. Aim for a complete blink every few seconds.",
        seconds: 25
      }
    ]
  },
  {
    id: "full-body",
    title: "Full Body Reset",
    focus: "The big one, when you have been sitting for hours",
    moves: [
      {
        name: "Overhead Reach",
        how: "Stand up and reach both arms overhead, fingers interlaced. Turn your palms to the ceiling and lengthen through your sides.",
        seconds: 30
      },
      {
        name: "Torso Side Reach",
        how: "Reach your right arm overhead and lean left, pressing your left palm gently away for a side-body stretch. Switch halfway.",
        seconds: 30
      },
      {
        name: "March in Place",
        how: "March steadily, lifting each knee to hip height. Swing your arms naturally and breathe deeply.",
        seconds: 40
      }
    ]
  },
  {
    id: "breathe-reset",
    title: "Breathe & Reset",
    focus: "Calm your nervous system before the next block",
    moves: [
      {
        name: "Box Breathing",
        how: "Breathe in through the nose for four counts, hold for four, out through the mouth for four, hold empty for four.",
        seconds: 40
      },
      {
        name: "Long Exhale",
        how: "Breathe in gently through the nose, then let the exhale take twice as long. Aim for a soft, sighing release.",
        seconds: 30
      },
      {
        name: "Shoulder Drop",
        how: "Inhale and lift your shoulders toward your ears. Exhale and let them fall away completely. Repeat slowly.",
        seconds: 25
      }
    ]
  }
];
