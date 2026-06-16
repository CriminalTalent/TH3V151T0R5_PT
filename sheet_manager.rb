require "google_drive"
require "date"

class SheetManager
  USER_SHEET     = "사용자"
  STAT_SHEET     = "스탯"
  ACTIVITY_SHEET = "활동"
  CAT_SHEET      = "카피캣"
  COLONY_SHEET   = "군체"
  LOG_SHEET      = "로그"

  # 사용자 시트 컬럼 (1-based, google_drive gem)
  # A(1)=ID / B(2)=이름 / C(3)=크레딧 / D(4)=아이템 / E(5)=기숙사
  # F(6)=마지막베팅일 / G(7)=오늘베팅횟수 / H(8)=마지막타로일
  # I(9)=누적툿수 / J(10)=정산기준툿수 / K(11)=스탯포인트잔여
  # L(12)=출석날짜 / M(13)=과제날짜

  # 스탯 시트 컬럼 (1-based)
  # A(1)=ID / B(2)=이름 / C(3)=HP / D(4)=마법능력 / E(5)=인내
  # F(6)=속도 / G(7)=기술 / H(8)=행운

  STAT_COLUMNS = {
    "건강"    => 3,
    "마법능력" => 4,
    "인내"    => 5,
    "속도"    => 6,
    "기술"    => 7,
    "행운"    => 8
  }.freeze

  # 활동 시트 컬럼 (1-based)
  # A(1)=종류 / B(2)=활동명 / C(3)=요일 / D(4)=크레딧
  # E(5)=관련스탯1 / F(6)=관련스탯2 / G(7)=난이도
  # H(8)=성공스탯보상 / I(9)=대성공배율 / J(10)=성공배율
  # K(11)=실패배율 / L(12)=대실패배율 / M(13)=출력문구

  def initialize
    session = GoogleDrive::Session.from_service_account_key(
      ENV.fetch("GOOGLE_CREDENTIALS_PATH")
    )
    @spreadsheet = session.spreadsheet_by_key(ENV.fetch("SPREADSHEET_KEY"))
  end

  def worksheet(name)
    ws = @spreadsheet.worksheet_by_title(name)
    raise "시트 탭을 찾을 수 없습니다: #{name}" unless ws
    ws
  end

  def today
    Date.today.strftime("%Y-%m-%d")
  end

  def now_string
    Time.now.strftime("%Y-%m-%d %H:%M:%S")
  end

  def find_row(sheet_name, column_index, value)
    ws = worksheet(sheet_name)
    (2..ws.num_rows).each do |row|
      return row if ws[row, column_index].to_s.strip == value.to_s.strip
    end
    nil
  end

  def user_row(account)
    find_row(USER_SHEET, 1, account)
  end

  def cat_row(account)
    find_row(CAT_SHEET, 1, account)
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
    ws.save

    create_default_stats(account, name)
    create_default_cat(account, name)

    true
  end

  def create_default_stats(account, name)
    ws  = worksheet(STAT_SHEET)
    row = ws.num_rows + 1

    ws[row, 1] = account  # ID
    ws[row, 2] = name     # 이름
    ws[row, 3] = "50"     # HP (건강)
    ws[row, 4] = "10"     # 마법능력
    ws[row, 5] = "10"     # 인내
    ws[row, 6] = "0"      # 속도
    ws[row, 7] = "0"      # 기술
    ws[row, 8] = "5"      # 행운
    ws.save
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
    ws.save
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
    ws.save
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
    ws.save
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
    ws.save
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
    ws.save
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
    ws.save
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
    ws.save
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
    row = find_row(STAT_SHEET, 1, account)
    return {} unless row
    ws = worksheet(STAT_SHEET)
    {
      "건강"    => ws[row, 3].to_i,
      "마법능력" => ws[row, 4].to_i,
      "인내"    => ws[row, 5].to_i,
      "속도"    => ws[row, 6].to_i,
      "기술"    => ws[row, 7].to_i,
      "행운"    => ws[row, 8].to_i
    }
  end

  def add_stat(account, stat_name, amount)
    return if amount.to_i == 0
    col = STAT_COLUMNS[stat_name]
    return unless col
    row = find_row(STAT_SHEET, 1, account)
    return unless row
    ws = worksheet(STAT_SHEET)
    ws[row, col] = (ws[row, col].to_i + amount.to_i).to_s
    ws.save
  end

  def set_stat(account, stat_name, value)
    col = STAT_COLUMNS[stat_name]
    return unless col
    row = find_row(STAT_SHEET, 1, account)
    return unless row
    ws = worksheet(STAT_SHEET)
    ws[row, col] = value.to_s
    ws.save
  end

  # ─────────────────────────────────────────────
  # 활동
  # 시트 컬럼: A=종류, B=활동명, C=요일, D=크레딧,
  #            E=관련스탯1, F=관련스탯2, G=난이도,
  #            H=성공스탯보상, I=대성공배율, J=성공배율,
  #            K=실패배율, L=대실패배율, M=출력문구
  # ─────────────────────────────────────────────
  def find_activity(kind, name)
    ws = worksheet(ACTIVITY_SHEET)
    (2..ws.num_rows).each do |row|
      next unless ws[row, 1].to_s.strip == kind
      next unless normalize(ws[row, 2]) == normalize(name)

      return {
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
    end
    nil
  end

  # ─────────────────────────────────────────────
  # 카피캣
  # ─────────────────────────────────────────────
  def cat(account)
    row = cat_row(account)
    return nil unless row
    ws = worksheet(CAT_SHEET)
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
    ws = worksheet(CAT_SHEET)
    row = cat_row(account)

    unless row
      row = ws.num_rows + 1
      character_name = user_name(account) || account

      ws[row, 1]  = account
      ws[row, 2]  = character_name
      ws[row, 3]  = cat_name
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
      ws.save
      return
    end

    ws[row, 3] = cat_name
    ws.save
  end

  def update_cat(account, changes)
    row = cat_row(account)
    return unless row
    ws = worksheet(CAT_SHEET)

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
    ws.save
  end

  # ─────────────────────────────────────────────
  # 군체
  # ─────────────────────────────────────────────
  def update_colony(stat_key, amount)
    ws  = worksheet(COLONY_SHEET)
    col = { affection: 1, aggression: 2, stability: 3, weirdness: 4, unknown: 5 }[stat_key]
    return unless col
    ws[2, col] = (ws[2, col].to_i + amount.to_i).to_s
    ws.save
  end

  def colony
    ws = worksheet(COLONY_SHEET)
    {
      affection:  ws[2, 1].to_i,
      aggression: ws[2, 2].to_i,
      stability:  ws[2, 3].to_i,
      weirdness:  ws[2, 4].to_i,
      unknown:    ws[2, 5].to_i,
      current:    ws[2, 6].to_s,
      stage:      ws[2, 7].to_s,
      message:    ws[2, 8].to_s
    }
  end

  def set_colony_result(current:, stage:, message:)
    ws = worksheet(COLONY_SHEET)
    ws[2, 6] = current
    ws[2, 7] = stage
    ws[2, 8] = message
    ws.save
  end

  # ─────────────────────────────────────────────
  # 로그
  # ─────────────────────────────────────────────
  def log(account, command, result)
    ws  = worksheet(LOG_SHEET)
    row = ws.num_rows + 1
    ws[row, 1] = now_string
    ws[row, 2] = account
    ws[row, 3] = command
    ws[row, 4] = result
    ws.save
  rescue
    nil
  end


  # ─────────────────────────────────────────────
  # 활동별 마지막 날짜 (N=수업, O=아르바이트, P=클럽)
  # ─────────────────────────────────────────────
  ACTIVITY_DATE_COLUMNS = {
    "수업"      => 14,  # N
    "아르바이트" => 15,  # O
    "클럽"      => 16   # P
  }.freeze

  def get_activity_last_date(account, kind)
    col = ACTIVITY_DATE_COLUMNS[kind]
    return nil unless col
    row = user_row(account)
    return nil unless row
    worksheet(USER_SHEET)[row, col].to_s
  end

  def set_activity_last_date(account, kind, value = today)
    col = ACTIVITY_DATE_COLUMNS[kind]
    return unless col
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, col] = value
    ws.save
  end

  # ─────────────────────────────────────────────
  # 발동한 이벤트 목록 (Q열, 콤마구분)
  # ─────────────────────────────────────────────
  def triggered_events(account)
    row = user_row(account)
    return [] unless row
    worksheet(USER_SHEET)[row, 17].to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def add_triggered_event(account, event_name)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    current = ws[row, 17].to_s.split(",").map(&:strip).reject(&:empty?)
    return if current.include?(event_name)
    current << event_name
    ws[row, 17] = current.join(",")
    ws.save
  end

  # ─────────────────────────────────────────────
  # 이벤트 시트
  # 컬럼: A=조건1스탯 B=조건1값 C=조건2스탯 D=조건2값 E=조건3스탯 F=조건3값
  #       G=카피캣영향스탯 H=카피캣영향값 I=메시지 J=1회한정여부
  # ─────────────────────────────────────────────
  EVENT_SHEET = "이벤트"

  def all_events
    ws = worksheet(EVENT_SHEET)
    events = []
    (2..ws.num_rows).each do |row|
      msg = ws[row, 9].to_s.strip
      next if msg.empty?
      events << {
        row:        row,
        conditions: [
          [ws[row, 1].to_s.strip, ws[row, 2].to_s.strip],
          [ws[row, 3].to_s.strip, ws[row, 4].to_s.strip],
          [ws[row, 5].to_s.strip, ws[row, 6].to_s.strip]
        ].reject { |stat, _| stat.empty? },
        cat_stat:   ws[row, 7].to_s.strip,
        cat_value:  ws[row, 8].to_i,
        message:    msg,
        once_only:  ws[row, 10].to_s.strip.upcase == "TRUE",
        name:       "이벤트#{row}"
      }
    end
    events
  end
  private

  def normalize(text)
    text.to_s.gsub(/\s+/, "").strip
  end

  def parse_float(value, default)
    v = value.to_s.strip
    v.empty? ? default : v.to_f
  end
end

class SheetManager
  TOOT_TOTAL_COL = 18
  TOOT_BASE_COL  = 19

  def get_toot_base(account)
    row = user_row(account)
    return 0 unless row
    worksheet(USER_SHEET)[row, TOOT_BASE_COL].to_i
  end

  def set_toot_base(account, count)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, TOOT_BASE_COL] = count.to_i
    ws.save
  end

  def set_toot_total(account, count)
    row = user_row(account)
    return unless row
    ws = worksheet(USER_SHEET)
    ws[row, TOOT_TOTAL_COL] = count.to_i
    ws.save
  end
end
