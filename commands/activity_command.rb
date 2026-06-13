require_relative "../utils/date_helper"
require_relative "../utils/result_judge"

class ActivityCommand
  include DateHelper
  include ResultJudge

  LAST_CLASS_COL = 6
  LAST_JOB_COL = 7
  LAST_CLUB_COL = 9

  STAT_REWARD_MAP = {
    "건강" => :health,
    "마법능력" => :magic,
    "내구도" => :durability,
    "민첩" => :agility,
    "기술" => :technique,
    "행운" => :luck
  }

  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.match?(/\[(수업|아르바이트|클럽)\/(.+?)\]/)
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    match = content.match(/\[(수업|아르바이트|클럽)\/(.+?)\]/)
    kind = match[1]
    name = match[2].strip

    limit_col = limit_column(kind)

    if @sheet.get_last_date(account, limit_col) == @sheet.today
      return "#{kind} 활동은 오늘 이미 처리되었습니다."
    end

    activity = @sheet.find_activity(kind, name)
    return "해당 활동을 찾을 수 없습니다. 활동 탭의 이름을 확인해주세요." unless activity

    unless allowed_day?(activity[:days])
      return "오늘은 `#{activity[:name]}` 활동을 할 수 있는 요일이 아닙니다."
    end

    stats = @sheet.stats(account)
    rate = success_rate(
      stats: stats,
      stat1: activity[:stat1],
      stat2: activity[:stat2],
      difficulty: activity[:difficulty]
    )

    result, roll = judge(rate)
    multiplier = reward_multiplier(result)

    credit = (activity[:base_credit] * multiplier).floor
    reputation = result == :great_success ? activity[:reputation] + 1 : activity[:reputation]

    apply_rewards(account, activity, multiplier)
    @sheet.add_credit(account, credit)
    @sheet.add_reputation(account, reputation)
    @sheet.set_last_date(account, limit_col)

    label = result_label(result)
    message = activity[:message].empty? ? "활동을 마쳤습니다." : activity[:message]

    log_text = "#{kind}/#{name}/#{label}/#{credit}크레딧"
    @sheet.log(account, kind, log_text)

    <<~TEXT.strip
      #{message}

      판정: #{label}
      성공률: #{rate}%
      주사위: #{roll}

      크레딧 +#{credit}
      평판 +#{reputation}
      #{stat_reward_text(activity, multiplier)}
    TEXT
  end

  private

  def limit_column(kind)
    case kind
    when "수업" then LAST_CLASS_COL
    when "아르바이트" then LAST_JOB_COL
    when "클럽" then LAST_CLUB_COL
    else LAST_JOB_COL
    end
  end

  def apply_rewards(account, activity, multiplier)
    stat_values(activity).each do |stat_name, value|
      amount = (value * multiplier).floor
      @sheet.add_stat(account, stat_name, amount) if amount > 0
    end
  end

  def stat_values(activity)
    {
      "건강" => activity[:health],
      "마법능력" => activity[:magic],
      "내구도" => activity[:durability],
      "민첩" => activity[:agility],
      "기술" => activity[:technique],
      "행운" => activity[:luck]
    }
  end

  def stat_reward_text(activity, multiplier)
    rewards = stat_values(activity).filter_map do |name, value|
      amount = (value * multiplier).floor
      "#{name} +#{amount}" if amount > 0
    end

    return "스테이터스 변화 없음" if rewards.empty?

    rewards.join(" / ")
  end
end
