require_relative "../utils/date_helper"
require_relative "../utils/result_judge"

class ActivityCommand
  include DateHelper
  include ResultJudge

  STAT_COLUMN_NAMES = %w[건강 마법능력 인내 속도 기술 행운].freeze

  CAT_STAT_MAP = {
    "애정"   => :affection,
    "공격성" => :aggression,
    "안정"   => :stability,
    "기묘함" => :weirdness,
    "???"    => :unknown
  }.freeze

  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.match?(/\[(수업|아르바이트|클럽)\/(.+?)\]/)
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    match = content.match(/\[(수업|아르바이트|클럽)\/(.+?)\]/)
    kind  = match[1]
    name  = match[2].strip

    if @sheet.get_activity_last_date(account, kind) == @sheet.today
      return "#{kind} 활동은 오늘 이미 처리되었습니다."
    end

    activity = @sheet.find_activity(kind, name)
    return "해당 활동을 찾을 수 없습니다. 활동 탭의 이름을 확인해주세요." unless activity

    unless allowed_day?(activity[:days])
      return "오늘은 `#{activity[:name]}` 활동을 할 수 있는 요일이 아닙니다."
    end

    current_stats = @sheet.stats(account)

    s1   = current_stats[activity[:stat1]].to_i
    s2   = current_stats[activity[:stat2]].to_i
    luck = current_stats["행운"].to_i
    rate = success_rate(
      s1:         s1,
      s2:         s2,
      luck:       luck,
      difficulty: activity[:difficulty]
    )

    result, roll = judge(rate)

    multiplier = case result
                 when :great_success then activity[:great_success_m]
                 when :success       then activity[:success_m]
                 when :failure       then activity[:failure_m]
                 when :great_failure then activity[:great_failure_m]
                 else 1.0
                 end

    credit = (activity[:base_credit] * multiplier).floor

    # 스탯 보상 적용 (성공/대성공 시만, "건강+5,기술+2" 형식 파싱)
    stat_gains = apply_stat_rewards(account, activity[:stat_reward], multiplier, result)

    @sheet.add_credit(account, credit)
    @sheet.set_activity_last_date(account, kind)

    label = result_label(result)

    log_text = "#{kind}/#{name}/#{label}/#{credit}크레딧"
    @sheet.log(account, kind, log_text)

    message = activity[:message].empty? ? "활동을 마쳤습니다." : activity[:message]

    stat_text = stat_gains.empty? ? "" : "\n#{stat_gains.join(' / ')}"

    event_text = check_events(account)

    <<~TEXT.strip
      #{message}

      판정: #{label}
      성공률: #{rate}%
      주사위: #{roll}

      크레딧 +#{credit}#{stat_text}#{event_text}
    TEXT
  end

  private

  # "건강+5,기술+2" 형식 파싱 후 적용. 결과/배율에 따라 반영하고
  # 오른 스탯명+수치만 배열로 반환 (예: ["건강 +5", "기술 +2"])
  def apply_stat_rewards(account, reward_text, multiplier, result)
    return [] if reward_text.to_s.strip.empty?
    return [] if [:failure, :great_failure].include?(result)

    gains = []

    reward_text.split(",").each do |part|
      part = part.strip
      next if part.empty?

      m = part.match(/(.+?)([+\-]\d+)/)
      next unless m

      stat_name = m[1].strip
      amount    = m[2].to_i
      next unless STAT_COLUMN_NAMES.include?(stat_name)

      applied = (amount * multiplier).round
      next if applied == 0

      @sheet.add_stat(account, stat_name, applied)
      sign = applied > 0 ? "+" : ""
      gains << "#{stat_name} #{sign}#{applied}"
    end

    gains
  end

  # 활동 성공 후 이벤트 조건 체크. 조건 만족하면 카피캣 스탯 변경 +
  # 메시지 출력. 1회한정이면 발동기록 남김.
  def check_events(account)
    stats = @sheet.stats(account)
    triggered = @sheet.triggered_events(account)
    messages = []

    @sheet.all_events.each do |event|
      next if event[:once_only] && triggered.include?(event[:name])

      all_met = event[:conditions].all? do |stat_name, threshold|
        stats[stat_name].to_i >= threshold.to_i
      end

      next unless all_met

      if event[:cat_stat] && CAT_STAT_MAP[event[:cat_stat]]
        cat_key = CAT_STAT_MAP[event[:cat_stat]]
        @sheet.update_cat(account, cat_key => event[:cat_value])
      end

      messages << event[:message]

      @sheet.add_triggered_event(account, event[:name]) if event[:once_only]
    end

    messages.empty? ? "" : "\n\n" + messages.join("\n")
  end
end
