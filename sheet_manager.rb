require "google_drive"
require "date"

class SheetManager
  USER_SHEET = "사용자"
  STAT_SHEET = "스탯"
  ACTIVITY_SHEET = "활동"
  CAT_SHEET = "카피캣"
  COLONY_SHEET = "군체"
  LOG_SHEET = "로그"

  STAT_COLUMNS = {
    "건강" => 5,
    "마법능력" => 6,
    "내구도" => 7,
    "민첩" => 8,
    "기술" => 9,
    "행운" => 10
  }

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

  def register_user(account, name)
    return false if registered?(account)

    ws = worksheet(USER_SHEET)
    row = ws.num_rows + 1

    ws[row, 1] = account
    ws[row, 2] = name
    ws[row, 3] = ""
    ws[row, 4] = "0"
    ws[row, 5] = ""
    ws[row, 6] = ""
    ws[row, 7] = ""
    ws[row, 8] = "0"
    ws[row, 9] = ""
    ws.save

    create_default_stats(account, name)
    create_default_cat(account, name)

    true
  end

  def create_default_stats(account, name)
    ws = worksheet(STAT_SHEET)
    row = ws.num_rows + 1

    ws[row, 1] = account
    ws[row, 2] = name
    ws[row, 3] = "0"
    ws[row, 4] = "0"
    ws[row, 5] = "50"
    ws[row, 6] = "10"
    ws[row, 7] = "10"
    ws[row, 8] = "0"
    ws[row, 9] = "0"
    ws[row, 10] = "0"
    ws.save
  end

  def create_default_cat(account, name)
    ws = worksheet(CAT_SHEET)
    row = ws.num_rows + 1

    ws[row, 1] = account
    ws[row, 2] = name
    ws[row, 3] = "#{name}의 카피캣"
    ws[row, 4] = "0"
    ws[row, 5] = "0"
    ws[row, 6] = "0"
    ws[row, 7] = "0"
    ws[row, 8] = "0"
    ws[row, 9] = "0"
    ws[row, 10] = "0"
    ws[row, 11] = ""
    ws[row, 12] = "새끼"
    ws[row, 13] = "아직 당신을 따라 하는 법을 배우는 중입니다."
    ws.save
  end

  def user_name(account)
    row = user_row(account)
    return nil unless row
    worksheet(USER_SHEET)[row, 2]
  end

  def get_credit(account)
    row = user_row(account)
    return 0 unless row
    worksheet(USER_SHEET)[row, 4].to_i
  end

  def add_credit(account, amount)
    row = user_row(account)
    return unless row

    ws = worksheet(USER_SHEET)
    ws[row, 4] = (ws[row, 4].to_i + amount.to_i).to_s
    ws.save
  end

  def add_reputation(account, amount)
    row = user_row(account)
    return unless row

    ws = worksheet(USER_SHEET)
    ws[row, 8] = (ws[row, 8].to_i + amount.to_i).to_s
    ws.save
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

  def stats(account)
    row = find_row(STAT_SHEET, 1, account)
    return {} unless row

    ws = worksheet(STAT_SHEET)

    {
      "건강" => ws[row, 5].to_i,
      "마법능력" => ws[row, 6].to_i,
      "내구도" => ws[row, 7].to_i,
      "민첩" => ws[row, 8].to_i,
      "기술" => ws[row, 9].to_i,
      "행운" => ws[row, 10].to_i
    }
  end

  def add_stat(account, stat_name, amount)
    return if amount.to_i == 0

    row = find_row(STAT_SHEET, 1, account)
    return unless row

    col = STAT_COLUMNS[stat_name]
    return unless col

    ws = worksheet(STAT_SHEET)
    ws[row, col] = (ws[row, col].to_i + amount.to_i).to_s
    ws.save
  end

  def find_activity(kind, name)
    ws = worksheet(ACTIVITY_SHEET)

    (2..ws.num_rows).each do |row|
      next unless ws[row, 1].to_s.strip == kind
      next unless normalize(ws[row, 2]) == normalize(name)

      return {
        row: row,
        kind: ws[row, 1],
        name: ws[row, 2],
        days: ws[row, 3],
        base_credit: ws[row, 4].to_i,
        stat1: ws[row, 5],
        stat2: ws[row, 6],
        difficulty: ws[row, 7].to_i,
        health: ws[row, 8].to_i,
        magic: ws[row, 9].to_i,
        durability: ws[row, 10].to_i,
        agility: ws[row, 11].to_i,
        technique: ws[row, 12].to_i,
        luck: ws[row, 13].to_i,
        reputation: ws[row, 14].to_i,
        message: ws[row, 15].to_s
      }
    end

    nil
  end

  def cat(account)
    row = cat_row(account)
    return nil unless row

    ws = worksheet(CAT_SHEET)

    {
      row: row,
      account: ws[row, 1],
      character: ws[row, 2],
      name: ws[row, 3],
      intimacy: ws[row, 4].to_i,
      hunger: ws[row, 5].to_i,
      affection: ws[row, 6].to_i,
      aggression: ws[row, 7].to_i,
      stability: ws[row, 8].to_i,
      weirdness: ws[row, 9].to_i,
      unknown: ws[row, 10].to_i,
      last_feed: ws[row, 11].to_s,
      stage: ws[row, 12].to_s,
      last_reaction: ws[row, 13].to_s
    }
  end

  def set_cat_name(account, cat_name)
    row = cat_row(account)
    return unless row

    ws = worksheet(CAT_SHEET)
    ws[row, 3] = cat_name
    ws.save
  end

  def update_cat(account, changes)
    row = cat_row(account)
    return unless row

    ws = worksheet(CAT_SHEET)

    column_map = {
      intimacy: 4,
      hunger: 5,
      affection: 6,
      aggression: 7,
      stability: 8,
      weirdness: 9,
      unknown: 10,
      last_feed: 11,
      stage: 12,
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

  def update_colony(stat_key, amount)
    ws = worksheet(COLONY_SHEET)

    col = {
      affection: 1,
      aggression: 2,
      stability: 3,
      weirdness: 4,
      unknown: 5
    }[stat_key]

    return unless col

    ws[2, col] = (ws[2, col].to_i + amount.to_i).to_s
    ws.save
  end

  def colony
    ws = worksheet(COLONY_SHEET)

    {
      affection: ws[2, 1].to_i,
      aggression: ws[2, 2].to_i,
      stability: ws[2, 3].to_i,
      weirdness: ws[2, 4].to_i,
      unknown: ws[2, 5].to_i,
      current: ws[2, 6].to_s,
      stage: ws[2, 7].to_s,
      message: ws[2, 8].to_s
    }
  end

  def set_colony_result(current:, stage:, message:)
    ws = worksheet(COLONY_SHEET)
    ws[2, 6] = current
    ws[2, 7] = stage
    ws[2, 8] = message
    ws.save
  end

  def log(account, command, result)
    ws = worksheet(LOG_SHEET)
    row = ws.num_rows + 1

    ws[row, 1] = now_string
    ws[row, 2] = account
    ws[row, 3] = command
    ws[row, 4] = result
    ws.save
  rescue
    nil
  end

  private

  def normalize(text)
    text.to_s.gsub(/\s+/, "").strip
  end
end
