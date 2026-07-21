class ColonyCommand
  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.include?("[군체확인]") || content.include?("[카피캣랭킹]")
  end

  def execute(content:, account:, status_id:)
    return ranking_text if content.include?("[카피캣랭킹]")

    colony = @sheet.colony
    current = decide_colony(colony)
    stage = decide_stage(colony)

    message = colony_message(current, stage)

    @sheet.set_colony_result(
      current: current,
      stage: stage,
      message: message
    )

    <<~TEXT.strip
      현재 군체 기록입니다.

      애정 총합: #{colony[:affection]}
      공격성 총합: #{colony[:aggression]}
      안정 총합: #{colony[:stability]}
      기묘함 총합: #{colony[:weirdness]}
      ??? 총합: #{colony[:unknown]}

      현재 군체: #{current}
      단계: #{stage}

      #{message}
    TEXT
  end

  private

  TRAIT_NAMES = {
    affection:  "애정",
    aggression: "공격성",
    stability:  "안정",
    weirdness:  "기묘함",
    unknown:    "???"
  }.freeze

  def ranking_text
    ws = @sheet.worksheet("카피캣")
    cats = []

    (2..ws.num_rows).each do |row|
      character = ws[row, 2].to_s.strip
      cat_name  = ws[row, 3].to_s.strip
      next if character.empty? && cat_name.empty?

      traits = {
        affection:  ws[row, 6].to_i,
        aggression: ws[row, 7].to_i,
        stability:  ws[row, 8].to_i,
        weirdness:  ws[row, 9].to_i,
        unknown:    ws[row, 10].to_i
      }

      total = traits.values.sum
      dominant_key = traits.max_by { |_k, v| v }[0]
      dominant = traits.values.all?(&:zero?) ? "없음" : TRAIT_NAMES[dominant_key]

      cats << {
        character: character,
        cat_name:  cat_name,
        total:     total,
        dominant:  dominant
      }
    end

    return "아직 등록된 카피캣이 없습니다." if cats.empty?

    cats.sort_by! { |c| -c[:total] }

    lines = []
    lines << "카피캣 랭킹입니다."
    lines << "──────────────────"
    cats.each_with_index do |c, i|
      lines << "#{i + 1}위. #{c[:cat_name]} (#{c[:character]})"
      lines << "   성향 총합 #{c[:total]} / 우세 성향: #{c[:dominant]}"
    end
    lines << "──────────────────"

    lines.join("\n")
  end

  def decide_colony(colony)
    values = {
      "따르는 군체" => colony[:affection],
      "사냥하는 군체" => colony[:aggression],
      "웅크린 군체" => colony[:stability],
      "흉내내는 군체" => colony[:weirdness],
      "방문하는 군체" => colony[:unknown]
    }

    values.max_by { |_k, v| v }[0]
  end

  def decide_stage(colony)
    total = colony[:affection] + colony[:aggression] + colony[:stability] + colony[:weirdness] + colony[:unknown]

    case total
    when 0..19 then "잠복"
    when 20..49 then "형성"
    when 50..99 then "성장"
    else "방문"
    end
  end

  def colony_message(current, stage)
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
end
