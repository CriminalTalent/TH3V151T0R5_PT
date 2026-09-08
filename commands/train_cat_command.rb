require_relative "../utils/korean_particle"
require_relative "../utils/cat_size"

class TrainCatCommand
  include KoreanParticle
  include CatSize

  COST = 500
  SUCCESS_RATE = 0.30
  DAILY_LIMIT = 3
  BOOST_STATS = 3
  BOOST_MIN = 3
  BOOST_MAX = 5

  STAT_LABELS = {
    affection: "애정",
    aggression: "공격성",
    stability: "안정",
    weirdness: "기묘함",
    unknown: "???"
  }.freeze

  # 훈련 시작 시 항상 먼저 보여주는 도입부 (긴장감을 위한 과정 묘사)
  INTRO_TEXTS = [
    "%{cat}%{을} 훈련장 한가운데 세워두고, 오늘은 평소보다 오래 마주 봅니다.",
    "%{cat}%{은는} 무엇을 배우게 될지 모른 채 당신의 손짓을 기다립니다.",
    "훈련 도구를 꺼내놓자 %{cat}%{은는} 귀를 쫑긋 세웁니다.",
    "%{cat}%{은는} 평소와 다른 공기를 눈치챈 듯 자세를 낮춥니다.",
    "%{cat}%{을} 데리고 조용한 방으로 들어갑니다. 오늘은 특별한 훈련입니다.",
    "%{cat}%{은는} 낯선 긴장감에 꼬리를 바짝 세웁니다.",
    "훈련이 시작되자 %{cat}%{은는} 한동안 움직이지 않습니다.",
    "%{cat}%{은는} 당신의 눈을 오래 마주 봅니다. 무언가를 각오한 얼굴입니다.",
    "오늘의 훈련은 평소의 놀이와는 다릅니다. %{cat}%{도} 그것을 아는 눈치입니다.",
    "%{cat}%{을} 앞에 두고, 당신은 크게 숨을 들이쉽니다."
  ].freeze

  # 성공 시 과정 묘사
  SUCCESS_PROCESS_TEXTS = [
    "%{cat}%{은는} 훈련 내내 눈을 반짝이며 당신을 따라 합니다. 실수도 있었지만 멈추지 않았습니다.",
    "%{cat}%{은는} 한 번도 보인 적 없는 몸놀림을 보여줍니다. 스스로도 놀란 기색입니다.",
    "%{cat}%{은는} 훈련을 마치고 한층 또렷한 눈빛으로 당신을 바라봅니다.",
    "%{cat}%{은는} 지친 기색 없이 마지막까지 훈련을 따라옵니다.",
    "%{cat}%{은는} 스스로도 놀란 듯 자기 발을 내려다봅니다.",
    "%{cat}%{은는} 몇 번이고 넘어졌지만, 그때마다 다시 일어났습니다.",
    "%{cat}%{은는} 훈련이 끝나갈 무렵 처음으로 자신 있게 움직입니다.",
    "%{cat}%{은는} 땀 한 방울 흘리지 않았을 텐데도 유난히 지쳐 보입니다. 좋은 의미로.",
    "%{cat}%{은는} 당신의 손짓 하나하나를 정확히 읽어내기 시작합니다.",
    "%{cat}%{은는} 훈련 막바지에 이르러 완전히 다른 걸음걸이로 돌아옵니다."
  ].freeze

  # 실패 시 과정 묘사
  FAILURE_PROCESS_TEXTS = [
    "%{cat}%{은는} 훈련 중간에 흥미를 잃고 자리에 앉아버립니다.",
    "%{cat}%{은는} 몇 번 시도하다 지쳐 웅크립니다.",
    "%{cat}%{은는} 훈련 도구를 물끄러미 바라만 봅니다.",
    "%{cat}%{은는} 당신의 손짓을 따라 하다 말고 하품합니다.",
    "%{cat}%{은는} 오늘은 몸이 무거운 듯 움직이지 않습니다.",
    "%{cat}%{은는} 몇 번 흉내를 내다가 이내 딴 곳을 봅니다.",
    "%{cat}%{은는} 절반쯤 하다 말고 당신 무릎으로 도망쳐 옵니다.",
    "%{cat}%{은는} 오늘따라 유독 산만하게 굽니다.",
    "%{cat}%{은는} 훈련 자세를 취하다 말고 하품을 세 번 합니다.",
    "%{cat}%{은는} 배운 것을 금방 잊은 듯 처음 동작으로 돌아갑니다."
  ].freeze

  def initialize(sheet, shop_sheet_manager)
    @sheet = sheet
    @shop_sheet_manager = shop_sheet_manager
  end

  def match?(content)
    content.include?("[특훈]")
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    cat = @sheet.cat(account)
    return "먼저 `[카피캣등록/이름]`을 해주세요." unless cat

    cat_name = cat[:name]

    used_today = @sheet.train_count_today(account)
    if used_today >= DAILY_LIMIT
      return "오늘은 이미 #{cat_name}%{을} 특훈시켰습니다. (1일 #{DAILY_LIMIT}회 제한)".sub("%{을}", eul_reul(cat_name))
    end

    credit = @sheet.get_credit(account)
    if credit < COST
      return "특훈에는 #{COST}크레딧이 필요합니다. 현재 크레딧: #{credit}"
    end

    @sheet.add_credit(account, -COST)
    @sheet.increment_train_count!(account)
    remaining_credit = credit - COST

    stage = cat[:stage].to_s.empty? ? STAGES[0] : cat[:stage]
    idx = stage_index(stage)

    before_stats = STAT_LABELS.keys.each_with_object({}) { |k, h| h[k] = cat[k].to_i }
    before_total = before_stats.values.sum

    intro = with_particles(INTRO_TEXTS.sample, cat_name)
    success = rand < SUCCESS_RATE

    if success
      keys = STAT_LABELS.keys.sample(BOOST_STATS)
      changes = {}
      stat_lines = []
      keys.each do |k|
        amount = rand(BOOST_MIN..BOOST_MAX)
        before_v = before_stats[k]
        after_v = before_v + amount
        # update_cat은 값을 절대값이 아니라 기존값에 "더하는" 방식으로 반영하므로
        # 여기서는 증가폭(amount)만 넘긴다 (절대값 after_v를 넘기면 이중으로 더해짐).
        changes[k] = amount
        stat_lines << "  · #{STAT_LABELS[k]}: #{before_v} → #{after_v} (+#{amount})"
      end

      process_text = with_particles(SUCCESS_PROCESS_TEXTS.sample, cat_name)
      changes[:last_reaction] = process_text
      @sheet.update_cat(account, changes)
      update_cat_stage(account)
      @sheet.log(account, "특훈", "성공: #{stat_lines.join(' / ')}")

      new_cat = @sheet.cat(account)
      new_stage = new_cat[:stage].to_s.empty? ? STAGES[0] : new_cat[:stage]
      after_total = STAT_LABELS.keys.sum { |k| new_cat[k].to_i }
      grew = (stage_index(new_stage) > idx)

      grow_line = ""
      if grew
        grow_line = "\n\n#{cat_name}%{은는} 훈련의 성과로 한 단계 성장했습니다!\n#{stage} → #{new_stage}".sub("%{은는}", eun_neun(cat_name))
      end

      <<~TEXT.strip
        ═══ 특훈 결과 ═══
        #{cat_name}%{을} 특훈시켰습니다. (-#{COST}크레딧, 잔여 #{remaining_credit}크레딧)

        #{intro}

        #{process_text}

        【판정】 성공 (확률 #{(SUCCESS_RATE * 100).to_i}%)

        【성향 변화】
        #{stat_lines.join("\n")}

        총 성향 합계: #{before_total} → #{after_total} (+#{after_total - before_total})
        현재 크기: #{size_text(new_stage)}#{grow_line}

        오늘 남은 특훈 횟수: #{DAILY_LIMIT - used_today - 1}회
      TEXT
        .sub("%{을}", eul_reul(cat_name))
    else
      process_text = with_particles(FAILURE_PROCESS_TEXTS.sample, cat_name)
      @sheet.update_cat(account, last_reaction: process_text)
      @sheet.log(account, "특훈", "실패")

      <<~TEXT.strip
        ═══ 특훈 결과 ═══
        #{cat_name}%{을} 특훈시켰습니다. (-#{COST}크레딧, 잔여 #{remaining_credit}크레딧)

        #{intro}

        #{process_text}

        【판정】 실패 (확률 #{(SUCCESS_RATE * 100).to_i}%)
        성향 변화 없음. 크레딧만 소모되었습니다.

        총 성향 합계: #{before_total} (변화 없음)
        현재 크기: #{size_text(stage)}

        오늘 남은 특훈 횟수: #{DAILY_LIMIT - used_today - 1}회
      TEXT
        .sub("%{을}", eul_reul(cat_name))
    end
  end

  private

  def update_cat_stage(account)
    cat = @sheet.cat(account)
    total = cat[:affection] + cat[:aggression] + cat[:stability] + cat[:weirdness] + cat[:unknown]

    stage =
      case total
      when 0..4 then "새끼"
      when 5..9 then "흉내내는 새끼"
      when 10..19 then "따라 걷는 것"
      when 20..39 then "방문을 배운 것"
      else "자리를 잡은 것"
      end

    @sheet.update_cat(account, stage: stage)
  end
end
