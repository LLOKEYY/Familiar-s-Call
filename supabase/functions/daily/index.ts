import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  dailyPayload,
  emptyCompleted,
  pickRituals,
  utcDayKey,
  type DailyRow,
} from "../_shared/daily.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-display-name",
};

type Action =
  | "status"
  | "claim_pack"
  | "record_battle_win"
  | "complete_ritual";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: "Unauthorized" }, 401);
    }
    const userId = userData.user.id;

    const admin = createClient(supabaseUrl, serviceKey);
    const displayName = (req.headers.get("x-display-name") ?? "").trim();

    if (displayName) {
      await admin.from("profiles").upsert({
        id: userId,
        display_name: displayName,
      });
    } else {
      await admin.from("profiles").upsert({ id: userId });
    }

    let body: Record<string, unknown> = {};
    if (req.method === "POST") {
      try {
        body = await req.json();
      } catch {
        body = {};
      }
    }
    const action = String(body.action ?? "status") as Action;
    const dailyDay = utcDayKey();
    const ritualIds = await pickRituals(dailyDay);
    let state = await loadDailyState(admin, userId, dailyDay, ritualIds);

    switch (action) {
      case "status":
        break;

      case "claim_pack": {
        if (state.pack_claimed) {
          return json({ error: "Daily pack already claimed" }, 409);
        }
        state = await saveDailyState(admin, userId, dailyDay, {
          ...state,
          pack_claimed: true,
        });
        break;
      }

      case "record_battle_win": {
        state = await saveDailyState(admin, userId, dailyDay, {
          ...state,
          daily_battle_wins: state.daily_battle_wins + 1,
        });
        break;
      }

      case "complete_ritual": {
        const ritualId = String(body.ritual_id ?? "").trim();
        if (!ritualId) {
          return json({ error: "ritual_id required" }, 400);
        }
        if (!state.ritual_ids.includes(ritualId)) {
          return json({ error: "Ritual not active today" }, 400);
        }
        if (state.ritual_completed[ritualId]) {
          return json({ error: "Ritual already completed" }, 409);
        }
        const completed = { ...state.ritual_completed, [ritualId]: true };
        state = await saveDailyState(admin, userId, dailyDay, {
          ...state,
          ritual_completed: completed,
        });
        const payload = dailyPayload(dailyDay, state);
        payload.ritual_id = ritualId;
        payload.dust_granted = payload.dust_reward;
        return json(payload, 200);
      }

      default:
        return json({ error: "Unknown action" }, 400);
    }

    return json(dailyPayload(dailyDay, state), 200);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal error";
    return json({ error: message }, 500);
  }
});

async function loadDailyState(
  admin: ReturnType<typeof createClient>,
  userId: string,
  dailyDay: string,
  ritualIds: string[],
): Promise<DailyRow> {
  const { data, error } = await admin
    .from("daily_state")
    .select(
      "ritual_ids, ritual_completed, daily_battle_wins, pack_claimed",
    )
    .eq("user_id", userId)
    .eq("daily_day", dailyDay)
    .maybeSingle();

  if (error) throw error;

  if (!data) {
    const fresh: DailyRow = {
      ritual_ids: ritualIds,
      ritual_completed: emptyCompleted(ritualIds),
      daily_battle_wins: 0,
      pack_claimed: false,
    };
    await saveDailyState(admin, userId, dailyDay, fresh);
    return fresh;
  }

  const storedIds = (data.ritual_ids as string[]) ?? [];
  if (JSON.stringify(storedIds) !== JSON.stringify(ritualIds)) {
    const fresh: DailyRow = {
      ritual_ids: ritualIds,
      ritual_completed: emptyCompleted(ritualIds),
      daily_battle_wins: 0,
      pack_claimed: false,
    };
    await saveDailyState(admin, userId, dailyDay, fresh);
    return fresh;
  }

  return {
    ritual_ids: storedIds,
    ritual_completed: (data.ritual_completed as Record<string, boolean>) ?? {},
    daily_battle_wins: Number(data.daily_battle_wins ?? 0),
    pack_claimed: Boolean(data.pack_claimed),
  };
}

async function saveDailyState(
  admin: ReturnType<typeof createClient>,
  userId: string,
  dailyDay: string,
  state: DailyRow,
): Promise<DailyRow> {
  const { error } = await admin.from("daily_state").upsert({
    user_id: userId,
    daily_day: dailyDay,
    ritual_ids: state.ritual_ids,
    ritual_completed: state.ritual_completed,
    daily_battle_wins: state.daily_battle_wins,
    pack_claimed: state.pack_claimed,
  });
  if (error) throw error;
  return state;
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
