require_relative "../utils/date_helper"
require_relative "../utils/result_judge"

class ActivityCommand
  include DateHelper
  include ResultJudge

  # 사용자 시트 컬럼 (마지막 활동일)
  LAST_CLASS_COL = 12  # L열 = 출석날짜 겸용 (수업)
  LAST_JOB_COL   = 12  # 아르바이트/클럽은 별도 컬럼 없으므로 같은 열 사용
  # ※ 수업/아르바이트/클럽을 각각 별도로 제한하려면 시트에 컬럼 추가 필요

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

    limit_col = limit_column(kind)

    if @sheet.get_last_date(account, limit_col) == @sheet.today
      return "#{kind} 활동은 오늘 이미 처리되었습니다."
    end

    activity = @sheet.find_activity(kind, name)
    return "해당 활동을 찾을 수 없습니다. 활동 탭의 이름을 확인해주세요." unless activity

    unless allowed_day?(activity[:days])
      return "오늘은 `#{activity[:name]}` 활동을 할 수 있는 요일이 아닙니다."
    end

    current_stats = @sheet.stats(account)

    # 성공률 계산: 50 + 관련스탯 합계×2 + 행운×1 - 난이도
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

    # 배율은 시트에서 읽음
    multiplier = case result
                 when :great_success then activity[:great_success_m]
                 when :success       then activity[:success_m]
                 when :failure       then activity[:failure_m]
                 when :great_failure then activity[:great_failure_m]
                 else 1.0
                 end

    credit = (activity[:base_credit] * multiplier).floor

    @sheet.add_credit(account, credit)
    @sheet.set_last_date(account, limit_col)

    label = result_label(result)

    log_text = "#{kind}/#{name}/#{label}/#{credit}크레딧"
    @sheet.log(account, kind, log_text)

    message = activity[:message].empty? ? "활동을 마쳤습니다." : activity[:message]

    <<~TEXT.strip
      #{message}

      판정: #{label}
      성공률: #{rate}%
      주사위: #{roll}

      크레딧 +#{credit}
    TEXT
  end

  private

  def limit_column(kind)
    case kind
    when "수업"      then 12   # L열
    when "아르바이트" then 12   # 별도 컬럼 없으면 같은 열
    when "클럽"      then 12
    else 12
    end
  end
end
