import socket
import threading
import json
import requests

from datetime import datetime, timedelta

user_logs = {}
user_checkins = {}
user_custom_exercises = {}

EXDB_BASE_URL = "https://exercisedb.p.rapidapi.com"

EXDB_API_KEY = "cbd28d34damsh2104400158a1cfcp139bfdjsnbe809da41701"   # ✅ 這裡填你的 key（跟 headers 用同一個）

EXDB_HEADERS = {
    "X-RapidAPI-Key": EXDB_API_KEY,
    "X-RapidAPI-Host": "exercisedb.p.rapidapi.com",
}

# 官方 GIF 服務的 URL 模板（ExerciseDB Image Service）
EXDB_IMAGE_URL_TEMPLATE = (
    f"{EXDB_BASE_URL}/image"
    f"?resolution=360"
    f"&rapidapi-key={EXDB_API_KEY}"
    f"&exerciseId={{id}}"
)

exercises_template = [
    {
        "id": 1,
        "name": "深蹲",
        "bodyPart": "legs",
        "baseWeight": 40,  # 之後可以改成 user-specific
        "minReps": 8,
        "maxReps": 10,
    },
    {
        "id": 2,
        "name": "臥推",
        "bodyPart": "chest",
        "baseWeight": 30,
        "minReps": 8,
        "maxReps": 10,
    },
    {
        "id": 3,
        "name": "硬舉",
        "bodyPart": "back",
        "baseWeight": 50,
        "minReps": 5,
        "maxReps": 8,
    },
]

exercise_index = {ex["id"]: ex for ex in exercises_template}

HOST = '0.0.0.0'  # 接受任意 IP 連線
PORT = 5000       # 之後 Flutter 要連這個 port

def search_exercises_exdb(name=None, body_part=None, limit=10):
    params = {
        "offset": 0,
        "limit": limit,
    }

    if name:
        url = f"{EXDB_BASE_URL}/exercises/name/{name}"
    elif body_part:
        url = f"{EXDB_BASE_URL}/exercises/bodyPart/{body_part}"
    else:
        url = f"{EXDB_BASE_URL}/exercises"

    r = requests.get(url, headers=EXDB_HEADERS, params=params, timeout=10)
    r.raise_for_status()
    data = r.json()

    simplified = []
    for item in data:
        ex_id = item.get("id")

        # ✅ 直接用官方 Image endpoint 組一個可以給 Image.network 用的網址
        gif_url = EXDB_IMAGE_URL_TEMPLATE.format(id=ex_id) if ex_id else None

        simplified.append(
            {
                "id": ex_id,
                "name": item.get("name"),
                "bodyPart": item.get("bodyPart"),
                "target": item.get("target"),
                "equipment": item.get("equipment"),
                "gifUrl": gif_url,
            }
        )

    print("[DEBUG] first item:", simplified[0] if simplified else "no data")
    return simplified

def handle_client(conn, addr):
    print(f"[CONNECTED] {addr}")
    buffer = ""

    try:
        while True:
            data = conn.recv(1024)
            if not data:
                break

            buffer += data.decode('utf-8')

            # 我們約定: 每一個 JSON 後面都加 '\n' 當分隔
            while '\n' in buffer:
                line, buffer = buffer.split('\n', 1)
                line = line.strip()
                if not line:
                    continue

                print(f"[RECV from {addr}] {line}")
                try:
                    req = json.loads(line)
                except json.JSONDecodeError:
                    resp = {"status": "error", "message": "invalid json"}
                    conn.sendall((json.dumps(resp) + "\n").encode('utf-8'))
                    continue

                action = req.get("action")

                # ----------- 簡單處理兩種 action -----------
                if action == "ping":
                    resp = {"status": "ok", "echo": "pong"}

                elif action == "login":
                    username = req.get("username")
                    password = req.get("password")

                    # 這邊先寫死：只要 username 不空就當作成功
                    if username:
                        resp = {
                            "status": "ok",
                            "action": "login",
                            "userId": 1,
                            "username": username
                        }
                    else:
                        resp = {
                            "status": "error",
                            "action": "login",
                            "message": "username required"
                        }

                elif action == "checkin":
                    user_id = req.get("userId")
                    sleep = int(req.get("sleep", 3))
                    fatigue = int(req.get("fatigue", 3))
                    soreness = int(req.get("soreness", 3))
                    stress = int(req.get("stress", 3))

                    fatigue_score = sleep + fatigue + soreness + stress

                    # 很粗略的建議：之後你可以再調整規則
                    if fatigue_score <= 8:
                        suggestion = "狀態不錯，可以照原本計畫訓練。"
                    elif fatigue_score <= 13:
                        suggestion = "有些疲勞，今天建議保守一點，重量先不要加太多。"
                    else:
                        suggestion = "狀態偏差，建議減量或改成輕鬆恢復訓練。"

                    # 記錄下來（之後可以配合 get_today_plan 使用）
                    user_checkins[user_id] = {
                        "time": datetime.now().isoformat(),
                        "sleep": sleep,
                        "fatigue": fatigue,
                        "soreness": soreness,
                        "stress": stress,
                        "score": fatigue_score,
                    }

                    resp = {
                        "status": "ok",
                        "action": "checkin",
                        "fatigueScore": fatigue_score,
                        "suggestion": suggestion,
                    }

                elif action == "get_today_plan":
                    user_id = req.get("userId")

                    today_str = datetime.now().date().isoformat()

                    # 讀取最近一次 checkin 的疲勞分數，如果沒有就給中間值 10
                    checkin = user_checkins.get(user_id)
                    if checkin:
                        score = checkin["score"]
                    else:
                        score = 10

                    # 根據疲勞分數調整「當日整體」重量係數
                    if score <= 8:
                        fatigue_factor = 1.0
                        note = "狀態良好，照原本計畫訓練。"
                    elif score <= 13:
                        fatigue_factor = 0.95
                        note = "中度疲勞，今天重量略降 5%。"
                    else:
                        fatigue_factor = 0.9
                        note = "狀態不佳，今天重量降 10%，以動作穩定為主。"

                    # 取出這個 user 的所有 log（之後用來算每個動作的「上一組」）
                    logs = user_logs.get(user_id, [])

                    # ===== ✅ 把「內建動作 + 自訂動作」合併成一份清單 =====
                    # user_custom_exercises 的結構：userId -> { ex_id: {name, bodyPart, baseWeight, minReps, maxReps, ...} }
                    custom_dict = user_custom_exercises.get(user_id, {})

                    all_exercises = []

                    # 1) 先放內建模板（原本的）
                    for ex in exercises_template:
                        all_exercises.append(ex)

                    # 2) 再把自訂動作轉成跟模板一樣的格式（補上 id 欄位）
                    for ex_id, info in custom_dict.items():
                        all_exercises.append({
                            "id": ex_id,
                            "name": info.get("name", ex_id),
                            "bodyPart": info.get("bodyPart"),
                            "baseWeight": float(info.get("baseWeight", 20.0)),
                            "minReps": int(info.get("minReps", 8)),
                            "maxReps": int(info.get("maxReps", 12)),
                        })

                    plan = []

                    # ===== ✅ 接下來的邏輯完全照你原本的，只是把迴圈對象換成 all_exercises =====
                    for ex in all_exercises:
                        ex_id = ex["id"]
                        base_weight = float(ex["baseWeight"])

                        # 找這個動作的所有 log
                        ex_logs = [entry for entry in logs if entry["exerciseId"] == ex_id]

                        last_weight = None
                        last_reps = None
                        last_difficulty = None

                        # 檢查「今天是否已經做過這個動作」
                        has_today_log = False
                        for entry in ex_logs:
                            try:
                                t = datetime.fromisoformat(entry["time"])
                                if t.date().isoformat() == today_str:
                                    has_today_log = True
                                    break
                            except Exception:
                                continue

                        # 有做過這個動作
                        if ex_logs:
                            # 依時間由新到舊排序，取最近一組當參考
                            ex_logs_sorted = sorted(
                                ex_logs,
                                key=lambda x: x["time"],
                                reverse=True,
                            )
                            last = ex_logs_sorted[0]
                            last_weight = float(last["weight"])
                            last_reps = int(last["reps"])
                            last_difficulty = int(last["difficulty"])

                            # 以上一組重量當基準
                            base = last_weight
                            adjust_factor = 1.0

                            max_reps = ex["maxReps"]
                            if last_difficulty <= 2 and last_reps >= max_reps:
                                adjust_factor = 1.05  # +5%
                            elif last_difficulty >= 4:
                                adjust_factor = 0.95  # -5%

                            suggested_weight = base * adjust_factor

                        # 第一次做這個動作：用 baseWeight 當起點，稍微保守一點
                        else:
                            suggested_weight = base_weight * 0.9  # 第一次稍微降 10%

                        # ✅ 疲勞係數只在「今天還沒做過這個動作」時套用
                        if has_today_log:
                            effective_factor = 1.0
                        else:
                            effective_factor = fatigue_factor

                        suggested_weight *= effective_factor

                        # 讓數字看起來漂亮一點（四捨五入到 0.5 kg）
                        suggested_weight = round(suggested_weight * 2) / 2.0

                        plan.append({
                            "id": ex_id,
                            "name": ex["name"],
                            "bodyPart": ex["bodyPart"],
                            "minReps": ex["minReps"],
                            "maxReps": ex["maxReps"],
                            "suggestedWeight": suggested_weight,
                            "lastWeight": last_weight,
                            "lastReps": last_reps,
                            "lastDifficulty": last_difficulty,
                        })

                    resp = {
                        "status": "ok",
                        "action": "get_today_plan",
                        "fatigueScore": score,
                        "note": note,
                        "plan": plan,
                    }


                elif action == "log_set":
                    user_id = req.get("userId")
                    ex_id = req.get("exerciseId")
                    weight = float(req.get("weight", 0))
                    reps = int(req.get("reps", 0))
                    difficulty = int(req.get("difficulty", 3))

                    logs = user_logs.setdefault(user_id, [])

                    # 送出這一組之前，先查這個動作的歷史最佳重量
                    prev_best = 0.0
                    for entry in logs:
                        if entry["exerciseId"] == ex_id:
                            if float(entry["weight"]) > prev_best:
                                prev_best = float(entry["weight"])

                    log = {
                        "time": datetime.now().isoformat(),
                        "exerciseId": ex_id,
                        "weight": weight,
                        "reps": reps,
                        "difficulty": difficulty,
                    }
                    logs.append(log)

                    # 判斷是否為 PR（嚴格 > 之前最佳）
                    is_pr = weight > prev_best and weight > 0

                    resp = {
                        "status": "ok",
                        "action": "log_set",
                        "message": "set logged",
                        "isPr": is_pr,
                        "prevBest": prev_best,
                    }

                elif action == "get_history":
                    user_id = req.get("userId")

                    logs = user_logs.get(user_id, [])

                    # 依時間由新到舊排序
                    sorted_logs = sorted(
                        logs,
                        key=lambda x: x["time"],
                        reverse=True,
                    )

                    resp_items = []
                    for entry in sorted_logs:
                        ex = exercise_index.get(entry["exerciseId"], {})
                        resp_items.append({
                            "time": entry["time"],
                            "exerciseId": entry["exerciseId"],
                            "exerciseName": ex.get("name", "Unknown"),
                            "bodyPart": ex.get("bodyPart", ""),
                            "weight": entry["weight"],
                            "reps": entry["reps"],
                            "difficulty": entry["difficulty"],
                        })

                    resp = {
                        "status": "ok",
                        "action": "get_history",
                        "items": resp_items,
                    }

                elif action == "get_summary":
                    user_id = req.get("userId")
                    logs = user_logs.get(user_id, [])

                    total_sets = len(logs)
                    total_volume = 0.0

                    # 近 7 天訓練量
                    now = datetime.now()
                    cutoff = now - timedelta(days=7)
                    recent_volume = 0.0

                    # 每個動作的統計
                    # exerciseId -> dict
                    ex_stats = {}

                    for entry in logs:
                        weight = float(entry["weight"])
                        reps = int(entry["reps"])
                        volume = weight * reps
                        total_volume += volume

                        # 處理時間字串
                        try:
                            t = datetime.fromisoformat(entry["time"])
                        except Exception:
                            t = now  # 如果解析失敗就算今天

                        if t >= cutoff:
                            recent_volume += volume

                        ex_id = entry["exerciseId"]
                        ex = exercise_index.get(ex_id, {})
                        stat = ex_stats.setdefault(ex_id, {
                            "exerciseId": ex_id,
                            "name": ex.get("name", "Unknown"),
                            "bodyPart": ex.get("bodyPart", ""),
                            "sets": 0,
                            "bestWeight": 0.0,
                            "totalVolume": 0.0,
                        })
                        stat["sets"] += 1
                        stat["totalVolume"] += volume
                        if weight > stat["bestWeight"]:
                            stat["bestWeight"] = weight

                    resp = {
                        "status": "ok",
                        "action": "get_summary",
                        "totalSets": total_sets,
                        "totalVolume": round(total_volume, 1),
                        "recent7DaysVolume": round(recent_volume, 1),
                        "exerciseStats": list(ex_stats.values()),
                    }

                elif action == "search_exercises":
                    name = req.get("query") or None
                    body_part = req.get("bodyPart") or None

                    try:
                        results = search_exercises_exdb(
                            name=name,
                            body_part=body_part,
                        )
                        resp = {
                            "status": "ok",
                            "action": "search_exercises",
                            "results": results,
                        }
                    except Exception as e:
                        print(f"[ERROR] search_exercises: {e}")
                        resp = {
                            "status": "error",
                            "action": "search_exercises",
                            "message": "查詢運動資料庫失敗，請稍後再試",
                        }

                elif action == "add_exercise_from_api":
                    user_id = req.get("userId")
                    if not user_id:
                        resp = {
                            "status": "error",
                            "action": "add_exercise_from_api",
                            "message": "尚未登入",
                        }
                    else:
                        ex_id = req.get("id")
                        name = req.get("name")
                        body_part = req.get("bodyPart")
                        target = req.get("target")
                        equipment = req.get("equipment")

                        if not ex_id or not name:
                            resp = {
                                "status": "error",
                                "action": "add_exercise_from_api",
                                "message": "缺少必要欄位 id 或 name",
                            }
                        else:
                            # 先給一個合理的 baseWeight、reps 範圍（可以之後再調）
                            base_weight = 20.0  # 先保守一點
                            min_reps = 8
                            max_reps = 12

                            user_custom_exercises.setdefault(user_id, {})

                            user_custom_exercises[user_id][ex_id] = {
                                "name": name,
                                "bodyPart": body_part,
                                "target": target,
                                "equipment": equipment,
                                "baseWeight": base_weight,
                                "minReps": min_reps,
                                "maxReps": max_reps,
                            }

                            resp = {
                                "status": "ok",
                                "action": "add_exercise_from_api",
                                "exerciseId": ex_id,
                                "name": name,
                            }
                    
                else:
                    resp = {
                        "status": "error",
                        "message": f"unknown action: {action}"
                    }

                conn.sendall((json.dumps(resp) + "\n").encode('utf-8'))

    finally:
        print(f"[DISCONNECTED] {addr}")
        conn.close()


def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind((HOST, PORT))
    server.listen(5)
    print(f"[LISTENING] TCP server on port {PORT}")

    while True:
        conn, addr = server.accept()
        t = threading.Thread(target=handle_client, args=(conn, addr), daemon=True)
        t.start()


if __name__ == "__main__":
    main()
