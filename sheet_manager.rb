require "google_drive"
require "date"

class SheetManager
  USER_SHEET     = "사용자"
  STAT_SHEET     = "스탯"
  ACTIVITY_SHEET = "활동"
  CAT_SHEET      = "카피캣"
  COLONY_SHEET   = "군체"
  HOUSE_SHEET    = "기숙사"
  LOG_SHEET      = "로그"

  # 사용자 시트 컬럼 (1-based, google_drive gem)
  # A(1)=ID / B(2)=이름 / C(3)=크레딧 / D(4)=아이템 / E(5)=기숙사
  # F(6)=마지막베팅일 / G(7)=오늘베팅횟수 / H(8)=마지막타로일
  # I(9)=누적툿수 / J(10)=정산기준툿수 / K(11)=스탯포인트잔여
  # L(12)=출석날짜 / M(13)=과제날짜 / N(14)=활동날짜

  # 스탯 시트 컬럼 (1-based)
  # A(1)=ID / B(2)=이름 / C(3)=기숙사 / D(4)=패시브선택
  # E(5)=건강 / F(6)=내구도 / G(7)=마법능력 / H(8)=민첩
  # I(9)=기술 / J(10)=행운

  STAT_COLUMNS = {
    "건강"     => 5,
    "내구도"   => 6,
    "마법능력" => 7,
    "민첩"     => 8,
    "기술"     => 9,
    "행운"     => 10,
    "최대건강" => 11
  }.freeze

  STAT_ALIASES = {
    "인내" => "내구도",
    "속도" => "민첩"
  }.freeze

  # 활동 시트 컬럼 (1-based)
  # A(1)=종류 / B(2)=활동명 / C(3)=요일 / D(4)=크레딧
  # E(5)=관련스탯1 / F(6)=관련스탯2 / G(7)=난이도
  # H(8)=성공스탯보상 / I(9)=대성공배율 / J(10)=성공배율
  # K(11)=실패배율 / L(12)=대실패배율 / M(13)=출력문구

  # 군체 시트 컬럼 (1-based) — 개인별 구조
  # A(1)=ID / B(2)=캐릭터명 / C(3)=카피캣명
  # D(4)=애정총합 / E(5)=공격성총합 / F(6)=안정총합 / G(7)=기묘함총합 / H(8)=???총합
  # I(9)=현재군체 / J(10)=단계 / K(11)=출력문구

  # 기숙사 시트 컬럼 (1-based)
  # A(1)=기숙사명 / B(2)=점수

  def initialize
    session = GoogleDrive::Session.from_service_account_key(
      ENV.fetch("GOOGLE_CREDENTIALS_PATH")
    )
    @spreadsheet = session.spreadsheet_by_key(ENV.fetch("SPREADSHEET_KEY"))
    @worksheet_cache = {}
    @row_cache = {}
  end

  def worksheet(name)
    @worksheet_cache[name] ||= with_retry("시트 열기 #{name}") do
      ws = @spreadsheet.worksheet_by_title(name)
      raise "시트 탭을 찾을 수 없습니다: #{name}" unless ws
      ws
    end
  end

  def today
    Date.today.strftime("%Y-%m-%d")
  end

  def now_string
    Time.now.strftime("%Y-%m-%d %H:%M:%S")
  end

  def find_row(sheet_name, column_index, value)
    ws = worksheet(sheet_name)
    target = normalize_account(value)

    rows = with_retry("읽기 #{sheet_name}") { ws.rows }
    rows.each_with_index do |row_data, index|
      next if index.zero?
      return index + 1 if normalize_account(row_data[column_index - 1]) == target
    end

    nil
  end

  # 등록 여부 판정의 기준값이므로 캐시된 worksheet가 아니라 서버의 현재
  # 상태를 매번 새로 읽는다. (다른 봇/프로세스가 방금 등록시킨 사용자를
  # 이 프로세스가 오래된 캐시 때문에 "미등록"으로 오판하는 사고 방지)
  def user_row(account)
    normalized = normalize_account(account)
    ws  = fresh_worksheet(USER_SHEET)
    row = find_row_in_worksheet(ws, 1, normalized)
    @worksheet_cache[USER_SHEET] = ws
    if row
      @row_cache[[:user, normalized]] = row
    else
      @row_cache.delete([:user, normalized])
    end
    row
  end

  def cat_row(account)
    cached_row(:cat, account) { find_row(CAT_SHEET, 1, account) }
  end

  def stat_row(account)
    cached_row(:stat, account) { find_row(STAT_SHEET, 1, account) }
  end

  def registered?(account)
    !!user_row(account)
  end

  # ─────────────────────────────────────────────
  # 등록
  # ─────────────────────────────────────────────
  def register_user(account, name)
    return false if registered?(account)

    ws  = worksheet(USER_SHEET)
    row = ws.num_rows + 1

    ws[row, 1]  = account  # ID
    ws[row, 2]  = name     # 이름
    ws[row, 3]  = "20"     # 크레딧 초기값
    ws[row, 4]  = ""       # 아이템
    ws[row, 5]  = ""       # 기숙사
    ws[row, 6]  = ""       # 마지막베팅일
    ws[row, 7]  = "0"      # 오늘베팅횟수
    ws[row, 8]  = ""       # 마지막타로일
    ws[row, 9]  = "0"      # 누적툿수
    ws[row, 10] = "0"      # 정산기준툿수
    ws[row, 11] = "10"     # 스탯포인트잔여 (신청 기간 10pt)
    ws[row, 12] = ""       # 출석날짜
    ws[row, 13] = ""       # 과제날짜
    save!(ws)

    create_default_stats(account, name)
    create_default_cat(account, name)
    clear_account_row_cache(account)

    true
  end

  def create_default_stats(account, name)
    ws  = worksheet(STAT_SHEET)
    row = ws.num_rows + 1

    ws[row, 1]  = account  # ID
    ws[row, 2]  = name     # 이름
    ws[row, 3]  = ""       # 기숙사
    ws[row, 4]  = ""       # 패시브선택
    ws[row, 5]  = "50"     # 건강
    ws[row, 6]  = "10"     # 내구도
    ws[row, 7]  = "10"     # 마법능력
    ws[row, 8]  = "0"      # 민첩
    ws[row, 9]  = "0"      # 기술
    ws[row, 10] = "5"      # 행운
    save!(ws)
    clear_account_row_cache(account)
  end

  def create_default_cat(account, name)
    ws  = worksheet(CAT_SHEET)
    row = ws.num_rows + 1

    ws[row, 1]  = account
    ws[row, 2]  = name
    ws[row, 3]  = "#{name}의 카피캣"
    ws[row, 4]  = "0"   # 친밀도
    ws[row, 5]  = "0"   # 허기
    ws[row, 6]  = "0"   # 애정
    ws[row, 7]  = "0"   # 공격성
    ws[row, 8]  = "0"   # 안정
    ws[row, 9]  = "0"   # 기묘함
    ws[row, 10] = "0"   # ???
    ws[row, 11] = ""    # 마지막먹이일
    ws[row, 12] = "새끼"
    ws[row, 13] = "아직 당신을 따라 하는 법을 배우는 중입니다."
    save!(ws)
    clear_account_row_cache(account)
  end

  # ─────────────────────────────────────────────
  # 사용자
  # ─────────────────────────────────────────────
  def user_name(account)
    row = user_row(account)
    return nil unless row
    worksheet(USER_SHEET)[row, 2]
  end

  def get_credit(account)
    row = user_row(account)
    return 0 unless row
    worksheet(USER_SHEET)[row, 3].to_i
  end

  def add_credit(account, amount)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, 3] = (ws[row, 3].to_i + amount.to_i).to_s
    save!(ws)
  end

  def get_toot_baseline(account)
    normalized = normalize_account(account)
    ws  = fresh_worksheet(USER_SHEET)
    row = find_row_in_worksheet(ws, 1, normalized)
    return 0 unless row
    @worksheet_cache[USER_SHEET] = ws
    @row_cache[[:user, normalized]] = row
    ws[row, 10].to_i
  end

  def set_toot_baseline(account, value)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, 10] = value.to_i.to_s
    save!(ws)
  end

  # 크레딧(C열)과 툿정산 기준(J열)을 한 번의 저장으로 함께 반영한다.
  #
  # 툿정산 직전에 사용자 시트를 새로 가져와 다른 봇이 반영한 최신 크레딧을
  # 기준으로 계산한다. 저장 후에도 다시 읽어 실제 반영값을 검증한다.
  def settle_toot_credit(account, expected_baseline, new_baseline, reward, status_id = nil)
    normalized_account = normalize_account(account)

    # 캐시된 worksheet의 오래된 셀 값을 사용하지 않도록 서버에서 새로 가져온다.
    ws = fresh_worksheet(USER_SHEET)
    row = find_row_in_worksheet(ws, 1, normalized_account)

    unless row
      warn "[툿정산 중단] status_id=#{status_id} account=#{account} 사용자 행을 찾을 수 없음"
      return false
    end

    current_credit   = ws[row, 3].to_i
    current_baseline = ws[row, 10].to_i
    expected         = expected_baseline.to_i
    target_baseline  = new_baseline.to_i
    reward_amount    = reward.to_i

    puts(
      "[툿정산 시작] status_id=#{status_id} account=#{account} row=#{row} " \
      "credit=#{current_credit} baseline=#{current_baseline} " \
      "expected=#{expected} reward=#{reward_amount} new_baseline=#{target_baseline}"
    )

    # 명령 계산 후 저장 사이에 다른 정산이 먼저 반영됐다면 중복 지급을 막는다.
    if current_baseline != expected
      warn(
        "[툿정산 중단] status_id=#{status_id} account=#{account} " \
        "baseline_changed=#{expected}->#{current_baseline}"
      )
      return false
    end

    return false if reward_amount <= 0
    return false if target_baseline <= current_baseline

    target_credit = current_credit + reward_amount

    ws[row, 3]  = target_credit.to_s
    ws[row, 10] = target_baseline.to_s
    save!(ws)

    # 저장 결과를 새 worksheet 객체로 다시 읽어서 검증한다.
    verify_ws = fresh_worksheet(USER_SHEET)
    verify_row = find_row_in_worksheet(verify_ws, 1, normalized_account)

    unless verify_row
      warn "[툿정산 검증 실패] status_id=#{status_id} account=#{account} 사용자 행을 찾을 수 없음"
      return false
    end

    saved_credit   = verify_ws[verify_row, 3].to_i
    saved_baseline = verify_ws[verify_row, 10].to_i
    success = saved_credit == target_credit && saved_baseline == target_baseline

    puts(
      "[툿정산 결과] status_id=#{status_id} account=#{account} " \
      "credit=#{current_credit}->#{saved_credit} " \
      "baseline=#{current_baseline}->#{saved_baseline} success=#{success}"
    )

    # 이후 다른 메서드도 검증된 최신 worksheet를 재사용하게 한다.
    @worksheet_cache[USER_SHEET] = verify_ws
    @row_cache[[:user, normalized_account]] = verify_row

    success
  rescue => e
    warn(
      "[툿정산 오류] status_id=#{status_id} account=#{account} " \
      "#{e.class}: #{e.message}"
    )
    warn e.backtrace.first(5).join("\n")
    false
  end

  def add_reputation(account, amount)
    # 현재 시트에 평판 컬럼 없음 — 기숙사 점수로 대체 예정이므로 로그만 기록
    log(account, "평판", "+#{amount}")
  end

  def get_last_date(account, column)
    row = user_row(account)
    return nil unless row
    worksheet(USER_SHEET)[row, column].to_s
  end

  def set_last_date(account, column, value = today)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, column] = value
    save!(ws)
  end

  def get_stat_points(account)
    row = user_row(account)
    return 0 unless row
    worksheet(USER_SHEET)[row, 11].to_i
  end

  def set_stat_points(account, value)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, 11] = value.to_s
    save!(ws)
  end

  def get_bet_info(account)
    row = user_row(account)
    return { last_date: nil, count: 0 } unless row
    ws = worksheet(USER_SHEET)
    { last_date: ws[row, 6].to_s, count: ws[row, 7].to_i }
  end

  def set_bet_info(account, date:, count:)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, 6] = date
    ws[row, 7] = count.to_s
    save!(ws)
  end

  def get_tarot_date(account)
    row = user_row(account)
    return nil unless row
    worksheet(USER_SHEET)[row, 8].to_s
  end

  def set_tarot_date(account, date = today)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, 8] = date
    save!(ws)
  end

  def remove_item(account, item_name)
    normalized = normalize_account(account)
    ws  = fresh_worksheet(USER_SHEET)
    row = find_row_in_worksheet(ws, 1, normalized)
    return false unless row
    @worksheet_cache[USER_SHEET] = ws
    @row_cache[[:user, normalized]] = row

    items  = ws[row, 4].to_s.split(",").map(&:strip).reject(&:empty?)
    target = item_name.to_s.strip
    index  = items.index(target)
    return false unless index

    items.delete_at(index)
    ws[row, 4] = items.join(",")
    save!(ws)
    true
  end

  def get_items(account)
    row = user_row(account)
    return [] unless row
    worksheet(USER_SHEET)[row, 4].to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def set_items(account, items_array)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, 4] = items_array.join(",")
    save!(ws)
  end

  def get_house(account)
    row = user_row(account)
    return nil unless row
    worksheet(USER_SHEET)[row, 5].to_s.strip
  end

  # ─────────────────────────────────────────────
  # 스탯
  # ─────────────────────────────────────────────
  def stats(account)
    row = stat_row(account)
    return {} unless row

    ws = worksheet(STAT_SHEET)
    health = ws[row, 5].to_i
    endurance = ws[row, 6].to_i
    magic = ws[row, 7].to_i
    agility = ws[row, 8].to_i
    skill = ws[row, 9].to_i
    luck = ws[row, 10].to_i

    {
      "건강"     => health,
      "내구도"   => endurance,
      "인내"     => endurance,
      "마법능력" => magic,
      "민첩"     => agility,
      "속도"     => agility,
      "기술"     => skill,
      "행운"     => luck
    }
  end

  def add_stat(account, stat_name, amount)
    amount = amount.to_i
    return true if amount.zero?

    normalized_name = STAT_ALIASES.fetch(stat_name.to_s.strip, stat_name.to_s.strip)
    col = STAT_COLUMNS[normalized_name]

    unless col
      puts "[ADD_STAT 오류] 스탯 컬럼을 찾을 수 없습니다: #{stat_name.inspect}"
      return false
    end

    row = stat_row(account)

    unless row
      puts "[ADD_STAT 오류] 스탯 탭에서 사용자를 찾을 수 없습니다: #{account.inspect}"
      return false
    end

    ws = worksheet(STAT_SHEET)
    before = ws[row, col].to_i
    after = before + amount

    ws[row, col] = after.to_s
    save!(ws)

    puts "[ADD_STAT 완료] #{account.inspect} / #{normalized_name} / #{before} -> #{after}"
    true
  rescue StandardError => e
    puts "[ADD_STAT 예외] #{e.class}: #{e.message}"
    puts e.backtrace.first(10).join("\n")
    false
  end

  def set_stat(account, stat_name, value)
    normalized_name = STAT_ALIASES.fetch(stat_name.to_s.strip, stat_name.to_s.strip)
    col = STAT_COLUMNS[normalized_name]
    return false unless col

    row = stat_row(account)
    return false unless row

    ws = worksheet(STAT_SHEET)
    ws[row, col] = value.to_i.to_s
    save!(ws)
    true
  rescue StandardError => e
    puts "[SET_STAT 예외] #{e.class}: #{e.message}"
    false
  end

  # ─────────────────────────────────────────────
  # 활동
  # 시트 컬럼: A=종류, B=활동명, C=요일, D=크레딧,
  #            E=관련스탯1, F=관련스탯2, G=난이도,
  #            H=성공스탯보상, I=대성공배율, J=성공배율,
  #            K=실패배율, L=대실패배율, M=출력문구
  # ─────────────────────────────────────────────
  def find_activity(kind, name)
    with_retry("활동 조회 #{kind}/#{name}") do
      ws = worksheet(ACTIVITY_SHEET)
      result = nil
      (2..ws.num_rows).each do |row|
        next unless ws[row, 1].to_s.strip == kind
        next unless normalize(ws[row, 2]) == normalize(name)

        result = {
          row:             row,
          kind:            ws[row, 1].to_s,
          name:            ws[row, 2].to_s,
          days:            ws[row, 3].to_s,
          base_credit:     ws[row, 4].to_i,
          stat1:           ws[row, 5].to_s.strip,
          stat2:           ws[row, 6].to_s.strip,
          difficulty:      ws[row, 7].to_i,
          stat_reward:     ws[row, 8].to_s.strip,   # 예: "평판+1"
          great_success_m: parse_float(ws[row, 9],  1.5),
          success_m:       parse_float(ws[row, 10], 1.0),
          failure_m:       parse_float(ws[row, 11], 0.5),
          great_failure_m: parse_float(ws[row, 12], 0.3),
          message:         ws[row, 13].to_s.strip
        }
        break
      end
      result
    end
  end

  # ─────────────────────────────────────────────
  # 활동 일자 기록
  # 사용자 시트 N(14)열에 "종류=날짜;종류=날짜" 형식으로 저장
  # ─────────────────────────────────────────────
  def get_activity_last_date(account, kind)
    normalized = normalize_account(account)
    ws  = fresh_worksheet(USER_SHEET)
    row = find_row_in_worksheet(ws, 1, normalized)
    return nil unless row
    @worksheet_cache[USER_SHEET] = ws
    @row_cache[[:user, normalized]] = row
    raw = ws[row, 14].to_s
    raw.split(";").each do |pair|
      k, v = pair.split("=", 2)
      return v.to_s.strip if k.to_s.strip == kind.to_s.strip
    end
    nil
  end

  def set_activity_last_date(account, kind, date = today)
    row = user_row(account)
    return unless row
    ws  = worksheet(USER_SHEET)
    raw = ws[row, 14].to_s

    entries = {}
    raw.split(";").each do |pair|
      k, v = pair.split("=", 2)
      entries[k.to_s.strip] = v.to_s.strip unless k.to_s.strip.empty?
    end
    entries[kind.to_s.strip] = date

    ws[row, 14] = entries.map { |k, v| "#{k}=#{v}" }.join(";")
    save!(ws)
  end

  # ─────────────────────────────────────────────
  # 카피캣
  # ─────────────────────────────────────────────
  def cat(account)
    normalized = normalize_account(account)
    ws  = fresh_worksheet(CAT_SHEET)
    row = find_row_in_worksheet(ws, 1, normalized)
    return nil unless row
    @worksheet_cache[CAT_SHEET] = ws
    @row_cache[[:cat, normalized]] = row
    {
      row:           row,
      account:       ws[row, 1].to_s,
      character:     ws[row, 2].to_s,
      name:          ws[row, 3].to_s,
      intimacy:      ws[row, 4].to_i,
      hunger:        ws[row, 5].to_i,
      affection:     ws[row, 6].to_i,
      aggression:    ws[row, 7].to_i,
      stability:     ws[row, 8].to_i,
      weirdness:     ws[row, 9].to_i,
      unknown:       ws[row, 10].to_i,
      last_feed:     ws[row, 11].to_s,
      stage:         ws[row, 12].to_s,
      last_reaction: ws[row, 13].to_s
    }
  end

  def set_cat_name(account, cat_name)
    row = cat_row(account)
    return unless row
    ws = worksheet(CAT_SHEET)
    ws[row, 3] = cat_name
    save!(ws)
  end

  def update_cat(account, changes)
    normalized = normalize_account(account)
    ws  = fresh_worksheet(CAT_SHEET)
    row = find_row_in_worksheet(ws, 1, normalized)
    return unless row
    @worksheet_cache[CAT_SHEET] = ws
    @row_cache[[:cat, normalized]] = row

    column_map = {
      intimacy:      4,
      hunger:        5,
      affection:     6,
      aggression:    7,
      stability:     8,
      weirdness:     9,
      unknown:       10,
      last_feed:     11,
      stage:         12,
      last_reaction: 13
    }

    changes.each do |key, value|
      col = column_map[key]
      next unless col
      if [:last_feed, :stage, :last_reaction].include?(key)
        ws[row, col] = value.to_s
      else
        new_value = ws[row, col].to_i + value.to_i
        ws[row, col] = [new_value, 0].max.to_s
      end
    end
    save!(ws)

    sync_colony_member(account)
  end

  # ─────────────────────────────────────────────
  # 군체 (개인별 구조)
  # A=ID / B=캐릭터명 / C=카피캣명
  # D=애정총합 / E=공격성총합 / F=안정총합 / G=기묘함총합 / H=???총합
  # I=현재군체 / J=단계 / K=출력문구
  # ─────────────────────────────────────────────
  def sync_colony_member(account)
    cat_data = cat(account)
    return unless cat_data

    ws = worksheet(COLONY_SHEET)

    member_row = nil
    (2..ws.num_rows).each do |r|
      if ws[r, 1].to_s.strip == account.to_s.strip
        member_row = r
        break
      end
    end
    member_row ||= ws.num_rows + 1

    traits = {
      affection:  cat_data[:affection],
      aggression: cat_data[:aggression],
      stability:  cat_data[:stability],
      weirdness:  cat_data[:weirdness],
      unknown:    cat_data[:unknown]
    }

    current = member_colony(traits)
    stage   = member_stage(traits)
    message = member_message(current)

    ws[member_row, 1]  = account
    ws[member_row, 2]  = cat_data[:character]
    ws[member_row, 3]  = cat_data[:name]
    ws[member_row, 4]  = traits[:affection].to_s
    ws[member_row, 5]  = traits[:aggression].to_s
    ws[member_row, 6]  = traits[:stability].to_s
    ws[member_row, 7]  = traits[:weirdness].to_s
    ws[member_row, 8]  = traits[:unknown].to_s
    ws[member_row, 9]  = current
    ws[member_row, 10] = stage
    ws[member_row, 11] = message
    save!(ws)
  rescue => e
    puts "[sync_colony_member 오류] #{e.class}: #{e.message}"
  end

  def member_colony(traits)
    return "미분화" if traits.values.all?(&:zero?)

    {
      "따르는 군체"   => traits[:affection],
      "사냥하는 군체" => traits[:aggression],
      "웅크린 군체"   => traits[:stability],
      "흉내내는 군체" => traits[:weirdness],
      "방문하는 군체" => traits[:unknown]
    }.max_by { |_k, v| v }[0]
  end

  def member_stage(traits)
    total = traits.values.sum

    case total
    when 0..19 then "잠복"
    when 20..49 then "형성"
    when 50..99 then "성장"
    else "방문"
    end
  end

  def member_message(current)
    case current
    when "따르는 군체"
      "그것들은 우리를 좋아하는 방식부터 배웠습니다."
    when "사냥하는 군체"
      "그것들은 움직이는 것을 놓치지 않습니다."
    when "웅크린 군체"
      "그것들은 기다립니다. 아주 오래 기다릴 수 있습니다."
    when "흉내내는 군체"
      "그것들은 이제 울음소리보다 말소리에 가깝습니다."
    when "방문하는 군체"
      "그것들은 여기서 자란 것이 아닙니다. 다만 돌아가는 법을 잊은 것도 아닙니다."
    else
      "아직 이름 붙일 만큼 자라지 않았습니다."
    end
  end

  def update_colony(stat_key, amount)
    # 개인별 구조에서는 전체 합산 셀이 없으므로 아무 것도 하지 않는다.
    # 전체 합산은 colony 메서드에서 개인별 행을 합산해 계산한다.
    nil
  end

  def colony
    with_retry("군체 합산 조회") do
      ws = worksheet(COLONY_SHEET)

      totals = { affection: 0, aggression: 0, stability: 0, weirdness: 0, unknown: 0 }

      (2..ws.num_rows).each do |r|
        next if ws[r, 1].to_s.strip.empty?
        totals[:affection]  += ws[r, 4].to_i
        totals[:aggression] += ws[r, 5].to_i
        totals[:stability]  += ws[r, 6].to_i
        totals[:weirdness]  += ws[r, 7].to_i
        totals[:unknown]    += ws[r, 8].to_i
      end

      {
        affection:  totals[:affection],
        aggression: totals[:aggression],
        stability:  totals[:stability],
        weirdness:  totals[:weirdness],
        unknown:    totals[:unknown],
        current:    "",
        stage:      "",
        message:    ""
      }
    end
  end

  def set_colony_result(current:, stage:, message:)
    # 개인별 구조에서는 결과를 시트에 저장하지 않는다.
    nil
  end

  # ─────────────────────────────────────────────
  # 기숙사 점수
  # 기숙사 시트: A(1)=기숙사명 / B(2)=점수
  # ─────────────────────────────────────────────
  def add_house_score(house, delta)
    with_retry("기숙사 점수 반영 #{house}") do
      ws = worksheet(HOUSE_SHEET)
      total = nil
      (2..ws.num_rows).each do |row|
        next unless ws[row, 1].to_s.strip == house.to_s.strip
        total = ws[row, 2].to_i + delta.to_i
        ws[row, 2] = total.to_s
        save!(ws)
        break
      end
      total
    end
  end

  def add_house_score_all(delta)
    with_retry("기숙사 점수 전체 반영") do
      ws = worksheet(HOUSE_SHEET)
      results = []
      (2..ws.num_rows).each do |row|
        name = ws[row, 1].to_s.strip
        next if name.empty?
        total = ws[row, 2].to_i + delta.to_i
        ws[row, 2] = total.to_s
        results << [name, total]
      end
      next nil if results.empty?
      save!(ws)
      results
    end
  end

  # ─────────────────────────────────────────────
  # 로그
  # ─────────────────────────────────────────────
  # 로그 시트에 같은 status_id의 툿정산 기록이 있으면 true
  def toot_settlement_done?(status_id)
    sid = status_id.to_s.strip
    return false if sid.empty?

    with_retry("툿정산 로그 조회") do
      ws = worksheet(LOG_SHEET)
      pattern = /status_id=#{Regexp.escape(sid)}(\D|\z)/
      found = false

      (2..ws.num_rows).each do |row|
        next unless ws[row, 3].to_s.strip == "툿정산"
        if ws[row, 4].to_s.match?(pattern)
          found = true
          break
        end
      end

      found
    end
  rescue => e
    warn "[toot_settlement_done? 오류] #{e.class}: #{e.message}"
    false
  end

  def log(account, command, result)
    ws  = worksheet(LOG_SHEET)
    row = ws.num_rows + 1
    ws[row, 1] = now_string
    ws[row, 2] = account
    ws[row, 3] = command
    ws[row, 4] = result
    save!(ws)
  rescue
    nil
  end

  private

  # 429 / 할당량 초과(RateLimitError) 등 일시적 오류에 대해 최대 3회
  # 재시도한다. 재시도 없이 바로 실패로 처리하면, 사람이 몰려 순간적으로
  # 할당량을 초과했을 때 정상적인 명령까지 오류로 끊겨버린다.
  def with_retry(label, max_retries: 3)
    attempt = 0
    begin
      yield
    rescue Google::Apis::RateLimitError, Google::Apis::ServerError, Google::Apis::TransmissionError => e
      attempt += 1
      if attempt <= max_retries
        wait_seconds = 1.5 * attempt
        puts "[시트 재시도] #{label}: #{e.class} - #{wait_seconds}초 후 재시도 (#{attempt}/#{max_retries})"
        sleep(wait_seconds)
        retry
      else
        raise
      end
    end
  end

  # ws.save 호출 지점을 전부 이걸 거치게 해서 429 재시도를 일괄 적용한다.
  def save!(ws)
    with_retry("저장") { ws.save }
  end

  # worksheet 캐시를 거치지 않고 서버의 현재 값을 새 객체로 가져온다.
  def fresh_worksheet(name)
    with_retry("시트 새로고침 #{name}") do
      ws = @spreadsheet.worksheet_by_title(name)
      raise "시트 탭을 찾을 수 없습니다: #{name}" unless ws
      ws
    end
  end

  def find_row_in_worksheet(ws, column_index, value)
    target = normalize_account(value)

    rows = with_retry("읽기 워크시트") { ws.rows }
    rows.each_with_index do |row_data, index|
      next if index.zero?
      return index + 1 if normalize_account(row_data[column_index - 1]) == target
    end

    nil
  end

  def normalize_account(value)
    value.to_s
         .gsub("\u00A0", " ")
         .strip
         .sub(/\A@/, "")
         .downcase
  end

  def cached_row(type, account)
    key = [type, normalize_account(account)]
    return @row_cache[key] if @row_cache.key?(key)

    @row_cache[key] = yield
  end

  def clear_account_row_cache(account)
    normalized = normalize_account(account)
    @row_cache.delete([:user, normalized])
    @row_cache.delete([:stat, normalized])
    @row_cache.delete([:cat, normalized])
  end

  def normalize(text)
    text.to_s.gsub(/\s+/, "").strip
  end

  def parse_float(value, default)
    v = value.to_s.strip
    v.empty? ? default : v.to_f
  end
end
