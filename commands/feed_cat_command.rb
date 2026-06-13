class FeedCatCommand
  FOOD_TABLE = {
    "생선" => {
      stat: :affection,
      colony: :affection,
      success: "카피캣이 생선을 앞발로 톡톡 건드립니다. 곧 당신이 먹는 방식까지 따라 하네요.",
      failure: "카피캣이 생선을 물끄러미 보더니, 당신의 실망한 표정을 먼저 따라 합니다."
    },
    "고기" => {
      stat: :aggression,
      colony: :aggression,
      success: "카피캣이 고기를 물고 낮게 웁니다. 어쩐지 사냥법을 배운 것 같습니다.",
      failure: "카피캣이 고기를 씹다 말고 당신의 손끝을 빤히 바라봅니다."
    },
    "우유" => {
      stat: :stability,
      colony: :stability,
      success: "카피캣이 우유를 마신 뒤 둥글게 웅크립니다. 잠시 평온해 보입니다.",
      failure: "카피캣이 우유 그릇을 엎었습니다. 그리고 당신의 당황한 얼굴을 흉내냅니다."
    },
    "별사탕" => {
      stat: :weirdness,
      colony: :weirdness,
      success: "카피캣이 별사탕을 삼키자 눈동자에 작은 빛이 떠오릅니다.",
      failure: "카피캣이 별사탕을 먹지 않았는데도, 별사탕은 사라졌습니다."
    },
    "검은호수의무언가" => {
      stat: :unknown,
      colony: :unknown,
      success: "카피캣이 그것을 삼킨 뒤, 당신이 모르는 목소리로 골골거립니다.",
      failure: "그것은 먹이가 아니었던 것 같습니다. 하지만 카피캣은 이미 맛을 기억했습니다."
    }
  }

  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.match?(/\[(먹이|밥주기)\/(.+?)\]/)
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    food = content.match(/\[(먹이|밥주기)\/(.+?)\]/)[2].strip
    data = FOOD_TABLE[food]

    return "그 먹이는 아직 준비되어 있지 않습니다." unless data

    cat = @sheet.cat(account)

    if cat[:last_feed] == @sheet.today
      return "오늘은 이미 카피캣에게 밥을 주었습니다. 너무 많이 먹이면 따라 하는 것도 무거워집니다."
    end

    success = rand < feed_success_rate(cat, food)
    reaction = success ? data[:success] : data[:failure]

    changes = {
      intimacy: success ? 1 : 0,
      hunger: success ? -1 : 1,
      data[:stat] => success ? 1 : 0,
      last_feed: @sheet.today,
      last_reaction: reaction
    }

    if !success && data[:stat] == :unknown
      changes[:unknown] = 1
    end

    @sheet.update_cat(account, changes)
    @sheet.update_colony(data[:colony], success ? 1 : 0)
    update_cat_stage(account)

    @sheet.log(account, "먹이/#{food}", success ? "성공" : "실패")

    <<~TEXT.strip
      #{reaction}

      결과: #{success ? "성공" : "실패"}
      #{success ? "친밀도 +1 / #{cat_stat_label(data[:stat])} +1" : "허기 +1"}
    TEXT
  end

  private

  def feed_success_rate(cat, food)
    base = 0.75
    base += cat[:intimacy] * 0.01
    base -= cat[:hunger] * 0.02
    base -= 0.15 if food == "검은호수의무언가"

    [[base, 0.25].max, 0.95].min
  end

  def cat_stat_label(stat)
    {
      affection: "애정",
      aggression: "공격성",
      stability: "안정",
      weirdness: "기묘함",
      unknown: "???"
    }[stat]
  end

  def update_cat_stage(account)
    cat = @sheet.cat(account)
    total = cat[:affection] + cat[:aggression] + cat[:stability] + cat[:weirdness] + cat[:unknown]

    stage =
      case total
      when 0..4 then "새끼"
      when 5..9 then "흉내내는 새끼"
      when 10..19 then "따라 걷는 것"
      else "방문을 배운 것"
      end

    @sheet.update_cat(account, stage: stage)
  end
end
