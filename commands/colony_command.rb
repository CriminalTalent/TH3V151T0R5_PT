class ColonyCommand
  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.include?("[군체확인]") || content.include?("[카피캣랭킹]")
  end

  def execute(content:, account:, status_id:)
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
