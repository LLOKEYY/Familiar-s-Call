import rituals from "./daily_rituals.json" with { type: "json" };

const DUST_REWARD = 150;

export function utcDayKey(when = new Date()): string {
  return when.toISOString().slice(0, 10);
}

export function utcNowIso(): string {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

export function dustReward(): number {
  return DUST_REWARD;
}

async function stableSeedAsync(value: string): Promise<number> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  const hex = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return parseInt(hex.slice(0, 8), 16);
}

export async function pickRituals(dailyDay: string): Promise<string[]> {
  const cfg = rituals as {
    easy_ritual?: string;
    school_rotation?: Array<{ id?: string }>;
    varied_pool?: string[];
  };
  const easy = String(cfg.easy_ritual ?? "win_2_battles");
  const rotation = cfg.school_rotation ?? [];
  let schoolId = "win_field_pyromancy";
  if (rotation.length > 0) {
    const parts = dailyDay.split("-").map((p) => parseInt(p, 10));
    const [year, month, day] = parts;
    const index = (year * 372 + month * 31 + day) % rotation.length;
    schoolId = String(rotation[index]?.id ?? schoolId);
  }

  const removeIds = new Set<string>([easy, schoolId]);
  for (const entry of rotation) {
    if (entry?.id) removeIds.add(String(entry.id));
  }

  const variedPool = (cfg.varied_pool ?? []).filter((id) => !removeIds.has(id));
  let variedId = easy;
  if (variedPool.length > 0) {
    const seed = await stableSeedAsync(`${dailyDay}:varied`);
    variedId = variedPool[seed % variedPool.length];
  }
  return [easy, schoolId, variedId];
}

export function emptyCompleted(ritualIds: string[]): Record<string, boolean> {
  const out: Record<string, boolean> = {};
  for (const id of ritualIds) out[id] = false;
  return out;
}

export type DailyRow = {
  ritual_ids: string[];
  ritual_completed: Record<string, boolean>;
  daily_battle_wins: number;
  pack_claimed: boolean;
};

export function dailyPayload(
  dailyDay: string,
  state: DailyRow,
): Record<string, unknown> {
  return {
    ok: true,
    server_time_utc: utcNowIso(),
    daily_day: dailyDay,
    ritual_ids: state.ritual_ids,
    ritual_completed: state.ritual_completed,
    daily_battle_wins: state.daily_battle_wins,
    pack_claimed: state.pack_claimed,
    dust_reward: dustReward(),
  };
}
