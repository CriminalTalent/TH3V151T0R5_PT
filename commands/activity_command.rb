require_relative "../utils/date_helper"
require_relative "../utils/result_judge"

class ActivityCommand
  include DateHelper
  include ResultJudge

  STAT_COLUMN_NAMES = %w[건강 내구도 마법능력 민첩 기술 행운 최대건강].freeze

  # 활동 탭의 다른 표기를 스탯 탭 실제 컬럼명으로 변환
  STAT_ALIASES = {
    "인내" => "내구도",
    "속도" => "민첩"
  }.freeze

  # 명령어 별칭: 입력된 종류를 시트의 종류 표기로 통일
  KIND_ALIASES = {
    "강의"       => "수업",
    "수업"       => "수업",
    "봉사활동"   => "아르바이트",
    "아르바이트" => "아르바이트"
  }.freeze

  CAT_STAT_MAP = {
    "애정"   => :affection,
    "공격성" => :aggression,
    "안정"   => :stability,
    "기묘함" => :weirdness,
    "???"    => :unknown
  }.freeze

  LESSON_EVENTS = {
    great_success: [
      "마법이 완벽하게 빛나며 발동했습니다.",
      "교수님이 칭찬하며 교과서에 싣고 싶다고 했습니다.",
      "반 전체가 환호성을 질렀습니다.",
      "주문의 마력이 아름답게 퍼져나갔습니다.",
      "마법 도구가 반짝이며 최고의 결과를 냈습니다.",
      "시험관의 용액이 완벽한 색으로 변했습니다.",
      "교수님이 '훌륭하다'며 점수를 주었습니다.",
      "친구들이 당신의 마법을 배우고 싶다고 했습니다.",
      "마법의 이론과 실제가 완벽하게 맞아떨어졌습니다.",
      "수업 시간의 최고 점수를 기록했습니다.",
      "교수님이 올해 최고의 학생이라고 평가했습니다.",
      "마법 에너지가 장엄하게 솟아올랐습니다.",
      "모든 친구들이 당신을 따라하려 했습니다.",
      "교실 전체에 마법의 빛이 가득 찼습니다.",
      "교수님이 대학원 과정을 추천했습니다.",
      "마법 실험이 교과서 사례로 채택되었습니다.",
      "당신의 성과에 다른 학년도 감탄했습니다.",
      "마법 에너지 제어가 완벽했습니다.",
      "교수님이 추가 학점을 주었습니다.",
      "호그와트 마법 역사에 기록될 만한 성과입니다.",
      "마법의 대가다운 솜씨를 보였습니다.",
      "선배들도 경탄하는 실력을 드러냈습니다.",
      "교수님이 당신을 특별히 관찰했습니다.",
      "마법의 미묘한 움직임을 완벽히 제어했습니다.",
      "수업을 마친 후 자발적 박수가 나왔습니다.",
      "교수님의 기대를 훨씬 넘어서는 결과입니다.",
      "마법이 교과서의 그림보다 더 아름다웠습니다.",
      "당신의 마법으로 마법 기구가 새로워진 기분입니다.",
      "교수님이 이 마법을 다음 세대에 전수하길 바란다고 했습니다.",
      "호그와트의 세계가 당신의 마법으로 밝아졌습니다."
    ],
    success: [
      "마법이 예상대로 발동했습니다.",
      "교수님이 좋은 성과라고 평가했습니다.",
      "대부분의 친구들이 성공했습니다.",
      "마법 도구가 제대로 반응했습니다.",
      "주문이 명확하게 나왔습니다.",
      "시험관의 색이 올바르게 변했습니다.",
      "교수님이 점수를 주었습니다.",
      "실험 결과가 만족스러웠습니다.",
      "마법 에너지가 적절하게 제어되었습니다.",
      "학점에 도움이 될 만한 성과입니다.",
      "친구들이 좋은 결과라며 축하했습니다.",
      "마법의 기초를 잘 이해하고 있습니다.",
      "교수님의 예상 범위 내의 좋은 성과입니다.",
      "수업의 핵심을 잘 파악했습니다.",
      "마법 이론을 잘 적용했습니다.",
      "평소보다 더 나은 결과입니다.",
      "학점 평가에 긍정적인 영향을 줄 것 같습니다.",
      "마법의 기본기가 탄탄합니다.",
      "교수님이 앞으로의 발전을 기대한다고 했습니다.",
      "다음 난이도의 마법에 도전해볼 만합니다.",
      "성공적인 마법 시연입니다.",
      "교실의 다른 조들보다 나은 성과입니다.",
      "마법 에너지 효율이 좋았습니다.",
      "교수님의 지도 덕분에 잘했습니다.",
      "실기 시험 준비가 잘되고 있습니다.",
      "마법의 아름다움을 느낄 수 있었습니다.",
      "동료들이 참고하고 싶다며 물어봤습니다.",
      "교수님이 쓸만한 학생이라고 평가했습니다.",
      "호그와트의 평균 이상의 실력입니다.",
      "계속 노력하면 더 나은 마법사가 될 것 같습니다."
    ],
    failure: [
      "마법이 완벽하게 작동하지 않았습니다.",
      "마법 에너지가 흩어져 나갔습니다.",
      "주문이 약하게 나왔습니다.",
      "시험관의 색이 잘못된 색으로 변했습니다.",
      "마법 도구가 반응하지 않았습니다.",
      "집중력이 흐트러렸습니다.",
      "교수님이 다시 시도하라고 했습니다.",
      "옆 친구의 마법이 방해했습니다.",
      "마법 이론을 잘못 이해했습니다.",
      "손 떨림으로 마법이 약해졌습니다.",
      "주의력이 산만했습니다.",
      "마법 에너지 제어에 실패했습니다.",
      "교수님의 설명을 제대로 못 들었습니다.",
      "마법의 타이밍을 놓쳤습니다.",
      "근처 학생의 흡음 때문에 방해받았습니다.",
      "충분한 준비 시간이 없었습니다.",
      "마법 기구의 성능이 좋지 않았습니다.",
      "어제 부족한 수면 때문입니다.",
      "마법 이론 복습을 해야 할 것 같습니다.",
      "오늘은 마법의 신이 나를 버린 것 같습니다.",
      "더 신중한 접근이 필요합니다.",
      "마법 에너지의 파동이 불안정했습니다.",
      "교수님의 다음 수업에 더 집중해야겠습니다.",
      "실수를 줄이기 위해 더 연습하겠습니다.",
      "오늘 하루는 마법 운이 없었습니다.",
      "조금 더 시간이 필요한 것 같습니다.",
      "다른 친구들보다 뒤떨어진 기분입니다.",
      "마법의 본질을 아직 이해하지 못했습니다.",
      "계속 노력하면 나아질 거라 믿습니다.",
      "오늘은 배우는 날이라고 생각하겠습니다."
    ],
    great_failure: [
      "마법이 폭발했습니다!",
      "마법 도구가 부러졌습니다!",
      "예상 밖의 반작용이 일어났습니다!",
      "교실 전체가 연기로 가득 찼습니다!",
      "마법이 역발동했습니다!",
      "시험관이 산산조각 났습니다!",
      "교수님이 즉시 보호 주문을 걸었습니다!",
      "다른 학생들까지 영향을 받았습니다!",
      "마법 에너지가 통제 불능 상태입니다!",
      "교수님이 수업을 중단했습니다!",
      "심각한 마법 실수입니다!",
      "마법사 의료팀이 출동했습니다!",
      "교실의 가구가 손상되었습니다!",
      "친구들이 모두 피신했습니다!",
      "마법의 역류가 당신을 맞았습니다!",
      "교수님이 매우 엄격한 표정입니다!",
      "이것은 위험한 마법 오류입니다!",
      "장시간의 청소 벌칙이 필요합니다!",
      "다른 학년의 학생들까지 피해를 입었습니다!",
      "호그와트 100년 역사에 기록될 사건입니다!",
      "마법사 규율위원회에 통보될 일입니다!",
      "당신의 마법 점수가 급락했습니다!",
      "부모님께 통보가 가실 것 같습니다!",
      "마법 도서관의 책들이 모두 날아갔습니다!",
      "교수님이 당신을 바라보는 눈이 차갑습니다!",
      "이 마법 실패는 영원한 오명입니다!",
      "수리 마법사도 손을 놓을 정도입니다!",
      "호그와트 교장실에 소환될 준비를 하세요!",
      "당신의 마법 재능을 의심하게 됩니다!",
      "이 사건은 절대 잊혀지지 않을 것입니다!"
    ]
  }

  PARTTIME_EVENTS = {
    great_success: [
      "정확한 손놀림으로 일을 완벽하게 끝냈습니다.",
      "담당 교수가 추가 보상을 약속했습니다.",
      "당신만의 효율적인 방식이 인정받았습니다.",
      "다른 직원들이 당신을 따라하려 합니다.",
      "일의 질이 최고 수준입니다.",
      "주변 학생들이 당신의 솜씨를 칭찬했습니다.",
      "일 처리 속도가 두 배입니다.",
      "담당 교수가 당신을 특별히 칭찬했습니다.",
      "일의 결과물이 완벽합니다.",
      "팀의 효율을 크게 높였습니다.",
      "모든 의뢰가 만족스럽게 마무리되었습니다.",
      "일하는 태도가 모범적입니다.",
      "예상 시간의 절반만에 완료했습니다.",
      "다음 업무도 맡아달라는 제안을 받았습니다.",
      "모든 동료들이 당신의 실력을 인정합니다.",
      "이 업무는 당신이 제일입니다.",
      "일의 품질이 표준을 초과했습니다.",
      "다음 의뢰도 당신에게 맡기고 싶어 합니다.",
      "팀의 분위기까지 밝혀졌습니다.",
      "일처리가 정말 깔끔합니다.",
      "추가 크레딧을 기대할 만합니다.",
      "당신의 일 방식은 교본이 될 정도입니다.",
      "서툰 동료도 당신에게 배우고 싶어 합니다.",
      "이 일은 당신을 위해 있는 일입니다.",
      "모든 과정이 완벽하게 진행되었습니다.",
      "담당 교수가 당신을 신뢰합니다.",
      "평가가 최고 점수입니다.",
      "당신의 책임감이 돋보입니다.",
      "이 일을 하면서 당신만큼 만족한 적 없습니다.",
      "호그와트 최고의 아르바이트생입니다."
    ],
    success: [
      "일을 무사히 완료했습니다.",
      "담당 교수가 칭찬했습니다.",
      "의뢰 결과가 만족스러웠습니다.",
      "정해진 시간 내에 끝냈습니다.",
      "일의 질이 만족스럽습니다.",
      "동료들과 잘 지냈습니다.",
      "예상대로 일이 진행되었습니다.",
      "평가가 긍정적입니다.",
      "특별한 문제가 없었습니다.",
      "일 처리가 깔끔했습니다.",
      "기대에 부응했습니다.",
      "팀과의 협력이 좋았습니다.",
      "업무 수행이 기대 이상입니다.",
      "일에 집중할 수 있었습니다.",
      "동료들이 신뢰합니다.",
      "담당 교수가 만족했습니다.",
      "다음 번에도 하고 싶습니다.",
      "일의 성과가 좋습니다.",
      "실수 없이 완료했습니다.",
      "의뢰 내용을 충실히 수행했습니다.",
      "일 후 기분이 좋습니다.",
      "신뢰를 얻었습니다.",
      "팀의 인정을 받았습니다.",
      "차주에도 같은 일을 하고 싶습니다.",
      "급여를 받을 자격이 충분합니다.",
      "다음 의뢰에도 추천받았습니다.",
      "일 능력이 인정받았습니다.",
      "팀에 도움이 되는 일입니다.",
      "계속 이런 식으로 일하면 좋겠습니다.",
      "호그와트의 평범한 아르바이트생입니다."
    ],
    failure: [
      "실수가 있었습니다.",
      "예상보다 시간이 오래 걸렸습니다.",
      "담당 교수가 지적했습니다.",
      "일의 일부를 다시 해야 합니다.",
      "집중력이 흐트러렸습니다.",
      "일의 퀄리티가 떨어졌습니다.",
      "의뢰 결과에 아쉬움이 남았습니다.",
      "동료의 도움이 필요했습니다.",
      "예상과 다른 결과가 나왔습니다.",
      "시간이 부족했습니다.",
      "일 중에 실수를 했습니다.",
      "안내를 놓쳤습니다.",
      "팀에 폐를 끼쳤습니다.",
      "일의 방향이 잘못되었습니다.",
      "수정하는 데 시간을 낭비했습니다.",
      "피로가 쌓였습니다.",
      "오늘따라 운이 없었습니다.",
      "담당 교수가 아쉬워했습니다.",
      "다시 한 번 체크가 필요합니다.",
      "일의 효율이 떨어졌습니다.",
      "의뢰를 완벽히 마무리하지 못했습니다.",
      "실수를 줄여야겠습니다.",
      "내일은 더 잘해야 합니다.",
      "동료들에게 폐를 끼쳐 미안합니다.",
      "근무 태도를 반성하겠습니다.",
      "이번 일은 부족했습니다.",
      "신뢰를 잃었을 수도 있습니다.",
      "다음에는 더 신중하겠습니다.",
      "오늘 급여는 적을 것 같습니다.",
      "이 일이 나와 맞지 않나 싶습니다."
    ],
    great_failure: [
      "큰 실수를 했습니다!",
      "의뢰에 큰 불만이 생겼습니다!",
      "일을 완전히 망쳤습니다!",
      "담당 교수가 매우 화났습니다!",
      "물건을 깨뜨렸습니다!",
      "보상을 다시 조정해야 할 상황입니다!",
      "일이 엉망이 되었습니다!",
      "즉시 수정 지시를 받았습니다!",
      "팀 전체에 피해를 입혔습니다!",
      "일을 처음부터 다시 해야 합니다!",
      "신뢰를 잃었습니다!",
      "담당 교수가 당신을 바라봤습니다!",
      "심각한 결과가 발생했습니다!",
      "다른 직원까지 피해를 입었습니다!",
      "이것은 용서받을 수 없는 실수입니다!",
      "담당 교수가 경고했습니다!",
      "관련된 학생들에게 사과해야 합니다!",
      "일을 그만두고 싶은 기분입니다!",
      "급여 페널티가 있을 것 같습니다!",
      "다음 업무 배정이 어려울 것 같습니다!",
      "다시는 이 일을 하지 않고 싶습니다!",
      "심각한 책임을 지게 되었습니다!",
      "업무 기준을 크게 벗어났습니다!",
      "팀의 신뢰를 잃었습니다!",
      "이런 실수는 호그와트에서 처음입니다!",
      "다음에는 보조 업무를 맡게 될 것 같습니다!",
      "이 일은 더 이상 당신의 것이 아닙니다!",
      "다음 의뢰를 받기 어려울 것 같습니다!",
      "당신의 평판이 망쳤습니다!",
      "이것은 절대 용서받을 수 없는 일입니다!"
    ]
  }

  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.match?(/\[(강의|수업|봉사활동|아르바이트)\/(.+?)\]/)
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    match = content.match(/\[(강의|수업|봉사활동|아르바이트)\/(.+?)\]/)
    kind  = KIND_ALIASES[match[1]] || match[1]
    name  = match[2].strip

    if @sheet.get_activity_last_date(account, kind) == @sheet.today
      return "#{kind} 활동은 오늘 이미 처리되었습니다."
    end

    activity = @sheet.find_activity(kind, name)
    activity ||= @sheet.find_activity(match[1], name)
    return "해당 활동을 찾을 수 없습니다. 활동 탭의 이름을 확인해주세요." unless activity

    unless allowed_day?(activity[:days])
      return "오늘은 `#{activity[:name]}` 활동을 할 수 있는 요일이 아닙니다."
    end

    current_stats = @sheet.stats(account)
    s1   = current_stats[activity[:stat1]].to_i
    s2   = current_stats[activity[:stat2]].to_i
    luck = current_stats["행운"].to_i

    base_rate = success_rate(
      s1:         s1,
      s2:         s2,
      luck:       luck,
      difficulty: activity[:difficulty]
    )

    attempts = []
    total_performance = 0

    4.times do |i|
      roll = rand(1..100)

      result, performance = judge_attempt(base_rate, roll)
      total_performance += performance

      event_pool = get_event_pool(kind)
      event = event_pool.fetch(result).sample

      attempts << {
        number: i + 1,
        roll: roll,
        target_rate: base_rate,
        result: result,
        performance: performance,
        event: event
      }
    end

    avg_performance = (total_performance / 4.0).round(1)
    final_result = determine_final_result(avg_performance)

    multiplier = case final_result
                 when :great_success then activity[:great_success_m]
                 when :success       then activity[:success_m]
                 when :failure       then activity[:failure_m]
                 when :great_failure then activity[:great_failure_m]
                 else 1.0
                 end

    multiplier = multiplier.to_f
    credit = (activity[:base_credit].to_f * multiplier).floor

    reward_text =
      activity[:stat_reward] ||
      activity[:success_stat_reward] ||
      activity[:success_stat] ||
      activity[:reward_stat]

    puts "[활동 데이터] 결과=#{final_result.inspect}, 배율=#{multiplier.inspect}, 스탯보상=#{reward_text.inspect}"

    stat_gains = apply_stat_rewards(account, reward_text, multiplier, final_result)
    label = result_label(final_result)

    @sheet.add_credit(account, credit)
    log_text = "#{kind}/#{name}/#{label}/#{credit}크레딧"
    @sheet.log(account, kind, log_text)
    @sheet.set_activity_last_date(account, kind)

    message = activity[:message].empty? ? "활동을 마쳤습니다." : activity[:message]

    build_response(message, attempts, avg_performance, final_result, credit, stat_gains, status_id)
  end

  private

  def get_event_pool(kind)
    case kind
    when "수업"
      LESSON_EVENTS
    when "아르바이트"
      PARTTIME_EVENTS
    else
      LESSON_EVENTS
    end
  end

  def judge_attempt(base_rate, roll)
    success_rate = [[base_rate.to_i, 20].max, 90].min

    return [:great_success, 100] if roll == 1
    return [:great_failure, 0] if roll == 100

    if roll <= success_rate
      great_success_limit = [(success_rate * 0.2).floor, 1].max

      if roll <= great_success_limit
        [:great_success, 100]
      else
        [:success, 75]
      end
    else
      great_failure_limit = success_rate + ((100 - success_rate) * 0.8).ceil

      if roll >= great_failure_limit
        [:great_failure, 0]
      else
        [:failure, 25]
      end
    end
  end

  def determine_final_result(avg_performance)
    if avg_performance >= 80
      :great_success
    elsif avg_performance >= 60
      :success
    elsif avg_performance >= 40
      :failure
    else
      :great_failure
    end
  end

  def result_label(result)
    case result
    when :great_success then "대성공"
    when :success then "성공"
    when :failure then "실패"
    when :great_failure then "대실패"
    else "불명"
    end
  end

  def result_phrase(result)
    case result
    when :great_success then "대성공했다!"
    when :success then "성공했다."
    when :failure then "실패했다."
    when :great_failure then "대실패했다!"
    else "결과를 알 수 없다."
    end
  end

  def build_response(message, attempts, avg_perf, final_result, credit, stat_gains, status_id)
    label = result_label(final_result)
    stat_text = stat_gains.to_a.empty? ? "" : "\n스탯 #{stat_gains.join(' / ')}"

    lines = []
    lines << message
    lines << "━" * 30

    attempts.each do |att|
      lines << "[시도 #{att[:number]}]"
      lines << "판정 수치: #{att[:roll]} / 성공 기준: #{att[:target_rate]} 이하"
      lines << "결과: #{result_label(att[:result])}"
      lines << att[:event]
      lines << ""
    end

    lines << "━" * 30
    lines << "성공률: #{attempts.first[:target_rate]}%"
    lines << "평균 성과: #{avg_perf}"
    lines << "최종 판정: #{label}"
    lines << "크레딧 +#{credit}#{stat_text}"

    messages = split_message(lines.join("\n"), 1000)

    if messages.size > 1
      store_pending_messages(status_id, messages[1..-1])
      messages[0]
    else
      messages[0]
    end
  end

  def split_message(text, limit)
    messages = []
    current = ""

    text.split("\n").each do |line|
      if (current + line + "\n").length > limit
        messages << current if current.length > 0
        current = line + "\n"
      else
        current += line + "\n"
      end
    end

    messages << current if current.length > 0
    messages
  end

  def store_pending_messages(status_id, messages)
    puts "[대기메시지] #{messages.size}개 메시지 대기중"
  end

  def apply_stat_rewards(account, reward_text, multiplier, result)
    puts "[활동 스탯] account=#{account.inspect}, reward=#{reward_text.inspect}, multiplier=#{multiplier.inspect}, result=#{result.inspect}"

    return [] if reward_text.to_s.strip.empty?

    unless @sheet.respond_to?(:add_stat)
      puts "[활동 스탯 오류] @sheet에 add_stat 메서드가 없습니다."
      return []
    end

    gains = []

    reward_text.to_s.split(/[,\/]/).each do |part|
      part = part.to_s.strip
      next if part.empty?

      match = part.match(/\A(.+?)\s*([+-]\s*\d+)\z/)

      unless match
        puts "[활동 스탯 오류] 보상 형식 해석 실패: #{part.inspect}"
        next
      end

      source_stat_name = match[1].strip
      stat_name = STAT_ALIASES.fetch(source_stat_name, source_stat_name)
      amount = match[2].delete(" ").to_i

      unless STAT_COLUMN_NAMES.include?(stat_name)
        puts "[활동 스탯 오류] 허용되지 않은 스탯명: #{stat_name.inspect}"
        next
      end

      applied = amount
      next if applied.zero?

      begin
        update_result = @sheet.add_stat(account, stat_name, applied)

        if update_result == false
          puts "[활동 스탯 오류] add_stat이 false를 반환했습니다: #{account.inspect}/#{stat_name}/#{applied}"
          next
        end

        sign = applied.positive? ? "+" : ""
        gains << "#{stat_name} #{sign}#{applied}"
        puts "[활동 스탯 적용] #{account.inspect}/#{stat_name}/#{sign}#{applied}, 반환=#{update_result.inspect}"

        if stat_name == "건강"
          max_result = @sheet.add_stat(account, "최대건강", applied)
          if max_result == false
            puts "[활동 스탯 오류] 최대건강 갱신 실패: #{account.inspect}/#{applied}"
          else
            gains << "최대건강 #{sign}#{applied}"
            puts "[활동 스탯 적용] #{account.inspect}/최대건강/#{sign}#{applied}, 반환=#{max_result.inspect}"
          end
        end
      rescue StandardError => e
        puts "[활동 스탯 예외] #{e.class}: #{e.message}"
        puts e.backtrace.first(10).join("\n")
      end
    end

    gains
  rescue StandardError => e
    puts "[활동 스탯 전체 예외] #{e.class}: #{e.message}"
    puts e.backtrace.first(10).join("\n")
    []
  end
end
