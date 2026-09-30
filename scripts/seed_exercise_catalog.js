const https = require("https");
const fs = require("fs");
const path = require("path");
const os = require("os");

const DRY_RUN = process.argv.includes("--dry-run");
const PROJECT_ID = "zynrto";
const COLLECTION = "exerciseCatalog";

function getAccessToken() {
  const cfgPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
  if (!fs.existsSync(cfgPath)) throw new Error("Run firebase login first.");
  const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
  const t = cfg.tokens;
  if (!t || !t.access_token) throw new Error("No access token.");
  if (t.expires_at && t.expires_at < Date.now()) throw new Error("Token expired. Run: firebase login --reauth");
  return t.access_token;
}

function normalize(name) { return name.toLowerCase().replace(/\s+/g, " ").trim(); }
function tokenize(n) { return n ? n.split(" ").filter(t => t.length > 0) : []; }

function toDoc(ex) {
  const norm = normalize(ex.name);
  return { fields: {
    name:          { stringValue: ex.name },
    normalizedName:{ stringValue: norm },
    searchTokens:  { arrayValue: { values: tokenize(norm).map(t => ({ stringValue: t })) } },
    muscleGroup:   { stringValue: ex.muscleGroup },
    equipment:     { stringValue: ex.equipment },
    isActive:      { booleanValue: true },
  }};
}

function patch(id, body, token) {
  return new Promise((resolve, reject) => {
    const json = JSON.stringify(body);
    const req = https.request({
      hostname: "firestore.googleapis.com",
      path: "/v1/projects/" + PROJECT_ID + "/databases/(default)/documents/" + COLLECTION + "/" + id,
      method: "PATCH",
      headers: {
        "Authorization": "Bearer " + token,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(json),
      },
    }, res => {
      let d = "";
      res.on("data", c => d += c);
      res.on("end", () => res.statusCode < 300 ? resolve() : reject(new Error("HTTP " + res.statusCode)));
    });
    req.on("error", reject);
    req.write(json);
    req.end();
  });
}

const exercises = [
  { id: "bench_press",             name: "Bench Press",              muscleGroup: "chest",     equipment: "Barbell"     },
  { id: "incline_bench_press",     name: "Incline Bench Press",      muscleGroup: "chest",     equipment: "Barbell"     },
  { id: "decline_bench_press",     name: "Decline Bench Press",      muscleGroup: "chest",     equipment: "Barbell"     },
  { id: "dumbbell_bench_press",    name: "Dumbbell Bench Press",     muscleGroup: "chest",     equipment: "Dumbbell"    },
  { id: "dumbbell_flyes",          name: "Dumbbell Flyes",           muscleGroup: "chest",     equipment: "Dumbbell"    },
  { id: "incline_dumbbell_flyes",  name: "Incline Dumbbell Flyes",   muscleGroup: "chest",     equipment: "Dumbbell"    },
  { id: "cable_crossover",         name: "Cable Crossover",          muscleGroup: "chest",     equipment: "Cables"      },
  { id: "cable_flyes",             name: "Cable Flyes",              muscleGroup: "chest",     equipment: "Cables"      },
  { id: "push_ups",                name: "Push-Ups",                 muscleGroup: "chest",     equipment: "Bodyweight"  },
  { id: "chest_dips",              name: "Chest Dips",               muscleGroup: "chest",     equipment: "Bodyweight"  },
  { id: "machine_chest_press",     name: "Machine Chest Press",      muscleGroup: "chest",     equipment: "Machine"     },
  { id: "pec_deck_fly",            name: "Pec Deck Fly",             muscleGroup: "chest",     equipment: "Machine"     },
  { id: "lat_pulldown",            name: "Lat Pulldown",             muscleGroup: "back",      equipment: "Cables"      },
  { id: "pull_ups",                name: "Pull-Ups",                 muscleGroup: "back",      equipment: "Pull-up Bar" },
  { id: "chin_ups",                name: "Chin-Ups",                 muscleGroup: "back",      equipment: "Pull-up Bar" },
  { id: "barbell_row",             name: "Barbell Row",              muscleGroup: "back",      equipment: "Barbell"     },
  { id: "dumbbell_row",            name: "Dumbbell Row",             muscleGroup: "back",      equipment: "Dumbbell"    },
  { id: "cable_row",               name: "Seated Cable Row",         muscleGroup: "back",      equipment: "Cables"      },
  { id: "t_bar_row",               name: "T-Bar Row",                muscleGroup: "back",      equipment: "Barbell"     },
  { id: "deadlift",                name: "Deadlift",                 muscleGroup: "back",      equipment: "Barbell"     },
  { id: "face_pulls",              name: "Face Pulls",               muscleGroup: "back",      equipment: "Cables"      },
  { id: "straight_arm_pulldown",   name: "Straight Arm Pulldown",    muscleGroup: "back",      equipment: "Cables"      },
  { id: "machine_row",             name: "Machine Row",              muscleGroup: "back",      equipment: "Machine"     },
  { id: "overhead_press",          name: "Overhead Press",           muscleGroup: "shoulders", equipment: "Barbell"     },
  { id: "dumbbell_shoulder_press", name: "Dumbbell Shoulder Press",  muscleGroup: "shoulders", equipment: "Dumbbell"    },
  { id: "arnold_press",            name: "Arnold Press",             muscleGroup: "shoulders", equipment: "Dumbbell"    },
  { id: "lateral_raises",          name: "Lateral Raises",           muscleGroup: "shoulders", equipment: "Dumbbell"    },
  { id: "front_raises",            name: "Front Raises",             muscleGroup: "shoulders", equipment: "Dumbbell"    },
  { id: "rear_delt_flyes",         name: "Rear Delt Flyes",          muscleGroup: "shoulders", equipment: "Dumbbell"    },
  { id: "cable_lateral_raises",    name: "Cable Lateral Raises",     muscleGroup: "shoulders", equipment: "Cables"      },
  { id: "upright_rows",            name: "Upright Rows",             muscleGroup: "shoulders", equipment: "Barbell"     },
  { id: "shrugs",                  name: "Shrugs",                   muscleGroup: "shoulders", equipment: "Barbell"     },
  { id: "machine_shoulder_press",  name: "Machine Shoulder Press",   muscleGroup: "shoulders", equipment: "Machine"     },
  { id: "barbell_curl",            name: "Barbell Curl",             muscleGroup: "biceps",    equipment: "Barbell"     },
  { id: "dumbbell_curl",           name: "Dumbbell Curl",            muscleGroup: "biceps",    equipment: "Dumbbell"    },
  { id: "hammer_curl",             name: "Hammer Curl",              muscleGroup: "biceps",    equipment: "Dumbbell"    },
  { id: "preacher_curl",           name: "Preacher Curl",            muscleGroup: "biceps",    equipment: "Barbell"     },
  { id: "concentration_curl",      name: "Concentration Curl",       muscleGroup: "biceps",    equipment: "Dumbbell"    },
  { id: "cable_curl",              name: "Cable Curl",               muscleGroup: "biceps",    equipment: "Cables"      },
  { id: "incline_dumbbell_curl",   name: "Incline Dumbbell Curl",    muscleGroup: "biceps",    equipment: "Dumbbell"    },
  { id: "ez_bar_curl",             name: "EZ Bar Curl",              muscleGroup: "biceps",    equipment: "Barbell"     },
  { id: "spider_curl",             name: "Spider Curl",              muscleGroup: "biceps",    equipment: "Dumbbell"    },
  { id: "tricep_pushdown",         name: "Tricep Pushdown",          muscleGroup: "triceps",   equipment: "Cables"      },
  { id: "skull_crushers",          name: "Skull Crushers",           muscleGroup: "triceps",   equipment: "Barbell"     },
  { id: "close_grip_bench_press",  name: "Close Grip Bench Press",   muscleGroup: "triceps",   equipment: "Barbell"     },
  { id: "tricep_dips",             name: "Tricep Dips",              muscleGroup: "triceps",   equipment: "Bodyweight"  },
  { id: "overhead_tricep_extension", name: "Overhead Tricep Extension", muscleGroup: "triceps", equipment: "Dumbbell"  },
  { id: "kickbacks",               name: "Tricep Kickbacks",         muscleGroup: "triceps",   equipment: "Dumbbell"    },
  { id: "diamond_push_ups",        name: "Diamond Push-Ups",         muscleGroup: "triceps",   equipment: "Bodyweight"  },
  { id: "rope_pushdown",           name: "Rope Pushdown",            muscleGroup: "triceps",   equipment: "Cables"      },
  { id: "squat",                   name: "Barbell Squat",            muscleGroup: "legs",      equipment: "Barbell"     },
  { id: "front_squat",             name: "Front Squat",              muscleGroup: "legs",      equipment: "Barbell"     },
  { id: "leg_press",               name: "Leg Press",                muscleGroup: "legs",      equipment: "Machine"     },
  { id: "lunges",                  name: "Lunges",                   muscleGroup: "legs",      equipment: "Dumbbell"    },
  { id: "bulgarian_split_squat",   name: "Bulgarian Split Squat",    muscleGroup: "legs",      equipment: "Dumbbell"    },
  { id: "leg_extension",           name: "Leg Extension",            muscleGroup: "legs",      equipment: "Machine"     },
  { id: "leg_curl",                name: "Leg Curl",                 muscleGroup: "legs",      equipment: "Machine"     },
  { id: "romanian_deadlift",       name: "Romanian Deadlift",        muscleGroup: "legs",      equipment: "Barbell"     },
  { id: "calf_raises",             name: "Calf Raises",              muscleGroup: "legs",      equipment: "Machine"     },
  { id: "goblet_squat",            name: "Goblet Squat",             muscleGroup: "legs",      equipment: "Dumbbell"    },
  { id: "hack_squat",              name: "Hack Squat",               muscleGroup: "legs",      equipment: "Machine"     },
  { id: "hip_thrust",              name: "Hip Thrust",               muscleGroup: "legs",      equipment: "Barbell"     },
  { id: "step_ups",                name: "Step-Ups",                 muscleGroup: "legs",      equipment: "Dumbbell"    },
  { id: "plank",                   name: "Plank",                    muscleGroup: "core",      equipment: "Bodyweight"  },
  { id: "crunches",                name: "Crunches",                 muscleGroup: "core",      equipment: "Bodyweight"  },
  { id: "hanging_leg_raises",      name: "Hanging Leg Raises",       muscleGroup: "core",      equipment: "Pull-up Bar" },
  { id: "cable_woodchops",         name: "Cable Woodchops",          muscleGroup: "core",      equipment: "Cables"      },
  { id: "ab_wheel_rollout",        name: "Ab Wheel Rollout",         muscleGroup: "core",      equipment: "Other"       },
  { id: "russian_twists",          name: "Russian Twists",           muscleGroup: "core",      equipment: "Bodyweight"  },
  { id: "dead_bug",                name: "Dead Bug",                 muscleGroup: "core",      equipment: "Bodyweight"  },
  { id: "mountain_climbers",       name: "Mountain Climbers",        muscleGroup: "core",      equipment: "Bodyweight"  },
  { id: "bicycle_crunches",        name: "Bicycle Crunches",         muscleGroup: "core",      equipment: "Bodyweight"  },
  { id: "side_plank",              name: "Side Plank",               muscleGroup: "core",      equipment: "Bodyweight"  },
  { id: "cable_crunch",            name: "Cable Crunch",             muscleGroup: "core",      equipment: "Cables"      },
];

async function main() {
  if (DRY_RUN) { exercises.forEach(e => console.log(e.id + " (" + e.muscleGroup + ")")); return; }
  const token = getAccessToken();
  console.log("Seeding", exercises.length, "exercises to", PROJECT_ID + "/" + COLLECTION, "...");
  let ok = 0, fail = 0;
  for (const ex of exercises) {
    try { await patch(ex.id, toDoc(ex), token); console.log("  v", ex.id); ok++; }
    catch (e) { console.error("  x", ex.id, "-", e.message); fail++; }
    await new Promise(r => setTimeout(r, 50));
  }
  console.log("\nDone: " + ok + " seeded, " + fail + " failed.");
}

main().catch(e => { console.error("FATAL:", e.message); process.exit(1); });
